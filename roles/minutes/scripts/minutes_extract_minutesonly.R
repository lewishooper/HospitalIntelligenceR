# minutes_extract_minutesonly.R
# Purpose: Extract full_text for the ~1,879 documents Stage 1 (llama3.1:8b)
# classified as "MinutesOnly" — i.e. containing only board minutes content,
# with no embedded agenda, reports, or other material to trim around.
#
# DESIGN — DELIBERATELY SIMPLER THAN THE OTHER THREE EXTRACTION SCRIPTS:
# minutes_extract_prescreen.R, minutes_extract_summary.R, and the remainder
# script all exist to find WHERE minutes content begins and ends WITHIN a
# mixed document (agenda + minutes, or minutes + reports). MinutesOnly
# documents don't have that problem by construction — Stage 1's whole job
# was separating documents that are only minutes from documents that mix
# minutes with other material (SomethingElse). Per the project's Stage 1
# design principle ("intentionally conservative toward false positives —
# false negatives cheap, false positives expensive"), a MinutesOnly
# classification should be a genuinely trustworthy signal that the whole
# document is minutes content, start to finish.
#
# So: NO start-page gate, NO close-page gate, NO same-page signal
# combination. Every page of every document is OCR'd and concatenated as
# full_text. classify_document() (identical logic to
# minutes_extract_prescreen.R) still runs against the full text, but ONLY as
# a QA/diagnostic tag (doc_class), not as a corpus_include gate — every
# document here defaults to corpus_include = TRUE unless word_count is
# implausibly low, which is the one thing this script actually checks for.
#
# QA FLAG — LOW WORD COUNT: if a "MinutesOnly" document comes back with an
# implausibly low word count (< MIN_WORD_COUNT), that's a signal Stage 1's
# classification may have been wrong for this specific document (e.g. a
# short agenda-only or cover-page document misclassified), OCR genuinely
# failed to extract readable text, or the document is real but unusually
# short (e.g. a brief special-meeting notice). Flagged for manual review
# (qa_flag = "low_word_count"), not silently excluded or silently included.
#
# THIS ASSUMPTION HAS NOT BEEN VALIDATED YET. Same discipline as every other
# script in this pipeline: TEST_FAC is set below for a single-hospital
# spot-check before the full batch runs. If the low-word-count flag or a
# manual spot-check surfaces documents that Stage 1 should NOT have called
# MinutesOnly (i.e. genuinely mixed content), that is a signal Stage 1's
# false-positive rate on this bucket needs a harder look — not something to
# patch around here with new gating logic. Escalate rather than quietly add
# start/end detection back into this script.
#
# Run from: E:/HospitalIntelligenceR (project root)

rm(list = ls())

library(dplyr)
library(stringr)
library(pdftools)
library(tesseract)

source("core/logger.R")
init_logger(role = "minutes")

RESULTS_FILE  <- "roles/minutes/outputs/llm_run1_results.csv"
OUTPUT_FILE   <- "roles/minutes/outputs/minutes_extract_minutesonly_results.rds"
PROJECT_ROOT  <- "E:/HospitalIntelligenceR"
OCR_DPI       <- 300
MIN_WORD_COUNT <- 150   # below this, flag for manual review rather than trust Stage 1's label blind

# Single-document/single-hospital test mode — same convention as the other
# three extraction scripts. MUST be run before the full ~1,879-document
# batch, since this script's core assumption (MinutesOnly = trustworthy,
# no gating needed) has not yet been spot-checked against real output.
TEST_FAC      <- "957"   # placeholder — replace with a hospital you can manually verify quickly before the overnight run
TEST_FILENAME <- NULL

# ── 1. Target set ──────────────────────────────────────────────────────────────
results_all <- read.csv(RESULTS_FILE, stringsAsFactors = FALSE) |>
  mutate(fac = as.character(fac))

target <- results_all |>
  filter(classification == "MinutesOnly") |>
  select(fac, hospital_name, filename, local_path) |>
  distinct()

log_info(sprintf("MinutesOnly documents (all hospitals): %d", nrow(target)))

resolve_path <- function(local_path) {
  if (is.na(local_path) || local_path == "") return(NA_character_)
  if (str_detect(local_path, "^[A-Za-z]:")) return(local_path)
  file.path(PROJECT_ROOT, local_path)
}

target <- target |>
  filter(!is.na(local_path), local_path != "") |>
  mutate(local_path_abs = vapply(local_path, resolve_path, character(1)))

log_info(sprintf("MinutesOnly documents with resolved path: %d", nrow(target)))

# ── 2. Structural detection — QA TAGGING ONLY, not a gate ─────────────────────
# Identical logic to minutes_extract_prescreen.R's whole-document detectors.
# Used here purely to set doc_class for downstream tier/analysis use — every
# document defaults to corpus_include = TRUE regardless of what these return.
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

classify_document <- function(text, word_count) {
  if (word_count < 50) {
    return("needs_ocr")
  }
  hdr <- detect_header(text)
  att <- detect_attendance(text)
  mot <- detect_motions(text)
  
  if (hdr && att && mot) {
    "minutes"
  } else if (hdr && att && !mot) {
    "summary_minutes"
  } else if (hdr && !att && !mot) {
    "agenda"   # worth a look if this shows up at all in a MinutesOnly-labelled document
  } else {
    "other"
  }
}

# ── 3. OCR extraction (identical to the other three scripts) ─────────────────
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

