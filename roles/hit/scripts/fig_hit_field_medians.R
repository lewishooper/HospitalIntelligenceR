# =============================================================================
# roles/hit/scripts/fig_hit_field_medians.R
# HospitalIntelligenceR — HIT Publication Figure
#
# Field median YoY % change in total revenue and total expenses
# across six fiscal year transitions, 2018/2019–2024/2025.
#
# Reads:  field_medians (object in memory from hit_01_field_segmentation.R)
# Writes: roles/hit/outputs/figures/publication/fig_hit_field_medians.png
#
# Run after hit_01_field_segmentation.R (field_medians must be in environment)
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(scales)
})

# -----------------------------------------------------------------------------
# 0. Output path
# -----------------------------------------------------------------------------

FIG_DIR <- "roles/hit/outputs/figures/publication"
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Prepare plot data
# -----------------------------------------------------------------------------

# Pivot field_medians to long format for ggplot
plot_data <- field_medians %>%
  select(fiscal_year, field_med_rev_yoy, field_med_exp_yoy, n_fac_rev) %>%
  pivot_longer(
    cols      = c(field_med_rev_yoy, field_med_exp_yoy),
    names_to  = "metric",
    values_to = "median_yoy"
  ) %>%
  mutate(
    metric_label = case_when(
      metric == "field_med_rev_yoy" ~ "Total Revenue",
      metric == "field_med_exp_yoy" ~ "Total Expenses"
    ),
    metric_label = factor(metric_label,
                          levels = c("Total Revenue", "Total Expenses")),
    # Short transition label for x-axis: "to" year only
    year_label = sub("^\\d{4}/", "", fiscal_year)
  )

# Min and max n for caption
n_min <- min(field_medians$n_fac_rev)
n_max <- max(field_medians$n_fac_rev)

# Point labels — rounded to 1 decimal
plot_data <- plot_data %>%
  mutate(pt_label = sprintf("%.1f%%", median_yoy))

# -----------------------------------------------------------------------------
# 2. Base theme (per figure_standards.md)
# -----------------------------------------------------------------------------

base_theme <- theme_linedraw(base_size = 11, base_family = "sans") +
  theme(
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(size = 10, colour = "grey40"),
    plot.caption     = element_text(size = 8, colour = "grey50", hjust = 0),
    legend.position  = "right",
    legend.title     = element_text(size = 9),
    legend.text      = element_text(size = 9),
    axis.title       = element_text(size = 10),
    axis.text        = element_text(size = 9),
    panel.grid.minor = element_blank(),
    strip.background = element_rect(fill = "grey92", colour = NA),
    strip.text       = element_text(face = "bold", size = 9)
  )

# Colours — Dark2 first two: teal for revenue, orange for expense
COLOUR_REV <- "#1B9E77"
COLOUR_EXP <- "#D95F02"

metric_colours  <- c("Total Revenue" = COLOUR_REV, "Total Expenses" = COLOUR_EXP)
metric_linetypes <- c("Total Revenue" = "solid",   "Total Expenses" = "dashed")
metric_shapes    <- c("Total Revenue" = 16,         "Total Expenses" = 17)

# -----------------------------------------------------------------------------
# 3. Build figure
# -----------------------------------------------------------------------------

p <- ggplot(
  plot_data,
  aes(x     = year_label,
      y     = median_yoy,
      colour = metric_label,
      linetype = metric_label,
      shape  = metric_label,
      group  = metric_label)
) +
  
  # Zero reference line
  geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.4, linetype = "dotted") +
  
  # Lines
  geom_line(linewidth = 1.0) +
  
  # Points
  geom_point(size = 3.2, fill = "white") +
  
  # Point labels — revenue above, expense below to avoid overlap
  geom_text(
    data = plot_data %>% filter(metric == "field_med_rev_yoy"),
    aes(label = pt_label),
    vjust  = -1.1,
    size   = 3.0,
    colour = COLOUR_REV,
    fontface = "plain"
  ) +
  geom_text(
    data = plot_data %>% filter(metric == "field_med_exp_yoy"),
    aes(label = pt_label),
    vjust  = 2.1,
    size   = 3.0,
    colour = COLOUR_EXP,
    fontface = "plain"
  ) +
  
  # COVID annotation band — 2020/2021 spike
  annotate(
    "rect",
    xmin  = 1.5, xmax = 2.5,    # 2020/2021 is the second transition
    ymin  = -Inf, ymax = Inf,
    fill  = "grey85", alpha = 0.35
  ) +
  annotate(
    "text",
    x     = 2,
    y     = 13.5,
    label = "COVID\nfunding",
    size  = 2.8,
    colour = "grey40",
    fontface = "italic",
    vjust = 0
  ) +
  
  # Scales
  scale_colour_manual(
    values = metric_colours,
    name   = "Indicator"
  ) +
  scale_linetype_manual(
    values = metric_linetypes,
    name   = "Indicator"
  ) +
  scale_shape_manual(
    values = metric_shapes,
    name   = "Indicator"
  ) +
  scale_y_continuous(
    labels = function(x) paste0(x, "%"),
    breaks = seq(-2, 16, by = 2),
    expand = expansion(mult = c(0.08, 0.12))
  ) +
  scale_x_discrete(
    expand = expansion(add = 0.5)
  ) +
  
  # Labels
  labs(
    title    = "COVID relief funding dominated sector revenue in 2020/21 and 2023/24",
    subtitle = paste0(
      "Sector-wide median year-over-year % change in total revenue and total expenses\n",
      "Field medians computed across all ", n_max, " Ontario public hospitals in the analytical cohort"
    ),
    x       = "Fiscal year transition (to year)",
    y       = "Median YoY % change",
    caption = paste0(
      "Source: HospitalIntelligenceR | Ontario Ministry of Health HIT Global data | ",
      "n = ", n_min, "\u2013", n_max, " hospitals per transition\n",
      "Field medians used as sector baseline for individual hospital trajectory adjustment."
    )
  ) +
  
  base_theme +
  theme(
    legend.key.width = unit(1.8, "cm")   # enough space to show dashed line
  )

# -----------------------------------------------------------------------------
# 4. Save
# -----------------------------------------------------------------------------

ggsave(
  filename = file.path(FIG_DIR, "fig_hit_field_medians.png"),
  plot     = p,
  width    = 7,
  height   = 5,
  dpi      = 300,
  units    = "in"
)

message("Figure saved: fig_hit_field_medians.png")
message(sprintf("  Path: %s", file.path(FIG_DIR, "fig_hit_field_medians.png")))