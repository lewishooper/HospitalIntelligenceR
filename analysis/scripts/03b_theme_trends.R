# =============================================================================
# analysis/scripts/03b_theme_trends.R
# HospitalIntelligenceR — Direction 3b: Theme Prevalence by Plan Era
#
# QUESTION:
#   Has the thematic composition of Ontario hospital strategic plans shifted
#   over time? Specifically, do plans written post-COVID differ in their
#   strategic emphasis compared to pre-COVID plans?
#
# APPROACH:
#   - Unit of analysis: hospital (one observation per hospital)
#   - Hospitals grouped into three plan eras based on plan_start_year
#   - Metric: % of hospitals in each era that have at least one direction
#     in each theme (hospital prevalence, not direction count)
#   - Top 5 and bottom 5 themes reported for each era
#   - Same analytical cohort as 01a/01b
#
# ERA DEFINITIONS:
#   Pre-COVID     2018–2021   Plans written before or during acute COVID period
#   Early Recovery 2022–2023  Plans written in immediate post-COVID period
#   Current       2024–2026   Most recently written plans
#
# NOTE ON METRIC CHOICE:
#   Direction count % (used in 01b) measures share of directions within a
#   hospital's plan. Hospital prevalence % (used here) measures how many
#   hospitals chose to include a theme at all — a better measure of whether
#   a theme is becoming more or less common across the sector over time.
#
# OUTPUTS:
#   analysis/outputs/tables/03b_theme_prevalence_by_era.csv
#   analysis/outputs/tables/03b_top5_bottom5_by_era.csv
#   analysis/outputs/figures/03b_theme_prevalence_heatmap.png
#   analysis/outputs/figures/03b_top5_bottom5_facet.png
#
# DEPENDENCIES:
#   Requires 'strategy_classified' in environment (from 00c_build_strategy_classified.R)
#   OR will load analysis/data/strategy_classified.csv directly.
#   Requires 'spine' in environment (from 00_prepare_data.R)
#   OR will load analysis/data/hospital_spine.csv directly.
#
# USAGE:
#   source("analysis/scripts/00_prepare_data.R")
#   source("analysis/scripts/00c_build_strategy_classified.R")
#   source("analysis/scripts/03b_theme_trends.R")
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
# SECTION 2: Define era banding
# =============================================================================

ERA_BANDS <- tribble(
  ~era_label,        ~year_min, ~year_max,
  "Pre-COVID",       2018,      2021,
  "Early Recovery",  2022,      2023,
  "Current",         2024,      2026
)

# Helper: assign era from year
.assign_era <- function(year) {
  case_when(
    year >= 2018 & year <= 2021 ~ "Pre-COVID",
    year >= 2022 & year <= 2023 ~ "Early Recovery",
    year >= 2024 & year <= 2026 ~ "Current",
    TRUE                        ~ NA_character_
  )
}

ERA_LEVELS <- c("Pre-COVID", "Early Recovery", "Current")


# =============================================================================
# SECTION 3: Build hospital-level analytical dataset
#
# One row per hospital. Each theme gets a binary flag: did this hospital
# have at least one direction classified to that theme?
# =============================================================================

# Analytical subset from classifications: usable, robots-allowed, classified
classified_usable <- strategy_classified %>%
  filter(
    robots_allowed       == "TRUE",
    extraction_quality   %in% c("full", "partial"),
    !is.na(primary_theme),
    classification_status == "ok"
  ) %>%
  mutate(plan_start_year = as.integer(plan_start_year))

# Join plan_start_year from spine for hospitals where it may be missing
# in strategy_classified (spine is authoritative for plan metadata)
spine_year <- spine %>%
  select(fac, plan_start_year) %>%
  mutate(plan_start_year = as.integer(plan_start_year))

classified_usable <- classified_usable %>%
  select(-plan_start_year) %>%
  left_join(spine_year, by = "fac")

# Assign era
classified_usable <- classified_usable %>%
  mutate(era = .assign_era(plan_start_year))

