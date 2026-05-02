# =============================================================================
# roles/hit/scripts/hit_01_field_segmentation.R
# HospitalIntelligenceR — Field Financial Performance Segmentation
#
# Characterises Ontario hospital financial performance trajectories from
# 2018/2019 through 2024/2025 (all years present in hit_master.csv).
#
# For each hospital, computes field-adjusted year-over-year changes in
# total revenue and total expenses, cumulates to a trajectory score, and
# classifies hospitals into segmentation quadrants:
#   Revenue-led improvement | Expense-led improvement | Both | Neither
#
# The expense quadrant is further sub-classified using service volume
# (AcutePtDays) to distinguish efficiency-led improvement from
# volume-driven contraction.
#
# Inputs:
#   roles/hit/outputs/hit_master.csv
#
# Outputs (roles/hit/outputs/):
#   hit_01_field_trajectories.csv   — one row per FAC, all scores + classification
#   hit_01_segment_summary.csv      — count/pct per quadrant, by hospital type
#
# Run sequence:  hit_import.R → hit_validate.R → hit_01_field_segmentation.R
#
# Design constraints (from HIT_Analytics_Project_Plan.md):
#   - fac as character throughout (coerced on load — no exceptions)
#   - Field normalization is NOT optional — all YoY changes subtract field median
#   - Hospital type stratification in all summary outputs
# =============================================================================

library(tidyverse)

# -----------------------------------------------------------------------------
# 0. Paths
# -----------------------------------------------------------------------------

HIT_MASTER  <- "roles/hit/outputs/hit_master.csv"
OUTPUT_DIR  <- "roles/hit/outputs"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Working indicator set — agreed April 29 session
# Primary analytical
INDS_PRIMARY <- c("ind01", "ind02", "ind05", "ind06")

# Supporting / decomposition
INDS_SUPPORT <- c("ind03", "ind04", "ind07", "ind08",
                  "ind12", "ind13", "ind18", "ind35")

# Service volume
INDS_VOLUME  <- c("ind45", "ind54", "ind56")

INDS_ALL <- c(INDS_PRIMARY, INDS_SUPPORT, INDS_VOLUME)

# Core computation indicators (used in trajectory scoring)
IND_REV    <- "ind01"   # TotRev
IND_EXP    <- "ind02"   # TotExp
IND_MARGIN <- "ind05"   # TotMarginHospital (PSC 1 — lead performance indicator)
IND_PTDAYS <- "ind45"   # AcutePtDays (primary service volume denominator)
IND_EDVIS  <- "ind56"   # TotEmergf2FInhouse (ED volume — secondary denominator,
#   primary for hospitals with thin inpatient volumes)

# -----------------------------------------------------------------------------
# 1. Load hit_master.csv and filter to working indicator set
# -----------------------------------------------------------------------------

message("Step 1 — Loading hit_master.csv")

hit_master <- read_csv(
  HIT_MASTER,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
)

message(sprintf("  Loaded: %d rows, %d cols", nrow(hit_master), ncol(hit_master)))
message(sprintf("  Unique FACs:          %d", n_distinct(hit_master$fac)))
message(sprintf("  Unique fiscal years:  %d", n_distinct(hit_master$fiscal_year)))
message(sprintf("  Unique indicators:    %d", n_distinct(hit_master$indicator_code)))
message("  Fiscal years present:")
print(sort(unique(hit_master$fiscal_year)))

# Filter to working indicator set
hit_work <- hit_master %>%
  filter(indicator_code %in% INDS_ALL)

message(sprintf("\n  After filtering to %d working indicators (incl. ind56 ED visits): %d rows",
                length(INDS_ALL), nrow(hit_work)))

# Confirm all expected indicators are present
inds_found   <- sort(unique(hit_work$indicator_code))
inds_missing <- setdiff(INDS_ALL, inds_found)

if (length(inds_missing) > 0) {
  message(sprintf("  WARNING: %d expected indicators not found in hit_master:",
                  length(inds_missing)))
  print(inds_missing)
} else {
  message("  All 15 working indicators confirmed present")
}

# Coverage check: how many FACs have data for the two core computation indicators?
coverage_check <- hit_work %>%
  filter(indicator_code %in% c(IND_REV, IND_EXP, IND_PTDAYS)) %>%
  group_by(indicator_code) %>%
  summarise(
    n_fac_total    = n_distinct(fac),
    n_fy_total     = n_distinct(fiscal_year),
    n_obs          = n(),
    .groups = "drop"
  )

