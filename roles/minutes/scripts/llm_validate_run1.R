# llm_validate_run1.R
# Purpose: Validate the Run 1 LLM classification prompt against the 30-document
#          hand-labelled set (llm_validation_run1.xlsx). Produces a scored
#          results data frame and a console summary for go/no-go assessment.
#
# Architecture:
#   - Four core functions (extracted from June 22 sessions) are defined in
#     Section 1. These will be promoted to a shared llm_functions.R once the
#     approach is validated.
#   - Section 2 defines the Run 1 prompt.
#   - Section 3 loads the validation set and normalises labels.
#   - Section 4 runs the classification loop with timing.
#   - Section 5 scores results and prints the summary.
#
# Prerequisites:
#   - Ollama running on Ubuntu, network-exposed on port 11434
#   - llama3.1:8b loaded (confirm with: ollama ps)
#   - R packages: httr2, jsonlite, tesseract, pdftools, magick, readxl, dplyr, stringr
#   - UBUNTU_IP substituted with actual LAN IP before running
#
# Run from: E:/HospitalIntelligenceR  (project root)
# Input:    roles/minutes/outputs/llm_validation_run1.xlsx
#           roles/minutes/outputs/extracted/  (PDF archive)
# Output:   roles/minutes/outputs/llm_run1_validation_results.csv  (scored)

#rm(list = ls())

library(httr2)
library(jsonlite)
library(tesseract)
library(pdftools)
library(magick)
library(readxl)
library(dplyr)
library(stringr)
`%||%` <- function(a, b) if (!is.null(a)) a else b
source("core/logger.R")
init_logger(role = "minutes")

# ── Config ─────────────────────────────────────────────────────────────────────

UBUNTU_IP    <- "192.168.3.112"   # e.g. "192.168.1.42"
OLLAMA_URL   <- paste0("http://", UBUNTU_IP, ":11434/api/generate")
MODEL        <- "llama3.1:8b"

EXTRACT_DIR  <- "roles/minutes/outputs/extracted"
VALID_FILE   <- "roles/minutes/outputs/llm_validation_run1.xlsx"
RESULTS_FILE <- "roles/minutes/outputs/llm_run1_validation_results.csv"

OCR_DPI      <- 300L       # default; bump to 400 for confirmed poor scans
MAX_WORDS    <- 700L       # trim target for Run 1 classification prompt


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1 — Core LLM pipeline functions
# ══════════════════════════════════════════════════════════════════════════════

# ── 1a. extract_text_ocr() ────────────────────────────────────────────────────
# Convert PDF pages to images, run Tesseract OCR, collapse to a single string.
# Page breaks are marked with a sentinel so downstream functions can split by
# page if needed (used in Run 2; for Run 1 the full string is consumed directly).
#
# Args:
#   pdf_path  : full path to the PDF file
#   dpi       : rasterisation resolution (default OCR_DPI = 300)
#
# Returns: single character string; pages separated by "\n\n--- PAGE BREAK ---\n\n"
# On error: returns "" and logs a warning.

extract_text_ocr <- function(pdf_path, dpi = OCR_DPI) {

  eng <- tesseract::tesseract("eng")

  pages <- tryCatch({
    images <- pdftools::pdf_convert(pdf_path, format = "png", dpi = dpi,
                                    verbose = FALSE)
    on.exit(unlink(images), add = TRUE)  # clean up temp PNGs

    lapply(images, function(img_path) {
      tesseract::ocr(img_path, engine = eng)
    })
  }, error = function(e) {
    log_warning(sprintf("extract_text_ocr: OCR failed for %s — %s",
                        basename(pdf_path), conditionMessage(e)))
    return(list(""))
  })

  paste(pages, collapse = "\n\n--- PAGE BREAK ---\n\n")
}


