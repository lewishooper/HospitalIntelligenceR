library(tidyverse)

HIT_MASTER <- "roles/hit/outputs/hit_master.csv"

hit <- read_csv(HIT_MASTER,
                col_types = cols(fac = col_character(), .default = col_guess()),
                show_col_types = FALSE)

all_years <- sort(unique(hit$fiscal_year))
first_yr  <- min(all_years)
last_yr   <- max(all_years)

message(sprintf("Window: %s to %s  |  %d years", first_yr, last_yr, length(all_years)))
message(sprintf("All years: %s", paste(all_years, collapse = " | ")))

# One row per FAC — presence by year using ind01 as proxy
coverage <- hit %>%
  filter(indicator_code == "ind01") %>%
  distinct(fac, fiscal_year) %>%
  mutate(present = 1) %>%
  pivot_wider(names_from = fiscal_year, values_from = present, values_fill = 0) %>%
  rowwise() %>%
  mutate(
    n_years_present = sum(c_across(-fac)),
    first_year      = all_years[which(c_across(-fac) == 1)[1]],
    last_year       = all_years[rev(which(c_across(-fac) == 1))[1]]
  ) %>%
  ungroup() %>%
  mutate(
    stopped_early = last_year  != last_yr,
    started_late  = first_year != first_yr
  ) %>%
  arrange(stopped_early, started_late, as.integer(fac))

message("\n=== FACs that STOPPED REPORTING before ", last_yr, " ===")
coverage %>%
  filter(stopped_early) %>%
  select(fac, first_year, last_year, n_years_present) %>%
  print(n = 50)

message("\n=== FACs that STARTED LATE (possible new entities / post-merger) ===")
coverage %>%
  filter(started_late & !stopped_early) %>%
  select(fac, first_year, last_year, n_years_present) %>%
  print(n = 50)

message("\n=== Year coverage distribution (all FACs) ===")
print(table(coverage$n_years_present))