# minutes_extract_summary.R
# Purpose: Extract and flag summary/highlights minutes for FAC 905 (Oak Valley),
# 736 (Newmarket Southlake), 967 (Cornwall Community, primary), 644 (Cornwall
# Hotel Dieu, duplicate_of 967). SomethingElse-bucket documents containing
# genuine but abbreviated board-highlights/meeting-summary content.
#
# Start gate: header+summary-phrase+date AND (call-to-order+time OR narrative
# meeting-held+date). Name-list dropped — summary docs don't reliably carry a
# full attendee list.
#
# END-OF-DOCUMENT HANDLING — DELIBERATE EXCEPTION TO STANDING PROJECT
# PRINCIPLE: minutes_extract_prescreen.R explicitly rejects silent EOF
# fallback (no close detected = flagged for manual review, never
# auto-extracted to end of file). This script departs from that rule, scoped
# ONLY to the four summary-tier hospitals: the FAC 967 test batch (37 docs)
# returned 34/37 no_close_detected against a real adjournment/next-meeting
# regex, and manual review of the Cornwall documents confirmed they simply
# end after the highlights content — no boilerplate, appendix, or unrelated
# material follows that a close gate would be protecting against. Given that,
# requiring a close signal here would just discard genuine content. Once a
# start page is detected, extraction runs from start_idx to end of document,
# no close check at all. This assumption was validated against Cornwall
# (967/644) and is expected to hold for Oak Valley (905) and Southlake (736)
# based on Skip's spot-check, but has not been separately confirmed against
# their documents yet — worth a quick manual glance at the first few 905/736
# extractions once run, same as any other new pattern in this pipeline.
#
# Annual Meeting documents (3 of 37 in the FAC 967 test batch) correctly fail
# the start gate — they don't use the Board Highlights header/summary-phrase
# format this script looks for, and Skip has confirmed they're out of scope
# for this workstream. They remain flagged as no_start_detected rather than
# silently dropped, with a best-effort is_annual_meeting tag for traceability.
#
# Run from: E:/HospitalIntelligenceR (project root)

rm(list = ls())

library(dplyr)
library(stringr)
library(pdftools)
library(tesseract)

source("core/logger.R")
init_logger(role = "minutes")

RESULTS_FILE <- "roles/minutes/outputs/llm_run1_results.csv"
OUTPUT_FILE  <- "roles/minutes/outputs/minutes_extract_summary_results.rds"
PROJECT_ROOT <- "E:/HospitalIntelligenceR"
OCR_DPI      <- 300

SUMMARY_FACS <- c("905", "967", "644", "736")

# Single-document test mode — same convention as minutes_extract_prescreen.R
TEST_FAC <-"736"; TEST_FILENAME <- NULL

# ── 1. Target set ────────────────────────────────────────────────────────────
results_all <- read.csv(RESULTS_FILE, stringsAsFactors = FALSE) |>
  mutate(fac = as.character(fac))

target <- results_all |>
  filter(fac %in% SUMMARY_FACS, classification == "SomethingElse") |>
  select(fac, hospital_name, filename, local_path)

log_info(sprintf("Summary-minutes candidates across %d hospitals: %d documents",
                 length(SUMMARY_FACS), nrow(target)))
print(target |> count(fac, hospital_name))

resolve_path <- function(local_path) {
  if (is.na(local_path)) return(NA_character_)
  if (str_detect(local_path, "^[A-Za-z]:")) return(local_path)
  file.path(PROJECT_ROOT, local_path)
}

target <- target |>
  mutate(local_path_abs = vapply(local_path, resolve_path, character(1)))

# ── 2. Detection functions ────────────────────────────────────────────────────
detect_date_page <- function(page_text) {
  date_pattern <- paste0(
    "(january|february|march|april|may|june|july|august|september|october|",
    "november|december)\\s+\\d{1,2},?\\s+\\d{4}",
    "|\\d{4}-\\d{2}-\\d{2}",
    "|\\d{1,2}/\\d{1,2}/\\d{2,4}"
  )
  str_detect(str_to_lower(page_text), date_pattern)
}

# Header variant requiring a summary/highlights phrase (not the standard
# minutes-header set). Deliberately REQUIRES the summary phrase — this gate is
# meant to isolate the summary tier, not catch full minutes that happen to
# mention "summary" somewhere on the page.
detect_header_page_summary <- function(page_text) {
  has_summary_phrase <- str_detect(
    str_to_lower(page_text),
    paste0(
      "board highlights|", "meeting highlights|", "highlights of the meeting|",
      "board meeting summary|", "meeting summary|", "summary of the board|",
      "summary minutes|", "summary of proceedings|", "summary of the meeting"
    )
  )
  has_summary_phrase && detect_date_page(page_text)
}

