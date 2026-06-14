# draw_t1s1_sample.R
# Purpose: Draw a stratified sample of PDFs from minutes_index.csv for
#          the T1-S1 hand-labelling session (Tier 1, Session 1).
#
# The sample is used to:
#   (1) calibrate the structural classifier in minutes_classify.R
#   (2) establish decision rules for ambiguous document types
#   (3) confirm regex patterns for headers, attendance, motions
#   (4) establish consent agenda detection criteria
#
# Output: t1s1_sample.xlsx  — one row per sampled PDF with full path and
#         strata labels, ready for annotation in Excel.
#
# Run from: E:/HospitalIntelligenceR  (project root)
# Input:    roles/minutes/outputs/minutes_index.csv
#           registry/hospital_registry.yaml
# Output:   roles/minutes/outputs/t1s1_sample.xlsx

rm(list = ls())

library(dplyr)
library(stringr)
library(readr)
library(yaml)
library(openxlsx)

set.seed(2026)  # reproducible draw

# ── Paths ──────────────────────────────────────────────────────────────────────
INDEX_FILE   <- "roles/minutes/outputs/minutes_index.csv"
REGISTRY     <- "registry/hospital_registry.yaml"
EXTRACT_DIR  <- "roles/minutes/outputs/extracted"
OUTPUT_FILE  <- "roles/minutes/outputs/t1s1_sample.xlsx"
SAMPLE_N     <- 60L

# ── 1. Load index ──────────────────────────────────────────────────────────────
cat("Loading minutes_index.csv...\n")
idx <- read.csv(INDEX_FILE, stringsAsFactors = FALSE) |>
  mutate(fac = as.character(fac))

cat(sprintf("  Index rows: %d across %d hospitals\n",
            nrow(idx), n_distinct(idx$fac)))

# ── 2. Load registry — extract hospital_type per FAC ─────────────────────────
cat("Loading registry...\n")
reg_raw <- yaml::read_yaml(REGISTRY)

type_lookup <- bind_rows(lapply(reg_raw$hospitals, function(h) {
  data.frame(
    fac            = as.character(h$FAC),
    hospital_type  = as.character(h$hospital_type %||% NA_character_),
    stringsAsFactors = FALSE
  )
}))

# Map MOH hospital_type labels → four analytical type groups
type_lookup <- type_lookup |>
  mutate(
    type_group = case_when(
      str_detect(str_to_lower(hospital_type), "teaching")           ~ "Teaching",
      str_detect(str_to_lower(hospital_type), "large")              ~ "Community Large",
      str_detect(str_to_lower(hospital_type), "small")              ~ "Community Small",
      str_detect(str_to_lower(hospital_type), "specialty|special")  ~ "Specialty",
      TRUE                                                           ~ "Other"
    )
  )

cat("  Type group distribution in registry:\n")
print(table(type_lookup$type_group))

# Join type group onto index
idx <- idx |>
  left_join(type_lookup |> select(fac, type_group), by = "fac")

# ── 3. Classify each row into a sampling stratum ───────────────────────────────
# Strata are defined by filename signals — this is the best proxy available
# before any PDFs are opened. The classifier will use actual document content;
# the sample needs to cover the *likely* range of document types.
#
# Stratum definitions:
#   "likely_minutes"   — filename contains "minute" → high confidence minutes
#   "thin_candidate"   — file_size_kb < 100 → could be agenda, special meeting,
#                         or genuine one-page summary; important edge case
#   "large_package"    — file_size_kb > 1000 → likely bundled package (minutes +
#                         reports + financials); key mixed-doc scenario
#   "yearonly_date"    — filename ends in _yearonly.pdf → date ambiguous; may
#                         signal agenda or loosely named file
#   "noise_signal"     — filename contains agenda|report|presentation|financial|
#                         bylaw|policy → likely non-minutes; need these in sample
#                         to establish exclusion patterns
#   "neutral"          — everything else; the bulk of the archive

idx <- idx |>
  mutate(
    fname_lower = str_to_lower(filename),
    stratum = case_when(
      str_detect(fname_lower, "agenda|report|presentation|financial|bylaw|policy|budget|annual") ~ "noise_signal",
      str_detect(fname_lower, "_yearonly\\.pdf$")                                                ~ "yearonly_date",
      file_size_kb < 100 & !is.na(file_size_kb)                                                 ~ "thin_candidate",
      file_size_kb > 1000 & !is.na(file_size_kb)                                                ~ "large_package",
      str_detect(fname_lower, "minute")                                                          ~ "likely_minutes",
      TRUE                                                                                        ~ "neutral"
    )
  )

cat("\nStratum distribution across full index:\n")
print(table(idx$stratum))

# ── 4. Stratified draw ─────────────────────────────────────────────────────────
# Target allocation across strata:
#   likely_minutes   20  — confirm the structural pattern across diverse hospitals
#   neutral          15  — the unclassified majority; need to know what they are
#   thin_candidate    8  — edge case: special meetings, agendas, summaries
#   large_package     7  — bundled packages; key mixed-doc scenario
#   noise_signal      6  — establish exclusion patterns
#   yearonly_date     4  — date ambiguity cases
#
# Within each stratum, oversample across type groups where possible.
# Total = 60.