# ── 1b. prepare_for_llm() ─────────────────────────────────────────────────────
# Trim extracted text to approximately max_words words for the LLM context.
# For Run 1, classification signals (header, meeting type, attendance block)
# appear within the first page, so the first 700 words are sufficient.
# str_squish is applied for word counting only; the returned text preserves
# original whitespace structure for better OCR readability by the model.
#
# Args:
#   text      : raw OCR text (character)
#   max_words : word ceiling (default MAX_WORDS = 700)
#
# Returns: trimmed character string

prepare_for_llm <- function(text, max_words = MAX_WORDS) {

  text_trimmed <- str_trim(text)

  # Word count on squished version; trim on original to preserve structure
  words <- str_split(str_squish(text_trimmed), "\\s+")[[1]]

  if (length(words) <= max_words) {
    return(text_trimmed)
  }

  # Find the character position of the max_words-th word boundary
  # by re-splitting on whitespace in the trimmed (not squished) version
  word_positions <- gregexpr("\\S+", text_trimmed)[[1]]
  if (length(word_positions) < max_words) {
    return(text_trimmed)
  }

  cutoff_start <- word_positions[max_words]
  cutoff_end   <- cutoff_start + attr(word_positions, "match.length")[max_words] - 1

  substr(text_trimmed, 1, cutoff_end)
}
# ── 1b2. prescreen_document() ─────────────────────────────────────────────────
# R-side pre-classifier that runs on raw OCR text BEFORE the LLM call.
# Detects two high-confidence SomethingElse signals deterministically:
#
#   Signal 1 — Standalone AGENDA heading:
#     The word AGENDA appears on a line by itself (possibly with whitespace)
#     within the first 300 words. This is characteristic of agenda packages
#     and never observed as a standalone heading in genuine board minutes.
#
#   Signal 2 — Numbered line compression:
#     Four or more consecutive short lines (≤80 chars) each beginning with a
#     number (e.g. "1.", "1.1", "2.0") within the first 40 lines. This detects
#     agenda tables that lack an explicit AGENDA heading.
#
# Args:
#   text : raw OCR text (character, pre-trim)
#
# Returns:
#   "SomethingElse" if a signal fires, with a reason attribute
#   NULL if no signal — proceed to LLM
#
# Note: prescreen operates on raw text (not squished) to preserve line structure.
#       It is called before prepare_for_llm() trimming in extract_and_classify().

prescreen_document <- function(text) {
  
  lines_all  <- str_trim(str_split(text, "\n")[[1]])
  lines_head <- head(lines_all, 40)
  
  # ── Positive guard: document declares itself as minutes ──────────────────────
  # If both a MINUTES heading and an attendance label appear in the first 40
  # lines, the document has identified itself as minutes. Skip all negative
  # signals and pass directly to LLM.
  has_minutes_heading  <- any(str_detect(lines_head,
                                         regex("\\bMINUTES\\b", ignore_case = TRUE)))
  has_attendance_label <- any(str_detect(lines_head,
                                         regex("^(Present|In Attendance|Members Present|
                                       Directors Present|Attendance)\\s*:",
                                               ignore_case = TRUE, comments = TRUE)))
  
  if (has_minutes_heading && has_attendance_label) {
    return(NULL)  # confirmed minutes signals — pass to LLM
  }
  
  # ── Signal 1: Standalone AGENDA heading ─────────────────────────────────────
  # A line containing only the word AGENDA (case-insensitive) within the first
  # 40 lines. Characteristic of agenda packages; never observed as a standalone
  # heading in genuine board minutes across the validation set.
  # NOTE: Compression signal removed from Stage 1 — reserved for Stage 2 where
  # it can be applied with fuller document context.
  agenda_line <- any(str_detect(lines_head, regex("^AGENDA[:\\s]*$",
                                                  ignore_case = TRUE)))
  
  if (agenda_line) {
    result <- "SomethingElse"
    attr(result, "prescreen_reason") <- "standalone AGENDA heading detected"
    return(result)
  }
  
  # ── No signal — pass to LLM ─────────────────────────────────────────────────
  NULL
}


