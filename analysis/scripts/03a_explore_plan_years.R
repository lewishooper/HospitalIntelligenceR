
# =============================================================================
# analysis/scripts/03a_explore_plan_years.R
# HospitalIntelligenceR — Direction 3 Preflight: Plan Year Distribution
#
# PURPOSE:
#   Exploratory analysis of plan_period_start year distribution before building
#   the temporal theme trend analysis. Confirms whether there is sufficient
#   spread and volume across years to support a credible trend analysis.
#
# QUESTIONS:
#   - How are hospitals distributed across plan start years?
#   - Is there sufficient volume in each year to support theme analysis?
#   - Which hospitals have missing or suspect plan start dates?
#   - Does year distribution vary by hospital type group?
#
# OUTPUTS:
#   analysis/outputs/tables/03a_plan_year_distribution.csv
#   analysis/outputs/tables/03a_plan_year_by_type.csv
#   analysis/outputs/tables/03a_missing_or_suspect_dates.csv
#   analysis/outputs/figures/03a_plan_year_histogram.png
#   analysis/outputs/figures/03a_plan_year_by_type.png
#
# DEPENDENCIES:
#   Requires 'spine' in environment (from 00_prepare_data.R)
#   OR will load analysis/data/hospital_spine.csv directly.
#
# USAGE:
#   source("analysis/scripts/00_prepare_data.R")   # if not already run
#   source("analysis/scripts/03a_explore_plan_years.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(tidyr)
  library(stringr)
})


# =============================================================================
# SECTION 1: Load data
# =============================================================================

if (!exists("spine")) {
  message("'spine' not found in environment — loading from CSV.")
  spine <- read_csv(
    "analysis/data/hospital_spine.csv",
    col_types = cols(
      .default         = col_character(),
      robots_allowed   = col_logical(),
      has_extraction   = col_logical(),
      has_vision       = col_logical(),
      has_mission      = col_logical(),
      has_values       = col_logical(),
      has_purpose      = col_logical(),
      plan_period_parse_ok = col_logical(),
      n_directions     = col_integer(),
      plan_start_year  = col_integer()
    ),
    show_col_types = FALSE
  )
}

cat(sprintf("Spine loaded: %d hospitals\n", nrow(spine)))


# =============================================================================
# SECTION 2: Analytical cohort — same exclusions as 01a/01b
# =============================================================================

# Collapse Community — Medium into Community — Large (n=1)
spine_all <- spine %>%
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

# Usable cohort: robots-allowed, full/partial extraction
spine_usable <- spine_all %>%
  filter(
    robots_allowed == TRUE,
    extraction_quality %in% c("full", "partial")
  )

cat(sprintf("Usable cohort (full/partial, robots-allowed): %d hospitals\n\n",
            nrow(spine_usable)))


# =============================================================================
# SECTION 3: Flag missing and suspect plan start years
# =============================================================================

# Missing: plan_start_year is NA
missing_year <- spine_usable %>%
  filter(is.na(plan_start_year)) %>%
  select(fac, hospital_name, hospital_type_group,
         plan_period_start, plan_period_parse_ok, extraction_quality)

# Suspect: years outside the plausible 2018–2026 window
# (pre-2018 plans are likely stale; post-2026 are likely data entry errors)
suspect_year <- spine_usable %>%
  filter(!is.na(plan_start_year)) %>%
  filter(plan_start_year < 2018 | plan_start_year > 2026) %>%
  select(fac, hospital_name, hospital_type_group, plan_start_year,
         plan_period_start, extraction_quality)

cat("=== Missing plan start year ===\n")
if (nrow(missing_year) == 0) {
  cat("None — all usable hospitals have a parseable plan start year.\n\n")
} else {
  print(as.data.frame(missing_year))
  cat("\n")
}

cat("=== Suspect plan start year (outside 2018–2026) ===\n")
if (nrow(suspect_year) == 0) {
  cat("None — all years within plausible window.\n\n")
} else {
  print(as.data.frame(suspect_year))
  cat("\n")
}


