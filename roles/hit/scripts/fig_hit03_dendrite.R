# =============================================================================
# fig_hit03_dendrite.R
# Dendrite graph — hospital-level field-adjusted trajectories, plan-anchored
#
## Purpose:
#   Visualise year-by-year field-adjusted revenue and expense changes for all
#   55 with-plan hospitals, aligned to years since plan initiation rather than
#   calendar fiscal year. Each hospital is one semi-transparent line. A group
#   median spine and a y = 0 field-reference line are overlaid.
#
# Inputs (read-only):
#   roles/hit/outputs/hit_03_year_level.csv    — FAC × fiscal_year, adj YoY values
#   roles/hit/outputs/hit_03_hospital_level.csv — plan_first_fy, plan_group, fin_flag
#
# Outputs:
#   roles/hit/outputs/figures/publication/fig_hit03_dendrite_revenue.png
#   roles/hit/outputs/figures/publication/fig_hit03_dendrite_expense.png
#   roles/hit/outputs/figures/publication/fig_hit03_dendrite_combined.png
#
# Dimensions: 7 × 5 inches each; combined panel 7 × 8 inches
# Resolution: 300 DPI
# =============================================================================

library(ggplot2)
library(dplyr)
library(readr)
library(patchwork)
library(scales)

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------

YEAR_LEVEL_PATH  <- "roles/hit/outputs/hit_03_year_level.csv"
HOSP_LEVEL_PATH  <- "roles/hit/outputs/hit_03_hospital_level.csv"
FIG_DIR          <- "roles/hit/outputs/figures/publication"

dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# Base theme — per figure_standards.md Section 3
# -----------------------------------------------------------------------------

base_theme <- theme_linedraw(base_size = 11, base_family = "sans") +
  theme(
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(size = 10, colour = "grey40"),
    plot.caption     = element_text(size = 8, colour = "grey50", hjust = 0),
    legend.position  = "right",
    legend.title     = element_text(size = 9),
    legend.text      = element_text(size = 8),
    axis.title       = element_text(size = 10),
    axis.text        = element_text(size = 9),
    panel.grid.minor = element_blank(),
    strip.background = element_rect(fill = "grey92", colour = NA),
    strip.text       = element_text(face = "bold", size = 9)
  )

# -----------------------------------------------------------------------------
# Colours
# -----------------------------------------------------------------------------

HOSPITAL_LINE_COLOUR <- "#7570B3"   # Dark2 purple — neutral, not type-coded
HOSPITAL_LINE_ALPHA  <- 0.25
HOSPITAL_LINE_SIZE   <- 0.45

MEDIAN_LINE_COLOUR   <- "#D95F02"   # Dark2 orange — contrasts clearly with purple
MEDIAN_LINE_SIZE     <- 1.4

ZERO_LINE_COLOUR     <- "grey30"
ZERO_LINE_SIZE       <- 0.6

N_SPINE_MIN          <- 10L    # Spine points below this n render as hollow circles

# -----------------------------------------------------------------------------
# Load data
# -----------------------------------------------------------------------------

year_level <- read_csv(
  YEAR_LEVEL_PATH,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
)

hosp_level <- read_csv(
  HOSP_LEVEL_PATH,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
)

# -----------------------------------------------------------------------------
# Restrict to 55 with-plan hospitals; pull plan_first_fy
# -----------------------------------------------------------------------------

with_plan <- hosp_level %>%
  filter(grepl("With strategic plan", plan_group)) %>%
  select(fac, plan_first_fy, hospital_type_group)

message(sprintf("With-plan hospitals: %d", nrow(with_plan)))

# -----------------------------------------------------------------------------
# Build plan-anchored dataset
# -----------------------------------------------------------------------------
# For each with-plan hospital, keep only fiscal years >= plan_first_fy,
# then rank them 0, 1, 2, ... within each hospital.
# String sort of YYYY/YYYY is lexicographically correct — no date conversion needed.

dendrite_raw <- year_level %>%
  filter(fac %in% with_plan$fac) %>%
  left_join(with_plan %>% select(fac, plan_first_fy), by = "fac") %>%
  filter(fiscal_year >= plan_first_fy) %>%
  arrange(fac, fiscal_year) %>%
  group_by(fac) %>%
  mutate(
    years_since_plan = row_number() - 1L   # 0-indexed
  ) %>%
  ungroup() %>%
  select(fac, hospital_type_group, fiscal_year, years_since_plan,
         rev_yoy_adj, exp_yoy_adj)

