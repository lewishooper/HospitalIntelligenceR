# =============================================================================
# analysis/scripts/00_prepare_data.R
# HospitalIntelligenceR — Analytical Layer
#
# PURPOSE:
#   Build the canonical analytical master dataset by joining the Phase 2
#   extraction output (strategy_master.csv) with hospital reference fields
#   from the registry (hospital_type, robots_allowed) and any externally
#   sourced reference data (CIHI peer group, bed count — added as available).
#
#   All downstream analysis scripts read from the OUTPUT of this script
#   (strategy_master_analytical.csv), never directly from the raw extraction.
#   This keeps the extraction layer and the analytical layer cleanly separated.
#
# INPUTS:
#   roles/strategy/outputs/extractions/strategy_master.csv   [Phase 2 output]
#   registry/hospital_registry.yaml                          [registry]
#   analysis/data/hospital_reference_external.csv            [optional — CIHI etc.]
#
# OUTPUTS:
#   analysis/data/strategy_master_analytical.csv             [canonical analytical input]
#   analysis/data/hospital_spine.csv                         [one row per hospital, for joins]
#
# USAGE:
#   source("analysis/scripts/00_prepare_data.R")
#   # Outputs written to analysis/data/
#   # Inspect: glimpse(master); glimpse(spine)
#
# NOTES:
#   - Run from the project root: setwd("E:/HospitalIntelligenceR")
#   - Re-run any time strategy_master.csv is updated (e.g. after a fine-tuning pass)
#   - hospital_reference_external.csv is optional; script runs without it and
#     logs a warning if not found
#   - plan_period_start / plan_period_end are stored as character in the master;
#     this script parses them to Date where possible and retains the raw string
#     as a fallback column
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(yaml)
  library(lubridate)
  library(readr)
  library(purrr)
})


# =============================================================================
# SECTION 1: Paths
# =============================================================================

PATHS <- list(
  # Inputs
  master_csv       = "roles/strategy/outputs/extractions/strategy_master.csv",
  registry_yaml    = "registry/hospital_registry.yaml",
  external_ref_csv = "analysis/data/hospital_reference_external.csv",

  # Outputs
  analytical_csv   = "analysis/data/strategy_master_analytical.csv",
  spine_csv        = "analysis/data/hospital_spine.csv"
)


# =============================================================================
# SECTION 2: Load strategy_master.csv
# =============================================================================

cat("-- Loading strategy_master.csv ...\n")

if (!file.exists(PATHS$master_csv)) {
  stop(
    "strategy_master.csv not found at: ", PATHS$master_csv, "\n",
    "Ensure Phase 2 has been run and the file exists at that path."
  )
}

master_raw <- read_csv(
  PATHS$master_csv,
  col_types = cols(.default = col_character()),  # read all as character first
  show_col_types = FALSE
)

cat(sprintf("   Loaded %d rows, %d columns\n", nrow(master_raw), ncol(master_raw)))
cat(sprintf("   Unique FACs: %d\n", n_distinct(master_raw$fac)))


# =============================================================================
# SECTION 3: Parse date fields
# =============================================================================

cat("-- Parsing date fields ...\n")

# plan_period_start and plan_period_end arrive as strings like "20220101",
# "2022-01-01", "January 2022", or NA. We attempt numeric YYYYMMDD parse first,
# then ISO, and retain the raw string for rows that fail both.
.parse_plan_date <- function(x) {
  # Attempt YYYYMMDD integer format
  parsed <- suppressWarnings(as.Date(as.character(x), format = "%Y%m%d"))
  # Attempt ISO yyyy-mm-dd
  iso_attempt <- suppressWarnings(as.Date(as.character(x), format = "%Y-%m-%d"))
  # Attempt 4-digit year only — treat as Jan 1 of that year
  year_only <- suppressWarnings(
    ifelse(grepl("^\\d{4}$", as.character(x)),
           as.character(as.Date(paste0(x, "-01-01"))),
           NA)
  )
  year_only <- as.Date(year_only)
  dplyr::coalesce(parsed, iso_attempt, year_only)
}

master <- master_raw %>%
  mutate(
    # Retain raw strings
    plan_period_start_raw = plan_period_start,
    plan_period_end_raw   = plan_period_end,
    # Parsed dates (NA where unparseable — see plan_period_parse_ok flag)
    plan_period_start     = .parse_plan_date(plan_period_start),
    plan_period_end       = .parse_plan_date(plan_period_end),
    # Flag rows where we got a valid start date
    plan_period_parse_ok  = !is.na(plan_period_start),
    # Derive plan year (year of plan_period_start) for temporal analysis
    plan_start_year       = as.integer(year(plan_period_start)),
    # direction_number to integer
    direction_number      = suppressWarnings(as.integer(direction_number))
  )

