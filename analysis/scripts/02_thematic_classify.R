# =============================================================================
# analysis/scripts/02_thematic_classify.R
# HospitalIntelligenceR — Thematic Classification of Strategic Directions
#
# PURPOSE:
#   Send each strategic direction row to the Claude API with a structured
#   classification prompt. Each direction is assigned a primary theme and
#   optional secondary theme from an 11-code taxonomy.
#
# RUN MODES:
#   "sample"  — classify a small random sample for review before full run
#   "facs"    — classify specific FACs only (set TARGET_FACS)
#   "all"     — classify all eligible direction rows
#
#   Set RUN_MODE before sourcing. Default is "sample".
#
# SAMPLE SIZE:
#   Set SAMPLE_N to control how many directions to classify in sample mode.
#   Default is 20 — enough to review taxonomy fit across diverse directions.
#
# OUTPUTS:
#   analysis/data/theme_classifications.csv          [full run — tracked in git]
#   analysis/data/theme_classifications_sample.csv   [sample runs — review only]
#
# USAGE:
#   # Sample run (default):
#   RUN_MODE <- "sample"
#   SAMPLE_N <- 20
#   source("analysis/scripts/02_thematic_classify.R")
#
#   # Specific FACs:
#   RUN_MODE <- "facs"
#   TARGET_FACS <- c("592", "644", "701")
#   source("analysis/scripts/02_thematic_classify.R")
#
#   # Full run (after sample review and taxonomy sign-off):
#   RUN_MODE <- "all"
#   source("analysis/scripts/02_thematic_classify.R")
#
# DEPENDENCIES:
#   core/claude_api.R — for API key and HTTP handling
#   analysis/scripts/theme_classify_prompt.txt — classification prompt
#   analysis/data/strategy_master_analytical.csv — or 'master' in environment
#
# COST NOTE:
#   Sample of 20 directions ≈ $0.02–0.05 USD
#   Full run of 543 directions ≈ $0.50–1.50 USD
#   Costs logged to analysis/data/theme_classify_api_log.csv
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(readr)
  library(jsonlite)
  library(httr2)
})


# =============================================================================
# SECTION 1: Configuration
# =============================================================================

if (!exists("RUN_MODE")) RUN_MODE <- "sample"
if (!exists("SAMPLE_N")) SAMPLE_N <- 20

valid_modes <- c("sample", "facs", "all")
if (!RUN_MODE %in% valid_modes) {
  stop(sprintf("Unknown RUN_MODE '%s'. Must be one of: %s",
               RUN_MODE, paste(valid_modes, collapse = ", ")))
}
if (RUN_MODE == "facs" && !exists("TARGET_FACS")) {
  stop("RUN_MODE is 'facs' but TARGET_FACS is not defined.")
}

CLASSIFY_CONFIG <- list(
  prompt_path      = "docs/prompts/theme_classify_prompt.txt",
  model            = "claude-sonnet-4-5",
  max_tokens       = 300,
  temperature      = 0,          # deterministic — classification is not creative
  output_full      = "analysis/data/theme_classifications.csv",
  output_sample    = "analysis/data/theme_classifications_sample.csv",
  api_log          = "analysis/data/theme_classify_api_log.csv",
  retry_max        = 3,
  retry_wait_sec   = 5
)

VALID_CODES <- c("WRK", "PAT", "ACC", "PAR", "FIN", "EDI",
                 "INN", "INF", "RES", "ORG")


# =============================================================================
# SECTION 2: Load data and prompt
# =============================================================================

if (!exists("master")) {
  message("'master' not found in environment — loading from CSV.")
  master <- read_csv(
    "analysis/data/strategy_master_analytical.csv",
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )
}

# Load API key via the project's core module pattern
api_key <- Sys.getenv("ANTHROPIC_API_KEY")
if (nchar(api_key) == 0) {
  stop("ANTHROPIC_API_KEY environment variable not set.")
}

# Load classification prompt
if (!file.exists(CLASSIFY_CONFIG$prompt_path)) {
  stop("Prompt file not found at: ", CLASSIFY_CONFIG$prompt_path)
}
system_prompt <- paste(readLines(CLASSIFY_CONFIG$prompt_path,
                                 encoding = "UTF-8"), collapse = "\n")

