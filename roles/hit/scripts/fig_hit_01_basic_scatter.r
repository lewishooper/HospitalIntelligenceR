# =============================================================================
# roles/hit/scripts/fig_hit_01_basic_scatter.R
# HospitalIntelligenceR — Revenue x Expense Trajectory Scatter
#
# Points coloured by quartile of acute patient day volume change (ind45),
# first to last available fiscal year. Red = bottom quartile (volume fell
# most), yellow = middle two quartiles, green = top quartile (volume grew
# most). Grey = no patient day data.
#
# Axes zoomed to dense cluster — hospitals outside range clipped.
# Acute hospitals only. Four structural outliers excluded.
#
# Inputs:
#   roles/hit/outputs/hit_01_field_trajectories.csv
#   roles/hit/outputs/hit_master.csv
#
# Outputs:
#   roles/hit/outputs/figures/publication/fig_hit_01_basic_scatter.png
# =============================================================================

library(ggplot2)
library(dplyr)
library(readr)
library(scales)

# -----------------------------------------------------------------------------
# 0. Paths and constants
# -----------------------------------------------------------------------------

TRAJECTORIES <- "roles/hit/outputs/hit_01_field_trajectories.csv"
MASTER_PATH  <- "roles/hit/outputs/hit_master.csv"
FIG_DIR      <- "roles/hit/outputs/figures/publication"
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

OUTLIER_FACS <- c("854", "971", "701", "938")
ACUTE_TYPES  <- c("Teaching", "Community \u2014 Large", "Community \u2014 Small")

X_MIN <- -20
X_MAX <-  30
Y_MIN <- -20
Y_MAX <-  30

# -----------------------------------------------------------------------------
# 1. Load trajectory scores — acute hospitals, outliers removed
# -----------------------------------------------------------------------------

traj <- read_csv(
  TRAJECTORIES,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
) %>%
  filter(
    hospital_type_group %in% ACUTE_TYPES,
    !fac %in% OUTLIER_FACS
  )

message(sprintf("Acute hospitals after outlier exclusion: %d", nrow(traj)))

# -----------------------------------------------------------------------------
# 2. Compute patient day volume change from hit_master
#    ind45 = AcutePtDays
#    Raw % change: (last - first) / abs(first) * 100
# -----------------------------------------------------------------------------

hit_master <- read_csv(
  MASTER_PATH,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
)

ptdays_change <- hit_master %>%
  filter(
    fac %in% traj$fac,
    indicator_code == "ind45"
  ) %>%
  group_by(fac) %>%
  summarise(
    value_first = value[fiscal_year == min(fiscal_year)][1],
    value_last  = value[fiscal_year == max(fiscal_year)][1],
    .groups = "drop"
  ) %>%
  mutate(
    ptdays_change_pct = if_else(
      !is.na(value_first) & value_first > 0,
      (value_last - value_first) / abs(value_first) * 100,
      NA_real_
    )
  ) %>%
  select(fac, ptdays_change_pct)

message(sprintf("FACs with patient day data:    %d", sum(!is.na(ptdays_change$ptdays_change_pct))))
message(sprintf("FACs without patient day data: %d", sum( is.na(ptdays_change$ptdays_change_pct))))

# -----------------------------------------------------------------------------
# 3. Join and assign quartile colour groups
# -----------------------------------------------------------------------------

traj_plot <- traj %>%
  left_join(ptdays_change, by = "fac") %>%
  mutate(
    ptdays_quartile = case_when(
      is.na(ptdays_change_pct)                                                  ~ "No data",
      ptdays_change_pct <= quantile(ptdays_change_pct, 0.25, na.rm = TRUE)      ~ "Q1 \u2014 Volume fell most",
      ptdays_change_pct <= quantile(ptdays_change_pct, 0.75, na.rm = TRUE)      ~ "Q2/Q3 \u2014 Middle",
      TRUE                                                                       ~ "Q4 \u2014 Volume grew most"
    ),
    ptdays_quartile = factor(ptdays_quartile, levels = c(
      "Q1 \u2014 Volume fell most",
      "Q2/Q3 \u2014 Middle",
      "Q4 \u2014 Volume grew most",
      "No data"
    ))
  )

