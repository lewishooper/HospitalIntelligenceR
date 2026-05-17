# =============================================================================
# roles/hit/scripts/hit_02_strategy_join.R
# HospitalIntelligenceR — Strategy-HIT Linkage Dataset
#
# PURPOSE:
#   Join HIT field trajectory data (hit_01 output) to strategy theme
#   classifications (strategy pipeline output) at the FAC level. Produces
#   the analytical dataset that enables the core linking question:
#
#     Do strategic directions influence financial and clinical performance?
#
#   The join is FAC-keyed. Strategy data is aggregated from direction-level
#   to FAC-level before joining, producing one binary presence flag and one
#   direction count per theme per hospital.
#
#   Three analytical summaries are also written:
#     (a) Theme × quadrant distribution — does holding a theme associate
#         with particular financial trajectories?
#     (b) Type group trajectory summary — mean/median cumulative scores
#         by hospital_type_group (cross-check with 04a Teaching divergence)
#     (c) Era × quadrant summary — does plan vintage associate with trajectory?
#
# INPUTS:
#   roles/hit/outputs/hit_01_field_trajectories.csv     [hit_01 output]
#   analysis/data/strategy_classified.csv               [direction-level with themes + plan dates]
#   analysis/data/hospital_spine.csv                    [FAC scope and type reference]
#
# OUTPUTS (roles/hit/outputs/):
#   hit_02_strategy_joined.csv     — one row per FAC; trajectories + theme flags + plan context
#   hit_02_theme_quadrant.csv      — theme × quadrant distribution (n and %)
#   hit_02_type_summary.csv        — mean trajectory scores by hospital_type_group
#   hit_02_era_quadrant.csv        — plan era × quadrant distribution
#
# RUN SEQUENCE:
#   hit_import.R → hit_validate.R → hit_01_field_segmentation.R
#     → hit_02_strategy_join.R
#
# DESIGN CONSTRAINTS:
#   - fac as character throughout — coerced on load, no exceptions
#   - Scope boundary: hospital_spine.csv (134 active hospitals)
#   - Strategy data aggregated to FAC level using primary_theme only
#     (secondary themes documented but not used in primary analysis)
#   - Hospitals present in hit_01 trajectories but absent from strategy data
#     receive NA theme fields and has_strategy_data = FALSE
#   - Structural outliers (FACs 854, 971) are retained in joined output but
#     flagged and excluded from percentage calculations in summaries
#   - Era classification cutpoints match 03b_theme_trends.R:
#       Pre-COVID  ≤ 2019 | COVID 2020–2022 | Current ≥ 2023
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(purrr)
  library(stringr)
  library(lubridate)
})


# =============================================================================
# SECTION 0 — Paths and constants
# =============================================================================

PATHS <- list(
  trajectories      = "roles/hit/outputs/hit_01_field_trajectories.csv",
  strategy          = "analysis/data/strategy_classified.csv",
  spine             = "analysis/data/hospital_spine.csv",
  out_joined        = "roles/hit/outputs/hit_02_strategy_joined.csv",
  out_theme_quad    = "roles/hit/outputs/hit_02_theme_quadrant.csv",
  out_type_summary  = "roles/hit/outputs/hit_02_type_summary.csv",
  out_era_quad      = "roles/hit/outputs/hit_02_era_quadrant.csv"
)

dir.create("roles/hit/outputs", recursive = TRUE, showWarnings = FALSE)

# Theme codes in use (GOV retired; INN included as active minority theme)
THEMES <- c("WRK", "PAT", "PAR", "FIN", "RES", "ACC", "INN", "INF", "EDI", "ORG")

# Era cutpoints — must match 03b_theme_trends.R
ERA_COVID_START   <- 2020L
ERA_CURRENT_START <- 2023L

# Structural outlier FACs (flagged in hit_01; excluded from pct calculations)
STRUCTURAL_OUTLIER_FACS <- c("854", "971")


# =============================================================================
# SECTION 1 — Load hit_01 trajectory data
#
# One row per FAC. Contains cumulative adjusted revenue and expense scores,
# quadrant classification, efficiency sub-classification, and type group.
# =============================================================================

message("Section 1 — Loading hit_01 field trajectories")

