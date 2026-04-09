# =============================================================================
# analysis/scripts/04b_unique_strategies.R
# HospitalIntelligenceR — Direction 4b: Unique and Outlier Strategies
#
# QUESTION:
#   Which hospitals are doing something genuinely different from their peers,
#   and which strategic directions are rare or distinctive within their theme?
#
# APPROACH:
#   Two-part analysis:
#
#   PART 1 — Theme-level outliers (pure R)
#     Using the type-group core profiles established in 04a, identify hospitals
#     whose theme portfolio deviates materially from their group's consensus.
#     Three outlier types:
#       (a) Missing core: hospital lacks one or more core themes for its type
#       (b) Peripheral adopters: hospital includes themes rare in its type group
#           (present in <25% of group) — these are the discretionary choices
#       (c) Zero-overlap outliers: hospital shares no themes with the sector
#           modal profile (WRK + PAT) — the most extreme outliers
#
#   PART 2 — Direction-level distinctiveness (Claude API)
#     Within each theme, directions are grouped by hospital type. The Claude
#     API is called once per theme × type cell (max 10 × 4 = 40 calls, but
#     only cells with sufficient directions are called). Claude is asked to:
#       - Identify the 3–5 most common/generic direction names in the cell
#       - Identify any directions that are unusual, specific, or distinctive
#         relative to peers in the same theme and type group
#     Output is a structured table of distinctive directions with brief
#     characterization of what makes them unusual.
#
#   Scope: Current era cohort (n=62) is the primary analysis population.
#   Full cohort results for Part 1 are produced as a secondary reference.
#
# OUTPUTS:
#   analysis/outputs/tables/04b_theme_outliers.csv       (Part 1 — all scopes)
#   analysis/outputs/tables/04b_peripheral_adopters.csv  (Part 1 — peripheral)
#   analysis/outputs/tables/04b_distinctive_directions.csv (Part 2 — API output)
#   analysis/outputs/figures/04b_outlier_map.png         (Part 1 figure)
#   logs/04b_api_log.csv                                 (Part 2 API audit)
#
# DEPENDENCIES:
#   Requires 'strategy_classified' in environment (from 00c_build_strategy_classified.R)
#   Requires 'spine' in environment (from 00_prepare_data.R)
#   OR will load from CSV directly.
#   Part 2 requires ANTHROPIC_API_KEY in environment.
#   Part 2 sources core/claude_api.R — set working directory to project root.
#
# COST ESTIMATE (Part 2):
#   ~30 API calls (populated theme × type cells, current era)
#   ~500 tokens input + ~300 tokens output per call
#   ~$0.05–0.10 USD total at Sonnet pricing
#   Run PART1_ONLY <- TRUE to skip API calls during development/review.
#
# USAGE:
#   source("analysis/scripts/00_prepare_data.R")
#   source("analysis/scripts/00c_build_strategy_classified.R")
#   source("analysis/scripts/04b_unique_strategies.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(readr)
  library(tidyr)
  library(stringr)
  library(forcats)
  library(jsonlite)
})


# =============================================================================
# CONFIGURATION
# =============================================================================

# Set TRUE to run Part 1 only (no API calls) — useful for development/review
PART1_ONLY <- FALSE

# Peripheral theme threshold: theme present in < this % of type group
# is considered a "peripheral" or discretionary choice
PERIPHERAL_THRESHOLD <- 25

# Minimum directions in a theme × type cell to warrant an API distinctiveness call
MIN_DIRECTIONS_FOR_API <- 5

# Current era bounds (consistent with 04a)
ERA_CURRENT_MIN <- 2024
ERA_CURRENT_MAX <- 2026

# API model
API_MODEL <- "claude-sonnet-4-20250514"


# =============================================================================
# SECTION 1: Constants (consistent with 03c and 04a)
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

# Sector-wide core themes (present in all type-group cores, both scopes)
SECTOR_CORE <- c("WRK", "PAT")


# =============================================================================
# SECTION 2: Load data
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
      plan_period_parse_ok = col_logical(),
      n_directions         = col_integer(),
      plan_start_year      = col_integer()
    ),
    show_col_types = FALSE
  )
}