# Hospitals with no era assignment (outside window or missing year)
n_no_era <- n_distinct(classified_usable$fac[is.na(classified_usable$era)])
if (n_no_era > 0) {
  cat(sprintf("WARNING: %d hospital(s) have no era assignment — excluded.\n",
              n_no_era))
  classified_usable %>%
    filter(is.na(era)) %>%
    distinct(fac, plan_start_year) %>%
    { cat(paste0("  FAC ", .$fac, " — year: ", .$plan_start_year, "\n")); . } %>%
    invisible()
}

classified_usable <- classified_usable %>% filter(!is.na(era))

# All valid theme codes (GOV retired)
VALID_CODES <- c("WRK", "PAT", "PAR", "FIN", "RES",
                 "ACC", "INN", "INF", "EDI", "ORG")

# Build hospital × theme binary matrix
# For each hospital: 1 if any direction has that primary theme, 0 otherwise
hospital_themes <- classified_usable %>%
  distinct(fac, era, plan_start_year, primary_theme) %>%
  filter(primary_theme %in% VALID_CODES) %>%
  mutate(has_theme = 1L) %>%
  pivot_wider(
    names_from  = primary_theme,
    values_from = has_theme,
    values_fill = 0L
  )

# Ensure all theme columns present even if no hospital has that theme in an era
for (code in VALID_CODES) {
  if (!code %in% names(hospital_themes)) hospital_themes[[code]] <- 0L
}

cat(sprintf("Hospital-era observations: %d hospitals across %d eras\n",
            nrow(hospital_themes), n_distinct(hospital_themes$era)))
cat("Era breakdown:\n")
print(table(hospital_themes$era))
cat("\n")


# =============================================================================
# SECTION 4: Theme prevalence by era
#
# % of hospitals in each era that have >= 1 direction in each theme
# =============================================================================

prevalence <- hospital_themes %>%
  mutate(era = factor(era, levels = ERA_LEVELS)) %>%
  group_by(era) %>%
  summarise(
    n_hospitals = n(),
    across(all_of(VALID_CODES), function(x) round(100 * mean(x), 1)),
    .groups = "drop"
  )

# Long format for plotting and tables
prevalence_long <- prevalence %>%
  pivot_longer(
    cols      = all_of(VALID_CODES),
    names_to  = "theme",
    values_to = "pct_hospitals"
  ) %>%
  mutate(
    theme = factor(theme, levels = VALID_CODES),
    era   = factor(era, levels = ERA_LEVELS)
  )

cat("=== Theme prevalence by era (% of hospitals with >= 1 direction in theme) ===\n")
prevalence_wide <- prevalence_long %>%
  pivot_wider(names_from = era, values_from = pct_hospitals) %>%
  arrange(desc(`Pre-COVID`))
print(as.data.frame(prevalence_wide))
cat("\n")


# =============================================================================
# SECTION 5: Top 5 and bottom 5 themes per era
# =============================================================================

top5_bottom5 <- prevalence_long %>%
  group_by(era) %>%
  arrange(desc(pct_hospitals)) %>%
  mutate(rank_desc = row_number()) %>%
  arrange(pct_hospitals) %>%
  mutate(rank_asc = row_number()) %>%
  ungroup() %>%
  filter(rank_desc <= 5 | rank_asc <= 5) %>%
  mutate(position = case_when(
    rank_desc <= 5 ~ paste0("Top ", rank_desc),
    rank_asc  <= 5 ~ paste0("Bottom ", rank_asc)
  )) %>%
  select(era, position, theme, pct_hospitals) %>%
  arrange(era, desc(pct_hospitals))

cat("=== Top 5 and Bottom 5 themes by era ===\n")
for (e in ERA_LEVELS) {
  cat(sprintf("\n%s (n=%d hospitals):\n",
              e, prevalence$n_hospitals[prevalence$era == e]))
  era_rows <- top5_bottom5 %>% filter(era == e)
  cat("  Top 5:\n")
  era_rows %>%
    filter(str_starts(position, "Top")) %>%
    { cat(paste0("    ", .$position, "  ", .$theme,
                 "  ", .$pct_hospitals, "%\n")); . } %>%
    invisible()
  cat("  Bottom 5:\n")
  era_rows %>%
    filter(str_starts(position, "Bottom")) %>%
    { cat(paste0("    ", .$position, "  ", .$theme,
                 "  ", .$pct_hospitals, "%\n")); . } %>%
    invisible()
}
cat("\n")

