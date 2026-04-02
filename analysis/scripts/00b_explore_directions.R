# =============================================================================
# analysis/scripts/00b_explore_directions.R
# HospitalIntelligenceR — Direction Name Landscape Exploration
#
# PURPOSE:
#   Examine the raw direction_name landscape before designing the thematic
#   taxonomy. Output is for human review only — not an analytical deliverable.
#   Run this once, review the output, then design the taxonomy.
#
# OUTPUTS:
#   analysis/outputs/tables/00b_direction_names_frequency.csv
#   analysis/outputs/tables/00b_direction_sample_full.csv   [name + desc + actions]
#   Console: frequency table, coverage stats, NA summary
#
# USAGE:
#   source("analysis/scripts/00_prepare_data.R")   # if not already run
#   source("analysis/scripts/00b_explore_directions.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(readr)
})


# =============================================================================
# SECTION 1: Load data
# =============================================================================

if (!exists("master")) {
  message("'master' not found in environment — loading from CSV.")
  master <- read_csv(
    "analysis/data/strategy_master_analytical.csv",
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )
}

# Work only with usable rows — full/partial, robots-allowed, has a direction
directions <- master %>%
  filter(
    robots_allowed == TRUE,
    extraction_quality %in% c("full", "partial"),
    !is.na(direction_name)
  )

cat(sprintf("Direction rows available for classification: %d\n", nrow(directions)))
cat(sprintf("Unique hospitals represented:               %d\n\n",
            n_distinct(directions$fac)))


# =============================================================================
# SECTION 2: Direction name frequency table
# =============================================================================

# Normalise for frequency counting — lowercase, trim whitespace
# Keep original for display
name_freq <- directions %>%
  mutate(name_normalised = str_squish(str_to_lower(direction_name))) %>%
  group_by(direction_name, name_normalised) %>%
  summarise(
    n_hospitals    = n_distinct(fac),
    n_rows         = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(n_hospitals), direction_name)

cat(sprintf("Unique direction names (exact):      %d\n", nrow(name_freq)))
cat(sprintf("Names appearing in only 1 hospital:  %d (%.0f%%)\n",
            sum(name_freq$n_hospitals == 1),
            100 * mean(name_freq$n_hospitals == 1)))
cat(sprintf("Names appearing in 2+ hospitals:     %d\n",
            sum(name_freq$n_hospitals >= 2)))
cat(sprintf("Names appearing in 5+ hospitals:     %d\n\n",
            sum(name_freq$n_hospitals >= 5)))

cat("=== Top 40 direction names by hospital count ===\n")
print(as.data.frame(name_freq %>% select(direction_name, n_hospitals) %>% head(40)))
cat("\n")


# =============================================================================
# SECTION 3: NA / missing field coverage
# =============================================================================

cat("=== Field coverage across direction rows ===\n")
cat(sprintf("  direction_name populated:        %d / %d (%.0f%%)\n",
            sum(!is.na(directions$direction_name)), nrow(directions),
            100 * mean(!is.na(directions$direction_name))))
cat(sprintf("  direction_description populated: %d / %d (%.0f%%)\n",
            sum(!is.na(directions$direction_description)), nrow(directions),
            100 * mean(!is.na(directions$direction_description))))
cat(sprintf("  key_actions populated:           %d / %d (%.0f%%)\n",
            sum(!is.na(directions$key_actions)), nrow(directions),
            100 * mean(!is.na(directions$key_actions))))

# Rows where name is present but both description AND actions are NA
name_only_rows <- directions %>%
  filter(!is.na(direction_name),
         is.na(direction_description),
         is.na(key_actions))

cat(sprintf("  Rows with name only (desc+actions both NA): %d (%.0f%%)\n\n",
            nrow(name_only_rows),
            100 * nrow(name_only_rows) / nrow(directions)))


# =============================================================================
# SECTION 4: Sample of full rows — name + description + actions
# Useful for taxonomy design — shows what each direction actually contains
# =============================================================================

# One representative row per unique direction name (most common first)
direction_sample <- directions %>%
  mutate(name_normalised = str_squish(str_to_lower(direction_name))) %>%
  left_join(
    name_freq %>% select(name_normalised, n_hospitals),
    by = "name_normalised"
  ) %>%
  arrange(desc(n_hospitals), direction_name) %>%
  group_by(direction_name) %>%
  slice(1) %>%
  ungroup() %>%
  select(
    n_hospitals,
    fac,
    hospital_type_group,
    direction_name,
    direction_type,
    direction_description,
    key_actions
  ) %>%
  arrange(desc(n_hospitals), direction_name)

cat(sprintf("Sample file: %d unique direction names with full context\n\n",
            nrow(direction_sample)))


# =============================================================================
# SECTION 5: Write outputs
# =============================================================================

dir.create("analysis/outputs/tables", recursive = TRUE, showWarnings = FALSE)

write_csv(name_freq,        "analysis/outputs/tables/00b_direction_names_frequency.csv")
write_csv(direction_sample, "analysis/outputs/tables/00b_direction_sample_full.csv")

cat("Written:\n")
cat("  analysis/outputs/tables/00b_direction_names_frequency.csv\n")
cat("  analysis/outputs/tables/00b_direction_sample_full.csv\n\n")

cat("NEXT STEP: Open 00b_direction_sample_full.csv and review.\n")
cat("Use it to design the 8-12 theme taxonomy before building the classifier.\n")