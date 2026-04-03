# =============================================================================
# analysis/scripts/01b_direction_types.R
# HospitalIntelligenceR — Direction 1b: Theme Distribution by Hospital Type
#
# QUESTION:
#   How does the thematic composition of strategic plans differ across hospital
#   type groups? Do Small Community hospitals over-index on workforce and financial
#   themes relative to Teaching hospitals?
#
# APPROACH:
#   - Unit of analysis: direction row (one row per strategic direction)
#   - Primary variable: primary_theme (10-code taxonomy, GOV retired)
#   - Grouping variable: hospital_type_group
#   - Metric: % of directions in each type group assigned to each theme
#     (proportion, not raw count — controls for group size differences)
#   - Same analytical cohort as 01a: full/partial extractions, robots-allowed
#
# OUTPUTS:
#   analysis/outputs/tables/01b_theme_by_type_counts.csv     [raw counts]
#   analysis/outputs/tables/01b_theme_by_type_pct.csv        [row percentages]
#   analysis/outputs/figures/01b_theme_heatmap.png           [primary chart]
#   analysis/outputs/figures/01b_theme_facet_bar.png         [secondary chart]
#
# DEPENDENCIES:
#   Requires 'strategy_classified' in environment (from 00c_build_strategy_classified.R)
#   OR will load analysis/data/strategy_classified.csv directly if not found.
#
# USAGE:
#   source("analysis/scripts/00_prepare_data.R")              # if not already run
#   source("analysis/scripts/00c_build_strategy_classified.R") # if not already run
#   source("analysis/scripts/01b_direction_types.R")
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
  message("'strategy_classified' not found in environment — loading from CSV.")
  strategy_classified <- read_csv(
    "analysis/data/strategy_classified.csv",
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )
}


# =============================================================================
# SECTION 2: Build analytical subset
# =============================================================================

