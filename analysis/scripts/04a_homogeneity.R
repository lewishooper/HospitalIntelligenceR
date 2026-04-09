# =============================================================================
# analysis/scripts/04a_homogeneity.R
# HospitalIntelligenceR — Direction 4a: Strategic Homogeneity
#
# QUESTION:
#   Are Ontario hospital strategic plans effectively the same?
#   How similar are hospitals to one another — within type groups, across
#   type groups, and across time? Does the Current era show meaningfully
#   different homogeneity than the full cohort?
#
# APPROACH:
#   Three complementary lenses:
#
#   LENS 1 — Theme breadth
#     Distribution of hospitals by number of themes present (0–10).
#     Reported by hospital type group. Answers: how many themes do hospitals
#     typically cover? Is breadth consistent or variable?
#
#   LENS 2 — Modal profile similarity
#     For each type group, identify the "core profile" — themes present in
#     ≥50% of hospitals in that group. For each hospital, calculate the
#     number of core themes it shares with its group's core profile.
#     Answers: how many hospitals closely match the consensus profile?
#
#   LENS 3 — Pairwise Jaccard similarity
#     For every hospital pair, compute Jaccard similarity on their binary
#     theme vectors (intersection / union). Summarise mean within-type and
#     between-type Jaccard. Answers: how interchangeable are hospitals'
#     strategic theme portfolios?
#
#   All three lenses run on TWO scopes:
#     (a) Full usable cohort (all eras)
#     (b) Current era only (plan_start_year 2024–2026)
#   Differences between scopes are reported explicitly.
#
# OUTPUTS:
#   analysis/outputs/tables/04a_breadth_summary.csv
#   analysis/outputs/tables/04a_core_profile_by_type.csv
#   analysis/outputs/tables/04a_modal_match_summary.csv
#   analysis/outputs/tables/04a_jaccard_summary.csv
#   analysis/outputs/tables/04a_jaccard_pairwise.csv       (full pair matrix)
#   analysis/outputs/figures/04a_breadth_distribution.png
#   analysis/outputs/figures/04a_jaccard_heatmap.png
#   analysis/outputs/figures/04a_jaccard_density.png
#
# DEPENDENCIES:
#   Requires 'strategy_classified' in environment (from 00c_build_strategy_classified.R)
#   Requires 'spine' in environment (from 00_prepare_data.R)
#   OR will load from CSV directly.
#
# USAGE:
#   source("analysis/scripts/00_prepare_data.R")
#   source("analysis/scripts/00c_build_strategy_classified.R")
#   source("analysis/scripts/04a_homogeneity.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(tidyr)
  library(stringr)
  library(forcats)
})


# =============================================================================
# SECTION 1: Load data
# =============================================================================

if (!exists("strategy_classified")) {
  message("'strategy_classified' not found — loading from CSV.")
  strategy_classified <- read_csv(
    "analysis/data/strategy_classified.csv",
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )
}

if (!exists("spine")) {
  message("'spine' not found — loading from CSV.")
  spine <- read_csv(
    "analysis/data/hospital_spine.csv",
    col_types = cols(
      .default             = col_character(),
      robots_allowed       = col_logical(),
      has_extraction       = col_logical(),
      has_vision           = col_logical(),
      has_mission          = col_logical(),
      has_values           = col_logical(),
      has_purpose          = col_logical(),
      plan_period_parse_ok = col_logical(),
      n_directions         = col_integer(),
      plan_start_year      = col_integer()
    ),
    show_col_types = FALSE
  )
}


# =============================================================================
# SECTION 2: Constants
# =============================================================================

VALID_CODES <- c("WRK", "PAT", "PAR", "FIN", "RES",
                 "ACC", "INN", "INF", "EDI", "ORG")

TYPE_LEVELS <- c("Teaching", "Community — Large",
                 "Community — Small", "Specialty")

