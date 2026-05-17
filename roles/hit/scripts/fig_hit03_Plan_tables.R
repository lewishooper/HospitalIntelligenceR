# =============================================================================
# roles/hit/scripts/fig_hit03_plan_tables.R
# HospitalIntelligenceR — Publication Tables: Strategic Plan × Financial Trajectory
#
# Produces two publication-quality flextable PNGs per figure_standards.md §11:
#   tbl_hit03_a_revenue.png  — field-adjusted cumulative revenue change
#   tbl_hit03_b_expense.png  — field-adjusted cumulative expense change
#
# Input (read-only):
#   roles/hit/outputs/hit_03_hospital_level.csv
#
# Output:
#   roles/hit/outputs/figures/publication/tbl_hit03_a_revenue.png
#   roles/hit/outputs/figures/publication/tbl_hit03_b_expense.png
#
# Standards: docs/figure_standards.md — Section 11 (Table Standards)
# Run after: hit_03_plan_comparison.R
# =============================================================================

library(tidyverse)
library(flextable)
library(officer)

# -----------------------------------------------------------------------------
# 0. Paths
# -----------------------------------------------------------------------------

HOSP_LEVEL <- "roles/hit/outputs/hit_03_hospital_level.csv"
FIG_DIR    <- "roles/hit/outputs/figures/publication"
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Load hospital-level scores; compute summary stats per group
#    Stats derived fresh here — graphics scripts never read from summary CSVs
# -----------------------------------------------------------------------------

hosp <- read_csv(
  HOSP_LEVEL,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
)

message(sprintf("Loaded: %d hospitals across %d plan groups",
                nrow(hosp), n_distinct(hosp$plan_group)))

# Group order: With plan first, No plan second
group_levels <- c("With strategic plan (≥2 years)", "No strategic plan")