message("\n  Coverage for core computation indicators:")
print(coverage_check)

# Hospital-level coverage: FACs with complete data for the two mandatory core
# indicators (rev + exp). ED visits checked separately — expected to be absent
# for specialty hospitals and those without 24/7 EDs.
fy_all <- sort(unique(hit_work$fiscal_year))
n_fy   <- length(fy_all)

fac_core_coverage <- hit_work %>%
  filter(indicator_code %in% c(IND_REV, IND_EXP, IND_PTDAYS)) %>%
  group_by(fac) %>%
  summarise(
    n_ind_fy = n_distinct(paste(indicator_code, fiscal_year)),
    complete  = n_ind_fy == (3 * n_fy),
    .groups = "drop"
  )

n_complete   <- sum(fac_core_coverage$complete)
n_incomplete <- nrow(fac_core_coverage) - n_complete

message(sprintf(
  "\n  FACs with complete core data (%d ind × %d fy = %d obs each): %d",
  3, n_fy, 3 * n_fy, n_complete
))
message(sprintf("  FACs with partial data: %d", n_incomplete))

if (n_incomplete > 0) {
  message("  Partial-data FACs (will be retained with available years):")
  partial <- fac_core_coverage %>%
    filter(!complete) %>%
    arrange(fac)
  print(partial)
}

# ED visits coverage — reported separately; absence is expected and not a defect
fac_ed_coverage <- hit_work %>%
  filter(indicator_code == IND_EDVIS) %>%
  group_by(fac) %>%
  summarise(n_fy_ed = n_distinct(fiscal_year), .groups = "drop")

message(sprintf(
  "\n  FACs with any ED visit data (ind56): %d of %d",
  nrow(fac_ed_coverage), n_distinct(hit_work$fac)
))
message(sprintf(
  "  FACs with no ED visit data (expected for specialty/no-ED hospitals): %d",
  n_distinct(hit_work$fac) - nrow(fac_ed_coverage)
))

message("\nhit_01 Section 1 complete — paste output above before proceeding to Section 2.")

# =============================================================================
# SECTION 2 — Year-over-year computation and field adjustment
#
# For each hospital and each fiscal year transition, compute:
#   (a) Raw YoY % change in TotRev and TotExp
#   (b) Field median YoY % change for that transition (across all reporting FACs)
#   (c) Field-adjusted YoY change = (a) − (b)
#
# AcutePtDays and ED visits YoY computed for efficiency sub-classification
# in Section 3. Not used in the primary trajectory scoring.
#
# Transition label convention: the "to" year.
#   2018/2019 → 2019/2020 labelled as "2019/2020"
# This means 7 fiscal years produce 6 transitions.
# =============================================================================

message("\nStep 2 — Computing year-over-year changes")

# Extract the four volume/efficiency indicators in long format, sorted
yoy_base <- hit_work %>%
  filter(indicator_code %in% c(IND_REV, IND_EXP, IND_PTDAYS, IND_EDVIS)) %>%
  select(fac, fiscal_year, indicator_code, value) %>%
  arrange(fac, indicator_code, fiscal_year)

# Compute YoY % change using lag within each fac × indicator group
# Formula: (value_t - value_t-1) / abs(value_t-1) * 100
# abs() in denominator guards against edge cases where base year is negative
yoy_long <- yoy_base %>%
  group_by(fac, indicator_code) %>%
  mutate(
    value_lag  = lag(value),
    yoy_pct    = (value - value_lag) / abs(value_lag) * 100
  ) %>%
  ungroup() %>%
  filter(!is.na(yoy_pct))   # drops first year (no lag) and any gap years

message(sprintf("  YoY rows computed: %d (max possible: %d FACs × 6 transitions × 4 indicators)",
                nrow(yoy_long), 149 * 6 * 4))

# Pivot to wide: one row per fac × fiscal_year (transition = "to" year)
yoy_wide <- yoy_long %>%
  select(fac, fiscal_year, indicator_code, yoy_pct) %>%
  pivot_wider(
    names_from  = indicator_code,
    values_from = yoy_pct,
    names_prefix = "yoy_"
  ) %>%
  rename(
    rev_yoy    = yoy_ind01,
    exp_yoy    = yoy_ind02,
    ptdays_yoy = yoy_ind45,
    edvis_yoy  = yoy_ind56
  )

