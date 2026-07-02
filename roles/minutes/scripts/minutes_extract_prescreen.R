# minutes_extract_prescreen.R
# Purpose: Extract embedded minutes text from the 35 agenda_prescreen documents
#          identified by llm_run1_fulltext_scan.R (100% boundary signal — these
#          open with a standalone AGENDA heading but contain genuine minutes
#          content from a later page onward).
#
# Design notes:
# - detect_header() / detect_attendance() / detect_motions() / detect_close()
#   are duplicated here from minutes_classify.R rather than sourced, since
#   minutes_classify.R is not safely sourceable (rm(list=ls()) + full corpus
#   run on source). Keep these in sync manually if patterns are revised there.
# - detect_close_page() and detect_call_to_order_page() are page-level-only
#   variants with no percentage-based slicing and (for close) no reliance on
#   header/attendance boilerplate. Three bugs were found and fixed across two
#   rounds of manual spot-checking against real PDFs (see July 2 session
#   summary for full detail):
#     (1) Percentage-slicing (detect_attendance/detect_close use "first 40%" /
#         "last 15%" of a string) is only valid against whole-document text.
#         Applied per-page, it produced misses — e.g. an adjournment sentence
#         sitting outside the literal last-15%-of-characters slice of the
#         final page (Cambridge, Thunder Bay).
#     (2) header + attendance co-occurrence, tried as the start gate after
#         fixing (1), was still too promiscuous: agenda cover pages carry the
#         same title boilerplate as real minutes, and the bare attendance
#         regex (\\bpresent\\b, \\bregrets\\b) matches agenda item TITLES with
#         no surrounding context. This produced false starts on agenda pages,
#         a motions-summary document, and a slide deck (CMH 661, TBay 935 x2),
#         and a fully spurious extraction from a document (Holland Bloorview)
#         that is agenda-only with no embedded minutes at all.
#     (3) Fix: start detection now anchors on "called to order" co-occurring
#         with an actual clock time within ~150 characters — a real minutes
#         narrative sentence has this; an agenda line item, slide deck, or
#         motions-summary document does not.
# - No EOF fallback on close detection. If no close is found, the document is
#   flagged for manual review rather than silently extracted to EOF.
# - attendance_nearby is carried as an INFORMATIONAL column only (not a gate)
#   for spot-checking the new start anchor without reintroducing attendance
#   as a false-positive-prone gate.
#
# STATUS AS OF JULY 2, 2026: Call-to-order anchor is untested against the
# five known failure cases (CMH 661 x2, TBay 935 x2, Holland Bloorview).
# Run single-document tests on all five via TEST_FAC before trusting a full
# batch run. See "Next Session — Start Here" in the July 2 session summary.
#
# Run from: E:/HospitalIntelligenceR (project root)
# Input:    roles/minutes/outputs/llm_run1_fulltext_scan.csv (bucket == "agenda_prescreen")
#           roles/minutes/outputs/llm_run1_results.csv (for local_path lookup)
# Output:   roles/minutes/outputs/minutes_extract_prescreen_results.rds
#           (or minutes_extract_prescreen_TEST.rds in single-document test mode)

rm(list = ls())

library(dplyr)
library(stringr)
library(pdftools)
library(tesseract)

source("core/logger.R")
init_logger(role = "minutes")

# ── Config ───────────────────────────────────────────────────────────────────
SCAN_FILE    <- "roles/minutes/outputs/llm_run1_fulltext_scan.csv"
RESULTS_FILE <- "roles/minutes/outputs/llm_run1_results.csv"
OUTPUT_FILE  <- "roles/minutes/outputs/minutes_extract_prescreen_results.rds"
PROJECT_ROOT <- "E:/HospitalIntelligenceR"
OCR_DPI      <- 300

# Single-document test mode — set TEST_FAC to a FAC code (character) to run
# extraction on just that document instead of the full 35. Leave NULL for a
# full batch run. If more than one document matches (e.g. a hospital has
# multiple agenda_prescreen docs), TEST_FILENAME narrows it further.
# Test mode writes to a separate output file so it never clobbers a prior
# full-batch result.
TEST_FAC      <- NULL   # e.g. "661" for CMH, "935" for Thunder Bay
TEST_FILENAME <- NULL   # e.g. "2024-11-06_board_minutes.pdf" — narrows TEST_FAC

# ── 1. Load scan output, filter to agenda_prescreen bucket ────────────────────
scan <- read.csv(SCAN_FILE, stringsAsFactors = FALSE) |>
  mutate(fac = as.character(fac)) |>
  filter(bucket == "agenda_prescreen")