THEME_LABELS <- c(
  WRK = "WRK — Workforce & People",
  PAT = "PAT — Patient Care & Quality",
  PAR = "PAR — Partnerships & Community",
  FIN = "FIN — Financial Sustainability",
  RES = "RES — Research & Academic",
  ACC = "ACC — Access & Care Delivery",
  INN = "INN — Innovation & Digital Health",
  INF = "INF — Infrastructure & Operations",
  EDI = "EDI — Equity, Diversity & Inclusion",
  ORG = "ORG — Organizational Culture"
)

ERA_CURRENT_MIN <- 2024
ERA_CURRENT_MAX <- 2026

# Core profile threshold: theme must be present in >= this % of type-group
# hospitals to be included in the group's core profile
CORE_THRESHOLD <- 50


# =============================================================================
# SECTION 3: Build hospital-level binary theme matrix
# =============================================================================

spine_year <- spine %>%
  select(fac, hospital_name, plan_start_year) %>%
  mutate(plan_start_year = as.integer(plan_start_year))

classified_usable <- strategy_classified %>%
  filter(
    robots_allowed       == "TRUE",
    extraction_quality   %in% c("full", "partial"),
    !is.na(primary_theme),
    classification_status == "ok"
  ) %>%
  select(-plan_start_year) %>%
  left_join(spine_year, by = "fac") %>%
  mutate(
    hospital_type_group = factor(hospital_type_group, levels = TYPE_LEVELS)
  )

# Hospital × theme binary matrix (one row per hospital)
.build_theme_matrix <- function(df) {
  mat <- df %>%
    distinct(fac, hospital_type_group, plan_start_year, primary_theme) %>%
    filter(primary_theme %in% VALID_CODES) %>%
    mutate(has_theme = 1L) %>%
    pivot_wider(
      names_from  = primary_theme,
      values_from = has_theme,
      values_fill = 0L
    )
  
  # Ensure all 10 theme columns present
  for (code in VALID_CODES) {
    if (!code %in% names(mat)) mat[[code]] <- 0L
  }
  
  # Join hospital_name from spine_year
  mat %>%
    left_join(spine_year %>% select(fac, hospital_name), by = "fac") %>%
    select(fac, hospital_name, hospital_type_group, plan_start_year,
           all_of(VALID_CODES))
}

# Full cohort matrix
hosp_full <- .build_theme_matrix(classified_usable)

# Current era matrix
hosp_current <- hosp_full %>%
  filter(
    !is.na(plan_start_year),
    plan_start_year >= ERA_CURRENT_MIN,
    plan_start_year <= ERA_CURRENT_MAX
  )

cat(sprintf("Full cohort:    %d hospitals\n", nrow(hosp_full)))
cat(sprintf("Current era:    %d hospitals (plan start %d–%d)\n\n",
            nrow(hosp_current), ERA_CURRENT_MIN, ERA_CURRENT_MAX))


# =============================================================================
# SECTION 4: LENS 1 — Theme breadth
# =============================================================================

cat("=== LENS 1: Theme Breadth ===\n\n")

.compute_breadth <- function(mat, scope_label) {
  mat %>%
    mutate(
      n_themes = rowSums(across(all_of(VALID_CODES))),
      scope    = scope_label
    ) %>%
    select(fac, hospital_name, hospital_type_group, plan_start_year,
           n_themes, scope)
}

breadth_full    <- .compute_breadth(hosp_full,    "Full cohort")
breadth_current <- .compute_breadth(hosp_current, "Current era")
breadth_all     <- bind_rows(breadth_full, breadth_current)

# Summary by type and scope
breadth_summary <- breadth_all %>%
  group_by(scope, hospital_type_group) %>%
  summarise(
    n_hospitals  = n(),
    mean_themes  = round(mean(n_themes), 2),
    median_themes = median(n_themes),
    sd_themes    = round(sd(n_themes), 2),
    min_themes   = min(n_themes),
    max_themes   = max(n_themes),
    .groups = "drop"
  )