message(sprintf("  Wide YoY table: %d rows, %d cols",
                nrow(yoy_wide), ncol(yoy_wide)))
message(sprintf("  Unique FACs with any YoY data: %d", n_distinct(yoy_wide$fac)))
message(sprintf("  Fiscal year transitions present:"))
print(sort(unique(yoy_wide$fiscal_year)))

# -----------------------------------------------------------------------------
# Field median YoY per transition — computed on revenue and expenses separately
# Field median uses all FACs with non-NA YoY for that transition
# -----------------------------------------------------------------------------

field_medians <- yoy_wide %>%
  group_by(fiscal_year) %>%
  summarise(
    field_med_rev_yoy  = median(rev_yoy, na.rm = TRUE),
    field_med_exp_yoy  = median(exp_yoy, na.rm = TRUE),
    n_fac_rev          = sum(!is.na(rev_yoy)),
    n_fac_exp          = sum(!is.na(exp_yoy)),
    .groups = "drop"
  )

message("\n  Field median YoY % change by transition year:")
print(field_medians %>%
        select(fiscal_year, field_med_rev_yoy, field_med_exp_yoy,
               n_fac_rev, n_fac_exp) %>%
        mutate(across(c(field_med_rev_yoy, field_med_exp_yoy),
                      function(x) round(x, 2))))

# -----------------------------------------------------------------------------
# Join field medians and compute field-adjusted YoY scores
# Field-adjusted = hospital raw YoY − field median for that transition
# Positive adj_rev_yoy: hospital grew revenue faster than field
# Negative adj_exp_yoy: hospital grew expenses SLOWER than field (improvement)
# -----------------------------------------------------------------------------

yoy_adj <- yoy_wide %>%
  left_join(field_medians, by = "fiscal_year") %>%
  mutate(
    adj_rev_yoy  = rev_yoy - field_med_rev_yoy,
    adj_exp_yoy  = exp_yoy - field_med_exp_yoy
  )

message(sprintf("\n  Field-adjusted YoY table: %d rows", nrow(yoy_adj)))
message("  adj_rev_yoy summary (positive = outperformed field on revenue):")
print(summary(yoy_adj$adj_rev_yoy))
message("  adj_exp_yoy summary (negative = held expenses below field growth):")
print(summary(yoy_adj$adj_exp_yoy))

message("\nhit_01 Section 2 complete — paste output above before proceeding to Section 3.")

# =============================================================================
# SECTION 3 — Cumulation, efficiency metrics, and trajectory classification
#
# Part A — Cumulate field-adjusted YoY scores per FAC
# Part B — Compute efficiency metrics (cost per pt day, cost per ED visit)
#           from raw first/last year values
# Part C — Apply trajectory thresholds and assign quadrant classifications
# Part D — Expense sub-classification (efficiency-led vs volume contraction)
# Part E — Summary table by quadrant
# =============================================================================

message("\nStep 3 — Cumulating scores and classifying trajectories")

# -----------------------------------------------------------------------------
# Part A — Cumulate field-adjusted YoY per FAC
# Uses all transitions where both rev and exp adj values are available
# Tracks n_transitions so we know whose score rests on < 6 years
# -----------------------------------------------------------------------------

trajectory_scores <- yoy_adj %>%
  filter(!is.na(adj_rev_yoy) & !is.na(adj_exp_yoy)) %>%
  group_by(fac) %>%
  summarise(
    cum_adj_rev    = sum(adj_rev_yoy),
    cum_adj_exp    = sum(adj_exp_yoy),
    n_transitions  = n(),
    .groups = "drop"
  )

message(sprintf("  FACs with trajectory scores: %d", nrow(trajectory_scores)))
message(sprintf("  FACs with all 6 transitions: %d",
                sum(trajectory_scores$n_transitions == 6)))
message(sprintf("  FACs with fewer than 6 transitions: %d",
                sum(trajectory_scores$n_transitions < 6)))

message("\n  Cumulative field-adjusted revenue score distribution:")
print(summary(trajectory_scores$cum_adj_rev))
message("  Cumulative field-adjusted expense score distribution:")
print(summary(trajectory_scores$cum_adj_exp))

