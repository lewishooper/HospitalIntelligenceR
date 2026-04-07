# =============================================================================
# analysis/scripts/00f_patch_plan_dates.R
# HospitalIntelligenceR — Manual Correction: Plan Period Dates
#
# PURPOSE:
#   Apply confirmed corrections to plan_period_start / plan_period_end in
#   strategy_master_analytical.csv and hospital_spine.csv.
#
#   Corrections are applied to the ANALYTICAL outputs (not to strategy_master.csv,
#   which is the raw Phase 2 output). The analytical layer is the correct place
#   to apply these fixes because:
#     - Re-running Phase 2 for date-only corrections is expensive
#     - The raw extraction is preserved for audit purposes
#     - This pattern matches 00d_patch_gov_corrections.R
#
# CORRECTIONS APPLIED:
#
#   FAC 953 — Sunnybrook Health Sciences Centre ("Invent 2030")
#     plan_period_start: "2030" → "2025"
#     Reason: API returned the end year (2030) as the start year.
#             Plan published 2025; "Invent 2030" names the horizon only.
#
#   FAC 682 — Hornepayne Community Hospital
#     plan_period_start: nulled out
#     plan_period_end:   nulled out
#     Reason: No strategic plan available. Downloaded document was unrelated
#             to strategy. Email outreach attempted with follow-up — no response.
#
# CORRECTION TABLE LOGIC:
#   - If new_start_raw and new_end_raw are both NA  → null out ALL date fields
#   - If new_start_raw is a value                   → overwrite start fields only
#   - If new_end_raw is a value                     → overwrite end fields only
#
# USAGE:
#   Run after 00_prepare_data.R. Safe to re-run — idempotent.
#   After running, re-run 00c, 03a, 03b to rebuild downstream outputs.
#
# OUTPUT:
#   Overwrites analysis/data/strategy_master_analytical.csv in place.
#   Overwrites analysis/data/hospital_spine.csv in place.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lubridate)
})

PATH_MASTER <- "analysis/data/strategy_master_analytical.csv"
PATH_SPINE  <- "analysis/data/hospital_spine.csv"

cat("=============================================================================\n")
cat("  00f_patch_plan_dates.R — Plan Period Date Corrections\n")
cat(sprintf("  Run date: %s\n", Sys.Date()))
cat("=============================================================================\n\n")


# =============================================================================
# SECTION 1: Load files
# =============================================================================

master <- read_csv(
  PATH_MASTER,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)
cat(sprintf("Loaded master: %d rows from %s\n", nrow(master), PATH_MASTER))

spine <- read_csv(
  PATH_SPINE,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)
cat(sprintf("Loaded spine:  %d rows from %s\n\n", nrow(spine), PATH_SPINE))


# =============================================================================
# SECTION 2: Corrections table
#
# new_start_raw / new_end_raw:
#   - Character value (e.g. "2025") → overwrite that field
#   - NA                            → leave unchanged (unless both are NA)
#   - Both NA                       → null out ALL date fields for that FAC
# =============================================================================

corrections <- tibble(
  fac = c(
    "953",
    "682"
  ),
  new_start_raw = c(
    "2025",        # FAC 953: correct start year
    NA_character_  # FAC 682: null out (both NA = full null-out)
  ),
  new_end_raw = c(
    NA_character_, # FAC 953: end (2030) is correct — leave unchanged
    NA_character_  # FAC 682: null out (both NA = full null-out)
  ),
  correction_note = c(
    "API returned end year (2030) as start year. Correct start is 2025 — plan published 2025, horizon is 2030 (Invent 2030).",
    "No strategic plan available. Captured document unrelated to strategy. Email outreach attempted with follow-up — no response. All dates nulled out."
  )
)

cat(sprintf("Corrections to apply: %d\n\n", nrow(corrections)))


# =============================================================================
# SECTION 3: Helper — parse raw string to Date
# =============================================================================

.raw_to_date <- function(raw_str) {
  if (is.na(raw_str)) return(as.Date(NA))
  d <- suppressWarnings(as.Date(raw_str, format = "%Y-%m-%d"))
  if (!is.na(d)) return(d)
  d <- suppressWarnings(as.Date(raw_str, format = "%Y%m%d"))
  if (!is.na(d)) return(d)
  if (grepl("^\\d{4}$", raw_str)) return(as.Date(paste0(raw_str, "-01-01")))
  return(as.Date(NA))
}


# =============================================================================
# SECTION 4: Helper — preview current date state for a FAC
# =============================================================================

.preview_fac <- function(df, fac_val, label) {
  has_raw <- "plan_period_start_raw" %in% names(df)
  cols <- c("fac", "plan_period_start", "plan_period_end")
  if (has_raw) cols <- c(cols, "plan_period_start_raw", "plan_period_end_raw")
  rows <- df %>% filter(fac == fac_val) %>% select(all_of(cols)) %>% distinct()
  if (nrow(rows) == 0) {
    cat(sprintf("  [%s] FAC %s: not found\n", label, fac_val))
    return(invisible(NULL))
  }
  r <- rows[1, ]
  start_raw <- if (has_raw) as.character(r$plan_period_start_raw) else "—"
  end_raw   <- if (has_raw) as.character(r$plan_period_end_raw)   else "—"
  cat(sprintf("  [%s] FAC %s: start='%s' (raw='%s')  end='%s' (raw='%s')\n",
              label, fac_val,
              r$plan_period_start, start_raw,
              r$plan_period_end,   end_raw))
}


# =============================================================================
# SECTION 5: Preview before state
# =============================================================================