# ── 1c. classify_document_llm() ──────────────────────────────────────────────
# Send trimmed text to the Ollama API with the Run 1 classification prompt.
# Returns a list with classification, confidence, and reasoning.
# temperature = 0 is mandatory for reproducibility.
#
# Args:
#   text : trimmed character string from prepare_for_llm()
#
# Returns: list(classification, confidence, reasoning, raw_response)
#          On parse failure: classification = "parse_error", confidence = "low"

classify_document_llm <- function(text) {

  prompt <- paste0(
    "You are classifying hospital governance documents.\n\n",
    
    "Classify the document below as one of two types:\n\n",
    
    "- MinutesOnly: The document is a record of a FULL BOARD OF DIRECTORS meeting. ",
    "To classify as MinutesOnly, ALL THREE of the following structural signals must ",
    "be present:\n",
    "  1. HEADER: A title or heading containing 'Board of Directors' (including joint ",
    "meeting titles such as 'Joint Meeting of the Finance Committee and Board of ",
    "Directors') referencing a past meeting date.\n",
    "  2. ATTENDANCE BLOCK: An explicit, dedicated list of named individuals who ",
    "were PRESENT or IN ATTENDANCE at that meeting, appearing immediately after the ",
    "header. A valid attendance block is grouped under a label such as 'Present:', ",
    "'In Attendance:', 'Members Present:', or 'Directors Present:', with names listed ",
    "in sequence beneath or beside that label.\n",
    "  DOES NOT QUALIFY as an attendance block: names appearing in document footers ",
    "(even if repeated on every page), names in org charts or leadership directories, ",
    "names assigned to agenda items as presenters or contacts, or names scattered ",
    "through the document body without a dedicated grouping label.\n",
    "  3. CLOSING: The document ends at an adjournment statement, a signature block ",
    "(Chair, Secretary), or the natural end of the minutes record with no content ",
    "outside the opening and closing boundaries.\n",
    "Everything between the attendance block and the closing is part of the record — ",
    "committee reports, CEO updates, delegations, and presentations tabled at the ",
    "meeting are all part of the minutes and do NOT disqualify the document.\n\n",
    
    "- SomethingElse: Any document that fails any MinutesOnly criterion. Specifically:\n",
    "  * Documents with NO attendance block — even if a Board of Directors header is ",
    "present. No named attendance list = SomethingElse.\n",
    "  * Documents where the only named individuals appear in footers, org charts, ",
    "leadership directories, or as agenda item presenters — without a dedicated ",
    "grouped attendance list immediately following the Board of Directors header.\n",
    "  * Documents that begin with a FORWARD-LOOKING AGENDA TABLE — a list of agenda ",
    "items with future tense ('to be discussed', 'for approval', 'to be presented') ",
    "or items numbered/bulleted before any attendance block appears. An agenda ",
    "preceding the minutes is not part of the minutes.\n",
    "  * Documents with a SUMMARY FORMAT TITLE — if the document title or opening ",
    "header contains 'Meeting Summary', 'Board Highlights', 'Board Update', ",
    "'Summary of Proceedings', or similar condensed-format language, classify as ",
    "SomethingElse regardless of other signals. These condense rather than record.\n",
    "  * Committee meeting minutes where the header names only a committee (Finance ",
    "Committee, Quality Committee, Joint Conference Committee, or any sub-committee) ",
    "WITHOUT 'Board of Directors' also in the header.\n",
    "  * Standalone agendas, CEO reports, org charts, presentations, or any document ",
    "with no minutes content at all.\n\n",
    
    "CRITICAL RULES:\n",
    "1. The markers '--- PAGE BREAK ---' in the text below are OCR formatting ",
    "artefacts only. They mark page boundaries in the scan and carry NO meaning about ",
    "document structure.\n",
    "2. A joint meeting header such as 'Joint Meeting of the Finance Committee and ",
    "Board of Directors' IS a full board meeting.\n",
    "3. Reports mentioned or tabled WITHIN the minutes body are part of the record. ",
    "Only physically separate documents attached outside the opening/closing ",
    "boundaries disqualify.\n\n",
    
    "Respond ONLY with valid JSON — no other text, no markdown fences:\n",
    "{\"classification\": \"MinutesOnly\" or \"SomethingElse\", ",
    "\"confidence\": \"high\" or \"medium\" or \"low\", ",
    "\"reasoning\": \"one sentence\"}\n\n",
    
    "Document:\n", text
  )
  
  body <- list(
    model   = MODEL,
    prompt  = prompt,
    stream  = FALSE,
    options = list(temperature = 0)
  )

  raw_response <- tryCatch({
    resp <- request(OLLAMA_URL) |>
      req_headers("Content-Type" = "application/json") |>
      req_body_raw(toJSON(body, auto_unbox = TRUE)) |>
      req_timeout(120) |>
      req_perform()
    resp_body_string(resp)
  }, error = function(e) {
    log_warning(sprintf("classify_document_llm: API call failed — %s",
                        conditionMessage(e)))
    return(NULL)
  })

  if (is.null(raw_response)) {
    return(list(classification = "api_error", confidence = "low",
                reasoning = "API call failed", raw_response = ""))
  }

  # Ollama wraps the model reply in a JSON envelope; extract the "response" field
  envelope <- tryCatch(fromJSON(raw_response), error = function(e) NULL)
  model_text <- if (!is.null(envelope) && !is.null(envelope$response)) {
    envelope$response
  } else {
    raw_response
  }

  # Parse the model's JSON reply
  parsed <- tryCatch({
    # Strip any accidental markdown fences the model may have added
    clean <- str_remove_all(model_text, "```json|```")
    fromJSON(str_trim(clean))
  }, error = function(e) NULL)

  if (is.null(parsed) ||
      !all(c("classification", "confidence", "reasoning") %in% names(parsed))) {
    log_warning(sprintf("classify_document_llm: JSON parse failed — raw: %s",
                        str_sub(model_text, 1, 200)))
    return(list(classification = "parse_error", confidence = "low",
                reasoning = "Could not parse model response",
                raw_response = model_text))
  }

  list(
    classification = as.character(parsed$classification),
    confidence     = as.character(parsed$confidence),
    reasoning      = as.character(parsed$reasoning),
    raw_response   = model_text
  )
}


