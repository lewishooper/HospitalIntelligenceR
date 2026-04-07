# =============================================================================
# analysis/scripts/00e_audit_plan_dates.R
# HospitalIntelligenceR — Audit: Plan Period Date Plausibility
#
# PURPOSE:
#   Read-only audit of plan_period_start and plan_period_end values across
#   all hospitals. Flags rows that are implausible, inconsistent, or likely
#   the result of API hallucination (e.g. end date returned as start).
#
# FLAGS CHECKED:
#   0. Known correction — FAC 953 (start recorded as 2030, should be 2025)
#   1. Start year before 2015 (too old for a current active plan)
#   2. Start year after current year (future start — plausible but rare)
#   3. Start year equals end year (zero-length plan)
#   4. Start year after end year (start > end — impossible)
#   5. Plan span > 7 years (unusually long; most plans are 3–5 years)
#   6. End year before 2020 (plan has expired — may be wrong document)
#   7. Precise full dates (YYYY-MM-DD) — flag for human verification since
#      exact dates are rarely stated in strategic plans
#
# DATA SOURCES:
#   - hospital_spine.csv             : one row per hospital, parsed dates
#   - strategy_master_analytical.csv : direction-level; carries _raw string columns
#   Raw strings are joined from master onto spine for display.
#
# USAGE:
#   Run after 00_prepare_data.R. Uses environment objects (spine, master)
#   if already loaded, otherwise reads from disk.
#   Read-only — no pipeline files are modified.
#
# OUTPUT:
#   Console report + analysis/outputs/tables/00e_flagged_dates.csv
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lubridate)
})

CURRENT_YEAR  <- as.integer(format(Sys.Date(), "%Y"))
MIN_PLAUSIBLE <- 2015L
MAX_SPAN_YRS  <- 11L
MIN_END_YEAR  <- 2020L

SPINE_PATH  <- "analysis/data/hospital_spine.csv"
MASTER_PATH <- "analysis/data/strategy_master_analytical.csv"

cat("=============================================================================\n")
cat("  00e_audit_plan_dates.R — Plan Period Date Plausibility Audit\n")
cat(sprintf("  Run date: %s | Current year threshold: %d\n", Sys.Date(), CURRENT_YEAR))
cat("=============================================================================\n\n")


# =============================================================================
# SECTION 1: Load spine and master
# =============================================================================

# --- Spine ---
if (exists("spine") && is.data.frame(spine)) {
  cat("Using 'spine' object from environment.\n")
  audit_spine <- spine
} else if (file.exists(SPINE_PATH)) {
  cat(sprintf("Loading spine from disk: %s\n", SPINE_PATH))
  audit_spine <- read_csv(
    SPINE_PATH,
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  ) %>%
    mutate(
      plan_period_start = as.Date(plan_period_start),
      plan_period_end   = as.Date(plan_period_end),
      plan_start_year   = suppressWarnings(as.integer(plan_start_year))
    )
} else {
  stop("No spine found. Run 00_prepare_data.R first.")
}

# --- Master (for raw string columns — plan_period_start_raw / _end_raw) ---
if (exists("master") && is.data.frame(master)) {
  cat("Using 'master' object from environment.\n")
  audit_master <- master
} else if (file.exists(MASTER_PATH)) {
  cat(sprintf("Loading master from disk: %s\n", MASTER_PATH))
  audit_master <- read_csv(
    MASTER_PATH,
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )
} else {
  stop("No master found. Run 00_prepare_data.R first.")
}

cat("\n")

# Build per-FAC raw string lookup and join onto spine
raw_lookup <- audit_master %>%
  distinct(fac, plan_period_start_raw, plan_period_end_raw)

audit_base <- audit_spine %>%
  left_join(raw_lookup, by = "fac")

has_start <- audit_base %>% filter(!is.na(plan_period_start))
has_end   <- audit_base %>% filter(!is.na(plan_period_end))
has_both  <- audit_base %>% filter(!is.na(plan_period_start), !is.na(plan_period_end))

cat(sprintf("Spine rows:                  %d hospitals\n", nrow(audit_base)))
cat(sprintf("With parsed start date:      %d\n", nrow(has_start)))
cat(sprintf("With parsed end date:        %d\n", nrow(has_end)))
cat(sprintf("With both start and end:     %d\n", nrow(has_both)))
cat("\n")


# =============================================================================
# SECTION 2: Known correction — FAC 953
# =============================================================================

cat("--- FLAG 0: Known correction (FAC 953) ---\n")
fac_953 <- audit_base %>%
  filter(fac == "953") %>%
  select(fac, hospital_name, plan_period_start, plan_period_end, plan_start_year,
         plan_period_start_raw, plan_period_end_raw)

if (nrow(fac_953) == 0) {
  cat("  FAC 953 not found in spine.\n")
} else {
  r <- fac_953[1, ]
  cat(sprintf("  FAC 953 (%s):\n", r$hospital_name))
  cat(sprintf("    plan_period_start (parsed): %s  [raw: '%s']\n",
              r$plan_period_start, r$plan_period_start_raw))
  cat(sprintf("    plan_period_end   (parsed): %s  [raw: '%s']\n",
              r$plan_period_end,   r$plan_period_end_raw))
  cat("    >> Correct start is 2025 (Invent 2030). Requires patching via 00f.\n")
}
cat("\n")