log_info(sprintf("agenda_prescreen documents to extract: %d", nrow(scan)))

# ── 2. Join to llm_run1_results.csv for local_path; build absolute path ───────
results_lookup <- read.csv(RESULTS_FILE, stringsAsFactors = FALSE) |>
  mutate(fac = as.character(fac)) |>
  select(fac, filename, local_path)

target <- scan |>
  select(fac, hospital_name, filename) |>
  left_join(results_lookup, by = c("fac", "filename"))

missing_path <- target |> filter(is.na(local_path))
if (nrow(missing_path) > 0) {
  log_warning(sprintf("No local_path match for %d documents — check fac/filename join", nrow(missing_path)))
  print(missing_path |> select(fac, hospital_name, filename))
}

resolve_path <- function(local_path) {
  if (is.na(local_path)) return(NA_character_)
  if (str_detect(local_path, "^[A-Za-z]:")) return(local_path)  # already absolute
  file.path(PROJECT_ROOT, local_path)
}

target <- target |>
  filter(!is.na(local_path)) |>
  mutate(local_path_abs = vapply(local_path, resolve_path, character(1)))

log_info(sprintf("Documents with resolved path, ready for extraction: %d", nrow(target)))

# ── 3. Structural detection functions (duplicated from minutes_classify.R) ────
# Whole-document versions kept for Section 5's final classify_document() call,
# which runs against the full concatenated extracted range — where percentage
# slicing is valid. Page-level variants below are for per-page boundary
# detection only.

detect_header <- function(text) {
  head_text <- str_sub(text, 1, 1500)
  str_detect(
    str_to_lower(head_text),
    paste0(
      "minutes of|", "board of directors|", "board meeting|", "open session|",
      "meeting of the board|", "regular meeting|", "special meeting|",
      "annual meeting|", "annual general meeting"
    )
  )
}

# Whole-document attendance detector — used only on the final extracted range.
detect_attendance <- function(text) {
  att_text <- str_sub(text, 1, nchar(text) * 0.40)
  str_detect(
    str_to_lower(att_text),
    paste0(
      "members present|", "board members present|", "directors present|",
      "in attendance|", "also in attendance|", "regrets:|", "regrets /|",
      "quorum (confirmed|declared|established|achieved)|",
      "quorum was established|", "there was a quorum|", "confirmed that there was|",
      "\\bpresent:|", "\\bpresent\\b|", "\\bregrets\\b|", "staff present|",
      "anson general hospital|", "bingham memorial hospital|", "lady minto hospital"
    )
  )
}

# Page-level attendance detector — informational only (see detect_call_to_order_page
# note below on why attendance is no longer used as a start gate).
detect_attendance_page <- function(page_text) {
  str_detect(
    str_to_lower(page_text),
    paste0(
      "members present|", "board members present|", "directors present|",
      "in attendance|", "also in attendance|", "regrets:|", "regrets /|",
      "quorum (confirmed|declared|established|achieved)|",
      "quorum was established|", "there was a quorum|", "confirmed that there was|",
      "\\bpresent:|", "\\bpresent\\b|", "\\bregrets\\b|", "staff present|",
      "anson general hospital|", "bingham memorial hospital|", "lady minto hospital"
    )
  )
}

detect_motions <- function(text) {
  str_detect(
    str_to_lower(text),
    paste0(
      "moved by|", "seconded by|", "\\bcarried\\b|", "\\bdefeated\\b|",
      "be it resolved|", "resolved that|", "motion (that|to)|",
      "\\bmotion:\\b|", "it was moved"
    )
  )
}

# Whole-document close detector — used only on the final extracted range.
detect_close <- function(text) {
  close_text <- str_sub(text, nchar(text) * 0.85, nchar(text))
  str_detect(
    str_to_lower(close_text),
    paste0(
      "\\badjourned\\b|", "meeting adjourned|", "next meeting|",
      "next regular meeting|", "there being no further business"
    )
  )
}

# Page-level close detector — checks the whole page, no percentage slicing.
# Fixed bug: an adjournment motion can sit anywhere on the final page of a
# scanned document, not reliably in the last 15% of that page's characters.
detect_close_page <- function(page_text) {
  str_detect(
    str_to_lower(page_text),
    paste0(
      "\\badjourned\\b|", "meeting adjourned|", "next meeting|",
      "next regular meeting|", "there being no further business"
    )
  )
}

