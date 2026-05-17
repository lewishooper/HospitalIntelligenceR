# =============================================================================
# roles/hit/scripts/hit_03_plan_comparison.R
# HospitalIntelligenceR — Strategic Plan × Financial Trajectory Comparison
#
# Builds a year-level field-adjusted revenue/expense table and produces the
# primary two-row descriptive table comparing hospitals with vs. without a
# strategic plan in place.
#
# Inputs:
#   roles/hit/outputs/hit_master.csv       — long format: fac × fiscal_year × indicator
#   analysis/data/hospital_spine.csv       — FAC scope and type reference
#   analysis/data/strategy_classified.csv  — direction-level; plan dates by FAC
#
# Outputs (roles/hit/outputs/):
#   hit_03_year_level.csv       — one row per FAC × fiscal_year (wide + field-adj YoY)
#   hit_03_hospital_level.csv   — one row per FAC (cumulative field-adj scores)
#   hit_03_plan_comparison.csv  — two-row summary: with plan vs. no plan
#
# Key design decisions (locked — see HIT_Session_Summary_May13_2026.md):
#   - Field adjustment: hospital YoY % change minus field median YoY for that year
#   - Two-year minimum plan tenure for "with plan" inclusion
#   - "With plan" measurement window: fiscal_year >= plan_start_year/plan_start_year+1
#   - "No plan" measurement window: full available HIT window
#   - Structural outliers (FAC 854, 971, 701, 938) excluded from all calculations
#   - FAC as character throughout — no exceptions
# =============================================================================

library(tidyverse)

# -----------------------------------------------------------------------------
# 0. Paths and constants
# -----------------------------------------------------------------------------

HIT_MASTER  <- "roles/hit/outputs/hit_master.csv"
SPINE_PATH  <- "analysis/data/hospital_spine.csv"
STRAT_PATH  <- "analysis/data/strategy_classified.csv"
OUTPUT_DIR  <- "roles/hit/outputs"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

INDS_NEEDED <- c("ind01", "ind02", "ind05", "ind06", "ind45", "ind56")

# FAC 854 (SA Grace Toronto) and 971 (Sudbury SJCC): COVID transitional care expansion
# FAC 701: large capital construction onboarding
# FAC 938 (Haliburton Health Services): amalgamation / MOHLTC review
STRUCTURAL_OUTLIERS <- c("854", "971", "701", "938")

# Minimum fiscal-year transitions in window for "with plan" group inclusion
MIN_PLAN_YEARS <- 2L

# =============================================================================
# SECTION 1 — Load hit_master.csv; apply scope and indicator filter
# =============================================================================

message("Step 1 — Loading hit_master.csv")

hit_master <- read_csv(
  HIT_MASTER,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
)

message(sprintf("  Loaded: %d rows, %d cols", nrow(hit_master), ncol(hit_master)))
message(sprintf("  Unique FACs:         %d", n_distinct(hit_master$fac)))
message(sprintf("  Unique fiscal years: %d", n_distinct(hit_master$fiscal_year)))
message(sprintf("  Unique indicators:   %d", n_distinct(hit_master$indicator_code)))

# Spine: authoritative scope boundary
spine <- read_csv(
  SPINE_PATH,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)

registry_facs <- spine %>% pull(fac)
scope_facs    <- setdiff(registry_facs, STRUCTURAL_OUTLIERS)

message(sprintf("  Registry FACs:            %d", length(registry_facs)))
message(sprintf("  Scope FACs (excl. outliers): %d", length(scope_facs)))

hit_work <- hit_master %>%
  filter(
    fac %in% scope_facs,
    indicator_code %in% INDS_NEEDED
  )

message(sprintf("  After scope + indicator filter: %d FACs, %d rows",
                n_distinct(hit_work$fac), nrow(hit_work)))