if (!file.exists(PATHS$trajectories)) {
  stop(
    "hit_01_field_trajectories.csv not found at: ", PATHS$trajectories, "\n",
    "Run hit_01_field_segmentation.R first."
  )
}

trajectories <- read_csv(
  PATHS$trajectories,
  col_types = cols(fac = col_character(), .default = col_guess()),
  show_col_types = FALSE
)

message(sprintf("  Loaded: %d rows, %d cols", nrow(trajectories), ncol(trajectories)))
message(sprintf("  Unique FACs: %d", n_distinct(trajectories$fac)))
message(sprintf("  Quadrant distribution:"))
print(table(trajectories$quadrant))

# Confirm outlier_flag presence — needed for pct calculations in summaries
if (!"outlier_flag" %in% names(trajectories)) {
  message("  NOTE: outlier_flag absent from trajectories — deriving from STRUCTURAL_OUTLIER_FACS")
  trajectories <- trajectories %>%
    mutate(outlier_flag = fac %in% STRUCTURAL_OUTLIER_FACS)
}

n_outlier     <- sum(trajectories$outlier_flag)
n_analytical  <- nrow(trajectories) - n_outlier

message(sprintf("  Structural outliers (excluded from pct denominators): %d", n_outlier))
message(sprintf("  Analytical cohort for percentage calculations:         %d", n_analytical))

message("\nhit_02 Section 1 complete — paste output above before proceeding.")


# =============================================================================
# SECTION 2 — Load and aggregate strategy data to FAC level
#
# strategy_classified.csv is direction-level (one row per direction per hospital).
# This section aggregates to one row per FAC, producing:
#   (a) Theme presence flags: has_WRK, has_PAT, etc.
#   (b) Theme direction counts: n_WRK, n_PAT, etc.
#   (c) Plan-level summary: plan_start_year, plan_era, n_themes, n_directions
# =============================================================================

message("\nSection 2 — Loading and aggregating strategy classification data")

if (!file.exists(PATHS$strategy)) {
  stop(
    "strategy_classified.csv not found at: ", PATHS$strategy, "\n",
    "Run 00c_build_strategy_classified.R first."
  )
}

strategy_raw <- read_csv(
  PATHS$strategy,
  col_types = cols(
    fac               = col_character(),
    direction_number  = col_character(),
    plan_period_start = col_date(),
    plan_period_end   = col_date(),
    plan_start_year   = col_integer(),
    .default          = col_character()
  ),
  show_col_types = FALSE
)

message(sprintf("  strategy_classified loaded: %d rows, %d cols",
                nrow(strategy_raw), ncol(strategy_raw)))
message(sprintf("  Unique FACs: %d", n_distinct(strategy_raw$fac)))

# Restrict to classified directions (primary_theme not NA)
# Unclassified rows (thin extraction, robots-blocked) are tracked separately
strategy_classified_only <- strategy_raw %>%
  filter(!is.na(primary_theme))

strategy_unclassified <- strategy_raw %>%
  filter(is.na(primary_theme))

message(sprintf("  Classified directions: %d across %d FACs",
                nrow(strategy_classified_only),
                n_distinct(strategy_classified_only$fac)))
message(sprintf("  Unclassified rows: %d across %d FACs",
                nrow(strategy_unclassified),
                n_distinct(strategy_unclassified$fac)))

# ---------------------------------------------------------------------------
# 2a — Plan-level context: one row per FAC
#      Derived from all rows (classified and unclassified) to capture plan
#      dates for every hospital, including those with thin strategy data.
# ---------------------------------------------------------------------------

