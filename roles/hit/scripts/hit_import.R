# =============================================================================
# roles/hit/scripts/hit_import.R
# HospitalIntelligenceR — HIT Import
#
# Loads the current and historical HIT global CSV files, normalises column
# names to lowercase, filters to hospital-level annual rows, binds the two
# sources (current takes precedence on overlap), pivots to long format, and
# joins the indicator lookup.
#
# Inputs  (roles/hit/source_data/):
#   FY2526Q3_GL HIT Hosp fac Level.csv   — current, primary
#   FY2223YE_GL HIT Hosp fac Level.csv   — historical, supplemental
#   GlobalIndicatorLkup.rds               — indicator code → description
#
# Outputs (roles/hit/outputs/):
#   hit_master.csv      — long format: fac × fiscal_year × indicator
#   hit_quarterly.csv   — quarterly rows held separately (not used in analysis)
#
# Run sequence:  hit_import.R  →  hit_validate.R
# =============================================================================

library(tidyverse)

# -----------------------------------------------------------------------------
# 0. Paths
# -----------------------------------------------------------------------------

SOURCE_DIR  <- "roles/hit/source_data"
OUTPUT_DIR  <- "roles/hit/outputs"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

PATH_CURRENT    <- file.path(SOURCE_DIR, "FY2526Q3_GL HIT Hosp fac Level.csv")
PATH_HISTORICAL <- file.path(SOURCE_DIR, "FY2223YE_GL HIT Hosp fac Level.csv")
PATH_LOOKUP     <- file.path(SOURCE_DIR, "GlobalIndicatorLkup.rds")

# -----------------------------------------------------------------------------
# 1. Load and normalise column names
# -----------------------------------------------------------------------------

message("Step 1 — Loading source files")

# All column names forced to lowercase on load.
# fac_rollup is the MOH identifier for FAC — renamed to fac throughout.

load_hit_csv <- function(path) {
  df <- read_csv(path, show_col_types = FALSE)
  names(df) <- tolower(names(df))
  df <- rename(df, fac = fac_rollup)
  df$fac <- as.character(df$fac)
  df
}

hit_current    <- load_hit_csv(PATH_CURRENT)
hit_historical <- load_hit_csv(PATH_HISTORICAL)

message(sprintf("  Current    — %d rows, %d cols", nrow(hit_current),    ncol(hit_current)))
message(sprintf("  Historical — %d rows, %d cols", nrow(hit_historical), ncol(hit_historical)))

# -----------------------------------------------------------------------------
# 2. Inspect structure (document before filtering)
# -----------------------------------------------------------------------------

message("\nStep 2 — Structure inspection")

message("  report_mapping_id values — CURRENT:")
print(table(hit_current$report_mapping_id))

message("  report_mapping_id values — HISTORICAL:")
print(table(hit_historical$report_mapping_id))

message("\n  accounting_period values — CURRENT:")
print(table(hit_current$accounting_period))

message("\n  accounting_period values — HISTORICAL:")
print(table(hit_historical$accounting_period))

# -----------------------------------------------------------------------------
# 3. Filter: entity type and frequency
# -----------------------------------------------------------------------------

message("\nStep 3 — Filtering")

# Entity filter: retain report_mapping_id == 4 (hospital global level)
# Defensive — current file expected to be all-4, but verify.
filter_entity <- function(df, label) {
  other <- filter(df, report_mapping_id != 4)
  if (nrow(other) > 0) {
    message(sprintf("  WARNING: %s — %d rows with report_mapping_id != 4 — dropped",
                    label, nrow(other)))
    print(table(other$report_mapping_id))
  } else {
    message(sprintf("  %s — report_mapping_id check OK (all rows == 4)", label))
  }
  filter(df, report_mapping_id == 4)
}

hit_current    <- filter_entity(hit_current,    "current")
hit_historical <- filter_entity(hit_historical, "historical")

# Frequency filter: separate YE (annual) from quarterly
hit_current_ye <- hit_current    %>% filter(str_ends(accounting_period, "YE"))
hit_current_q  <- hit_current    %>% filter(!str_ends(accounting_period, "YE"))
hit_hist_ye    <- hit_historical %>% filter(str_ends(accounting_period, "YE"))
hit_hist_q     <- hit_historical %>% filter(!str_ends(accounting_period, "YE"))

message(sprintf("  Current    YE: %d rows | Q: %d rows",
                nrow(hit_current_ye), nrow(hit_current_q)))
message(sprintf("  Historical YE: %d rows | Q: %d rows",
                nrow(hit_hist_ye),    nrow(hit_hist_q)))

# Combine quarterly rows and write out — held for potential future use
hit_quarterly <- bind_rows(hit_current_q, hit_hist_q)
write_csv(hit_quarterly, file.path(OUTPUT_DIR, "hit_quarterly.csv"))
message(sprintf("  Quarterly rows written: %d", nrow(hit_quarterly)))

# -----------------------------------------------------------------------------
# 4. Bind annual rows — current takes precedence on overlap
# -----------------------------------------------------------------------------

message("\nStep 4 — Binding and deduplication")