# ── 1d. extract_and_classify() ───────────────────────────────────────────────
# Combined pipeline wrapper: OCR → trim → classify.
# Returns a flat list suitable for coercion to a data frame row.
#
# Args:
#   pdf_path : full path to PDF
#   dpi      : passed to extract_text_ocr()
#
# Returns: list with filename, text_preview (first 200 chars), word_count,
#          classification, confidence, reasoning, ocr_time_s, llm_time_s


extract_and_classify <- function(pdf_path, dpi = OCR_DPI) {
  
  fname <- basename(pdf_path)
  
  # OCR
  t_ocr_start <- proc.time()["elapsed"]
  raw_text    <- extract_text_ocr(pdf_path, dpi = dpi)
  ocr_time_s  <- round(proc.time()["elapsed"] - t_ocr_start, 2)
  
  trimmed_text <- prepare_for_llm(raw_text)
  word_count   <- str_count(str_squish(trimmed_text), "\\S+")
  
  # ── R-side pre-screen (runs before LLM) ────────────────────────────────────
  prescreen_result <- prescreen_document(raw_text)
  
  if (!is.null(prescreen_result)) {
    reason <- attr(prescreen_result, "prescreen_reason") %||% "R prescreen"
    log_info("  PRESCREEN → SomethingElse (%s): %s", reason, fname)
    return(list(
      filename       = fname,
      text_preview   = str_sub(str_squish(raw_text), 1, 200),
      word_count     = word_count,
      classification = "SomethingElse",
      confidence     = "high",
      reasoning      = sprintf("R prescreen: %s", reason),
      raw_response   = "",
      ocr_time_s     = ocr_time_s,
      llm_time_s     = 0
    ))
  }
  
  # ── LLM classification ─────────────────────────────────────────────────────
  t_llm_start <- proc.time()["elapsed"]
  result      <- classify_document_llm(trimmed_text)
  llm_time_s  <- round(proc.time()["elapsed"] - t_llm_start, 2)
  
  list(
    filename       = fname,
    text_preview   = str_sub(str_squish(raw_text), 1, 200),
    word_count     = word_count,
    classification = result$classification,
    confidence     = result$confidence,
    reasoning      = result$reasoning,
    raw_response   = result$raw_response,
    ocr_time_s     = ocr_time_s,
    llm_time_s     = llm_time_s
  )
}

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2 — Connectivity check
# ══════════════════════════════════════════════════════════════════════════════
# Confirm Ollama is reachable before beginning the validation loop.
# If this fails, fix the IP or restart Ollama before proceeding.