# Notable shifts: themes where prevalence changes >= 15 pp across eras
cat("=== Notable shifts (Pre-COVID → Current, >= 15 pp change) ===\n")
shifts <- prevalence_wide %>%
  mutate(
    shift_pp = `Current` - `Pre-COVID`,
    direction = if_else(shift_pp > 0, "UP", "DOWN")
  ) %>%
  filter(abs(shift_pp) >= 15) %>%
  arrange(desc(abs(shift_pp)))

if (nrow(shifts) > 0) {
  for (i in seq_len(nrow(shifts))) {
    cat(sprintf("  %-5s  %s %.0f pp  (Pre-COVID: %.0f%%  →  Current: %.0f%%)\n",
                shifts$theme[i], shifts$direction[i], abs(shifts$shift_pp[i]),
                shifts$`Pre-COVID`[i], shifts$`Current`[i]))
  }
} else {
  cat("  No themes show >= 15 pp shift from Pre-COVID to Current.\n")
  cat("  Largest shifts:\n")
  prevalence_wide %>%
    mutate(shift_pp = abs(`Current` - `Pre-COVID`)) %>%
    arrange(desc(shift_pp)) %>%
    slice_head(n = 3) %>%
    { cat(paste0("    ", .$theme, ": ", round(.$shift_pp, 1), " pp\n")); . } %>%
    invisible()
}
cat("\n")


# =============================================================================
# SECTION 6: Write tables
# =============================================================================

dir.create("analysis/outputs/tables", recursive = TRUE, showWarnings = FALSE)

write_csv(prevalence_wide, "analysis/outputs/tables/03b_theme_prevalence_by_era.csv")
write_csv(top5_bottom5,    "analysis/outputs/tables/03b_top5_bottom5_by_era.csv")

cat("Tables written to analysis/outputs/tables/\n\n")


# =============================================================================
# SECTION 7: Chart 1 — Heatmap: theme prevalence by era
# =============================================================================

dir.create("analysis/outputs/figures", recursive = TRUE, showWarnings = FALSE)

THEME_LABELS <- c(
  WRK = "WRK — Workforce & Culture",
  PAT = "PAT — Patient Experience & Quality",
  PAR = "PAR — Partnerships & Integration",
  FIN = "FIN — Financial Sustainability",
  RES = "RES — Research & Academic",
  ACC = "ACC — Access & Care Delivery",
  INN = "INN — Innovation & Digital Health",
  INF = "INF — Infrastructure & Operations",
  EDI = "EDI — Equity, Diversity & Inclusion",
  ORG = "ORG — Organizational Culture"
)

# Order themes by overall prevalence (avg across eras)
theme_order_overall <- prevalence_long %>%
  group_by(theme) %>%
  summarise(mean_pct = mean(pct_hospitals), .groups = "drop") %>%
  arrange(desc(mean_pct)) %>%
  pull(theme) %>%
  as.character()

# Era labels with n
era_n_labels <- prevalence %>%
  mutate(era_label = sprintf("%s\n(n=%d)", era, n_hospitals)) %>%
  select(era, era_label)

heatmap_data <- prevalence_long %>%
  left_join(era_n_labels, by = "era") %>%
  mutate(
    theme_label = THEME_LABELS[as.character(theme)],
    theme_label = factor(theme_label,
                         levels = rev(THEME_LABELS[theme_order_overall])),
    era_label   = factor(era_label,
                         levels = era_n_labels$era_label[
                           match(ERA_LEVELS, era_n_labels$era)])
  )

