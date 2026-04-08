# =============================================================================
# analysis/scripts/03c_theme_by_era_type.R
# HospitalIntelligenceR — Direction 3c: Era × Hospital Type Interaction
#
# QUESTION:
#   Do the thematic shifts identified in 03b hold uniformly across hospital
#   types, or are they concentrated in specific segments?
#   Specifically:
#   (a) Does WRK's rise (67% → 94% Pre-COVID to Current) hold across all
#       four hospital type groups?
#   (b) Does RES's V-shape (25% → 9% → 38%) persist after accounting for
#       the composition of hospital types within each era?
#
# DESIGN NOTE:
#   Teaching hospitals include paediatric-specialty hospitals (e.g., SickKids).
#   Specialty hospitals include Chronic & Rehab and Specialty Mental Health.
#   These groups are not general acute hospitals and may show structurally
#   different thematic profiles. Findings for these groups should be interpreted
#   with awareness of their distinct mandates.
#
# APPROACH:
#   - Same analytical cohort and era assignment as 03b
#   - Prevalence metric: % of hospitals in each era × type cell with >= 1
#     direction in that theme (hospital prevalence, not direction count)
#   - Primary outputs: WRK and RES interaction tables + full 10-theme heatmaps
#     faceted by hospital type
#   - Secondary: era composition by hospital type (composition check table)
#
# OUTPUTS:
#   analysis/outputs/tables/03c_era_type_composition.csv
#   analysis/outputs/tables/03c_wrk_res_interaction.csv
#   analysis/outputs/tables/03c_theme_prevalence_era_type.csv
#   analysis/outputs/figures/03c_wrk_interaction.png
#   analysis/outputs/figures/03c_res_interaction.png
#   analysis/outputs/figures/03c_heatmap_by_type.png
#
# DEPENDENCIES:
#   Requires 'strategy_classified' in environment (from 00c_build_strategy_classified.R)
#   Requires 'spine' in environment (from 00_prepare_data.R)
#   OR will load from CSV directly.
#
# USAGE:
#   source("analysis/scripts/00_prepare_data.R")
#   source("analysis/scripts/00c_build_strategy_classified.R")
#   source("analysis/scripts/03c_theme_by_era_type.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(tidyr)
  library(stringr)
  library(forcats)
})


# =============================================================================
# SECTION 1: Load data
# =============================================================================

if (!exists("strategy_classified")) {
  message("'strategy_classified' not found — loading from CSV.")
  strategy_classified <- read_csv(
    "analysis/data/strategy_classified.csv",
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )
}

if (!exists("spine")) {
  message("'spine' not found — loading from CSV.")
  spine <- read_csv(
    "analysis/data/hospital_spine.csv",
    col_types = cols(
      .default             = col_character(),
      robots_allowed       = col_logical(),
      has_extraction       = col_logical(),
      has_vision           = col_logical(),
      has_mission          = col_logical(),
      has_values           = col_logical(),
      has_purpose          = col_logical(),
      plan_period_parse_ok = col_logical(),
      n_directions         = col_integer(),
      plan_start_year      = col_integer()
    ),
    show_col_types = FALSE
  )
}


# =============================================================================
# SECTION 2: Era banding (identical to 03b)
# =============================================================================

ERA_BANDS <- tribble(
  ~era_label,        ~year_min, ~year_max,
  "Pre-COVID",       2018,      2021,
  "Early Recovery",  2022,      2023,
  "Current",         2024,      2026
)

.assign_era <- function(year) {
  case_when(
    year >= 2018 & year <= 2021 ~ "Pre-COVID",
    year >= 2022 & year <= 2023 ~ "Early Recovery",
    year >= 2024 & year <= 2026 ~ "Current",
    TRUE                        ~ NA_character_
  )
}

ERA_LEVELS  <- c("Pre-COVID", "Early Recovery", "Current")
VALID_CODES <- c("WRK", "PAT", "PAR", "FIN", "RES",
                 "ACC", "INN", "INF", "EDI", "ORG")

TYPE_LEVELS <- c("Teaching", "Community — Large",
                 "Community — Small", "Specialty")

THEME_LABELS <- c(
  WRK = "WRK — Workforce & People",
  PAT = "PAT — Patient Care & Quality",
  PAR = "PAR — Partnerships & Community",
  FIN = "FIN — Financial Sustainability",
  RES = "RES — Research & Academic",
  ACC = "ACC — Access & Care Delivery",
  INN = "INN — Innovation & Digital Health",
  INF = "INF — Infrastructure & Operations",
  EDI = "EDI — Equity, Diversity & Inclusion",
  ORG = "ORG — Organizational Culture"
)


# =============================================================================
# SECTION 3: Build analytical dataset
# =============================================================================

