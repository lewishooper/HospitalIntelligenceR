hit_master %>%
  filter(indicator_code == "ind03") %>%
  summarise(
    min    = min(value, na.rm = TRUE),
    median = median(value, na.rm = TRUE),
    mean   = mean(value, na.rm = TRUE),
    max    = max(value, na.rm = TRUE),
    n      = n()
  )# =============================================================================
# roles/hit/scripts/fig_hit_margin.R
# HospitalIntelligenceR — Mean Operating Margin by Hospital, 7-Year Average
# "Baseball graph" — sorted lollipop coloured by hospital type group
#
# Shows mean operating margin (ind03) across all available years per hospital.
# Acute hospitals only (Community Large, Community Small, Teaching).
# Sorted greatest (top) to least (bottom).
# Hospital names on y-axis (from strategy_master_analytical.csv).
# Colour encodes hospital type group using fixed project palette.
# Zero reference line and median reference line shown.
#
# ind03 = Operating Margin — stored as a ratio (e.g. 0.05 = 5%).
# Displayed as percentage on x-axis.
#
# Requires:
#   roles/hit/outputs/hit_master.csv
#   analysis/data/strategy_master_analytical.csv  (hospital name + type group)
#
# Follows figure_standards.md:
#   theme_linedraw() | sans font | Dark2 type colours | 7 x 12 in | 300 DPI
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
# Load hospital name and type group from strategy analytical CSV
# -----------------------------------------------------------------------------

hospital_lookup <- read_csv(
  STRATEGY,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
) %>%
  distinct(fac, hospital_name, hospital_type_group) %>%
  filter(hospital_type_group %in% acute_types)

message(sprintf("Acute hospital FACs in strategy data: %d", nrow(hospital_lookup)))
print(table(hospital_lookup$hospital_type_group))

# -----------------------------------------------------------------------------
# Load operating margin (ind03) from HIT master
# ind03 is a ratio — multiply by 100 for percentage display
# -----------------------------------------------------------------------------

hit_master <- read_csv(
  HIT_MASTER,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
)

margin_data <- hit_master %>%
  filter(indicator_code == "ind03") %>%
  select(fac, fiscal_year, value) %>%
  filter(fac %in% hospital_lookup$fac)

message(sprintf("Operating margin rows (acute FACs): %d", nrow(margin_data)))
message(sprintf("Fiscal years present: %s",
                paste(sort(unique(margin_data$fiscal_year)), collapse = ", ")))

# -----------------------------------------------------------------------------
# Compute mean margin per hospital across all available years
# Only include hospitals with at least 3 years of data
# -----------------------------------------------------------------------------

mean_margin <- margin_data %>%
  group_by(fac) %>%
  summarise(
    n_years     = n(),
    mean_margin = mean(value, na.rm = TRUE),
    .groups     = "drop"
  ) %>%
  filter(n_years >= 3) %>%
  left_join(hospital_lookup, by = "fac") %>%
  mutate(
    mean_margin_pct    = mean_margin * 100,
    hospital_type_group = factor(hospital_type_group, levels = acute_types)
  )

message(sprintf("Hospitals in figure (>= 3 years data): %d", nrow(mean_margin)))
message(sprintf("Hospitals excluded (< 3 years):         %d",
                n_distinct(margin_data$fac) - nrow(mean_margin)))

# -----------------------------------------------------------------------------
# Compute median across hospitals for reference line
# -----------------------------------------------------------------------------

median_margin <- median(mean_margin$mean_margin_pct, na.rm = TRUE)
message(sprintf("Median mean operating margin: %.2f%%", median_margin))

# -----------------------------------------------------------------------------
# Sort ascending so largest plots at top
# hospital_label is character — never numeric
# Use hospital_name; trim long names for legibility
# -----------------------------------------------------------------------------