cat("Theme breadth by type and scope:\n")
print(as.data.frame(breadth_summary))
cat("\n")

# Overall (across all types)
breadth_overall <- breadth_all %>%
  group_by(scope) %>%
  summarise(
    n_hospitals   = n(),
    mean_themes   = round(mean(n_themes), 2),
    median_themes = median(n_themes),
    sd_themes     = round(sd(n_themes), 2),
    .groups = "drop"
  ) %>%
  mutate(hospital_type_group = factor("ALL TYPES", levels = c(levels(breadth_summary$hospital_type_group), "ALL TYPES")))

cat("Overall breadth:\n")
print(as.data.frame(breadth_overall))
cat("\n")

write_csv(
  bind_rows(breadth_summary, breadth_overall),
  "analysis/outputs/tables/04a_breadth_summary.csv"
)
cat("Table written: 04a_breadth_summary.csv\n\n")


# =============================================================================
# SECTION 5: LENS 2 — Core profile and modal match
# =============================================================================

cat("=== LENS 2: Core Profile and Modal Match ===\n\n")

.compute_core_profile <- function(mat, scope_label) {
  # Core profile: themes present in >= CORE_THRESHOLD % of hospitals in type group
  mat %>%
    group_by(hospital_type_group) %>%
    summarise(
      n_hospitals = n(),
      across(all_of(VALID_CODES), function(x) round(100 * mean(x), 1)),
      .groups = "drop"
    ) %>%
    pivot_longer(
      cols      = all_of(VALID_CODES),
      names_to  = "theme",
      values_to = "pct_hospitals"
    ) %>%
    mutate(
      in_core_profile = pct_hospitals >= CORE_THRESHOLD,
      scope           = scope_label
    )
}

core_full    <- .compute_core_profile(hosp_full,    "Full cohort")
core_current <- .compute_core_profile(hosp_current, "Current era")
core_all     <- bind_rows(core_full, core_current)

cat(sprintf("Core profile threshold: themes present in >= %d%% of type-group hospitals\n\n",
            CORE_THRESHOLD))

# Print core profiles
for (sc in c("Full cohort", "Current era")) {
  cat(sprintf("--- %s ---\n", sc))
  core_all %>%
    filter(scope == sc, in_core_profile) %>%
    arrange(hospital_type_group, desc(pct_hospitals)) %>%
    group_by(hospital_type_group) %>%
    summarise(
      n_hospitals   = first(n_hospitals),
      core_themes   = paste(theme, collapse = ", "),
      n_core_themes = n(),
      .groups = "drop"
    ) %>%
    { for (i in seq_len(nrow(.))) {
      cat(sprintf("  %-22s (n=%2d)  core themes (%d): %s\n",
                  .$hospital_type_group[i],
                  .$n_hospitals[i],
                  .$n_core_themes[i],
                  .$core_themes[i]))
    }; . } %>%
    invisible()
  cat("\n")
}

write_csv(core_all, "analysis/outputs/tables/04a_core_profile_by_type.csv")
cat("Table written: 04a_core_profile_by_type.csv\n\n")

# Modal match: for each hospital, count how many core themes it has
.compute_modal_match <- function(mat, core_df, scope_label) {
  # Build per-type core theme sets
  core_sets <- core_df %>%
    filter(scope == scope_label, in_core_profile) %>%
    group_by(hospital_type_group) %>%
    summarise(core_set = list(theme), .groups = "drop")
  
  mat %>%
    left_join(core_sets, by = "hospital_type_group") %>%
    rowwise() %>%
    mutate(
      core_set_size = length(core_set),
      themes_present = list(VALID_CODES[c_across(all_of(VALID_CODES)) == 1]),
      n_core_matches = length(intersect(themes_present, core_set)),
      n_core_missing = core_set_size - n_core_matches,
      scope = scope_label
    ) %>%
    ungroup() %>%
    select(fac, hospital_name, hospital_type_group,
           core_set_size, n_core_matches, n_core_missing, scope)
}