plan_context <- strategy_raw %>%
  group_by(fac) %>%
  summarise(
    hospital_name_strat = first(hospital_name),   # strategy pipeline name (reference)
    plan_start_year     = first(plan_start_year[!is.na(plan_start_year)]),
    plan_period_start   = first(plan_period_start[!is.na(plan_period_start)]),
    plan_period_end     = first(plan_period_end[!is.na(plan_period_end)]),
    .groups = "drop"
  ) %>%
  mutate(
    # Plan end year for overlap calculation
    plan_end_year = as.integer(year(plan_period_end)),
    
    # Era classification — matches 03b cutpoints
    plan_era = case_when(
      is.na(plan_start_year)                          ~ NA_character_,
      plan_start_year < ERA_COVID_START               ~ "Pre-COVID",
      plan_start_year < ERA_CURRENT_START             ~ "COVID",
      TRUE                                            ~ "Current"
    ),
    
    # Active during HIT window flag
    # HIT window: 2018/2019 → 2024/2025 → calendar years 2018–2025
    # A plan overlaps if: plan ends >= 2018 AND plan starts <= 2025
    plan_active_in_hit_window = case_when(
      is.na(plan_start_year) | is.na(plan_end_year) ~ NA,
      plan_end_year >= 2018L & plan_start_year <= 2025L ~ TRUE,
      TRUE                                              ~ FALSE
    )
  )

message(sprintf("\n  Plan context rows: %d unique FACs", nrow(plan_context)))
message("  Plan era distribution:")
print(table(plan_context$plan_era, useNA = "ifany"))
message("  Plans active during HIT window:")
print(table(plan_context$plan_active_in_hit_window, useNA = "ifany"))

# ---------------------------------------------------------------------------
# 2b — Theme presence flags and counts: one row per FAC
#      Based on classified directions only (primary_theme not NA)
# ---------------------------------------------------------------------------

# Direction counts per FAC × theme
theme_counts_long <- strategy_classified_only %>%
  group_by(fac, primary_theme) %>%
  summarise(n_directions_theme = n(), .groups = "drop")

# Pivot to wide: one column per theme (count)
theme_counts_wide <- theme_counts_long %>%
  pivot_wider(
    names_from  = primary_theme,
    values_from = n_directions_theme,
    values_fill = 0L,
    names_prefix = "n_"
  )

# Ensure all theme count columns exist (even if no hospital uses a given theme)
for (th in THEMES) {
  col_name <- paste0("n_", th)
  if (!col_name %in% names(theme_counts_wide)) {
    theme_counts_wide[[col_name]] <- 0L
  }
}

# Presence flags (has_*): TRUE if at least one classified direction in that theme
theme_flags_wide <- theme_counts_wide %>%
  mutate(
    across(
      all_of(paste0("n_", THEMES)),
      function(x) x > 0L,
      .names = "has_{str_remove(.col, 'n_')}"
    )
  )

# FAC-level direction summary
direction_summary <- strategy_classified_only %>%
  group_by(fac) %>%
  summarise(
    n_directions = n(),
    n_themes     = n_distinct(primary_theme),
    .groups = "drop"
  )

# Combine theme flags with direction summary
strategy_fac <- theme_flags_wide %>%
  left_join(direction_summary, by = "fac") %>%
  mutate(has_strategy_data = TRUE)

# FACs in strategy data but with no classified directions get has_strategy_data = FALSE
facs_no_classified <- setdiff(plan_context$fac, strategy_classified_only$fac)

if (length(facs_no_classified) > 0) {
  message(sprintf("\n  FACs with strategy records but no classified directions: %d",
                  length(facs_no_classified)))
  print(facs_no_classified)
  
  # Add skeleton rows for these FACs with 0 directions, NA flags
  skeleton_rows <- tibble(fac = facs_no_classified) %>%
    mutate(
      n_directions     = 0L,
      n_themes         = 0L,
      has_strategy_data = FALSE
    )
  for (th in THEMES) {
    skeleton_rows[[paste0("n_", th)]]   <- 0L
    skeleton_rows[[paste0("has_", th)]] <- FALSE
  }
  strategy_fac <- bind_rows(strategy_fac, skeleton_rows)
}

# Join plan context to produce the complete FAC-level strategy table
strategy_fac_full <- strategy_fac %>%
  left_join(plan_context, by = "fac")

message(sprintf("\n  FAC-level strategy summary: %d rows", nrow(strategy_fac_full)))
message("  Theme prevalence (% of FACs with each theme, classified only):")
theme_prev <- strategy_fac_full %>%
  filter(has_strategy_data) %>%
  summarise(
    across(
      all_of(paste0("has_", THEMES)),
      function(x) round(mean(x, na.rm = TRUE) * 100, 1)
    )
  ) %>%
  pivot_longer(everything(), names_to = "flag", values_to = "pct") %>%
  mutate(theme = str_remove(flag, "has_")) %>%
  select(theme, pct) %>%
  arrange(desc(pct))
