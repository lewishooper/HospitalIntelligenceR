# =============================================================================
# analysis/scripts/00c_build_strategy_classified.R
# HospitalIntelligenceR — Strategy Classification Merged View
#
# PURPOSE:
#   Build a single flat table merging strategy_master_analytical.csv with
#   theme_classifications.csv for review and ad-hoc analysis. Avoids the
#   need to look in two places when reviewing classification output.
#
# STATUS:
#   Temporary review utility. Will be promoted to a tracked analytical asset
#   once the taxonomy is finalised and any manual corrections are applied.
#
# INPUTS:
#   analysis/data/strategy_master_analytical.csv   [canonical analytical master]
#   analysis/data/theme_classifications.csv        [thematic classification output]
#
# OUTPUTS:
#   analysis/data/strategy_classified.csv          [merged flat table — NOT git tracked]
#
# USAGE:
#   source("analysis/scripts/00c_build_strategy_classified.R")
#   # Inspect: glimpse(strategy_classified)
#   # Filter example: strategy_classified %>% filter(primary_theme == "ORG")
#
# NOTES:
#   - Join key: fac + direction_number (both character)
#   - Rows in master with no classification (thin/no_data hospitals, robots-blocked)
#     are retained with NA theme fields — use left_join intentionally
#   - Column order: identifiers first, then hospital context, then direction
#     content, then classification fields
#   - Re-run any time either input file changes
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})


# =============================================================================
# SECTION 1: Paths
# =============================================================================

PATHS <- list(
  master         = "analysis/data/strategy_master_analytical.csv",
  classifications = "analysis/data/theme_classifications.csv",
  output         = "analysis/data/strategy_classified.csv"
)


# =============================================================================
# SECTION 2: Load inputs
# =============================================================================

master <- read_csv(
  PATHS$master,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)

classifications <- read_csv(
  PATHS$classifications,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)

cat(sprintf("master:          %d rows, %d cols\n", nrow(master), ncol(master)))
cat(sprintf("classifications: %d rows, %d cols\n", nrow(classifications), ncol(classifications)))


# =============================================================================
# SECTION 3: Merge
# =============================================================================

# Classification columns to bring across — drop row_id and direction_name
# (already in master) to avoid duplication
classify_cols <- classifications %>%
  select(
    fac,
    direction_number,
    primary_theme,
    secondary_theme,
    classification_confidence,
    classified_on,
    classification_notes,
    classification_status
  )

# Left join: all master rows retained; unclassified rows get NA theme fields
strategy_classified <- master %>%
  left_join(classify_cols, by = c("fac", "direction_number"))


# =============================================================================
# SECTION 4: Column reorder — identifiers, context, content, classification
# =============================================================================

id_cols      <- c("fac", "hospital_name", "hospital_type", "hospital_type_group",
                  "direction_number", "direction_name")
content_cols <- c("direction_description", "key_actions")
plan_cols    <- c("plan_name", "plan_period_start", "plan_period_end",
                  "plan_period_start_raw", "plan_period_end_raw")
classify_out <- c("primary_theme", "secondary_theme", "classification_confidence",
                  "classified_on", "classification_notes", "classification_status")

# Remaining columns (extraction metadata etc.) appended at end
remaining <- setdiff(names(strategy_classified),
                     c(id_cols, content_cols, plan_cols, classify_out))

strategy_classified <- strategy_classified %>%
  select(
    any_of(id_cols),
    any_of(content_cols),
    any_of(plan_cols),
    any_of(classify_out),
    any_of(remaining)
  )


# =============================================================================
# SECTION 5: Write output
# =============================================================================

dir.create("analysis/data", recursive = TRUE, showWarnings = FALSE)
write_csv(strategy_classified, PATHS$output)

cat(sprintf("\nWritten: %s\n", PATHS$output))
cat(sprintf("Rows:    %d\n", nrow(strategy_classified)))
cat(sprintf("Cols:    %d\n", ncol(strategy_classified)))


# =============================================================================
# SECTION 6: Quick summary
# =============================================================================

classified_rows <- strategy_classified %>%
  filter(!is.na(primary_theme))

cat(sprintf("\nClassified rows: %d of %d\n",
            nrow(classified_rows), nrow(strategy_classified)))

cat("\nPrimary theme distribution (classified rows):\n")
classified_rows %>%
  count(primary_theme, sort = TRUE) %>%
  mutate(pct = round(n / sum(n) * 100, 1)) %>%
  { cat(paste0("  ", .$primary_theme, ": ", .$n, " (", .$pct, "%)\n")); . } %>%
  invisible()

cat("\nUnclassified rows by reason:\n")
strategy_classified %>%
  filter(is.na(primary_theme)) %>%
  count(extraction_quality, robots_allowed, sort = TRUE) %>%
  { cat(paste0("  quality=", .$extraction_quality,
               " robots=", .$robots_allowed,
               ": ", .$n, "\n")); . } %>%
  invisible()

# Make available in environment
strategy_classified <<- strategy_classified

cat("\nDone. Use strategy_classified for all review work.\n")
cat("Example filters:\n")
cat("  strategy_classified %>% filter(primary_theme == 'GOV')\n")
cat("  strategy_classified %>% filter(primary_theme == 'ORG') %>% select(fac, hospital_name, hospital_type_group, direction_name, direction_description, classification_notes)\n")
cat("  strategy_classified %>% filter(primary_theme == 'RES', hospital_type_group != 'Teaching')\n")
