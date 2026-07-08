# minutes_minutesonly_cleanup.R
# Purpose: Apply confirmed manual-review exclusions to
# minutes_extract_minutesonly_results.rds before folding it into the merged
# corpus as a fourth tier. Built July 7/8, 2026 following manual review of
# the 62 "corpus_include but no motion language detected" documents flagged
# during MinutesOnly validation.
#
# EXCLUSIONS APPLIED:
#
# 1. FAC 644 (Cornwall Hotel Dieu) — WHOLE HOSPITAL, all documents.
#    Confirmed duplicate of FAC 967 (Cornwall Community), same as the
#    exclusion already applied in minutes_merge_corpus.R for the
#    SomethingElse-derived summary tier. Applied here too since FAC 644
#    documents also appear independently in the MinutesOnly bucket.
#
# 2. FAC 978 (Kingston Health Sciences) — WHOLE HOSPITAL, all documents.
#    Manually confirmed (5 documents read, consistent pattern across the
#    entire FAC 978 folder) that Kingston conducts board business primarily
#    in camera. Filed minutes contain only a redacted "Report on In-Camera
#    Matters" — a list of decisions the Board approved, with no discussion
#    or narrative content ("the Board approved the Fiscal 2021 Budget," etc,
#    with no substance behind the approval). This is a structural governance
#    pattern, not a detection or OCR problem — no fix to the extraction
#    logic would produce discussion content that was never filed publicly.
#    Excluded from the analytical corpus entirely. Logged as a possible
#    future follow-up (direct request to Kingston for full/unredacted
#    minutes, or treatment as a separate governance case study) — NOT
#    something to revisit via script changes.
#
# 3. Specific document-level exclusions — individual non-minutes documents
#    manually confirmed during the same review, not representative of their
#    hospital's overall corpus:
#      - FAC 661 (Cambridge Memorial): one agenda-with-reports/no-minutes
#        document, one organizational-chart-only document
#      - FAC 701 (Richmond Hill Mackenzie): one community-report document
#        (filename used the "_yearonly" placeholder-dating pattern also
#        seen on FAC 939's non-minutes documents — same upstream filename-
#        dating unreliability already flagged as a carry-forward item)
#      - FAC 953 (Sunnybrook): two documents, one organizational-structure
#        chart, one medical-structure chart
#
# NOT excluded, confirmed genuine during the same review:
#   - FAC 858 (Michael Garron): summary-tier format, no motion language by
#     design — already known
#   - FAC 888 (New Liskeard Temiskaming): uses a formal structured
#     Mover/Seconder/Decision Date/Outcome motion format rather than
#     narrative "moved by... seconded by..." prose — detect_motions()
#     simply doesn't recognize this format; the documents themselves are
#     genuine. NOTE for a future motion-extraction workstream: this
#     structured field format (whitespace-heavy, field-label-based) will
#     need its own extraction logic distinct from the narrative-prose
#     pattern used elsewhere.
#   - FAC 967 (Cornwall Community, canonical): genuine Board Highlights,
#     no motion language by design — already known
#   - FAC 736 (Newmarket Southlake): a second, independent occurrence of
#     the confirmed summary-tier format, this time surfacing via the
#     MinutesOnly bucket rather than SomethingElse
#   - FAC 936 (London Health Sciences): confirmed genuine board minutes
#
# Run from: E:/HospitalIntelligenceR (project root)

rm(list = ls())
library(dplyr)

source("core/logger.R")
init_logger(role = "minutes")

INPUT_FILE  <- "roles/minutes/outputs/minutes_extract_minutesonly_results.rds"
OUTPUT_FILE <- "roles/minutes/outputs/minutes_extract_minutesonly_clean.rds"

# Whole-hospital exclusions
EXCLUDE_FACS_WHOLE <- c("644", "978")

# Document-level exclusions — fac + filename pairs, manually confirmed
EXCLUDE_DOCS <- tibble::tribble(
  ~fac, ~filename,
  "661", "2025-06-25_board_minutes_v2.pdf",  # agenda with reports, no minutes
  "661", "2025-09-01_board_minutes_v2.pdf",  # organizational chart
  "701", "2024-01-01_board_minutes_yearonly.pdf",  # community report
  "953", "2026-05-01_board_minutes.pdf",     # medical structure chart
  "953", "2026-05-01_board_minutes_v2.pdf"   # organizational structure chart
)

results <- readRDS(INPUT_FILE) |> mutate(fac = as.character(fac))
n_before <- nrow(results)
log_info(sprintf("MinutesOnly documents before cleanup: %d", n_before))

# Apply whole-hospital exclusions
whole_hospital_excluded <- results |> filter(fac %in% EXCLUDE_FACS_WHOLE)
log_info(sprintf("Excluding %d documents from whole-hospital exclusions (FAC %s): %d documents",
                 nrow(whole_hospital_excluded), paste(EXCLUDE_FACS_WHOLE, collapse = ", "),
                 nrow(whole_hospital_excluded)))
print(whole_hospital_excluded |> count(fac, hospital_name))

results <- results |> filter(!fac %in% EXCLUDE_FACS_WHOLE)

# Apply document-level exclusions
doc_level_excluded <- results |> semi_join(EXCLUDE_DOCS, by = c("fac", "filename"))
log_info(sprintf("Excluding %d specific documents (individual non-minutes content)",
                 nrow(doc_level_excluded)))
print(doc_level_excluded |> select(fac, hospital_name, filename))

results <- results |> anti_join(EXCLUDE_DOCS, by = c("fac", "filename"))

n_after <- nrow(results)
log_info(sprintf("MinutesOnly documents after cleanup: %d (removed %d)", n_after, n_before - n_after))

saveRDS(results, OUTPUT_FILE)
log_info(sprintf("Clean MinutesOnly file written: %s", OUTPUT_FILE))

cat("\n══════ MINUTESONLY CLEANUP — SUMMARY ══════\n")
cat(sprintf("Before: %d\nAfter:  %d\nRemoved: %d (%.1f%%)\n",
            n_before, n_after, n_before - n_after, 100 * (n_before - n_after) / n_before))