print(theme_prev)

message("\nhit_02 Section 2 complete — paste output above before proceeding.")


# =============================================================================
# SECTION 3 — Join trajectories to strategy FAC-level data
#
# Left join: all trajectory FACs are retained.
# FACs with no strategy match receive NA theme fields and
# has_strategy_data = FALSE.
# =============================================================================

message("\nSection 3 — Joining trajectories to strategy data")

# Load spine for coverage validation
spine <- read_csv(
  PATHS$spine,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>%
  select(fac, hospital_name, hospital_type_group) %>%
  distinct()

message(sprintf("  Spine loaded: %d rows", nrow(spine)))

# Join
joined <- trajectories %>%
  left_join(strategy_fac_full, by = "fac")

# Coverage report
n_has_strategy   <- sum(joined$has_strategy_data, na.rm = TRUE)
n_no_strategy    <- sum(!joined$has_strategy_data | is.na(joined$has_strategy_data))
n_strategy_not_in_hit <- nrow(anti_join(strategy_fac_full, trajectories, by = "fac"))

message(sprintf("  Trajectory FACs with strategy data:    %d of %d",
                n_has_strategy, nrow(joined)))
message(sprintf("  Trajectory FACs WITHOUT strategy data: %d", n_no_strategy))
message(sprintf("  Strategy FACs not in trajectories:     %d", n_strategy_not_in_hit))

if (n_no_strategy > 0) {
  message("  FACs without strategy data:")
  no_strat_facs <- joined %>%
    filter(!has_strategy_data | is.na(has_strategy_data)) %>%
    pull(fac)
  print(sort(no_strat_facs))
}

if (n_strategy_not_in_hit > 0) {
  message("  Strategy FACs not in HIT cohort (expected — strategy-only hospitals):")
  strat_only <- anti_join(strategy_fac_full, trajectories, by = "fac") %>% pull(fac)
  print(sort(strat_only))
}

# Column tidy: if hospital_name came through from both sides, prefer hit_01 version
if ("hospital_name.x" %in% names(joined)) {
  joined <- joined %>%
    rename(hospital_name = hospital_name.x) %>%
    select(-hospital_name.y)
}
# hospital_name_strat column (from strategy pipeline) retained for reference
# hospital_type_group already in trajectories from hit_01 — keep it

message(sprintf("\n  Joined dataset: %d rows, %d cols", nrow(joined), ncol(joined)))
message("  has_strategy_data distribution:")
print(table(joined$has_strategy_data, useNA = "ifany"))

message("\nhit_02 Section 3 complete — paste output above before proceeding.")


# =============================================================================
# SECTION 4 — Analytical summaries
#
# Three cross-tabulations written to separate CSVs. All exclude structural
# outliers from denominator percentages.
#
# 4a: Theme × quadrant — primary linking question
# 4b: Hospital type × trajectory scores — financial divergence check
# 4c: Plan era × quadrant — temporal dimension
# =============================================================================

message("\nSection 4 — Computing analytical summaries")

# Working dataset: exclude structural outliers from percentage calculations
# (retain them in the full joined dataset but not in summary denominators)
joined_analytical <- joined %>%
  filter(!outlier_flag)

n_analytical_confirmed <- nrow(joined_analytical)

message(sprintf("  Analytical cohort (excl. structural outliers): %d hospitals",
                n_analytical_confirmed))

# ---------------------------------------------------------------------------
# 4a — Theme × quadrant distribution
#
# For each theme: among hospitals that DO hold this theme vs. those that don't,
# what is the quadrant distribution? Reports n and pct within each theme-presence
# group, plus mean trajectory scores.
# ---------------------------------------------------------------------------

message("\n  4a: Computing theme × quadrant distribution")

# Build one-theme-at-a-time using lapply, then bind_rows
theme_quadrant_list <- lapply(THEMES, function(th) {
  flag_col <- paste0("has_", th)
  
  # Only hospitals with strategy data contribute to theme-specific rows
  df <- joined_analytical %>%
    filter(has_strategy_data) %>%
    mutate(has_theme = if_else(.data[[flag_col]] == TRUE, "With theme", "Without theme"))
  
  n_with    <- sum(df$has_theme == "With theme",    na.rm = TRUE)
  n_without <- sum(df$has_theme == "Without theme", na.rm = TRUE)
  
  df %>%
    group_by(has_theme, quadrant) %>%
    summarise(
      n_hospitals      = n(),
      mean_cum_adj_rev = round(mean(cum_adj_rev, na.rm = TRUE), 1),
      mean_cum_adj_exp = round(mean(cum_adj_exp, na.rm = TRUE), 1),
      .groups = "drop"
    ) %>%
    group_by(has_theme) %>%
    mutate(
      theme         = th,
      n_theme_group = if_else(has_theme == "With theme", n_with, n_without),
      pct_within    = round(n_hospitals / n_theme_group * 100, 1)
    ) %>%
    ungroup() %>%
    select(theme, has_theme, n_theme_group, quadrant, n_hospitals, pct_within,
           mean_cum_adj_rev, mean_cum_adj_exp)
})

theme_quadrant <- bind_rows(theme_quadrant_list) %>%
  arrange(theme, has_theme, desc(n_hospitals))

message("  Theme × quadrant rows: ", nrow(theme_quadrant))
message("  Preview — FIN theme quadrant distribution:")
print(theme_quadrant %>% filter(theme == "FIN") %>% select(has_theme, quadrant, n_hospitals, pct_within, mean_cum_adj_rev, mean_cum_adj_exp))

# ---------------------------------------------------------------------------
# 4b — Hospital type × trajectory summary
#
# Mean and median cum_adj_rev and cum_adj_exp by hospital_type_group.
# Checks whether the Teaching strategic divergence finding from 04a also
# manifests as a financial trajectory divergence.
# ---------------------------------------------------------------------------

message("\n  4b: Computing type group trajectory summary")

type_summary <- joined_analytical %>%
  filter(!is.na(hospital_type_group)) %>%
  group_by(hospital_type_group) %>%
  summarise(
    n_hospitals       = n(),
    mean_cum_adj_rev  = round(mean(cum_adj_rev,  na.rm = TRUE), 1),
    median_cum_adj_rev = round(median(cum_adj_rev, na.rm = TRUE), 1),
    mean_cum_adj_exp  = round(mean(cum_adj_exp,  na.rm = TRUE), 1),
    median_cum_adj_exp = round(median(cum_adj_exp, na.rm = TRUE), 1),
    pct_revenue_led   = round(mean(quadrant == "Revenue-led", na.rm = TRUE) * 100, 1),
    pct_neither       = round(mean(quadrant == "Neither",     na.rm = TRUE) * 100, 1),
    pct_expense_led   = round(mean(quadrant == "Expense-led", na.rm = TRUE) * 100, 1),
    pct_cost_pressure = round(mean(quadrant == "Cost pressure", na.rm = TRUE) * 100, 1),
    .groups = "drop"
  ) %>%
  arrange(hospital_type_group)

# Add overall row
overall_type <- joined_analytical %>%
  summarise(
    hospital_type_group = "All",
    n_hospitals         = n(),
    mean_cum_adj_rev    = round(mean(cum_adj_rev,  na.rm = TRUE), 1),
    median_cum_adj_rev  = round(median(cum_adj_rev, na.rm = TRUE), 1),
    mean_cum_adj_exp    = round(mean(cum_adj_exp,  na.rm = TRUE), 1),
    median_cum_adj_exp  = round(median(cum_adj_exp, na.rm = TRUE), 1),
    pct_revenue_led     = round(mean(quadrant == "Revenue-led", na.rm = TRUE) * 100, 1),
    pct_neither         = round(mean(quadrant == "Neither",     na.rm = TRUE) * 100, 1),
    pct_expense_led     = round(mean(quadrant == "Expense-led", na.rm = TRUE) * 100, 1),
    pct_cost_pressure   = round(mean(quadrant == "Cost pressure", na.rm = TRUE) * 100, 1)
  )

type_summary_out <- bind_rows(overall_type, type_summary)

message("  Type group trajectory summary:")
print(type_summary_out %>%
        select(hospital_type_group, n_hospitals, mean_cum_adj_rev, mean_cum_adj_exp,
               pct_revenue_led, pct_neither, pct_expense_led))

# ---------------------------------------------------------------------------
# 4c — Plan era × quadrant distribution
#
# Among hospitals with strategy data, does plan vintage (Pre-COVID / COVID /
# Current) associate with financial trajectory quadrant?
# ---------------------------------------------------------------------------

message("\n  4c: Computing plan era × quadrant distribution")

era_quadrant <- joined_analytical %>%
  filter(has_strategy_data, !is.na(plan_era)) %>%
  group_by(plan_era, quadrant) %>%
  summarise(
    n_hospitals      = n(),
    mean_cum_adj_rev = round(mean(cum_adj_rev, na.rm = TRUE), 1),
    mean_cum_adj_exp = round(mean(cum_adj_exp, na.rm = TRUE), 1),
    .groups = "drop"
  ) %>%
  group_by(plan_era) %>%
  mutate(
    era_total  = sum(n_hospitals),
    pct_within = round(n_hospitals / era_total * 100, 1)
  ) %>%
  ungroup() %>%
  arrange(plan_era, desc(n_hospitals))

message("  Plan era × quadrant distribution:")
print(era_quadrant %>% select(plan_era, quadrant, n_hospitals, pct_within))

message("\nhit_02 Section 4 complete — paste output above before proceeding.")


# =============================================================================
# SECTION 5 — Write output CSVs
# =============================================================================

message("\nSection 5 — Writing output files")

# ---------------------------------------------------------------------------
# hit_02_strategy_joined.csv — primary analytical dataset
# Column order: identifiers, type, trajectory, theme flags, theme counts,
#               plan context, metadata
# ---------------------------------------------------------------------------

id_cols          <- c("fac", "hospital_name", "hospital_type_group")
trajectory_cols  <- c("n_transitions", "cum_adj_rev", "cum_adj_exp",
                      "quadrant", "exp_subclass", "vol_metric_used",
                      "vol_change_pct", "eff_improved", "outlier_flag",
                      "rev_improving", "rev_declining",
                      "exp_improving", "exp_worsening",
                      "cpd_change", "ced_change",
                      "rev_first", "rev_last", "exp_first", "exp_last")
has_cols         <- paste0("has_", THEMES)
n_cols           <- paste0("n_", THEMES)
plan_cols        <- c("has_strategy_data", "n_directions", "n_themes",
                      "plan_start_year", "plan_period_start", "plan_period_end",
                      "plan_end_year", "plan_era", "plan_active_in_hit_window",
                      "hospital_name_strat")

# Select in order, keeping only columns that exist in `joined`
cols_to_select <- c(id_cols, trajectory_cols, has_cols, n_cols, plan_cols)
cols_present   <- intersect(cols_to_select, names(joined))
cols_extra     <- setdiff(names(joined), cols_present)  # any remaining columns

joined_out <- joined %>%
  select(all_of(cols_present), any_of(cols_extra)) %>%
  arrange(hospital_type_group, fac)

write_csv(joined_out, PATHS$out_joined)
message(sprintf("  hit_02_strategy_joined.csv:  %d rows, %d cols",
                nrow(joined_out), ncol(joined_out)))

write_csv(theme_quadrant, PATHS$out_theme_quad)
message(sprintf("  hit_02_theme_quadrant.csv:   %d rows", nrow(theme_quadrant)))

write_csv(type_summary_out, PATHS$out_type_summary)
message(sprintf("  hit_02_type_summary.csv:     %d rows", nrow(type_summary_out)))

write_csv(era_quadrant, PATHS$out_era_quad)
message(sprintf("  hit_02_era_quadrant.csv:     %d rows", nrow(era_quadrant)))

# ---------------------------------------------------------------------------
# Console — final summary
# ---------------------------------------------------------------------------

n_full_overlap <- joined_out %>%
  filter(has_strategy_data, !outlier_flag) %>%
  nrow()

message(sprintf("\n  === hit_02 complete ==="))
message(sprintf("  Trajectory FACs in output:           %d", nrow(joined_out)))
message(sprintf("  With full strategy + trajectory data: %d (analytical core)",
                n_full_overlap))
message(sprintf("  Outputs written to: roles/hit/outputs/"))
message("  Next: FIN vs. expense trajectory first-cut analysis (hit_03 or ad hoc)")


# =============================================================================
# SECTION 6 — Visualizations
#
# Three figures written to roles/hit/outputs/figures/:
#   fig_hit02_a_fin_quadrant.png    — FIN theme × quadrant (primary linking figure)
#   fig_hit02_b_type_trajectory.png — Type group mean trajectory scores (dumbbell)
#   fig_hit02_c_era_quadrant.png    — Plan era × quadrant distribution
#
# All use a consistent palette and strip to a clean minimal theme.
# Structural outliers already excluded in joined_analytical.
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(forcats)
})

