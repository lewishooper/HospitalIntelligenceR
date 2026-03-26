# =============================================================================
# roles/strategy/phase2_extract.R  —  PHASE 2: Extract & Structure
# HospitalIntelligenceR
#
# What this script does:
#   For each hospital that has a local file from Phase 1, read the content,
#   send it to the Claude API with a structured extraction prompt, parse the
#   response into long-format rows, and write the results to a per-hospital
#   CSV and the strategy master CSV.
#
# Input sources (determined by file extension):
#   .pdf         — pdftools::pdf_text() extracts raw text from PDF pages
#   .txt / .csv  — readLines() reads as plain text
#   html_only    — rvest fetches live HTML from content_url in the registry
#
# Outputs:
#   roles/strategy/outputs/extractions/<FAC_FOLDER>/<FAC>_<YYYYMMDD>_extracted.csv
#   roles/strategy/outputs/extractions/strategy_master.csv
#
# Run modes (set before sourcing):
#   "all"  — all hospitals with a local file (or html_only status) [default]
#   "facs" — specific FAC codes only (set TARGET_FACS vector)
#
# Usage:
#   TARGET_MODE <- "all"
#   source("roles/strategy/phase2_extract.R")
#
#   # Or for specific hospitals:
#   TARGET_MODE <- "facs"
#   TARGET_FACS <- c("592", "644", "701")
#   source("roles/strategy/phase2_extract.R")
#
# Dependencies:
#   core/registry.R, core/fetcher.R, core/logger.R, core/claude_api.R
#   roles/strategy/config.R
#   pdftools, rvest, jsonlite, dplyr, purrr, stringr
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(purrr)
  library(jsonlite)
  library(pdftools)
  library(rvest)
})

# --- Source core modules ---
source("core/registry.R")
source("core/fetcher.R")
source("core/logger.R")
source("core/claude_api.R")

# --- Source role config ---
source("roles/strategy/config.R")   # produces STRATEGY_CONFIG


# =============================================================================
# STEP 0: Validate run mode and initialise
# =============================================================================

if (!exists("TARGET_MODE")) TARGET_MODE <- "all"

valid_modes <- c("all", "facs")
if (!TARGET_MODE %in% valid_modes) {
  stop(sprintf("Unknown TARGET_MODE '%s'. Must be one of: %s",
               TARGET_MODE, paste(valid_modes, collapse = ", ")))
}

if (TARGET_MODE == "facs" && !exists("TARGET_FACS")) {
  stop("TARGET_MODE is 'facs' but TARGET_FACS is not defined.")
}

run_id <- format(Sys.time(), "%Y%m%d_%H%M%S")

init_logger(
  role     = paste0(STRATEGY_CONFIG$role, "_phase2"),
  log_root = "logs",
  echo     = TRUE
)

log_info(sprintf("Strategy Phase 2 — extract & structure | mode: %s | run_id: %s",
                 TARGET_MODE, run_id))

# --- Ensure output directory exists ---
extraction_root <- "roles/strategy/outputs/extractions"
if (!dir.exists(extraction_root)) {
  dir.create(extraction_root, recursive = TRUE, showWarnings = FALSE)
  log_info(sprintf("Created extractions output directory: %s", extraction_root))
}

# --- Load extraction prompt ---
prompt_path <- STRATEGY_CONFIG$prompt_file
if (!file.exists(prompt_path)) {
  stop(sprintf("Extraction prompt not found: %s", prompt_path))
}
system_prompt <- paste(readLines(prompt_path, warn = FALSE), collapse = "\n")
log_info(sprintf("Loaded extraction prompt from: %s", prompt_path))


# =============================================================================
# STEP 1: Load eligible hospitals
# =============================================================================

log_info("STEP 1: Loading hospital list from registry")

all_hospitals <- load_registry()

# Filter by run mode
if (TARGET_MODE == "facs") {
  all_hospitals <- Filter(function(h) {
    as.character(h$FAC) %in% as.character(TARGET_FACS)
  }, all_hospitals)
}