cat(sprintf("Prompt loaded: %d characters\n", nchar(system_prompt)))


# =============================================================================
# SECTION 3: Build eligible direction set
# =============================================================================

eligible <- master %>%
  filter(
    robots_allowed == TRUE,
    extraction_quality %in% c("full", "partial"),
    !is.na(direction_name)
  ) %>%
  # Add row identifier for tracking
  mutate(
    row_id = paste0(fac, "_", direction_number),
    # Determine which fields are available for this row
    has_description = !is.na(direction_description) & str_length(direction_description) > 5,
    has_actions     = !is.na(key_actions) & str_length(key_actions) > 5
  )

cat(sprintf("Eligible direction rows: %d across %d hospitals\n",
            nrow(eligible), n_distinct(eligible$fac)))


# =============================================================================
# SECTION 4: Apply run mode filter
# =============================================================================
if (RUN_MODE == "sample") {
  set.seed(42)
  per_group <- max(1, floor(SAMPLE_N / n_distinct(eligible$hospital_type_group)))
  target_rows <- eligible %>%
    group_by(hospital_type_group) %>%
    slice_sample(n = per_group) %>%
    ungroup() %>%
    slice_sample(n = SAMPLE_N)
  cat(sprintf("RUN_MODE=sample: %d directions selected\n", nrow(target_rows)))
  cat("Hospital types in sample:\n")
  print(table(target_rows$hospital_type_group))

} else if (RUN_MODE == "facs") {
  target_rows <- eligible %>% filter(fac %in% TARGET_FACS)
  cat(sprintf("RUN_MODE=facs: %d directions across FACs: %s\n",
              nrow(target_rows), paste(TARGET_FACS, collapse = ", ")))
  
} else {
  target_rows <- eligible
  cat(sprintf("RUN_MODE=all: %d directions to classify\n", nrow(target_rows)))
}

# =============================================================================
# SECTION 5: API call function
# =============================================================================

.classify_direction <- function(row, system_prompt, api_key, config) {

  # Build user message — JSON input to Claude
  input_fields <- list(
    direction_name        = row$direction_name,
    direction_description = if (row$has_description) row$direction_description else NULL,
    key_actions           = if (row$has_actions) row$key_actions else NULL,
    hospital_type         = row$hospital_type
  )
  
  # Sanitise input fields — remove control characters that break JSON
  .clean_text <- function(x) {
    if (is.null(x) || is.na(x)) return(NULL)
    str_replace_all(as.character(x), "[\\x00-\\x1F\\x7F]", " ")
  }
  
  input_fields <- list(
    direction_name        = .clean_text(row$direction_name),
    direction_description = if (row$has_description) .clean_text(row$direction_description) else NULL,
    key_actions           = if (row$has_actions) .clean_text(row$key_actions) else NULL,
    hospital_type         = .clean_text(row$hospital_type)
  )
  
  user_message <- toJSON(input_fields, auto_unbox = TRUE, null = "null") 


  # Attempt API call with retries
  result <- NULL
  last_error <- NULL

  for (attempt in seq_len(config$retry_max)) {
    tryCatch({
      resp <- request("https://api.anthropic.com/v1/messages") %>%
        req_headers(
          "x-api-key"         = api_key,
          "anthropic-version" = "2023-06-01",
          "content-type"      = "application/json"
        ) %>%
        req_body_json(list(
          model      = config$model,
          max_tokens = config$max_tokens,
          temperature = config$temperature,
          system     = system_prompt,
          messages   = list(list(role = "user", content = user_message))
        )) %>%
        req_perform()

      resp_body <- resp_body_json(resp)
      
      raw_text   <- resp_body$content[[1]]$text
     # cat(sprintf("\nDEBUG raw_text: %s\n", str_trunc(raw_text, 200)))
      
      # Strip markdown code fences — Claude wraps JSON in ```json ... ```
      clean_text <- gsub("^```json\\s*", "", raw_text)
      clean_text <- gsub("^```\\s*",     "", clean_text)
      clean_text <- gsub("\\s*```$",     "", clean_text)
      clean_text <- trimws(clean_text)
      
      # Parse JSON response
      parsed <- fromJSON(clean_text, simplifyVector = TRUE)

      result <- list(
        success        = TRUE,
        raw_text       = raw_text,
        parsed         = parsed,
        input_tokens   = resp_body$usage$input_tokens,
        output_tokens  = resp_body$usage$output_tokens,
        attempts       = attempt
      )
      break  # success — exit retry loop

    }, error = function(e) {
      last_error <<- conditionMessage(e)
      if (attempt < config$retry_max) Sys.sleep(config$retry_wait_sec)
    })
  }

  if (is.null(result)) {
    result <- list(
      success  = FALSE,
      raw_text = NA_character_,
      parsed   = NULL,
      error    = last_error,
      attempts = config$retry_max
    )
  }

  result
}