dir.create("roles/hit/outputs/figures", recursive = TRUE, showWarnings = FALSE)

message("\nSection 6 — Writing figures")

# ---------------------------------------------------------------------------
# Palette and shared theme
# ---------------------------------------------------------------------------

QUADRANT_COLOURS <- c(
  "Revenue-led"   = "#2166AC",   # blue
  "Both"          = "#4DAC26",   # green
  "Expense-led"   = "#D6604D",   # coral
  "Cost pressure" = "#B2ABD2",   # muted lavender
  "Neither"       = "#D9D9D9"    # light grey
)

hit_theme <- theme_minimal(base_size = 11) +
  theme(
    plot.title       = element_text(face = "bold", size = 12),
    plot.subtitle    = element_text(size = 10, colour = "grey40"),
    plot.caption     = element_text(size = 8,  colour = "grey55"),
    axis.title       = element_text(size = 10),
    legend.position  = "bottom",
    legend.title     = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.minor   = element_blank()
  )

# ---------------------------------------------------------------------------
# Figure A — FIN theme × quadrant
#
# Two grouped bars: "Has FIN direction" vs "No FIN direction"
# Y-axis: % of hospitals within each group
# Bars coloured by quadrant
# ---------------------------------------------------------------------------

message("  Figure A: FIN theme × quadrant")