# Spine is authoritative for plan_start_year
spine_year <- spine %>%
  select(fac, plan_start_year) %>%
  mutate(plan_start_year = as.integer(plan_start_year))

classified_usable <- strategy_classified %>%
  filter(
    robots_allowed       == "TRUE",
    extraction_quality   %in% c("full", "partial"),
    !is.na(primary_theme),
    classification_status == "ok"
  ) %>%
  select(-plan_start_year) %>%
  left_join(spine_year, by = "fac") %>%
  mutate(
    era              = .assign_era(plan_start_year),
    hospital_type_group = factor(hospital_type_group, levels = TYPE_LEVELS)
  )

# Exclude hospitals with no era
n_no_era <- n_distinct(classified_usable$fac[is.na(classified_usable$era)])
if (n_no_era > 0) {
  cat(sprintf("NOTE: %d hospital(s) excluded — no era assignment.\n\n", n_no_era))
}
classified_usable <- classified_usable %>% filter(!is.na(era))

# Hospital-level binary theme matrix with era and type
hospital_themes <- classified_usable %>%
  distinct(fac, era, plan_start_year, hospital_type_group, primary_theme) %>%
  filter(primary_theme %in% VALID_CODES) %>%
  mutate(has_theme = 1L) %>%
  pivot_wider(
    names_from  = primary_theme,
    values_from = has_theme,
    values_fill = 0L
  )

# Ensure all theme columns present
for (code in VALID_CODES) {
  if (!code %in% names(hospital_themes)) hospital_themes[[code]] <- 0L
}

hospital_themes <- hospital_themes %>%
  mutate(era = factor(era, levels = ERA_LEVELS))

cat(sprintf("Analytical cohort: %d hospitals, %d eras, %d type groups\n\n",
            n_distinct(hospital_themes$fac),
            n_distinct(hospital_themes$era),
            n_distinct(hospital_themes$hospital_type_group)))


# =============================================================================
# SECTION 4: Era composition by hospital type (composition check)
# =============================================================================

era_type_comp <- hospital_themes %>%
  count(era, hospital_type_group, name = "n_hospitals") %>%
  group_by(era) %>%
  mutate(
    era_total = sum(n_hospitals),
    pct_of_era = round(100 * n_hospitals / era_total, 1)
  ) %>%
  ungroup()

cat("=== Era composition by hospital type ===\n")
print(as.data.frame(era_type_comp))
cat("\n")

write_csv(era_type_comp, "analysis/outputs/tables/03c_era_type_composition.csv")
cat("Table written: 03c_era_type_composition.csv\n\n")


# =============================================================================
# SECTION 5: Full theme prevalence by era × type
# =============================================================================

prevalence_era_type <- hospital_themes %>%
  group_by(era, hospital_type_group) %>%
  summarise(
    n_hospitals = n(),
    across(all_of(VALID_CODES), function(x) round(100 * mean(x), 1)),
    .groups = "drop"
  ) %>%
  pivot_longer(
    cols      = all_of(VALID_CODES),
    names_to  = "theme",
    values_to = "pct_hospitals"
  ) %>%
  mutate(
    theme = factor(theme, levels = VALID_CODES),
    era   = factor(era,   levels = ERA_LEVELS)
  )

write_csv(prevalence_era_type, "analysis/outputs/tables/03c_theme_prevalence_era_type.csv")
cat("Table written: 03c_theme_prevalence_era_type.csv\n\n")


# =============================================================================
# SECTION 6: WRK and RES interaction tables (primary analytical output)
# =============================================================================

wrk_res <- prevalence_era_type %>%
  filter(theme %in% c("WRK", "RES")) %>%
  select(theme, era, hospital_type_group, n_hospitals, pct_hospitals) %>%
  arrange(theme, hospital_type_group, era)

cat("=== WRK prevalence by era × hospital type ===\n")
wrk_res %>%
  filter(theme == "WRK") %>%
  pivot_wider(
    id_cols    = hospital_type_group,
    names_from = era,
    values_from = pct_hospitals
  ) %>%
  print()
cat("\n")

cat("=== RES prevalence by era × hospital type ===\n")
wrk_res %>%
  filter(theme == "RES") %>%
  pivot_wider(
    id_cols    = hospital_type_group,
    names_from = era,
    values_from = pct_hospitals
  ) %>%
  print()
cat("\n")

write_csv(wrk_res, "analysis/outputs/tables/03c_wrk_res_interaction.csv")
cat("Table written: 03c_wrk_res_interaction.csv\n\n")


# =============================================================================
# SECTION 7: Figure — WRK interaction (line plot, one line per type)
# =============================================================================