# Identify overlap: same fac + accounting_period in both sources
current_keys    <- hit_current_ye    %>% select(fac, accounting_period)
historical_keys <- hit_hist_ye       %>% select(fac, accounting_period)
overlap         <- inner_join(current_keys, historical_keys,
                              by = c("fac", "accounting_period"))

message(sprintf("  Overlapping fac × period combinations: %d", nrow(overlap)))
if (nrow(overlap) > 0) {
  message("  Overlap periods (current takes precedence):")
  print(sort(unique(overlap$accounting_period)))
}

# Remove overlapping rows from historical, then bind
hit_hist_deduped <- anti_join(hit_hist_ye, current_keys,
                              by = c("fac", "accounting_period"))

# bind_rows handles mismatched columns natively — columns missing in either
# source are filled with NA. No manual alignment required.
hit_combined <- bind_rows(hit_current_ye, hit_hist_deduped)

message(sprintf("  Combined annual rows: %d (current: %d + historical supplement: %d)",
                nrow(hit_combined), nrow(hit_current_ye), nrow(hit_hist_deduped)))

# -----------------------------------------------------------------------------
# 5. Extract fiscal_year from accounting_period
# -----------------------------------------------------------------------------

message("\nStep 5 — Extracting fiscal_year")

# accounting_period format: "2022/2023YE" → fiscal_year "2022/2023"
hit_combined <- hit_combined %>%
  mutate(fiscal_year = str_remove(accounting_period, "YE$"))

message("  fiscal_year values:")
print(sort(unique(hit_combined$fiscal_year)))

# -----------------------------------------------------------------------------
# 6. Pivot to long format
# -----------------------------------------------------------------------------

message("\nStep 6 — Pivoting to long format")

# Identify all indicator columns (ind01 through ind74, plus any others)
ind_cols <- names(hit_combined)[str_detect(names(hit_combined), "^ind\\d+$")]
message(sprintf("  Indicator columns found: %d", length(ind_cols)))

hit_long <- hit_combined %>%
  select(fac, fiscal_year, accounting_period, report_mapping_id,
         all_of(ind_cols)) %>%
  pivot_longer(
    cols      = all_of(ind_cols),
    names_to  = "indicator_code",
    values_to = "value"
  ) %>%
  # Drop rows where value is NA — indicator not applicable for that year/hospital
  filter(!is.na(value))

message(sprintf("  Long format rows (non-NA values): %d", nrow(hit_long)))
message(sprintf("  Unique fac values:       %d", n_distinct(hit_long$fac)))
message(sprintf("  Unique fiscal years:     %d", n_distinct(hit_long$fiscal_year)))
message(sprintf("  Unique indicator codes:  %d", n_distinct(hit_long$indicator_code)))

# -----------------------------------------------------------------------------
# 7. Load indicator lookup and join
# -----------------------------------------------------------------------------

message("\nStep 7 — Joining indicator lookup")

lookup_raw <- readRDS(PATH_LOOKUP)

# Normalise lookup: ensure it is a data frame with lowercase column names
if (!is.data.frame(lookup_raw)) {
  stop("GlobalIndicatorLkup.rds is not a data frame — review structure before proceeding")
}
names(lookup_raw) <- tolower(names(lookup_raw))

message("  Lookup columns: ", paste(names(lookup_raw), collapse = ", "))
message("  Lookup rows: ", nrow(lookup_raw))
message("  Lookup head:")
print(head(lookup_raw, 5))

# Lookup uses integer ind column (1, 2, 3...).
# CSV indicator columns use zero-padded format: ind01, ind02, ... ind74.
# Construct indicator_code by zero-padding to match.
lookup <- lookup_raw %>%
  mutate(indicator_code = sprintf("ind%02d", as.integer(ind))) %>%
  select(indicator_code, everything(), -ind)

message("  Lookup indicator_code sample:")
print(head(lookup$indicator_code, 5))

# Left join — unmatched codes are flagged in validate script
hit_long <- hit_long %>%
  left_join(lookup, by = "indicator_code")

# Report unmatched codes
unmatched <- hit_long %>%
  filter(is.na(names(lookup)[names(lookup) != "indicator_code"][1])) %>%
  distinct(indicator_code)

if (nrow(unmatched) > 0) {
  message(sprintf("  WARNING: %d indicator codes not matched in lookup:", nrow(unmatched)))
  print(unmatched$indicator_code)
} else {
  message("  All indicator codes matched in lookup")
}

# -----------------------------------------------------------------------------
# 8. Final column order and write output
# -----------------------------------------------------------------------------

message("\nStep 8 — Writing outputs")

# Bring key columns forward; lookup columns follow
lookup_extra_cols <- setdiff(names(lookup), "indicator_code")

hit_master <- hit_long %>%
  select(fac, fiscal_year, indicator_code,
         all_of(lookup_extra_cols),
         value,
         accounting_period, report_mapping_id)

write_csv(hit_master, file.path(OUTPUT_DIR, "hit_master.csv"))

message(sprintf("  hit_master.csv written — %d rows, %d cols",
                nrow(hit_master), ncol(hit_master)))
message(sprintf("  Path: %s", file.path(OUTPUT_DIR, "hit_master.csv")))
message("\nhit_import.R complete. Run hit_validate.R next.")