# =============================================================================
# SECTION 4: Year distribution — overall
# =============================================================================

# Restrict to plausible window for distribution analysis
# Flag outliers separately rather than silently dropping
YEAR_MIN <- 2018
YEAR_MAX <- 2026

spine_dated <- spine_usable %>%
  filter(!is.na(plan_start_year)) %>%
  mutate(
    year_in_window = plan_start_year >= YEAR_MIN & plan_start_year <= YEAR_MAX
  )

spine_windowed <- spine_dated %>% filter(year_in_window)
spine_outliers <- spine_dated %>% filter(!year_in_window)

year_dist <- spine_windowed %>%
  count(plan_start_year, name = "n_hospitals") %>%
  arrange(plan_start_year) %>%
  mutate(
    pct          = round(100 * n_hospitals / sum(n_hospitals), 1),
    cum_pct      = round(cumsum(n_hospitals) / sum(n_hospitals) * 100, 1),
    # Flag years with fewer than 10 hospitals — may be too thin for theme analysis
    thin_year    = n_hospitals < 10
  )

cat("=== Plan start year distribution (usable cohort, 2018–2026 window) ===\n")
print(as.data.frame(year_dist))
cat(sprintf("\nTotal in window: %d hospitals\n", sum(year_dist$n_hospitals)))
cat(sprintf("Outliers excluded from window: %d hospitals\n", nrow(spine_outliers)))
if (nrow(spine_outliers) > 0) {
  cat("  FACs excluded:\n")
  spine_outliers %>%
    select(fac, hospital_name, plan_start_year, plan_period_start) %>%
    { cat(paste0("    FAC ", .$fac, " (", .$hospital_name, "): ",
                 .$plan_start_year, " [parsed: ", .$plan_period_start, "]\n")); . } %>%
    invisible()
}
cat("\n")


# =============================================================================
# SECTION 5: Year distribution by hospital type
# =============================================================================

year_by_type <- spine_windowed %>%
  count(type_group, plan_start_year, name = "n_hospitals") %>%
  pivot_wider(
    names_from  = plan_start_year,
    values_from = n_hospitals,
    values_fill = 0
  ) %>%
  arrange(type_group)

cat("=== Plan start year by hospital type ===\n")
print(as.data.frame(year_by_type))
cat("\n")


# =============================================================================
# SECTION 6: Feasibility assessment
# =============================================================================

cat("=== Temporal feasibility assessment ===\n")

# For theme trend analysis we need sufficient hospitals per year
# Minimum threshold: 10 hospitals per year-point for stable percentages
n_years_sufficient <- sum(year_dist$n_hospitals >= 10)
n_years_thin       <- sum(year_dist$n_hospitals < 10 & year_dist$n_hospitals > 0)

cat(sprintf("  Years with >= 10 hospitals: %d\n", n_years_sufficient))
cat(sprintf("  Years with < 10 hospitals:  %d (may need grouping)\n", n_years_thin))

# Suggest banding if individual years are thin
# e.g. group into Pre-2021, 2021, 2022, 2023, 2024, 2025+
if (n_years_thin > 0) {
  cat("\n  Thin years (< 10 hospitals):\n")
  year_dist %>%
    filter(thin_year) %>%
    { cat(paste0("    ", .$plan_start_year, ": n=", .$n_hospitals, "\n")); . } %>%
    invisible()
  cat("\n  Consider banding thin years into a combined group (e.g. '2018–2020')\n")
  cat("  before proceeding with theme trend analysis.\n")
}

cat("\n")


# =============================================================================
# SECTION 7: Write tables
# =============================================================================

dir.create("analysis/outputs/tables", recursive = TRUE, showWarnings = FALSE)

write_csv(year_dist,    "analysis/outputs/tables/03a_plan_year_distribution.csv")
write_csv(year_by_type, "analysis/outputs/tables/03a_plan_year_by_type.csv")

# Missing/suspect flags — always write even if empty (useful as a record)
write_csv(missing_year, "analysis/outputs/tables/03a_missing_dates.csv")
write_csv(suspect_year, "analysis/outputs/tables/03a_suspect_dates.csv")