spine_year <- spine %>%
  select(fac, hospital_name, plan_start_year) %>%
  mutate(plan_start_year = as.integer(plan_start_year))

# Usable directions (all eras)
directions_usable <- strategy_classified %>%
  filter(
    robots_allowed       == "TRUE",
    extraction_quality   %in% c("full", "partial"),
    !is.na(primary_theme),
    classification_status == "ok",
    primary_theme %in% VALID_CODES
  ) %>%
  select(-plan_start_year) %>%
  left_join(spine_year, by = "fac") %>%
  mutate(
    hospital_type_group = factor(hospital_type_group, levels = TYPE_LEVELS)
  )

# Current era subset
directions_current <- directions_usable %>%
  filter(
    !is.na(plan_start_year),
    plan_start_year >= ERA_CURRENT_MIN,
    plan_start_year <= ERA_CURRENT_MAX
  )

cat(sprintf("Usable directions — full cohort:  %d directions, %d hospitals\n",
            nrow(directions_usable), n_distinct(directions_usable$fac)))
cat(sprintf("Usable directions — current era:  %d directions, %d hospitals\n\n",
            nrow(directions_current), n_distinct(directions_current$fac)))


# =============================================================================
# SECTION 3: Build hospital-level theme matrix and type-group prevalence
#            (Replicated from 04a for self-contained operation)
# =============================================================================

.build_theme_matrix <- function(df) {
  mat <- df %>%
    distinct(fac, hospital_type_group, plan_start_year, primary_theme) %>%
    mutate(has_theme = 1L) %>%
    pivot_wider(
      names_from  = primary_theme,
      values_from = has_theme,
      values_fill = 0L
    )
  for (code in VALID_CODES) {
    if (!code %in% names(mat)) mat[[code]] <- 0L
  }
  mat %>%
    left_join(spine_year %>% select(fac, hospital_name), by = "fac") %>%
    select(fac, hospital_name, hospital_type_group, plan_start_year,
           all_of(VALID_CODES))
}

hosp_full    <- .build_theme_matrix(directions_usable)
hosp_current <- .build_theme_matrix(directions_current)

# Type-group theme prevalence (% of hospitals with each theme)
.compute_type_prevalence <- function(mat) {
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
      values_to = "pct_in_type"
    )
}

prev_full    <- .compute_type_prevalence(hosp_full)    %>% mutate(scope = "Full cohort")
prev_current <- .compute_type_prevalence(hosp_current) %>% mutate(scope = "Current era")
type_prev    <- bind_rows(prev_full, prev_current)


# =============================================================================
# PART 1: THEME-LEVEL OUTLIER IDENTIFICATION
# =============================================================================

cat("=============================================================================\n")
cat("PART 1: Theme-Level Outlier Identification\n")
cat("=============================================================================\n\n")


# =============================================================================
# SECTION 4: Outlier type (a) — Missing core themes
#            Hospitals that lack one or more of their type group's core themes.
#            Core defined as >= 50% prevalence within type group (consistent with 04a).
# =============================================================================

CORE_THRESHOLD <- 50

.flag_missing_core <- function(mat, prev_df, scope_label) {
  # Build core theme set per type group
  core_sets <- prev_df %>%
    filter(scope == scope_label, pct_in_type >= CORE_THRESHOLD) %>%
    group_by(hospital_type_group) %>%
    summarise(core_themes = list(theme), .groups = "drop")
  
  mat %>%
    left_join(core_sets, by = "hospital_type_group") %>%
    rowwise() %>%
    mutate(
      core_themes_list  = list(core_themes),
      themes_present    = list(VALID_CODES[c_across(all_of(VALID_CODES)) == 1]),
      missing_core      = list(setdiff(core_themes_list, themes_present)),
      n_missing_core    = length(missing_core),
      missing_core_str  = paste(missing_core, collapse = ", "),
      is_missing_core   = n_missing_core > 0,
      scope             = scope_label
    ) %>%
    ungroup() %>%
    select(fac, hospital_name, hospital_type_group, plan_start_year,
           n_missing_core, missing_core_str, is_missing_core, scope)
}

