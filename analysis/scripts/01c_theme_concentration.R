# =============================================================================
# analysis/scripts/01c_theme_concentration.R
# HospitalIntelligenceR — Direction 1c: Theme Concentration by Hospital Type
#
# QUESTION:
#   What fraction of hospitals in each type group have at least one strategic
#   direction touching each theme? This is a hospital-level prevalence view,
#   distinct from 01b which reports the direction-level share of themes.
#
#   The key distinction: 01b answers "what fraction of Teaching directions are
#   WRK?" This script answers "what fraction of Teaching hospitals have any
#   WRK direction?" These are different questions and produce meaningfully
#   different numbers — a theme can represent a small share of directions but
#   still appear in the majority of hospitals (e.g. WRK is ~14% of Teaching
#   directions but present in ~88% of Teaching hospitals).
#
# APPROACH:
#   Two versions of the concentration table are produced:
#
#   (A) PRIMARY ONLY — counts a hospital as "touching" a theme only if at
#       least one direction has that theme as its primary classification.
#       Consistent with 01b, 03b, 03c (all primary-only).
#
#   (B) PRIMARY + SECONDARY — counts a hospital as "touching" a theme if any
#       direction has it as primary OR secondary. Wider net; surfaces themes
#       that commonly appear as secondary concerns. GOV appears only here
#       (as a secondary theme in a small subset of Small Community hospitals).
#
#   The primary+secondary version is the main publication table.
#   The primary-only version is retained for consistency checks.
#
# OUTPUTS:
#   analysis/outputs/tables/01c_theme_concentration_primary.csv     [version A]
#   analysis/outputs/tables/01c_theme_concentration_any.csv         [version B — main]
#   analysis/outputs/tables/01c_theme_concentration_wide.csv        [B, wide — for publication]
#
# DEPENDENCIES:
#   Requires 'strategy_classified' in environment (from 00c_build_strategy_classified.R)
#   OR will load analysis/data/strategy_classified.csv directly if not found.
#
# USAGE:
#   source("analysis/scripts/00_prepare_data.R")               # if not already run
#   source("analysis/scripts/00c_build_strategy_classified.R") # if not already run
#   source("analysis/scripts/01c_theme_concentration.R")
#
# NOTES:
#   - GOV was retired as a primary classification code (0 legitimate primary
#     directions). It appears only in version B, exclusively as a secondary
#     theme in a small number of Small Community hospitals. This is an
#     authentic finding and is retained in the primary+secondary output.
#   - Same analytical cohort as 01a/01b: full/partial extractions, robots-allowed.
#   - Community — Medium (n=1) is collapsed into Community — Large throughout.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
})


# =============================================================================
# SECTION 1: Load data
# =============================================================================

if (!exists("strategy_classified")) {
  message("'strategy_classified' not found in environment — loading from CSV.")
  strategy_classified <- read_csv(
    "analysis/data/strategy_classified.csv",
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )
}


# =============================================================================
# SECTION 2: Build analytical cohort
# =============================================================================

# Identical filter and type_group recode as 01b
classified <- strategy_classified %>%
  filter(
    robots_allowed        == "TRUE",
    extraction_quality    %in% c("full", "partial"),
    !is.na(primary_theme),
    classification_status == "ok"
  ) %>%
  mutate(
    type_group = case_when(
      hospital_type_group == "Community — Medium" ~ "Community — Large",
      TRUE                                        ~ hospital_type_group
    ),
    type_group = factor(type_group, levels = c(
      "Teaching",
      "Community — Large",
      "Community — Small",
      "Specialty"
    ))
  )

n_directions <- nrow(classified)
n_hospitals  <- n_distinct(classified$fac)

cat(sprintf("Analytical cohort: %d directions across %d hospitals\n",
            n_directions, n_hospitals))
cat("Hospital type breakdown:\n")
print(table(classified$type_group))


# =============================================================================
# SECTION 3: Hospital-level totals by type group
# =============================================================================

# One row per hospital — needed as denominators throughout
hospital_roster <- classified %>%
  distinct(fac, type_group)

type_totals <- hospital_roster %>%
  count(type_group, name = "n_hospitals")

cat("\nHospital counts by type group (denominators):\n")
print(as.data.frame(type_totals))


# =============================================================================
# SECTION 4: Theme sets — long tables
#
# Strategy: expand to one row per hospital × theme for each version.
# Using bind_rows + distinct avoids list-columns entirely.
# =============================================================================

# --- Version A: Primary themes only ---
# One row per hospital × primary_theme (deduplicated — a hospital with two WRK
# directions still counts once for WRK)
primary_long <- classified %>%
  filter(!is.na(primary_theme)) %>%
  distinct(fac, type_group, theme = primary_theme)

# --- Version B: Primary + secondary ---
# Union of primary and secondary theme appearances per hospital
secondary_long <- classified %>%
  filter(!is.na(secondary_theme)) %>%
  distinct(fac, type_group, theme = secondary_theme)

any_long <- bind_rows(primary_long, secondary_long) %>%
  distinct(fac, type_group, theme)    # deduplicate: theme counts once per hospital


# =============================================================================
# SECTION 5: Concentration tables — long format
# =============================================================================

# Full theme x type_group grid for zero-filling
# Include GOV so it shows in version B output
ALL_THEMES <- c("ACC", "EDI", "FIN", "GOV", "INF", "INN", "ORG", "PAR", "PAT", "RES", "WRK")
type_levels <- levels(classified$type_group)

full_grid <- expand.grid(
  type_group = factor(type_levels, levels = type_levels),
  theme      = ALL_THEMES,
  stringsAsFactors = FALSE
)