cat("-- Before state --\n")
for (fac_target in corrections$fac) {
  .preview_fac(master, fac_target, "MASTER before")
  .preview_fac(spine,  fac_target, "SPINE  before")
}
cat("\n")


# =============================================================================
# SECTION 6: Apply corrections to master
# =============================================================================

cat("-- Applying corrections to master --\n")

for (i in seq_len(nrow(corrections))) {
  fac_target <- corrections$fac[i]
  note       <- corrections$correction_note[i]
  idx        <- which(master$fac == fac_target)
  
  if (length(idx) == 0) {
    cat(sprintf("  WARNING: FAC %s not found in master — skipping.\n", fac_target))
    next
  }
  
  null_start <- is.na(corrections$new_start_raw[i])
  null_end   <- is.na(corrections$new_end_raw[i])
  
  if (null_start && null_end) {
    # Both NA — null out all date fields
    master$plan_period_start_raw[idx] <- NA_character_
    master$plan_period_start[idx]     <- NA_character_
    master$plan_start_year[idx]       <- NA_character_
    master$plan_period_parse_ok[idx]  <- "FALSE"
    master$plan_period_end_raw[idx]   <- NA_character_
    master$plan_period_end[idx]       <- NA_character_
    cat(sprintf("  FAC %s master: all date fields nulled out\n", fac_target))
  } else {
    # Selective update
    if (!null_start) {
      old_raw  <- master$plan_period_start_raw[idx[1]]
      new_raw  <- corrections$new_start_raw[i]
      new_date <- as.character(.raw_to_date(new_raw))
      new_year <- as.character(year(.raw_to_date(new_raw)))
      master$plan_period_start_raw[idx] <- new_raw
      master$plan_period_start[idx]     <- new_date
      master$plan_start_year[idx]       <- new_year
      master$plan_period_parse_ok[idx]  <- "TRUE"
      cat(sprintf("  FAC %s start: '%s' → '%s' (parsed: %s, year: %s)\n",
                  fac_target, old_raw, new_raw, new_date, new_year))
    }
    if (!null_end) {
      old_raw  <- master$plan_period_end_raw[idx[1]]
      new_raw  <- corrections$new_end_raw[i]
      new_date <- as.character(.raw_to_date(new_raw))
      master$plan_period_end_raw[idx] <- new_raw
      master$plan_period_end[idx]     <- new_date
      cat(sprintf("  FAC %s end:   '%s' → '%s' (parsed: %s)\n",
                  fac_target, old_raw, new_raw, new_date))
    }
  }
  cat(sprintf("  Note: %s\n", note))
}
cat("\n")


# =============================================================================
# SECTION 7: Apply corrections to spine
# =============================================================================

cat("-- Applying corrections to spine --\n")

# Spine was built without _raw columns — add as NA vectors if absent
if (!"plan_period_start_raw" %in% names(spine)) {
  spine$plan_period_start_raw <- NA_character_
}
if (!"plan_period_end_raw" %in% names(spine)) {
  spine$plan_period_end_raw <- NA_character_
}

for (i in seq_len(nrow(corrections))) {
  fac_target <- corrections$fac[i]
  idx        <- which(spine$fac == fac_target)
  
  if (length(idx) == 0) {
    cat(sprintf("  WARNING: FAC %s not found in spine — skipping.\n", fac_target))
    next
  }
  
  null_start <- is.na(corrections$new_start_raw[i])
  null_end   <- is.na(corrections$new_end_raw[i])
  
  if (null_start && null_end) {
    spine[idx, "plan_period_start_raw"] <- NA_character_
    spine[idx, "plan_period_start"]     <- NA_character_
    spine[idx, "plan_start_year"]       <- NA_character_
    spine[idx, "plan_period_parse_ok"]  <- "FALSE"
    spine[idx, "plan_period_end_raw"]   <- NA_character_
    spine[idx, "plan_period_end"]       <- NA_character_
    cat(sprintf("  FAC %s spine: all date fields nulled out\n", fac_target))
  } else {
    if (!null_start) {
      new_raw  <- corrections$new_start_raw[i]
      new_date <- as.character(.raw_to_date(new_raw))
      new_year <- as.character(year(.raw_to_date(new_raw)))
      spine[idx, "plan_period_start_raw"] <- new_raw
      spine[idx, "plan_period_start"]     <- new_date
      spine[idx, "plan_start_year"]       <- new_year
      spine[idx, "plan_period_parse_ok"]  <- "TRUE"
      cat(sprintf("  FAC %s spine start updated → '%s'\n", fac_target, new_raw))
    }
    if (!null_end) {
      new_raw  <- corrections$new_end_raw[i]
      new_date <- as.character(.raw_to_date(new_raw))
      spine[idx, "plan_period_end_raw"] <- new_raw
      spine[idx, "plan_period_end"]     <- new_date
      cat(sprintf("  FAC %s spine end updated → '%s'\n", fac_target, new_raw))
    }
  }
}
cat("\n")


# =============================================================================
# SECTION 8: Verify — after state
# =============================================================================

cat("-- After state --\n")
for (fac_target in corrections$fac) {
  .preview_fac(master, fac_target, "MASTER after")
  .preview_fac(spine,  fac_target, "SPINE  after")
}
cat("\n")


# =============================================================================
# SECTION 9: Write corrected files
# =============================================================================

write_csv(master, PATH_MASTER)
cat(sprintf("Written: %s (%d rows)\n", PATH_MASTER, nrow(master)))

write_csv(spine, PATH_SPINE)
cat(sprintf("Written: %s (%d rows)\n", PATH_SPINE, nrow(spine)))

cat("\n-- Done. Re-run 00_prepare_data.R is NOT needed. Re-run 00c, 03a, 03b. --\n")