missing_core_full    <- .flag_missing_core(hosp_full,    type_prev, "Full cohort")
missing_core_current <- .flag_missing_core(hosp_current, type_prev, "Current era")
missing_core_all     <- bind_rows(missing_core_full, missing_core_current)

cat("--- Missing core themes by type and scope ---\n")
missing_core_all %>%
  group_by(scope, hospital_type_group) %>%
  summarise(
    n_hospitals        = n(),
    n_missing_any_core = sum(is_missing_core),
    pct_missing_core   = round(100 * mean(is_missing_core), 1),
    .groups = "drop"
  ) %>%
  { cat(sprintf("  %-16s  %-22s  n=%2d  missing core: %2d (%.0f%%)\n",
                .$scope, .$hospital_type_group,
                .$n_hospitals, .$n_missing_any_core, .$pct_missing_core)); . } %>%
  invisible()
cat("\n")

cat("--- Hospitals with missing core themes (Current era) ---\n")
missing_core_current %>%
  filter(is_missing_core) %>%
  arrange(hospital_type_group, desc(n_missing_core)) %>%
  { cat(sprintf("  FAC %-6s  %-40s  %-22s  missing: %s\n",
                .$fac, .$hospital_name, .$hospital_type_group,
                .$missing_core_str)); . } %>%
  invisible()
cat("\n")


# =============================================================================
# SECTION 5: Outlier type (b) — Peripheral theme adopters
#            Hospitals that include themes present in < PERIPHERAL_THRESHOLD %
#            of their type group — these are the discretionary strategic choices.
# =============================================================================

.flag_peripheral <- function(mat, prev_df, scope_label) {
  # Build peripheral theme list per type group (< threshold %)
  peripheral_sets <- prev_df %>%
    filter(scope == scope_label, pct_in_type < PERIPHERAL_THRESHOLD,
           pct_in_type > 0) %>%  # exclude themes with zero presence
    group_by(hospital_type_group) %>%
    summarise(
      peripheral_themes = list(theme),
      peripheral_pcts   = list(setNames(pct_in_type, theme)),
      .groups = "drop"
    )
  
  mat %>%
    left_join(peripheral_sets, by = "hospital_type_group") %>%
    rowwise() %>%
    mutate(
      themes_present      = list(VALID_CODES[c_across(all_of(VALID_CODES)) == 1]),
      peripheral_adopted  = list(intersect(themes_present, peripheral_themes)),
      n_peripheral        = length(peripheral_adopted),
      peripheral_str      = paste(peripheral_adopted, collapse = ", "),
      has_peripheral      = n_peripheral > 0,
      scope               = scope_label
    ) %>%
    ungroup() %>%
    select(fac, hospital_name, hospital_type_group, plan_start_year,
           n_peripheral, peripheral_str, has_peripheral, scope)
}

peripheral_full    <- .flag_peripheral(hosp_full,    type_prev, "Full cohort")
peripheral_current <- .flag_peripheral(hosp_current, type_prev, "Current era")
peripheral_all     <- bind_rows(peripheral_full, peripheral_current)

cat(sprintf("--- Peripheral theme adopters (threshold: <%d%% of type group) ---\n\n",
            PERIPHERAL_THRESHOLD))

cat("Summary by type and scope:\n")
peripheral_all %>%
  group_by(scope, hospital_type_group) %>%
  summarise(
    n_hospitals      = n(),
    n_has_peripheral = sum(has_peripheral),
    pct_peripheral   = round(100 * mean(has_peripheral), 1),
    .groups = "drop"
  ) %>%
  { cat(sprintf("  %-16s  %-22s  n=%2d  has peripheral: %2d (%.0f%%)\n",
                .$scope, .$hospital_type_group,
                .$n_hospitals, .$n_has_peripheral, .$pct_peripheral)); . } %>%
  invisible()
cat("\n")

cat("Hospitals with peripheral themes (Current era, sorted by n peripheral):\n")
peripheral_current %>%
  filter(has_peripheral) %>%
  arrange(hospital_type_group, desc(n_peripheral), fac) %>%
  { cat(sprintf("  FAC %-6s  %-40s  %-22s  peripheral: %s\n",
                .$fac, .$hospital_name, .$hospital_type_group,
                .$peripheral_str)); . } %>%
  invisible()