match_full    <- .compute_modal_match(hosp_full,    core_all, "Full cohort")
match_current <- .compute_modal_match(hosp_current, core_all, "Current era")
match_all     <- bind_rows(match_full, match_current)

# Summary: % of hospitals matching full core profile (0 missing)
modal_match_summary <- match_all %>%
  group_by(scope, hospital_type_group) %>%
  summarise(
    n_hospitals        = n(),
    mean_core_set_size = round(mean(core_set_size), 1),
    pct_full_match     = round(100 * mean(n_core_missing == 0), 1),
    pct_miss_1_or_less = round(100 * mean(n_core_missing <= 1), 1),
    pct_miss_2_or_less = round(100 * mean(n_core_missing <= 2), 1),
    mean_n_missing     = round(mean(n_core_missing), 2),
    .groups = "drop"
  )

cat("Modal match summary (% of hospitals matching group core profile):\n")
print(as.data.frame(modal_match_summary))
cat("\n")

write_csv(modal_match_summary, "analysis/outputs/tables/04a_modal_match_summary.csv")
cat("Table written: 04a_modal_match_summary.csv\n\n")


# =============================================================================
# SECTION 6: LENS 3 — Pairwise Jaccard similarity
# =============================================================================

cat("=== LENS 3: Pairwise Jaccard Similarity ===\n\n")

.compute_jaccard_matrix <- function(mat) {
  # Extract binary theme matrix as numeric matrix
  m <- as.matrix(mat[, VALID_CODES])
  n <- nrow(m)
  facs <- mat$fac
  types <- as.character(mat$hospital_type_group)
  
  # Pre-allocate results
  results <- vector("list", n * (n - 1) / 2)
  idx <- 1L
  
  for (i in seq_len(n - 1)) {
    for (j in (i + 1):n) {
      a <- m[i, ]
      b <- m[j, ]
      intersection <- sum(a & b)
      union        <- sum(a | b)
      jaccard      <- if (union == 0) NA_real_ else intersection / union
      
      results[[idx]] <- list(
        fac_a       = facs[i],
        fac_b       = facs[j],
        type_a      = types[i],
        type_b      = types[j],
        jaccard     = jaccard,
        intersection = intersection,
        union        = union
      )
      idx <- idx + 1L
    }
  }
  
  bind_rows(results) %>%
    mutate(
      pair_type = if_else(type_a == type_b, type_a, "Between types")
    )
}

cat("Computing Jaccard similarity — full cohort...\n")
jaccard_full <- .compute_jaccard_matrix(hosp_full) %>%
  mutate(scope = "Full cohort")

cat("Computing Jaccard similarity — current era...\n")
jaccard_current <- .compute_jaccard_matrix(hosp_current) %>%
  mutate(scope = "Current era")

jaccard_pairwise <- bind_rows(jaccard_full, jaccard_current)

write_csv(jaccard_pairwise, "analysis/outputs/tables/04a_jaccard_pairwise.csv")
cat("Table written: 04a_jaccard_pairwise.csv\n\n")

# Summary: mean Jaccard by pair type and scope
jaccard_summary <- jaccard_pairwise %>%
  filter(!is.na(jaccard)) %>%
  group_by(scope, pair_type) %>%
  summarise(
    n_pairs      = n(),
    mean_jaccard = round(mean(jaccard), 3),
    median_jaccard = round(median(jaccard), 3),
    sd_jaccard   = round(sd(jaccard), 3),
    pct_above_50 = round(100 * mean(jaccard >= 0.5), 1),
    pct_above_67 = round(100 * mean(jaccard >= 0.667), 1),
    .groups = "drop"
  ) %>%
  arrange(scope, desc(mean_jaccard))

cat("Jaccard summary by pair type and scope:\n")
print(as.data.frame(jaccard_summary))
cat("\n")