# =============================================================================
# SECTION 3: Start year implausibly old (< 2015)
# =============================================================================

cat(sprintf("--- FLAG 1: Start year before %d ---\n", MIN_PLAUSIBLE))
old_start <- has_start %>%
  filter(plan_start_year < MIN_PLAUSIBLE) %>%
  select(fac, hospital_name, plan_start_year, plan_period_start_raw, plan_period_end_raw)

if (nrow(old_start) == 0) {
  cat("  None found.\n")
} else {
  cat(sprintf("  %d hospital(s):\n", nrow(old_start)))
  for (i in seq_len(nrow(old_start))) {
    cat(sprintf("    FAC %s (%s): start=%d  [raw start='%s', raw end='%s']\n",
                old_start$fac[i], old_start$hospital_name[i],
                old_start$plan_start_year[i],
                old_start$plan_period_start_raw[i], old_start$plan_period_end_raw[i]))
  }
}
cat("\n")


# =============================================================================
# SECTION 4: Start year in the future (> current year)
# =============================================================================

cat(sprintf("--- FLAG 2: Start year after %d (future) ---\n", CURRENT_YEAR))
future_start <- has_start %>%
  filter(plan_start_year > CURRENT_YEAR) %>%
  select(fac, hospital_name, plan_start_year, plan_period_start_raw, plan_period_end_raw)

if (nrow(future_start) == 0) {
  cat("  None found.\n")
} else {
  cat(sprintf("  %d hospital(s):\n", nrow(future_start)))
  for (i in seq_len(nrow(future_start))) {
    cat(sprintf("    FAC %s (%s): start=%d  [raw start='%s', raw end='%s']\n",
                future_start$fac[i], future_start$hospital_name[i],
                future_start$plan_start_year[i],
                future_start$plan_period_start_raw[i],
                future_start$plan_period_end_raw[i]))
  }
}
cat("\n")


# =============================================================================
# SECTION 5: Start year equals end year (zero-length plan)
# =============================================================================

cat("--- FLAG 3: Start year equals end year ---\n")
zero_span <- has_both %>%
  mutate(
    start_yr = as.integer(year(plan_period_start)),
    end_yr   = as.integer(year(plan_period_end))
  ) %>%
  filter(start_yr == end_yr) %>%
  select(fac, hospital_name, start_yr, end_yr,
         plan_period_start_raw, plan_period_end_raw)

if (nrow(zero_span) == 0) {
  cat("  None found.\n")
} else {
  cat(sprintf("  %d hospital(s):\n", nrow(zero_span)))
  for (i in seq_len(nrow(zero_span))) {
    cat(sprintf("    FAC %s (%s): start=%d end=%d  [raw start='%s', raw end='%s']\n",
                zero_span$fac[i], zero_span$hospital_name[i],
                zero_span$start_yr[i], zero_span$end_yr[i],
                zero_span$plan_period_start_raw[i], zero_span$plan_period_end_raw[i]))
  }
}
cat("\n")


# =============================================================================
# SECTION 6: Start year after end year (impossible ordering)
# =============================================================================

cat("--- FLAG 4: Start year after end year (impossible) ---\n")
reversed <- has_both %>%
  filter(plan_period_start > plan_period_end) %>%
  select(fac, hospital_name, plan_period_start, plan_period_end,
         plan_period_start_raw, plan_period_end_raw)

if (nrow(reversed) == 0) {
  cat("  None found.\n")
} else {
  cat(sprintf("  %d hospital(s):\n", nrow(reversed)))
  for (i in seq_len(nrow(reversed))) {
    cat(sprintf("    FAC %s (%s): start=%s end=%s  [raw start='%s', raw end='%s']\n",
                reversed$fac[i], reversed$hospital_name[i],
                reversed$plan_period_start[i], reversed$plan_period_end[i],
                reversed$plan_period_start_raw[i], reversed$plan_period_end_raw[i]))
  }
}
cat("\n")


# =============================================================================
# SECTION 7: Plan span > MAX_SPAN_YRS years
# =============================================================================

cat(sprintf("--- FLAG 5: Plan span > %d years ---\n", MAX_SPAN_YRS))
long_span <- has_both %>%
  mutate(span_yrs = as.numeric(difftime(plan_period_end, plan_period_start,
                                        units = "days")) / 365.25) %>%
  filter(span_yrs > MAX_SPAN_YRS) %>%
  select(fac, hospital_name, span_yrs, plan_period_start, plan_period_end,
         plan_period_start_raw, plan_period_end_raw) %>%
  arrange(desc(span_yrs))

