# load_extraction_design.R
# Purpose: Read extract_minutes_design.xlsx and derive master keyword lists for
#          use by extract_minutes.R and find_partners.R.
#
# Exports:
#   design_fac      data frame — one row per FAC entry in FAC_Design sheet
#   begin_keywords  character vector — union of all Beginning Keywords across all rows
#   end_keywords    character vector — union of all Ending Keywords across all rows
#
# Usage:
#   source("E:/HospitalIntelligenceR/roles/minutes/scripts/load_extraction_design.R")
#
# Note: Beginning Structure signals are universal constants — they are not derived
#       dynamically from the design file. They are hardcoded in extract_minutes.R
#       as detection logic, not vocabulary.
#
# File: E:/HospitalIntelligenceR/roles/minutes/scripts/load_extraction_design.R

library(readxl)
library(dplyr)
library(stringr)

DESIGN_FILE <- "E:/HospitalIntelligenceR/roles/minutes/scripts/extract_minutes_design.xlsx"

# ── Helper: split a semicolon-delimited column into a clean character vector ───
split_keywords <- function(x) {
  x |>
    paste(collapse = ";") |>
    str_split(";") |>
    unlist() |>
    str_trim() |>
    str_squish() |>
    (\(v) v[nchar(v) > 0])() |>
    unique() |>
    sort()
}

# ── Load FAC_Design sheet ──────────────────────────────────────────────────────
design_fac <- read_excel(
  DESIGN_FILE,
  sheet     = "FAC_Design",
  col_types = "text"
) |>
  rename(
    fac                  = FAC,
    hospital_name        = `Hospital Name`,
    beginning_structure  = `Beginning Structure`,
    beginning_keywords   = `Beginning Keywords`,
    ending_keywords      = `Ending Keywords`,
    notes                = Notes
  ) |>
  mutate(fac = as.character(fac))

# ── Derive master keyword lists ────────────────────────────────────────────────
begin_keywords <- split_keywords(design_fac$beginning_keywords)
end_keywords   <- split_keywords(design_fac$ending_keywords)

# ── Report on load ─────────────────────────────────────────────────────────────
message(sprintf(
  "load_extraction_design.R: %d FAC rows loaded | %d beginning keywords | %d ending keywords",
  nrow(design_fac),
  length(begin_keywords),
  length(end_keywords)
))