n_parsed   <- sum(master$plan_period_parse_ok, na.rm = TRUE)
n_unparsed <- sum(!master$plan_period_parse_ok, na.rm = TRUE)
cat(sprintf("   plan_period_start parsed successfully: %d rows\n", n_parsed))
cat(sprintf("   plan_period_start unparseable / NA:    %d rows\n", n_unparsed))

# Report unparseable raw values so they can be cleaned manually if needed
unparseable_dates <- master %>%
  filter(!plan_period_parse_ok, !is.na(plan_period_start_raw)) %>%
  distinct(fac, plan_period_start_raw) %>%
  arrange(plan_period_start_raw)

if (nrow(unparseable_dates) > 0) {
  cat("   Unparseable plan_period_start values (FAC, raw):\n")
  for (i in seq_len(nrow(unparseable_dates))) {
    cat(sprintf("     FAC %s: '%s'\n",
                unparseable_dates$fac[i],
                unparseable_dates$plan_period_start_raw[i]))
  }
}


# =============================================================================
# SECTION 4: Build hospital spine from registry
# =============================================================================

cat("-- Loading registry ...\n")

if (!file.exists(PATHS$registry_yaml)) {
  stop("registry YAML not found at: ", PATHS$registry_yaml)
}

registry_raw <- yaml.load_file(PATHS$registry_yaml)

# Pull reference fields into a per-hospital data frame
spine_registry <- map(registry_raw$hospitals, function(h) {
  if (isTRUE(h$retired)) return(NULL)
  tibble(
    fac            = as.character(h$FAC),
    hospital_name  = as.character(h$name),
    hospital_type  = as.character(h$hospital_type %||% NA_character_),
    robots_allowed = isTRUE(h$robots_allowed),
    base_url       = as.character(h$base_url %||% NA_character_)
  )
}) |> bind_rows()

# =============================================================================
# SECTION 5: Derive hospital_type_group (collapsed grouping)
# =============================================================================

# The 7 registry types collapse into 5 analytical groups for most comparisons.
# Adjust this mapping as analytical needs evolve.

hospital_type_map <- tribble(
  ~hospital_type,                ~hospital_type_group,
  "Teaching Hospital",           "Teaching",
  "Large Community Hospital",    "Community — Large",
  "Medium Hospital",             "Community — Medium",
  "Small Hospital",              "Community — Small",
  "Chronic/Rehab Hospital",      "Specialty",
  "Specialty Children Hospital", "Specialty",
  "Specialty Mental Health Hospital", "Specialty"
)

spine_registry <- spine_registry %>%
  left_join(hospital_type_map, by = "hospital_type") %>%
  mutate(
    hospital_type_group = if_else(
      is.na(hospital_type_group), "Unknown", hospital_type_group
    )
  )


# =============================================================================
# SECTION 6: Merge optional external reference data (CIHI, beds, etc.)
# =============================================================================

if (file.exists(PATHS$external_ref_csv)) {
  cat("-- Loading external reference data ...\n")

  external_ref <- read_csv(
    PATHS$external_ref_csv,
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )

  # Expect at minimum: fac, cihi_peer_group, licensed_beds
  # Warn if expected columns are missing
  expected_ext_cols <- c("fac", "cihi_peer_group", "licensed_beds")
  missing_ext_cols  <- setdiff(expected_ext_cols, colnames(external_ref))

  if (length(missing_ext_cols) > 0) {
    warning(
      "hospital_reference_external.csv is missing expected columns: ",
      paste(missing_ext_cols, collapse = ", "),
      ". Join will proceed with available columns."
    )
  }

  spine_registry <- spine_registry %>%
    left_join(external_ref, by = "fac")

  cat(sprintf("   External reference joined: %d hospitals matched\n",
              sum(!is.na(spine_registry$cihi_peer_group))))

} else {
  cat("-- No external reference file found at analysis/data/hospital_reference_external.csv\n")
  cat("   Spine will contain registry fields only (hospital_type, robots_allowed).\n")
  cat("   Add CIHI peer group and bed counts here when available.\n")

  # Add placeholder columns so downstream scripts have consistent schema
  spine_registry <- spine_registry %>%
    mutate(
      cihi_peer_group = NA_character_,
      licensed_beds   = NA_integer_
    )
}


# =============================================================================
# SECTION 7: Join master to spine
# =============================================================================

cat("-- Joining master CSV to spine ...\n")

# Check for FACs in master that are absent from the registry
facs_in_master   <- unique(master$fac)
facs_in_registry <- unique(spine_registry$fac)
unmatched_facs   <- setdiff(facs_in_master, facs_in_registry)

if (length(unmatched_facs) > 0) {
  warning(
    length(unmatched_facs), " FAC(s) in strategy_master not found in registry: ",
    paste(unmatched_facs, collapse = ", ")
  )
}