# =============================================================================
# SECTION 6: Validate parsed response
# =============================================================================

.validate_response <- function(parsed, valid_codes) {
  issues <- c()

  if (is.null(parsed$primary_theme) || !parsed$primary_theme %in% valid_codes) {
    issues <- c(issues, sprintf("invalid primary_theme: '%s'", parsed$primary_theme))
  }
  if (!is.null(parsed$secondary_theme) &&
      !is.na(parsed$secondary_theme) &&
      parsed$secondary_theme != "null" &&
      !parsed$secondary_theme %in% valid_codes) {
    issues <- c(issues, sprintf("invalid secondary_theme: '%s'", parsed$secondary_theme))
  }
  if (!parsed$classification_confidence %in% c("high", "medium", "low")) {
    issues <- c(issues, "invalid confidence value")
  }

  list(valid = length(issues) == 0, issues = issues)
}


# =============================================================================
# SECTION 7: Main classification loop
# =============================================================================

cat(sprintf("\nClassifying %d directions...\n", nrow(target_rows)))
cat(paste(rep("-", 50), collapse = ""), "\n")

results      <- vector("list", nrow(target_rows))
api_log_rows <- vector("list", nrow(target_rows))

for (i in seq_len(nrow(target_rows))) {
  row <- target_rows[i, ]

  cat(sprintf("[%d/%d] FAC %s — %s ... ",
              i, nrow(target_rows), row$fac,
              str_trunc(row$direction_name, 45)))

  api_result <- .classify_direction(row, system_prompt, api_key, CLASSIFY_CONFIG)

  if (!api_result$success) {
    cat(sprintf("FAILED: %s\n", str_trunc(api_result$error, 60)))
    results[[i]] <- tibble(
      row_id                 = row$row_id,
      fac                    = row$fac,
      direction_number       = row$direction_number,
      direction_name         = row$direction_name,
      primary_theme          = NA_character_,
      secondary_theme        = NA_character_,
      classification_confidence = NA_character_,
      classified_on          = NA_character_,
      classification_notes   = paste("API error:", api_result$error),
      classification_status  = "failed"
    )
  } else {
    parsed   <- api_result$parsed
    validity <- .validate_response(parsed, VALID_CODES)

    if (!validity$valid) {
      cat(sprintf("INVALID RESPONSE: %s\n", paste(validity$issues, collapse = "; ")))
      status <- "invalid"
    } else {
      cat(sprintf("OK [%s/%s] conf=%s\n",
                  parsed$primary_theme,
                  if (!is.null(parsed$secondary_theme) &&
                      !is.na(parsed$secondary_theme) &&
                      parsed$secondary_theme != "null")
                    parsed$secondary_theme else "—",
                  parsed$classification_confidence))
      status <- "ok"
    }

    # Clean secondary_theme — normalise null/NA/"null" to NA
    sec_theme <- parsed$secondary_theme
    if (is.null(sec_theme) || is.na(sec_theme) || sec_theme == "null") {
      sec_theme <- NA_character_
    }

    results[[i]] <- tibble(
      row_id                    = row$row_id,
      fac                       = row$fac,
      direction_number          = row$direction_number,
      direction_name            = row$direction_name,
      primary_theme             = as.character(parsed$primary_theme %||% NA),
      secondary_theme           = as.character(sec_theme),
      classification_confidence = as.character(parsed$classification_confidence %||% NA),
      classified_on             = as.character(parsed$classified_on %||% NA),
      classification_notes      = as.character(parsed$classification_notes %||% NA),
      classification_status     = status
    )
  }

  # API log row
  api_log_rows[[i]] <- tibble(
    timestamp     = as.character(Sys.time()),
    row_id        = row$row_id,
    fac           = row$fac,
    run_mode      = RUN_MODE,
    success       = api_result$success,
    input_tokens  = if (api_result$success) api_result$input_tokens  else NA_integer_,
    output_tokens = if (api_result$success) api_result$output_tokens else NA_integer_,
    cost_usd      = if (api_result$success)
      round((api_result$input_tokens  / 1e6 * 3.00) +
            (api_result$output_tokens / 1e6 * 15.00), 5) else NA_real_,
    attempts      = api_result$attempts
  )

  # Polite pause between calls
  if (i < nrow(target_rows)) Sys.sleep(0.3)
}