log_info("Checking Ollama connectivity at %s", OLLAMA_URL)

ping_ok <- tryCatch({
  resp <- request(paste0("http://", UBUNTU_IP, ":11434/api/tags")) |>
    req_timeout(10) |>
    req_perform()
  resp_status(resp) == 200L
}, error = function(e) {
  FALSE
})

if (!ping_ok) {
  stop(sprintf(
    "Cannot reach Ollama at %s. Check UBUNTU_IP, firewall, and that Ollama is running.",
    UBUNTU_IP
  ))
}
log_info("Ollama reachable — proceeding")


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 3 — Load and prepare the validation set
# ══════════════════════════════════════════════════════════════════════════════

log_info("Loading validation set from %s", VALID_FILE)

val_raw <- readxl::read_excel(VALID_FILE, sheet = 1)

# Normalise column names (Excel may vary case)
names(val_raw) <- str_to_lower(names(val_raw))

val <- val_raw |>
  mutate(
    fac      = as.character(fac),
    seq_num  = as.integer(seq),

    # Canonical label: MinutesOnly | SomethingElse (case-normalised)
    expected = case_when(
      str_to_lower(classification) == "minutesonly"   ~ "MinutesOnly",
      str_to_lower(classification) == "somethingelse" ~ "SomethingElse",
      TRUE ~ NA_character_
    ),

    # Derive local file path from the file:/// URI
    # Converts "file:///E:/HospitalIntelligenceR/roles/minutes/outputs/extracted/..."
    # to a Windows path: "roles/minutes/outputs/extracted/..."
    local_path = str_remove(file, "file:///E:/HospitalIntelligenceR/"),

    hand_label_notes = as.character(notes)
  ) |>
  select(seq_num, fac, filename = file, local_path, expected,
         hand_label_notes)

# Report any rows with unresolvable labels
bad_labels <- val |> filter(is.na(expected))
if (nrow(bad_labels) > 0) {
  log_warning("  %d rows have unrecognised Classification values — check Excel",
              nrow(bad_labels))
  print(bad_labels |> select(seq_num, fac, filename))
}

log_info("Validation set: %d documents (%d MinutesOnly, %d SomethingElse)",
         nrow(val),
         sum(val$expected == "MinutesOnly",  na.rm = TRUE),
         sum(val$expected == "SomethingElse", na.rm = TRUE))


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4 — Classification loop
# ══════════════════════════════════════════════════════════════════════════════
# Runs each document through extract_and_classify() in sequence.
# Console output on each document allows monitoring without waiting for the full
# batch. Paste this output back to the session for joint interpretation.

log_info("Beginning classification — %d documents", nrow(val))
cat("\n")