# Same cohort as 01a: robots-allowed, full/partial extractions, classified rows
classified <- strategy_classified %>%
  filter(
    robots_allowed == "TRUE",
    extraction_quality %in% c("full", "partial"),
    !is.na(primary_theme),
    classification_status == "ok"
  ) %>%
  mutate(
    # Collapse Community — Medium into Community — Large (n=1)
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
# SECTION 3: Theme ordering — by overall prevalence (descending)
# =============================================================================

# Order themes by overall frequency so charts read highest → lowest
theme_order <- classified %>%
  count(primary_theme, sort = TRUE) %>%
  pull(primary_theme)

classified <- classified %>%
  mutate(primary_theme = factor(primary_theme, levels = theme_order))


# =============================================================================
# SECTION 4: Cross-tab — counts and proportions
# =============================================================================

# Raw counts: directions per theme per type group
counts <- classified %>%
  group_by(type_group, primary_theme) %>%
  summarise(n_directions = n(), .groups = "drop")

# Group totals for denominator
group_totals <- classified %>%
  count(type_group, name = "n_total")

# Proportions: % of each type group's directions in each theme
theme_pct <- counts %>%
  left_join(group_totals, by = "type_group") %>%
  mutate(pct = round(100 * n_directions / n_total, 1)) %>%
  # Fill zeros for type/theme combinations with no directions
  complete(type_group, primary_theme, fill = list(n_directions = 0, pct = 0)) %>%
  left_join(group_totals, by = "type_group") %>%
  mutate(n_total = coalesce(n_total.x, n_total.y)) %>%
  select(type_group, primary_theme, n_directions, n_total, pct)

# Wide format for readable table output
counts_wide <- counts %>%
  pivot_wider(
    names_from  = type_group,
    values_from = n_directions,
    values_fill = 0
  ) %>%
  arrange(primary_theme)

pct_wide <- theme_pct %>%
  select(type_group, primary_theme, pct) %>%
  pivot_wider(
    names_from  = type_group,
    values_from = pct,
    values_fill = 0
  ) %>%
  arrange(primary_theme)

cat("\n=== Theme distribution by hospital type (% of group directions) ===\n")
print(as.data.frame(pct_wide))


# =============================================================================
# SECTION 5: Write tables
# =============================================================================

dir.create("analysis/outputs/tables", recursive = TRUE, showWarnings = FALSE)

write_csv(counts_wide, "analysis/outputs/tables/01b_theme_by_type_counts.csv")
write_csv(pct_wide,    "analysis/outputs/tables/01b_theme_by_type_pct.csv")

cat("\nTables written to analysis/outputs/tables/\n")


# =============================================================================
# SECTION 6: Chart 1 — Heatmap (primary chart)
#
# Rows = themes (ordered by overall prevalence)
# Cols = hospital type groups
# Fill = % of that group's directions in that theme
# This is the most information-dense view of the full cross-tab
# =============================================================================

dir.create("analysis/outputs/figures", recursive = TRUE, showWarnings = FALSE)

# Theme labels — code + readable name for axis
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

# Add readable label and flip theme order for heatmap (highest at top)
heatmap_data <- theme_pct %>%
  mutate(
    theme_label = THEME_LABELS[as.character(primary_theme)],
    theme_label = factor(theme_label,
                         levels = rev(THEME_LABELS[theme_order]))
  )

# Group size labels for column headers
group_labels <- group_totals %>%
  mutate(label = sprintf("%s\n(n=%d dirs)", type_group, n_total))

# Add to heatmap data
heatmap_data <- heatmap_data %>%
  left_join(
    group_totals %>% mutate(col_label = sprintf("%s\n(n=%d)", type_group, n_total)),
    by = "type_group"
  ) %>%
  mutate(col_label = factor(col_label, levels = {
    group_totals %>%
      arrange(type_group) %>%
      mutate(col_label = sprintf("%s\n(n=%d)", type_group, n_total)) %>%
      pull(col_label)
  }))

p_heatmap <- ggplot(
  heatmap_data,
  aes(x = col_label, y = theme_label, fill = pct)
) +
  geom_tile(colour = "white", linewidth = 0.5) +
  geom_text(
    aes(label = sprintf("%.0f%%", pct)),
    size = 3.2,
    colour = ifelse(heatmap_data$pct > 15, "white", "grey20")
  ) +
  scale_fill_gradient(
    low      = "#EFF3FF",
    high     = "#08519C",
    name     = "% of group\ndirections",
    limits   = c(0, NA),
    breaks   = c(0, 10, 20, 30),
    labels   = function(x) paste0(x, "%")
  ) +
  labs(
    title    = "Thematic Composition of Strategic Plans by Hospital Type",
    subtitle = sprintf(
      "Ontario hospitals — %d directions across %d hospitals (full/partial extractions, robots-allowed)\nCell values = %% of that hospital type's directions assigned to each theme",
      n_directions, n_hospitals
    ),
    x = NULL,
    y = NULL,
    caption = paste0(
      "Source: HospitalIntelligenceR Phase 2 extraction + thematic classification (claude-sonnet-4-5, temp=0).\n",
      "GOV code retired (n=2, reclassified). Thin extractions (n=11) and robots-blocked hospitals (n=7) excluded."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title     = element_text(face = "bold", size = 12),
    plot.subtitle  = element_text(colour = "grey40", size = 8),
    plot.caption   = element_text(colour = "grey50", size = 6.5),
    axis.text.x    = element_text(size = 9, hjust = 0.5),
    axis.text.y    = element_text(size = 8.5),
    panel.grid     = element_blank(),
    legend.key.height = unit(1.2, "cm")
  )

ggsave(
  "analysis/outputs/figures/01b_theme_heatmap.png",
  plot   = p_heatmap,
  width  = 8,
  height = 6,
  dpi    = 300
)
cat("Figure saved: 01b_theme_heatmap.png\n")


# =============================================================================
# SECTION 7: Chart 2 — Faceted bar chart (secondary chart)
#
# One facet per theme, bars = hospital type groups, height = % of group directions
# Good for reading within-theme variation across groups
# =============================================================================

# Facet label wrapping for theme names
heatmap_data_facet <- theme_pct %>%
  mutate(
    theme_label = str_wrap(THEME_LABELS[as.character(primary_theme)], width = 22),
    theme_label = factor(theme_label,
                         levels = str_wrap(THEME_LABELS[theme_order], width = 22))
  )

p_facet <- ggplot(
  heatmap_data_facet,
  aes(x = type_group, y = pct, fill = type_group)
) +
  geom_col(width = 0.65, show.legend = FALSE) +
  geom_text(
    aes(label = ifelse(pct >= 2, sprintf("%.0f%%", pct), "")),
    vjust = -0.4, size = 2.5, colour = "grey20"
  ) +
  facet_wrap(~ theme_label, ncol = 5) +
  scale_fill_manual(values = c(
    "Teaching"          = "#08519C",
    "Community — Large" = "#2171B5",
    "Community — Small" = "#6BAED6",
    "Specialty"         = "#BDD7E7"
  )) +
  scale_x_discrete(labels = function(x) str_wrap(x, width = 10)) +
  scale_y_continuous(
    limits = c(0, NA),
    expand = expansion(mult = c(0, 0.15)),
    labels = function(x) paste0(x, "%")
  ) +
  labs(
    title    = "Strategic Theme Prevalence by Hospital Type",
    subtitle = sprintf(
      "Ontario hospitals — %d directions, %d hospitals | Values = %% of each hospital type's directions",
      n_directions, n_hospitals
    ),
    x = NULL,
    y = "% of group directions",
    caption = paste0(
      "Source: HospitalIntelligenceR Phase 2 extraction + thematic classification.\n",
      "GOV code retired. Thin and robots-blocked hospitals excluded."
    )
  ) +
  theme_minimal(base_size = 10) +
  theme(
    plot.title     = element_text(face = "bold", size = 12),
    plot.subtitle  = element_text(colour = "grey40", size = 8),
    plot.caption   = element_text(colour = "grey50", size = 6.5),
    strip.text     = element_text(size = 7.5, face = "bold"),
    axis.text.x    = element_text(size = 6.5),
    axis.text.y    = element_text(size = 7),
    axis.title.y   = element_text(size = 8),
    panel.grid.major.x = element_blank(),
    panel.spacing  = unit(0.8, "lines")
  )

ggsave(
  "analysis/outputs/figures/01b_theme_facet_bar.png",
  plot   = p_facet,
  width  = 11,
  height = 7,
  dpi    = 300
)
cat("Figure saved: 01b_theme_facet_bar.png\n")


# =============================================================================
# SECTION 8: Narrative summary
# =============================================================================

cat("\n========== DIRECTION 1b SUMMARY ==========\n")
cat(sprintf("  Analytical cohort:  %d directions, %d hospitals\n",
            n_directions, n_hospitals))
cat("\n  Theme distribution by group (% of group directions):\n")
print(as.data.frame(pct_wide))

# Flag notable differentials: themes where max - min across groups >= 8 pct points
cat("\n  Notable differentials (max - min >= 8 pct points across groups):\n")
pct_long_numeric <- theme_pct %>%
  select(type_group, primary_theme, pct)

differentials <- pct_long_numeric %>%
  group_by(primary_theme) %>%
  summarise(
    max_pct  = max(pct),
    min_pct  = min(pct),
    range_pp = max_pct - min_pct,
    high_group = type_group[which.max(pct)],
    low_group  = type_group[which.min(pct)],
    .groups = "drop"
  ) %>%
  filter(range_pp >= 8) %>%
  arrange(desc(range_pp))

if (nrow(differentials) > 0) {
  for (i in seq_len(nrow(differentials))) {
    cat(sprintf("    %-5s  range=%.0f pp  high=%s (%.0f%%)  low=%s (%.0f%%)\n",
                differentials$primary_theme[i],
                differentials$range_pp[i],
                differentials$high_group[i],
                differentials$max_pct[i],
                differentials$low_group[i],
                differentials$min_pct[i]))
  }
} else {
  cat("    No theme shows >= 8 pp differential across groups.\n")
}

cat("==========================================\n")
