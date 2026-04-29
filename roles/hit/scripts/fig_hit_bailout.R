# =============================================================================
# roles/hit/scripts/fig_hit_bailout.R
# HospitalIntelligenceR — Sector-Wide Revenue vs Expense Growth by Year
#
# For each year-over-year transition, shows the total sector increase in
# revenue and expenses in absolute dollars ($M). A "bailout" year shows as
# a large revenue bar relative to the expense bar.
#
# Acute hospitals only. Only FACs present in both the current and prior year
# are included in each transition (apples-to-apples comparison).
#
# Follows figure_standards.md:
#   theme_linedraw() | sans font | Dark2 colours | 8 x 5 in | 300 DPI
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
# Only include FACs present in BOTH the current and prior year per transition
# so the sector total is always comparing the same set of hospitals
# -----------------------------------------------------------------------------

yoy <- rev_exp %>%
  group_by(fac) %>%
  arrange(fiscal_year, .by_group = TRUE) %>%
  mutate(
    rev_prior   = lag(revenue),
    exp_prior   = lag(expense),
    year_from   = lag(fiscal_year),
    rev_change  = revenue - rev_prior,
    exp_change  = expense - exp_prior,
    transition  = paste0(str_sub(year_from, 1, 4), "/",
                         str_sub(year_from, 6, 7), "-->",
                         str_sub(fiscal_year, 1, 4), "/",
                         str_sub(fiscal_year, 6, 7))
    
    
  ) %>%
  filter(!is.na(rev_prior)) %>%
  ungroup()

# -----------------------------------------------------------------------------
# Sum across all acute hospitals per transition — convert to $M
# -----------------------------------------------------------------------------

sector_change <- yoy %>%
  group_by(transition) %>%
  summarise(
    n_hospitals      = n_distinct(fac),
    total_rev_change = sum(rev_change, na.rm = TRUE) / 1e6,
    total_exp_change = sum(exp_change, na.rm = TRUE) / 1e6,
    .groups          = "drop"
  ) %>%
  mutate(transition = factor(transition, levels = sort(unique(transition))))

message("Sector-wide changes by transition ($M):")
print(sector_change)

# Pivot long for grouped bar
plot_data <- sector_change %>%
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

# Colours: teal for revenue, orange for expense — Dark2 palette
bar_colours <- c(
  "Revenue increase" = "#1B9E77",
  "Expense increase" = "#D95F02"
)

# -----------------------------------------------------------------------------
# Base theme
# -----------------------------------------------------------------------------

base_theme <- theme_linedraw(base_size = 11, base_family = "sans") +
  theme(
    plot.title       = element_text(face = "bold", size = 12),
    plot.subtitle    = element_text(size = 9, colour = "grey40"),
    plot.caption     = element_text(size = 7.5, colour = "grey50", hjust = 0),
    legend.position  = "top",
    legend.title     = element_blank(),
    legend.text      = element_text(size = 9),
    axis.title       = element_text(size = 9),
    axis.text        = element_text(size = 9),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank()
  )

# -----------------------------------------------------------------------------
# Grouped bar chart
# -----------------------------------------------------------------------------

p <- ggplot(plot_data,
            aes(x = transition, y = change_m, fill = series)) +
  
  geom_col(position = position_dodge(width = 0.7), width = 0.6, alpha = 0.9) +
  
  # Zero line
  geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.5) +
  
  # Value labels on bars
  geom_text(
    aes(label = sprintf("$%.0fM", change_m),
        vjust = if_else(change_m >= 0, -0.4, 1.3)),
    position = position_dodge(width = 0.7),
    size     = 2.8,
    colour   = "grey20"
  ) +
  
  scale_fill_manual(values = bar_colours) +
  
  scale_y_continuous(
    labels = label_dollar(suffix = "M", accuracy = 1),
    expand = expansion(mult = c(0.08, 0.12))
  ) +
  
  labs(
    title    = "2020→2021 shows a clear revenue injection; expense growth has outpaced revenue since",
    subtitle = "Total year-over-year change in sector revenue and expenses ($M). Acute hospitals only.",
    x        = NULL,
    y        = "Change from prior year ($M)",
    caption  = paste0(
      "Source: Ontario Ministry of Health HIT global download | ",
      "Acute hospitals only (Community Large, Community Small, Teaching). ",
      "Each transition includes only FACs present in both years."
    )
  ) +
  
  base_theme

# -----------------------------------------------------------------------------
# Save
# -----------------------------------------------------------------------------

ggsave(
  filename = file.path(FIG_DIR, "fig_hit_bailout.png"),
  plot     = p,
  width    = 8,
  height   = 5,
  dpi      = 300,
  units    = "in"
)

message("Figure written: ", file.path(FIG_DIR, "fig_hit_bailout.png"))