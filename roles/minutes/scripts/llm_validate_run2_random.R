# llm_validate_run2_random.R
# Purpose: Random-sample blind evaluation of the Run 1 classification pipeline
#          (R pre-screen + LLM). Draws 30 documents from minutes_index.csv,
#          runs the full pipeline, and saves results for blind hand-evaluation.
#
# BLIND EVALUATION PROTOCOL:
#   1. Source this script — it runs the model and writes results to CSV.
#   2. Open the output CSV. The 'got' column shows model classifications.
#   3. Review each file WITHOUT looking at 'got' first — record your label
#      in the 'hand_label' column, then compare.
#   4. Bring the completed CSV back to the session for joint scoring.
#
# Sampling design:
#   - 20 documents drawn at random from the full corpus (stratified by FAC
#     so no single hospital dominates)
#   - 10 documents drawn from hospitals flagged as difficult format cases
#     (BoardPro layouts, known mixed packages, multi-column designs)
#   The two strata are combined and deduplicated before running.
#
# Prerequisites:
#   - Ollama running on Ubuntu, network-exposed on port 11434
#   - llama3.1:8b loaded (confirm with: ollama ps)
#   - R packages: httr2, jsonlite, tesseract, pdftools, magick, dplyr, stringr
#   - minutes_index.csv present at the path below
#
# Run from: E:/HospitalIntelligenceR  (project root)
# Input:    roles/minutes/outputs/minutes_index.csv
#           roles/minutes/outputs/extracted/  (PDF archive)
# Output:   roles/minutes/outputs/llm_run2_random_results.csv

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
RESULTS_FILE <- "roles/minutes/outputs/llm_run2_random_results.csv"

OCR_DPI      <- 300L
MAX_WORDS    <- 700L

SEED_RANDOM  <- 2026L    # change to reshuffle random stratum
SEED_HARD    <- 9999L    # change to reshuffle hard-case stratum
N_RANDOM     <- 20L      # random stratum size
N_HARD       <- 10L      # hard-case stratum size

# FACs known to have difficult formats:
#   695  Kingston Providence Care  — two-panel column design
#   714  London St. Joseph's       — two-column with membership panel
#   826  Kenora Lake of the Woods  — three-column agenda/discussion/action
#   661  Cambridge Memorial        — large agenda package (known FP)
#   935  Thunder Bay Regional      — large agenda package (known FP)
#   953  Sunnybrook                — org chart (known FP)
#   940  Cobourg Northumberland    — regular but older format
#   624  Campbellford              — annual meeting variant
HARD_FACS <- c("695", "714", "826", "661", "935", "953", "940", "624",
               "709", "719")   # 709/719 = smaller rural hospitals

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1 — Core pipeline functions (copied from llm_validate_run1.R)
# ══════════════════════════════════════════════════════════════════════════════
# NOTE: Once Run 1 is finalised, these will be promoted to a shared
# llm_functions.R. For now they are copied here to keep this script
# self-contained and runnable independently.

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
# R-side pre-classifier. Returns "SomethingElse" (with reason attribute) or NULL.
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

# ── 1d. classify_document_llm() ──────────────────────────────────────────────
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
    return(list(filename = fname,
                text_preview   = str_sub(str_squish(raw_text), 1, 200),
                word_count     = word_count,
                classification = "SomethingElse",
                confidence     = "high",
                reasoning      = sprintf("R prescreen: %s", reason),
                raw_response   = "",
                ocr_time_s     = ocr_time_s,
                llm_time_s     = 0,
                prescreen      = reason))
  }

  t_llm_start <- proc.time()["elapsed"]
  result      <- classify_document_llm(trimmed_text)
  llm_time_s  <- round(proc.time()["elapsed"] - t_llm_start, 2)

  list(filename       = fname,
       text_preview   = str_sub(str_squish(raw_text), 1, 200),
       word_count     = word_count,
       classification = result$classification,
       confidence     = result$confidence,
       reasoning      = result$reasoning,
       raw_response   = result$raw_response,
       ocr_time_s     = ocr_time_s,
       llm_time_s     = llm_time_s,
       prescreen      = NA_character_)
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
# SECTION 3 — Build sample
# ══════════════════════════════════════════════════════════════════════════════

log_info("Loading index from %s", INDEX_FILE)
index <- read.csv(INDEX_FILE, stringsAsFactors = FALSE) |>
  mutate(fac = as.character(fac),
         local_path = file.path(EXTRACT_DIR, folder_name, filename))

# Restrict to files that exist on disk
index_exists <- index |>
  filter(file.exists(local_path))

log_info("Index: %d total rows, %d files present on disk",
         nrow(index), nrow(index_exists))

# ── Stratum A: Random sample (one file per FAC, then sample FACs) ─────────────
# Sample one document per FAC first, then draw N_RANDOM FACs — this prevents
# high-volume hospitals (e.g. large teaching centres with 50+ files) from
# dominating the random stratum.
set.seed(SEED_RANDOM)

stratum_random <- index_exists |>
  filter(!fac %in% HARD_FACS) |>       # hard-case FACs handled separately
  group_by(fac) |>
  slice_sample(n = 1) |>               # one doc per FAC
  ungroup() |>
  slice_sample(n = min(N_RANDOM, n())) |>
  mutate(stratum = "random")

log_info("Stratum A (random): %d documents from %d hospitals",
         nrow(stratum_random), n_distinct(stratum_random$fac))

# ── Stratum B: Hard-case FACs ─────────────────────────────────────────────────
set.seed(SEED_HARD)

