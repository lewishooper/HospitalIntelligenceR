# minutes_extract_prescreen.R
# Purpose: Extract embedded minutes text from the SomethingElse REMAINDER batch —
#          i.e. every SomethingElse document that has NOT already been handled by
#          a completed workstream. As of July 6, 2026 that means:
#            - the 35 agenda_prescreen documents (done — minutes_extract_prescreen_results.rds,
#              produced by an earlier run of this same script against the narrower
#              agenda_prescreen bucket)
#            - the 197 documents across the four summary-tier hospitals, FAC 905,
#              736, 967, 644 (done — minutes_extract_summary_results.rds)
#            - FAC 941 (Humber) — dropped entirely, no useful content
#            - FAC 975 (Trillium) — deferred to a future workstream, failed
#              extraction scripts
#          The remaining SomethingElse documents use the same strict same-page
#          three-signal start gate validated on the original 35-document batch.
#
# REPURPOSING NOTE (July 6, 2026): This script previously targeted only the
# agenda_prescreen bucket via llm_run1_fulltext_scan.R's `bucket` column. That
# scan file is not confirmed to be a complete partition of the full
# SomethingElse population, so the remainder target-set below is built
# directly off llm_run1_results.csv (classification == "SomethingElse")
# anti-joined against the two completed extraction outputs on fac + filename,
# rather than trusting a bucket label. See July 6 chat record for the Option
# A vs Option B discussion behind this choice. OUTPUT_FILE is renamed to
# minutes_extract_remainder_results.rds so this run cannot clobber the
# original 35-document agenda_prescreen output.
#
# Design notes (original, agenda_prescreen-era — retained for detection-logic
# history; the detection functions below are unchanged from that validated
# version):
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
#     NOTE: a fourth gap (active-voice call-to-order construction, "called
#     the meeting to order" vs. passive "was called to order") was found and
#     fixed in the sibling script minutes_extract_summary.R on July 6, but was
#     NOT ported here. This script's validated 35-document batch never
#     surfaced that gap, and per the July 6 session decision, reopening a
#     closed, validated script for an untriggered theoretical gap isn't
#     warranted. If the remainder batch below produces an unexpected cluster
#     of no_start_detected results, this is the first place to check —
#     see minutes_extract_summary.R's detect_call_to_order_page() for the
#     broadened regex if a port turns out to be needed.
# - No EOF fallback on close detection. If no close is found, the document is
#   flagged for manual review rather than silently extracted to EOF.
# - attendance_nearby is carried as an INFORMATIONAL column (bare-keyword
#   detect_attendance_page(), not the stricter name-list version) for
#   spot-checking, kept separate from the new name-list gate itself.
#
# STATUS AS OF JULY 3, 2026 (agenda_prescreen batch): Strict same-page
# three-signal start gate VALIDATED — 6/6 single-document tests passed (both
# start and end page confirmed correct against manual PDF review): CMH 661
# (2024-03-06, 2026-06-03), TBay 935 (2024-10-02, 2025-10-01), plus 2
# additional documents from hospitals not previously tested. Holland
# Bloorview 939 correctly flagged no_start_detected (true negative —
# agenda-only, no embedded minutes). Cleared for full 35-document batch run.
#
# STATUS AS OF JULY 6, 2026 (remainder batch, first run): Quinte (FAC 957)
# test batch (4 documents) passed — manually confirmed against source PDFs
# that minutes_page_start/end were correct and full_text read cleanly as
# board minutes, even with Quinte's buried-minutes-after-reports pattern.
# Full remainder run (215 documents) then returned only those same 4 Quinte
# documents as corpus_include TRUE — 210 of 215 came back no_start_detected.
#
# ROOT CAUSE CONFIRMED: manual spot-check of FAC 858 (Michael Garron) found
# clear board-minutes content that should have passed — header, date, name
# list, call-to-order, and close were all genuinely present. The failure was
# detect_call_to_order_page()'s regex requiring "call(ed)" and "to order" to
# be immediately adjacent, matching only the passive construction ("was
# called to order"). FAC 858 uses the active construction ("The Chair
# called the meeting to order at 1605H"), with "the meeting" intervening —
# never matched. This is the exact same bug already found and fixed on Oak
# Valley (FAC 905) in minutes_extract_summary.R on July 6 — that fix was
# deliberately scoped to that script only, on the reasoning that this script
# was "already validated and closed" and the gap was untriggered here. The
# 210/215 remainder failure confirms the gap was real and dominant across
# this more structurally diverse population; only Quinte's passive-voice
# phrasing happened to avoid it.
#
# FIX APPLIED (this version): ported the same broadened regex —
# call(ed)?\s(?:[a-z]+\s){0,3}to order — from minutes_extract_summary.R.
# Also added four whole-document diagnostic columns (any_header, any_names,
# any_call_to_order, any_close), computed regardless of gate success, so any
# remaining no_start_detected/no_close_detected rows can be audited at a
# glance rather than requiring a fresh manual PDF read for every one.
#
# TEST_FAC is set to "858" below — per standing project discipline
# ("confirm fix on real output before batch runs"), this fix must be
# spot-checked against the exact document it was diagnosed from before
# trusting it against the full remainder batch. Revert to NULL only after
# 858 confirms clean.
#
# NOTE: fixing this regex should recover a meaningful share of the 210, but
# the remainder population is far more structurally diverse than either the
# 35 agenda_prescreen documents or the 4 summary-tier hospitals validated so
# far. Do not assume this fix clears everything — re-run the full batch
# after 858 confirms, and treat whatever's still stuck as a fresh, smaller
# diagnosis using the new any_* columns.
#
# Run from: E:/HospitalIntelligenceR (project root)
# Input:    roles/minutes/outputs/llm_run1_results.csv (classification == "SomethingElse")
#           roles/minutes/outputs/minutes_extract_prescreen_results.rds (already-processed exclusion)
#           roles/minutes/outputs/minutes_extract_summary_results.rds (already-processed exclusion)
# Output:   roles/minutes/outputs/minutes_extract_remainder_results.rds
#           (or minutes_extract_remainder_TEST.rds in single-document/single-hospital test mode)

