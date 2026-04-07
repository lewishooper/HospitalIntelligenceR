# =============================================================================
# analysis/scripts/00g_fetch_missing_dates.R
# HospitalIntelligenceR — Targeted Date Re-Extraction for Missing Plan Dates
#
# PURPOSE:
#   14 hospitals in the usable cohort have no parsed plan_period_start year,
#   excluding them from all temporal analysis (03b_theme_trends.R).
#   This script sends each hospital's document to Claude with a date-only
#   prompt, attempts to recover plan_period_start and plan_period_end, and
#   writes results to a manually-editable review CSV.
#
#   NO DATA IS MODIFIED BY THIS SCRIPT. The review CSV is the only output.
#   Apply confirmed dates using 00h_patch_missing_dates.R (built separately).
#
# STRATEGY:
#   1. Attempt text extraction via pdftools::pdf_text()
#   2. If text is thin (< 200 chars), fall back to image mode (150 DPI)
#   3. For hospitals already flagged force_image_mode in YAML, use image mode directly
#   4. Send to Claude with a focused date-only prompt (cheap: ~200 output tokens)
#   5. Parse response and write to review CSV with confidence flags
#
# 5-YEAR HORIZON ASSUMPTION:
#   Where plan_period_end is recovered but plan_period_start remains null,
#   start is set to (end - 4) per the 5-year horizon assumption.
#   This assumption is flagged explicitly in the review CSV and must be
#   confirmed before applying. It will be documented in the 03b narrative.
#
# OUTPUTS:
#   analysis/outputs/tables/00g_date_review.csv   -- manually editable
#
# COLUMNS IN REVIEW CSV:
#   fac, hospital_name, hospital_type_group, extraction_quality,
#   api_start_raw, api_end_raw,
#   derived_start, derived_end,
#   assumption_applied,   -- "5yr_horizon" | "none" | "manual_required"
#   confidence,           -- "high" | "medium" | "low" | "not_found"
#   api_notes,            -- Claude's reasoning / uncertainty statement
#   source_mode,          -- "text" | "image"
#   cost_usd,
#   manual_override_start,  -- BLANK — fill in manually if needed
#   manual_override_end,    -- BLANK — fill in manually if needed
#   manual_notes            -- BLANK — fill in manually if needed
#
# USAGE:
#   source("analysis/scripts/00g_fetch_missing_dates.R")
#
# DEPENDENCIES:
#   core/registry.R, core/logger.R, core/claude_api.R
#   pdftools, png, base64enc, jsonlite, dplyr, readr
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(jsonlite)
  library(pdftools)
  library(png)
  library(base64enc)
  library(stringr)
})

source("core/registry.R")
source("core/logger.R")
source("core/claude_api.R")


# =============================================================================
# CONFIGURATION
# =============================================================================

TARGET_FACS <- c("611", "619", "624", "654", "662", "707",
                 "928", "935", "940", "942", "947", "950", "959", "975")

IMAGE_DPI          <- 150L
TEXT_MIN_CHARS     <- 200L    # below this → fall back to image mode
MAX_IMAGE_PAGES    <- 20L     # cap to control cost; cover + first pages sufficient
OUTPUT_PATH        <- "analysis/outputs/tables/00g_date_review.csv"
LOCAL_FILE_ROOT    <- "roles/strategy/outputs/pdfs"


# =============================================================================
# DATE-ONLY SYSTEM PROMPT
# =============================================================================

DATE_SYSTEM_PROMPT <- '
You are a precise data extraction assistant working with Ontario hospital strategic plans.

Your ONLY task is to find the plan period dates — the years during which this strategic
plan is in effect. Return ONLY a JSON object with no preamble, explanation, or markdown.

EXTRACTION RULES:
1. Extract plan_period_start and plan_period_end from explicit document content only.
   Do NOT use file metadata, creation date, publication date, or copyright year.
2. Accept any of: "2023–2027", "2023-2027", "Our 2030 Plan", "a five-year plan to 2028",
   "Strategic Plan 2024" (single year = end year), or similar natural language.
3. If only the end year is stated (e.g. "Our Vision to 2030", "Plan to 2030"),
   return null for plan_period_start and the stated year for plan_period_end.
4. If only a single year is stated ambiguously and you cannot determine if it is
   start or end, return null for both and explain in notes.
5. Do NOT infer, calculate, or guess. If a value is not explicitly stated, return null.
6. Return 4-digit years only (e.g. "2025"). Do not return full dates.