# Key quantiles for threshold-setting
message("\n  Revenue score quantiles (10th, 25th, 75th, 90th):")
print(round(quantile(trajectory_scores$cum_adj_rev,
                     probs = c(0.10, 0.25, 0.75, 0.90)), 2))
message("  Expense score quantiles (10th, 25th, 75th, 90th):")
print(round(quantile(trajectory_scores$cum_adj_exp,
                     probs = c(0.10, 0.25, 0.75, 0.90)), 2))

# -----------------------------------------------------------------------------
# Part B — Efficiency metrics from raw values
# Pull TotRev, TotExp, AcutePtDays, ED visits for each FAC's
# first and last available fiscal year, then derive cost ratios
# -----------------------------------------------------------------------------

message("\nStep 3B — Computing efficiency metrics from raw values")

# First and last fiscal year per FAC for each of the four raw indicators
raw_endpoints <- hit_work %>%
  filter(indicator_code %in% c(IND_REV, IND_EXP, IND_PTDAYS, IND_EDVIS)) %>%
  select(fac, fiscal_year, indicator_code, value) %>%
  group_by(fac, indicator_code) %>%
  summarise(
    first_fy    = min(fiscal_year),
    last_fy     = max(fiscal_year),
    value_first = value[fiscal_year == min(fiscal_year)][1],
    value_last  = value[fiscal_year == max(fiscal_year)][1],
    .groups = "drop"
  )

# Pivot to wide: one row per FAC, columns for first/last by indicator
raw_wide <- raw_endpoints %>%
  select(fac, indicator_code, value_first, value_last) %>%
  pivot_wider(
    names_from  = indicator_code,
    values_from = c(value_first, value_last)
  ) %>%
  rename(
    rev_first    = value_first_ind01,
    rev_last     = value_last_ind01,
    exp_first    = value_first_ind02,
    exp_last     = value_last_ind02,
    ptdays_first = value_first_ind45,
    ptdays_last  = value_last_ind45,
    edvis_first  = value_first_ind56,
    edvis_last   = value_last_ind56
  )

# Derive efficiency metrics
# cost_per_pt_day  = TotExp / AcutePtDays  (NA for FACs with no ptdays data)
# cost_per_ed_visit = TotExp / TotEmergf2FInhouse (NA for no-ED FACs)
raw_wide <- raw_wide %>%
  mutate(
    cpd_first  = ifelse(!is.na(ptdays_first) & ptdays_first > 0,
                        exp_first / ptdays_first, NA_real_),
    cpd_last   = ifelse(!is.na(ptdays_last)  & ptdays_last  > 0,
                        exp_last  / ptdays_last,  NA_real_),
    cpd_change = cpd_last - cpd_first,   # negative = efficiency improved
    
    ced_first  = ifelse(!is.na(edvis_first) & edvis_first > 0,
                        exp_first / edvis_first, NA_real_),
    ced_last   = ifelse(!is.na(edvis_last)  & edvis_last  > 0,
                        exp_last  / edvis_last,  NA_real_),
    ced_change = ced_last - ced_first,   # negative = efficiency improved
    
    # Volume change flags (raw, not field-adjusted — did the hospital do more or less?)
    ptdays_change_pct = ifelse(!is.na(ptdays_first) & ptdays_first > 0,
                               (ptdays_last - ptdays_first) / ptdays_first * 100, NA_real_),
    edvis_change_pct  = ifelse(!is.na(edvis_first)  & edvis_first  > 0,
                               (edvis_last  - edvis_first)  / edvis_first  * 100, NA_real_)
  )

message(sprintf("  FACs with cost_per_pt_day data: %d", sum(!is.na(raw_wide$cpd_change))))
message(sprintf("  FACs with cost_per_ed_visit data: %d", sum(!is.na(raw_wide$ced_change))))
message(sprintf("  FACs with neither volume metric: %d",
                sum(is.na(raw_wide$cpd_change) & is.na(raw_wide$ced_change))))

# -----------------------------------------------------------------------------
# Part C — Trajectory thresholds and quadrant classification
#
# PROVISIONAL THRESHOLDS — review the distributions above before confirming.
# Threshold logic: a hospital must accumulate > REV_THRESHOLD pp of
# field-adjusted cumulative revenue growth to be classified as "revenue-led".
# Similarly, cumulative expense score < -EXP_THRESHOLD = expense improvement.
# These are named constants — adjust here if the distributions suggest otherwise.
# -----------------------------------------------------------------------------