p_heatmap <- ggplot(
  heatmap_data,
  aes(x = era_label, y = theme_label, fill = pct_hospitals)
) +
  geom_tile(colour = "white", linewidth = 0.6) +
  geom_text(
    aes(label = sprintf("%.0f%%", pct_hospitals)),
    size   = 3.5,
    colour = ifelse(heatmap_data$pct_hospitals > 55, "white", "grey20")
  ) +
  scale_fill_gradient(
    low    = "#EFF3FF",
    high   = "#08519C",
    name   = "% of hospitals\nwith theme",
    limits = c(0, 100),
    breaks = c(0, 25, 50, 75, 100),
    labels = function(x) paste0(x, "%")
  ) +
  labs(
    title    = "Strategic Theme Prevalence by Plan Era",
    subtitle = paste0(
      "% of Ontario hospitals with \u2265 1 direction classified to each theme\n",
      "Pre-COVID = 2018\u20132021  |  Early Recovery = 2022\u20132023  |  Current = 2024\u20132026"
    ),
    x       = NULL,
    y       = NULL,
    caption = paste0(
      "Source: HospitalIntelligenceR Phase 2 extraction + thematic classification (claude-sonnet-4-5).\n",
      "Usable cohort only (full/partial extractions, robots-allowed). GOV code retired."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(colour = "grey40", size = 8),
    plot.caption  = element_text(colour = "grey50", size = 6.5),
    axis.text.x   = element_text(size = 10, hjust = 0.5),
    axis.text.y   = element_text(size = 8.5),
    panel.grid    = element_blank(),
    legend.key.height = unit(1.2, "cm")
  )

ggsave(
  "analysis/outputs/figures/03b_theme_prevalence_heatmap.png",
  plot   = p_heatmap,
  width  = 7,
  height = 6,
  dpi    = 300
)
cat("Figure saved: 03b_theme_prevalence_heatmap.png\n")


# =============================================================================
# SECTION 8: Chart 2 — Top 5 / Bottom 5 per era (faceted dot plot)
# =============================================================================

# Build plot data: top 5 and bottom 5 per era, labelled
plot_tb <- prevalence_long %>%
  group_by(era) %>%
  arrange(desc(pct_hospitals)) %>%
  mutate(rank = row_number()) %>%
  ungroup() %>%
  filter(rank <= 5 | rank > (n_distinct(prevalence_long$theme) - 5)) %>%
  mutate(
    position_group = if_else(rank <= 5, "Top 5", "Bottom 5"),
    theme_label    = THEME_LABELS[as.character(theme)],
    theme_short    = str_extract(theme_label, "^[A-Z]+"),
    era            = factor(era, levels = ERA_LEVELS)
  )

p_dotplot <- ggplot(
  plot_tb,
  aes(x = pct_hospitals, y = fct_reorder(theme_short, pct_hospitals),
      colour = position_group)
) +
  geom_segment(
    aes(x = 0, xend = pct_hospitals,
        y = fct_reorder(theme_short, pct_hospitals),
        yend = fct_reorder(theme_short, pct_hospitals)),
    colour = "grey85", linewidth = 0.5
  ) +
  geom_point(size = 4) +
  geom_text(
    aes(label = paste0(pct_hospitals, "%")),
    hjust = -0.4, size = 3, colour = "grey20"
  ) +
  facet_wrap(~ era, ncol = 3, scales = "free_y") +
  scale_colour_manual(
    values = c("Top 5" = "#08519C", "Bottom 5" = "#BDD7E7"),
    name   = NULL
  ) +
  scale_x_continuous(
    limits = c(0, 110),
    labels = function(x) paste0(x, "%"),
    expand = expansion(mult = c(0, 0))
  ) +
  labs(
    title    = "Top 5 and Bottom 5 Strategic Themes by Plan Era",
    subtitle = "% of hospitals in each era with \u2265 1 direction in that theme",
    x        = "% of hospitals",
    y        = NULL,
    caption  = paste0(
      "Source: HospitalIntelligenceR Phase 2 extraction + thematic classification.\n",
      "Usable cohort only. GOV code retired."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(colour = "grey40", size = 8),
    plot.caption  = element_text(colour = "grey50", size = 6.5),
    strip.text    = element_text(face = "bold", size = 10),
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    legend.position    = "bottom"
  )

ggsave(
  "analysis/outputs/figures/03b_top5_bottom5_facet.png",
  plot   = p_dotplot,
  width  = 11,
  height = 5,
  dpi    = 300
)
cat("Figure saved: 03b_top5_bottom5_facet.png\n")

cat("\nDone. Review console output and figures before writing 03b narrative.\n")
cat("Key question: do notable shifts hold up given Pre-COVID n is small?\n")
