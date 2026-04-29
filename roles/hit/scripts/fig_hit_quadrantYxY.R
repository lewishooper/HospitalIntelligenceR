# =============================================================================
# roles/hit/scripts/fig_hit_quadrant.R
# HospitalIntelligenceR — Revenue vs Expense Change Quadrant Scatter
# Faceted by year-over-year transition
#
# Each point = one hospital in one year-over-year transition.
# X-axis: % change in total revenue (ind01)
# Y-axis: % change in total expenses (ind02)
# Diagonal (y = x): zero margin impact
# Above diagonal: expense-led pressure | Below: revenue-led improvement
#
# Faceted by transition year so each panel shows one year's pattern.
# Acute hospitals only. Colour = hospital type group.
#
# Follows figure_standards.md:
#   theme_linedraw() | sans font | Dark2 type colours | 12 x 10 in | 300 DPI
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
  pivot_wider(names_from = indicator_code, values_from = value) %>%
  rename(revenue = ind01, expense = ind02) %>%
  arrange(fac, fiscal_year)

# -----------------------------------------------------------------------------
# Compute year-over-year % change
# -----------------------------------------------------------------------------

yoy <- rev_exp %>%
  group_by(fac) %>%
  arrange(fiscal_year, .by_group = TRUE) %>%
  mutate(
    rev_prior   = lag(revenue),
    exp_prior   = lag(expense),
    year_from   = lag(fiscal_year),
    year_to     = fiscal_year,
    rev_chg_pct = 100 * (revenue - rev_prior) / rev_prior,
    exp_chg_pct = 100 * (expense - exp_prior) / exp_prior,
    transition  = paste0(str_sub(year_from, 1, 4), "→",
                         str_sub(year_to,   6, 9))
  ) %>%
  filter(!is.na(rev_prior)) %>%
  ungroup() %>%
  left_join(hospital_lookup, by = "fac") %>%
  mutate(
    hospital_type_group = factor(hospital_type_group, levels = acute_types),
    transition = factor(transition, levels = sort(unique(transition)))
  )

message(sprintf("Year-over-year observations: %d", nrow(yoy)))
message("Observations per transition:")
print(table(yoy$transition))

# Axis range: 1st–99th percentile across ALL years so panels are comparable
x_lims     <- quantile(yoy$rev_chg_pct, c(0.01, 0.99), na.rm = TRUE)
y_lims     <- quantile(yoy$exp_chg_pct, c(0.01, 0.99), na.rm = TRUE)
axis_range <- range(c(x_lims, y_lims))
axis_pad   <- diff(axis_range) * 0.10
ax_lo      <- axis_range[1] - axis_pad
ax_hi      <- axis_range[2] + axis_pad

# Quadrant label positions — placed consistently across all panels
ql_inset <- diff(axis_range) * 0.05   # small inset from edge
q_top    <- ax_hi - ql_inset
q_bot    <- ax_lo + ql_inset
q_right  <- ax_hi - ql_inset
q_left   <- ax_lo + ql_inset

# Build a label data frame so annotations work inside facet_wrap
transitions <- levels(yoy$transition)
n_trans     <- length(transitions)
quad_labels <- tibble(
  transition  = factor(rep(transitions, each = 4), levels = transitions),
  x           = rep(c(q_right, q_left,  q_right, q_left),  times = n_trans),
  y           = rep(c(q_top,   q_top,   q_bot,   q_bot),   times = n_trans),
  label       = rep(c("Expense-led\npressure",
                      "Revenue fell,\nexpenses rose",
                      "Revenue-led\nimprovement",
                      "Both contracted"),             times = n_trans),
  hjust       = rep(c(1, 0, 1, 0),                   times = n_trans),
  colour_quad = rep(c("bad", "bad", "good", "bad"),  times = n_trans)
)

quad_colours <- c("bad" = "#993300", "good" = "#1B6644")

# -----------------------------------------------------------------------------
# Base theme — slightly smaller text for faceted panels
# -----------------------------------------------------------------------------

