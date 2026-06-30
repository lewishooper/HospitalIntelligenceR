# llm_run1_classify.R
# Purpose: Full corpus Stage 1 classification of all board minutes PDFs.
#          Runs the validated pipeline (R prescreen + LLM) over every document
#          in minutes_index.csv and writes a corpus-level results CSV.
#
# Architecture:
#   Stage 1 pipeline: OCR → prescreen_document() → classify_document_llm()
#   - prescreen_document() handles high-confidence SomethingElse cases
#     deterministically (standalone AGENDA heading). LLM call is skipped.
#   - classify_document_llm() handles all remaining documents.
#   - False negatives (uncertain documents) are expected and acceptable —
#     they will be reviewed in Stage 2. False positives are the expensive error.
#
# Resumability:
#   If the run is interrupted, set RESUME <- TRUE. The script will skip any
#   document already present in the output CSV and continue from where it
#   left off.
#
# Prerequisites:
#   - Ollama running on Ubuntu, network-exposed on port 11434
#   - llama3.1:8b loaded (confirm with: ollama ps)
#   - R packages: httr2, jsonlite, tesseract, pdftools, magick, dplyr, stringr
#
# Run from: E:/HospitalIntelligenceR  (project root)
# Input:    roles/minutes/outputs/minutes_index.csv
#           roles/minutes/outputs/extracted/  (PDF archive)
# Output:   roles/minutes/outputs/llm_run1_results.csv
#           roles/minutes/outputs/llm_run1_missing.csv  (files not found on disk)

rm(list = ls())

library(httr2)
library(jsonlite)
library(tesseract)
library(pdftools)
library(magick)
library(dplyr)
library(stringr)

source("core/logger.R")
init_logger(role = "minutes")

`%||%` <- function(a, b) if (!is.null(a)) a else b

# ── Config ─────────────────────────────────────────────────────────────────────
UBUNTU_IP    <- "192.168.3.112"
OLLAMA_URL   <- paste0("http://", UBUNTU_IP, ":11434/api/generate")
MODEL        <- "llama3.1:8b"

EXTRACT_DIR  <- "roles/minutes/outputs/extracted"
INDEX_FILE   <- "roles/minutes/outputs/minutes_index.csv"
RESULTS_FILE <- "roles/minutes/outputs/llm_run1_results.csv"
MISSING_FILE <- "roles/minutes/outputs/llm_run1_missing.csv"

OCR_DPI      <- 300L
MAX_WORDS    <- 700L

# Set RESUME <- TRUE to skip already-processed documents and continue a
# previously interrupted run.
RESUME       <- FALSE


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1 — Core pipeline functions
# ══════════════════════════════════════════════════════════════════════════════

# ── 1a. extract_text_ocr() ────────────────────────────────────────────────────
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

# ── 1b. prepare_for_llm() ─────────────────────────────────────────────────────
prepare_for_llm <- function(text, max_words = MAX_WORDS) {
  text_trimmed <- str_trim(text)
  words <- str_split(str_squish(text_trimmed), "\\s+")[[1]]
  if (length(words) <= max_words) return(text_trimmed)
  word_positions <- gregexpr("\\S+", text_trimmed)[[1]]
  if (length(word_positions) < max_words) return(text_trimmed)
  cutoff_start <- word_positions[max_words]
  cutoff_end   <- cutoff_start + attr(word_positions, "match.length")[max_words] - 1
  substr(text_trimmed, 1, cutoff_end)
}

# ── 1c. prescreen_document() ─────────────────────────────────────────────────
# R-side pre-classifier. Runs before LLM call.
# Returns "SomethingElse" (with reason attribute) or NULL (pass to LLM).
#
# Stage 1 signals:
#   Positive guard: MINUTES heading + attendance label → pass to LLM immediately
#   Signal 1: standalone AGENDA heading → SomethingElse
#
# NOTE: Compression signal (consecutive short numbered lines) was validated but
# removed from Stage 1 — it produced a false negative on FAC 939 due to OCR
# interleaving. Reserved for Stage 2 where it can be applied with context.
prescreen_document <- function(text) {

  lines_all  <- str_trim(str_split(text, "\n")[[1]])
  lines_head <- head(lines_all, 40)

  # ── Positive guard ───────────────────────────────────────────────────────────
  # If MINUTES heading + attendance label both present → confirmed minutes
  # signals; skip all negative checks and pass directly to LLM.
  has_minutes_heading  <- any(str_detect(lines_head,
                                regex("\\bMINUTES\\b", ignore_case = TRUE)))
  has_attendance_label <- any(str_detect(lines_head,
                                regex("^(Present|In Attendance|Members Present|
                                       Directors Present|Attendance)\\s*:",
                                      ignore_case = TRUE, comments = TRUE)))
  if (has_minutes_heading && has_attendance_label) {
    return(NULL)
  }

  # ── Signal 1: Standalone AGENDA heading ─────────────────────────────────────
  # Never observed as a standalone heading in genuine board minutes.
  agenda_line <- any(str_detect(lines_head,
                                regex("^AGENDA[:\\s]*$", ignore_case = TRUE)))
  if (agenda_line) {
    result <- "SomethingElse"
    attr(result, "prescreen_reason") <- "standalone AGENDA heading detected"
    return(result)
  }

  NULL
}