# Suppress type groups with n < 3 in any era cell (unreliable estimates)
wrk_plot_data <- prevalence_era_type %>%
  filter(theme == "WRK") %>%
  left_join(
    hospital_themes %>% count(era, hospital_type_group, name = "n"),
    by = c("era", "hospital_type_group")
  ) %>%
  mutate(
    label       = sprintf("%d%%\n(n=%d)", round(pct_hospitals), n_hospitals),
    type_label  = as.character(hospital_type_group)
  )

p_wrk <- ggplot(
  wrk_plot_data,
  aes(x = era, y = pct_hospitals,
      colour = hospital_type_group,
      group  = hospital_type_group)
) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 3.5) +
  geom_text(
    aes(label = paste0(round(pct_hospitals), "%")),
    vjust = -1.1, size = 3, show.legend = FALSE
  ) +
  scale_y_continuous(
    limits = c(0, 105),
    labels = function(x) paste0(x, "%"),
    expand = expansion(mult = c(0, 0))
  ) +
  scale_colour_manual(
    values = c(
      "Teaching"         = "#08519C",
      "Community — Large" = "#2171B5",
      "Community — Small" = "#6BAED6",
      "Specialty"        = "#BDD7E7"
    ),
    name = "Hospital type"
  ) +
  labs(
    title    = "WRK Theme Prevalence by Era and Hospital Type",
    subtitle = paste0(
      "% of hospitals in each era × type cell with \u2265 1 WRK direction\n",
      "Note: Teaching includes paediatric hospitals; Specialty includes Chronic/Rehab and Mental Health"
    ),
    x       = "Plan era",
    y       = "% of hospitals with WRK theme",
    caption = "Source: HospitalIntelligenceR Phase 2 + thematic classification. Usable cohort only."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(colour = "grey40", size = 8),
    plot.caption  = element_text(colour = "grey50", size = 6.5),
    legend.position = "right",
    panel.grid.minor = element_blank()
  )

ggsave(
  "analysis/outputs/figures/03c_wrk_interaction.png",
  plot   = p_wrk,
  width  = 7,
  height = 5,
  dpi    = 300
)
cat("Figure saved: 03c_wrk_interaction.png\n")


# =============================================================================
# SECTION 8: Figure — RES interaction
# =============================================================================

res_plot_data <- prevalence_era_type %>%
  filter(theme == "RES") %>%
  mutate(type_label = as.character(hospital_type_group))

