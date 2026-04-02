# =============================================================================
# analysis/scripts/01a_plan_volume.R
# HospitalIntelligenceR — Direction 1a: Plan Volume vs. Hospital Type
#
# QUESTION:
#   Do larger/more complex hospitals produce more substantive strategic plans,
#   as measured by number of strategic directions?
#
# APPROACH:
#   - Unit of analysis: hospital (one row per hospital, from spine)
#   - Primary variable: n_directions (count of extracted direction rows)
#   - Grouping variable: hospital_type_group (from registry)
#   - Exclusions:
#       * thin extraction quality — direction count unreliable (extraction failure
#         cannot be distinguished from genuinely thin plan at this stage)
#       * no_data — no extraction at all
#       * robots_allowed == FALSE — excluded from all analysis denominators
#   - Community — Medium (n=1) is collapsed into Community — Large for display
#
# OUTPUTS:
#   analysis/outputs/tables/01a_direction_count_by_type.csv
#   analysis/outputs/tables/01a_extraction_quality_by_type.csv
#   analysis/outputs/figures/01a_direction_count_boxplot.png
#   analysis/outputs/figures/01a_extraction_quality_stacked.png
#
# DEPENDENCIES:
#   Requires 'spine' object in environment (from 00_prepare_data.R)
#   OR will load analysis/data/hospital_spine.csv directly if not found.
#
# USAGE:
#   source("analysis/scripts/00_prepare_data.R")   # if not already run
#   source("analysis/scripts/01a_plan_volume.R")
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
    col_types = cols(.default = col_character(),
                     robots_allowed   = col_logical(),
                     has_extraction   = col_logical(),
                     has_vision       = col_logical(),
                     has_mission      = col_logical(),
                     has_values       = col_logical(),
                     has_purpose      = col_logical(),
                     plan_period_parse_ok = col_logical(),
                     n_directions     = col_integer(),
                     plan_start_year  = col_integer()),
    show_col_types = FALSE
  )
}


# =============================================================================
# SECTION 2: Prepare analytical subset
# =============================================================================

# Collapse Community — Medium into Community — Large (n=1, not analytically
# meaningful as a standalone group). Record the reclassification.
spine_01a <- spine %>%
  mutate(
    type_group = case_when(
      hospital_type_group == "Community — Medium" ~ "Community — Large",
      TRUE                                        ~ hospital_type_group
    ),
    # Ordered factor for consistent display order in plots
    type_group = factor(type_group, levels = c(
      "Teaching",
      "Community — Large",
      "Community — Small",
      "Specialty"
    ))
  )

# Full cohort counts (before exclusions) — for reporting denominators
n_total      <- nrow(spine_01a)
n_robots_blocked <- sum(!spine_01a$robots_allowed, na.rm = TRUE)
n_no_data    <- sum(spine_01a$extraction_quality == "no_data", na.rm = TRUE)
n_thin       <- sum(spine_01a$extraction_quality == "thin", na.rm = TRUE)

cat(sprintf(
  "Cohort: %d total hospitals | %d robots-blocked | %d no_data | %d thin\n",
  n_total, n_robots_blocked, n_no_data, n_thin
))

# Analytical subset: robots-allowed hospitals with usable extraction
# (full or partial — thin excluded from direction count analysis)
spine_usable <- spine_01a %>%
  filter(
    robots_allowed == TRUE,
    extraction_quality %in% c("full", "partial")
  )

n_usable <- nrow(spine_usable)
cat(sprintf("Analytical subset (full/partial, robots-allowed): %d hospitals\n\n", n_usable))


# =============================================================================
# SECTION 3: Direction count summary by hospital type
# =============================================================================