strata_targets <- c(
  likely_minutes  = 20L,
  neutral         = 15L,
  thin_candidate  =  8L,
  large_package   =  7L,
  noise_signal    =  6L,
  yearonly_date   =  4L
)
draw_stratum <- function(data, stratum_name, n_draw) {
  pool <- data |> filter(stratum == stratum_name)
  if (nrow(pool) == 0) {
    cat(sprintf("  WARNING: stratum '%s' has no rows — skipping\n", stratum_name))
    return(data.frame())
  }
  if (n_draw >= nrow(pool)) {
    cat(sprintf("  Stratum '%s': pool smaller than target (%d < %d) — taking all\n",
                stratum_name, nrow(pool), n_draw))
    return(pool |> mutate(stratum_draw = stratum_name))
  }
  groups <- pool |>
    count(type_group) |>
    mutate(
      raw_alloc = n_draw * n / nrow(pool),
      alloc     = pmax(1L, round(raw_alloc))
    )
  overshoot <- sum(groups$alloc) - n_draw
  if (overshoot > 0) {
    order_idx <- order(-groups$alloc)
    for (i in seq_len(overshoot)) {
      groups$alloc[order_idx[i]] <- groups$alloc[order_idx[i]] - 1L
    }
  }
  rows <- bind_rows(lapply(seq_len(nrow(groups)), function(i) {
    g         <- groups$type_group[i]
    n_g       <- groups$alloc[i]
    group_pool <- pool |> filter(type_group == g)
    if (nrow(group_pool) <= n_g) return(group_pool)
    group_pool[sample(nrow(group_pool), n_g), ]
  }))
  still_needed <- n_draw - nrow(rows)
  if (still_needed > 0) {
    remainder_pool <- pool |> anti_join(rows, by = c("fac", "filename"))
    if (nrow(remainder_pool) > 0) {
      extra <- remainder_pool[sample(nrow(remainder_pool),
                                     min(still_needed, nrow(remainder_pool))), ]
      rows  <- bind_rows(rows, extra)
    }
  }
  rows |> mutate(stratum_draw = stratum_name)
}

sample_list <- lapply(names(strata_targets), function(s) {
  cat(sprintf("\nDrawing stratum: %s (target n=%d)\n", s, strata_targets[s]))
  draw_stratum(idx, s, strata_targets[s])
})

sample_df <- bind_rows(sample_list) |>
  # Remove any accidental duplicates (same fac + filename)
  distinct(fac, filename, .keep_all = TRUE)

cat(sprintf("\nTotal sampled: %d rows\n", nrow(sample_df)))
cat("Type group distribution in sample:\n")
print(table(sample_df$type_group))
cat("\nStratum distribution in sample:\n")
print(table(sample_df$stratum_draw))

# ── 5. Build output — add local file path and annotation columns ───────────────
sample_out <- sample_df |>
  mutate(
    local_path = file.path(EXTRACT_DIR, folder_name, filename),
    file_exists = file.exists(local_path),
    # Annotation columns — to be filled during hand-labelling session
    doc_class         = NA_character_,  # minutes / agenda / mixed / report / other
    is_corpus_include = NA_character_,  # TRUE / FALSE
    has_header_block  = NA_character_,  # TRUE / FALSE
    has_attendance    = NA_character_,  # TRUE / FALSE
    has_motions       = NA_character_,  # TRUE / FALSE
    has_consent_agenda = NA_character_, # TRUE / FALSE
    meeting_type      = NA_character_,  # regular / special / annual / agm / unknown
    analyst_notes     = NA_character_
  ) |>
  select(
    fac, hospital_name, type_group, stratum_draw,
    filename, doc_date, file_size_kb,
    local_path, file_exists,
    doc_class, is_corpus_include,
    has_header_block, has_attendance, has_motions,
    has_consent_agenda, meeting_type, analyst_notes,
    source_url
  ) |>
  arrange(stratum_draw, type_group, fac)

# ── 6. Warn on missing files ───────────────────────────────────────────────────
missing_files <- sample_out |> filter(!file_exists)
if (nrow(missing_files) > 0) {
  cat(sprintf("\nWARNING: %d sampled files not found on disk:\n", nrow(missing_files)))
  print(missing_files |> select(fac, hospital_name, filename, local_path))
} else {
  cat("\nAll sampled files confirmed on disk.\n")
}

# ── 7. Write to Excel ──────────────────────────────────────────────────────────
wb <- createWorkbook()
addWorksheet(wb, "sample")

# Header style
hs <- createStyle(fontColour = "#FFFFFF", fgFill = "#2C3E50",
                  halign = "LEFT", textDecoration = "bold", border = "Bottom")

writeData(wb, "sample", sample_out, headerStyle = hs)

# Column widths
setColWidths(wb, "sample", cols = 1:ncol(sample_out),
             widths = c(6, 28, 16, 16, 40, 12, 10, 70, 10,
                        12, 16, 14, 14, 12, 16, 14, 30, 50))

# Freeze panes
freezePane(wb, "sample", firstRow = TRUE)

# Alternate row shading
row_fill <- createStyle(fgFill = "#F2F2F2")
even_rows <- seq(3, nrow(sample_out) + 1, by = 2)
addStyle(wb, "sample", style = row_fill,
         rows = even_rows, cols = 1:ncol(sample_out), gridExpand = TRUE)

saveWorkbook(wb, OUTPUT_FILE, overwrite = TRUE)
cat(sprintf("\nSample written to: %s\n", OUTPUT_FILE))
cat(sprintf("Rows: %d | Columns: %d\n", nrow(sample_out), ncol(sample_out)))
cat("\nDone. Open t1s1_sample.xlsx and work through each PDF in the sample.\n")
cat("Fill in doc_class, is_corpus_include, structural flags, and analyst_notes for each row.\n")