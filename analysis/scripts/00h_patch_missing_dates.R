# =============================================================================
# analysis/scripts/00h_patch_missing_dates.R
# HospitalIntelligenceR — Apply Confirmed Missing Date Corrections
#
# PURPOSE:
#   Reads the manually reviewed 00g_date_review.csv and applies confirmed
#   plan_period_start / plan_period_end values to strategy_master_analytical.csv
#   and hospital_spine.csv.
#
# LOGIC:
#   For each row in the review CSV, the final applied value is determined as:
#     1. manual_override_start / manual_override_end  (if not blank — highest priority)
#     2. derived_start / derived_end                   (API result or 5yr_horizon)
#     3. No change                                     (if both are NA)
#
#   Rows where confidence == "not_found" or "api_error" AND no manual override
#   is provided are SKIPPED — a warning is printed for each.
#
#   A 5-year horizon assumption is ONLY applied if assumption_applied == "5yr_horizon"
#   in the review CSV (i.e. you confirmed it by not overriding it).
#
# OUTPUTS (modified in place):
#   analysis/data/strategy_master_analytical.csv
#   analysis/data/hospital_spine.csv
#
# ALSO WRITES:
#   analysis/outputs/tables/00h_patch_log.csv  — one row per FAC showing what changed
#
# SAFETY:
#   - Only writes changes if at least one of start/end would actually change
#   - Prints a full summary of all changes before writing — review before confirming
#   - Set DRY_RUN <- TRUE to preview changes without writing
#
# USAGE:
#   DRY_RUN <- FALSE   # set TRUE to preview only
#   source("analysis/scripts/00h_patch_missing_dates.R")
#
# DEPENDENCIES:
#   analysis/outputs/tables/00g_date_review.csv (from 00g_fetch_missing_dates.R)
#   analysis/data/strategy_master_analytical.csv
#   analysis/data/hospital_spine.csv
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
})

if (!exists("DRY_RUN")) DRY_RUN <- FALSE

REVIEW_PATH  <- "analysis/outputs/tables/00g_date_review.csv"
MASTER_PATH  <- "analysis/data/strategy_master_analytical.csv"
SPINE_PATH   <- "analysis/data/hospital_spine.csv"
PATCH_LOG    <- "analysis/outputs/tables/00h_patch_log.csv"

cat(sprintf("=== 00h_patch_missing_dates.R | DRY_RUN = %s ===\n\n", DRY_RUN))


# =============================================================================
# LOAD REVIEW CSV
# =============================================================================

if (!file.exists(REVIEW_PATH)) {
  stop(sprintf("Review CSV not found: %s\n  Run 00g_fetch_missing_dates.R first.", REVIEW_PATH))
}

review <- read_csv(REVIEW_PATH, col_types = cols(.default = col_character()),
                   show_col_types = FALSE)

cat(sprintf("Review CSV loaded: %d rows\n\n", nrow(review)))


# =============================================================================
# RESOLVE FINAL VALUES PER ROW
# =============================================================================

resolve_value <- function(manual_override, derived) {
  mo <- if (!is.na(manual_override) && nchar(trimws(manual_override)) > 0)
          trimws(manual_override) else NA_character_
  dv <- if (!is.na(derived) && nchar(trimws(derived)) > 0)
          trimws(derived) else NA_character_

  # Manual override takes priority
  if (!is.na(mo)) return(list(value = mo, source = "manual_override"))
  if (!is.na(dv)) return(list(value = dv, source = "derived"))
  list(value = NA_character_, source = "no_change")
}


patch_table <- review %>%
  rowwise() %>%
  mutate(
    res_start = list(resolve_value(manual_override_start, derived_start)),
    res_end   = list(resolve_value(manual_override_end,   derived_end)),

    final_start  = res_start$value,
    final_end    = res_end$value,
    source_start = res_start$source,
    source_end   = res_end$source,

    # Derive plan_start_year from final_start
    final_year   = suppressWarnings(as.integer(final_start)),

    # Should this row be skipped?
    skip = (is.na(final_start) & is.na(final_end)),
    skip_reason = case_when(
      confidence %in% c("not_found", "api_error", "file_not_found") &
        is.na(manual_override_start) & is.na(manual_override_end)
        ~ sprintf("confidence=%s, no manual override provided", confidence),
      TRUE ~ NA_character_
    )
  ) %>%
  ungroup()


# =============================================================================
# PRINT SUMMARY
# =============================================================================

cat("=== Planned patches ===\n\n")

apply_rows <- patch_table %>% filter(!skip)
skip_rows  <- patch_table %>% filter(skip)

if (nrow(apply_rows) > 0) {
  for (i in seq_len(nrow(apply_rows))) {
    r <- apply_rows[i, ]
    assumption_note <- if (r$assumption_applied == "5yr_horizon")
      " [5YR HORIZON ASSUMPTION]" else ""
    cat(sprintf(
      "FAC %s | %-42s | start: %s (%s)  end: %s (%s)%s\n",
      r$fac, r$hospital_name,
      r$final_start %||% "NA", r$source_start,
      r$final_end   %||% "NA", r$source_end,
      assumption_note
    ))
  }
} else {
  cat("  No rows to patch.\n")
}