rm(list = ls())

library(dplyr)
library(stringr)
library(pdftools)
library(tesseract)

source("core/logger.R")
init_logger(role = "minutes")

# ── Config ───────────────────────────────────────────────────────────────────
RESULTS_FILE      <- "roles/minutes/outputs/llm_run1_results.csv"
PRESCREEN_DONE    <- "roles/minutes/outputs/minutes_extract_prescreen_results.rds"
SUMMARY_DONE      <- "roles/minutes/outputs/minutes_extract_summary_results.rds"
OUTPUT_FILE       <- "roles/minutes/outputs/minutes_extract_remainder_results.rds"
PROJECT_ROOT      <- "E:/HospitalIntelligenceR"
OCR_DPI           <- 300
MIN_NAMES         <- 5   # minimum Title-Case name-pattern hits near an attendance
# keyword to count as a real name list (see
# detect_name_list_near). Tune against test-case output.

# Hospitals excluded entirely from the remainder batch by explicit prior
# decision — not part of the same-page-gate scope at all.
#   941 (Humber)   — dropped, no useful content
#   975 (Trillium) — deferred to a future workstream, failed extraction scripts
# The four summary-tier hospitals are excluded via the anti-join against
# SUMMARY_DONE below (not listed here), since that exclusion is at the
# fac+filename level, not a blanket FAC exclusion — keeping the two
# mechanisms distinct makes it obvious in Section 1 output which exclusion
# path removed which rows.
EXCLUDE_FACS <- c("941", "975")

# Single-document/single-hospital test mode — set TEST_FAC to a FAC code
# (character) to run extraction on just that hospital's documents instead of
# the full remainder batch. TEST_FILENAME narrows further to one document.
# Test mode writes to a separate output file so it never clobbers a prior
# full-batch result.
# Set per July 6 handoff (post active-voice regex fix): Michael Garron (858)
# is the verification test — this is the exact document manually confirmed
# to contain header, names, call-to-order, and close, that failed under the
# old adjacency-only regex. Confirming 858 now passes is the checkpoint
# before trusting the fix against the full 215-document remainder batch.
TEST_FAC      <- NULL 
TEST_FILENAME <- NULL