# ── 4. Per-document processing — no boundary gate ─────────────────────────────
process_document_minutesonly <- function(row) {
  pdf_path <- row$local_path_abs
  
  make_result <- function(n_pages = NA_integer_, full_text = NA_character_,
                          doc_class = NA_character_, corpus_include = FALSE,
                          word_count = NA_integer_, qa_flag = NA_character_) {
    data.frame(
      fac = row$fac, hospital_name = row$hospital_name, filename = row$filename,
      local_path = pdf_path,
      minutes_page_start = if (is.na(n_pages)) NA_integer_ else 1L,
      minutes_page_end   = n_pages,
      n_pages_extracted  = n_pages, full_text = full_text,
      doc_class = doc_class, corpus_include = corpus_include,
      word_count = word_count,
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
  
  full_text  <- paste(pages, collapse = "\n\n--- PAGE BREAK ---\n\n")
  word_count <- length(str_split(str_squish(full_text), "\\s+")[[1]])
  cls        <- classify_document(full_text, word_count)
  
  if (word_count < MIN_WORD_COUNT) {
    # Flagged for manual review, but NOT excluded — the point is visibility,
    # not a silent gate. See header note on what a low count might mean.
    return(make_result(n_pages = n_pages, full_text = full_text, doc_class = cls,
                       corpus_include = TRUE, word_count = word_count,
                       qa_flag = "low_word_count"))
  }
  
  make_result(n_pages = n_pages, full_text = full_text, doc_class = cls,
              corpus_include = TRUE, word_count = word_count)
}

# ── 5. Test-mode filter ───────────────────────────────────────────────────────
if (!is.null(TEST_FAC)) {
  target <- target |> filter(fac == as.character(TEST_FAC))
  if (!is.null(TEST_FILENAME)) target <- target |> filter(filename == TEST_FILENAME)
  if (nrow(target) == 0) {
    stop(sprintf("TEST_FAC %s matched no MinutesOnly rows — check spelling, or confirm this hospital has MinutesOnly documents", TEST_FAC))
  }
  log_info(sprintf("TEST MODE — %d document(s)", nrow(target)))
}

OUTPUT_FILE_ACTUAL <- if (!is.null(TEST_FAC)) {
  "roles/minutes/outputs/minutes_extract_minutesonly_TEST.rds"
} else OUTPUT_FILE

# ── 5b. Skip already-processed documents (checkpoint-resume) ─────────────────
existing_results <- data.frame()
if (file.exists(OUTPUT_FILE_ACTUAL)) {
  existing_results <- readRDS(OUTPUT_FILE_ACTUAL) |> mutate(fac = as.character(fac))
  log_info(sprintf("Existing output found — %d documents already processed, resuming",
                   nrow(existing_results)))
  before_n <- nrow(target)
  target <- target |>
    anti_join(existing_results |> select(fac, filename), by = c("fac", "filename"))
  log_info(sprintf("After excluding already-processed documents: %d remaining (was %d)",
                   nrow(target), before_n))
}

# ── 6. Run extraction loop ──────────────────────────────────────────────────────
log_info(sprintf("Beginning MinutesOnly extraction — %d documents", nrow(target)))

results_list <- vector("list", nrow(target))

if (nrow(target) > 0) {
  for (i in seq_len(nrow(target))) {
    row <- target[i, ]
    cat(sprintf("[%4d/%d] FAC %-4s  %s\n", i, nrow(target), row$fac, row$filename))
    
    results_list[[i]] <- process_document_minutesonly(row)
    cat(sprintf("          doc_class=%-15s word_count=%-6s qa_flag=%s\n",
                results_list[[i]]$doc_class, results_list[[i]]$word_count,
                ifelse(is.na(results_list[[i]]$qa_flag), "none", results_list[[i]]$qa_flag)))
    
    if (i %% 10 == 0L) {
      checkpoint <- bind_rows(existing_results, bind_rows(results_list[1:i]))
      saveRDS(checkpoint, OUTPUT_FILE_ACTUAL)
      log_info(sprintf("Checkpoint written at document %d / %d (%d total in file)",
                       i, nrow(target), nrow(checkpoint)))
    }
  }
}

results <- bind_rows(existing_results, bind_rows(results_list))
saveRDS(results, OUTPUT_FILE_ACTUAL)
log_info(sprintf("Extraction complete — %d documents written to %s", nrow(results), OUTPUT_FILE_ACTUAL))

# ── 7. Summary ───────────────────────────────────────────────────────────────
cat("\n══════════════════════════════════════════════════════\n")
cat("  MINUTESONLY EXTRACTION — SUMMARY\n")
cat("══════════════════════════════════════════════════════\n\n")
cat(sprintf("Total processed:         %d\n", nrow(results)))
cat(sprintf("  corpus_include TRUE:   %d\n", sum(results$corpus_include, na.rm = TRUE)))
cat(sprintf("  low_word_count:        %d  (included, but flagged for manual review)\n",
            sum(results$qa_flag == "low_word_count", na.rm = TRUE)))
cat(sprintf("  file_missing:          %d\n", sum(results$qa_flag == "file_missing", na.rm = TRUE)))
cat(sprintf("  ocr_failed:            %d\n", sum(results$qa_flag == "ocr_failed", na.rm = TRUE)))
cat(sprintf("\ndoc_class breakdown (QA tag only — did not gate inclusion):\n"))
print(results |> filter(!is.na(doc_class)) |> count(doc_class, sort = TRUE))