# Revenue summary
rev_stats <- hosp %>%
  filter(plan_group %in% group_levels) %>%
  group_by(plan_group) %>%
  summarise(
    `N Hospitals` = n(),
    `Mean (pp)`   = round(mean(cum_rev_adj,   na.rm = TRUE), 1),
    `Median (pp)` = round(median(cum_rev_adj, na.rm = TRUE), 1),
    `SD (pp)`     = round(sd(cum_rev_adj,     na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  mutate(plan_group = factor(plan_group, levels = group_levels)) %>%
  arrange(plan_group) %>%
  rename(`Hospital Group` = plan_group)

# Expense summary
exp_stats <- hosp %>%
  filter(plan_group %in% group_levels) %>%
  group_by(plan_group) %>%
  summarise(
    `N Hospitals` = n(),
    `Mean (pp)`   = round(mean(cum_exp_adj,   na.rm = TRUE), 1),
    `Median (pp)` = round(median(cum_exp_adj, na.rm = TRUE), 1),
    `SD (pp)`     = round(sd(cum_exp_adj,     na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  mutate(plan_group = factor(plan_group, levels = group_levels)) %>%
  arrange(plan_group) %>%
  rename(`Hospital Group` = plan_group)

message("Revenue stats:")
print(rev_stats)
message("Expense stats:")
print(exp_stats)

# -----------------------------------------------------------------------------
# 2. Shared text elements
# -----------------------------------------------------------------------------

SOURCE_NOTE <- paste0(
  "Source: HospitalIntelligenceR HIT Analytics Workstream  |  ",
  "With plan: n = 55 hospitals (2015\u20132023 plan vintage)  |  ",
  "No plan: n = 10 hospitals"
)

FOOTNOTE <- paste0(
  "\u00b9 Field-adjusted cumulative change: sum of annual hospital YoY % change ",
  "minus field median YoY % change for that transition year, accumulated over ",
  "the measurement window.  ",
  "\u00b2 \u2018With plan\u2019 window begins at the first fiscal year following plan adoption ",
  "(plan start year Y \u2192 window begins Y/Y+1); transition year Y\u20131/Y excluded (conservative).  ",
  "\u2018No plan\u2019 window spans the full available HIT series (2019/2020\u20132024/2025).  ",
  "\u00b3 Hospitals with plans in place fewer than two full fiscal years (n = 65, primarily ",
  "2024\u20132026 plan vintage) excluded from the primary comparison and reported separately.  ",
  "FAC 983 (Huron Perth Healthcare Alliance) excluded: merged entity, no HIT data ",
  "available under the consolidated FAC code. Structural outliers FAC 854, 971, 701, and 938 ",
  "excluded from all calculations.  ",
  "\u2074 The no-plan group (n = 10) exhibits high variability (SD = 15.8 pp revenue; ",
  "9.8 pp expense); interpret both tables descriptively only. Type composition is broadly comparable: ",
  "no-plan hospitals have modestly higher Community Large representation (50%) than the ",
  "with-plan group (42%), which biases against rather than toward the observed negative trajectory."
)

# -----------------------------------------------------------------------------
# 3. std_flextable — standard styling per figure_standards.md §11
#    Called AFTER add_header_lines() so title row (i=1) can be overridden
# -----------------------------------------------------------------------------

std_flextable <- function(ft, n_data_cols = 4L) {
  
  numeric_cols <- seq(2L, n_data_cols + 1L)  # columns 2 onward are numeric
  
  ft %>%
    theme_vanilla() %>%
    font(fontname = "Arial", part = "all") %>%
    fontsize(size = 10, part = "body") %>%
    fontsize(size = 10, part = "header") %>%
    bold(part = "header") %>%
    bg(bg = "#F2F2F2", part = "header") %>%
    # Title row (i = 1 after add_header_lines) — white background, larger font
    fontsize(i = 1, size = 11, part = "header") %>%
    bg(i = 1, bg = "white", part = "header") %>%
    italic(i = 1, part = "header") %>%
    # Borders
    border_outer(part = "all",  border = fp_border(color = "grey40", width = 1.0)) %>%
    border_inner_h(part = "body",   border = fp_border(color = "grey80", width = 0.5)) %>%
    hline(i = 1, part = "header",   border = fp_border(color = "grey60", width = 0.5)) %>%
    # Alignment — text left, numerics right
    align(j = 1,           align = "left",  part = "all") %>%
    align(j = numeric_cols, align = "right", part = "all") %>%
    # Padding — slightly more on title row
    padding(padding = 5, part = "all") %>%
    padding(i = 1, padding.top = 7, padding.bottom = 7, part = "header") %>%
    set_table_properties(layout = "autofit") %>%
    width(j = 1, width = 2.5) %>%         # Group label column wider
    width(j = numeric_cols, width = 0.85) # Numeric columns equal width
}

# -----------------------------------------------------------------------------
# 4. Build and save: Revenue table
# -----------------------------------------------------------------------------

message("\nBuilding revenue table...")

ft_rev <- flextable(rev_stats) %>%
  add_header_lines(
    values = "Hospitals with strategic plans outperformed on field-adjusted revenue trajectories"
  ) %>%
  std_flextable() %>%
  add_footer_lines(SOURCE_NOTE) %>%
  add_footer_lines(FOOTNOTE) %>%
  fontsize(size = 8, part = "footer") %>%
  color(color = "grey50", part = "footer") %>%
  italic(part = "footer")

save_as_image(
  ft_rev,
  path  = file.path(FIG_DIR, "tbl_hit03_a_revenue.png"),
  res   = 300,
  webshot = "webshot2"
)
message("  Written: tbl_hit03_a_revenue.png")

# -----------------------------------------------------------------------------
# 5. Build and save: Expense table
# -----------------------------------------------------------------------------

message("Building expense table...")

ft_exp <- flextable(exp_stats) %>%
  add_header_lines(
    values = "The expense trajectory gap mirrors the revenue finding, with greater variability in the no-plan group"
  ) %>%
  std_flextable() %>%
  add_footer_lines(SOURCE_NOTE) %>%
  add_footer_lines(FOOTNOTE) %>%
  fontsize(size = 8, part = "footer") %>%
  color(color = "grey50", part = "footer") %>%
  italic(part = "footer")

save_as_image(
  ft_exp,
  path  = file.path(FIG_DIR, "tbl_hit03_b_expense.png"),
  res   = 300,
  webshot = "webshot2"
)
message("  Written: tbl_hit03_b_expense.png")

# =============================================================================
# SECTION 6 — FIN decomposition tables (within with-plan group)
#
# Decomposes the 55 with-plan hospitals by FIN primary theme status.
# fin_flag and fin_group are read from hit_03_hospital_level.csv (added by
# Section 9 of hit_03_plan_comparison.R — re-run that script first if the
# columns are absent).
#
# Outputs:
#   tbl_hit03_c_fin_revenue.png
#   tbl_hit03_d_fin_expense.png
# =============================================================================

message("\nBuilding FIN decomposition tables...")

# Confirm fin_flag column is present
if (!"fin_flag" %in% names(hosp)) {
  stop("fin_flag column missing from hit_03_hospital_level.csv. ",
       "Re-run hit_03_plan_comparison.R (Section 9) before this script.")
}

# FIN group order: FIN first, non-FIN second — mirrors plan table convention
fin_levels <- c("Primary emphasis on finance", "No primary emphasis on finance")

# Revenue summary — within with-plan group only
fin_rev_stats <- hosp %>%
  filter(
    plan_group == "With strategic plan (≥2 years)",
    !is.na(fin_group)
  ) %>%
  group_by(fin_group) %>%
  summarise(
    `N Hospitals` = n(),
    `Mean (pp)`   = round(mean(cum_rev_adj,   na.rm = TRUE), 1),
    `Median (pp)` = round(median(cum_rev_adj, na.rm = TRUE), 1),
    `SD (pp)`     = round(sd(cum_rev_adj,     na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  mutate(fin_group = factor(fin_group, levels = fin_levels)) %>%
  arrange(fin_group) %>%
  rename(`Hospital Group` = fin_group)

# Expense summary
fin_exp_stats <- hosp %>%
  filter(
    plan_group == "With strategic plan (≥2 years)",
    !is.na(fin_group)
  ) %>%
  group_by(fin_group) %>%
  summarise(
    `N Hospitals` = n(),
    `Mean (pp)`   = round(mean(cum_exp_adj,   na.rm = TRUE), 1),
    `Median (pp)` = round(median(cum_exp_adj, na.rm = TRUE), 1),
    `SD (pp)`     = round(sd(cum_exp_adj,     na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  mutate(fin_group = factor(fin_group, levels = fin_levels)) %>%
  arrange(fin_group) %>%
  rename(`Hospital Group` = fin_group)

message("FIN revenue stats:")
print(fin_rev_stats)
message("FIN expense stats:")
print(fin_exp_stats)

# Source note and footnote — scoped to with-plan group
# N counts filled dynamically from the summary data
n_fin     <- fin_rev_stats %>% filter(`Hospital Group` == "Primary emphasis on finance")    %>% pull(`N Hospitals`)
n_non_fin <- fin_rev_stats %>% filter(`Hospital Group` == "No primary emphasis on finance") %>% pull(`N Hospitals`)

FIN_SOURCE_NOTE <- paste0(
  "Source: HospitalIntelligenceR HIT Analytics Workstream  |  ",
  "Restricted to hospitals with strategic plans in place \u22652 years (n = 55)  |  ",
  sprintf("FIN group: n = %d  |  Non-FIN group: n = %d", n_fin, n_non_fin)
)

FIN_FOOTNOTE <- paste0(
  "\u00b9 FIN classification: hospital has at least one strategic direction with a ",
  "primary theme of Financial Sustainability. Secondary theme assignments are excluded; ",
  "a hospital with FIN as a secondary theme only is counted in the non-FIN group.  ",
  "\u00b2 Measurement windows are plan-anchored (first fiscal year following plan adoption ",
  "through 2024/2025) and field-adjusted, consistent with Tables HIT-03a/b. ",
  "All exclusions from those tables apply here.  ",
  "\u00b3 This comparison is restricted to the 55 hospitals meeting the \u22652-year plan ",
  "tenure threshold. Hospitals without strategic plans are not included."
)

# -----------------------------------------------------------------------------
# Revenue table — FIN vs non-FIN
# -----------------------------------------------------------------------------

ft_fin_rev <- flextable(fin_rev_stats) %>%
  add_header_lines(
    values = "Financial sustainability as a strategic priority shows no detectable revenue trajectory advantage"
  ) %>%
  std_flextable() %>%
  add_footer_lines(FIN_SOURCE_NOTE) %>%
  add_footer_lines(FIN_FOOTNOTE) %>%
  fontsize(size = 8, part = "footer") %>%
  color(color = "grey50", part = "footer") %>%
  italic(part = "footer")

save_as_image(
  ft_fin_rev,
  path    = file.path(FIG_DIR, "tbl_hit03_c_fin_revenue.png"),
  res     = 300,
  webshot = "webshot2"
)
message("  Written: tbl_hit03_c_fin_revenue.png")

# -----------------------------------------------------------------------------
# Expense table — FIN vs non-FIN
# -----------------------------------------------------------------------------

ft_fin_exp <- flextable(fin_exp_stats) %>%
  add_header_lines(
    values = "The expense trajectory is similarly indistinguishable between hospitals with and without a finance strategic priority"
  ) %>%
  std_flextable() %>%
  add_footer_lines(FIN_SOURCE_NOTE) %>%
  add_footer_lines(FIN_FOOTNOTE) %>%
  fontsize(size = 8, part = "footer") %>%
  color(color = "grey50", part = "footer") %>%
  italic(part = "footer")

save_as_image(
  ft_fin_exp,
  path    = file.path(FIG_DIR, "tbl_hit03_d_fin_expense.png"),
  res     = 300,
  webshot = "webshot2"
)
message("  Written: tbl_hit03_d_fin_expense.png")

message("\n--- fig_hit03_plan_tables.R complete ---")
message(sprintf("  Output directory: %s", FIG_DIR))
message("  Tables produced:")
message("    tbl_hit03_a_revenue.png       — plan vs. no plan, revenue")
message("    tbl_hit03_b_expense.png       — plan vs. no plan, expense")
message("    tbl_hit03_c_fin_revenue.png   — FIN vs. non-FIN, revenue")
message("    tbl_hit03_d_fin_expense.png   — FIN vs. non-FIN, expense")