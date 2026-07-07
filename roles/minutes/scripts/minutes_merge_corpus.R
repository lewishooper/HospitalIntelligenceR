# minutes_merge_corpus.R
# Purpose: Merge the three completed SomethingElse-derived extraction tiers
# (prescreen, summary, remainder) into one analysis-ready dataframe of
# confirmed board minutes / summary minutes content.
#
# SCOPE NOTE: this is NOT minutes_analytical_master.rds. That name is
# reserved for the full analytical build, which requires four mandatory
# pre-steps (Stage 2 completion — done as of this merge; LH prior corpus
# decision — pending; internal date extraction — pending; master build
# itself). This script also does not include the ~1,879 MinutesOnly
# documents (Stage 1 classification) — those have never been through an
# extraction pass; minutes_extract_minutesonly.R (built same session) covers
# that separately. This merge covers only the three tiers derived from the
# SomethingElse bucket.
#
# Tier values:
#   "prescreen" — minutes_extract_prescreen_results.rds (35 agenda_prescreen
#                 documents; minutes embedded after an agenda/other content)
#   "summary"   — minutes_extract_summary_results.rds (905, 967, 644, 736,
#                 858; Board Highlights / meeting-summary format, no full
#                 attendee name list, no close-detection gate by design)
#   "remainder" — minutes_extract_remainder_results.rds (SomethingElse
#                 remainder batch after excluding the above two tiers plus
#                 FAC 941/975; only Quinte/957 confirmed corpus_include)
#
# FAC 644 (Cornwall Hotel Dieu) excluded entirely — confirmed empirically
# (42/42 identical filenames against FAC 967 in llm_run1_results.csv) to be
# a full duplicate of FAC 967 (Cornwall Community), catalogued under two FAC
# codes. Dropped here rather than flagged, since minutes_extract_summary.R
# computes is_duplicate_of per-row but does not persist a saved
# analytical_include column — filtering at merge time avoids depending on
# that unpersisted flag.
#
# Only corpus_include == TRUE rows are carried into the merged dataframe —
# this is meant to be the analysis-ready corpus, not the full audit trail of
# every document considered. The three source .rds files remain the
# authoritative record of qa_flag / no_start_detected / no_close_detected
# documents for anyone who needs the full picture later.
#
# Run from: E:/HospitalIntelligenceR (project root)

rm(list = ls())

library(dplyr)

source("core/logger.R")
init_logger(role = "minutes")

PRESCREEN_FILE <- "roles/minutes/outputs/minutes_extract_prescreen_results.rds"
SUMMARY_FILE   <- "roles/minutes/outputs/minutes_extract_summary_results.rds"
REMAINDER_FILE <- "roles/minutes/outputs/minutes_extract_remainder_results.rds"
OUTPUT_FILE    <- "roles/minutes/outputs/minutes_merged_corpus.rds"

# Common columns across all three source files. Source-specific diagnostic
# columns (attendance_nearby, any_header/any_names/any_call_to_order/
# any_close, is_duplicate_of, is_annual_meeting) are intentionally dropped —
# they're extraction-diagnostic, not analytical content.
COMMON_COLS <- c("fac", "hospital_name", "filename", "local_path",
                 "minutes_page_start", "minutes_page_end", "n_pages_extracted",
                 "full_text", "doc_class", "corpus_include", "qa_flag")

load_tier <- function(path, tier_name) {
  if (!file.exists(path)) {
    log_warning(sprintf("Source file not found for tier '%s': %s — this tier will be EMPTY in the merge",
                        tier_name, path))
    return(data.frame())
  }
  df <- readRDS(path) |>
    mutate(fac = as.character(fac)) |>
    filter(corpus_include == TRUE)
  
  missing_cols <- setdiff(COMMON_COLS, names(df))
  if (length(missing_cols) > 0) {
    log_warning(sprintf("Tier '%s' missing expected column(s): %s — filling with NA",
                        tier_name, paste(missing_cols, collapse = ", ")))
    for (col in missing_cols) df[[col]] <- NA
  }
  
  df <- df |>
    select(all_of(COMMON_COLS)) |>
    mutate(tier = tier_name)
  
  log_info(sprintf("Tier '%s': %d corpus_include documents loaded", tier_name, nrow(df)))
  df
}

prescreen <- load_tier(PRESCREEN_FILE, "prescreen")
summary_t <- load_tier(SUMMARY_FILE, "summary") |>
  filter(fac != "644")   # confirmed full duplicate of 967 — dropped, not flagged
remainder <- load_tier(REMAINDER_FILE, "remainder")

log_info(sprintf("Summary tier after dropping FAC 644 duplicate rows: %d documents", nrow(summary_t)))

merged <- bind_rows(prescreen, summary_t, remainder)

# Sanity check — no fac+filename should appear under more than one tier.
dupes <- merged |> count(fac, filename) |> filter(n > 1)
if (nrow(dupes) > 0) {
  log_warning(sprintf("%d fac+filename pairs appear in more than one tier — check for overlap between source files before trusting this merge",
                      nrow(dupes)))
  print(merged |> semi_join(dupes, by = c("fac", "filename")) |> select(fac, filename, tier))
} else {
  log_info("No fac+filename overlap across tiers — merge is clean.")
}

saveRDS(merged, OUTPUT_FILE)
log_info(sprintf("Merged corpus written: %d documents to %s", nrow(merged), OUTPUT_FILE))

cat("\n══════ MERGED CORPUS — SUMMARY ══════\n")
cat(sprintf("Total documents: %d\n\n", nrow(merged)))
print(merged |> count(tier, hospital_name) |> arrange(tier, hospital_name))
cat(sprintf("\nTotal hospitals represented: %d\n", n_distinct(merged$fac)))
cat(sprintf("Documents by tier:\n"))
print(merged |> count(tier))