# Confirm all expected indicators are present
inds_found   <- sort(unique(hit_work$indicator_code))
inds_missing <- setdiff(INDS_NEEDED, inds_found)
if (length(inds_missing) > 0) {
  warning(sprintf("Missing indicators: %s", paste(inds_missing, collapse = ", ")))
} else {
  message("  All expected indicators present: OK")
}

# =============================================================================
# SECTION 2 — Pivot wide: one row per FAC × fiscal_year
# =============================================================================

message("\nStep 2 — Pivoting to FAC × fiscal_year wide format")

hit_wide <- hit_work %>%
  select(fac, fiscal_year, indicator_code, value) %>%
  pivot_wider(
    names_from  = indicator_code,
    values_from = value
  )

# Guard: add column as NA if any indicator was entirely absent
for (ind in INDS_NEEDED) {
  if (!ind %in% names(hit_wide)) {
    hit_wide[[ind]] <- NA_real_
    message(sprintf("  WARNING: %s absent from hit_master — column added as NA", ind))
  }
}

# Join hospital_type_group from spine
hit_wide <- hit_wide %>%
  left_join(
    spine %>% select(fac, hospital_name, hospital_type_group),
    by = "fac"
  ) %>%
  rename(
    tot_rev       = ind01,
    tot_exp       = ind02,
    margin_psc1   = ind05,
    pct_nonmoh    = ind06,
    acute_pt_days = ind45,
    er_visits     = ind56
  )

# Derived fields
hit_wide <- hit_wide %>%
  mutate(
    moh_revenue     = tot_rev * (1 - pct_nonmoh / 100),
    cost_per_pt_day = if_else(
      !is.na(acute_pt_days) & acute_pt_days > 0,
      tot_exp / acute_pt_days,
      NA_real_
    )
  )

message(sprintf("  Wide table: %d rows (FAC × fiscal_year)", nrow(hit_wide)))
message(sprintf("  Unique FACs: %d", n_distinct(hit_wide$fac)))
message("  Fiscal years in wide table:")
print(sort(unique(hit_wide$fiscal_year)))

# =============================================================================
# SECTION 3 — Field-adjusted YoY revenue and expense changes
#
#   Pattern mirrors hit_01_field_segmentation.R:
#   (a) YoY % change = (value_t - value_t-1) / |value_t-1| × 100
#   (b) Field median YoY across all reporting FACs for that transition
#   (c) Field-adjusted YoY = (a) − (b)
#
#   Field medians are computed on the full scope population (including both
#   with-plan and no-plan hospitals) — they must not be split by plan group.
# =============================================================================

message("\nStep 3 — Computing field-adjusted YoY revenue and expense changes")

hit_wide <- hit_wide %>% arrange(fac, fiscal_year)

# YoY % change per FAC (lag within FAC)
hit_yoy <- hit_wide %>%
  group_by(fac) %>%
  mutate(
    rev_lag    = lag(tot_rev),
    exp_lag    = lag(tot_exp),
    rev_yoy    = (tot_rev - rev_lag) / abs(rev_lag) * 100,
    exp_yoy    = (tot_exp - exp_lag) / abs(exp_lag) * 100
  ) %>%
  ungroup() %>%
  filter(!is.na(rev_yoy) | !is.na(exp_yoy))  # drop first observation per FAC (no lag)

message(sprintf("  YoY rows computed: %d (FAC × transition)", nrow(hit_yoy)))

# Field median YoY per transition — across all scope FACs with non-NA values
field_meds <- hit_yoy %>%
  group_by(fiscal_year) %>%
  summarise(
    field_med_rev_yoy = median(rev_yoy, na.rm = TRUE),
    field_med_exp_yoy = median(exp_yoy, na.rm = TRUE),
    n_fac_rev         = sum(!is.na(rev_yoy)),
    n_fac_exp         = sum(!is.na(exp_yoy)),
    .groups = "drop"
  )

message("\n  Field medians by transition year:")
print(field_meds %>%
        mutate(across(c(field_med_rev_yoy, field_med_exp_yoy), \(x) round(x, 2))))

