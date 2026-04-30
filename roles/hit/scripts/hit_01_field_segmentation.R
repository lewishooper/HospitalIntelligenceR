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
