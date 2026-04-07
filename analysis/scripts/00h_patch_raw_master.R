# =============================================================================
# analysis/scripts/00h_patch_raw_master.R
# ONE-TIME SCRIPT — patches plan_period_start / plan_period_end into
# strategy_master.csv so that 00_prepare_data.R picks up the corrected dates.
#
# Background: 00h_patch_missing_dates.R wrote to strategy_master_analytical.csv
# and hospital_spine.csv, but 00_prepare_data.R rebuilds both from the upstream
# strategy_master.csv. This script applies the same date corrections to that
# upstream file so the full pipeline is consistent.
#
# Run once, then re-run 00_prepare_data.R → 03a → 03b.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

REVIEW_PATH  <- "analysis/outputs/tables/00g_date_review.csv"
RAW_MASTER   <- "roles/strategy/outputs/extractions/strategy_master.csv"

# Load review CSV — same source of truth as 00h
review <- read_csv(REVIEW_PATH, col_types = cols(.default = col_character()),
                   show_col_types = FALSE)

# Resolve final value per row (manual override > derived)
resolve <- function(mo, dv) {
  mo <- if (!is.na(mo) && nchar(trimws(mo)) > 0) trimws(mo) else NA_character_
  dv <- if (!is.na(dv) && nchar(trimws(dv)) > 0) trimws(dv) else NA_character_
  if (!is.na(mo)) mo else dv
}

corrections <- review %>%
  rowwise() %>%
  mutate(
    final_start = resolve(manual_override_start, derived_start),
    final_end   = resolve(manual_override_end,   derived_end)
  ) %>%
  ungroup() %>%
  filter(!is.na(final_start) | !is.na(final_end)) %>%
  select(fac, final_start, final_end)

cat(sprintf("Corrections to apply: %d FACs\n", nrow(corrections)))

# Load raw master
master_raw <- read_csv(RAW_MASTER, col_types = cols(.default = col_character()),
                       show_col_types = FALSE)
cat(sprintf("Raw master loaded: %d rows\n", nrow(master_raw)))

# Apply corrections
for (i in seq_len(nrow(corrections))) {
  fac   <- as.character(corrections$fac[i])
  start <- corrections$final_start[i]
  end   <- corrections$final_end[i]
  
  idx <- which(as.character(master_raw$fac) == fac)
  if (length(idx) == 0) {
    cat(sprintf("  WARNING: FAC %s not found in raw master\n", fac))
    next
  }
  if (!is.na(start)) master_raw$plan_period_start[idx] <- start
  if (!is.na(end))   master_raw$plan_period_end[idx]   <- end
  cat(sprintf("  FAC %s: start=%s end=%s (%d rows)\n", fac, start, end, length(idx)))
}

write_csv(master_raw, RAW_MASTER)
cat(sprintf("\nDone. Raw master written: %s\n", RAW_MASTER))
cat("Now run: source('analysis/scripts/00_prepare_data.R')\n")
cat("Then:    source('analysis/scripts/03a_explore_plan_years.R')\n")
cat("Then:    source('analysis/scripts/03b_theme_trends.R')\n")