# Join field medians; compute field-adjusted YoY
hit_yoy <- hit_yoy %>%
  left_join(field_meds, by = "fiscal_year") %>%
  mutate(
    rev_yoy_adj = rev_yoy - field_med_rev_yoy,
    exp_yoy_adj = exp_yoy - field_med_exp_yoy
  )

# Merge field-adjusted YoY back to wide table (year-level output)
hit_wide_adj <- hit_wide %>%
  left_join(
    hit_yoy %>% select(fac, fiscal_year,
                       rev_yoy, exp_yoy,
                       field_med_rev_yoy, field_med_exp_yoy,
                       rev_yoy_adj, exp_yoy_adj),
    by = c("fac", "fiscal_year")
  )

write_csv(hit_wide_adj, file.path(OUTPUT_DIR, "hit_03_year_level.csv"))
message(sprintf("\n  Written: hit_03_year_level.csv (%d rows)", nrow(hit_wide_adj)))

# =============================================================================
# SECTION 4 — Load strategy plan dates; collapse to one row per FAC
# =============================================================================

message("\nStep 4 — Loading strategy plan dates")

strat_raw <- read_csv(
  STRAT_PATH,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
)

# Collapse to FAC level; exclude structural outliers
# plan_period_start is a 4-digit integer year
# Hospitals with all-NA plan_period_start are treated as "no plan"
fac_plans <- strat_raw %>%
  filter(
    fac %in% scope_facs,
    !is.na(plan_period_start)
  ) %>%
  group_by(fac) %>%
  summarise(
    plan_start_year = as.integer(format(min(plan_period_start, na.rm = TRUE), "%Y")),
    .groups = "drop"
  )

message(sprintf("  FACs with non-NA plan_period_start: %d", nrow(fac_plans)))
message(sprintf("  FACs in scope with no plan data:    %d",
                length(setdiff(scope_facs, fac_plans$fac))))

# =============================================================================
# SECTION 5 — Classify with / no plan; apply 2-year tenure filter
# =============================================================================

message("\nStep 5 — Classifying hospitals and applying tenure filter")

# Transition years available in HIT data (sorted — string sort correct for YYYY/YYYY)
transition_years <- sort(unique(hit_yoy$fiscal_year))
message(sprintf("  Transition years available: %d  (%s → %s)",
                length(transition_years),
                min(transition_years), max(transition_years)))

# For each FAC with a plan: derive first treatment fiscal year and count
# observations >= that year in the HIT transition series
fac_plan_tenure <- fac_plans %>%
  mutate(
    plan_first_fy   = sprintf("%d/%d", plan_start_year, plan_start_year + 1)
  ) %>%
  rowwise() %>%
  mutate(
    n_yoy_in_window = sum(transition_years >= plan_first_fy)
  ) %>%
  ungroup() %>%
  mutate(
    meets_tenure = n_yoy_in_window >= MIN_PLAN_YEARS
  )

n_with_plan_ok    <- sum(fac_plan_tenure$meets_tenure)
n_with_plan_short <- sum(!fac_plan_tenure$meets_tenure)
n_no_plan         <- length(setdiff(scope_facs, fac_plans$fac))

message(sprintf("  With plan, meets ≥%d-year tenure:  %d  ← primary comparison group",
                MIN_PLAN_YEARS, n_with_plan_ok))
message(sprintf("  With plan, below tenure threshold: %d  (excluded from primary table)",
                n_with_plan_short))
message(sprintf("  No strategic plan:                 %d",
                n_no_plan))

if (n_with_plan_short > 0) {
  message("  Short-tenure FACs (excluded from comparison):")
  print(fac_plan_tenure %>%
          filter(!meets_tenure) %>%
          select(fac, plan_start_year, plan_first_fy, n_yoy_in_window))
}

fac_with_plan <- fac_plan_tenure %>% filter(meets_tenure)  %>% pull(fac)
fac_no_plan   <- setdiff(scope_facs, fac_plans$fac)

# =============================================================================
# SECTION 6 — Cumulative field-adjusted changes, per hospital, within window
# =============================================================================