# ── 1. Build remainder target set ─────────────────────────────────────────────
# Option B (July 6 decision): filter llm_run1_results.csv directly rather than
# trust a bucket column of unconfirmed completeness, then anti-join against
# the two completed extraction outputs on fac + filename. This is self-
# auditing — each subtraction step below is logged with its row count so the
# exclusion is traceable rather than assumed.

results_csv <- read.csv(RESULTS_FILE, stringsAsFactors = FALSE) |>
  mutate(fac = as.character(fac))

something_else <- results_csv |>
  filter(classification == "SomethingElse")

log_info(sprintf("SomethingElse total (llm_run1_results.csv): %d", nrow(something_else)))

# Exclude FAC 941 and 975 by explicit decision.
something_else <- something_else |>
  filter(!fac %in% EXCLUDE_FACS)

log_info(sprintf("After excluding FAC 941/975: %d", nrow(something_else)))

# Load already-processed fac+filename pairs from both completed workstreams.
load_done_keys <- function(path) {
  if (!file.exists(path)) {
    log_warning(sprintf("Expected completed-output file not found: %s — exclusion for this workstream will NOT be applied. Confirm path before trusting the remainder target set.", path))
    return(data.frame(fac = character(0), filename = character(0)))
  }
  readRDS(path) |>
    mutate(fac = as.character(fac)) |>
    select(fac, filename) |>
    distinct()
}

prescreen_done_keys <- load_done_keys(PRESCREEN_DONE)
summary_done_keys   <- load_done_keys(SUMMARY_DONE)

log_info(sprintf("agenda_prescreen already-processed keys loaded: %d", nrow(prescreen_done_keys)))
log_info(sprintf("summary-tier already-processed keys loaded: %d", nrow(summary_done_keys)))

target_pre <- something_else |>
  anti_join(prescreen_done_keys, by = c("fac", "filename"))

log_info(sprintf("After excluding agenda_prescreen (already processed): %d", nrow(target_pre)))

target <- target_pre |>
  anti_join(summary_done_keys, by = c("fac", "filename"))

log_info(sprintf("After excluding summary-tier (already processed) — REMAINDER TARGET SET: %d", nrow(target)))

target <- target |>
  select(fac, hospital_name, filename, local_path) |>
  distinct()

missing_path <- target |> filter(is.na(local_path) | local_path == "")
if (nrow(missing_path) > 0) {
  log_warning(sprintf("No local_path for %d remainder documents — check llm_run1_results.csv", nrow(missing_path)))
  print(missing_path |> select(fac, hospital_name, filename))
}

resolve_path <- function(local_path) {
  if (is.na(local_path) || local_path == "") return(NA_character_)
  if (str_detect(local_path, "^[A-Za-z]:")) return(local_path)  # already absolute
  file.path(PROJECT_ROOT, local_path)
}

target <- target |>
  filter(!is.na(local_path), local_path != "") |>
  mutate(local_path_abs = vapply(local_path, resolve_path, character(1)))

log_info(sprintf("Remainder documents with resolved path, ready for extraction: %d", nrow(target)))

# ── 3. Structural detection functions (duplicated from minutes_classify.R) ────
# Whole-document versions kept for Section 5's final classify_document() call,
# which runs against the full concatenated extracted range — where percentage
# slicing is valid. Page-level variants below are for per-page boundary
# detection only.
#
# UNCHANGED from the validated agenda_prescreen version — see design notes at
# top of file for the active-voice call-to-order gap known but not ported.

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

# ── Date detector — header must co-occur with an actual date ─────────────────
detect_date_page <- function(page_text) {
  date_pattern <- paste0(
    "(january|february|march|april|may|june|july|august|september|october|",
    "november|december)\\s+\\d{1,2},?\\s+\\d{4}",
    "|\\d{4}-\\d{2}-\\d{2}",
    "|\\d{1,2}/\\d{1,2}/\\d{2,4}"
  )
  str_detect(str_to_lower(page_text), date_pattern)
}