fin_quad_plot_data <- theme_quadrant %>%
  filter(theme == "FIN") %>%
  mutate(
    has_theme  = factor(has_theme, levels = c("With theme", "Without theme")),
    quadrant   = factor(quadrant,  levels = names(QUADRANT_COLOURS))
  )

fig_a <- ggplot(fin_quad_plot_data,
                aes(x = has_theme, y = pct_within, fill = quadrant)) +
  geom_col(position = "stack", width = 0.55, colour = "white", linewidth = 0.3) +
  geom_text(aes(label = ifelse(pct_within >= 5, paste0(pct_within, "%"), "")),
            position = position_stack(vjust = 0.5),
            size = 3.2, colour = "white", fontface = "bold") +
  scale_fill_manual(values = QUADRANT_COLOURS, drop = FALSE) +
  scale_y_continuous(labels = scales::percent_format(scale = 1),
                     expand = expansion(mult = c(0, 0.03))) +
  scale_x_discrete(labels = c("With theme" = "FIN strategic\ndirection", 
                              "Without theme" = "No FIN strategic\ndirection")) +
  labs(
    title    = "Financial trajectory by FIN strategic theme",
    subtitle = "Hospitals with a Financial Sustainability direction vs. those without",
    x        = NULL,
    y        = "% of hospitals in group",
    caption  = paste0("Ontario acute care hospitals, n = ", 
                      sum(fin_quad_plot_data$n_hospitals),
                      ". Structural outliers excluded.")
  ) +
  hit_theme +
  guides(fill = guide_legend(nrow = 2))