message("\nStep 6 — Computing cumulative field-adjusted changes")

# "With plan" group: sum field-adjusted YoY from first treatment year onward
cum_with_plan <- hit_yoy %>%
  filter(fac %in% fac_with_plan) %>%
  left_join(
    fac_plan_tenure %>% select(fac, plan_start_year, plan_first_fy),
    by = "fac"
  ) %>%
  filter(fiscal_year >= plan_first_fy) %>%
  group_by(fac, hospital_type_group) %>%
  summarise(
    plan_start_year = first(plan_start_year),
    plan_first_fy   = first(plan_first_fy),
    cum_rev_adj     = sum(rev_yoy_adj, na.rm = TRUE),
    cum_exp_adj     = sum(exp_yoy_adj, na.rm = TRUE),
    n_yoy_obs       = n(),
    .groups = "drop"
  ) %>%
  mutate(plan_group = "With strategic plan (≥2 years)")

# "No plan" group: sum over full available window
cum_no_plan <- hit_yoy %>%
  filter(fac %in% fac_no_plan) %>%
  group_by(fac, hospital_type_group) %>%
  summarise(
    plan_start_year = NA_integer_,
    plan_first_fy   = NA_character_,
    cum_rev_adj     = sum(rev_yoy_adj, na.rm = TRUE),
    cum_exp_adj     = sum(exp_yoy_adj, na.rm = TRUE),
    n_yoy_obs       = n(),
    .groups = "drop"
  ) %>%
  mutate(plan_group = "No strategic plan")

cum_all <- bind_rows(cum_with_plan, cum_no_plan)

write_csv(cum_all, file.path(OUTPUT_DIR, "hit_03_hospital_level.csv"))
message(sprintf("  Written: hit_03_hospital_level.csv (%d hospitals)", nrow(cum_all)))

# =============================================================================
# SECTION 7 — Two-row summary table
# =============================================================================

message("\nStep 7 — Building two-row summary table")

