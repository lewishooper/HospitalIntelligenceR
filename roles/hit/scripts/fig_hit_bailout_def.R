# =============================================================================
# roles/hit/scripts/fig_hit_bailout.R
# HospitalIntelligenceR — Sector-Wide Revenue vs Expense Growth + Deficit Line
#
# Grouped bars: total YoY change in sector revenue and expenses ($M)
# Overlaid line: sector operating position (total revenue - total expense)
#   at the CLOSING year of each transition — the financial position after
#   that year's flows have occurred.
#
# Acute hospitals only. Dual y-axis: bars on left (change $M), line on right
# (absolute position $M).
#
# Follows figure_standards.md:
#   theme_linedraw() | sans font | Dark2 colours | 9 x 5.5 in | 300 DPI
# =============================================================================

library(tidyverse)
library(scales)

HIT_MASTER <- "roles/hit/outputs/hit_master.csv"
STRATEGY   <- "analysis/data/strategy_master_analytical.csv"
FIG_DIR    <- "roles/hit/outputs/figures"
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

acute_types <- c("Community — Large", "Community — Small", "Teaching")

# -----------------------------------------------------------------------------
# Hospital type lookup — acute only
# -----------------------------------------------------------------------------

hospital_lookup <- read_csv(
  STRATEGY,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
) %>%
  distinct(fac, hospital_type_group) %>%
  filter(hospital_type_group %in% acute_types)

# -----------------------------------------------------------------------------
# Load revenue (ind01) and expense (ind02) for acute hospitals
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
# Year-over-year change per hospital
# -----------------------------------------------------------------------------

yoy <- rev_exp %>%
  group_by(fac) %>%
  arrange(fiscal_year, .by_group = TRUE) %>%
  mutate(
    rev_prior      = lag(revenue),
    exp_prior      = lag(expense),
    year_from      = lag(fiscal_year),
    rev_change     = revenue - rev_prior,
    exp_change     = expense - exp_prior,
    margin_closing = revenue - expense,   # closing-year position
    transition     = paste0(str_sub(year_from,   1, 4), "/",
                            str_sub(year_from,   8, 9), "-->",
                            str_sub(fiscal_year, 1, 4), "/",
                            str_sub(fiscal_year, 8, 9))
  ) %>%
  filter(!is.na(rev_prior)) %>%
  ungroup()

# -----------------------------------------------------------------------------
# Sector totals per transition — bars (changes) and line (closing position)
# -----------------------------------------------------------------------------

sector_change <- yoy %>%
  group_by(transition) %>%
  summarise(
    n_hospitals         = n_distinct(fac),
    total_rev_change    = sum(rev_change,     na.rm = TRUE) / 1e6,
    total_exp_change    = sum(exp_change,     na.rm = TRUE) / 1e6,
    total_margin_close  = sum(margin_closing, na.rm = TRUE) / 1e6,
    .groups             = "drop"
  ) %>%
  mutate(transition = factor(transition, levels = sort(unique(transition))))

message("Sector-wide changes by transition ($M):")
print(sector_change)

# -----------------------------------------------------------------------------
# Dual y-axis scaling
# The line (absolute margin, potentially large) is scaled to fit the bar axis.
# scale_factor converts margin $M to bar-axis $M for plotting;
# the secondary axis reverses that transform for labelling.
# -----------------------------------------------------------------------------

bar_range    <- range(c(sector_change$total_rev_change,
                        sector_change$total_exp_change), na.rm = TRUE)
line_range   <- range(sector_change$total_margin_close, na.rm = TRUE)

# Map line values into bar axis space
scale_factor <- diff(bar_range) / diff(line_range)
line_offset  <- bar_range[1] - line_range[1] * scale_factor

sector_change <- sector_change %>%
  mutate(margin_scaled = total_margin_close * scale_factor + line_offset)

# Pivot bars long
plot_data <- sector_change %>%
  select(transition, total_rev_change, total_exp_change) %>%
  pivot_longer(
    cols      = c(total_rev_change, total_exp_change),
    names_to  = "series",
    values_to = "change_m"
  ) %>%
  mutate(
    series = recode(series,
                    "total_rev_change" = "Revenue increase",
                    "total_exp_change" = "Expense increase"
    ),
    series = factor(series, levels = c("Revenue increase", "Expense increase"))
  )