# ── 1d. classify_document_llm() ──────────────────────────────────────────────
# Round 3 prompt — validated at 29/30 (96.7%) on curated set and 30/30 on
# random sample blind evaluation (June 26, 2026).
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

  body <- list(model = MODEL, prompt = prompt, stream = FALSE,
               options = list(temperature = 0))

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

  envelope   <- tryCatch(fromJSON(raw_response), error = function(e) NULL)
  model_text <- if (!is.null(envelope) && !is.null(envelope$response)) {
    envelope$response
  } else { raw_response }

  parsed <- tryCatch({
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

  list(classification = as.character(parsed$classification),
       confidence     = as.character(parsed$confidence),
       reasoning      = as.character(parsed$reasoning),
       raw_response   = model_text)
}

# ── 1e. extract_and_classify() ───────────────────────────────────────────────
extract_and_classify <- function(pdf_path, dpi = OCR_DPI) {

  fname <- basename(pdf_path)

  t_ocr_start <- proc.time()["elapsed"]
  raw_text    <- extract_text_ocr(pdf_path, dpi = dpi)
  ocr_time_s  <- round(proc.time()["elapsed"] - t_ocr_start, 2)

  trimmed_text <- prepare_for_llm(raw_text)
  word_count   <- str_count(str_squish(trimmed_text), "\\S+")

  # R-side pre-screen
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
      llm_time_s     = 0,
      prescreen      = reason
    ))
  }

  # LLM classification
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
    llm_time_s     = llm_time_s,
    prescreen      = NA_character_
  )
}


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2 — Connectivity check
# ══════════════════════════════════════════════════════════════════════════════

log_info("Checking Ollama connectivity at %s", OLLAMA_URL)
ping_ok <- tryCatch({
  resp <- request(paste0("http://", UBUNTU_IP, ":11434/api/tags")) |>
    req_timeout(10) |>
    req_perform()
  resp_status(resp) == 200L
}, error = function(e) FALSE)

if (!ping_ok) {
  stop(sprintf("Cannot reach Ollama at %s. Check UBUNTU_IP and that Ollama is running.",
               UBUNTU_IP))
}
log_info("Ollama reachable — proceeding")


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 3 — Load index and resolve file paths
# ══════════════════════════════════════════════════════════════════════════════

log_info("Loading index from %s", INDEX_FILE)

index <- read.csv(INDEX_FILE, stringsAsFactors = FALSE) |>
  mutate(
    fac        = as.character(fac),
    local_path = file.path(EXTRACT_DIR, folder_name, filename)
  )

log_info("Index: %d total rows", nrow(index))

# ── Separate missing files — log and skip ─────────────────────────────────────
missing_files <- index |> filter(!file.exists(local_path))
corpus        <- index |> filter(file.exists(local_path))

if (nrow(missing_files) > 0) {
  log_warning("%d files in index not found on disk — writing to %s",
              nrow(missing_files), MISSING_FILE)
  write.csv(missing_files, MISSING_FILE, row.names = FALSE)
}

log_info("Corpus: %d files present on disk", nrow(corpus))

# ── Resume: skip already-processed documents ──────────────────────────────────
if (RESUME && file.exists(RESULTS_FILE)) {
  already_done <- read.csv(RESULTS_FILE, stringsAsFactors = FALSE)
  corpus <- corpus |>
    filter(!local_path %in% already_done$local_path)
  log_info("RESUME mode: %d documents already processed, %d remaining",
           nrow(already_done), nrow(corpus))
} else {
  already_done <- NULL
}