cat("\n")


# =============================================================================
# SECTION 6: Outlier type (c) — Zero sector-core overlap
#            Hospitals missing both WRK and PAT — the two universal core themes.
#            These are the most extreme outliers in the dataset.
# =============================================================================

.flag_zero_sector_core <- function(mat, scope_label) {
  mat %>%
    mutate(
      has_WRK = WRK == 1L,
      has_PAT = PAT == 1L,
      has_sector_core = has_WRK & has_PAT,
      missing_WRK = !has_WRK,
      missing_PAT = !has_PAT,
      scope = scope_label
    ) %>%
    select(fac, hospital_name, hospital_type_group, plan_start_year,
           has_WRK, has_PAT, has_sector_core, missing_WRK, missing_PAT, scope)
}

sector_core_full    <- .flag_zero_sector_core(hosp_full,    "Full cohort")
sector_core_current <- .flag_zero_sector_core(hosp_current, "Current era")
sector_core_all     <- bind_rows(sector_core_full, sector_core_current)

cat("--- Sector core (WRK + PAT) absence ---\n")
sector_core_all %>%
  group_by(scope) %>%
  summarise(
    n_hospitals       = n(),
    missing_WRK       = sum(missing_WRK),
    missing_PAT       = sum(missing_PAT),
    missing_both      = sum(!has_sector_core),
    pct_missing_both  = round(100 * mean(!has_sector_core), 1),
    .groups = "drop"
  ) %>%
  { cat(sprintf("  %-16s  n=%3d  missing WRK=%d  missing PAT=%d  missing both=%d (%.0f%%)\n",
                .$scope, .$n_hospitals, .$missing_WRK, .$missing_PAT,
                .$missing_both, .$pct_missing_both)); . } %>%
  invisible()

if (any(!sector_core_current$has_sector_core)) {
  cat("\nHospitals missing WRK and/or PAT (Current era):\n")
  sector_core_current %>%
    filter(!has_sector_core | missing_WRK | missing_PAT) %>%
    { cat(sprintf("  FAC %-6s  %-40s  %-22s  WRK=%s  PAT=%s\n",
                  .$fac, .$hospital_name, .$hospital_type_group,
                  ifelse(.$has_WRK, "Y", "N"),
                  ifelse(.$has_PAT, "Y", "N"))); . } %>%
    invisible()
} else {
  cat("\nAll Current era hospitals have both WRK and PAT. No extreme outliers.\n")
}
cat("\n")


# =============================================================================
# SECTION 7: Combine outlier flags and write Part 1 tables
# =============================================================================

outlier_full <- hosp_full %>%
  select(fac, hospital_name, hospital_type_group, plan_start_year) %>%
  left_join(missing_core_full %>% select(fac, n_missing_core, missing_core_str, is_missing_core),
            by = "fac") %>%
  left_join(peripheral_full %>% select(fac, n_peripheral, peripheral_str, has_peripheral),
            by = "fac") %>%
  left_join(sector_core_full %>% select(fac, has_WRK, has_PAT, has_sector_core),
            by = "fac") %>%
  mutate(
    outlier_score = n_missing_core + n_peripheral + (!has_sector_core) * 3L,
    scope = "Full cohort"
  )

outlier_current <- hosp_current %>%
  select(fac, hospital_name, hospital_type_group, plan_start_year) %>%
  left_join(missing_core_current %>% select(fac, n_missing_core, missing_core_str, is_missing_core),
            by = "fac") %>%
  left_join(peripheral_current %>% select(fac, n_peripheral, peripheral_str, has_peripheral),
            by = "fac") %>%
  left_join(sector_core_current %>% select(fac, has_WRK, has_PAT, has_sector_core),
            by = "fac") %>%
  mutate(
    outlier_score = n_missing_core + n_peripheral + (!has_sector_core) * 3L,
    scope = "Current era"
  )

outlier_all <- bind_rows(outlier_full, outlier_current)

write_csv(outlier_all,      "analysis/outputs/tables/04b_theme_outliers.csv")
write_csv(peripheral_all,   "analysis/outputs/tables/04b_peripheral_adopters.csv")
cat("Tables written: 04b_theme_outliers.csv, 04b_peripheral_adopters.csv\n\n")