stratum_hard <- index_exists |>
  filter(fac %in% HARD_FACS) |>
  group_by(fac) |>
  slice_sample(n = 1) |>               # one doc per hard FAC
  ungroup() |>
  slice_sample(n = min(N_HARD, n())) |>
  mutate(stratum = "hard_case")

log_info("Stratum B (hard cases): %d documents from %d hospitals",
         nrow(stratum_hard), n_distinct(stratum_hard$fac))

# ── Combine and deduplicate ───────────────────────────────────────────────────
sample_df <- bind_rows(stratum_random, stratum_hard) |>
  distinct(local_path, .keep_all = TRUE) |>
  arrange(stratum, fac) |>
  mutate(sample_seq = row_number())

log_info("Final sample: %d documents (%d random, %d hard-case)",
         nrow(sample_df),
         sum(sample_df$stratum == "random"),
         sum(sample_df$stratum == "hard_case"))

cat("\n── Sample manifest ───────────────────────────────────────────────────────\n")
print(sample_df |> select(sample_seq, stratum, fac, hospital_name, filename),
      n = nrow(sample_df))
cat("─────────────────────────────────────────────────────────────────────────\n\n")


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4 — Classification loop
# ══════════════════════════════════════════════════════════════════════════════

log_info("Beginning classification — %d documents", nrow(sample_df))
cat("\n")

results_list <- lapply(seq_len(nrow(sample_df)), function(i) {

  row      <- sample_df[i, ]
  pdf_path <- row$local_path

  cat(sprintf("[%2d/%d] FAC %-4s  %-12s  %s\n",
              i, nrow(sample_df), row$fac, row$stratum, basename(pdf_path)))

  if (!file.exists(pdf_path)) {
    log_warning("  File not found: %s", pdf_path)
    return(data.frame(
      sample_seq   = row$sample_seq,
      stratum      = row$stratum,
      fac          = row$fac,
      hospital_name= row$hospital_name,
      filename     = row$filename,
      local_path   = pdf_path,
      got          = "file_missing",
      confidence   = NA_character_,
      reasoning    = "File not found on disk",
      prescreen    = NA_character_,
      ocr_time_s   = NA_real_,
      llm_time_s   = NA_real_,
      word_count   = NA_integer_,
      text_preview = NA_character_,
      hand_label   = NA_character_,   # filled in by Skip during blind review
      hand_notes   = NA_character_,   # filled in by Skip during blind review
      stringsAsFactors = FALSE
    ))
  }

  res <- extract_and_classify(pdf_path)

  cat(sprintf("        got=%-15s conf=%-8s prescreen=%s  (ocr=%.1fs llm=%.1fs)\n",
              res$classification, res$confidence,
              if (!is.na(res$prescreen)) "YES" else "no ",
              res$ocr_time_s, res$llm_time_s))

  data.frame(
    sample_seq   = row$sample_seq,
    stratum      = row$stratum,
    fac          = row$fac,
    hospital_name= row$hospital_name,
    filename     = row$filename,
    local_path   = pdf_path,
    got          = res$classification,
    confidence   = res$confidence,
    reasoning    = res$reasoning,
    prescreen    = res$prescreen,
    ocr_time_s   = res$ocr_time_s,
    llm_time_s   = res$llm_time_s,
    word_count   = res$word_count,
    text_preview = res$text_preview,
    hand_label   = NA_character_,   # filled in by Skip during blind review
    hand_notes   = NA_character_,   # filled in by Skip during blind review
    stringsAsFactors = FALSE
  )
})

results <- bind_rows(results_list)

# Save immediately
write.csv(results, RESULTS_FILE, row.names = FALSE)
log_info("Results written to: %s", RESULTS_FILE)


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 5 — Run summary (no scoring — blind evaluation not yet complete)
# ══════════════════════════════════════════════════════════════════════════════

cat("\n")
cat("══════════════════════════════════════════════════════\n")
cat("  RUN 2 RANDOM SAMPLE — CLASSIFICATION COMPLETE\n")
cat("══════════════════════════════════════════════════════\n\n")

cat(sprintf("Documents classified:  %d\n", nrow(results)))
cat(sprintf("  MinutesOnly:         %d\n", sum(results$got == "MinutesOnly",  na.rm = TRUE)))
cat(sprintf("  SomethingElse:       %d\n", sum(results$got == "SomethingElse", na.rm = TRUE)))
cat(sprintf("  Pre-screened (R):    %d\n", sum(!is.na(results$prescreen),     na.rm = TRUE)))
cat(sprintf("  Errors:              %d\n",
            sum(results$got %in% c("file_missing","api_error","parse_error"), na.rm = TRUE)))

mean_total <- mean(results$ocr_time_s + results$llm_time_s, na.rm = TRUE)
cat(sprintf("\nMean total/doc: %.1f s\n", mean_total))
cat(sprintf("Projected full corpus (1,732 docs): %.0f min  (%.1f hr)\n",
            1732 * mean_total / 60,
            1732 * mean_total / 3600))

cat("\n── Next step ────────────────────────────────────────\n")
cat("  Open:", RESULTS_FILE, "\n")
cat("  Review each file at local_path WITHOUT looking at 'got'.\n")
cat("  Record your label in hand_label (MinutesOnly / SomethingElse).\n")
cat("  Add notes in hand_notes for any ambiguous documents.\n")
cat("  Return the completed CSV for joint scoring.\n")
cat("══════════════════════════════════════════════════════\n\n")

log_info("Run 2 random sample complete — awaiting blind evaluation")