message("\nPatient day quartile distribution:")
print(table(traj_plot$ptdays_quartile, useNA = "ifany"))
message("\nPatient day change summary (non-NA):")
print(summary(traj_plot$ptdays_change_pct))

n_clipped <- sum(
  traj_plot$cum_adj_rev > X_MAX | traj_plot$cum_adj_rev < X_MIN |
    traj_plot$cum_adj_exp > Y_MAX | traj_plot$cum_adj_exp < Y_MIN,
  na.rm = TRUE
)
message(sprintf("Hospitals outside plot range (clipped): %d", n_clipped))

# -----------------------------------------------------------------------------
# 4. Colour palette
# -----------------------------------------------------------------------------

quartile_colours <- c(
  "Q1 \u2014 Volume fell most"  = "#CC3300",
  "Q2/Q3 \u2014 Middle"         = "#E6AB02",
  "Q4 \u2014 Volume grew most"  = "#1B9E77",
  "No data"                     = "#AAAAAA"
)

# -----------------------------------------------------------------------------
# 5. Base theme
# -----------------------------------------------------------------------------

base_theme <- theme_linedraw(base_size = 11, base_family = "sans") +
  theme(
    plot.title       = element_text(face = "bold", size = 13),
    plot.subtitle    = element_text(size = 10, colour = "grey40"),
    plot.caption     = element_text(size = 8, colour = "grey50", hjust = 0),
    axis.title       = element_text(size = 10),
    axis.text        = element_text(size = 9),
    panel.grid.minor = element_blank(),
    legend.position  = "none"
  )

# -----------------------------------------------------------------------------
# 6. Plot
# -----------------------------------------------------------------------------

p <- ggplot(traj_plot,
            aes(x = cum_adj_rev, y = cum_adj_exp, colour = ptdays_quartile)) +
  
  # Zero reference lines
  geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.4) +
  geom_vline(xintercept = 0, colour = "grey30", linewidth = 0.4) +
  
  # Grey no-data points first so coloured points render on top
  geom_point(data = function(d) filter(d, ptdays_quartile == "No data"),
             size = 2.2, alpha = 0.50) +
  geom_point(data = function(d) filter(d, ptdays_quartile != "No data"),
             size = 2.2, alpha = 0.75) +
  
  scale_colour_manual(values = quartile_colours) +
  
  scale_x_continuous(
    name   = "Cumulative field-adjusted revenue (pp)",
    labels = label_number(suffix = "pp", accuracy = 1),
    limits = c(X_MIN, X_MAX)
  ) +
  scale_y_continuous(
    name   = "Cumulative field-adjusted expenses (pp)",
    labels = label_number(suffix = "pp", accuracy = 1),
    limits = c(Y_MIN, Y_MAX)
  ) +
  
  labs(
    title    = "How Ontario acute hospitals managed revenue and expenses,\n2018/19\u20132024/25",
    subtitle = "Colour shows quartile of acute patient day volume change, first to last year\nGreen = grew most  |  Yellow = middle  |  Red = fell most  |  Grey = no data",
    caption  = sprintf(
      "Source: HospitalIntelligenceR HIT import | n = %d acute hospitals | Excludes FAC 854, 971, 701, 938\nAxes clipped to \u221220pp\u2013+30pp; %d hospitals outside plot range not shown",
      nrow(traj_plot),
      n_clipped
    )
  ) +
  
  base_theme

# -----------------------------------------------------------------------------
# 7. Save
# -----------------------------------------------------------------------------

ggsave(
  filename = file.path(FIG_DIR, "fig_hit_01_basic_scatter.png"),
  plot     = p,
  width    = 7,
  height   = 5.5,
  dpi      = 300,
  units    = "in"
)

message("\nfig_hit_01_basic_scatter.png written to: ", FIG_DIR)