# --- Version A: primary only ---
conc_primary <- primary_long %>%
  count(type_group, theme, name = "n_hospitals_with_theme") %>%
  right_join(full_grid, by = c("type_group", "theme")) %>%
  mutate(n_hospitals_with_theme = coalesce(n_hospitals_with_theme, 0L)) %>%
  left_join(type_totals, by = "type_group") %>%
  mutate(
    pct_hospitals = round(100 * n_hospitals_with_theme / n_hospitals, 1),
    version       = "primary_only"
  ) %>%
  arrange(type_group, theme)

# --- Version B: primary + secondary ---
conc_any <- any_long %>%
  count(type_group, theme, name = "n_hospitals_with_theme") %>%
  right_join(full_grid, by = c("type_group", "theme")) %>%
  mutate(n_hospitals_with_theme = coalesce(n_hospitals_with_theme, 0L)) %>%
  left_join(type_totals, by = "type_group") %>%
  mutate(
    pct_hospitals = round(100 * n_hospitals_with_theme / n_hospitals, 1),
    version       = "primary_and_secondary"
  ) %>%
  arrange(type_group, theme)


# =============================================================================
# SECTION 6: Console output — both versions side by side
# =============================================================================

# Wide format helper for printing
make_wide <- function(conc_df) {
  conc_df %>%
    select(theme, type_group, pct_hospitals) %>%
    pivot_wider(
      names_from  = type_group,
      values_from = pct_hospitals,
      values_fill = 0
    ) %>%
    arrange(theme)
}

wide_primary <- make_wide(conc_primary)
wide_any     <- make_wide(conc_any)

# Column header line showing n per type group
header_line <- type_totals %>%
  mutate(label = sprintf("%s (n=%d)", type_group, n_hospitals)) %>%
  pull(label) %>%
  paste(collapse = " | ")

cat("\n========== THEME CONCENTRATION: PRIMARY THEMES ONLY ==========\n")
cat("  % of hospitals in each type group with >=1 direction in theme\n")
cat(sprintf("  Columns: %s\n\n", header_line))
print(as.data.frame(wide_primary), row.names = FALSE)

cat("\n========== THEME CONCENTRATION: PRIMARY + SECONDARY THEMES ==========\n")
cat("  % of hospitals in each type group with >=1 direction in theme (primary or secondary)\n")
cat(sprintf("  Columns: %s\n\n", header_line))
print(as.data.frame(wide_any), row.names = FALSE)

# GOV callout — always print even if zero everywhere
gov_any <- conc_any %>%
  filter(theme == "GOV") %>%
  select(type_group, n_hospitals_with_theme, n_hospitals, pct_hospitals)

cat("\n  GOV (secondary theme appearances only — no primary GOV directions exist):\n")
for (i in seq_len(nrow(gov_any))) {
  if (gov_any$n_hospitals_with_theme[i] > 0) {
    cat(sprintf("    %-22s  %d of %d hospitals  (%.1f%%)\n",
                as.character(gov_any$type_group[i]),
                gov_any$n_hospitals_with_theme[i],
                gov_any$n_hospitals[i],
                gov_any$pct_hospitals[i]))
  } else {
    cat(sprintf("    %-22s  0 hospitals\n",
                as.character(gov_any$type_group[i])))
  }
}

# Notable differentials in the primary+secondary table
cat("\n  Notable differentials in primary+secondary table (max - min >= 15 pp):\n")
differentials <- conc_any %>%
  filter(theme != "GOV") %>%
  group_by(theme) %>%
  summarise(
    max_pct    = max(pct_hospitals),
    min_pct    = min(pct_hospitals),
    range_pp   = max_pct - min_pct,
    high_group = as.character(type_group[which.max(pct_hospitals)]),
    low_group  = as.character(type_group[which.min(pct_hospitals)]),
    .groups    = "drop"
  ) %>%
  filter(range_pp >= 15) %>%
  arrange(desc(range_pp))

if (nrow(differentials) > 0) {
  for (i in seq_len(nrow(differentials))) {
    cat(sprintf("    %-5s  range=%.0f pp  high=%s (%.0f%%)  low=%s (%.0f%%)\n",
                differentials$theme[i],
                differentials$range_pp[i],
                differentials$high_group[i],
                differentials$max_pct[i],
                differentials$low_group[i],
                differentials$min_pct[i]))
  }
} else {
  cat("    No theme shows >= 15 pp differential across groups.\n")
}

cat("=====================================================================\n")


# =============================================================================
# SECTION 7: Write outputs
# =============================================================================

dir.create("analysis/outputs/tables", recursive = TRUE, showWarnings = FALSE)

# Long format — both versions
write_csv(conc_primary, "analysis/outputs/tables/01c_theme_concentration_primary.csv")
write_csv(conc_any,     "analysis/outputs/tables/01c_theme_concentration_any.csv")

# Wide format of version B — publication table
# Embed n_hospitals in column names for self-documentation
wide_any_pub <- wide_any
type_n_lookup <- setNames(type_totals$n_hospitals,
                          as.character(type_totals$type_group))
new_colnames <- c("theme", sprintf("%s (n=%d)",
                                   type_levels,
                                   type_n_lookup[type_levels]))
colnames(wide_any_pub) <- new_colnames

write_csv(wide_any_pub, "analysis/outputs/tables/01c_theme_concentration_wide.csv")

cat("\nOutputs written:\n")
cat("  analysis/outputs/tables/01c_theme_concentration_primary.csv\n")
cat("  analysis/outputs/tables/01c_theme_concentration_any.csv\n")
cat("  analysis/outputs/tables/01c_theme_concentration_wide.csv\n")