# Console summary — top outliers in current era
cat("--- Top theme-level outliers (Current era, by outlier score) ---\n")
outlier_current %>%
  arrange(desc(outlier_score), hospital_type_group) %>%
  filter(outlier_score >= 2) %>%
  { cat(sprintf("  FAC %-6s  %-40s  %-22s  score=%d  missing=%s  peripheral=%s\n",
                .$fac, .$hospital_name, .$hospital_type_group, .$outlier_score,
                ifelse(is.na(.$missing_core_str) | .$missing_core_str == "",
                       "none", .$missing_core_str),
                ifelse(is.na(.$peripheral_str) | .$peripheral_str == "",
                       "none", .$peripheral_str))); . } %>%
  invisible()
cat("\n")


# =============================================================================
# SECTION 8: Part 1 Figure — Outlier map
#            Dot plot: each hospital is a dot; x = n peripheral themes,
#            y = n missing core themes; colour = type group; facet = scope
# =============================================================================

outlier_plot_data <- outlier_all %>%
  mutate(
    hospital_type_group = factor(hospital_type_group, levels = TYPE_LEVELS),
    scope = factor(scope, levels = c("Full cohort", "Current era")),
    # jitter slightly on integer axes; fixed seed for reproducibility
    n_missing_core = as.integer(n_missing_core),
    n_peripheral   = as.integer(n_peripheral)
  )