# Phase 2 eligibility: hospital must either have a local file or be html_only
# A hospital is eligible if:
#   (a) local_filename is non-empty (has a file on disk), OR
#   (b) extraction_status is "html_only" (we will fetch live HTML)
is_eligible <- function(h) {
  role_data  <- h$status$strategy
  if (is.null(role_data)) return(FALSE)

  has_file   <- !is.null(role_data$local_filename) &&
                nchar(trimws(as.character(role_data$local_filename))) > 0

  is_html    <- !is.null(role_data$extraction_status) &&
                identical(as.character(role_data$extraction_status), "html_only")

  has_file || is_html
}

hospitals <- Filter(is_eligible, all_hospitals)

if (length(hospitals) == 0) {
  log_info("No eligible hospitals found (no local files and no html_only entries). Exiting.")
  log_run_summary()
  stop("No eligible hospitals — nothing to do.", call. = FALSE)
}

log_info(sprintf("Hospitals eligible for Phase 2: %d", length(hospitals)))


# =============================================================================
# STEP 2: Helper functions
# =============================================================================

# -----------------------------------------------------------------------------
# .read_content(hospital)
# Returns a list: list(text = character, source_type = character, error = character|NULL)
# source_type: "pdf" | "txt" | "html"
# -----------------------------------------------------------------------------

.read_content <- function(hospital) {
  role_data <- hospital$status$strategy
  fac       <- as.character(hospital$FAC)

  # --- html_only path ---
  if (!is.null(role_data$extraction_status) &&
      identical(as.character(role_data$extraction_status), "html_only")) {

    content_url <- role_data$content_url
    if (is.null(content_url) || nchar(trimws(content_url)) == 0) {
      return(list(text = NULL, source_type = "html",
                  error = "html_only but content_url is empty"))
    }

    log_info(sprintf("FAC %s: fetching HTML from %s", fac, content_url))
    html_result <- tryCatch({
      page <- read_html(content_url)
      # Strip nav, header, footer, script, style — keep body text
      body_text <- page |>
        html_element("body") |>
        html_text2()
      list(text = body_text, source_type = "html", error = NULL)
    }, error = function(e) {
      list(text = NULL, source_type = "html",
           error = sprintf("rvest fetch failed: %s", conditionMessage(e)))
    })
    return(html_result)
  }

  # --- File-based path ---
  local_folder   <- role_data$local_folder
  local_filename <- role_data$local_filename

  if (is.null(local_filename) || nchar(trimws(local_filename)) == 0) {
    return(list(text = NULL, source_type = NA_character_,
                error = "local_filename is empty"))
  }

  file_path <- file.path(STRATEGY_CONFIG$output_root, local_folder, local_filename)

  if (!file.exists(file_path)) {
    return(list(text = NULL, source_type = NA_character_,
                error = sprintf("File not found on disk: %s", file_path)))
  }

  ext <- tolower(tools::file_ext(local_filename))

  if (ext == "pdf") {
    text <- tryCatch({
      pages <- pdf_text(file_path)
      paste(pages, collapse = "\n")
    }, error = function(e) {
      return(list(text = NULL, source_type = "pdf",
                  error = sprintf("pdftools failed: %s", conditionMessage(e))))
    })
    if (is.list(text)) return(text)   # caught an error above
    return(list(text = text, source_type = "pdf", error = NULL))
  }

  if (ext %in% c("txt", "csv")) {
    text <- tryCatch({
      paste(readLines(file_path, warn = FALSE), collapse = "\n")
    }, error = function(e) {
      return(list(text = NULL, source_type = "txt",
                  error = sprintf("readLines failed: %s", conditionMessage(e))))
    })
    if (is.list(text)) return(text)
    return(list(text = text, source_type = "txt", error = NULL))
  }

  list(text = NULL, source_type = ext,
       error = sprintf("Unrecognised file extension: %s", ext))
}


# -----------------------------------------------------------------------------
# .is_text_usable(text)
# Quick check — returns FALSE if text is empty or clearly garbage
# (happens when a PDF is entirely image-based and pdftools gets nothing)
# -----------------------------------------------------------------------------

