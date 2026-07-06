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
#     (3) Fix attempted July 2: start detection anchored on "called to order"
#         co-occurring with an actual clock time within ~150 characters, used
#         alone as the sole start gate. This was designed but never run.
#     (4) Fix applied July 3 (this version): call-to-order+time alone was
#         judged too thin a foundation — a single untested signal carrying
#         the entire start gate. Start detection is now a STRICT, SAME-PAGE
#         combination of three independent structural signals, matching the
#         real sequence of a minutes document's opening block:
#           - detect_header_page(): header phrase (e.g. "minutes of",
#             "board of directors") co-occurring with an actual date on the
#             page — a bare header phrase with no date is not sufficient
#             (agenda cover pages carry header phrases too).
#           - detect_name_list_near(): an attendance keyword ("present",
#             "in attendance", "regrets", etc.) with a real run of proper
#             names nearby — not just the bare keyword, which matched agenda
#             item titles like "Regrets" with zero surrounding names.
#             min_names = 5. Matches BOTH full-name format ("Patricia Lang")
#             and initial-based format ("L.Woeller", "Dr. W. Lee") — the
#             initial-based pattern was added after CMH testing showed the
#             full-name-only pattern found zero names on a page with 13 real
#             attendees, because CMH lists attendees by initial, not full
#             first name.
#           - detect_call_to_order_page(): "call(ed) to order" co-occurring
#             with a clock time within ~150 characters. Time pattern covers
#             colon+am/pm ("5:06 p.m."), military with "h"/"hrs"/"hours"
#             suffix ("1700h", "1700 hours"), and bare HH:MM. The matching
#             window also normalizes a lowercase "o" sitting between two
#             digits (or a digit and "h") back to "0" — CMH's source PDF has
#             a font-substitution issue (missing 'AmsiPro' font) that causes
#             tesseract to sporadically misread "1700h" as "170oh"; this
#             normalization is scoped to the narrow time-matching window only,
#             so it can't affect anything else on the page.
#         All three must fire on the SAME page. This is deliberately strict:
#         false positives across three separate documents (agenda pages, a
#         motions-summary doc, a slide deck) motivate requiring independent
#         confirmation from header, attendance, and call-to-order structure
#         rather than trusting any single signal.
# - No EOF fallback on close detection. If no close is found, the document is
#   flagged for manual review rather than silently extracted to EOF.
# - attendance_nearby is carried as an INFORMATIONAL column (bare-keyword
#   detect_attendance_page(), not the stricter name-list version) for
#   spot-checking, kept separate from the new name-list gate itself.
#
# STATUS AS OF JULY 3, 2026: Strict same-page three-signal start gate
# VALIDATED — 6/6 single-document tests passed (both start and end page
# confirmed correct against manual PDF review): CMH 661 (2024-03-06,
# 2026-06-03), TBay 935 (2024-10-02, 2025-10-01), plus 2 additional documents
# from hospitals not previously tested. Holland Bloorview 939 correctly
# flagged no_start_detected (true negative — agenda-only, no embedded
# minutes). Cleared for full 35-document batch run.
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
MIN_NAMES    <- 5   # minimum Title-Case name-pattern hits near an attendance
# keyword to count as a real name list (see
# detect_name_list_near). Tune against test-case output.

# Single-document test mode — set TEST_FAC to a FAC code (character) to run
# extraction on just that document instead of the full 35. Leave NULL for a
# full batch run. If more than one document matches (e.g. a hospital has
# multiple agenda_prescreen docs), TEST_FILENAME narrows it further.
# Test mode writes to a separate output file so it never clobbers a prior
# full-batch result.
#TEST_FAC      <- "933"
#TEST_FILENAME <- "2024-07-01_board_minutes_v4.pdf"
TEST_FAC <- NULL; TEST_FILENAME <- NULL
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

# Page-level attendance detector — informational only. Bare keyword, no name
# check. See detect_name_list_near() below for the stricter gating version.
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

# ── New (July 3): date detector — header must co-occur with an actual date ────
detect_date_page <- function(page_text) {
  date_pattern <- paste0(
    "(january|february|march|april|may|june|july|august|september|october|",
    "november|december)\\s+\\d{1,2},?\\s+\\d{4}",
    "|\\d{4}-\\d{2}-\\d{2}",
    "|\\d{1,2}/\\d{1,2}/\\d{2,4}"
  )
  str_detect(str_to_lower(page_text), date_pattern)
}

# ── New (July 3): page-level header — phrase + date, same page ────────────────
# A bare header phrase (detect_header() above) matches agenda cover pages too.
# Requiring a co-occurring date narrows this to an actual opening-block page.
detect_header_page <- function(page_text) {
  has_header_phrase <- str_detect(
    str_to_lower(page_text),
    paste0(
      "minutes of|", "board of directors|", "board meeting|", "open session|",
      "meeting of the board|", "regular meeting|", "special meeting|",
      "annual meeting|", "annual general meeting"
    )
  )
  has_header_phrase && detect_date_page(page_text)
}

