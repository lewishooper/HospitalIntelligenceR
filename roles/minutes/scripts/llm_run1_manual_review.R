# llm_run1_manual_review.R
# Purpose: Export the three spot-check groups identified from the Section 4
#          summary of llm_run1_fulltext_scan.R for manual review:
#            1. summary_highlights with NO signal (confirm true-negative status)
#            2. report_to_board WITH signal (confirm motion-only hits aren't
#               embedded minutes)
#            3. agenda_other WITH signal (single-document check)
#
#          agenda_prescreen (all 35, 100% boundary signal) and the bulk
#          true-negatives (211 docs, zero signal) are NOT included here —
#          those dispositions are already settled by the Section 4 summary.
#
# Run from: E:/HospitalIntelligenceR  (project root)
# Input:    roles/minutes/outputs/llm_run1_fulltext_scan.csv
# Output:   roles/minutes/outputs/llm_run1_manual_review.csv
#
# NOTE ON COLUMNS: this script assumes scan_df / the scan CSV has the columns
# visible in the Section 4 console output (fac, hospital_name, filename,
# bucket, n_motion_hits, n_decision_hits, n_boundary_hits, has_motion_lang,
# has_decision_lang, has_boundary_signal) plus a local_path and some form of
# extracted text (text_preview or full text) column carried over from the
# OCR step. If the actual column names differ, adjust the `select()` calls
# in Section 2 accordingly — the filtering logic in Section 1 does not
# depend on exact column names beyond those listed above.

library(dplyr)
library(stringr)
source("core/logger.R")
init_logger(role = "minutes")

SCAN_FILE   <- "roles/minutes/outputs/llm_run1_fulltext_scan.csv"
REVIEW_FILE <- "roles/minutes/outputs/llm_run1_manual_review.csv"

scan_df <- read.csv(SCAN_FILE, stringsAsFactors = FALSE)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1 — Filter the three review groups
# ══════════════════════════════════════════════════════════════════════════════

group_summary_no_signal <- scan_df |>
  filter(bucket == "summary_highlights",
         !has_motion_lang, !has_decision_lang, !has_boundary_signal) |>
  mutate(review_reason = "summary_highlights, no signal — confirm true negative")

group_report_signal <- scan_df |>
  filter(bucket == "report_to_board",
         has_motion_lang | has_decision_lang | has_boundary_signal) |>
  mutate(review_reason = "report_to_board, motion/decision hit — check for embedded minutes")

group_agenda_other_signal <- scan_df |>
  filter(bucket == "agenda_other",
         has_motion_lang | has_decision_lang | has_boundary_signal) |>
  mutate(review_reason = "agenda_other, signal present — single doc check")

review_df <- bind_rows(
  group_summary_no_signal,
  group_report_signal,
  group_agenda_other_signal
)

log_info(sprintf("Manual review set: %d documents (%d summary_highlights, %d report_to_board, %d agenda_other)",
                  nrow(review_df),
                  nrow(group_summary_no_signal),
                  nrow(group_report_signal),
                  nrow(group_agenda_other_signal)))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2 — Build review export
# ══════════════════════════════════════════════════════════════════════════════
# Adjust the column list below to match whatever columns actually exist in
# llm_run1_fulltext_scan.csv. text_preview (or equivalent) is included so
# review can happen from the CSV alone without reopening each PDF, but a
# manual_decision column is added blank for you to fill in during review.

review_export <- review_df |>
  select(
    fac, hospital_name, filename, bucket, review_reason,
    n_motion_hits, n_decision_hits, n_boundary_hits,
    any_of(c("local_path", "text_preview", "doc_date"))
  ) |>
  mutate(
    manual_decision = "",   # fill in: MinutesOnly / MinutesSummary / Excluded
    reviewer_notes   = ""
  ) |>
  arrange(bucket, fac)

write.csv(review_export, REVIEW_FILE, row.names = FALSE)
log_info(sprintf("Manual review file written to %s (%d rows)", REVIEW_FILE, nrow(review_export)))

cat("\n══════════════════════════════════════════════════════\n")
cat("  MANUAL REVIEW EXPORT SUMMARY\n")
cat("══════════════════════════════════════════════════════\n\n")
print(review_export |> count(bucket))
cat("\nReview file:", REVIEW_FILE, "\n")
cat("Fill in manual_decision for each row, then paste the completed\n")
cat("CSV summary back to Claude to finalize tier dispositions.\n")