.is_text_usable <- function(text) {
  if (is.null(text) || length(text) == 0) return(FALSE)
  cleaned <- gsub("\\s+", "", text)
  nchar(cleaned) >= 200   # Fewer than 200 non-whitespace chars is useless
}


# -----------------------------------------------------------------------------
# .call_extraction_api(text, fac)
# Calls the Claude API with the document text and extraction prompt.
# Returns list(response_text, input_tokens, output_tokens, cost, error)
# -----------------------------------------------------------------------------

.call_extraction_api <- function(text, fac) {
  user_message <- paste0(
    "Extract the strategic plan information from the following document:\n\n",
    text
  )

  tryCatch({
    result <- call_claude(
      user_message  = user_message,
      system_prompt = system_prompt,
      model         = "claude-sonnet-4-20250514",
      max_tokens    = STRATEGY_CONFIG$max_tokens,
      temperature   = STRATEGY_CONFIG$temperature
    )
    result
  }, error = function(e) {
    list(response_text  = NULL,
         input_tokens   = 0L,
         output_tokens  = 0L,
         cost           = 0.0,
         error          = conditionMessage(e))
  })
}


# -----------------------------------------------------------------------------
# .parse_response(response_text, fac)
# Parses the JSON response from Claude into a list.
# Returns list(parsed = list|NULL, error = character|NULL)
# -----------------------------------------------------------------------------

.parse_response <- function(response_text, fac) {
  if (is.null(response_text) || nchar(trimws(response_text)) == 0) {
    return(list(parsed = NULL, error = "Empty response from Claude API"))
  }

  # Strip any accidental markdown fences Claude may have added
  clean <- response_text |>
    str_remove("^```json\\s*") |>
    str_remove("^```\\s*")     |>
    str_remove("\\s*```$")     |>
    trimws()

  tryCatch({
    parsed <- fromJSON(clean, simplifyVector = FALSE)
    list(parsed = parsed, error = NULL)
  }, error = function(e) {
    list(parsed = NULL,
         error  = sprintf("JSON parse failed: %s", conditionMessage(e)))
  })
}


# -----------------------------------------------------------------------------
# .build_rows(parsed, fac, capture_date, source_type)
# Converts parsed JSON into a long-format data frame — one row per direction.
# Plan-level fields repeat across all rows for the same hospital.
# Returns a data.frame.
# -----------------------------------------------------------------------------

.build_rows <- function(parsed, fac, capture_date, source_type) {

  # Plan-level fields (repeat per row)
  plan_level <- list(
    fac                      = as.character(fac),
    hospital_name_self_reported = .safe_str(parsed$hospital_name_self_reported),
    plan_period_start        = .safe_str(parsed$plan_period_start),
    plan_period_end          = .safe_str(parsed$plan_period_end),
    vision                   = .safe_str(parsed$vision),
    mission                  = .safe_str(parsed$mission),
    values                   = .safe_str(parsed$values),
    purpose                  = .safe_str(parsed$purpose),
    extraction_quality       = .safe_str(parsed$extraction_quality),
    extraction_notes         = .safe_str(parsed$extraction_notes),
    source_type              = as.character(source_type),
    extraction_date          = as.character(capture_date)
  )

  directions <- parsed$directions

  # If no directions, return a single summary row with no direction fields
  if (is.null(directions) || length(directions) == 0) {
    return(as.data.frame(c(plan_level, list(
      direction_number      = NA_integer_,
      direction_name        = NA_character_,
      direction_type        = NA_character_,
      direction_description = NA_character_,
      key_actions           = NA_character_
    )), stringsAsFactors = FALSE))
  }

  # One row per direction
  rows <- map(directions, function(d) {
    as.data.frame(c(plan_level, list(
      direction_number      = .safe_int(d$direction_number),
      direction_name        = .safe_str(d$direction_name),
      direction_type        = .safe_str(d$direction_type),
      direction_description = .safe_str(d$direction_description),
      key_actions           = .safe_str(d$key_actions)
    )), stringsAsFactors = FALSE)
  })

  bind_rows(rows)
}

