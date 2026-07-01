# llm_run1_fulltext_scan.R
# Purpose: Stage 2 prep — resolve open questions on the SomethingElse (471 doc)
#          population before boundary-detection design.
#
#   (1) Flag the Cornwall FAC 644/967 partner-duplicate pair so it isn't
#       double-counted in any of the buckets below.
#   (2) Bucket the SomethingElse population by reasoning/preview text
#       (same heuristic used in chat-side exploration of llm_run1_results.csv).
#   (3) Re-OCR full text (not just the 200-char preview) for two target sets:
#         - summary_highlights  (Board Highlights / Meeting Summary docs)
#         - other_uncertain + report_to_board (candidates for embedded-minutes
#           content per Point 1 discussion)
#   (4) Scan full text for motion language ("moved/seconded/carried/motion")
#       AND declarative decision language ("the Board approved/endorsed/
#       agreed/directed"), since summary documents may record decisions without
#       formal motion wording.
#
# This re-OCRs only the ~370 target documents (summary_highlights +
# other_uncertain + report_to_board), not the full corpus — should take
# roughly (370 * mean_ocr_time_s) seconds; check the mean from
# llm_run1_results.csv$ocr_time_s before running if you want an estimate.
#
# Run from: E:/HospitalIntelligenceR  (project root)
# Input:    roles/minutes/outputs/llm_run1_results.csv
# Output:   roles/minutes/outputs/llm_run1_fulltext_scan.csv

rm(list = ls())

library(dplyr)
library(stringr)
library(tesseract)
library(pdftools)

source("core/logger.R")
init_logger(role = "minutes")

RESULTS_FILE <- "roles/minutes/outputs/llm_run1_results.csv"
OUTPUT_FILE  <- "roles/minutes/outputs/llm_run1_fulltext_scan.csv"
OCR_DPI      <- 300L

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1 — Load and bucket the SomethingElse population
# ══════════════════════════════════════════════════════════════════════════════

results <- read.csv(RESULTS_FILE, stringsAsFactors = FALSE) |>
  mutate(fac = as.character(fac))

se <- results |> filter(classification == "SomethingElse")
log_info(sprintf("SomethingElse population: %d documents", nrow(se)))

# ── Bucket assignment ─────────────────────────────────────────────────────────
# Mirrors the keyword-based pass used in chat-side exploration. This is a
# coarse first cut for triage, not a final taxonomy — expect to refine after
# reviewing the full-text scan results below.
bucket_doc <- function(prescreen, reasoning, preview) {
  pre <- tolower(paste(prescreen, reasoning, preview))

  if (!is.na(prescreen) && str_detect(prescreen, "AGENDA")) return("agenda_prescreen")
  if (str_detect(pre, "highlight|summary of (the )?meeting|meeting summary|board highlights|in brief"))
    return("summary_highlights")
  if (str_detect(pre, "by-?law|bylaw")) return("bylaw")
  if (str_detect(pre, "org(anizational)? chart")) return("org_chart")
  if (str_detect(pre, "report to the board|report to board|quarterly report|annual report|ceo report|financial report|cfo report"))
    return("report_to_board")
  if (str_detect(pre, "policy|procedure|terms of reference|charter")) return("governance_doc")
  if (str_detect(pre, "agenda")) return("agenda_other")
  "other_uncertain"
}

se <- se |>
  rowwise() |>
  mutate(bucket = bucket_doc(prescreen, reasoning, text_preview)) |>
  ungroup()

log_info("Bucket counts:")
print(se |> count(bucket, sort = TRUE))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2 — Flag Cornwall FAC 644/967 partner duplicates
# ══════════════════════════════════════════════════════════════════════════════
# Known case: FAC 644 (Cornwall Community Hospital) and FAC 967 share scraped
# minutes — same underlying board, two registry entries. Match on doc_date
# within the summary_highlights bucket as a first pass; confirm by filename
# pattern before relying on this for any deduplicated counts.

cornwall <- se |> filter(fac %in% c("644", "967"))

cornwall_dupes <- cornwall |>
  group_by(doc_date) |>
  filter(n_distinct(fac) > 1) |>
  ungroup()

log_info(sprintf(
  "Cornwall (644/967) summary docs: %d total, %d appear to share doc_date across both FACs",
  nrow(cornwall), nrow(cornwall_dupes)
))
if (nrow(cornwall_dupes) > 0) {
  print(cornwall_dupes |> select(fac, doc_date, filename) |> arrange(doc_date, fac))
}

se <- se |>
  mutate(is_cornwall_dupe_candidate = fac %in% c("644", "967") &
           doc_date %in% cornwall_dupes$doc_date)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 3 — Full-text OCR for target buckets
# ══════════════════════════════════════════════════════════════════════════════
# Re-OCR only summary_highlights + other_uncertain + report_to_board.
# (agenda_prescreen / agenda_other / bylaw / governance_doc / org_chart are
# excluded — already confirmed non-minutes by title/heading alone.)

extract_text_ocr <- function(pdf_path, dpi = OCR_DPI) {
  eng <- tesseract::tesseract("eng")
  pages <- tryCatch({
    images <- pdftools::pdf_convert(pdf_path, format = "png", dpi = dpi,
                                    verbose = FALSE)
    on.exit(unlink(images), add = TRUE)
    lapply(images, function(img_path) tesseract::ocr(img_path, engine = eng))
  }, error = function(e) {
    log_warning(sprintf("extract_text_ocr: OCR failed for %s — %s",
                        basename(pdf_path), conditionMessage(e)))
    return(list(""))
  })
  paste(pages, collapse = "\n\n--- PAGE BREAK ---\n\n")
}

