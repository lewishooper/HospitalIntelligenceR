# =============================================================================
# roles/hit/scripts/hit_validate.R
# HospitalIntelligenceR — HIT Validation
#
# Reads hit_master.csv and checks:
#   1. FAC coverage — which registry FACs are present / absent in HIT
#   2. FACs in HIT but not in the registry (non-hospital entities, etc.)
#   3. Year coverage per FAC — which hospitals have data in which years
#   4. Indicator coverage — which indicators are present in which years
#   5. Completeness summary — non-NA rate by fiscal year
#
# Output: roles/hit/outputs/hit_coverage.csv
#
# Run sequence:  hit_import.R  →  hit_validate.R
# =============================================================================

library(tidyverse)
library(yaml)

OUTPUT_DIR   <- "roles/hit/outputs"
REGISTRY_PATH <- "registry/hospital_registry.yaml"

# -----------------------------------------------------------------------------
# 1. Load inputs
# -----------------------------------------------------------------------------

message("Step 1 — Loading hit_master and registry")

hit_master <- read_csv(
  file.path(OUTPUT_DIR, "hit_master.csv"),
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
)

message(sprintf("  hit_master: %d rows | %d unique FACs | %d fiscal years",
                nrow(hit_master),
                n_distinct(hit_master$fac),
                n_distinct(hit_master$fiscal_year)))

# Load registry FACs
reg <- yaml.load_file(REGISTRY_PATH)
registry_facs <- sapply(reg$hospitals, function(h) as.character(h$FAC))
message(sprintf("  Registry FACs: %d", length(registry_facs)))

# -----------------------------------------------------------------------------
# 2. FAC coverage — registry vs HIT
# -----------------------------------------------------------------------------

message("\nStep 2 — FAC coverage")

hit_facs <- unique(hit_master$fac)

facs_in_both     <- intersect(registry_facs, hit_facs)
facs_registry_only <- setdiff(registry_facs, hit_facs)   # in registry, not in HIT
facs_hit_only    <- setdiff(hit_facs, registry_facs)     # in HIT, not in registry

message(sprintf("  FACs in both registry and HIT:        %d", length(facs_in_both)))
message(sprintf("  FACs in registry but absent from HIT: %d", length(facs_registry_only)))
message(sprintf("  FACs in HIT but not in registry:      %d", length(facs_hit_only)))

if (length(facs_registry_only) > 0) {
  message("  Registry FACs missing from HIT:")
  # Look up names from registry
  missing_names <- sapply(facs_registry_only, function(f) {
    h <- Filter(function(x) as.character(x$FAC) == f, reg$hospitals)
    if (length(h) > 0) h[[1]]$name else f
  })
  for (i in seq_along(facs_registry_only)) {
    message(sprintf("    FAC %s — %s", facs_registry_only[i], missing_names[i]))
  }
}

if (length(facs_hit_only) > 0) {
  message("  HIT FACs not in registry (non-hospital entities or retired FACs):")
  print(sort(as.integer(facs_hit_only)))
}

# -----------------------------------------------------------------------------
# 3. Year coverage per FAC
# -----------------------------------------------------------------------------

message("\nStep 3 — Year coverage per FAC")

year_coverage <- hit_master %>%
  distinct(fac, fiscal_year) %>%
  group_by(fac) %>%
  summarise(
    n_years     = n(),
    years       = paste(sort(fiscal_year), collapse = "; "),
    .groups     = "drop"
  ) %>%
  arrange(as.integer(fac))

message(sprintf("  Year coverage range: %d to %d years per FAC",
                min(year_coverage$n_years), max(year_coverage$n_years)))
message("  Distribution of year counts:")
print(table(year_coverage$n_years))

# -----------------------------------------------------------------------------
# 4. Indicator coverage by fiscal year
# -----------------------------------------------------------------------------

message("\nStep 4 — Indicator coverage by fiscal year")

ind_by_year <- hit_master %>%
  group_by(fiscal_year) %>%
  summarise(
    n_unique_indicators = n_distinct(indicator_code),
    n_facs              = n_distinct(fac),
    n_rows              = n(),
    .groups = "drop"
  ) %>%
  arrange(fiscal_year)