# Full vs Current delta
jaccard_delta <- jaccard_summary %>%
  select(scope, pair_type, mean_jaccard) %>%
  pivot_wider(names_from = scope, values_from = mean_jaccard) %>%
  mutate(
    delta = round(`Current era` - `Full cohort`, 3),
    direction = case_when(
      delta >  0.01 ~ "More similar in Current era",
      delta < -0.01 ~ "Less similar in Current era",
      TRUE          ~ "No meaningful change"
    )
  )

cat("Full cohort vs Current era — Jaccard delta:\n")
print(as.data.frame(jaccard_delta))
cat("\n")

write_csv(jaccard_summary, "analysis/outputs/tables/04a_jaccard_summary.csv")
cat("Table written: 04a_jaccard_summary.csv\n\n")


# =============================================================================
# SECTION 7: Figure — Theme breadth distribution
# =============================================================================

# Dot strip + mean overlay, faceted by hospital type, panels = scope
# Consistent with project visualization conventions

breadth_plot_data <- breadth_all %>%
  mutate(
    hospital_type_group = factor(hospital_type_group, levels = TYPE_LEVELS),
    scope = factor(scope, levels = c("Full cohort", "Current era"))
  )

breadth_means <- breadth_plot_data %>%
  group_by(scope, hospital_type_group) %>%
  summarise(mean_n = mean(n_themes), .groups = "drop")