target_buckets <- c("agenda_prescreen", "agenda_other",
                     "summary_highlights", "other_uncertain", "report_to_board")
# Excluded (definitionally non-minutes, not worth scanning):
#   bylaw, org_chart, governance_doc  (7 docs total)
targets <- se |> filter(bucket %in% target_buckets)

log_info(sprintf("Re-OCR target set: %d documents (%s)",
                  nrow(targets), paste(target_buckets, collapse = ", ")))

# ── Language scan patterns ────────────────────────────────────────────────────
# (1) Formal motion language — present in proper minutes, sometimes in summaries
motion_pattern <- regex(
  "\\bmoved\\b|\\bseconded\\b|\\bcarried\\b|\\bmotion\\b|\\bresolved\\b",
  ignore_case = TRUE
)
# (2) Declarative decision language — how summaries may record decisions without
#     formal motion wording
decision_pattern <- regex(
  "the board (approved|endorsed|agreed|directed|accepted|received and approved|ratified)",
  ignore_case = TRUE
)
# (3) Minutes-boundary signals — Call to Order + attendance block label.
#     Key for agenda_prescreen / agenda_other buckets: a document that opens
#     with an agenda may still have genuine minutes starting further in, marked
#     by these signals.
boundary_pattern <- regex(
  "call(ed)? to order|present\\s*:|in attendance\\s*:|members present\\s*:|directors present\\s*:",
  ignore_case = TRUE
)

WRITE_INTERVAL <- 25L
scan_results <- vector("list", nrow(targets))

for (i in seq_len(nrow(targets))) {

  row <- targets[i, ]
  if (!file.exists(row$local_path)) {
    log_warning(sprintf("File not found, skipping: %s", row$local_path))
    scan_results[[i]] <- data.frame(
      fac = row$fac, hospital_name = row$hospital_name, filename = row$filename,
      bucket = row$bucket, has_motion_lang = NA, has_decision_lang = NA,
      n_motion_hits = NA, n_decision_hits = NA, fulltext_word_count = NA,
      stringsAsFactors = FALSE
    )
    next
  }

  cat(sprintf("[%3d/%3d] FAC %-4s  %s\n", i, nrow(targets), row$fac, row$filename))

  full_text <- extract_text_ocr(row$local_path)

  motion_hits   <- str_count(full_text, motion_pattern)
  decision_hits <- str_count(full_text, decision_pattern)
  boundary_hits <- str_count(full_text, boundary_pattern)

  scan_results[[i]] <- data.frame(
    fac                  = row$fac,
    hospital_name        = row$hospital_name,
    filename             = row$filename,
    bucket               = row$bucket,
    doc_date             = row$doc_date,
    has_motion_lang      = motion_hits > 0,
    has_decision_lang    = decision_hits > 0,
    has_boundary_signal  = boundary_hits > 0,
    n_motion_hits        = motion_hits,
    n_decision_hits      = decision_hits,
    n_boundary_hits      = boundary_hits,
    fulltext_word_count  = str_count(full_text, "\\S+"),
    fulltext_preview_400 = str_sub(str_squish(full_text), 1, 400),
    stringsAsFactors = FALSE
  )

  if (i %% WRITE_INTERVAL == 0L) {
    checkpoint <- bind_rows(scan_results[1:i])
    write.csv(checkpoint, OUTPUT_FILE, row.names = FALSE)
    log_info(sprintf("Checkpoint written at %d / %d", i, nrow(targets)))
  }
}

scan_df <- bind_rows(scan_results)
write.csv(scan_df, OUTPUT_FILE, row.names = FALSE)
log_info(sprintf("Full-text scan complete — written to %s", OUTPUT_FILE))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4 — Summary
# ══════════════════════════════════════════════════════════════════════════════

cat("\n══════════════════════════════════════════════════════\n")
cat("  FULL-TEXT SCAN SUMMARY (by bucket)\n")
cat("══════════════════════════════════════════════════════\n\n")

summary_tbl <- scan_df |>
  group_by(bucket) |>
  summarise(
    n                = n(),
    n_motion         = sum(has_motion_lang,     na.rm = TRUE),
    n_decision       = sum(has_decision_lang,   na.rm = TRUE),
    n_boundary       = sum(has_boundary_signal, na.rm = TRUE),
    n_any_signal     = sum(has_motion_lang | has_decision_lang | has_boundary_signal,
                           na.rm = TRUE),
    .groups = "drop"
  )
print(summary_tbl)

cat("\nDocuments with NO signal of any kind (likely clean true-negatives):\n")
print(scan_df |> filter(!has_motion_lang, !has_decision_lang, !has_boundary_signal) |> nrow())

cat("\nDocuments WITH any signal — candidates for manual review:\n")
print(scan_df |>
        filter(has_motion_lang | has_decision_lang | has_boundary_signal) |>
        select(fac, hospital_name, filename, bucket,
               n_motion_hits, n_decision_hits, n_boundary_hits))

cat("\n══════════════════════════════════════════════════════\n\n")
log_info("Done.")