message("  Indicators present per fiscal year:")
print(ind_by_year)

# -----------------------------------------------------------------------------
# 5. Completeness summary — non-NA share by year
# -----------------------------------------------------------------------------

message("\nStep 5 — Completeness summary")

# For each fiscal year: how many FAC × indicator combinations have a value?
# (NA rows were dropped in hit_import, so hit_master only contains non-NA rows)
# We compute the potential max as n_facs × n_indicators in that year

completeness <- hit_master %>%
  group_by(fiscal_year) %>%
  summarise(
    n_facs         = n_distinct(fac),
    n_indicators   = n_distinct(indicator_code),
    n_obs          = n(),
    potential_max  = n_facs * n_indicators,
    pct_complete   = round(100 * n_obs / potential_max, 1),
    .groups        = "drop"
  ) %>%
  arrange(fiscal_year)

message("  Completeness by fiscal year (non-NA values / potential max):")
print(completeness)

# -----------------------------------------------------------------------------
# 6. Unmatched lookup codes
# -----------------------------------------------------------------------------

message("\nStep 6 — Lookup match check")

# Identify which indicator codes have no lookup name
# Assumes the lookup join added at least one non-key column from the lookup
# Detect lookup columns as any column that isn't a core structural column
core_cols <- c("fac", "fiscal_year", "indicator_code", "value",
               "accounting_period", "report_mapping_id")
lookup_cols <- setdiff(names(hit_master), core_cols)

if (length(lookup_cols) == 0) {
  message("  WARNING: No lookup columns detected in hit_master — lookup may not have joined correctly")
} else {
  # Use first lookup column to detect unmatched codes
  unmatched_codes <- hit_master %>%
    filter(is.na(.data[[lookup_cols[1]]])) %>%
    distinct(indicator_code) %>%
    pull(indicator_code)

  if (length(unmatched_codes) == 0) {
    message("  All indicator codes matched in lookup")
  } else {
    message(sprintf("  %d indicator codes unmatched in lookup:", length(unmatched_codes)))
    print(sort(unmatched_codes))
  }
}

# -----------------------------------------------------------------------------
# 7. Build and write hit_coverage.csv
# -----------------------------------------------------------------------------

message("\nStep 7 — Writing hit_coverage.csv")

# One row per FAC — registry match status, year coverage, year list
registry_lookup <- tibble(
  fac            = registry_facs,
  in_registry    = TRUE,
  hospital_name  = sapply(reg$hospitals, function(h) h$name)
)

coverage <- year_coverage %>%
  full_join(registry_lookup, by = "fac") %>%
  mutate(
    in_hit       = fac %in% hit_facs,
    in_registry  = replace_na(in_registry, FALSE),
    match_status = case_when(
      in_registry & in_hit   ~ "matched",
      in_registry & !in_hit  ~ "registry_only",
      !in_registry & in_hit  ~ "hit_only",
      TRUE                   ~ "unknown"
    )
  ) %>%
  select(fac, hospital_name, match_status, n_years, years,
         in_registry, in_hit) %>%
  arrange(match_status, as.integer(fac))

write_csv(coverage, file.path(OUTPUT_DIR, "hit_coverage.csv"))

message(sprintf("  hit_coverage.csv written — %d rows", nrow(coverage)))
message(sprintf("  Path: %s", file.path(OUTPUT_DIR, "hit_coverage.csv")))

# -----------------------------------------------------------------------------
# 8. Summary print
# -----------------------------------------------------------------------------

message("\n========================================")
message("HIT VALIDATION SUMMARY")
message("========================================")
message(sprintf("  hit_master rows:          %d",   nrow(hit_master)))
message(sprintf("  FACs matched to registry: %d",   length(facs_in_both)))
message(sprintf("  FACs missing from HIT:    %d",   length(facs_registry_only)))
message(sprintf("  FACs in HIT only:         %d",   length(facs_hit_only)))
message(sprintf("  Fiscal years covered:     %s",
                paste(sort(unique(hit_master$fiscal_year)), collapse = ", ")))
message(sprintf("  Indicators in dataset:    %d",   n_distinct(hit_master$indicator_code)))
message("========================================")
message("\nhit_validate.R complete.")