# Call-to-order anchor — replaces header+attendance as the start gate.
# Requires "call(ed) to order" to co-occur with an actual clock time within
# ~150 characters. A real minutes narrative sentence has this ("called the
# meeting to order at 6:32 p.m."); an agenda line item ("1. Call to Order"),
# slide deck, or motions-summary document does not. header+attendance
# co-occurrence was tried first and rejected — both signals proved too
# promiscuous (agenda title boilerplate satisfies header; agenda item titles
# like "Regrets" or "Attendance" satisfy the bare attendance regex with zero
# surrounding context).
detect_call_to_order_page <- function(page_text) {
  text_lower <- str_to_lower(page_text)
  positions  <- str_locate_all(text_lower, "call(ed)? to order")[[1]]
  if (nrow(positions) == 0) return(FALSE)
  
  time_pattern <- "\\d{1,2}:\\d{2}\\s*(a\\.?m\\.?|p\\.?m\\.?)"
  
  for (i in seq_len(nrow(positions))) {
    win_start <- max(1, positions[i, "start"] - 150)
    win_end   <- min(nchar(text_lower), positions[i, "end"] + 150)
    window    <- str_sub(text_lower, win_start, win_end)
    if (str_detect(window, time_pattern)) return(TRUE)
  }
  FALSE
}

classify_document <- function(text, word_count) {
  if (word_count < 50) {
    return(list(doc_class = "needs_ocr", corpus_include = FALSE))
  }
  hdr <- detect_header(text)
  att <- detect_attendance(text)
  mot <- detect_motions(text)
  
  if (hdr && att && mot) {
    list(doc_class = "minutes", corpus_include = TRUE)
  } else if (hdr && att && !mot) {
    list(doc_class = "summary_minutes", corpus_include = TRUE)
  } else if (hdr && !att && !mot) {
    list(doc_class = "agenda", corpus_include = FALSE)
  } else {
    list(doc_class = "other", corpus_include = FALSE)
  }
}

# ── 4. Page-by-page OCR extraction ─────────────────────────────────────────────
extract_pages <- function(pdf_path, dpi = OCR_DPI) {
  eng <- tesseract::tesseract("eng")
  tryCatch({
    images <- pdftools::pdf_convert(pdf_path, format = "png", dpi = dpi, verbose = FALSE)
    on.exit(unlink(images), add = TRUE)
    unlist(lapply(images, function(img_path) tesseract::ocr(img_path, engine = eng)))
  }, error = function(e) {
    log_warning(sprintf("extract_pages: OCR failed for %s — %s",
                        basename(pdf_path), conditionMessage(e)))
    character(0)
  })
}

# ── 5. Per-document boundary detection and extraction ──────────────────────────
process_document <- function(row) {
  pdf_path <- row$local_path_abs
  
  make_result <- function(start = NA_integer_, end = NA_integer_, n_pages = NA_integer_,
                          full_text = NA_character_, doc_class = NA_character_,
                          corpus_include = FALSE, qa_flag = NA_character_,
                          attendance_nearby = NA) {
    data.frame(
      fac = row$fac, hospital_name = row$hospital_name, filename = row$filename,
      local_path = pdf_path,
      minutes_page_start = start, minutes_page_end = end,
      n_pages_extracted = n_pages, full_text = full_text,
      doc_class = doc_class, corpus_include = corpus_include,
      attendance_nearby = attendance_nearby,
      qa_flag = qa_flag, stringsAsFactors = FALSE
    )
  }
  
  if (is.na(pdf_path) || !file.exists(pdf_path)) {
    log_warning(sprintf("File not found: %s", pdf_path))
    return(make_result(qa_flag = "file_missing"))
  }
  
  pages <- extract_pages(pdf_path)
  n_pages <- length(pages)
  
  if (n_pages == 0) {
    return(make_result(qa_flag = "ocr_failed"))
  }
  
  # ── Start detection: call-to-order + time anchor ──────────────────────────────
  call_hits <- vapply(pages, detect_call_to_order_page, logical(1))
  start_idx <- which(call_hits)[1]
  
  if (is.na(start_idx)) {
    return(make_result(qa_flag = "no_start_detected"))
  }
  
  # Informational only — not a gate. Records whether an attendance-style match
  # also appears near the confirmed start, for spot-checking without
  # reintroducing attendance as a false-positive-prone gate.
  attendance_hits  <- vapply(pages, detect_attendance_page, logical(1))
  att_window_end   <- min(start_idx + 1, n_pages)
  attendance_nearby <- any(attendance_hits[start_idx:att_window_end])
  
  # ── Close detection: page-level, no percentage slicing ────────────────────────
  close_hits <- vapply(pages[start_idx:n_pages], detect_close_page, logical(1))
  close_rel  <- which(close_hits)[1]
  
  if (is.na(close_rel)) {
    # No EOF fallback — flag for manual review rather than silently over-extracting.
    return(make_result(start = start_idx, qa_flag = "no_close_detected",
                       attendance_nearby = attendance_nearby))
  }
  
  end_idx <- start_idx + close_rel - 1
  
  full_text  <- paste(pages[start_idx:end_idx], collapse = "\n\n--- PAGE BREAK ---\n\n")
  word_count <- length(str_split(str_squish(full_text), "\\s+")[[1]])
  cls        <- classify_document(full_text, word_count)
  
  make_result(
    start = start_idx, end = end_idx, n_pages = end_idx - start_idx + 1,
    full_text = full_text, doc_class = cls$doc_class,
    corpus_include = cls$corpus_include,
    attendance_nearby = attendance_nearby
  )
}

