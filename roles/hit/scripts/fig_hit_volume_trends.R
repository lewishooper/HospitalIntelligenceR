# =============================================================================
# roles/hit/scripts/fig_hit_volume_trends.R
# HospitalIntelligenceR — HIT Publication Figure
#
# Sector-wide median clinical volume trends across seven fiscal years,
# indexed to 2018/2019 = 100. Shows COVID-era dip and recovery pattern
# for four key service volume indicators.
#
# Reads:  roles/hit/outputs/hit_master.csv
#         analysis/data/hospital_spine.csv  (scope boundary)
#
# Writes: roles/hit/outputs/figures/publication/fig_hit_volume_trends.png
#
# Standalone — does not require hit_01 objects in memory.
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(scales)
})

# -----------------------------------------------------------------------------
# 0. Paths and output directory
# -----------------------------------------------------------------------------

HIT_MASTER <- "roles/hit/outputs/hit_master.csv"
SPINE_PATH <- "analysis/data/hospital_spine.csv"
FIG_DIR    <- "roles/hit/outputs/figures/publication"
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# Volume indicators to attempt — ind59 may not be present in data
VOLUME_INDS <- c("ind45", "ind54", "ind56", "ind59")

INDICATOR_LABELS <- c(
  ind45 = "Acute Inpatient Days",
  ind54 = "Total Surgical Cases",
  ind56 = "Total ED Visits",
  ind59 = "Total Ambulatory Visits"
)

# Dark2 colours assigned to each indicator
INDICATOR_COLOURS <- c(
  ind45 = "#1B9E77",   # Teal
  ind54 = "#D95F02",   # Orange
  ind56 = "#7570B3",   # Purple
  ind59 = "#66A61E"    # Green
)

INDICATOR_SHAPES <- c(
  ind45 = 16,
  ind54 = 17,
  ind56 = 15,
  ind59 = 18
)

INDICATOR_LINETYPES <- c(
  ind45 = "solid",
  ind54 = "dashed",
  ind56 = "dotdash",
  ind59 = "longdash"
)

BASE_YEAR <- "2018/2019"

# -----------------------------------------------------------------------------
# 1. Load data and apply scope filter
# -----------------------------------------------------------------------------

message("Loading hit_master.csv...")

hit_master <- read_csv(
  HIT_MASTER,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
)

# Scope filter — registry FACs only
registry_facs <- read_csv(
  SPINE_PATH,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>%
  pull(fac)

hit_volume <- hit_master %>%
  filter(
    fac %in% registry_facs,
    indicator_code %in% VOLUME_INDS
  )

# Report which indicators are actually present
inds_present <- unique(hit_volume$indicator_code)
inds_missing <- setdiff(VOLUME_INDS, inds_present)

message(sprintf("  Indicators found:   %s", paste(inds_present, collapse = ", ")))
if (length(inds_missing) > 0) {
  message(sprintf("  Indicators absent:  %s (excluded from figure)", paste(inds_missing, collapse = ", ")))
}

# Restrict labels/colours/shapes to present indicators only
INDICATOR_LABELS   <- INDICATOR_LABELS[inds_present]
INDICATOR_COLOURS  <- INDICATOR_COLOURS[inds_present]
INDICATOR_SHAPES   <- INDICATOR_SHAPES[inds_present]
INDICATOR_LINETYPES <- INDICATOR_LINETYPES[inds_present]

# -----------------------------------------------------------------------------
# 2. Compute sector median per indicator per fiscal year
# -----------------------------------------------------------------------------

sector_medians <- hit_volume %>%
  group_by(indicator_code, fiscal_year) %>%
  summarise(
    sector_median = median(value, na.rm = TRUE),
    n_fac         = sum(!is.na(value)),
    .groups       = "drop"
  ) %>%
  arrange(indicator_code, fiscal_year)

message("\nSector medians computed:")
print(sector_medians %>%
        mutate(sector_median = round(sector_median, 0)) %>%
        pivot_wider(names_from = fiscal_year,
                    values_from = sector_median,
                    id_cols = indicator_code))

# -----------------------------------------------------------------------------
# 3. Index to base year = 100
# -----------------------------------------------------------------------------

base_values <- sector_medians %>%
  filter(fiscal_year == BASE_YEAR) %>%
  select(indicator_code, base_median = sector_median)

missing_base <- setdiff(inds_present, base_values$indicator_code)
if (length(missing_base) > 0) {
  message(sprintf(
    "WARNING: %s has no data in base year %s — cannot index. Dropping.",
    paste(missing_base, collapse = ", "), BASE_YEAR
  ))
  INDICATOR_LABELS   <- INDICATOR_LABELS[setdiff(names(INDICATOR_LABELS), missing_base)]
  INDICATOR_COLOURS  <- INDICATOR_COLOURS[setdiff(names(INDICATOR_COLOURS), missing_base)]
  INDICATOR_SHAPES   <- INDICATOR_SHAPES[setdiff(names(INDICATOR_SHAPES), missing_base)]
  INDICATOR_LINETYPES <- INDICATOR_LINETYPES[setdiff(names(INDICATOR_LINETYPES), missing_base)]
}

plot_data <- sector_medians %>%
  filter(indicator_code %in% names(INDICATOR_LABELS)) %>%
  left_join(base_values, by = "indicator_code") %>%
  mutate(
    index        = round(sector_median / base_median * 100, 1),
    ind_label    = INDICATOR_LABELS[indicator_code],
    ind_label    = factor(ind_label, levels = unname(INDICATOR_LABELS))
  )

message("\nIndexed values (2018/2019 = 100):")
print(plot_data %>%
        select(indicator_code, fiscal_year, index) %>%
        pivot_wider(names_from = fiscal_year, values_from = index,
                    id_cols = indicator_code))

# n range for caption
n_min <- min(plot_data$n_fac)
n_max <- max(plot_data$n_fac)

# -----------------------------------------------------------------------------
# 4. Base theme
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
    axis.text.x      = element_text(angle = 35, hjust = 1),
    panel.grid.minor = element_blank(),
    strip.background = element_rect(fill = "grey92", colour = NA),
    strip.text       = element_text(face = "bold", size = 9)
  )