# ── Page-level header — phrase + date, same page ──────────────────────────────
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

# ── Name-list detector — attendance keyword + real names ──────────────────────
# Operates on ORIGINAL-CASE page_text (not lowered) since Title-Case matching
# needs case preserved; keyword search uses inline case-insensitive character
# classes for the same reason. The bare attendance keyword alone matches
# agenda item titles ("Regrets" as a line-item label) with zero names
# attached — this is the fix: require a real run of Title-Case two-word
# sequences within `window` characters of the keyword.
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
# Requires "call(ed) ... to order" to co-occur with an actual clock time
# within ~150 characters. A real minutes narrative sentence has this
# ("called the meeting to order at 6:32 p.m."); an agenda line item
# ("1. Call to Order"), slide deck, or motions-summary document does not.
# FIX (July 6, ported from minutes_extract_summary.R): the original pattern
# required "call(ed)" and "to order" to sit immediately adjacent, matching
# only the passive construction ("was called to order"). Confirmed against
# FAC 858 (Michael Garron) that the active construction ("The Chair called
# the meeting to order at 1605H") — with "the meeting" intervening — was
# never matched, and this same gap was empirically confirmed as the dominant
# failure mode across the SomethingElse remainder batch (210 of 215
# documents came back no_start_detected on the first remainder run; only the
# 4 Quinte documents, which use the passive construction, passed). Broadened
# to tolerate up to 3 intervening lowercase words, matching the fix already
# validated on Oak Valley (FAC 905, 69/69 after this same change).
detect_call_to_order_page <- function(page_text) {
  text_lower <- str_to_lower(page_text)
  positions  <- str_locate_all(text_lower, "call(ed)?\\s(?:[a-z]+\\s){0,3}to order")[[1]]
  if (nrow(positions) == 0) return(FALSE)
  
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
    
    # OCR fix: font-substitution 0/O digit misreads sporadically turn
    # "1700h" into "170oh" on some pages. Normalize only within this already-
    # narrow window, only where an 'o' sits between a digit and another
    # digit-or-h, so this can't accidentally rewrite unrelated text elsewhere
    # on the page.
    window <- str_replace_all(window, "(?<=[0-9])o(?=[0-9]|h)", "0")
    
    if (str_detect(window, time_pattern)) return(TRUE)
  }
  FALSE
}

# ── Combined strict start gate — all three signals, same page ─────────────────
# header+date, attendance+name-list, and call-to-order+time must ALL fire on
# the same page. Deliberately strict — see design notes at top of file.
detect_minutes_start_page <- function(page_text) {
  detect_header_page(page_text) &&
    detect_name_list_near(page_text) &&
    detect_call_to_order_page(page_text)
}