# Coercion helpers — return NA of the right type rather than NULL
.safe_str <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_character_)
  as.character(x[[1]])
}

.safe_int <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_integer_)
  suppressWarnings(as.integer(x[[1]]))
}


# -----------------------------------------------------------------------------
# .write_hospital_csv(df, fac, local_folder)
# Writes the per-hospital extraction CSV.
# Returns the path written.
# -----------------------------------------------------------------------------

.write_hospital_csv <- function(df, fac, local_folder) {
  out_dir <- file.path(extraction_root, local_folder)
  if (!dir.exists(out_dir)) {
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  }
  filename <- sprintf("%s_%s_extracted.csv", fac, format(Sys.Date(), "%Y%m%d"))
  out_path <- file.path(out_dir, filename)
  write.csv(df, out_path, row.names = FALSE)
  out_path
}


# =============================================================================
# STEP 3: Process hospitals
# =============================================================================

log_info(sprintf("%s", strrep("=", 60)))
log_info("STEP 3: Processing hospitals")

# Accumulator for master CSV rows
all_rows <- list()

for (i in seq_along(hospitals)) {

  hospital      <- hospitals[[i]]
  fac           <- as.character(hospital$FAC)
  hospital_name <- as.character(hospital$name)
  role_data     <- hospital$status$strategy

  # Derive folder name for output — use local_folder from registry if available,
  # else fall back to FAC + sanitised name
  local_folder <- role_data$local_folder
  if (is.null(local_folder) || nchar(trimws(local_folder)) == 0) {
    local_folder <- sprintf("%s_%s", fac,
                            toupper(str_replace_all(hospital_name, "[^A-Z0-9a-z]+", "_")))
  }

  log_info(sprintf("--- Hospital %d/%d: FAC %s — %s ---",
                   i, length(hospitals), fac, hospital_name))


  # ------------------------------------------------------------------
  # STEP 3a: Read document content
  # ------------------------------------------------------------------

  content_result <- .read_content(hospital)

  if (!is.null(content_result$error)) {
    log_outcome(fac, hospital_name, "failure",
                failure_type  = "content_read_error",
                error_message = content_result$error)
    update_hospital_status(fac, "strategy", list(
      phase2_status = "read_failed",
      needs_review  = TRUE
    ))
    next
  }

  if (!.is_text_usable(content_result$text)) {
    log_warning(sprintf(
      "FAC %s: extracted text is empty or too short — PDF may be image-based. Logging as thin.",
      fac
    ))
    # Don't skip — pass to Claude anyway; it will return extraction_quality = "thin"
    # and we log it. Fine-tuning pass can handle image-mode retry.
    log_warning(sprintf("FAC %s: proceeding with thin text — will flag in output", fac))
  }

  source_type <- content_result$source_type
  text        <- content_result$text %||% ""

  log_info(sprintf("FAC %s: content read (%s) — %d characters",
                   fac, source_type, nchar(text)))


  # ------------------------------------------------------------------
  # STEP 3b: Call Claude API
  # ------------------------------------------------------------------

  log_info(sprintf("FAC %s: calling Claude API", fac))

  api_result <- .call_extraction_api(text, fac)

  if (!is.null(api_result$error)) {
    log_outcome(fac, hospital_name, "failure",
                failure_type  = "api_error",
                error_message = api_result$error)
    update_hospital_status(fac, "strategy", list(
      phase2_status = "api_failed",
      needs_review  = TRUE
    ))
    next
  }

  log_info(sprintf("FAC %s: API call complete — %d input tokens, %d output tokens, $%.4f",
                   fac,
                   api_result$input_tokens,
                   api_result$output_tokens,
                   api_result$cost))


  # ------------------------------------------------------------------
  # STEP 3c: Parse JSON response
  # ------------------------------------------------------------------

  parse_result <- .parse_response(api_result$response_text, fac)

  if (!is.null(parse_result$error)) {
    log_outcome(fac, hospital_name, "failure",
                cost          = api_result$cost,
                failure_type  = "parse_error",
                error_message = parse_result$error)
    update_hospital_status(fac, "strategy", list(
      phase2_status = "parse_failed",
      needs_review  = TRUE
    ))
    next
  }

  parsed <- parse_result$parsed


  # ------------------------------------------------------------------
  # STEP 3d: Build long-format data frame
  # ------------------------------------------------------------------

  df <- tryCatch({
    .build_rows(parsed, fac, Sys.Date(), source_type)
  }, error = function(e) {
    log_warning(sprintf("FAC %s: .build_rows() error — %s", fac, conditionMessage(e)))
    NULL
  })

  if (is.null(df) || nrow(df) == 0) {
    log_outcome(fac, hospital_name, "failure",
                cost          = api_result$cost,
                failure_type  = "empty_result",
                error_message = "build_rows returned empty data frame")
    update_hospital_status(fac, "strategy", list(
      phase2_status = "empty_result",
      needs_review  = TRUE
    ))
    next
  }


  # ------------------------------------------------------------------
  # STEP 3e: Write per-hospital CSV
  # ------------------------------------------------------------------

  out_path <- tryCatch(
    .write_hospital_csv(df, fac, local_folder),
    error = function(e) {
      log_warning(sprintf("FAC %s: failed to write CSV — %s", fac, conditionMessage(e)))
      NULL
    }
  )

  if (is.null(out_path)) {
    log_outcome(fac, hospital_name, "failure",
                cost          = api_result$cost,
                failure_type  = "write_error",
                error_message = "Could not write per-hospital CSV")
    next
  }


  # ------------------------------------------------------------------
  # STEP 3f: Update registry and log success
  # ------------------------------------------------------------------

  quality <- .safe_str(parsed$extraction_quality)
  n_dirs  <- if (!is.null(parsed$directions)) length(parsed$directions) else 0L

  update_hospital_status(fac, "strategy", list(
    phase2_status    = "extracted",
    phase2_date      = as.character(Sys.Date()),
    phase2_quality   = quality,
    phase2_n_dirs    = n_dirs,
    needs_review     = identical(quality, "thin")
  ))

  all_rows[[length(all_rows) + 1]] <- df

  log_outcome(
    fac           = fac,
    hospital_name = hospital_name,
    outcome       = "success",
    cost          = api_result$cost,
    context       = sprintf("quality: %s | directions: %d | file: %s",
                             quality, n_dirs, basename(out_path))
  )
}