ggsave("roles/hit/outputs/figures/fig_hit02_a_fin_quadrant.png",
       plot = fig_a, width = 6, height = 5, dpi = 150)
message("    Written: fig_hit02_a_fin_quadrant.png")


# ---------------------------------------------------------------------------
# Figure B — Type group trajectory dumbbell
#
# Each hospital_type_group shown as a dumbbell:
#   left anchor  = mean cum_adj_exp  (expense trajectory score)
#   right anchor = mean cum_adj_rev  (revenue trajectory score)
# Helps answer: are some types systematically revenue-led vs expense-led?
# ---------------------------------------------------------------------------

message("  Figure B: Type group trajectory dumbbell")

type_dumbbell_data <- type_summary_out %>%
  filter(hospital_type_group != "All") %>%
  mutate(
    hospital_type_group = fct_reorder(hospital_type_group, mean_cum_adj_rev)
  )

fig_b <- ggplot(type_dumbbell_data) +
  # Connecting segment
  geom_segment(aes(x = mean_cum_adj_exp, xend = mean_cum_adj_rev,
                   y = hospital_type_group, yend = hospital_type_group),
               colour = "grey70", linewidth = 0.8) +
  # Expense anchor
  geom_point(aes(x = mean_cum_adj_exp, y = hospital_type_group),
             colour = "#D6604D", size = 4) +
  # Revenue anchor
  geom_point(aes(x = mean_cum_adj_rev, y = hospital_type_group),
             colour = "#2166AC", size = 4) +
  # Zero reference
  geom_vline(xintercept = 0, linetype = "dashed", colour = "grey50", linewidth = 0.5) +
  # n label
  geom_text(aes(x = pmax(mean_cum_adj_rev, mean_cum_adj_exp) + 0.3,
                y = hospital_type_group,
                label = paste0("n=", n_hospitals)),
            size = 3, colour = "grey45", hjust = 0) +
  scale_x_continuous(expand = expansion(mult = c(0.05, 0.12))) +
  labs(
    title    = "Mean field-adjusted trajectory by hospital type",
    subtitle = "Blue = revenue trajectory  |  Red = expense trajectory  |  Positive = improving relative to field",
    x        = "Mean cumulative field-adjusted score (pp)",
    y        = NULL,
    caption  = "Structural outliers excluded."
  ) +
  hit_theme +
  theme(legend.position = "none",
        panel.grid.major.y = element_line(colour = "grey92"))