master_analytical <- master %>%
  left_join(spine_registry, by = "fac") %>%
  # Reorder: identifiers first, then plan-level, then direction-level, then metadata
  select(
    # Identifiers
    fac,
    hospital_name,
    hospital_type,
    hospital_type_group,
    robots_allowed,
    cihi_peer_group,
    licensed_beds,
    # Plan-level
    hospital_name_self_reported,
    plan_period_start,
    plan_period_end,
    plan_start_year,
    plan_period_start_raw,
    plan_period_end_raw,
    plan_period_parse_ok,
    vision,
    mission,
    values,
    purpose,
    extraction_quality,
    extraction_notes,
    source_type,
    extraction_date,
    # Direction-level
    direction_number,
    direction_name,
    direction_type,
    direction_description,
    key_actions
  )
# Drop rows for retired FACs (present in strategy_master but excluded from registry)
n_before <- nrow(master_analytical)
master_analytical <- master_analytical %>%
  filter(!is.na(hospital_type_group))
n_dropped <- n_before - nrow(master_analytical)
if (n_dropped > 0) {
  cat(sprintf("   Dropped %d rows for retired FACs (no registry match)\n", n_dropped))
}

cat(sprintf("   Analytical master: %d rows, %d columns\n",
            nrow(master_analytical), ncol(master_analytical)))
cat(sprintf("   Unique FACs in analytical master: %d\n",
            n_distinct(master_analytical$fac)))


# =============================================================================
# SECTION 8: Derive hospital-level summary flags (for spine output)
# =============================================================================

# Build a one-row-per-hospital spine with plan-level summary fields
# Useful for analyses that don't need the direction-level rows

hospital_plan_summary <- master_analytical %>%
  group_by(fac) %>%
  summarise(
    n_directions          = sum(!is.na(direction_name)),
    extraction_quality    = first(extraction_quality),
    plan_period_start     = first(plan_period_start),
    plan_period_end       = first(plan_period_end),
    plan_start_year       = first(plan_start_year),
    plan_period_parse_ok  = first(plan_period_parse_ok),
    has_vision            = !is.na(first(vision)),
    has_mission           = !is.na(first(mission)),
    has_values            = !is.na(first(values)),
    has_purpose           = !is.na(first(purpose)),
    source_type           = first(source_type),
    extraction_date       = first(extraction_date),
    .groups = "drop"
  )

spine_full <- spine_registry %>%
  left_join(hospital_plan_summary, by = "fac") %>%
  mutate(
    has_extraction = !is.na(extraction_quality),
    extraction_quality = if_else(is.na(extraction_quality), "no_data", extraction_quality)
  ) %>%
  arrange(fac)

cat(sprintf("   Hospital spine: %d rows\n", nrow(spine_full)))


# =============================================================================
# SECTION 9: Write outputs
# =============================================================================

cat("-- Writing outputs ...\n")

write_csv(master_analytical, PATHS$analytical_csv)
cat(sprintf("   Written: %s\n", PATHS$analytical_csv))

write_csv(spine_full, PATHS$spine_csv)
cat(sprintf("   Written: %s\n", PATHS$spine_csv))


# =============================================================================
# SECTION 10: Diagnostic summary
# =============================================================================

cat("\n========== PREPARE DATA SUMMARY ==========\n")
cat(sprintf("  Hospitals in registry:              %d\n", nrow(spine_registry)))
cat(sprintf("  Hospitals with extraction data:     %d\n", sum(spine_full$has_extraction)))
cat(sprintf("  Total direction rows:               %d\n", sum(!is.na(master_analytical$direction_name))))
cat("\n  Extraction quality breakdown (hospitals):\n")
spine_full %>%
  count(extraction_quality) %>%
  arrange(desc(n)) %>%
  { cat(paste0("    ", .$extraction_quality, ": ", .$n, "\n")); . } %>%
  invisible()

cat("\n  Hospital type breakdown:\n")
spine_full %>%
  count(hospital_type_group) %>%
  arrange(desc(n)) %>%
  { cat(paste0("    ", .$hospital_type_group, ": ", .$n, "\n")); . } %>%
  invisible()

cat("\n  Plan start year distribution (parsed rows):\n")
master_analytical %>%
  filter(plan_period_parse_ok) %>%
  distinct(fac, plan_start_year) %>%
  count(plan_start_year) %>%
  arrange(plan_start_year) %>%
  { cat(paste0("    ", .$plan_start_year, ": ", .$n, " hospitals\n")); . } %>%
  invisible()

cat("\n  Robots-blocked hospitals: ")
cat(sum(!spine_full$robots_allowed, na.rm = TRUE), "\n")
cat("==========================================\n")

# Make objects available in the calling environment
master    <<- master_analytical
spine     <<- spine_full

cat("\nObjects available: 'master' (direction-level), 'spine' (hospital-level)\n")
