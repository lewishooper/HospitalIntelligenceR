# =============================================================================
# roles/hit/scripts/fig_hit_01_scatter.R
# HospitalIntelligenceR — HIT Quadrant Scatter Plot + Outlier Table
#
# Plots each hospital as a point in the revenue x expense trajectory space.
# Four hospitals with extreme scores are excluded from the plot and reported
# in a companion flextable (tbl_hit_01_outliers.png).
#
# Excluded FACs (hardcoded — review if registry changes):
#   854  SA Grace Toronto          — COVID-era transitional care expansion
#   971  Sudbury St. Joseph's CC   — COVID-era transitional care expansion
#   701  [Large construction]      — Capital project onboarding
#   938  [Small amalgamation]      — MOHLTC review / amalgamation
#
# Inputs:
#   roles/hit/outputs/hit_01_field_trajectories.csv
#
# Outputs:
#   roles/hit/outputs/figures/fig_hit_01_scatter.png
#   roles/hit/outputs/figures/tbl_hit_01_outliers.png
#
# Run after: hit_01_field_segmentation.R
# =============================================================================

library(ggplot2)
library(dplyr)
library(readr)
library(scales)
library(flextable)

# -----------------------------------------------------------------------------
# 0. Paths
# -----------------------------------------------------------------------------

TRAJECTORIES <- "roles/hit/outputs/hit_01_field_trajectories.csv"
FIG_DIR      <- "roles/hit/outputs/figures"
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Load data
# -----------------------------------------------------------------------------

traj <- read_csv(
  TRAJECTORIES,
  col_types = cols(fac = col_character(), .default = col_guess())
)

message(sprintf("Loaded %d hospitals", nrow(traj)))

# -----------------------------------------------------------------------------
# 2. Hardcoded exclusions
# -----------------------------------------------------------------------------

EXCLUDE_FACS <- c("854", "971", "701", "938")

excluded <- traj %>%
  filter(fac %in% EXCLUDE_FACS) %>%
  arrange(desc(cum_adj_rev - cum_adj_exp))

traj_plot <- traj %>%
  filter(!fac %in% EXCLUDE_FACS)

message(sprintf("\nExcluded: %d hospitals | Plotting: %d hospitals",
                nrow(excluded), nrow(traj_plot)))

message("\n--- Excluded hospital scores ---")
print(excluded %>%
        select(fac, hospital_name, hospital_type_group, quadrant,
               cum_adj_rev, cum_adj_exp),
      width = Inf)

# -----------------------------------------------------------------------------
# 3. Quadrant colour palette and relabelling
#
# Legend labels:
#   Revenue-led  --> Revenue gains
#   Expense-led  --> Expense cuts
#   Cost pressure, Both, Neither unchanged
#   Structural outlier excluded from plot via drop = TRUE
# -----------------------------------------------------------------------------

quadrant_colours <- c(
  "Revenue gains"      = "#2166AC",
  "Expense cuts"       = "#D9A520",
  "Both"               = "#1A9850",
  "Neither"            = "#878787",
  "Cost pressure"      = "#D73027",
  "Structural outlier" = "#9970AB"   # retained for recode completeness; dropped by drop = TRUE
)

quadrant_order <- c(
  "Revenue gains", "Neither", "Expense cuts",
  "Cost pressure", "Both", "Structural outlier"
)

# Recode labels in plot data
traj_plot <- traj_plot %>%
  mutate(
    quadrant = recode(quadrant,
                      "Revenue-led"  = "Revenue gains",
                      "Expense-led"  = "Expense cuts"
    ),
    quadrant = factor(quadrant, levels = quadrant_order)
  )

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
    legend.text      = element_text(size = 8),
    axis.title       = element_text(size = 10),
    axis.text        = element_text(size = 9),
    panel.grid.minor = element_blank()
  )

# -----------------------------------------------------------------------------
# 5. Scatter plot
# -----------------------------------------------------------------------------

THRESH  <- 5
n_plot  <- nrow(traj_plot)
n_total <- nrow(traj)