REV_THRESHOLD <- 5    # pp cumulative — revenue outperformance vs field
EXP_THRESHOLD <- 5    # pp cumulative — expense held below field growth

message(sprintf("\n  Provisional thresholds: revenue ±%.0fpp | expense ±%.0fpp cumulative",
                REV_THRESHOLD, EXP_THRESHOLD))
message("  Review distributions above — adjust constants if needed before Section 4.")

# Join scores and raw data
trajectories <- trajectory_scores %>%
  left_join(raw_wide, by = "fac") %>%
  mutate(
    # Revenue direction: positive adj = outperformed field
    rev_improving  = cum_adj_rev >  REV_THRESHOLD,
    rev_declining  = cum_adj_rev < -REV_THRESHOLD,
    rev_flat       = !rev_improving & !rev_declining,
    
    # Expense direction: negative adj = expense held below field (improvement)
    exp_improving  = cum_adj_exp < -EXP_THRESHOLD,
    exp_worsening  = cum_adj_exp >  EXP_THRESHOLD,
    exp_flat       = !exp_improving & !exp_worsening,
    
    # Primary quadrant — 2×2 on revenue and expense direction
    quadrant = case_when(
      rev_improving & exp_improving  ~ "Both",
      rev_improving & !exp_improving ~ "Revenue-led",
      exp_improving & !rev_improving ~ "Expense-led",
      exp_worsening | rev_declining  ~ "Cost pressure",
      TRUE                           ~ "Neither"
    )
  )

message("\n  Primary quadrant distribution:")
print(table(trajectories$quadrant))

# -----------------------------------------------------------------------------
# Part D — Expense sub-classification
# Applied within Expense-led and Both quadrants only
# Distinguishes efficiency-led from volume-driven contraction
# Volume metric priority: AcutePtDays first, ED visits second
# -----------------------------------------------------------------------------

trajectories <- trajectories %>%
  mutate(
    # Best available volume change: prefer ptdays; fall back to ed visits
    vol_change_pct = case_when(
      !is.na(ptdays_change_pct) ~ ptdays_change_pct,
      !is.na(edvis_change_pct)  ~ edvis_change_pct,
      TRUE                      ~ NA_real_
    ),
    vol_metric_used = case_when(
      !is.na(ptdays_change_pct) ~ "AcutePtDays",
      !is.na(edvis_change_pct)  ~ "EDVisits",
      TRUE                      ~ "None"
    ),
    
    # Efficiency improvement: cost per unit fell
    eff_improved = case_when(
      !is.na(cpd_change) ~ cpd_change < 0,
      !is.na(ced_change) ~ ced_change < 0,
      TRUE               ~ NA
    ),
    
    # Expense sub-classification (only meaningful in Expense-led / Both)
    exp_subclass = case_when(
      !quadrant %in% c("Expense-led", "Both") ~ NA_character_,
      is.na(vol_change_pct)                   ~ "Volume data unavailable",
      vol_change_pct < -5 & !eff_improved     ~ "Volume contraction",
      vol_change_pct < -5 &  eff_improved     ~ "Efficiency-led (volume declining)",
      TRUE                                    ~ "Efficiency-led"
    )
  )

message("\n  Expense sub-classification (Expense-led and Both quadrants only):")
print(table(trajectories$exp_subclass, useNA = "ifany"))

# -----------------------------------------------------------------------------
# Part E — Summary by quadrant
# -----------------------------------------------------------------------------

quadrant_summary <- trajectories %>%
  group_by(quadrant) %>%
  summarise(
    n_hospitals      = n(),
    pct_hospitals    = round(n() / nrow(trajectories) * 100, 1),
    mean_cum_rev     = round(mean(cum_adj_rev), 1),
    mean_cum_exp     = round(mean(cum_adj_exp), 1),
    mean_transitions = round(mean(n_transitions), 1),
    .groups = "drop"
  ) %>%
  arrange(desc(n_hospitals))

message("\n  Quadrant summary:")
print(quadrant_summary)

message("\nhit_01 Section 3 complete — paste output above before proceeding to Section 4.")
message("  Key decision: confirm or adjust REV_THRESHOLD and EXP_THRESHOLD")
message("  before Section 4 writes the output CSVs.")