# ── 5b. Single-document test mode filter ───────────────────────────────────────
if (!is.null(TEST_FAC)) {
  target <- target |> filter(fac == as.character(TEST_FAC))
  if (!is.null(TEST_FILENAME)) {
    target <- target |> filter(filename == TEST_FILENAME)
  }
  if (nrow(target) == 0) {
    stop(sprintf("TEST_FAC %s / TEST_FILENAME %s matched no rows in target — check spelling against llm_run1_fulltext_scan.csv",
                 TEST_FAC, ifelse(is.null(TEST_FILENAME), "(any)", TEST_FILENAME)))
  }
  if (nrow(target) > 1) {
    log_warning(sprintf("TEST_FAC %s matched %d documents — set TEST_FILENAME to narrow to one", TEST_FAC, nrow(target)))
    print(target |> select(fac, hospital_name, filename))
  }
  log_info(sprintf("TEST MODE — running on %d document(s) only", nrow(target)))
}

OUTPUT_FILE_ACTUAL <- if (!is.null(TEST_FAC)) {
  "roles/minutes/outputs/minutes_extract_prescreen_TEST.rds"
} else {
  OUTPUT_FILE
}

# ── 6. Run extraction loop ──────────────────────────────────────────────────────
log_info(sprintf("Beginning extraction — %d documents", nrow(target)))

results_list <- vector("list", nrow(target))

for (i in seq_len(nrow(target))) {
  row <- target[i, ]
  cat(sprintf("[%2d/%d] FAC %-4s  %s\n", i, nrow(target), row$fac, row$filename))
  results_list[[i]] <- process_document(row)
  cat(sprintf("        doc_class=%-15s corpus_include=%-5s attendance_nearby=%-5s qa_flag=%s\n",
              results_list[[i]]$doc_class, results_list[[i]]$corpus_include,
              results_list[[i]]$attendance_nearby,
              ifelse(is.na(results_list[[i]]$qa_flag), "none", results_list[[i]]$qa_flag)))
  
  if (i %% 10 == 0L) {
    checkpoint <- bind_rows(results_list[1:i])
    saveRDS(checkpoint, OUTPUT_FILE_ACTUAL)
    log_info(sprintf("Checkpoint written at document %d / %d", i, nrow(target)))
  }
}

results <- bind_rows(results_list)
saveRDS(results, OUTPUT_FILE_ACTUAL)
log_info(sprintf("Extraction complete — %d documents written to %s", nrow(results), OUTPUT_FILE_ACTUAL))

# ── 7. Summary ───────────────────────────────────────────────────────────────
cat("\n══════════════════════════════════════════════════════\n")
cat("  AGENDA_PRESCREEN EXTRACTION — SUMMARY\n")
cat("══════════════════════════════════════════════════════\n\n")
cat(sprintf("Total processed:         %d\n", nrow(results)))
cat(sprintf("  corpus_include TRUE:   %d\n", sum(results$corpus_include, na.rm = TRUE)))
cat(sprintf("  no_start_detected:     %d  (needs manual review)\n",
            sum(results$qa_flag == "no_start_detected", na.rm = TRUE)))
cat(sprintf("  no_close_detected:     %d  (needs manual review)\n",
            sum(results$qa_flag == "no_close_detected", na.rm = TRUE)))
cat(sprintf("  file_missing:          %d\n", sum(results$qa_flag == "file_missing", na.rm = TRUE)))
cat(sprintf("  ocr_failed:            %d\n", sum(results$qa_flag == "ocr_failed", na.rm = TRUE)))