message(sprintf("Dendrite rows (FAC × time step): %d", nrow(dendrite_raw)))
message(sprintf("Years-since-plan range: %d – %d",
                min(dendrite_raw$years_since_plan),
                max(dendrite_raw$years_since_plan)))

# Hospital counts per time step — useful for caption and median interpretation
step_counts <- dendrite_raw %>%
  group_by(years_since_plan) %>%
  summarise(n_hospitals = n_distinct(fac), .groups = "drop")

message("\nHospitals per time step:")
print(step_counts)

# -----------------------------------------------------------------------------
# Group median spine — median of adjusted values at each time step
# (across whichever hospitals are present at that step)
# -----------------------------------------------------------------------------

median_spine <- dendrite_raw %>%
  group_by(years_since_plan) %>%
  summarise(
    med_rev = median(rev_yoy_adj, na.rm = TRUE),
    med_exp = median(exp_yoy_adj, na.rm = TRUE),
    n        = n_distinct(fac),
    .groups  = "drop"
  ) %>%
  mutate(spine_solid = n >= N_SPINE_MIN)

message("\nMedian spine values:")
print(median_spine %>% mutate(across(c(med_rev, med_exp), \(x) round(x, 2))))

# -----------------------------------------------------------------------------
# Caption text — shared across both panels
# -----------------------------------------------------------------------------

n_hospitals <- n_distinct(dendrite_raw$fac)
max_step    <- max(dendrite_raw$years_since_plan)

CAPTION <- paste0(
  "Source: HospitalIntelligenceR HIT Analytics Workstream  |  ",
  sprintf("n = %d hospitals with strategic plans in place \u22652 years  |  ", n_hospitals),
  "Y-axis: annual field-adjusted revenue or expense growth (pp above/below sector median)  |  ",
  sprintf("X-axis: years since plan initiation (0 = first post-plan fiscal year); max = %d", max_step)
)

# -----------------------------------------------------------------------------
# Revenue dendrite panel
# -----------------------------------------------------------------------------

x_breaks <- sort(unique(dendrite_raw$years_since_plan))

p_rev <- ggplot() +
  # y = 0 field reference line — drawn first so lines sit on top
  geom_hline(
    yintercept = 0,
    colour     = ZERO_LINE_COLOUR,
    linewidth  = ZERO_LINE_SIZE,
    linetype   = "dashed"
  ) +
  # Individual hospital lines
  geom_line(
    data    = dendrite_raw,
    mapping = aes(x = years_since_plan, y = rev_yoy_adj, group = fac),
    colour  = HOSPITAL_LINE_COLOUR,
    alpha   = HOSPITAL_LINE_ALPHA,
    linewidth = HOSPITAL_LINE_SIZE
  ) +
  # Group median spine
  geom_line(
    data    = median_spine,
    mapping = aes(x = years_since_plan, y = med_rev),
    colour  = MEDIAN_LINE_COLOUR,
    linewidth = MEDIAN_LINE_SIZE,
    lineend = "round"
  ) +
  geom_point(
    data    = median_spine,
    mapping = aes(x = years_since_plan, y = med_rev,
                  shape = spine_solid),
    colour  = MEDIAN_LINE_COLOUR,
    size    = 2.5,
    stroke  = 1.1,
    fill    = MEDIAN_LINE_COLOUR
  ) +
  scale_shape_manual(
    values = c(`TRUE` = 21, `FALSE` = 1),   # 21 = filled circle; 1 = hollow circle
    guide  = "none"
  ) +
  scale_x_continuous(
    breaks = x_breaks,
    labels = as.character(x_breaks)
  ) +
  scale_y_continuous(
    labels = function(x) paste0(ifelse(x >= 0, "+", ""), x, "pp")
  ) +
  labs(
    title    = "Hospital revenue trajectories cluster near the field median after plan adoption",
    subtitle = paste0(
      "Each line = one hospital (n = ", n_hospitals, "). ",
      "Orange line = group median (filled = n \u226510; hollow = n <10). ",
      "Dashed line = sector field median (y = 0)."
    ),
    caption = CAPTION
  ) +
  base_theme

# -----------------------------------------------------------------------------
# Expense dendrite panel
# -----------------------------------------------------------------------------