bar_colours <- c(
  "Revenue increase" = "#1B9E77",
  "Expense increase" = "#D95F02"
)
line_colour <- "#7570B3"   # Purple — Dark2, distinct from bars

# -----------------------------------------------------------------------------
# Base theme
# -----------------------------------------------------------------------------

base_theme <- theme_linedraw(base_size = 11, base_family = "sans") +
  theme(
    plot.title         = element_text(face = "bold", size = 12),
    plot.subtitle      = element_text(size = 9, colour = "grey40"),
    plot.caption       = element_text(size = 7.5, colour = "grey50", hjust = 0),
    legend.position    = "top",
    legend.title       = element_blank(),
    legend.text        = element_text(size = 9),
    axis.title.y.left  = element_text(size = 9),
    axis.title.y.right = element_text(size = 9, colour = line_colour),
    axis.text.y.right  = element_text(size = 8, colour = line_colour),
    axis.text          = element_text(size = 9),
    panel.grid.minor   = element_blank(),
    panel.grid.major.x = element_blank()
  )

# -----------------------------------------------------------------------------
# Plot
# -----------------------------------------------------------------------------

p <- ggplot() +
  
  # Bars — YoY change
  geom_col(data = plot_data,
           aes(x = transition, y = change_m, fill = series),
           position = position_dodge(width = 0.7), width = 0.6, alpha = 0.9) +
  
  # Zero line
  geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.5) +
  
  # Bar value labels
  geom_text(data = plot_data,
            aes(x = transition, y = change_m,
                label = sprintf("$%.0fM", change_m),
                vjust = if_else(change_m >= 0, -0.4, 1.3),
                group = series),
            position = position_dodge(width = 0.7),
            size = 2.6, colour = "grey20") +
  
  # Deficit/surplus line — closing year position (scaled to left axis)
  geom_line(data = sector_change,
            aes(x = transition, y = margin_scaled, group = 1),
            colour = line_colour, linewidth = 1.1) +
  
  geom_point(data = sector_change,
             aes(x = transition, y = margin_scaled),
             colour = line_colour, size = 3) +
  
  # Line value labels
  geom_text(data = sector_change,
            aes(x = transition, y = margin_scaled,
                label = sprintf("$%.0fM", total_margin_close)),
            colour = line_colour, size = 2.6,
            vjust = -1.0, fontface = "bold") +
  
  # Text box — describes the purple operating position line
  annotate(
    "label",
    x      = 1.5,
    y      = Inf,
    label  = "Purple line: Sector operating position\n(total revenue minus total expenses\nat closing year, right axis)",
    colour      = line_colour,
    fill        = "white",
    label.size  = 0.3,
    size        = 2.6,
    hjust       = 0,
    vjust       = 1.2,
    fontface    = "italic"
  ) +
  
  # Scales
  scale_fill_manual(
    values = bar_colours,
    guide  = guide_legend(order = 1)
  ) +
  
  scale_y_continuous(
    name   = "Change from prior year ($M)",
    labels = label_dollar(suffix = "M", accuracy = 1),
    expand = expansion(mult = c(0.10, 0.15)),
    sec.axis = sec_axis(
      transform = ~ (. - line_offset) / scale_factor,
      name      = "Sector operating position ($M)",
      labels    = label_dollar(suffix = "M", accuracy = 1)
    )
  ) +
  
  # Add purple line to legend manually
  scale_colour_manual(
    values = c("Sector operating position" = line_colour),
    guide  = guide_legend(order = 2,
                          override.aes = list(linewidth = 1.1, shape = 19))
  ) +
  
  labs(
    title    = "COVID-era revenue injection visible in 2019/20→2020/21; sector operating position remains fragile",
    subtitle = "Bars: total YoY change in sector revenue and expenses. Line: sector operating position at year-end. Acute hospitals only.",
    x        = NULL,
    caption  = paste0(
      "Source: Ontario Ministry of Health HIT global download | ",
      "Acute hospitals only (Community Large, Community Small, Teaching). ",
      "\nOperating position = total revenue minus total expenses at closing year."
    )
  ) +
  
  base_theme

# -----------------------------------------------------------------------------
# Save
# -----------------------------------------------------------------------------

ggsave(
  filename = file.path(FIG_DIR, "fig_hit_bailoutDef.png"),
  plot     = p,
  width    = 9,
  height   = 5.5,
  dpi      = 300,
  units    = "in"
)

message("Figure written: ", file.path(FIG_DIR, "fig_hit_bailoutDef.png"))