if (nrow(long_span) == 0) {
  cat("  None found.\n")
} else {
  cat(sprintf("  %d hospital(s):\n", nrow(long_span)))
  for (i in seq_len(nrow(long_span))) {
    cat(sprintf(
      "    FAC %s (%s): span=%.1f yrs  start=%s end=%s  [raw start='%s', raw end='%s']\n",
      long_span$fac[i], long_span$hospital_name[i], long_span$span_yrs[i],
      long_span$plan_period_start[i], long_span$plan_period_end[i],
      long_span$plan_period_start_raw[i], long_span$plan_period_end_raw[i]))
  }
}
cat("\n")


# =============================================================================
# SECTION 8: End year before MIN_END_YEAR (expired plan)
# =============================================================================

cat(sprintf("--- FLAG 6: End year before %d (likely expired/wrong doc) ---\n", MIN_END_YEAR))
old_end <- has_end %>%
  mutate(end_yr = as.integer(year(plan_period_end))) %>%
  filter(end_yr < MIN_END_YEAR) %>%
  select(fac, hospital_name, end_yr, plan_period_start_raw, plan_period_end_raw)

if (nrow(old_end) == 0) {
  cat("  None found.\n")
} else {
  cat(sprintf("  %d hospital(s):\n", nrow(old_end)))
  for (i in seq_len(nrow(old_end))) {
    cat(sprintf("    FAC %s (%s): end=%d  [raw start='%s', raw end='%s']\n",
                old_end$fac[i], old_end$hospital_name[i], old_end$end_yr[i],
                old_end$plan_period_start_raw[i], old_end$plan_period_end_raw[i]))
  }
}
cat("\n")


# =============================================================================
# SECTION 9: Precise full dates (YYYY-MM-DD) — informational flag
# =============================================================================

cat("--- FLAG 7: Precise full dates (YYYY-MM-DD) — verify explicit in document ---\n")
precise_dates <- audit_base %>%
  filter(
    grepl("^\\d{4}-\\d{2}-\\d{2}$", plan_period_start_raw, perl = TRUE) |
      grepl("^\\d{4}-\\d{2}-\\d{2}$", plan_period_end_raw,   perl = TRUE)
  ) %>%
  select(fac, hospital_name, plan_period_start_raw, plan_period_end_raw)

if (nrow(precise_dates) == 0) {
  cat("  None found.\n")
} else {
  cat(sprintf("  %d hospital(s) — verify dates are explicitly stated in document:\n",
              nrow(precise_dates)))
  for (i in seq_len(nrow(precise_dates))) {
    cat(sprintf("    FAC %s (%s): start='%s'  end='%s'\n",
                precise_dates$fac[i], precise_dates$hospital_name[i],
                precise_dates$plan_period_start_raw[i],
                precise_dates$plan_period_end_raw[i]))
  }
}
cat("\n")


# =============================================================================
# SECTION 10: Summary
# =============================================================================

flagged_facs <- unique(c(
  "953",
  old_start$fac,
  future_start$fac,
  zero_span$fac,
  reversed$fac,
  long_span$fac,
  old_end$fac
))

cat("=============================================================================\n")
cat("  AUDIT SUMMARY\n")
cat("=============================================================================\n")
cat(sprintf("  FLAG 0 — Known correction (FAC 953):           1\n"))
cat(sprintf("  FLAG 1 — Start before %d:                    %d\n", MIN_PLAUSIBLE, nrow(old_start)))
cat(sprintf("  FLAG 2 — Start after %d (future):             %d\n", CURRENT_YEAR,  nrow(future_start)))
cat(sprintf("  FLAG 3 — Start equals end year:                %d\n", nrow(zero_span)))
cat(sprintf("  FLAG 4 — Start after end (impossible):         %d\n", nrow(reversed)))
cat(sprintf("  FLAG 5 — Span > %d years:                      %d\n", MAX_SPAN_YRS,  nrow(long_span)))
cat(sprintf("  FLAG 6 — End before %d (expired):             %d\n", MIN_END_YEAR,  nrow(old_end)))
cat(sprintf("  FLAG 7 — Precise full dates (informational):   %d\n", nrow(precise_dates)))
cat(sprintf("\n  Total distinct FACs with hard flags (0–6):     %d\n", length(flagged_facs)))
if (length(flagged_facs) > 0) {
  cat(sprintf("  FACs: %s\n", paste(sort(flagged_facs), collapse = ", ")))
}
cat("\n  Next step: review flags above, then run 00f_patch_plan_dates.R\n")
cat("  with confirmed corrections added to the corrections table.\n")
cat("=============================================================================\n")


# =============================================================================
# SECTION 11: Write audit table
# =============================================================================

dir.create("analysis/outputs/tables", recursive = TRUE, showWarnings = FALSE)

all_flagged <- audit_base %>%
  filter(fac %in% flagged_facs) %>%
  select(fac, hospital_name, plan_start_year, plan_period_start, plan_period_end,
         plan_period_start_raw, plan_period_end_raw, extraction_quality)

write_csv(all_flagged, "analysis/outputs/tables/00e_flagged_dates.csv")
cat(sprintf("\nAudit table written: analysis/outputs/tables/00e_flagged_dates.csv (%d rows)\n",
            nrow(all_flagged)))