p_breadth <- ggplot(breadth_plot_data,
                    aes(x = hospital_type_group, y = n_themes)) +
  geom_jitter(
    width = 0.18, height = 0.15,
    colour = "#2171B5", alpha = 0.55, size = 1.8
  ) +
  geom_crossbar(
    data = breadth_means,
    aes(x = hospital_type_group, y = mean_n,
        ymin = mean_n, ymax = mean_n),
    width = 0.45, colour = "#08306B", linewidth = 0.9
  ) +
  facet_wrap(~ scope, ncol = 2) +
  scale_x_discrete(labels = function(x) str_wrap(x, width = 12)) +
  scale_y_continuous(
    limits = c(0, 10),
    breaks = 0:10,
    expand = expansion(mult = c(0, 0.05))
  ) +
  labs(
    title    = "Strategic Theme Breadth by Hospital Type",
    subtitle = paste0(
      "Number of distinct themes per hospital | Each dot = one hospital | Bar = group mean\n",
      "Full cohort (all eras) vs Current era (", ERA_CURRENT_MIN, "\u2013", ERA_CURRENT_MAX, ")"
    ),
    x       = NULL,
    y       = "Number of themes",
    caption = paste0(
      "Source: HospitalIntelligenceR Phase 2 extraction + thematic classification.\n",
      "Usable cohort only (full/partial extractions, robots-allowed)."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(colour = "grey40", size = 8),
    plot.caption  = element_text(colour = "grey50", size = 6.5),
    strip.text    = element_text(face = "bold", size = 10),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank()
  )

ggsave(
  "analysis/outputs/figures/04a_breadth_distribution.png",
  plot   = p_breadth,
  width  = 7,
  height = 5,
  dpi    = 300
)
cat("Figure saved: 04a_breadth_distribution.png\n")


# =============================================================================
# SECTION 8: Figure — Jaccard heatmap (mean by type-pair, side-by-side scopes)
# =============================================================================

# Build symmetric type × type mean Jaccard for each scope
.build_heatmap_data <- function(jac_df, scope_label) {
  within <- jac_df %>%
    filter(pair_type != "Between types", scope == scope_label) %>%
    group_by(pair_type) %>%
    summarise(mean_jaccard = round(mean(jaccard, na.rm = TRUE), 3), .groups = "drop") %>%
    mutate(type_a = pair_type, type_b = pair_type)
  
  between <- jac_df %>%
    filter(pair_type == "Between types", scope == scope_label) %>%
    mutate(
      key_a = pmin(type_a, type_b),
      key_b = pmax(type_a, type_b)
    ) %>%
    group_by(key_a, key_b) %>%
    summarise(mean_jaccard = round(mean(jaccard, na.rm = TRUE), 3), .groups = "drop") %>%
    rename(type_a = key_a, type_b = key_b)
  
  # Make symmetric
  bind_rows(
    within,
    between,
    between %>% rename(type_a = type_b, type_b = type_a)
  ) %>%
    mutate(scope = scope_label)
}

heatmap_data <- bind_rows(
  .build_heatmap_data(jaccard_pairwise, "Full cohort"),
  .build_heatmap_data(jaccard_pairwise, "Current era")
) %>%
  mutate(
    type_a = factor(type_a, levels = TYPE_LEVELS),
    type_b = factor(type_b, levels = rev(TYPE_LEVELS)),
    scope  = factor(scope, levels = c("Full cohort", "Current era"))
  )

p_heatmap <- ggplot(heatmap_data, aes(x = type_a, y = type_b, fill = mean_jaccard)) +
  geom_tile(colour = "white", linewidth = 0.8) +
  geom_text(
    aes(label = sprintf("%.2f", mean_jaccard)),
    size = 3.5,
    colour = ifelse(heatmap_data$mean_jaccard > 0.55, "white", "grey20")
  ) +
  facet_wrap(~ scope, ncol = 2) +
  scale_fill_gradient(
    low    = "#EFF3FF",
    high   = "#08519C",
    name   = "Mean\nJaccard",
    limits = c(0, 1),
    breaks = c(0, 0.25, 0.5, 0.75, 1.0)
  ) +
  scale_x_discrete(labels = function(x) str_wrap(x, width = 10)) +
  scale_y_discrete(labels = function(x) str_wrap(x, width = 10)) +
  labs(
    title    = "Strategic Similarity Between Hospital Type Groups",
    subtitle = paste0(
      "Mean Jaccard similarity (theme-set overlap) | 0 = no shared themes, 1 = identical\n",
      "Diagonal = within-group similarity; off-diagonal = between-group similarity"
    ),
    x       = NULL,
    y       = NULL,
    caption = paste0(
      "Source: HospitalIntelligenceR Phase 2 extraction + thematic classification.\n",
      "Jaccard = |A \u2229 B| / |A \u222a B| on binary theme presence vectors."
    )
  ) +
  theme_minimal(base_size = 10) +
  theme(
    plot.title    = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(colour = "grey40", size = 8),
    plot.caption  = element_text(colour = "grey50", size = 6.5),
    strip.text    = element_text(face = "bold", size = 10),
    panel.grid    = element_blank(),
    axis.text.x   = element_text(size = 8, angle = 20, hjust = 1),
    axis.text.y   = element_text(size = 8),
    legend.key.height = unit(1.2, "cm")
  )

ggsave(
  "analysis/outputs/figures/04a_jaccard_heatmap.png",
  plot   = p_heatmap,
  width  = 9,
  height = 5,
  dpi    = 300
)
cat("Figure saved: 04a_jaccard_heatmap.png\n")


# =============================================================================
# SECTION 9: Figure — Jaccard density / distribution (within vs between type)
# =============================================================================

density_data <- jaccard_pairwise %>%
  filter(!is.na(jaccard)) %>%
  mutate(
    comparison = if_else(pair_type == "Between types",
                         "Between type groups",
                         "Within type group"),
    scope = factor(scope, levels = c("Full cohort", "Current era"))
  )

p_density <- ggplot(density_data, aes(x = jaccard, fill = comparison)) +
  geom_density(alpha = 0.45, colour = NA) +
  geom_vline(
    data = density_data %>%
      group_by(scope, comparison) %>%
      summarise(mean_j = mean(jaccard), .groups = "drop"),
    aes(xintercept = mean_j, colour = comparison),
    linewidth = 0.9, linetype = "dashed"
  ) +
  facet_wrap(~ scope, ncol = 2) +
  scale_fill_manual(
    values = c("Within type group" = "#2171B5", "Between type groups" = "#FC8D59"),
    name   = NULL
  ) +
  scale_colour_manual(
    values = c("Within type group" = "#08306B", "Between type groups" = "#D73027"),
    name   = NULL
  ) +
  scale_x_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.25),
    labels = function(x) sprintf("%.2f", x)
  ) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.05))) +
  labs(
    title    = "Distribution of Pairwise Jaccard Similarity",
    subtitle = paste0(
      "Within-type pairs (blue) vs Between-type pairs (orange) | Dashed lines = group means\n",
      "Full cohort (all eras) vs Current era (", ERA_CURRENT_MIN, "\u2013", ERA_CURRENT_MAX, ")"
    ),
    x       = "Jaccard similarity",
    y       = "Density",
    caption = paste0(
      "Source: HospitalIntelligenceR Phase 2 extraction + thematic classification.\n",
      "Each observation is a unique hospital pair."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(colour = "grey40", size = 8),
    plot.caption  = element_text(colour = "grey50", size = 6.5),
    strip.text    = element_text(face = "bold", size = 10),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

ggsave(
  "analysis/outputs/figures/04a_jaccard_density.png",
  plot   = p_density,
  width  = 9,
  height = 5,
  dpi    = 300
)
cat("Figure saved: 04a_jaccard_density.png\n\n")


# =============================================================================
# SECTION 10: Console summary — key findings
# =============================================================================

cat("=============================================================================\n")
cat("KEY FINDINGS SUMMARY — 04a Strategic Homogeneity\n")
cat("=============================================================================\n\n")

cat("LENS 1 — Theme Breadth\n")
cat("---------------------------------------------------------------------\n")
breadth_overall %>%
  arrange(scope) %>%
  { cat(sprintf("  %-16s  n=%d  mean=%.1f  median=%.0f  SD=%.2f\n",
                .$scope, .$n_hospitals, .$mean_themes,
                .$median_themes, .$sd_themes)); . } %>%
  invisible()
cat("\n")

cat("LENS 2 — Core Profile (themes in >=50% of type-group hospitals)\n")
cat("---------------------------------------------------------------------\n")
for (sc in c("Full cohort", "Current era")) {
  cat(sprintf("  %s:\n", sc))
  modal_match_summary %>%
    filter(scope == sc) %>%
    { cat(sprintf("    %-22s  n=%2d  core themes=%s  full match=%.0f%%  miss<=1=%.0f%%\n",
                  .$hospital_type_group, .$n_hospitals,
                  .$mean_core_set_size,
                  .$pct_full_match, .$pct_miss_1_or_less)); . } %>%
    invisible()
}
cat("\n")

cat("LENS 3 — Jaccard Similarity\n")
cat("---------------------------------------------------------------------\n")
for (sc in c("Full cohort", "Current era")) {
  cat(sprintf("  %s:\n", sc))
  jaccard_summary %>%
    filter(scope == sc) %>%
    arrange(desc(mean_jaccard)) %>%
    { cat(sprintf("    %-26s  n pairs=%5d  mean=%.3f  pct>0.5=%.0f%%  pct>0.67=%.0f%%\n",
                  .$pair_type, .$n_pairs, .$mean_jaccard,
                  .$pct_above_50, .$pct_above_67)); . } %>%
    invisible()
}
cat("\n")

cat("Full vs Current delta:\n")
for (i in seq_len(nrow(jaccard_delta))) {
  cat(sprintf("  %-26s  Full=%.3f  Current=%.3f  delta=%+.3f  (%s)\n",
              jaccard_delta$pair_type[i],
              jaccard_delta[["Full cohort"]][i],
              jaccard_delta[["Current era"]][i],
              jaccard_delta$delta[i],
              jaccard_delta$direction[i]))
}

cat("\nDone. Review console output, tables, and figures.\n")
cat("Outputs in:\n")
cat("  analysis/outputs/tables/04a_*.csv\n")
cat("  analysis/outputs/figures/04a_*.png\n")