results_list <- lapply(seq_len(nrow(val)), function(i) {

  row        <- val[i, ]
  pdf_path   <- row$local_path

  cat(sprintf("[%2d/%d] FAC %-4s  %s\n",
              i, nrow(val), row$fac, basename(row$local_path)))

  if (!file.exists(pdf_path)) {
    log_warning("  File not found: %s", pdf_path)
    return(data.frame(
      seq_num          = row$seq_num,
      fac              = row$fac,
      local_path       = row$local_path,
      expected         = row$expected,
      got              = "file_missing",
      confidence       = NA_character_,
      correct          = FALSE,
      reasoning        = "File not found on disk",
      ocr_time_s       = NA_real_,
      llm_time_s       = NA_real_,
      word_count       = NA_integer_,
      text_preview     = NA_character_,
      hand_label_notes = row$hand_label_notes,
      stringsAsFactors = FALSE
    ))
  }

  res <- extract_and_classify(pdf_path)

  correct <- !is.na(row$expected) &&
             res$classification == row$expected

  cat(sprintf("        expected=%-15s got=%-15s conf=%-8s correct=%s  (ocr=%.1fs llm=%.1fs)\n",
              row$expected, res$classification, res$confidence,
              if (correct) "YES" else "NO ",
              res$ocr_time_s, res$llm_time_s))

  data.frame(
    seq_num          = row$seq_num,
    fac              = row$fac,
    local_path       = row$local_path,
    expected         = row$expected,
    got              = res$classification,
    confidence       = res$confidence,
    correct          = correct,
    reasoning        = res$reasoning,
    ocr_time_s       = res$ocr_time_s,
    llm_time_s       = res$llm_time_s,
    word_count       = res$word_count,
    text_preview     = res$text_preview,
    hand_label_notes = row$hand_label_notes,
    stringsAsFactors = FALSE
  )
})

results <- bind_rows(results_list)

# Save results immediately — do not wait for scoring to complete
write.csv(results, RESULTS_FILE, row.names = FALSE)
log_info("Raw results written to: %s", RESULTS_FILE)


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 5 — Scoring summary
# ══════════════════════════════════════════════════════════════════════════════

cat("\n")
cat("══════════════════════════════════════════════════════\n")
cat("  RUN 1 VALIDATION SCORING SUMMARY\n")
cat("══════════════════════════════════════════════════════\n\n")

scoreable <- results |> filter(!is.na(expected), got != "file_missing",
                                got != "api_error", got != "parse_error")

# ── Overall accuracy ──────────────────────────────────────────────────────────
n_total   <- nrow(scoreable)
n_correct <- sum(scoreable$correct)
pct_all   <- round(100 * n_correct / n_total, 1)

cat(sprintf("Overall accuracy:  %d / %d  (%.1f%%)\n\n", n_correct, n_total, pct_all))

# ── By confidence tier ────────────────────────────────────────────────────────
cat("By confidence tier:\n")
conf_summary <- scoreable |>
  group_by(confidence) |>
  summarise(
    n         = n(),
    n_correct = sum(correct),
    pct       = round(100 * n_correct / n, 1),
    .groups = "drop"
  ) |>
  arrange(desc(pct))

print(conf_summary, row.names = FALSE)

# Pass criteria from feasibility plan:
#   ≥95% at high confidence
#   ≥90% at high + medium combined
high_acc    <- conf_summary |> filter(confidence == "high") |> pull(pct)
hi_med_rows <- scoreable   |> filter(confidence %in% c("high", "medium"))
hi_med_acc  <- round(100 * sum(hi_med_rows$correct) / nrow(hi_med_rows), 1)

cat(sprintf("\nHigh-confidence accuracy:         %.1f%%  (target ≥95%%)\n", high_acc))
cat(sprintf("High + medium combined accuracy:  %.1f%%  (target ≥90%%)\n\n", hi_med_acc))

