# =============================================================================
# roles/hit/scripts/fig_hit_rev_change.R
# HospitalIntelligenceR — Per-Hospital Revenue Change, First to Last Year
# "Baseball graph" — sorted lollipop coloured by hospital type group
#
# Shows % revenue change (last year vs first year) for acute hospitals only
# (Community Large, Community Small, Teaching). Specialty excluded.
# Sorted greatest (top) to least (bottom).
# Colour encodes hospital type group using fixed project palette.
# Median shown as labelled dashed vertical reference line.
# Closed and merged hospitals excluded by construction (both-endpoint rule).
#
# Requires:
#   roles/hit/outputs/hit_master.csv
#   analysis/data/strategy_master_analytical.csv  (for hospital_type_group)
#
# Follows figure_standards.md:
#   theme_linedraw() | sans font | Dark2 type colours | 7 x 12 in | 300 DPI
# =============================================================================

library(tidyverse)
library(scales)

HIT_MASTER  <- "roles/hit/outputs/hit_master.csv"
STRATEGY    <- "analysis/data/strategy_master_analytical.csv"
FIG_DIR     <- "roles/hit/outputs/figures"
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# Fixed type group colour palette (figure_standards.md)
# -----------------------------------------------------------------------------

type_colours <- c(
  "Community — Large" = "#1B9E77",   # Teal
  "Community — Small" = "#D95F02",   # Orange
  "Teaching"          = "#7570B3"    # Purple
  # Specialty excluded from this figure
)

acute_types <- names(type_colours)

# -----------------------------------------------------------------------------
# Load hospital type group from strategy analytical CSV
# One row per FAC — distinct to get the type lookup
# -----------------------------------------------------------------------------

type_lookup <- read_csv(
  STRATEGY,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
) %>%
  distinct(fac, hospital_type_group) %>%
  filter(hospital_type_group %in% acute_types)

message(sprintf("Acute hospital FACs in strategy data: %d", nrow(type_lookup)))
print(table(type_lookup$hospital_type_group))

# -----------------------------------------------------------------------------
# Load revenue indicator from HIT master
# -----------------------------------------------------------------------------

hit_master <- read_csv(
  HIT_MASTER,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
)

revenue <- hit_master %>%
  filter(indicator_code == "ind01") %>%
  select(fac, fiscal_year, value)

# -----------------------------------------------------------------------------
# Identify first and last fiscal year
# -----------------------------------------------------------------------------

all_years  <- sort(unique(revenue$fiscal_year))
first_year <- all_years[1]
last_year  <- all_years[length(all_years)]

message(sprintf("First year: %s | Last year: %s", first_year, last_year))

# -----------------------------------------------------------------------------
# Restrict to FACs present in BOTH endpoints
# -----------------------------------------------------------------------------

facs_first <- revenue %>% filter(fiscal_year == first_year) %>% pull(fac)
facs_last  <- revenue %>% filter(fiscal_year == last_year)  %>% pull(fac)
facs_both  <- intersect(facs_first, facs_last)
n_excluded_endpoints <- length(union(facs_first, facs_last)) - length(facs_both)

# Further restrict to acute types only
facs_acute <- intersect(facs_both, type_lookup$fac)
n_excluded_specialty <- length(facs_both) - length(facs_acute)

message(sprintf(
  "FACs in both endpoints: %d | Acute only: %d | Excluded (endpoints): %d | Excluded (non-acute): %d",
  length(facs_both), length(facs_acute),
  n_excluded_endpoints, n_excluded_specialty
))

# -----------------------------------------------------------------------------
# Compute % change
# -----------------------------------------------------------------------------

rev_first <- revenue %>%
  filter(fiscal_year == first_year, fac %in% facs_acute) %>%
  select(fac, rev_first = value)

rev_last <- revenue %>%
  filter(fiscal_year == last_year, fac %in% facs_acute) %>%
  select(fac, rev_last = value)

change_data <- left_join(rev_first, rev_last, by = "fac") %>%
  mutate(change_pct = 100 * (rev_last - rev_first) / rev_first) %>%
  left_join(type_lookup, by = "fac") %>%
  mutate(hospital_type_group = factor(hospital_type_group, levels = acute_types))

median_change <- median(change_data$change_pct, na.rm = TRUE)
message(sprintf("Median %% change (acute): %.1f%%", median_change))
message(sprintf("n hospitals in figure: %d", nrow(change_data)))

# Sort ascending so largest plots at top of y-axis
# fac_label is character — never interpreted as numeric by ggplot
change_data <- change_data %>%
  arrange(change_pct) %>%
  mutate(
    fac_label = factor(paste0("FAC ", fac), levels = paste0("FAC ", fac))
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
# Baseball graph — coloured by hospital type group
# -----------------------------------------------------------------------------

p <- ggplot(change_data,
            aes(x = change_pct, y = fac_label, colour = hospital_type_group)) +
  
  # Zero reference
  geom_vline(xintercept = 0, colour = "grey60",
             linewidth = 0.5, linetype = "dotted") +
  
  # Median reference line
  geom_vline(xintercept = median_change, colour = "grey20",
             linewidth = 0.85, linetype = "dashed") +
  
  # Median label anchored to top factor level
  annotate(
    "text",
    x        = median_change,
    y        = as.character(change_data$fac_label[nrow(change_data)]),
    label    = sprintf("Median: %.1f%%", median_change),
    colour   = "grey20",
    size     = 2.8,
    hjust    = -0.1,
    vjust    = -0.9,
    fontface = "bold"
  ) +
  
  # Stems
  geom_segment(
    aes(x = 0, xend = change_pct, y = fac_label, yend = fac_label),
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
    labels = label_percent(scale = 1, accuracy = 1, suffix = "%"),
    expand = expansion(mult = c(0.05, 0.18))
  ) +
  
  labs(
    title    = sprintf(
      "Revenue growth varied widely across acute Ontario hospitals, %s to %s",
      first_year, last_year
    ),
    subtitle = sprintf(
      "Percentage change in total revenue per hospital. Sorted greatest to least. n = %d acute hospitals.",
      nrow(change_data)
    ),
    x       = sprintf("Revenue change (%s to %s)", first_year, last_year),
    y       = "FAC",
    caption = paste0(
      "Source: Ontario Ministry of Health HIT global download | ",
      "Acute hospitals only (Community Large, Community Small, Teaching). ",
      "Closed and merged hospitals not included — only FACs present in both ",
      first_year, " and ", last_year, " are shown."
    )
  ) +
  
  base_theme

# -----------------------------------------------------------------------------
# Save — slightly shorter than all-hospital version (fewer rows)
# -----------------------------------------------------------------------------

ggsave(
  filename = file.path(FIG_DIR, "fig_hit_rev_change.png"),
  plot     = p,
  width    = 7,
  height   = 12,
  dpi      = 300,
  units    = "in"
)

message("Figure written: ", file.path(FIG_DIR, "fig_hit_rev_change.png"))