mean_margin <- mean_margin %>%
  arrange(mean_margin_pct) %>%
  mutate(
    # Truncate very long names to keep y-axis readable
    hosp_label = if_else(
      nchar(hospital_name) > 40,
      paste0(str_sub(hospital_name, 1, 38), "…"),
      hospital_name
    ),
    hosp_label = factor(hosp_label, levels = hosp_label)
  )

# -----------------------------------------------------------------------------
# Base theme
# -----------------------------------------------------------------------------

base_theme <- theme_linedraw(base_size = 10, base_family = "sans") +
  theme(
    plot.title         = element_text(face = "bold", size = 12),
    plot.subtitle      = element_text(size = 9, colour = "grey40"),
    plot.caption       = element_text(size = 7.5, colour = "grey50", hjust = 0),
    legend.position    = "right",
    legend.title       = element_text(size = 9, face = "bold"),
    legend.text        = element_text(size = 8.5),
    legend.key.size    = unit(0.85, "lines"),
    axis.title         = element_text(size = 9),
    axis.text.x        = element_text(size = 8),
    axis.text.y        = element_text(size = 6.5),
    panel.grid.minor   = element_blank(),
    panel.grid.major.y = element_blank()
  )

# -----------------------------------------------------------------------------
# Baseball graph
# -----------------------------------------------------------------------------

p <- ggplot(mean_margin,
            aes(x = mean_margin_pct, y = hosp_label,
                colour = hospital_type_group)) +
  
  # Zero reference — breakeven line
  geom_vline(xintercept = 0, colour = "grey40",
             linewidth = 0.7, linetype = "solid") +
  
  # Median reference line
  geom_vline(xintercept = median_margin, colour = "grey20",
             linewidth = 0.85, linetype = "dashed") +
  
  # Median label anchored to top factor level
  annotate(
    "text",
    x        = median_margin,
    y        = as.character(mean_margin$hosp_label[nrow(mean_margin)]),
    label    = sprintf("Median: %.2f%%", median_margin),
    colour   = "grey20",
    size     = 2.8,
    hjust    = -0.1,
    vjust    = -0.9,
    fontface = "bold"
  ) +
  
  # Stems
  geom_segment(
    aes(x = 0, xend = mean_margin_pct,
        y = hosp_label, yend = hosp_label),
    linewidth = 0.45, alpha = 0.75
  ) +
  
  # Heads
  geom_point(size = 2.2, alpha = 0.9) +
  
  scale_colour_manual(
    values = type_colours,
    name   = "Hospital type",
    guide  = guide_legend(
      override.aes = list(size = 3.5, linewidth = 1.2),
      keywidth     = unit(1.2, "lines")
    )
  ) +
  
  scale_x_continuous(
    labels = label_percent(scale = 1, accuracy = 0.1, suffix = "%"),
    expand = expansion(mult = c(0.08, 0.20))
  ) +
  
  labs(
    title    = "Most acute Ontario hospitals operate near breakeven; outliers in both directions",
    subtitle = sprintf(
      "Mean operating margin per hospital across available fiscal years (up to 7 years). n = %d hospitals.",
      nrow(mean_margin)
    ),
    x       = "Mean operating margin (% of revenue)",
    y       = NULL,
    caption = paste0(
      "Source: Ontario Ministry of Health HIT global download | ",
      "Operating margin = ind03 (ratio, displayed as %). ",
      "Acute hospitals only (Community Large, Community Small, Teaching). ",
      "Hospitals with fewer than 3 years of data excluded."
    )
  ) +
  
  base_theme +
  # Give hospital names more room on the left
  theme(plot.margin = margin(5, 10, 5, 5))

# -----------------------------------------------------------------------------
# Save
# -----------------------------------------------------------------------------

ggsave(
  filename = file.path(FIG_DIR, "fig_hit_margin.png"),
  plot     = p,
  width    = 9,
  height   = 12,
  dpi      = 300,
  units    = "in"
)

message("Figure written: ", file.path(FIG_DIR, "fig_hit_margin.png"))