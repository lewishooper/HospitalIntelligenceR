rm(list=ls())
# =============================================================================
# roles/hit/scripts/fig_hit_quadrant.R
# HospitalIntelligenceR — Revenue vs Expense Change Quadrant Scatter
#
# Each point = one hospital in one year-over-year transition.
# X-axis: % change in total revenue (ind01)
# Y-axis: % change in total expenses (ind02)
# Diagonal (y = x): zero margin impact — revenue and expense moved equally
# Above diagonal: expenses grew faster than revenue (margin pressure)
# Below diagonal: revenue grew faster than expenses (margin improvement)
#
# Acute hospitals only. Colour = hospital type group.
# Up to 6 year-over-year transitions per hospital (2018/19→2024/25).
#
# Quadrant annotations:
#   Q1 (top-right):  Both grew — expense-led (pressure)
#   Q2 (top-left):   Revenue fell, expenses rose (crisis)
#   Q3 (bottom-left): Both fell — revenue-led (contraction)
#   Q4 (bottom-right): Revenue grew faster (MOH injection / relief)
#
# Follows figure_standards.md:
#   theme_linedraw() | sans font | Dark2 type colours | 7 x 7 in | 300 DPI
# =============================================================================

library(tidyverse)
library(scales)

HIT_MASTER <- "roles/hit/outputs/hit_master.csv"
STRATEGY   <- "analysis/data/strategy_master_analytical.csv"
FIG_DIR    <- "roles/hit/outputs/figures"
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# Fixed type group colour palette (figure_standards.md)
# -----------------------------------------------------------------------------

type_colours <- c(
  "Community — Large" = "#1B9E77",
  "Community — Small" = "#D95F02",
  "Teaching"          = "#7570B3"
)

acute_types <- names(type_colours)

# -----------------------------------------------------------------------------
# Hospital type lookup
# -----------------------------------------------------------------------------

hospital_lookup <- read_csv(
  STRATEGY,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
) %>%
  distinct(fac, hospital_name, hospital_type_group) %>%
  filter(hospital_type_group %in% acute_types)

# -----------------------------------------------------------------------------
# Load revenue (ind01) and expense (ind02)
# -----------------------------------------------------------------------------

hit_master <- read_csv(
  HIT_MASTER,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
)

rev_exp <- hit_master %>%
  filter(indicator_code %in% c("ind01", "ind02"),
         fac %in% hospital_lookup$fac) %>%
  select(fac, fiscal_year, indicator_code, value) %>%
  pivot_wider(names_from = indicator_code,
              values_from = value) %>%
  rename(revenue = ind01, expense = ind02) %>%
  arrange(fac, fiscal_year)

# -----------------------------------------------------------------------------
# Compute year-over-year % change per hospital
# Lag within each FAC to get adjacent-year pairs
# -----------------------------------------------------------------------------

yoy <- rev_exp %>%
  group_by(fac) %>%
  arrange(fiscal_year, .by_group = TRUE) %>%
  mutate(
    rev_prior = lag(revenue),
    exp_prior = lag(expense),
    year_from = lag(fiscal_year),
    year_to   = fiscal_year,
    rev_chg_pct = 100 * (revenue - rev_prior) / rev_prior,
    exp_chg_pct = 100 * (expense - exp_prior) / exp_prior,
    transition  = paste0(str_sub(year_from, 1, 4), "→",
                         str_sub(year_to,   6, 9))
  ) %>%
  filter(!is.na(rev_prior)) %>%   # drop first year (no lag)
  ungroup() %>%
  left_join(hospital_lookup, by = "fac") %>%
  mutate(hospital_type_group = factor(hospital_type_group, levels = acute_types))

message(sprintf("Year-over-year observations: %d", nrow(yoy)))
message(sprintf("Hospitals represented: %d", n_distinct(yoy$fac)))
message("Transitions:")
print(table(yoy$transition))

# Trim extreme outliers for axis range (keep 1st–99th percentile)
# Outliers still plotted but axes won't be dominated by one anomalous year
x_lims <- quantile(yoy$rev_chg_pct, c(0.01, 0.99), na.rm = TRUE)
y_lims <- quantile(yoy$exp_chg_pct, c(0.01, 0.99), na.rm = TRUE)
axis_range <- range(c(x_lims, y_lims))   # symmetric feel
axis_pad   <- diff(axis_range) * 0.12

# How many points fall outside the trimmed range
n_clipped <- yoy %>%
  filter(rev_chg_pct < x_lims[1] | rev_chg_pct > x_lims[2] |
           exp_chg_pct < y_lims[1] | exp_chg_pct > y_lims[2]) %>%
  nrow()
message(sprintf("Points outside 1st-99th percentile (still plotted): %d", n_clipped))

# -----------------------------------------------------------------------------
# Quadrant label positions — inside the plot area
# -----------------------------------------------------------------------------

qx_right <- axis_range[2] + axis_pad * 0.6
qx_left  <- axis_range[1] - axis_pad * 0.6
qy_top   <- axis_range[2] + axis_pad * 0.6
qy_bot   <- axis_range[1] - axis_pad * 0.6

# -----------------------------------------------------------------------------
# Base theme
# -----------------------------------------------------------------------------