# Formal call-to-order anchor — Oak Valley (905) style: "called the meeting to
# order at 6:16 p.m."
# Call-to-order anchor — Oak Valley (905) style. Broadened: allows up to 3
# intervening lowercase words between "call(ed)" and "to order," rather than
# requiring exact adjacency. The original pattern only matched a passive
# construction ("was called to order") — CMH and Windsor happen to phrase it
# that way, but Oak Valley uses an active construction ("called the meeting
# to order at 5:00 p.m."), where "the meeting" sits between "called" and "to
# order" and the exact-adjacency pattern never fired despite being a clear,
# unambiguous match on manual read.
detect_call_to_order_page <- function(page_text) {
  text_lower <- str_to_lower(page_text)
  positions  <- str_locate_all(text_lower, "call(ed)?\\s(?:[a-z]+\\s){0,3}to order")[[1]]
  if (nrow(positions) == 0) return(FALSE)
  time_pattern <- paste0(
    "\\d{1,2}:\\d{2}\\s*(a\\.?m\\.?|p\\.?m\\.?)",
    "|\\d{3,4}\\s*h(rs|ours)?\\b",
    "|\\d{1,2}:\\d{2}\\s*h(rs|ours)?\\b",
    "|\\b\\d{1,2}:\\d{2}\\b"
  )
  for (i in seq_len(nrow(positions))) {
    win_start <- max(1, positions[i, "start"] - 150)
    win_end   <- min(nchar(text_lower), positions[i, "end"] + 150)
    window    <- str_sub(text_lower, win_start, win_end)
    window    <- str_replace_all(window, "(?<=[0-9])o(?=[0-9]|h)", "0")
    if (str_detect(window, time_pattern)) return(TRUE)
  }
  FALSE
}

# Narrative "meeting was held" opening statement — Cornwall (967/644): "held a
# meeting on October 8, 2020"; Southlake (736): "A meeting of the ... Board of
# Directors was held on ...".
detect_meeting_held_page <- function(page_text, window = 150) {
  text_lower <- str_to_lower(page_text)
  positions <- str_locate_all(
    text_lower,
    paste0(
      "held (a |its |the )?meeting on|",
      "meeting .{0,100}was held on"
    )
  )[[1]]
  if (nrow(positions) == 0) return(FALSE)
  for (i in seq_len(nrow(positions))) {
    win_start <- positions[i, "start"]
    win_end   <- min(nchar(text_lower), win_start + window)
    if (detect_date_page(str_sub(text_lower, win_start, win_end))) return(TRUE)
  }
  FALSE
}

# Second signal accepts EITHER construction — call-to-order+time (Oak Valley)
# OR narrative meeting-held+date (Cornwall/Southlake).
detect_meeting_open_page <- function(page_text) {
  detect_call_to_order_page(page_text) || detect_meeting_held_page(page_text)
}

detect_summary_start_page <- function(page_text) {
  detect_header_page_summary(page_text) && detect_meeting_open_page(page_text)
}

# Best-effort tag only — does not gate anything, just labels why a page
# failed the start gate when it looks like an Annual Meeting document.
detect_annual_meeting_page <- function(page_text) {
  str_detect(str_to_lower(page_text), "annual (general )?meeting")
}

print_page_diagnostics_summary <- function(pages) {
  for (i in seq_along(pages)) {
    hdr <- detect_header_page_summary(pages[i])
    opn <- detect_meeting_open_page(pages[i])
    cat(sprintf("\n--- Page %d ---  header_summary=%s  meeting_open=%s\n", i, hdr, opn))
    if (hdr || opn) cat(str_sub(pages[i], 1, 800), "\n")
  }
}

# ── 3. OCR extraction (identical to minutes_extract_prescreen.R) ─────────────
extract_pages <- function(pdf_path, dpi = OCR_DPI) {
  eng <- tesseract::tesseract("eng")
  tryCatch({
    images <- pdftools::pdf_convert(pdf_path, format = "png", dpi = dpi, verbose = FALSE)
    on.exit(unlink(images), add = TRUE)
    unlist(lapply(images, function(img_path) tesseract::ocr(img_path, engine = eng)))
  }, error = function(e) {
    log_warning(sprintf("extract_pages: OCR failed for %s — %s", basename(pdf_path), conditionMessage(e)))
    character(0)
  })
}