summary_table <- cum_all %>%
  group_by(plan_group) %>%
  summarise(
    n_hospitals      = n(),
    mean_cum_rev_adj = round(mean(cum_rev_adj, na.rm = TRUE), 1),
    mean_cum_exp_adj = round(mean(cum_exp_adj, na.rm = TRUE), 1),
    median_cum_rev   = round(median(cum_rev_adj, na.rm = TRUE), 1),
    median_cum_exp   = round(median(cum_exp_adj, na.rm = TRUE), 1),
    sd_cum_rev       = round(sd(cum_rev_adj, na.rm = TRUE), 1),
    sd_cum_exp       = round(sd(cum_exp_adj, na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  arrange(desc(grepl("With", plan_group)))  # "With plan" row first

message("\n  ── Two-row summary (primary deliverable) ──")
print(summary_table)

write_csv(summary_table, file.path(OUTPUT_DIR, "hit_03_plan_comparison.csv"))
message(sprintf("\n  Written: hit_03_plan_comparison.csv"))

# =============================================================================
# SECTION 8 — Type-stratified breakdown (supporting output)
#   Kept separate from two-row primary table; intended for next drill-down step
# =============================================================================

message("\nStep 8 — Type-stratified breakdown (supporting output)")

type_summary <- cum_all %>%
  group_by(plan_group, hospital_type_group) %>%
  summarise(
    n_hospitals      = n(),
    mean_cum_rev_adj = round(mean(cum_rev_adj, na.rm = TRUE), 1),
    mean_cum_exp_adj = round(mean(cum_exp_adj, na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  arrange(plan_group, hospital_type_group)

message("\n  Type-stratified breakdown:")
print(type_summary)

write_csv(type_summary, file.path(OUTPUT_DIR, "hit_03_type_breakdown.csv"))
message("  Written: hit_03_type_breakdown.csv")

# =============================================================================
# SECTION 9 — FIN theme decomposition within the with-plan group
#
# Decomposes the 55 with-plan hospitals into:
#   FIN group:     at least one strategic direction with primary_theme == "FIN"
#   Non-FIN group: no primary FIN direction (secondary FIN excluded by design)
#
# Measurement windows are unchanged — each hospital's plan-anchored window
# from Section 6 is preserved. This section adds a fin_flag column to
# cum_with_plan and re-exports hit_03_hospital_level.csv with that flag.
#
# Design decision (locked — session May 13 2026):
#   primary_theme == "FIN" only; secondary_theme excluded; sensitivity deferred
# =============================================================================

message("\nStep 9 — FIN theme decomposition within with-plan group")

# Classify each FAC as FIN or non-FIN based on primary theme only
# strat_raw is already loaded from Section 4
fac_fin <- strat_raw %>%
  filter(fac %in% fac_with_plan) %>%
  group_by(fac) %>%
  summarise(
    fin_flag = any(primary_theme == "FIN", na.rm = TRUE),
    .groups  = "drop"
  ) %>%
  mutate(
    fin_group = if_else(
      fin_flag,
      "Primary emphasis on finance",
      "No primary emphasis on finance"
    )
  )

n_fin     <- sum(fac_fin$fin_flag)
n_non_fin <- sum(!fac_fin$fin_flag)
n_unclassified <- length(fac_with_plan) - nrow(fac_fin)

message(sprintf("  With plan — FIN primary direction:    %d", n_fin))
message(sprintf("  With plan — no FIN primary direction: %d", n_non_fin))
if (n_unclassified > 0) {
  message(sprintf("  WARNING: %d with-plan FACs absent from strategy_classified — fin_flag will be NA",
                  n_unclassified))
}

# Add fin_flag and fin_group to cum_with_plan; re-export hospital-level file
cum_with_plan <- cum_with_plan %>%
  left_join(fac_fin %>% select(fac, fin_flag, fin_group), by = "fac")

# Rebuild cum_all with fin columns (cum_no_plan gets NA — not in scope for FIN analysis)
cum_all <- bind_rows(
  cum_with_plan,
  cum_no_plan %>% mutate(fin_flag = NA, fin_group = NA_character_)
)

write_csv(cum_all, file.path(OUTPUT_DIR, "hit_03_hospital_level.csv"))
message("  Re-written: hit_03_hospital_level.csv (fin_flag and fin_group added)")

# FIN decomposition summary — within with-plan group only
fin_summary <- cum_with_plan %>%
  filter(!is.na(fin_group)) %>%
  group_by(fin_group) %>%
  summarise(
    n_hospitals      = n(),
    mean_cum_rev_adj = round(mean(cum_rev_adj,   na.rm = TRUE), 1),
    mean_cum_exp_adj = round(mean(cum_exp_adj,   na.rm = TRUE), 1),
    median_cum_rev   = round(median(cum_rev_adj, na.rm = TRUE), 1),
    median_cum_exp   = round(median(cum_exp_adj, na.rm = TRUE), 1),
    sd_cum_rev       = round(sd(cum_rev_adj,     na.rm = TRUE), 1),
    sd_cum_exp       = round(sd(cum_exp_adj,     na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  arrange(desc(grepl("emphasis on finance$", fin_group)))  # FIN row first

message("\n  ── FIN decomposition (within with-plan group) ──")
print(fin_summary)

write_csv(fin_summary, file.path(OUTPUT_DIR, "hit_03_fin_comparison.csv"))
message("  Written: hit_03_fin_comparison.csv")

message("\n--- hit_03_plan_comparison.R complete ---")
message(sprintf("  Primary output:    hit_03_plan_comparison.csv"))
message(sprintf("  FIN decomposition: hit_03_fin_comparison.csv"))
message(sprintf("  Year-level data:   hit_03_year_level.csv"))
message(sprintf("  Hospital scores:   hit_03_hospital_level.csv  (fin_flag added)"))
message(sprintf("  Type breakdown:    hit_03_type_breakdown.csv"))