p <- ggplot(traj_plot, aes(x = cum_adj_rev, y = cum_adj_exp, colour = quadrant)) +
  
  # --- Quadrant shading ---
  annotate("rect", xmin = THRESH, xmax = Inf,   ymin = -Inf,   ymax = -THRESH,
           fill = "#2166AC", alpha = 0.04) +
  annotate("rect", xmin = -Inf,   xmax = THRESH, ymin = -Inf,   ymax = -THRESH,
           fill = "#D9A520", alpha = 0.04) +
  annotate("rect", xmin = THRESH, xmax = Inf,   ymin = -THRESH, ymax = Inf,
           fill = "#1A9850", alpha = 0.05) +
  annotate("rect", xmin = -Inf,   xmax = THRESH, ymin = THRESH, ymax = Inf,
           fill = "#D73027", alpha = 0.04) +
  
  # --- Reference lines ---
  geom_hline(yintercept = 0,       colour = "grey30", linewidth = 0.4) +
  geom_vline(xintercept = 0,       colour = "grey30", linewidth = 0.4) +
  geom_hline(yintercept =  THRESH, colour = "grey50", linewidth = 0.3, linetype = "dashed") +
  geom_hline(yintercept = -THRESH, colour = "grey50", linewidth = 0.3, linetype = "dashed") +
  geom_vline(xintercept =  THRESH, colour = "grey50", linewidth = 0.3, linetype = "dashed") +
  geom_vline(xintercept = -THRESH, colour = "grey50", linewidth = 0.3, linetype = "dashed") +
  
  # --- Hospital dots ---
  geom_point(size = 2, alpha = 0.65, shape = 16) +
  
  # --- Threshold labels ---
  annotate("text", x =  THRESH, y = max(traj_plot$cum_adj_exp, na.rm = TRUE) * 0.95,
           label = "+5%", size = 2.8, colour = "grey55", hjust = -0.2) +
  annotate("text", x = -THRESH, y = max(traj_plot$cum_adj_exp, na.rm = TRUE) * 0.95,
           label = "\u22125%", size = 2.8, colour = "grey55", hjust =  1.2) +
  annotate("text", x = max(traj_plot$cum_adj_rev, na.rm = TRUE) * 0.95, y =  THRESH,
           label = "+5%", size = 2.8, colour = "grey55", vjust = -0.4) +
  annotate("text", x = max(traj_plot$cum_adj_rev, na.rm = TRUE) * 0.95, y = -THRESH,
           label = "\u22125%", size = 2.8, colour = "grey55", vjust =  1.4) +
  
  # --- Scales ---
  scale_colour_manual(
    values = quadrant_colours,
    name   = "Quadrant",
    drop   = TRUE                     # removes Structural outlier from legend
  ) +
  scale_x_continuous(
    name   = "Cumulative field-adjusted revenue (%)",
    labels = label_percent(scale = 1, accuracy = 1)
  ) +
  scale_y_reverse(
    name   = "Cumulative field-adjusted expenses (%)\n\u2190 Above field  |  Below field \u2192",
    labels = label_percent(scale = 1, accuracy = 1)
  ) +
  
  # --- Text elements (Skip's wording) ---
  labs(
    title    = "How Ontario hospitals dealt with financial pressures,\n 2018/19\u20132024/25",
    subtitle = "Each point is one hospital; axes show cumulative deviation from the sector\nmedian, 2018/19\u20132024/25",
    caption  = sprintf(
      "Source: HospitalIntelligenceR | n = %d hospitals (of %d total) | \nExcluded outliers shown separately | Dashed lines = \u00b15%% thresholds",
      n_plot, n_total
    )
  ) +
  
  base_theme

ggsave(
  filename = file.path(FIG_DIR, "fig_hit_01_scatter.png"),
  plot     = p,
  width    = 7,
  height   = 5.5,
  dpi      = 300,
  units    = "in"
)

message("fig_hit_01_scatter.png written")

# -----------------------------------------------------------------------------
# 6. Companion flextable — excluded hospitals
#
# Changes from prior version:
#   - FAC column dropped; hospital name only
#   - Footer colour: white (was grey50)
#   - Row height increased to prevent wrapped text collision
# -----------------------------------------------------------------------------

tbl_data <- excluded %>%
  select(hospital_name, hospital_type_group, cum_adj_rev, cum_adj_exp) %>%
  mutate(
    cum_adj_rev = sprintf("%+.1f%%", cum_adj_rev),
    cum_adj_exp = sprintf("%+.1f%%", cum_adj_exp),
    Note        = ""
  ) %>%
  rename(
    `Hospital`     = hospital_name,
    `Type`         = hospital_type_group,
    `Revenue (%)`  = cum_adj_rev,
    `Expenses (%)` = cum_adj_exp
  )

ft <- flextable(tbl_data) %>%
  theme_vanilla() %>%
  bold(part = "header") %>%
  bg(bg = "#F2F2F2", part = "header") %>%
  fontsize(size = 9, part = "all") %>%
  font(fontname = "Arial", part = "all") %>%
  align(align = "right",  part = "body", j = c("Revenue (%)", "Expenses (%)")) %>%
  align(align = "left",   part = "body", j = c("Hospital", "Type", "Note")) %>%
  align(align = "center", part = "header") %>%
  width(j = "Hospital",     width = 2.60) %>%
  width(j = "Type",         width = 1.20) %>%
  width(j = "Revenue (%)",  width = 0.80) %>%
  width(j = "Expenses (%)", width = 0.85) %>%
  width(j = "Note",         width = 1.60) %>%
  height(height = 0.40, part = "body") %>%    # wider rows — prevents line collision
  hrule(rule = "exact", part = "body") %>%
  add_footer_lines(
    "Source: HospitalIntelligenceR | Cumulative field-adjusted scores, 2018/19\u20132024/25 | Excluded from main scatter plot"
  ) %>%
  fontsize(size = 8, part = "footer") %>%
  color(color = "white", part = "footer") %>%  # white footer text
  bg(bg = "#333333", part = "footer") %>%      # dark footer background so white is legible
  set_caption("Table: Excluded hospitals \u2014 extreme cumulative scores") %>%
  set_table_properties(layout = "autofit")

save_as_image(
  ft,
  path = file.path(FIG_DIR, "tbl_hit_01_outliers.png"),
  res  = 300
)

message("tbl_hit_01_outliers.png written")
message("\nBoth outputs in: ", FIG_DIR)