# ── 4. Per-document processing ────────────────────────────────────────────────
# NOTE: no close/adjournment check in this script — see header comment.
# Extraction runs from the detected start page to the end of the document.
process_document_summary <- function(row) {
  pdf_path <- row$local_path_abs
  
  make_result <- function(start = NA_integer_, end = NA_integer_, n_pages = NA_integer_,
                          full_text = NA_character_, corpus_include = FALSE,
                          qa_flag = NA_character_, is_annual_meeting = NA) {
    data.frame(
      fac = row$fac, hospital_name = row$hospital_name, filename = row$filename,
      local_path = pdf_path,
      minutes_page_start = start, minutes_page_end = end,
      n_pages_extracted = n_pages, full_text = full_text,
      doc_class = "summary_minutes",
      corpus_include = corpus_include,
      is_duplicate_of = ifelse(row$fac == "644", "967", NA_character_),
      is_annual_meeting = is_annual_meeting,
      qa_flag = qa_flag, stringsAsFactors = FALSE
    )
  }
  
  if (is.na(pdf_path) || !file.exists(pdf_path)) {
    log_warning(sprintf("File not found: %s", pdf_path))
    return(make_result(qa_flag = "file_missing"))
  }
  
  pages <- extract_pages(pdf_path)
  n_pages <- length(pages)
  if (n_pages == 0) return(make_result(qa_flag = "ocr_failed"))
  
  start_hits <- vapply(pages, detect_summary_start_page, logical(1))
  start_idx  <- which(start_hits)[1]
  
  if (is.na(start_idx)) {
    is_annual <- any(vapply(pages, detect_annual_meeting_page, logical(1)))
    return(make_result(qa_flag = "no_start_detected", is_annual_meeting = is_annual))
  }
  
  # No close check — extract to end of document (see header note).
  end_idx   <- n_pages
  full_text <- paste(pages[start_idx:end_idx], collapse = "\n\n--- PAGE BREAK ---\n\n")
  
  make_result(start = start_idx, end = end_idx,
              n_pages = end_idx - start_idx + 1,
              full_text = full_text, corpus_include = TRUE,
              is_annual_meeting = FALSE)
}

# ── 5. Test-mode filter ───────────────────────────────────────────────────────
if (!is.null(TEST_FAC)) {
  target <- target |> filter(fac == as.character(TEST_FAC))
  if (!is.null(TEST_FILENAME)) target <- target |> filter(filename == TEST_FILENAME)
  log_info(sprintf("TEST MODE — %d document(s)", nrow(target)))
}

OUTPUT_FILE_ACTUAL <- if (!is.null(TEST_FAC)) {
  "roles/minutes/outputs/minutes_extract_summary_TEST.rds"
} else OUTPUT_FILE

# ── 6. Run loop ────────────────────────────────────────────────────────────────
results_list <- vector("list", nrow(target))
for (i in seq_len(nrow(target))) {
  row <- target[i, ]
  cat(sprintf("[%2d/%d] FAC %-4s  %s\n", i, nrow(target), row$fac, row$filename))
  if (!is.null(TEST_FAC)) {
    diag_pages <- extract_pages(row$local_path_abs)
    print_page_diagnostics_summary(diag_pages)
  }
  results_list[[i]] <- process_document_summary(row)
  cat(sprintf("        corpus_include=%-5s qa_flag=%s\n",
              results_list[[i]]$corpus_include,
              ifelse(is.na(results_list[[i]]$qa_flag), "none", results_list[[i]]$qa_flag)))
  if (i %% 10 == 0L) {
    saveRDS(bind_rows(results_list[1:i]), OUTPUT_FILE_ACTUAL)
    log_info(sprintf("Checkpoint at %d/%d", i, nrow(target)))
  }
}

results <- bind_rows(results_list)
saveRDS(results, OUTPUT_FILE_ACTUAL)

cat("\n══════ SUMMARY-MINUTES EXTRACTION — RESULTS ══════\n")
cat(sprintf("Total processed:      %d\n", nrow(results)))
cat(sprintf("  corpus_include:     %d\n", sum(results$corpus_include, na.rm = TRUE)))
cat(sprintf("  no_start_detected:  %d\n", sum(results$qa_flag == "no_start_detected", na.rm = TRUE)))
cat(sprintf("    of which annual: %d\n", sum(results$is_annual_meeting, na.rm = TRUE)))
print(results |> count(fac, hospital_name, corpus_include))