# -----------------------------------------------------------------------------
# 5. Build figure
# -----------------------------------------------------------------------------

# COVID band — 2020/2021 is the third fiscal year on the x-axis
# Convert to numeric position for annotate
fy_levels <- sort(unique(plot_data$fiscal_year))
covid_pos  <- which(fy_levels == "2020/2021")

p <- ggplot(
  plot_data,
  aes(x        = fiscal_year,
      y        = index,
      colour   = ind_label,
      linetype = ind_label,
      shape    = ind_label,
      group    = ind_label)
) +
  
  # Reference line at 100 (base year)
  geom_hline(yintercept = 100, colour = "grey55", linewidth = 0.4,
             linetype = "dotted") +
  
  # COVID shading — 2020/2021 column
  annotate(
    "rect",
    xmin  = covid_pos - 0.5,
    xmax  = covid_pos + 0.5,
    ymin  = -Inf, ymax = Inf,
    fill  = "grey85", alpha = 0.40
  ) +
  annotate(
    "text",
    x      = covid_pos,
    y      = Inf,
    label  = "COVID\n2020/21",
    size   = 2.8,
    colour = "grey40",
    fontface = "italic",
    vjust  = 1.3
  ) +
  
  # Lines
  geom_line(linewidth = 1.0) +
  
  # Points
  geom_point(size = 3.0) +
  
  # Scales
  scale_colour_manual(
    values = setNames(INDICATOR_COLOURS, unname(INDICATOR_LABELS)),
    name   = "Volume indicator"
  ) +
  scale_linetype_manual(
    values = setNames(INDICATOR_LINETYPES, unname(INDICATOR_LABELS)),
    name   = "Volume indicator"
  ) +
  scale_shape_manual(
    values = setNames(INDICATOR_SHAPES, unname(INDICATOR_LABELS)),
    name   = "Volume indicator"
  ) +
  scale_x_discrete(
    limits = fy_levels,
    expand = expansion(add = 0.4)
  ) +
  scale_y_continuous(
    labels = function(x) paste0(x),
    breaks = seq(60, 160, by = 10),
    expand = expansion(mult = c(0.05, 0.08))
  ) +
  
  # Labels
  labs(
    title    = "Comparison of Clinical Volume Trends",
    subtitle = paste0(
      "Sector-wide median volume by indicator, indexed to 2018/2019 = 100\n",
      "Index above 100 indicates growth relative to pre-pandemic baseline"
    ),
    x       = "Fiscal Year",
    y       = "Index (2018/2019 = 100)",
    caption = paste0(
      "Source: HospitalIntelligenceR | Ontario Ministry of Health HIT Global data | ",
      "n = ", n_min, "\u2013", n_max, " hospitals per indicator per year\n",
      "Medians computed across registry-matched Ontario public hospitals only. ",
      "Structural outliers (FAC 854, 971) included in medians."
    )
  ) +
  
  base_theme +
  theme(
    legend.key.width = unit(1.8, "cm")
  )

# -----------------------------------------------------------------------------
# 6. Save
# -----------------------------------------------------------------------------

ggsave(
  filename = file.path(FIG_DIR, "fig_hit_volume_trends.png"),
  plot     = p,
  width    = 7,
  height   = 5,
  dpi      = 300,
  units    = "in"
)

message("\nFigure saved: fig_hit_volume_trends.png")
message(sprintf("  Path: %s", file.path(FIG_DIR, "fig_hit_volume_trends.png")))