direction_summary <- spine_usable %>%
  group_by(type_group) %>%
  summarise(
    n_hospitals  = n(),
    mean_dirs    = round(mean(n_directions, na.rm = TRUE), 1),
    median_dirs  = median(n_directions, na.rm = TRUE),
    min_dirs     = min(n_directions, na.rm = TRUE),
    max_dirs     = max(n_directions, na.rm = TRUE),
    sd_dirs      = round(sd(n_directions, na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  arrange(type_group)

cat("=== Direction count by hospital type (full/partial extractions only) ===\n")
print(as.data.frame(direction_summary))
cat("\n")


# =============================================================================
# SECTION 4: Extraction quality breakdown by hospital type
# =============================================================================

# All robots-allowed hospitals (including thin and no_data) for quality table
quality_summary <- spine_01a %>%
  filter(robots_allowed == TRUE) %>%
  group_by(type_group, extraction_quality) %>%
  summarise(n = n(), .groups = "drop") %>%
  pivot_wider(
    names_from  = extraction_quality,
    values_from = n,
    values_fill = 0
  ) %>%
  # Ensure all quality columns present even if a group has none
  { cols_needed <- c("full", "partial", "thin", "no_data")
  missing     <- setdiff(cols_needed, colnames(.))
  for (col in missing) .[[col]] <- 0L
  . } %>%
  mutate(
    total       = full + partial + thin + no_data,
    pct_usable  = round(100 * (full + partial) / total, 1)
  ) %>%
  select(type_group, total, full, partial, thin, no_data, pct_usable) %>%
  arrange(type_group)

cat("=== Extraction quality by hospital type (robots-allowed hospitals) ===\n")
print(as.data.frame(quality_summary))
cat("\n")


# =============================================================================
# SECTION 5: Write tables
# =============================================================================

dir.create("analysis/outputs/tables", recursive = TRUE, showWarnings = FALSE)

write_csv(direction_summary, "analysis/outputs/tables/01a_direction_count_by_type.csv")
write_csv(quality_summary,   "analysis/outputs/tables/01a_extraction_quality_by_type.csv")

cat("Tables written to analysis/outputs/tables/\n\n")


# =============================================================================
# SECTION 6: Plot 1 — Direction count boxplot by hospital type
# =============================================================================

dir.create("analysis/outputs/figures", recursive = TRUE, showWarnings = FALSE)

# Colour palette — blue spread across all groups, consistent across all 01x scripts
TYPE_COLOURS <- c(
  "Teaching"          = "#08519C",
  "Community — Large" = "#2171B5",
  "Community — Small" = "#6BAED6",
  "Specialty"         = "#BDD7E7"
)

# Jitter with a fixed seed so the plot is reproducible
set.seed(42)

# Mean + SD summary for overlay
dir_mean_sd <- spine_usable %>%
  group_by(type_group) %>%
  summarise(
    mean_n = mean(n_directions, na.rm = TRUE),
    sd_n   = sd(n_directions, na.rm = TRUE),
    .groups = "drop"
  )

p_box <- ggplot(
  spine_usable,
  aes(x = type_group, y = n_directions)
) +
  # Individual hospital points — uniform colour, jittered to separate overlapping integers
  geom_jitter(width = 0.2, height = 0.15, alpha = 0.5, size = 1.6,
              colour = "#4292C6") +
  # Mean bar — thick horizontal segment
  geom_crossbar(
    data    = dir_mean_sd,
    aes(x = type_group, y = mean_n, ymin = mean_n, ymax = mean_n),
    width   = 0.45,
    colour  = "grey15",
    linewidth = 1.2,
    inherit.aes = FALSE
  ) +
  # SD error bars
  geom_errorbar(
    data    = dir_mean_sd,
    aes(x = type_group, y = mean_n,
        ymin = mean_n - sd_n, ymax = mean_n + sd_n),
    width   = 0.18,
    colour  = "grey15",
    linewidth = 0.7,
    inherit.aes = FALSE
  ) +
  scale_y_continuous(
    limits = c(0, 12),
    breaks = seq(0, 12, by = 2),
    expand = expansion(mult = c(0, 0.05))
  ) +
  labs(
    title    = "Strategic Direction Count by Hospital Type",
    subtitle = sprintf(
      "Ontario hospitals (n = %d); full/partial extractions only\nEach point = one hospital  |  Bar = mean  |  Error bars = \u00b11 SD",
      n_usable
    ),
    x = NULL,
    y = "Number of strategic directions",
    caption = paste0(
      "Source: HospitalIntelligenceR Phase 2 extraction.\n",
      "Specialty includes Chronic/Rehabilitation and Specialty Mental Health hospitals.\n",
      "Thin extractions (n=11) and robots-blocked hospitals (n=7) excluded."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(colour = "grey40", size = 8),
    plot.caption  = element_text(colour = "grey50", size = 6.5),
    panel.grid.major.x = element_blank(),
    panel.grid.minor.y = element_blank(),
    axis.text.x   = element_text(size = 9),
    axis.text.y   = element_text(size = 9),
    axis.title.y  = element_text(size = 9)
  )

ggsave(
  "analysis/outputs/figures/01a_direction_count_boxplot.png",
  plot   = p_box,
  width  = 7,
  height = 5,
  dpi    = 300
)
cat("Figure saved: 01a_direction_count_boxplot.png\n")


# =============================================================================
# SECTION 7: Plot 2 — Extraction quality stacked bar by hospital type
# =============================================================================

QUALITY_COLOURS <- c(
  "full"    = "#4DAC26",
  "partial" = "#B8E186",
  "thin"    = "#F1B6DA",
  "no_data" = "#D01C8B"
)

quality_long <- spine_01a %>%
  filter(robots_allowed == TRUE) %>%
  mutate(
    extraction_quality = factor(
      extraction_quality,
      levels = c("full", "partial", "thin", "no_data")
    )
  ) %>%
  group_by(type_group, extraction_quality) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(type_group) %>%
  mutate(pct = 100 * n / sum(n)) %>%
  ungroup()

p_stack <- ggplot(
  quality_long,
  aes(x = type_group, y = pct, fill = extraction_quality)
) +
  geom_col(width = 0.6, colour = "white", linewidth = 0.3) +
  geom_text(
    aes(label = ifelse(pct >= 5, paste0(round(pct), "%"), "")),
    position = position_stack(vjust = 0.5),
    size = 3, colour = "grey20"
  ) +
  scale_fill_manual(
    values = QUALITY_COLOURS,
    labels = c("Full", "Partial", "Thin", "No data"),
    name   = "Extraction quality"
  ) +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(
    title    = "Extraction Quality by Hospital Type",
    subtitle = "Robots-allowed hospitals only",
    x = NULL,
    y = "Percentage of hospitals",
    caption = paste0(
      "Source: HospitalIntelligenceR Phase 2 extraction.\n",
      "Specialty includes Chronic/Rehabilitation and Specialty Mental Health hospitals.\n",
      "Robots-blocked hospitals (n=7) excluded."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title    = element_text(face = "bold", size = 13),
    plot.subtitle = element_text(colour = "grey40", size = 9),
    plot.caption  = element_text(colour = "grey50", size = 7),
    panel.grid.major.x = element_blank(),
    legend.position = "right"
  )

ggsave(
  "analysis/outputs/figures/01a_extraction_quality_stacked.png",
  plot   = p_stack,
  width  = 7,
  height = 5,
  dpi    = 300
)
cat("Figure saved: 01a_extraction_quality_stacked.png\n")


# =============================================================================
# SECTION 8: Narrative summary
# =============================================================================

cat("\n========== DIRECTION 1a SUMMARY ==========\n")
cat(sprintf("  Analytical cohort:         %d hospitals (full/partial)\n", n_usable))
cat(sprintf("  Excluded — thin:           %d hospitals\n", n_thin))
cat(sprintf("  Excluded — no data:        %d hospitals\n", n_no_data))
cat(sprintf("  Excluded — robots-blocked: %d hospitals\n", n_robots_blocked))
cat("\n  Direction count by type (mean / median):\n")
for (i in seq_len(nrow(direction_summary))) {
  cat(sprintf("    %-22s n=%2d  mean=%.1f  median=%g  range=%g–%g\n",
              as.character(direction_summary$type_group[i]),
              direction_summary$n_hospitals[i],
              direction_summary$mean_dirs[i],
              direction_summary$median_dirs[i],
              direction_summary$min_dirs[i],
              direction_summary$max_dirs[i]))
}
cat("==========================================\n")