# ── Diagnostic helper — test mode only ────────────────────────────────────────
# Prints, per page, which of the three gate signals fired plus a raw text
# snippet — using the ACTUAL tesseract OCR output, not a manual transcription.
# For the Quinte (957) test, watch specifically for pages where minutes
# content sits after other material (reports, correspondence) earlier in the
# same file — the known pattern this test is designed to check.
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
                          attendance_nearby = NA,
                          any_header = NA, any_names = NA,
                          any_call_to_order = NA, any_close = NA) {
    data.frame(
      fac = row$fac, hospital_name = row$hospital_name, filename = row$filename,
      local_path = pdf_path,
      minutes_page_start = start, minutes_page_end = end,
      n_pages_extracted = n_pages, full_text = full_text,
      doc_class = doc_class, corpus_include = corpus_include,
      attendance_nearby = attendance_nearby,
      any_header = any_header, any_names = any_names,
      any_call_to_order = any_call_to_order, any_close = any_close,
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
  
  # ── Whole-document diagnostic flags (added July 6, remainder-batch audit) ────
  # Computed across ALL pages regardless of whether the same-page start gate
  # succeeds below. Purpose: make a stuck no_start_detected or
  # no_close_detected row auditable at a glance. If all four signals are
  # present SOMEWHERE in the document but the strict same-page gate still
  # didn't fire, that's a gate-logic miss worth a second look (this is
  # exactly the FAC 858 / Michael Garron pattern — header, names, and close
  # were all present, only call-to-order was missed, on a page where all
  # three of the OTHER signals did co-occur). A row with all four FALSE is a
  # genuine non-minutes document, not a detection failure.
  any_header        <- any(vapply(pages, detect_header_page, logical(1)))
  any_names         <- any(vapply(pages, detect_name_list_near, logical(1)))
  any_call_to_order <- any(vapply(pages, detect_call_to_order_page, logical(1)))
  any_close         <- any(vapply(pages, detect_close_page, logical(1)))
  
  # ── Start detection: strict same-page combination of header+date, ────────────
  # attendance+name-list, and call-to-order+time.
  start_hits <- vapply(pages, detect_minutes_start_page, logical(1))
  start_idx  <- which(start_hits)[1]
  
  if (is.na(start_idx)) {
    return(make_result(qa_flag = "no_start_detected",
                       any_header = any_header, any_names = any_names,
                       any_call_to_order = any_call_to_order, any_close = any_close))
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
                       attendance_nearby = attendance_nearby,
                       any_header = any_header, any_names = any_names,
                       any_call_to_order = any_call_to_order, any_close = any_close))
  }
  
  end_idx <- start_idx + close_rel - 1
  
  full_text  <- paste(pages[start_idx:end_idx], collapse = "\n\n--- PAGE BREAK ---\n\n")
  word_count <- length(str_split(str_squish(full_text), "\\s+")[[1]])
  cls        <- classify_document(full_text, word_count)
  
  make_result(
    start = start_idx, end = end_idx, n_pages = end_idx - start_idx + 1,
    full_text = full_text, doc_class = cls$doc_class,
    corpus_include = cls$corpus_include,
    attendance_nearby = attendance_nearby,
    any_header = any_header, any_names = any_names,
    any_call_to_order = any_call_to_order, any_close = any_close
  )
}

# ── 5b. Single-document/single-hospital test mode filter ──────────────────────
if (!is.null(TEST_FAC)) {
  target <- target |> filter(fac == as.character(TEST_FAC))
  if (!is.null(TEST_FILENAME)) {
    target <- target |> filter(filename == TEST_FILENAME)
  }
  if (nrow(target) == 0) {
    stop(sprintf("TEST_FAC %s / TEST_FILENAME %s matched no rows in remainder target set — check spelling, or confirm this FAC wasn't already excluded (941/975/summary-tier/agenda_prescreen)",
                 TEST_FAC, ifelse(is.null(TEST_FILENAME), "(any)", TEST_FILENAME)))
  }
  log_info(sprintf("TEST MODE — running on %d document(s) only", nrow(target)))
}

OUTPUT_FILE_ACTUAL <- if (!is.null(TEST_FAC)) {
  "roles/minutes/outputs/minutes_extract_remainder_TEST.rds"
} else {
  OUTPUT_FILE
}

# ── 5c. Checkpoint-resume ──────────────────────────────────────────────────────
# Added July 6 (post-Quinte confirmation), before the first full remainder run.
# Without this, any interruption mid-run (crash, sleep, anything) meant
# reprocessing every document from the top — OCR is expensive enough across a
# few hundred documents that this needed fixing before letting the full batch
# run unattended.
#
# On startup: if OUTPUT_FILE_ACTUAL already exists on disk, load it and treat
# its fac+filename pairs as already done. `target` is reduced to only the
# documents NOT already present in that file, so a re-run after an
# interruption picks up where it left off rather than restarting. If nothing
# needs resuming (fresh run, or output file doesn't exist yet),
# existing_results is an empty 0-row frame and target is untouched.
existing_results <- if (file.exists(OUTPUT_FILE_ACTUAL)) {
  prior <- readRDS(OUTPUT_FILE_ACTUAL) |> mutate(fac = as.character(fac))
  log_info(sprintf("Existing output found at %s — %d documents already processed, resuming from checkpoint",
                   OUTPUT_FILE_ACTUAL, nrow(prior)))
  prior
} else {
  log_info("No existing output file found — starting fresh (no checkpoint to resume from)")
  data.frame()
}