# =============================================================================
# STEP 4: Assemble strategy_master.csv
# =============================================================================

log_info(sprintf("%s", strrep("=", 60)))
log_info("STEP 4: Assembling strategy_master.csv")

if (length(all_rows) > 0) {
  master_df   <- bind_rows(all_rows)
  master_path <- file.path(extraction_root, "strategy_master.csv")

  # If a master already exists, append new rows (union on fac + direction_number)
  if (file.exists(master_path)) {
    existing    <- read.csv(master_path, stringsAsFactors = FALSE)
    # Remove old rows for FACs we just re-processed
    processed_facs <- unique(master_df$fac)
    existing    <- existing[!existing$fac %in% processed_facs, ]
    master_df   <- bind_rows(existing, master_df)
    log_info(sprintf(
      "Merged with existing master: %d existing rows retained, %d new rows added",
      nrow(existing), nrow(bind_rows(all_rows))
    ))
  }

  master_df <- arrange(master_df, fac, direction_number)
  write.csv(master_df, master_path, row.names = FALSE)
  log_info(sprintf("strategy_master.csv written: %d rows, %d hospitals — %s",
                   nrow(master_df), length(unique(master_df$fac)), master_path))
} else {
  log_warning("No rows were successfully extracted — strategy_master.csv not updated.")
}


# =============================================================================
# STEP 5: Run summary
# =============================================================================

log_info(sprintf("%s", strrep("=", 60)))
log_info("STEP 5: Run complete")
log_run_summary()