RESPONSE FORMAT — return ONLY this JSON, nothing else:
{
  "plan_period_start": "2023" or null,
  "plan_period_end":   "2027" or null,
  "confidence":        "high" | "medium" | "low" | "not_found",
  "notes":             "Brief statement of where dates were found, or why not found."
}

confidence guide:
  "high"      — explicit range stated (e.g. "2023–2027")
  "medium"    — end year clear, start inferred from context (e.g. "five-year plan to 2027")
  "low"       — dates present but ambiguous or partially legible
  "not_found" — no plan period dates found anywhere in the document
'


# =============================================================================
# HELPERS
# =============================================================================

init_logger(role = "date_fetch", log_root = "logs", echo = TRUE)

`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0) a else b


# Resolve local file path for a hospital
.get_file_path <- function(h) {
  s <- h$status$strategy
  folder   <- s$local_folder   %||% ""
  filename <- s$local_filename %||% ""
  if (nchar(folder) == 0 || nchar(filename) == 0) return(NULL)
  file.path(LOCAL_FILE_ROOT, folder, filename)
}


# Extract text from PDF
.read_text <- function(file_path) {
  tryCatch({
    pages <- pdf_text(file_path)
    paste(pages, collapse = "\n")
  }, error = function(e) {
    log_warning(sprintf("pdf_text() failed for %s: %s", basename(file_path), conditionMessage(e)))
    ""
  })
}


# Render PDF to images (capped at MAX_IMAGE_PAGES)
.read_images <- function(file_path) {
  tryCatch({
    info    <- pdf_info(file_path)
    n_pages <- min(info$pages, MAX_IMAGE_PAGES)
    images  <- vector("list", n_pages)
    for (pg in seq_len(n_pages)) {
      raw_png      <- pdf_render_page(file_path, page = pg, dpi = IMAGE_DPI, numeric = FALSE)
      png_bytes    <- png::writePNG(raw_png)
      images[[pg]] <- list(
        data       = base64enc::base64encode(png_bytes),
        media_type = "image/png"
      )
    }
    list(images = images, n_pages = n_pages, error = NULL)
  }, error = function(e) {
    list(images = NULL, n_pages = 0L,
         error  = sprintf("PDF render failed: %s", conditionMessage(e)))
  })
}


# Call Claude in text mode
.call_text_mode <- function(text, fac) {
  user_message <- paste0(
    "Find the plan period dates in this hospital strategic plan document:\n\n",
    text
  )
  call_claude(
    user_message  = user_message,
    system_prompt = DATE_SYSTEM_PROMPT,
    model         = "claude-sonnet-4-20250514",
    max_tokens    = 300L,
    temperature   = 0,
    role          = "date_fetch",
    fac           = fac
  )
}


# Call Claude in image mode — appends targeted instruction to content
.call_image_mode <- function(images, fac) {
  # Build content: image blocks + targeted text instruction
  image_blocks <- lapply(images, function(img) {
    list(
      type   = "image",
      source = list(
        type       = "base64",
        media_type = img$media_type,
        data       = img$data
      )
    )
  })
  
  content_blocks <- c(image_blocks, list(
    list(
      type = "text",
      text = "Find the plan period dates in these hospital strategic plan pages. Return only the JSON object specified."
    )
  ))
  
  api_key <- Sys.getenv("ANTHROPIC_API_KEY")
  if (nchar(api_key) == 0) stop("ANTHROPIC_API_KEY not set.")
  
  body <- list(
    model       = "claude-sonnet-4-20250514",
    max_tokens  = 300L,
    temperature = 0,
    system      = DATE_SYSTEM_PROMPT,
    messages    = list(
      list(role = "user", content = content_blocks)
    )
  )
  
  attempt    <- 1L
  max_retries <- 3L
  last_error  <- NULL
  
  while (attempt <= max_retries) {
    if (attempt > 1L) Sys.sleep(2^(attempt - 1L))
    
    result <- tryCatch({
      resp <- httr2::request("https://api.anthropic.com/v1/messages") |>
        httr2::req_headers(
          "x-api-key"         = api_key,
          "anthropic-version" = "2023-06-01",
          "content-type"      = "application/json"
        ) |>
        httr2::req_body_raw(toJSON(body, auto_unbox = TRUE), type = "application/json") |>
        httr2::req_error(is_error = function(resp) FALSE) |>
        httr2::req_perform()
      
      status    <- httr2::resp_status(resp)
      resp_json <- fromJSON(httr2::resp_body_string(resp), simplifyVector = FALSE)
      
      if (status != 200L) {
        is_retryable <- status %in% c(429L, 529L) || status >= 500L
        last_error   <- sprintf("HTTP %d: %s", status,
                                resp_json$error$message %||% "unknown")
        list(retry = is_retryable, error = last_error)
      } else {
        resp_text <- paste(
          sapply(resp_json$content, function(b) b$text %||% ""),
          collapse = "\n"
        )
        usage <- resp_json$usage
        in_tok  <- as.integer(usage$input_tokens  %||% 0L)
        out_tok <- as.integer(usage$output_tokens %||% 0L)
        cost    <- (in_tok / 1e6 * 3.00) + (out_tok / 1e6 * 15.00)
        
        list(
          success       = TRUE,
          response_text = resp_text,
          input_tokens  = in_tok,
          output_tokens = out_tok,
          cost          = cost,
          error         = NULL
        )
      }
    }, error = function(e) {
      last_error <<- conditionMessage(e)
      list(retry = TRUE, error = last_error)
    })
    
    if (isTRUE(result$success)) return(result)
    if (!isTRUE(result$retry))  break
    attempt <- attempt + 1L
  }
  
  list(response_text = NULL, input_tokens = 0L, output_tokens = 0L,
       cost = 0.0, error = last_error %||% "All retries failed")
}


# Parse Claude's JSON response — strip markdown fences if present
.parse_response <- function(response_text) {
  clean <- gsub("```json|```", "", response_text, fixed = FALSE)
  clean <- trimws(clean)
  tryCatch(
    fromJSON(clean, simplifyVector = FALSE),
    error = function(e) {
      list(plan_period_start = NULL, plan_period_end = NULL,
           confidence = "parse_error", notes = response_text)
    }
  )
}


# Apply the 5-year horizon assumption
# If end is known and start is null → start = end - 4
.apply_horizon_assumption <- function(start_raw, end_raw) {
  start <- start_raw %||% NA_character_
  end   <- end_raw   %||% NA_character_
  
  assumption <- "none"
  
  if (is.na(start) && !is.na(end)) {
    end_yr <- suppressWarnings(as.integer(end))
    if (!is.na(end_yr)) {
      start      <- as.character(end_yr - 4L)
      assumption <- "5yr_horizon"
    }
  }
  
  list(derived_start = start, derived_end = end, assumption = assumption)
}


# =============================================================================
# MAIN LOOP
# =============================================================================

log_info(sprintf("00g_fetch_missing_dates: processing %d FACs", length(TARGET_FACS)))

all_hospitals <- load_registry()

# Index by FAC for fast lookup
hosp_index <- setNames(
  all_hospitals,
  sapply(all_hospitals, function(h) as.character(h$FAC))
)

results <- vector("list", length(TARGET_FACS))

for (i in seq_along(TARGET_FACS)) {
  fac  <- TARGET_FACS[i]
  h    <- hosp_index[[fac]]
  
  if (is.null(h)) {
    log_warning(sprintf("FAC %s not found in registry — skipping", fac))
    next
  }
  
  hosp_name   <- h$name %||% ""
  hosp_type   <- h$hospital_type %||% ""
  s           <- h$status$strategy %||% list()
  phase2_qual <- s$phase2_quality  %||% ""
  force_image <- isTRUE(s$force_image_mode)
  
  log_info(sprintf("--- FAC %s | %s | quality=%s | force_image=%s",
                   fac, hosp_name, phase2_qual, force_image))
  
  # --- Locate file ---
  file_path <- .get_file_path(h)
  
  if (is.null(file_path) || !file.exists(file_path)) {
    log_warning(sprintf("FAC %s: file not found at expected path — skipping", fac))
    results[[i]] <- data.frame(
      fac = fac, hospital_name = hosp_name, hospital_type_group = hosp_type,
      extraction_quality = phase2_qual,
      api_start_raw = NA, api_end_raw = NA,
      derived_start = NA, derived_end = NA,
      assumption_applied = "manual_required",
      confidence = "file_not_found", api_notes = "File not found on disk",
      source_mode = NA, cost_usd = 0,
      manual_override_start = NA, manual_override_end = NA, manual_notes = NA,
      stringsAsFactors = FALSE
    )
    next
  }
  
  # --- Decide extraction mode ---
  use_image <- force_image
  
  if (!use_image) {
    text <- .read_text(file_path)
    if (nchar(trimws(text)) < TEXT_MIN_CHARS) {
      log_info(sprintf("FAC %s: text thin (%d chars) — switching to image mode",
                       fac, nchar(trimws(text))))
      use_image <- TRUE
    }
  }
  
  # --- Call API ---
  if (use_image) {
    log_info(sprintf("FAC %s: rendering PDF to images at %d DPI", fac, IMAGE_DPI))
    img_result <- .read_images(file_path)
    
    if (!is.null(img_result$error)) {
      log_warning(sprintf("FAC %s: image render failed: %s", fac, img_result$error))
      api_result <- list(response_text = NULL, cost = 0, error = img_result$error)
    } else {
      log_info(sprintf("FAC %s: sending %d pages to Claude (image mode)", fac, img_result$n_pages))
      api_result <- .call_image_mode(img_result$images, fac)
    }
    source_mode <- "image"
    
  } else {
    log_info(sprintf("FAC %s: sending text to Claude (%d chars)", fac, nchar(text)))
    api_result  <- .call_text_mode(text, fac)
    source_mode <- "text"
  }
  
  # --- Parse response ---
  if (!is.null(api_result$error) && is.null(api_result$response_text)) {
    log_warning(sprintf("FAC %s: API call failed: %s", fac, api_result$error))
    parsed <- list(plan_period_start = NULL, plan_period_end = NULL,
                   confidence = "api_error", notes = api_result$error)
  } else {
    parsed <- .parse_response(api_result$response_text)
  }
  
  start_raw  <- as.character(parsed$plan_period_start %||% NA_character_)[1]
  end_raw    <- as.character(parsed$plan_period_end   %||% NA_character_)[1]
  confidence <- as.character(parsed$confidence        %||% "unknown")[1]
  notes      <- as.character(parsed$notes             %||% "")[1]
  
  log_info(sprintf("FAC %s: start=%s end=%s confidence=%s",
                   fac, start_raw %||% "NA", end_raw %||% "NA", confidence))
  
  # --- Apply 5-year horizon assumption where applicable ---
  derived <- .apply_horizon_assumption(start_raw, end_raw)
  
  if (derived$assumption == "5yr_horizon") {
    log_info(sprintf("FAC %s: 5-year horizon applied — derived start=%s",
                     fac, derived$derived_start))
  }
  
  cost <- api_result$cost %||% 0
  
  results[[i]] <- data.frame(
    fac                   = fac,
    hospital_name         = hosp_name,
    hospital_type_group   = hosp_type,
    extraction_quality    = phase2_qual,
    api_start_raw         = start_raw %||% NA_character_,
    api_end_raw           = end_raw   %||% NA_character_,
    derived_start         = derived$derived_start %||% NA_character_,
    derived_end           = derived$derived_end   %||% NA_character_,
    assumption_applied    = derived$assumption,
    confidence            = confidence,
    api_notes             = notes,
    source_mode           = source_mode,
    cost_usd              = round(cost, 5),
    manual_override_start = NA_character_,
    manual_override_end   = NA_character_,
    manual_notes          = NA_character_,
    stringsAsFactors = FALSE
  )
  
  Sys.sleep(0.5)   # gentle pacing between API calls
}


# =============================================================================
# WRITE REVIEW CSV
# =============================================================================

review <- bind_rows(results)

dir.create(dirname(OUTPUT_PATH), recursive = TRUE, showWarnings = FALSE)
write_csv(review, OUTPUT_PATH)

log_info(sprintf("Review CSV written: %s", OUTPUT_PATH))
log_info(sprintf("  Rows: %d", nrow(review)))
log_info(sprintf("  Dates recovered (both fields): %d",
                 sum(!is.na(review$derived_start) & !is.na(review$derived_end))))
log_info(sprintf("  5-year horizon applied: %d",
                 sum(review$assumption_applied == "5yr_horizon", na.rm = TRUE)))
log_info(sprintf("  Manual review required: %d",
                 sum(review$confidence %in% c("not_found","api_error","file_not_found","low"), na.rm = TRUE)))
log_info(sprintf("  Total API cost: $%.4f USD", sum(review$cost_usd, na.rm = TRUE)))

cat("\n=== 00g_fetch_missing_dates complete ===\n")
cat(sprintf("Review CSV: %s\n", OUTPUT_PATH))
cat("\nNEXT STEPS:\n")
cat("  1. Open the review CSV and inspect all rows\n")
cat("  2. For any row needing correction, fill in manual_override_start / manual_override_end\n")
cat("  3. Add a note in manual_notes explaining the override\n")
cat("  4. Confirm the 5yr_horizon assumption rows are acceptable\n")
cat("  5. Run 00h_patch_missing_dates.R to apply confirmed values\n")
cat(sprintf("\nTotal cost this run: $%.4f USD\n", sum(review$cost_usd, na.rm = TRUE)))