# =============================================================================
# SECTION 8: Assemble and write outputs
# =============================================================================

classifications <- bind_rows(results)
api_log         <- bind_rows(api_log_rows)

# Choose output path based on run mode
out_path <- if (RUN_MODE == "all" || RUN_MODE == "facs") {
  CLASSIFY_CONFIG$output_full
} else {
  CLASSIFY_CONFIG$output_sample
}

dir.create("analysis/data", recursive = TRUE, showWarnings = FALSE)

if (RUN_MODE == "facs" && file.exists(out_path)) {
  existing <- read_csv(out_path, col_types = cols(.default = col_character()),
                       show_col_types = FALSE)
  merged <- existing %>%
    filter(!fac %in% TARGET_FACS) %>%
    bind_rows(classifications)
  write_csv(merged, out_path)
  cat(sprintf("Merged: %d existing rows retained, %d rows updated/added\n",
              nrow(existing) - sum(existing$fac %in% TARGET_FACS),
              nrow(classifications)))
} else {
  write_csv(classifications, out_path)
}
write_csv(api_log, CLASSIFY_CONFIG$api_log, append = file.exists(CLASSIFY_CONFIG$api_log))

cat(paste(rep("-", 50), collapse = ""), "\n")
cat(sprintf("Written: %s\n", out_path))


# =============================================================================
# SECTION 9: Run summary
# =============================================================================

n_ok      <- sum(classifications$classification_status == "ok")
n_invalid <- sum(classifications$classification_status == "invalid")
n_failed  <- sum(classifications$classification_status == "failed")
total_cost <- sum(api_log$cost_usd, na.rm = TRUE)

cat("\n========== CLASSIFICATION RUN SUMMARY ==========\n")
cat(sprintf("  Run mode:          %s\n", RUN_MODE))
cat(sprintf("  Directions sent:   %d\n", nrow(target_rows)))
cat(sprintf("  Successful:        %d\n", n_ok))
cat(sprintf("  Invalid response:  %d\n", n_invalid))
cat(sprintf("  Failed (API):      %d\n", n_failed))
cat(sprintf("  Estimated cost:    $%.4f USD\n", total_cost))

if (n_ok > 0) {
  cat("\n  Primary theme distribution:\n")
  classifications %>%
    filter(classification_status == "ok") %>%
    count(primary_theme) %>%
    arrange(desc(n)) %>%
    { cat(paste0("    ", .$primary_theme, ": ", .$n, "\n")); . } %>%
    invisible()

  cat("\n  Confidence distribution:\n")
  classifications %>%
    filter(classification_status == "ok") %>%
    count(classification_confidence) %>%
    { cat(paste0("    ", .$classification_confidence, ": ", .$n, "\n")); . } %>%
    invisible()

  low_conf <- classifications %>%
    filter(classification_confidence == "low", classification_status == "ok")
  if (nrow(low_conf) > 0) {
    cat(sprintf("\n  Low-confidence directions flagged for review (%d):\n",
                nrow(low_conf)))
    for (i in seq_len(nrow(low_conf))) {
      cat(sprintf("    FAC %s: '%s' [%s/%s] — %s\n",
                  low_conf$fac[i],
                  str_trunc(low_conf$direction_name[i], 40),
                  low_conf$primary_theme[i],
                  coalesce(low_conf$secondary_theme[i], "—"),
                  str_trunc(coalesce(low_conf$classification_notes[i], ""), 50)))
    }
  }
}

cat("=================================================\n")
cat(sprintf("\nReview output: %s\n", out_path))
if (RUN_MODE != "all") {
  cat("When satisfied with sample quality, re-run with RUN_MODE <- 'all'\n")
}

# Make classifications available in environment
classifications <<- classifications