if (nrow(existing_results) > 0) {
  before_n <- nrow(target)
  target <- target |>
    anti_join(existing_results |> select(fac, filename), by = c("fac", "filename"))
  log_info(sprintf("After excluding already-checkpointed documents: %d remaining (was %d)",
                   nrow(target), before_n))
}

if (nrow(target) == 0) {
  log_info("Nothing left to process — all target documents already present in output file.")
}

# ── 6. Run extraction loop ──────────────────────────────────────────────────────
log_info(sprintf("Beginning extraction — %d documents", nrow(target)))

results_list <- vector("list", nrow(target))

if (nrow(target) > 0) {
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
    
    # Checkpoint every 10 documents. Written as existing_results (already-done,
    # from a prior run) PLUS everything processed so far this run — so a crash
    # partway through never loses more than the last <10 documents' progress,
    # and the file on disk is always a valid, resumable superset.
    if (i %% 10 == 0L) {
      checkpoint <- bind_rows(existing_results, bind_rows(results_list[1:i]))
      saveRDS(checkpoint, OUTPUT_FILE_ACTUAL)
      log_info(sprintf("Checkpoint written at document %d / %d (%d total in file, including resumed)",
                       i, nrow(target), nrow(checkpoint)))
    }
  }
}

# BUG FIX (July 6): the prior version of this script referenced an object
# called `results` in this section and in Section 7 below, but the loop above
# only ever built `results_list` (and, every 10th iteration, a transient
# `checkpoint`). `results` was never assigned, so the final saveRDS() and the
# summary block would have errored out at the end of any real run. Combining
# results_list into `results` here is the fix. Also folds in existing_results
# (checkpoint-resume, added same day) so a resumed run's final output contains
# every document ever processed for this batch, not just this session's.
results <- bind_rows(existing_results, bind_rows(results_list))

saveRDS(results, OUTPUT_FILE_ACTUAL)
log_info(sprintf("Extraction complete — %d documents written to %s", nrow(results), OUTPUT_FILE_ACTUAL))

# ── 7. Summary ───────────────────────────────────────────────────────────────
cat("\n══════════════════════════════════════════════════════\n")
cat("  SOMETHINGELSE REMAINDER EXTRACTION — SUMMARY\n")
cat("══════════════════════════════════════════════════════\n\n")
cat(sprintf("Total processed:         %d\n", nrow(results)))
cat(sprintf("  corpus_include TRUE:   %d\n", sum(results$corpus_include, na.rm = TRUE)))
cat(sprintf("  no_start_detected:     %d  (needs manual review)\n",
            sum(results$qa_flag == "no_start_detected", na.rm = TRUE)))
cat(sprintf("  no_close_detected:     %d  (needs manual review)\n",
            sum(results$qa_flag == "no_close_detected", na.rm = TRUE)))
cat(sprintf("  file_missing:          %d\n", sum(results$qa_flag == "file_missing", na.rm = TRUE)))
cat(sprintf("  ocr_failed:            %d\n", sum(results$qa_flag == "ocr_failed", na.rm = TRUE)))

# Among stuck (no_start_detected / no_close_detected) rows, how many have
# ALL four structural signals present somewhere in the document — a strong
# hint of a gate-logic miss (like FAC 858) rather than a genuine non-minutes
# document. Worth checking first during manual review.
stuck <- results |> filter(qa_flag %in% c("no_start_detected", "no_close_detected"))
if (nrow(stuck) > 0) {
  all_four_present <- stuck |>
    filter(any_header, any_names, any_call_to_order, any_close)
  cat(sprintf("\nAmong %d stuck documents: %d have ALL FOUR signals present somewhere\n",
              nrow(stuck), nrow(all_four_present)))
  cat("  in the document (check these first — likely gate-logic misses, not genuine non-minutes):\n")
  if (nrow(all_four_present) > 0) {
    print(all_four_present |> select(fac, hospital_name, filename, qa_flag))
  }
}