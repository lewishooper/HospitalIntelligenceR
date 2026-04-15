# =============================================================================
# roles/hit/scripts/fig_hit_rev_change.R
# HospitalIntelligenceR — Per-Hospital Revenue Change, First to Last Year
# "Baseball graph" — sorted lollipop with above/below median colouring
#
# Shows % revenue change (last year vs first year) for each hospital present
# in BOTH the first and last available fiscal year.
# Sorted greatest (top) to least (bottom).
# Green = above median | Red = below median
# Median shown as labelled vertical reference line.
# Closed and merged hospitals excluded by construction.
#
# Follows figure_standards.md:
#   theme_linedraw() | sans font | 7 x 14 in tall | 300 DPI
# =============================================================================

library(tidyverse)
library(scales)

HIT_MASTER <- "roles/hit/outputs/hit_master.csv"
FIG_DIR    <- "roles/hit/outputs/figures"
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# Load revenue indicator
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
n_excluded <- length(union(facs_first, facs_last)) - length(facs_both)

message(sprintf(
  "FACs in %s: %d | FACs in %s: %d | In both: %d | Excluded: %d",
  first_year, length(facs_first),
  last_year,  length(facs_last),
  length(facs_both), n_excluded
))

# -----------------------------------------------------------------------------
# Compute % change: (last - first) / first x 100
# -----------------------------------------------------------------------------

rev_first <- revenue %>%
  filter(fiscal_year == first_year, fac %in% facs_both) %>%
  select(fac, rev_first = value)

rev_last <- revenue %>%
  filter(fiscal_year == last_year, fac %in% facs_both) %>%
  select(fac, rev_last = value)

change_data <- left_join(rev_first, rev_last, by = "fac") %>%
  mutate(change_pct = 100 * (rev_last - rev_first) / rev_first)

median_change <- median(change_data$change_pct, na.rm = TRUE)
message(sprintf("Median %% change: %.1f%%", median_change))

# Sort largest on top.
# fac_label is a character string ("FAC 592") — never interpreted as numeric.
# Factor levels set in ascending order so the largest plots at the top of y-axis.
change_data <- change_data %>%
  arrange(change_pct) %>%            # ascending so rev() puts largest on top
  mutate(
    above_median = change_pct >= median_change,
    colour_group = if_else(above_median, "Above median", "Below median"),
    fac_label    = factor(paste0("FAC ", fac), levels = paste0("FAC ", fac))
  )

n_above <- sum(change_data$above_median)
n_below <- nrow(change_data) - n_above
message(sprintf("Above median: %d | Below median: %d", n_above, n_below))

# -----------------------------------------------------------------------------
# Base theme
# -----------------------------------------------------------------------------

base_theme <- theme_linedraw(base_size = 10, base_family = "sans") +
  theme(
    plot.title         = element_text(face = "bold", size = 12),
    plot.subtitle      = element_text(size = 9, colour = "grey40"),
    plot.caption       = element_text(size = 7.5, colour = "grey50", hjust = 0),
    legend.position    = "top",
    legend.title       = element_blank(),
    legend.text        = element_text(size = 9),
    axis.title         = element_text(size = 9),
    axis.text.x        = element_text(size = 8),
    axis.text.y        = element_text(size = 6.5),
    panel.grid.minor   = element_blank(),
    panel.grid.major.y = element_blank()
  )

lollipop_colours <- c(
  "Above median" = "#1B9E77",
  "Below median" = "#CC3300"
)

# -----------------------------------------------------------------------------
# Baseball graph
# -----------------------------------------------------------------------------

p <- ggplot(change_data,
            aes(x = change_pct, y = fac_label, colour = colour_group)) +

  # Zero reference
  geom_vline(xintercept = 0, colour = "grey60",
             linewidth = 0.5, linetype = "dotted") +

  # Median reference line
  geom_vline(xintercept = median_change, colour = "grey20",
             linewidth = 0.85, linetype = "dashed") +

  # Median label at top of chart
  annotate(
    "text",
    x        = median_change,
    y        = as.character(change_data$fac_label[nrow(change_data)]),
    label    = sprintf("Median: %.1f%%", median_change),
    colour   = "grey20",
    size     = 2.8,
    hjust    = -0.1,
    vjust    = -0.8,
    fontface = "bold"
  ) +

  # Stems
  geom_segment(
    aes(x = 0, xend = change_pct, y = fac_label, yend = fac_label),
    linewidth = 0.45, alpha = 0.75
  ) +

  # Heads
  geom_point(size = 1.8, alpha = 0.9) +

  scale_colour_manual(values = lollipop_colours) +

  scale_x_continuous(
    labels = label_percent(scale = 1, accuracy = 1, suffix = "%"),
    expand = expansion(mult = c(0.05, 0.18))
  ) +

  labs(
    title    = sprintf(
      "Revenue growth varied widely across Ontario hospitals, %s to %s",
      first_year, last_year
    ),
    subtitle = sprintf(
      "Percentage change in total revenue per hospital. Sorted greatest to least. n = %d hospitals.",
      nrow(change_data)
    ),
    x       = sprintf("Revenue change (%s to %s)", first_year, last_year),
    y       = "FAC",
    caption = paste0(
      "Source: Ontario Ministry of Health HIT global download | ",
      "Closed and merged hospitals not included — only FACs present in both ",
      first_year, " and ", last_year, " are shown. ",
      n_excluded, " FAC(s) excluded."
    )
  ) +

  base_theme

# -----------------------------------------------------------------------------
# Save
# -----------------------------------------------------------------------------

ggsave(
  filename = file.path(FIG_DIR, "fig_hit_rev_change.png"),
  plot     = p,
  width    = 7,
  height   = 14,
  dpi      = 300,
  units    = "in"
)

message("Figure written: ", file.path(FIG_DIR, "fig_hit_rev_change.png"))