p_outlier <- ggplot(
  outlier_plot_data,
  aes(x = n_peripheral, y = n_missing_core,
      colour = hospital_type_group)
) +
  geom_jitter(width = 0.2, height = 0.2, alpha = 0.65, size = 2.2) +
  facet_wrap(~ scope, ncol = 2) +
  scale_colour_manual(
    values = c(
      "Teaching"          = "#08519C",
      "Community — Large" = "#2171B5",
      "Community — Small" = "#6BAED6",
      "Specialty"         = "#BDD7E7"
    ),
    name = "Hospital type"
  ) +
  scale_x_continuous(breaks = 0:6, limits = c(-0.5, NA)) +
  scale_y_continuous(breaks = 0:5, limits = c(-0.5, NA)) +
  labs(
    title    = "Theme-Level Outlier Map by Hospital",
    subtitle = paste0(
      "X axis: number of peripheral themes adopted (<", PERIPHERAL_THRESHOLD,
      "% prevalence in type group)\n",
      "Y axis: number of core themes missing from plan | ",
      "Each dot = one hospital"
    ),
    x       = "Number of peripheral themes adopted",
    y       = "Number of core themes missing",
    caption = paste0(
      "Source: HospitalIntelligenceR Phase 2 extraction + thematic classification.\n",
      "Core threshold: \u226550% of type-group hospitals. Peripheral threshold: <",
      PERIPHERAL_THRESHOLD, "%."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title    = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(colour = "grey40", size = 8),
    plot.caption  = element_text(colour = "grey50", size = 6.5),
    strip.text    = element_text(face = "bold", size = 10),
    panel.grid.minor = element_blank(),
    legend.position  = "right"
  )

ggsave(
  "analysis/outputs/figures/04b_outlier_map.png",
  plot   = p_outlier,
  width  = 9,
  height = 5,
  dpi    = 300
)
cat("Figure saved: 04b_outlier_map.png\n\n")


# =============================================================================
# PART 2: DIRECTION-LEVEL DISTINCTIVENESS (Claude API)
# =============================================================================

if (PART1_ONLY) {
  cat("PART1_ONLY = TRUE — skipping Part 2 API calls.\n")
  cat("Set PART1_ONLY <- FALSE and re-source to run direction-level analysis.\n")
} else {
  
  cat("=============================================================================\n")
  cat("PART 2: Direction-Level Distinctiveness (Claude API)\n")
  cat("=============================================================================\n\n")
  
  # Source claude_api.R (requires project root as working directory)
  if (!exists("call_claude")) {
    source("core/claude_api.R")
    if (!exists("log_info")) {
      log_info <- function(msg) cat("[INFO]", msg, "\n")
    }
  }
  
  # ---------------------------------------------------------------------------
  # SECTION 9: Build direction inventory by theme × type (Current era only)
  # ---------------------------------------------------------------------------
  
  # For each theme × type cell, collect all direction names with their
  # description and hospital context. Used as input to the API prompt.
  
  direction_inventory <- directions_current %>%
    filter(!is.na(direction_name)) %>%
    mutate(
      # Clean direction text for prompt inclusion
      direction_name_clean = str_squish(gsub("[\\x00-\\x1F\\x7F]", " ",
                                             direction_name, perl = TRUE)),
      direction_desc_clean = str_squish(gsub("[\\x00-\\x1F\\x7F]", " ",
                                             coalesce(direction_description, ""),
                                             perl = TRUE))
    ) %>%
    select(fac, hospital_type_group, primary_theme,
           direction_name_clean, direction_desc_clean) %>%
    left_join(spine_year %>% select(fac, hospital_name), by = "fac")
  
  # Summarise cell sizes
  cell_sizes <- direction_inventory %>%
    count(hospital_type_group, primary_theme, name = "n_directions") %>%
    arrange(hospital_type_group, primary_theme)
  
  cat("Direction counts by theme × type (Current era):\n")
  cat(sprintf("  Cells with >= %d directions (will receive API call): %d\n",
              MIN_DIRECTIONS_FOR_API,
              sum(cell_sizes$n_directions >= MIN_DIRECTIONS_FOR_API)))
  cat(sprintf("  Cells with < %d directions (skipped): %d\n\n",
              MIN_DIRECTIONS_FOR_API,
              sum(cell_sizes$n_directions < MIN_DIRECTIONS_FOR_API)))
  
  # Cells to process
  cells_to_process <- cell_sizes %>%
    filter(n_directions >= MIN_DIRECTIONS_FOR_API)
  
  # ---------------------------------------------------------------------------
  # SECTION 10: System prompt for distinctiveness analysis
  # ---------------------------------------------------------------------------
  
  DISTINCTIVENESS_SYSTEM_PROMPT <- paste0(
    "You are an expert analyst of Canadian public hospital strategic planning. ",
    "You will be given a list of strategic directions from hospitals in a specific ",
    "type group, all classified under the same strategic theme. Your task is to ",
    "identify which directions are generic and common versus which are unusual, ",
    "specific, or genuinely distinctive relative to their peers.\n\n",
    "A direction is GENERIC if: it uses standard sector language, could apply to ",
    "virtually any Ontario hospital, and does not commit to anything specific.\n\n",
    "A direction is DISTINCTIVE if: it uses specific language about a particular ",
    "population, geography, capability, approach, or commitment not commonly found ",
    "in peer hospitals' strategies; or it applies a theme in an unusual way for ",
    "this type of hospital.\n\n",
    "Respond ONLY with a JSON object in this exact structure — no preamble, no ",
    "markdown fences:\n",
    "{\n",
    "  \"generic_examples\": [\"direction name 1\", \"direction name 2\", \"direction name 3\"],\n",
    "  \"distinctive_directions\": [\n",
    "    {\n",
    "      \"fac\": \"<FAC code>\",\n",
    "      \"direction_name\": \"<exact direction name as provided>\",\n",
    "      \"reason\": \"<one sentence: what makes this unusual or specific>\"\n",
    "    }\n",
    "  ],\n",
    "  \"analyst_note\": \"<optional: one sentence observation about this theme × type cell, or null>\"\n",
    "}"
  )
  
  # ---------------------------------------------------------------------------
  # SECTION 11: API call loop
  # ---------------------------------------------------------------------------
  
  api_results <- vector("list", nrow(cells_to_process))
  api_log     <- vector("list", nrow(cells_to_process))
  total_cost  <- 0
  
  for (i in seq_len(nrow(cells_to_process))) {
    type_grp <- as.character(cells_to_process$hospital_type_group[i])
    theme    <- cells_to_process$primary_theme[i]
    n_dirs   <- cells_to_process$n_directions[i]
    
    cat(sprintf("[%d/%d] %s × %s (%d directions)... ",
                i, nrow(cells_to_process), type_grp, theme, n_dirs))
    
    # Build direction list for this cell
    cell_directions <- direction_inventory %>%
      filter(hospital_type_group == type_grp, primary_theme == theme) %>%
      arrange(fac, direction_name_clean)
    
    # Format as numbered list for prompt
    dir_lines <- cell_directions %>%
      mutate(
        line = sprintf("%s (%s): %s%s", fac, hospital_name, direction_name_clean,
                       ifelse(nchar(direction_desc_clean) > 0,
                              paste0(" | ", str_trunc(direction_desc_clean, 120)),
                              ""))
      ) %>%
      pull(line)
    
    user_message <- paste0(
      "Hospital type: ", type_grp, "\n",
      "Theme: ", theme, " — ", THEME_LABELS[theme], "\n",
      "Number of directions: ", n_dirs, "\n\n",
      "DIRECTIONS:\n",
      paste(seq_along(dir_lines), dir_lines, sep = ". ", collapse = "\n")
    )
    
    result <- call_claude(
      user_message  = user_message,
      system_prompt = DISTINCTIVENESS_SYSTEM_PROMPT,
      model         = API_MODEL,
      max_tokens    = 1000L,
      temperature   = 0,
      role          = "04b_distinctiveness",
      fac           = paste0(type_grp, "_", theme)
    )
    
    if (!is.null(result$error)) {
      cat(sprintf("ERROR: %s\n", result$error))
      api_results[[i]] <- list(
        hospital_type_group = type_grp,
        theme               = theme,
        n_directions        = n_dirs,
        status              = "error",
        error_msg           = result$error
      )
    } else {
      # Strip any markdown fences (defensive)
      raw <- gsub("```json|```", "", result$response_text, fixed = FALSE)
      raw <- trimws(raw)
      
      parsed <- tryCatch(
        fromJSON(raw, simplifyVector = FALSE),
        error = function(e) {
          cat(sprintf("JSON PARSE ERROR: %s\n", conditionMessage(e)))
          NULL
        }
      )
      
      if (is.null(parsed)) {
        api_results[[i]] <- list(
          hospital_type_group = type_grp,
          theme               = theme,
          n_directions        = n_dirs,
          status              = "parse_error"
        )
      } else {
        cat(sprintf("OK — %d distinctive, cost $%.4f\n",
                    length(parsed$distinctive_directions %||% list()),
                    result$cost %||% 0))
        
        api_results[[i]] <- list(
          hospital_type_group  = type_grp,
          theme                = theme,
          n_directions         = n_dirs,
          status               = "ok",
          generic_examples     = parsed$generic_examples %||% list(),
          distinctive          = parsed$distinctive_directions %||% list(),
          analyst_note         = parsed$analyst_note %||% NA_character_,
          input_tokens         = result$input_tokens,
          output_tokens        = result$output_tokens,
          cost                 = result$cost %||% 0
        )
        
        total_cost <- total_cost + (result$cost %||% 0)
      }
    }
    
    # Small pause between calls — be a good API citizen
    if (i < nrow(cells_to_process)) Sys.sleep(0.5)
  }
  
  cat(sprintf("\nPart 2 complete. Total API cost: $%.4f USD\n\n", total_cost))
  
  # ---------------------------------------------------------------------------
  # SECTION 12: Flatten API results to output table
  # ---------------------------------------------------------------------------
  
  # Build distinctive directions table
  distinctive_rows <- bind_rows(lapply(api_results, function(r) {
    if (r$status != "ok" || length(r$distinctive) == 0) return(NULL)
    bind_rows(lapply(r$distinctive, function(d) {
      tibble(
        hospital_type_group = r$hospital_type_group,
        theme               = r$theme,
        theme_label         = THEME_LABELS[r$theme],
        fac = gsub("^FAC ", "", as.character(d$fac %||% NA_character_)),
        direction_name      = as.character(d$direction_name %||% NA_character_),
        reason              = as.character(d$reason %||% NA_character_),
        analyst_note        = as.character(r$analyst_note %||% NA_character_)
      )
    }))
  }))
  
  # Join hospital name
  if (!is.null(distinctive_rows) && nrow(distinctive_rows) > 0) {
    # Join hospital_name from spine — do this before any select() call
    hosp_names <- spine_year %>% select(fac, hospital_name)
    distinctive_rows <- distinctive_rows %>%
      left_join(hosp_names, by = "fac")
    # Now safe to select — hospital_name is guaranteed present
    keep_cols <- intersect(
      c("fac", "hospital_name", "hospital_type_group", "theme", "theme_label",
        "direction_name", "reason", "analyst_note"),
      names(distinctive_rows)
    )
    distinctive_rows <- distinctive_rows %>%
      select(all_of(keep_cols)) %>%
      arrange(hospital_type_group, theme, fac)
  } else {
    distinctive_rows <- tibble(
      fac = character(), hospital_name = character(),
      hospital_type_group = character(), theme = character(),
      theme_label = character(), direction_name = character(),
      reason = character(), analyst_note = character()
    )
  }
  
  write_csv(distinctive_rows,
            "analysis/outputs/tables/04b_distinctive_directions.csv")
  cat(sprintf("Table written: 04b_distinctive_directions.csv (%d distinctive directions)\n\n",
              nrow(distinctive_rows)))
  
  # Build API log
  api_log_df <- bind_rows(lapply(api_results, function(r) {
    tibble(
      hospital_type_group = r$hospital_type_group %||% NA_character_,
      theme               = r$theme %||% NA_character_,
      n_directions        = r$n_directions %||% NA_integer_,
      status              = r$status %||% NA_character_,
      n_distinctive       = length(r$distinctive %||% list()),
      input_tokens        = r$input_tokens %||% NA_integer_,
      output_tokens       = r$output_tokens %||% NA_integer_,
      cost_usd            = r$cost %||% NA_real_
    )
  }))
  
  write_csv(api_log_df, "logs/04b_api_log.csv")
  cat("Log written: logs/04b_api_log.csv\n\n")
  
  # ---------------------------------------------------------------------------
  # SECTION 13: Console summary — distinctive directions
  # ---------------------------------------------------------------------------
  
  cat("=== DISTINCTIVE DIRECTIONS SUMMARY ===\n\n")
  
  if (nrow(distinctive_rows) > 0) {
    # By theme
    cat("Distinctive directions by theme:\n")
    distinctive_rows %>%
      count(theme, theme_label, name = "n_distinctive") %>%
      arrange(desc(n_distinctive)) %>%
      { cat(sprintf("  %s: %d\n", .$theme, .$n_distinctive)); . } %>%
      invisible()
    cat("\n")
    
    # By type group
    cat("Distinctive directions by hospital type:\n")
    distinctive_rows %>%
      count(hospital_type_group, name = "n_distinctive") %>%
      arrange(desc(n_distinctive)) %>%
      { cat(sprintf("  %-22s: %d\n", .$hospital_type_group, .$n_distinctive)); . } %>%
      invisible()
    cat("\n")
    
    # Full listing
    cat("Full listing of distinctive directions:\n")
    distinctive_rows %>%
      arrange(hospital_type_group, theme, fac) %>%
      { for (i in seq_len(nrow(.))) {
        cat(sprintf(
          "  [%s | %s | FAC %s | %s]\n  %s\n  Reason: %s\n\n",
          .$hospital_type_group[i], .$theme[i], .$fac[i],
          .$hospital_name[i], .$direction_name[i], .$reason[i]
        ))
      }; . } %>%
      invisible()
  } else {
    cat("No distinctive directions identified.\n\n")
  }
  
}  # end PART1_ONLY branch


# =============================================================================
# SECTION 14: Final summary
# =============================================================================

cat("=============================================================================\n")
cat("04b Complete\n")
cat("=============================================================================\n")
cat("Outputs:\n")
cat("  analysis/outputs/tables/04b_theme_outliers.csv\n")
cat("  analysis/outputs/tables/04b_peripheral_adopters.csv\n")
if (!PART1_ONLY) {
  cat("  analysis/outputs/tables/04b_distinctive_directions.csv\n")
  cat("  logs/04b_api_log.csv\n")
}
cat("  analysis/outputs/figures/04b_outlier_map.png\n")
cat("\nReview console output and tables before writing narrative.\n")