base_theme <- theme_linedraw(base_size = 9, base_family = "sans") +
  theme(
    plot.title       = element_text(face = "bold", size = 12),
    plot.subtitle    = element_text(size = 9, colour = "grey40"),
    plot.caption     = element_text(size = 7.5, colour = "grey50", hjust = 0),
    legend.position  = "right",
    legend.title     = element_text(size = 9, face = "bold"),
    legend.text      = element_text(size = 8.5),
    legend.key.size  = unit(0.85, "lines"),
    axis.title       = element_text(size = 8),
    axis.text        = element_text(size = 7),
    panel.grid.minor = element_blank(),
    strip.background = element_rect(fill = "grey92", colour = NA),
    strip.text       = element_text(face = "bold", size = 9)
  )

# -----------------------------------------------------------------------------
# Faceted quadrant scatter
# -----------------------------------------------------------------------------

p <- ggplot(yoy, aes(x = rev_chg_pct, y = exp_chg_pct,
                     colour = hospital_type_group)) +
  
  # Quadrant shading — pressure zones light grey, improvement zone clear
  geom_rect(aes(xmin = 0,    xmax =  Inf, ymin = 0,    ymax =  Inf),
            fill = "grey80", alpha = 0.25, colour = NA,
            inherit.aes = FALSE) +
  geom_rect(aes(xmin = -Inf, xmax =  0,   ymin = 0,    ymax =  Inf),
            fill = "grey80", alpha = 0.40, colour = NA,
            inherit.aes = FALSE) +
  geom_rect(aes(xmin = -Inf, xmax =  0,   ymin = -Inf, ymax =  0),
            fill = "grey80", alpha = 0.25, colour = NA,
            inherit.aes = FALSE) +
  geom_rect(aes(xmin = 0,    xmax =  Inf, ymin = -Inf, ymax =  0),
            fill = NA, colour = NA,
            inherit.aes = FALSE) +
  
  # Reference lines
  geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.4) +
  geom_vline(xintercept = 0, colour = "grey50", linewidth = 0.4) +
  geom_abline(slope = 1, intercept = 0,
              colour = "grey30", linewidth = 0.6, linetype = "dashed") +
  
  # Quadrant labels via data frame — renders correctly inside each panel
  geom_text(data = quad_labels,
            aes(x = x, y = y, label = label, hjust = hjust,
                colour = colour_quad),
            size = 2.2, fontface = "bold", inherit.aes = FALSE) +
  
  # Data points
  geom_point(size = 1.6, alpha = 0.6) +
  
  # Facet by transition year
  facet_wrap(~ transition, ncol = 3) +
  
  scale_colour_manual(
    values = c(type_colours, quad_colours),
    breaks = names(type_colours),        # legend shows only hospital types
    name   = "Hospital type",
    guide  = guide_legend(
      override.aes = list(size = 3.5, alpha = 1),
      keywidth     = unit(1.2, "lines")
    )
  ) +
  
  scale_x_continuous(
    labels = label_percent(scale = 1, accuracy = 1, suffix = "%"),
    limits = c(ax_lo, ax_hi)
  ) +
  
  scale_y_continuous(
    labels = label_percent(scale = 1, accuracy = 1, suffix = "%"),
    limits = c(ax_lo, ax_hi)
  ) +
  
  labs(
    title    = "The 2019→2020 and 2022→2023 transitions show the clearest expense-led pressure",
    subtitle = paste0(
      "Year-over-year % change in revenue vs expenses by transition. ",
      "Each point = one acute hospital. Dashed diagonal = zero margin impact."
    ),
    x       = "% change in total revenue",
    y       = "% change in total expenses",
    caption = paste0(
      "Source: Ontario Ministry of Health HIT global download | ",
      "Acute hospitals only (Community Large, Community Small, Teaching). ",
      "Axis range fixed across panels (1st–99th percentile). ",
      "Points beyond axis limits are excluded from view but included in counts."
    )
  ) +
  
  base_theme

# -----------------------------------------------------------------------------
# Save — wide format, 2 rows × 3 cols
# -----------------------------------------------------------------------------

ggsave(
  filename = file.path(FIG_DIR, "fig_hit_quadrantYxY.png"),
  plot     = p,
  width    = 12,
  height   = 9,
  dpi      = 300,
  units    = "in"
)