# ── Committee-as-MinutesOnly check (zero tolerance) ──────────────────────────
# Any SomethingElse document that the model classified as MinutesOnly is a
# false positive. Amongst these, flag any where hand_label_notes suggests
# committee minutes specifically — these are the highest-risk failure mode.
false_positives <- results |>
  filter(expected == "SomethingElse", got == "MinutesOnly")

cat(sprintf("False positives (SomethingElse → MinutesOnly): %d\n", nrow(false_positives)))
if (nrow(false_positives) > 0) {
  cat("  *** REVIEW REQUIRED — these may include committee minutes misclassifications ***\n")
  print(false_positives |>
    select(seq_num, fac, local_path, confidence, reasoning, hand_label_notes))
}

# ── False negatives ───────────────────────────────────────────────────────────
false_negatives <- results |>
  filter(expected == "MinutesOnly", got == "SomethingElse")

cat(sprintf("\nFalse negatives (MinutesOnly → SomethingElse): %d\n", nrow(false_negatives)))
if (nrow(false_negatives) > 0) {
  print(false_negatives |>
    select(seq_num, fac, local_path, confidence, reasoning, hand_label_notes))
}

# ── Errors and parse failures ─────────────────────────────────────────────────
error_rows <- results |>
  filter(got %in% c("file_missing", "api_error", "parse_error"))

cat(sprintf("\nErrors / failures: %d\n", nrow(error_rows)))
if (nrow(error_rows) > 0) {
  print(error_rows |> select(seq_num, fac, got, reasoning))
}

# ── Speed benchmark ───────────────────────────────────────────────────────────
cat("\nTiming (scoreable documents):\n")
cat(sprintf("  Mean OCR time:  %.1f s\n",  mean(scoreable$ocr_time_s, na.rm = TRUE)))
cat(sprintf("  Max  OCR time:  %.1f s\n",  max(scoreable$ocr_time_s,  na.rm = TRUE)))
cat(sprintf("  Mean LLM time:  %.1f s\n",  mean(scoreable$llm_time_s, na.rm = TRUE)))
cat(sprintf("  Max  LLM time:  %.1f s\n",  max(scoreable$llm_time_s,  na.rm = TRUE)))
mean_total <- mean(scoreable$ocr_time_s + scoreable$llm_time_s, na.rm = TRUE)
cat(sprintf("  Mean total/doc: %.1f s\n",  mean_total))
cat(sprintf("  Projected full corpus (1,732 docs): %.0f min  (%.1f hr)\n",
            1732 * mean_total / 60,
            1732 * mean_total / 3600))

# ── Pass / Fail banner ────────────────────────────────────────────────────────
cat("\n")
cat("══════════════════════════════════════════════════════\n")

pass_high_acc  <- length(high_acc)  > 0 && high_acc  >= 95
pass_combined  <- hi_med_acc >= 90
pass_no_fp     <- nrow(false_positives) == 0

if (pass_high_acc && pass_combined && pass_no_fp) {
  cat("  RESULT: *** PASS *** — Run 1 meets all criteria\n")
  cat("  Proceed to: llm_run1_classify.R (full corpus build)\n")
} else {
  cat("  RESULT: *** FAIL / REVIEW *** — criteria not met\n")
  if (!pass_high_acc)  cat(sprintf("    High-confidence accuracy below 95%% (got %.1f%%)\n", high_acc))
  if (!pass_combined)  cat(sprintf("    High+medium accuracy below 90%% (got %.1f%%)\n", hi_med_acc))
  if (!pass_no_fp)     cat(sprintf("    %d false positive(s) — SomethingElse classified as MinutesOnly\n",
                                   nrow(false_positives)))
  cat("  Next: review misclassifications above, revise prompt, re-run\n")
  cat("  After 2 failed revision rounds: revert to keyword extractor\n")
}

cat("══════════════════════════════════════════════════════\n\n")

log_info("Validation complete — results at %s", RESULTS_FILE)