log_info("Beginning classification — %d documents to process", nrow(corpus))
cat(sprintf("\nCorpus: %d documents  |  Est. time: %.1f hr\n\n",
            nrow(corpus), nrow(corpus) * 20.3 / 3600))


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4 — Classification loop
# ══════════════════════════════════════════════════════════════════════════════
# Results are written to disk every 50 documents so progress is not lost
# if the run is interrupted.

WRITE_INTERVAL <- 50L
results_list   <- vector("list", nrow(corpus))

for (i in seq_len(nrow(corpus))) {

  row      <- corpus[i, ]
  pdf_path <- row$local_path

  cat(sprintf("[%4d/%4d] FAC %-4s  %s\n",
              i, nrow(corpus), row$fac, basename(pdf_path)))

  res <- extract_and_classify(pdf_path)

  cat(sprintf("           got=%-15s conf=%-6s prescreen=%-5s  (ocr=%.1fs llm=%.1fs)\n",
              res$classification, res$confidence,
              if (!is.na(res$prescreen)) "YES" else "no",
              res$ocr_time_s, res$llm_time_s))

  results_list[[i]] <- data.frame(
    fac            = row$fac,
    hospital_name  = row$hospital_name,
    folder_name    = row$folder_name,
    filename       = row$filename,
    local_path     = pdf_path,
    doc_date       = row$doc_date,
    classification = res$classification,
    confidence     = res$confidence,
    reasoning      = res$reasoning,
    prescreen      = res$prescreen,
    ocr_time_s     = res$ocr_time_s,
    llm_time_s     = res$llm_time_s,
    word_count     = res$word_count,
    text_preview   = res$text_preview,
    stringsAsFactors = FALSE
  )

  # Write checkpoint every WRITE_INTERVAL documents
  if (i %% WRITE_INTERVAL == 0L) {
    checkpoint <- bind_rows(c(list(already_done), results_list[1:i]))
    write.csv(checkpoint, RESULTS_FILE, row.names = FALSE)
    log_info("Checkpoint written at document %d / %d", i, nrow(corpus))
  }
}

# Final write — complete results including any remainder after last checkpoint
results <- bind_rows(c(list(already_done), results_list))
write.csv(results, RESULTS_FILE, row.names = FALSE)
log_info("Full results written to: %s", RESULTS_FILE)


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 5 — Corpus summary
# ══════════════════════════════════════════════════════════════════════════════

cat("\n")
cat("══════════════════════════════════════════════════════\n")
cat("  RUN 1 CORPUS CLASSIFICATION — COMPLETE\n")
cat("══════════════════════════════════════════════════════\n\n")

processed <- results |> filter(!is.na(classification))

cat(sprintf("Documents processed:      %d\n",   nrow(processed)))
cat(sprintf("  MinutesOnly:            %d  (%.1f%%)\n",
            sum(processed$classification == "MinutesOnly"),
            100 * mean(processed$classification == "MinutesOnly")))
cat(sprintf("  SomethingElse:          %d  (%.1f%%)\n",
            sum(processed$classification == "SomethingElse"),
            100 * mean(processed$classification == "SomethingElse")))
cat(sprintf("  Pre-screened by R:      %d\n",
            sum(!is.na(processed$prescreen))))
cat(sprintf("  Parse errors:           %d\n",
            sum(processed$classification == "parse_error", na.rm = TRUE)))
cat(sprintf("  API errors:             %d\n",
            sum(processed$classification == "api_error",   na.rm = TRUE)))
cat(sprintf("\nFiles not found on disk:  %d\n", nrow(missing_files)))

mean_total <- mean(processed$ocr_time_s + processed$llm_time_s, na.rm = TRUE)
cat(sprintf("\nMean time/doc: %.1f s\n", mean_total))
cat(sprintf("Total run time: %.1f hr\n",
            sum(processed$ocr_time_s + processed$llm_time_s, na.rm = TRUE) / 3600))

cat("\n── Parse / API errors (review these) ───────────────\n")
errors <- processed |>
  filter(classification %in% c("parse_error", "api_error"))
if (nrow(errors) == 0) {
  cat("  None.\n")
} else {
  print(errors |> select(fac, hospital_name, filename, classification, reasoning))
}

cat("\n══════════════════════════════════════════════════════\n\n")
log_info("Run 1 corpus classification complete — results at %s", RESULTS_FILE)