p_exp <- ggplot() +
  geom_hline(
    yintercept = 0,
    colour     = ZERO_LINE_COLOUR,
    linewidth  = ZERO_LINE_SIZE,
    linetype   = "dashed"
  ) +
  geom_line(
    data    = dendrite_raw,
    mapping = aes(x = years_since_plan, y = exp_yoy_adj, group = fac),
    colour  = HOSPITAL_LINE_COLOUR,
    alpha   = HOSPITAL_LINE_ALPHA,
    linewidth = HOSPITAL_LINE_SIZE
  ) +
  geom_line(
    data    = median_spine,
    mapping = aes(x = years_since_plan, y = med_exp),
    colour  = MEDIAN_LINE_COLOUR,
    linewidth = MEDIAN_LINE_SIZE,
    lineend = "round"
  ) +
  geom_point(
    data    = median_spine,
    mapping = aes(x = years_since_plan, y = med_exp,
                  shape = spine_solid),
    colour  = MEDIAN_LINE_COLOUR,
    size    = 2.5,
    stroke  = 1.1,
    fill    = MEDIAN_LINE_COLOUR
  ) +
  scale_shape_manual(
    values = c(`TRUE` = 21, `FALSE` = 1),
    guide  = "none"
  ) +
  scale_x_continuous(
    breaks = x_breaks,
    labels = as.character(x_breaks)
  ) +
  scale_y_continuous(
    labels = function(x) paste0(ifelse(x >= 0, "+", ""), x, "pp")
  ) +
  labs(
    title    = "Expense trajectories show no systematic drift above or below field median",
    subtitle = paste0(
      "Each line = one hospital (n = ", n_hospitals, "). ",
      "Orange line = group median (filled = n \u226510; hollow = n <10). ",
      "Dashed line = sector field median (y = 0)."
    ),
    x       = "Years since plan initiation",
    y       = "Expense growth vs. field median (pp)",
    caption = CAPTION
  ) +
  base_theme

# -----------------------------------------------------------------------------
# Save individual panels
# -----------------------------------------------------------------------------

ggsave(
  filename = file.path(FIG_DIR, "fig_hit03_dendrite_revenue.png"),
  plot     = p_rev,
  width    = 7,
  height   = 5,
  dpi      = 300,
  units    = "in"
)
message("  Written: fig_hit03_dendrite_revenue.png")

ggsave(
  filename = file.path(FIG_DIR, "fig_hit03_dendrite_expense.png"),
  plot     = p_exp,
  width    = 7,
  height   = 5,
  dpi      = 300,
  units    = "in"
)
message("  Written: fig_hit03_dendrite_expense.png")

# -----------------------------------------------------------------------------
# Combined stacked panel (revenue over expense)
# -----------------------------------------------------------------------------
# Subtitles stripped from individual panels to avoid redundancy;
# a single combined subtitle carries the legend key.

p_rev_combined <- p_rev +
  labs(
    title    = "Revenue",
    subtitle = NULL,
    caption  = NULL
  ) +
  theme(plot.title = element_text(size = 11, face = "bold"))

p_exp_combined <- p_exp +
  labs(
    title    = "Expense",
    subtitle = NULL,
    caption  = CAPTION
  ) +
  theme(plot.title = element_text(size = 11, face = "bold"))

p_combined <- (p_rev_combined / p_exp_combined) +
  plot_annotation(
    title    = "Hospital financial trajectories relative to field median, aligned to plan adoption year",
    subtitle = paste0(
      "Each line = one hospital (n = ", n_hospitals, "). ",
      "Orange line = group median (filled = n \u226510; hollow = n <10). ",
      "Dashed line = sector field median (y = 0). ",
      "X-axis: years since plan initiation."
    ),
    theme = theme(
      plot.title    = element_text(face = "bold", size = 13, family = "sans"),
      plot.subtitle = element_text(size = 10, colour = "grey40", family = "sans")
    )
  )

ggsave(
  filename = file.path(FIG_DIR, "fig_hit03_dendrite_combined.png"),
  plot     = p_combined,
  width    = 7,
  height   = 8,
  dpi      = 300,
  units    = "in"
)
message("  Written: fig_hit03_dendrite_combined.png")

message("\n--- fig_hit03_dendrite.R complete ---")
message(sprintf("  Output directory: %s", FIG_DIR))
message("  Figures produced:")
message("    fig_hit03_dendrite_revenue.png  — revenue panel (7 × 5 in)")
message("    fig_hit03_dendrite_expense.png  — expense panel (7 × 5 in)")
message("    fig_hit03_dendrite_combined.png — stacked combined (7 × 8 in)")