# ── New (July 3): name-list detector — attendance keyword + real names ────────
# Operates on ORIGINAL-CASE page_text (not lowered) since Title-Case matching
# needs case preserved; keyword search uses inline case-insensitive character
# classes for the same reason. Round 2 (July 2) found the bare attendance
# keyword alone matches agenda item titles ("Regrets" as a line-item label)
# with zero names attached — this is the fix: require a real run of
# Title-Case two-word sequences within `window` characters of the keyword.
detect_name_list_near <- function(page_text, min_names = MIN_NAMES, window = 600) {
  text_lower <- str_to_lower(page_text)
  kw_positions <- str_locate_all(
    text_lower,
    paste0(
      "members present|", "board members present|",
      "directors present|", "in attendance|",
      "also in attendance|regrets|present:"
    )
  )[[1]]
  if (nrow(kw_positions) == 0) return(FALSE)
  
  name_pattern <- paste0(
    "(?:Dr\\.?\\s*)?[A-Z]\\.\\s?[A-Z][a-z]+",
    "|",
    "[A-Z][a-z]+\\s[A-Z][a-z]+"
  )
  
  for (i in seq_len(nrow(kw_positions))) {
    win_start <- kw_positions[i, "start"]
    win_end   <- min(nchar(page_text), win_start + window)
    win_text  <- str_sub(page_text, win_start, win_end)  # original-case page_text, not text_lower
    n_names   <- length(str_extract_all(win_text, name_pattern)[[1]])
    if (n_names >= min_names) return(TRUE)
  }
  FALSE
}

# Call-to-order anchor — one of three signals in the combined start gate.
# Requires "call(ed) to order" to co-occur with an actual clock time within
# ~150 characters. A real minutes narrative sentence has this ("called the
# meeting to order at 6:32 p.m."); an agenda line item ("1. Call to Order"),
# slide deck, or motions-summary document does not.
detect_call_to_order_page <- function(page_text) {
  text_lower <- str_to_lower(page_text)
  positions  <- str_locate_all(text_lower, "call(ed)? to order")[[1]]
  if (nrow(positions) == 0) return(FALSE)
  
  # Broadened July 3 (post-Cambridge test): the original pattern only
  # recognized colon+am/pm formats ("5:06p.m."). Cambridge uses military
  # time with no colon and an "h" suffix ("1700h"), which matched nothing
  # and caused a false no_start_detected despite "called to order" being
  # present on the page.
  time_pattern <- paste0(
    "\\d{1,2}:\\d{2}\\s*(a\\.?m\\.?|p\\.?m\\.?)",  # 5:06 p.m.
    "|\\d{3,4}\\s*h(rs|ours)?\\b",                  # 1700h, 1700hrs, 1700 hours
    "|\\d{1,2}:\\d{2}\\s*h(rs|ours)?\\b",           # 17:00h
    "|\\b\\d{1,2}:\\d{2}\\b"                        # bare HH:MM fallback
  )
  
  for (i in seq_len(nrow(positions))) {
    win_start <- max(1, positions[i, "start"] - 150)
    win_end   <- min(nchar(text_lower), positions[i, "end"] + 150)
    window    <- str_sub(text_lower, win_start, win_end)
    
    # OCR fix (July 3, round 3): the 'AmsiPro' font substitution warnings on
    # this document line up with sporadic 0/O digit misreads — "1700h" comes
    # through as "170oh" on some pages of the same PDF and correctly as
    # "1700h" on others. Normalize only within this already-narrow window,
    # only where an 'o' sits between a digit and another digit-or-h, so this
    # can't accidentally rewrite unrelated text elsewhere on the page.
    window <- str_replace_all(window, "(?<=[0-9])o(?=[0-9]|h)", "0")
    
    if (str_detect(window, time_pattern)) return(TRUE)
  }
  FALSE
}

# ── New (July 3): combined strict start gate — all three signals, same page ───
# header+date, attendance+name-list, and call-to-order+time must ALL fire on
# the same page. Deliberately strict: single-signal gates (header+attendance
# in Round 1, call-to-order alone as designed July 2) both proved insufficient
# or went untested. Requiring independent confirmation from all three
# structural elements of a real minutes opening block is the July 3 fix.
detect_minutes_start_page <- function(page_text) {
  detect_header_page(page_text) &&
    detect_name_list_near(page_text) &&
    detect_call_to_order_page(page_text)
}

# ── New (July 3, round 2): diagnostic helper — test mode only ─────────────────
# Prints, per page, which of the three gate signals fired plus a raw text
# snippet — using the ACTUAL tesseract OCR output, not a manual transcription.
# Added because the 2024-03-06 CMH doc passed with visible OCR misreads
# ("8. Alvarado" for "S. Alvarado", "|. Morgan" for "J. Morgan") while the
# 2026-06-03 CMH doc failed — the only way to tell whether that's a genuine
# threshold miss on real OCR artifacts (vs. a still-missing pattern case) is
# to look at what OCR actually produced, not a hand-typed reference passage.
print_page_diagnostics <- function(pages) {
  for (i in seq_along(pages)) {
    hdr <- detect_header_page(pages[i])
    nms <- detect_name_list_near(pages[i])
    cto <- detect_call_to_order_page(pages[i])
    cat(sprintf("\n--- Page %d ---  header=%s  names=%s  call_to_order=%s\n",
                i, hdr, nms, cto))
    if (hdr || nms || cto) {
      cat(str_sub(pages[i], 1, 800), "\n")
    }
  }
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
  
  # ── Start detection: strict same-page combination of header+date, ────────────
  # attendance+name-list, and call-to-order+time.
  start_hits <- vapply(pages, detect_minutes_start_page, logical(1))
  start_idx  <- which(start_hits)[1]
  
  if (is.na(start_idx)) {
    return(make_result(qa_flag = "no_start_detected"))
  }
  
  # Informational only — bare-keyword attendance (not the name-list version),
  # for spot-checking without duplicating the gating logic.
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
  
  if (!is.null(TEST_FAC)) {
    cat(sprintf("\n════ DIAGNOSTICS (raw OCR, actual tesseract output): FAC %s  %s ════\n",
                row$fac, row$filename))
    diag_pages <- extract_pages(row$local_path_abs)
    print_page_diagnostics(diag_pages)
    cat("\n════ END DIAGNOSTICS ════\n\n")
  }
  
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