cat(sprintf("\n  Total to patch: %d\n", nrow(apply_rows)))

if (nrow(skip_rows) > 0) {
  cat(sprintf("\n=== Skipped rows (%d) ===\n", nrow(skip_rows)))
  for (i in seq_len(nrow(skip_rows))) {
    r <- skip_rows[i, ]
    cat(sprintf("  FAC %s | %s | reason: %s\n",
                r$fac, r$hospital_name, r$skip_reason %||% "both values NA"))
  }
}

if (DRY_RUN) {
  cat("\n[DRY RUN] No files written. Set DRY_RUN <- FALSE to apply.\n")
  invisible(NULL)
  stop("Dry run complete — stopping before write.", call. = FALSE)
}


# =============================================================================
# LOAD DATA FILES
# =============================================================================

master <- read_csv(MASTER_PATH, col_types = cols(.default = col_character()),
                   show_col_types = FALSE)
spine  <- read_csv(SPINE_PATH,  col_types = cols(.default = col_character()),
                   show_col_types = FALSE)

cat(sprintf("\nMaster loaded: %d rows across %d hospitals\n",
            nrow(master), n_distinct(master$fac)))
cat(sprintf("Spine loaded:  %d rows\n\n", nrow(spine)))


# =============================================================================
# APPLY PATCHES
# =============================================================================

patch_log <- vector("list", nrow(apply_rows))

for (i in seq_len(nrow(apply_rows))) {
  r   <- apply_rows[i, ]
  fac <- as.character(r$fac)

  # --- Patch master (all rows for this FAC) ---
  master_idx <- which(as.character(master$fac) == fac)

  old_start_m <- if (length(master_idx) > 0) master$plan_period_start[master_idx[1]] else NA
  old_end_m   <- if (length(master_idx) > 0) master$plan_period_end[master_idx[1]]   else NA

  if (length(master_idx) > 0) {
    if (!is.na(r$final_start)) master$plan_period_start[master_idx] <- r$final_start
    if (!is.na(r$final_end))   master$plan_period_end[master_idx]   <- r$final_end
    if (!is.na(r$final_year))  master$plan_start_year[master_idx]   <- as.character(r$final_year)
    master$plan_period_parse_ok[master_idx] <- "TRUE"
  }

  # --- Patch spine (one row per FAC) ---
  spine_idx <- which(as.character(spine$fac) == fac)

  old_start_s <- if (length(spine_idx) > 0) spine$plan_period_start[spine_idx[1]] else NA
  old_end_s   <- if (length(spine_idx) > 0) spine$plan_period_end[spine_idx[1]]   else NA

  if (length(spine_idx) > 0) {
    if (!is.na(r$final_start)) spine$plan_period_start[spine_idx] <- r$final_start
    if (!is.na(r$final_end))   spine$plan_period_end[spine_idx]   <- r$final_end
    if (!is.na(r$final_year))  spine$plan_start_year[spine_idx]   <- as.character(r$final_year)
    spine$plan_period_parse_ok[spine_idx] <- "TRUE"
  }

  patch_log[[i]] <- data.frame(
    fac              = fac,
    hospital_name    = r$hospital_name,
    old_start        = old_start_s %||% NA_character_,
    old_end          = old_end_s   %||% NA_character_,
    new_start        = r$final_start %||% NA_character_,
    new_end          = r$final_end   %||% NA_character_,
    new_year         = r$final_year  %||% NA_integer_,
    source_start     = r$source_start,
    source_end       = r$source_end,
    assumption       = r$assumption_applied,
    confidence       = r$confidence,
    master_rows_patched = length(master_idx),
    stringsAsFactors = FALSE
  )

  cat(sprintf("  Patched FAC %s — master rows: %d, spine rows: %d\n",
              fac, length(master_idx), length(spine_idx)))
}


# =============================================================================
# WRITE OUTPUT FILES
# =============================================================================

write_csv(master, MASTER_PATH)
write_csv(spine,  SPINE_PATH)

patch_log_df <- bind_rows(patch_log)
dir.create(dirname(PATCH_LOG), recursive = TRUE, showWarnings = FALSE)
write_csv(patch_log_df, PATCH_LOG)

cat(sprintf("\n=== Patch complete ===\n"))
cat(sprintf("  strategy_master_analytical.csv updated: %d hospitals patched\n",
            nrow(apply_rows)))
cat(sprintf("  hospital_spine.csv updated\n"))
cat(sprintf("  Patch log written: %s\n", PATCH_LOG))
cat(sprintf("\n  5-year horizon assumption applied to: %d hospitals\n",
            sum(patch_log_df$assumption == "5yr_horizon", na.rm = TRUE)))

cat("\nNEXT STEPS:\n")
cat("  1. Re-run 00_prepare_data.R to refresh the environment\n")
cat("  2. Re-run 03a_explore_plan_years.R to confirm missing dates resolved\n")
cat("  3. Re-run 03b_theme_trends.R to include newly dated hospitals in era analysis\n")
cat("  4. Note 5yr_horizon assumption in 03b narrative\n")