p_res <- ggplot(
  res_plot_data,
  aes(x = era, y = pct_hospitals,
      colour = hospital_type_group,
      group  = hospital_type_group)
) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 3.5) +
  geom_text(
    aes(label = paste0(round(pct_hospitals), "%")),
    vjust = -1.1, size = 3, show.legend = FALSE
  ) +
  scale_y_continuous(
    limits = c(0, 80),
    labels = function(x) paste0(x, "%"),
    expand = expansion(mult = c(0, 0))
  ) +
  scale_colour_manual(
    values = c(
      "Teaching"         = "#08519C",
      "Community — Large" = "#2171B5",
      "Community — Small" = "#6BAED6",
      "Specialty"        = "#BDD7E7"
    ),
    name = "Hospital type"
  ) +
  labs(
    title    = "RES Theme Prevalence by Era and Hospital Type",
    subtitle = paste0(
      "% of hospitals in each era × type cell with \u2265 1 RES direction\n",
      "V-shape check: does the Pre-COVID \u2192 Early Recovery dip \u2192 Current recovery hold across types?"
    ),
    x       = "Plan era",
    y       = "% of hospitals with RES theme",
    caption = paste0(
      "Source: HospitalIntelligenceR Phase 2 + thematic classification. Usable cohort only.\n",
      "Note: Teaching hospitals have academic mandates — expect structurally higher RES prevalence."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(colour = "grey40", size = 8),
    plot.caption  = element_text(colour = "grey50", size = 6.5),
    legend.position = "right",
    panel.grid.minor = element_blank()
  )

ggsave(
  "analysis/outputs/figures/03c_res_interaction.png",
  plot   = p_res,
  width  = 7,
  height = 5,
  dpi    = 300
)
cat("Figure saved: 03c_res_interaction.png\n")


# =============================================================================
# SECTION 9: Figure — Full 10-theme heatmap faceted by hospital type
# =============================================================================

# Overall theme order (by mean prevalence across all era × type cells)
theme_order <- prevalence_era_type %>%
  group_by(theme) %>%
  summarise(mean_pct = mean(pct_hospitals, na.rm = TRUE), .groups = "drop") %>%
  arrange(desc(mean_pct)) %>%
  pull(theme) %>%
  as.character()

heatmap_data <- prevalence_era_type %>%
  mutate(
    theme_label = factor(
      THEME_LABELS[as.character(theme)],
      levels = rev(THEME_LABELS[theme_order])
    ),
    # Suppress cells with n < 3 — display as NA
    pct_display = if_else(n_hospitals < 3, NA_real_, pct_hospitals),
    cell_label  = if_else(
      n_hospitals < 3,
      paste0("n=", n_hospitals),
      paste0(round(pct_hospitals), "%")
    )
  )

p_heatmap <- ggplot(
  heatmap_data,
  aes(x = era, y = theme_label, fill = pct_display)
) +
  geom_tile(colour = "white", linewidth = 0.6) +
  geom_text(
    aes(label = cell_label),
    size   = 3,
    colour = ifelse(
      !is.na(heatmap_data$pct_display) & heatmap_data$pct_display > 55,
      "white", "grey20"
    )
  ) +
  facet_wrap(~ hospital_type_group, ncol = 2) +
  scale_fill_gradient(
    low    = "#EFF3FF",
    high   = "#08519C",
    name   = "% of hospitals\nwith theme",
    limits = c(0, 100),
    breaks = c(0, 25, 50, 75, 100),
    labels = function(x) paste0(x, "%"),
    na.value = "grey90"
  ) +
  labs(
    title    = "Strategic Theme Prevalence by Era and Hospital Type",
    subtitle = paste0(
      "% of hospitals with \u2265 1 direction in each theme | Grey cells: n < 3 hospitals\n",
      "Teaching includes paediatric hospitals; Specialty includes Chronic/Rehab and Mental Health"
    ),
    x       = NULL,
    y       = NULL,
    caption = paste0(
      "Source: HospitalIntelligenceR Phase 2 extraction + thematic classification (claude-sonnet-4-5).\n",
      "Usable cohort only (full/partial extractions, robots-allowed). Pre-COVID era 2018\u20132021."
    )
  ) +
  theme_minimal(base_size = 10) +
  theme(
    plot.title       = element_text(face = "bold", size = 12),
    plot.subtitle    = element_text(colour = "grey40", size = 8),
    plot.caption     = element_text(colour = "grey50", size = 6.5),
    axis.text.x      = element_text(size = 8, angle = 15, hjust = 1),
    axis.text.y      = element_text(size = 7.5),
    panel.grid       = element_blank(),
    strip.text       = element_text(face = "bold", size = 9),
    legend.key.height = unit(1.2, "cm")
  )

ggsave(
  "analysis/outputs/figures/03c_heatmap_by_type.png",
  plot   = p_heatmap,
  width  = 9,
  height = 8,
  dpi    = 300
)
cat("Figure saved: 03c_heatmap_by_type.png\n\n")


# =============================================================================
# SECTION 10: Console summary — WRK and RES key findings
# =============================================================================

cat("=== KEY FINDINGS SUMMARY ===\n\n")

cat("WRK — Workforce & People\n")
cat("Overall shift (03b): Pre-COVID 67% → Early Recovery 91% → Current 94%\n")
cat("By hospital type:\n")
prevalence_era_type %>%
  filter(theme == "WRK") %>%
  select(hospital_type_group, era, pct_hospitals, n_hospitals) %>%
  pivot_wider(names_from = era, values_from = c(pct_hospitals, n_hospitals)) %>%
  { cat(sprintf(
    "  %-22s  Pre-COVID: %4.0f%%  Early Recovery: %4.0f%%  Current: %4.0f%%\n",
    .$hospital_type_group,
    .[[paste0("pct_hospitals_Pre-COVID")]],
    .[[paste0("pct_hospitals_Early Recovery")]],
    .[[paste0("pct_hospitals_Current")]]
  )); . } %>%
  invisible()
cat("\n")

cat("RES — Research & Academic\n")
cat("Overall shift (03b): Pre-COVID 25% → Early Recovery 9% → Current 38%\n")
cat("By hospital type:\n")
prevalence_era_type %>%
  filter(theme == "RES") %>%
  select(hospital_type_group, era, pct_hospitals, n_hospitals) %>%
  pivot_wider(names_from = era, values_from = c(pct_hospitals, n_hospitals)) %>%
  { cat(sprintf(
    "  %-22s  Pre-COVID: %4.0f%%  Early Recovery: %4.0f%%  Current: %4.0f%%\n",
    .$hospital_type_group,
    .[[paste0("pct_hospitals_Pre-COVID")]],
    .[[paste0("pct_hospitals_Early Recovery")]],
    .[[paste0("pct_hospitals_Current")]]
  )); . } %>%
  invisible()

cat("\nDone. Review console output and figures.\n")
cat("Key questions:\n")
cat("  WRK: Is the rise universal, or concentrated in one type group?\n")
cat("  RES: Does the V-shape hold in Community hospitals, or only in Teaching?\n")