# =============================================================================
# SECTION 4 — Join hospital type and write output CSVs
#
# Joins hospital_type_group from the strategy analytical spine, then writes:
#   hit_01_field_trajectories.csv  — one row per FAC, all scores + classification
#   hit_01_segment_summary.csv     — count/pct per quadrant, by hospital type
# =============================================================================

message("\nStep 4 — Joining hospital type and writing outputs")

# Load hospital type from strategy spine
# hospital_spine.csv is the canonical source for hospital_type_group by FAC
SPINE_PATH <- "analysis/data/hospital_spine.csv"

spine <- read_csv(
  SPINE_PATH,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
) %>%
  select(fac, hospital_name, hospital_type_group) %>%
  distinct()

message(sprintf("  Spine loaded: %d rows", nrow(spine)))
message(sprintf("  Hospital type groups:"))
print(table(spine$hospital_type_group))

# Join to trajectories
trajectories_typed <- trajectories %>%
  left_join(spine, by = "fac")

# Report join coverage
n_matched   <- sum(!is.na(trajectories_typed$hospital_type_group))
n_unmatched <- sum( is.na(trajectories_typed$hospital_type_group))

message(sprintf("\n  FACs matched to registry: %d", n_matched))
message(sprintf("  FACs not in registry (HIT-only): %d", n_unmatched))

if (n_unmatched > 0) {
  message("  Unmatched FACs (expected — HIT-only, no strategy data):")
  print(trajectories_typed %>% filter(is.na(hospital_type_group)) %>% pull(fac))
}

# -----------------------------------------------------------------------------
# Write hit_01_field_trajectories.csv
# One row per FAC — all trajectory scores, classifications, and efficiency metrics
# -----------------------------------------------------------------------------

trajectories_out <- trajectories_typed %>%
  select(
    fac,
    hospital_name,
    hospital_type_group,
    n_transitions,
    cum_adj_rev,
    cum_adj_exp,
    rev_improving,
    rev_declining,
    exp_improving,
    exp_worsening,
    quadrant,
    exp_subclass,
    vol_metric_used,
    vol_change_pct,
    eff_improved,
    cpd_first,
    cpd_last,
    cpd_change,
    ced_first,
    ced_last,
    ced_change,
    rev_first,
    rev_last,
    exp_first,
    exp_last
  ) %>%
  arrange(hospital_type_group, fac)

write_csv(trajectories_out,
          file.path(OUTPUT_DIR, "hit_01_field_trajectories.csv"))

message(sprintf("\n  hit_01_field_trajectories.csv written: %d rows",
                nrow(trajectories_out)))

# -----------------------------------------------------------------------------
# Write hit_01_segment_summary.csv
# Counts and percentages per quadrant, overall and by hospital type
# -----------------------------------------------------------------------------

# Overall summary
summary_overall <- trajectories_typed %>%
  group_by(quadrant) %>%
  summarise(
    n_hospitals   = n(),
    pct_hospitals = round(n() / nrow(trajectories_typed) * 100, 1),
    .groups = "drop"
  ) %>%
  mutate(hospital_type_group = "All") %>%
  select(hospital_type_group, quadrant, n_hospitals, pct_hospitals)

# By hospital type — registry-matched only
summary_by_type <- trajectories_typed %>%
  filter(!is.na(hospital_type_group)) %>%
  group_by(hospital_type_group, quadrant) %>%
  summarise(
    n_hospitals = n(),
    .groups = "drop"
  ) %>%
  group_by(hospital_type_group) %>%
  mutate(
    pct_hospitals = round(n_hospitals / sum(n_hospitals) * 100, 1)
  ) %>%
  ungroup()

segment_summary <- bind_rows(summary_overall, summary_by_type) %>%
  arrange(hospital_type_group, desc(n_hospitals))

write_csv(segment_summary,
          file.path(OUTPUT_DIR, "hit_01_segment_summary.csv"))

message(sprintf("  hit_01_segment_summary.csv written: %d rows",
                nrow(segment_summary)))

# Console preview
message("\n  Segment summary — All hospitals:")
print(summary_overall %>% select(quadrant, n_hospitals, pct_hospitals))

message("\n  Segment summary — by hospital type:")
print(summary_by_type %>% arrange(hospital_type_group, desc(n_hospitals)))

message("\nhit_01_field_segmentation.R complete.")
message(sprintf("  Outputs in: %s", OUTPUT_DIR))
message("  Next: hit_02_strategy_join.R")