cat("Tables written to analysis/outputs/tables/\n\n")


# =============================================================================
# SECTION 8: Chart 1 — Overall year histogram
# =============================================================================

dir.create("analysis/outputs/figures", recursive = TRUE, showWarnings = FALSE)

p_hist <- ggplot(
  spine_windowed,
  aes(x = plan_start_year)
) +
  geom_bar(fill = "#2171B5", width = 0.7) +
  geom_text(
    stat  = "count",
    aes(label = after_stat(count)),
    vjust = -0.5,
    size  = 3.5,
    colour = "grey20"
  ) +
  scale_x_continuous(
    breaks = YEAR_MIN:YEAR_MAX
  ) +
  scale_y_continuous(
    limits = c(0, NA),
    expand = expansion(mult = c(0, 0.15))
  ) +
  labs(
    title    = "Distribution of Strategic Plan Start Years",
    subtitle = sprintf(
      "Ontario hospitals — usable cohort (n=%d, full/partial extractions, robots-allowed)\n%d–%d window shown; %d outlier(s) excluded",
      nrow(spine_windowed), YEAR_MIN, YEAR_MAX, nrow(spine_outliers)
    ),
    x       = "Plan period start year",
    y       = "Number of hospitals",
    caption = "Source: HospitalIntelligenceR hospital_registry.yaml + Phase 2 extraction."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(colour = "grey40", size = 8),
    plot.caption  = element_text(colour = "grey50", size = 6.5),
    panel.grid.major.x = element_blank(),
    panel.grid.minor   = element_blank(),
    axis.text.x   = element_text(size = 9)
  )

ggsave(
  "analysis/outputs/figures/03a_plan_year_histogram.png",
  plot   = p_hist,
  width  = 8,
  height = 5,
  dpi    = 300
)
cat("Figure saved: 03a_plan_year_histogram.png\n")


# =============================================================================
# SECTION 9: Chart 2 — Year distribution by hospital type (stacked bar)
# =============================================================================

year_type_long <- spine_windowed %>%
  count(type_group, plan_start_year, name = "n_hospitals")

p_type_year <- ggplot(
  year_type_long,
  aes(x = plan_start_year, y = n_hospitals, fill = type_group)
) +
  geom_col(width = 0.7, colour = "white", linewidth = 0.3) +
  scale_fill_manual(
    values = c(
      "Teaching"          = "#08519C",
      "Community — Large" = "#2171B5",
      "Community — Small" = "#6BAED6",
      "Specialty"         = "#BDD7E7"
    ),
    name = "Hospital type"
  ) +
  scale_x_continuous(breaks = YEAR_MIN:YEAR_MAX) +
  scale_y_continuous(
    limits = c(0, NA),
    expand = expansion(mult = c(0, 0.1))
  ) +
  labs(
    title    = "Plan Start Year Distribution by Hospital Type",
    subtitle = sprintf(
      "Ontario hospitals — usable cohort (n=%d) | %d–%d window",
      nrow(spine_windowed), YEAR_MIN, YEAR_MAX
    ),
    x       = "Plan period start year",
    y       = "Number of hospitals",
    caption = "Source: HospitalIntelligenceR hospital_registry.yaml + Phase 2 extraction."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(colour = "grey40", size = 8),
    plot.caption  = element_text(colour = "grey50", size = 6.5),
    panel.grid.major.x = element_blank(),
    panel.grid.minor   = element_blank(),
    axis.text.x   = element_text(size = 9),
    legend.position = "right"
  )

ggsave(
  "analysis/outputs/figures/03a_plan_year_by_type.png",
  plot   = p_type_year,
  width  = 8,
  height = 5,
  dpi    = 300
)
cat("Figure saved: 03a_plan_year_by_type.png\n")

cat("\nDone. Review year distribution before proceeding to 03b_theme_trends.R\n")
cat("Key decision: are any years thin enough to require banding?\n")