base_theme <- theme_linedraw(base_size = 10, base_family = "sans") +
  theme(
    plot.title       = element_text(face = "bold", size = 12),
    plot.subtitle    = element_text(size = 9, colour = "grey40"),
    plot.caption     = element_text(size = 7.5, colour = "grey50", hjust = 0),
    legend.position  = "right",
    legend.title     = element_text(size = 9, face = "bold"),
    legend.text      = element_text(size = 8.5),
    legend.key.size  = unit(0.85, "lines"),
    axis.title       = element_text(size = 9),
    axis.text        = element_text(size = 8),
    panel.grid.minor = element_blank()
  )

# -----------------------------------------------------------------------------
# Quadrant scatter
# -----------------------------------------------------------------------------

p <- ggplot(yoy, aes(x = rev_chg_pct, y = exp_chg_pct,
                     colour = hospital_type_group)) +
  
  # --- Reference lines ---
  
  # Axes through zero
  geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.5) +
  geom_vline(xintercept = 0, colour = "grey50", linewidth = 0.5) +
  
  # Diagonal: y = x — zero net margin impact
  geom_abline(slope = 1, intercept = 0,
              colour = "grey30", linewidth = 0.7, linetype = "dashed") +
  
  # Diagonal label
  annotate("text",
           x = axis_range[2] * 0.55,
           y = axis_range[2] * 0.55 + axis_pad * 0.55,
           label = "Revenue = Expense change\n(zero margin impact)",
           colour = "grey30", size = 2.4, hjust = 0, fontface = "italic") +
  
  # --- Quadrant shading ---
  
  annotate("rect",
           xmin = 0, xmax = Inf, ymin = 0, ymax = Inf,
           fill = "#CC3300", alpha = 0.04) +   # Q1: both up, expense-led
  
  annotate("rect",
           xmin = -Inf, xmax = 0, ymin = -Inf, ymax = 0,
           fill = "#CC3300", alpha = 0.04) +   # Q3: both down, revenue-led
  
  annotate("rect",
           xmin = 0, xmax = Inf, ymin = -Inf, ymax = 0,
           fill = "#1B9E77", alpha = 0.04) +   # Q4: revenue-led improvement
  
  annotate("rect",
           xmin = -Inf, xmax = 0, ymin = 0, ymax = Inf,
           fill = "#CC3300", alpha = 0.06) +   # Q2: revenue down, expense up
  
  # --- Quadrant labels ---
  
  annotate("text", x = axis_range[2] * 0.85, y = axis_range[2] * 0.97,
           label = "Expense-led\npressure",
           colour = "#993300", size = 2.6, hjust = 1, fontface = "bold") +
  
  annotate("text", x = axis_range[1] * 0.85, y = axis_range[2] * 0.97,
           label = "Revenue fell,\nexpenses rose",
           colour = "#993300", size = 2.6, hjust = 0, fontface = "bold") +
  
  annotate("text", x = axis_range[2] * 0.85, y = axis_range[1] * 0.97,
           label = "Revenue-led\nimprovement",
           colour = "#1B6644", size = 2.6, hjust = 1, fontface = "bold") +
  
  annotate("text", x = axis_range[1] * 0.85, y = axis_range[1] * 0.97,
           label = "Both contracted\n(revenue-led)",
           colour = "#993300", size = 2.6, hjust = 0, fontface = "bold") +
  
  # --- Data points ---
  
  geom_point(size = 1.8, alpha = 0.55) +
  
  # --- Scales ---
  
  scale_colour_manual(
    values = type_colours,
    name   = "Hospital type",
    guide  = guide_legend(
      override.aes = list(size = 3.5, alpha = 1),
      keywidth     = unit(1.2, "lines")
    )
  ) +
  
  scale_x_continuous(
    labels = label_percent(scale = 1, accuracy = 1, suffix = "%"),
    limits = c(axis_range[1] - axis_pad, axis_range[2] + axis_pad)
  ) +
  
  scale_y_continuous(
    labels = label_percent(scale = 1, accuracy = 1, suffix = "%"),
    limits = c(axis_range[1] - axis_pad, axis_range[2] + axis_pad)
  ) +
  
  labs(
    title    = "Margin pressure is mostly expense-driven; revenue injections visible in 2020/21",
    subtitle = sprintf(
      "Year-over-year %% change in revenue vs expenses. Each point = one hospital-year transition. n = %d observations, %d acute hospitals.",
      nrow(yoy), n_distinct(yoy$fac)
    ),
    x       = "% change in total revenue (year over year)",
    y       = "% change in total expenses (year over year)",
    caption = paste0(
      "Source: Ontario Ministry of Health HIT global download | ",
      "Acute hospitals only (Community Large, Community Small, Teaching). ",
      "Points above the diagonal = expenses grew faster than revenue (margin pressure). ",
      if (n_clipped > 0)
        sprintf("%d extreme outlier point(s) outside 1st–99th percentile range shown but may exceed axis limits.", n_clipped)
      else ""
    )
  ) +
  
  base_theme

# -----------------------------------------------------------------------------
# Save
# -----------------------------------------------------------------------------

ggsave(
  filename = file.path(FIG_DIR, "fig_hit_quadrant.png"),
  plot     = p,
  width    = 8,
  height   = 7,
  dpi      = 300,
  units    = "in"
)

message("Figure written: ", file.path(FIG_DIR, "fig_hit_quadrant.png"))