ggsave("roles/hit/outputs/figures/fig_hit02_b_type_trajectory.png",
       plot = fig_b, width = 7.5, height = 4.5, dpi = 150)
message("    Written: fig_hit02_b_type_trajectory.png")


# ---------------------------------------------------------------------------
# Figure C — Plan era × quadrant
#
# Faceted or stacked: for Pre-COVID / COVID / Current plans,
# what % of hospitals land in each trajectory quadrant?
# Answers: are newer plans associated with different financial outcomes?
# ---------------------------------------------------------------------------

message("  Figure C: Plan era × quadrant")

era_plot_data <- era_quadrant %>%
  mutate(
    plan_era = factor(plan_era, levels = c("Pre-COVID", "COVID", "Current")),
    quadrant = factor(quadrant, levels = names(QUADRANT_COLOURS))
  )

fig_c <- ggplot(era_plot_data,
                aes(x = plan_era, y = pct_within, fill = quadrant)) +
  geom_col(position = "stack", width = 0.55, colour = "white", linewidth = 0.3) +
  geom_text(aes(label = ifelse(pct_within >= 6, paste0(pct_within, "%"), "")),
            position = position_stack(vjust = 0.5),
            size = 3.2, colour = "white", fontface = "bold") +
  scale_fill_manual(values = QUADRANT_COLOURS, drop = FALSE) +
  scale_y_continuous(labels = scales::percent_format(scale = 1),
                     expand = expansion(mult = c(0, 0.03))) +
  labs(
    title    = "Financial trajectory quadrant by strategic plan era",
    subtitle = "Pre-COVID ≤ 2019  |  COVID 2020–2022  |  Current ≥ 2023",
    x        = "Plan era",
    y        = "% of hospitals in era",
    caption  = paste0("Hospitals with strategy data and active HIT-window plan only. ",
                      "Structural outliers excluded.")
  ) +
  hit_theme +
  guides(fill = guide_legend(nrow = 2))

ggsave("roles/hit/outputs/figures/fig_hit02_c_era_quadrant.png",
       plot = fig_c, width = 6.5, height = 5, dpi = 150)
message("    Written: fig_hit02_c_era_quadrant.png")

message("\nhit_02 Section 6 complete — figures written to roles/hit/outputs/figures/")