# minutes_classify.R
# Purpose: Text extraction and structural classification for all PDFs in the
#          board minutes archive. Produces minutes_corpus_audit.csv — one row
#          per PDF with doc_class, word count, structural flags, and QA signals.
#
# Design basis: T1-S1 hand-labelling of 39 PDFs (June 13, 2026)
# Key findings from labelling that shape this classifier:
#   - "Summary" is a real doc_class: minutes where motions are absent but the
#     structural header and attendance blocks are intact. corpus_include = TRUE.
#     Observed at FACs 858, 905, 967, 644 — mostly Community Large.
#   - Consent agenda is near-universal (35/37 corpus-include docs used it).
#     Detection must capture variants: "Items for Approval", "Consent Agenda".
#   - FAC 661 scraper error: v23/v49 files are non-minutes content. These will
#     be correctly classified as "other" by the structural classifier.
#   - type_group "Other" in registry (FACs 781, 927, 939): valid minutes;
#     classification proceeds normally.
#   - meeting_type "special" was logged with a trailing backtick in one row —
#     regex output is always stripped of trailing whitespace/punctuation.
#   - All yearonly-dated files in the sample were genuine minutes; the yearonly
#     suffix reflects date inference ambiguity only, not content.
#
# Run from: E:/HospitalIntelligenceR  (project root)
# Input:    roles/minutes/outputs/minutes_index.csv
#           roles/minutes/outputs/extracted/  (PDF archive)
# Output:   roles/minutes/outputs/minutes_corpus_audit.csv

rm(list = ls())

library(dplyr)
library(stringr)
library(pdftools)

source("core/logger.R")
init_logger(role = "minutes")
# ── Config ─────────────────────────────────────────────────────────────────────
EXTRACT_DIR  <- "roles/minutes/outputs/extracted"
INDEX_FILE   <- "roles/minutes/outputs/minutes_index.csv"
AUDIT_FILE   <- "roles/minutes/outputs/minutes_corpus_audit.csv"

# Minimum word count to attempt structural classification (below this → thin flag)
THIN_THRESHOLD <- 100L

# ── 1. Load index ──────────────────────────────────────────────────────────────
log_info("Loading minutes_index.csv")
idx <- read.csv(INDEX_FILE, stringsAsFactors = FALSE) |>
  mutate(fac = as.character(fac))

log_info("Index: %d rows across %d hospitals", nrow(idx), n_distinct(idx$fac))

# ── 2. Structural detection functions ─────────────────────────────────────────
# Each function takes the full extracted text (single character string, all pages
# concatenated) and returns TRUE/FALSE. Patterns are derived from T1-S1 labelling.

# Header block: title-position keywords in the first 300 words.
# "open session" covers Ontario hospitals that explicitly label the public portion.
detect_header <- function(text) {
  head_text <- str_sub(text, 1, 1500)  # approx first 300 words
  str_detect(
    str_to_lower(head_text),
    paste0(
      "minutes of|",
      "board of directors|",
      "board meeting|",
      "open session|",
      "meeting of the board|",
      "regular meeting|",
      "special meeting|",
      "annual meeting|",
      "annual general meeting"
    )
  )
}

# Attendance block: member listing or quorum statement, within first 40% of doc.
# "in attendance" captures both members and staff sections.

detect_attendance <- function(text) {
  att_text <- str_sub(text, 1, nchar(text) * 0.40)
  str_detect(
    str_to_lower(att_text),
    paste0(
      "members present|",
      "board members present|",
      "directors present|",
      "in attendance|",
      "also in attendance|",
      "regrets:|",
      "regrets /|",
      "quorum (confirmed|declared|established|achieved)|",
      "quorum was established|",
      "there was a quorum|",           # FAC 858: inline quorum confirmation
      "confirmed that there was|",     # FAC 858: variant
      "\\bpresent:|",                  # with colon
      "\\bpresent\\b|",               # FAC 709: PRESENT without colon
      "\\bregrets\\b|",               # FAC 709: REGRETS without colon
      "staff present|",               # FAC 709: STAFF PRESENT header
      "anson general hospital|",
      "bingham memorial hospital|",
      "lady minto hospital"
    )
  )
}

# Motions block: at least one recorded motion or resolution anywhere in document.
# "be it resolved" and "resolved that" are common in Ontario hospital minutes.
# "items for approval" and "consent agenda" motions are captured by consent detection.
detect_motions <- function(text) {
  str_detect(
    str_to_lower(text),
    paste0(
      "moved by|",
      "seconded by|",
      "\\bcarried\\b|",
      "\\bdefeated\\b|",
      "be it resolved|",
      "resolved that|",
      "motion (that|to)|",
      "\\bmotion:\\b|",
      "it was moved"
    )
  )
}

# Close block: adjournment or next meeting note, within the last 15% of doc.
detect_close <- function(text) {
  close_text <- str_sub(text, nchar(text) * 0.85, nchar(text))
  str_detect(
    str_to_lower(close_text),
    paste0(
      "\\badjourned\\b|",
      "meeting adjourned|",
      "next meeting|",
      "next regular meeting|",
      "there being no further business"
    )
  )
}

# Consent agenda: near-universal in corpus (35/37 labelled corpus-include docs).
# Captures standard label and common Ontario hospital variants.
detect_consent_agenda <- function(text) {
  str_detect(
    str_to_lower(text),
    paste0(
      "consent agenda|",
      "items for approval|",
      "consent items|",
      "items on consent|",
      "approve.{1,30}consent"
    )
  )
}

# Summary minutes: header + attendance present but motions absent.
# These are valid corpus documents — labelled as such in T1-S1 (FACs 858, 905, 967, 644).
# The classifier assigns doc_class = "summary_minutes" and corpus_include = TRUE.

# Report markers: keywords in header position suggest this is a CEO/committee report.
detect_report_lead <- function(text) {
  head_text <- str_to_lower(str_sub(text, 1, 1500))
  str_detect(
    head_text,
    paste0(
      "ceo report|",
      "chief executive officer report|",
      "president.{1,10}ceo report|",
      "committee report|",
      "financial statements|",
      "quality improvement plan|",
      "annual report"
    )
  )
}

# ── 3. Meeting type extraction ─────────────────────────────────────────────────
# Keyword match on the header region. "special" before "regular" to avoid
# "regular" matching inside "irregularly scheduled special meeting" etc.
extract_meeting_type <- function(text) {
  head_text <- str_to_lower(str_sub(text, 1, 1500))
  if (str_detect(head_text, "annual general meeting|agm|annual meeting of"))  return("annual")
  if (str_detect(head_text, "special meeting|called meeting"))                return("special")
  if (str_detect(head_text, "regular meeting|regular board"))                 return("regular")
  if (str_detect(head_text, "in.camera|in camera|closed session"))            return("in_camera")
  return("unknown")
}

# ── 4. Classification logic ───────────────────────────────────────────────────
# Combines structural flags into a doc_class and corpus_include decision.
#
# Hierarchy (in order of precedence):
#   needs_ocr        → empty text (< 50 chars after trim)
#   other            → report_lead markers AND no structural pattern
#   mixed            → has_header + has_attendance + has_motions, AND report_lead
#                      markers also present (minutes bundled with other material)
#   minutes          → has_header + has_attendance + has_motions
#   summary_minutes  → has_header + has_attendance, motions absent
#                      (T1-S1 confirmed: these are valid abbreviated records)
#   agenda           → has_header, no attendance, no motions
#   other            → fallback

classify_document <- function(text, word_count) {

  if (word_count < 50) {
    return(list(
      doc_class        = "needs_ocr",
      corpus_include   = FALSE,
      has_header       = NA,
      has_attendance   = NA,
      has_motions      = NA,
      has_close        = NA,
      has_consent      = NA,
      meeting_type     = NA_character_
    ))
  }

  hdr  <- detect_header(text)
  att  <- detect_attendance(text)
  mot  <- detect_motions(text)
  cls  <- detect_close(text)
  cons <- detect_consent_agenda(text)
  rep  <- detect_report_lead(text)
  mtyp <- extract_meeting_type(text)

  # Classification
  if (!hdr && !att && !mot && rep) {
    doc_class <- "report"
    corpus_include <- FALSE
  } else if (hdr && att && mot && rep) {
    # Both structural pattern AND report markers — bundled package
    doc_class <- "mixed"
    corpus_include <- TRUE
  } else if (hdr && att && mot) {
    doc_class <- "minutes"
    corpus_include <- TRUE
  } else if (hdr && att && !mot) {
    # Summary minutes — header and attendance intact, motions absent
    # T1-S1 confirmed these as valid corpus documents
    doc_class <- "summary_minutes"
    corpus_include <- TRUE
  } else if (hdr && !att && !mot) {
    doc_class <- "agenda"
    corpus_include <- FALSE
  } else {
    doc_class <- "other"
    corpus_include <- FALSE
  }

  list(
    doc_class      = doc_class,
    corpus_include = corpus_include,
    has_header     = hdr,
    has_attendance = att,
    has_motions    = mot,
    has_close      = cls,
    has_consent    = cons,
    meeting_type   = mtyp
  )
}

# ── 5. Main processing loop ───────────────────────────────────────────────────
log_info("Beginning classification pass — %d PDFs", nrow(idx))

results <- bind_rows(lapply(seq_len(nrow(idx)), function(i) {

  row         <- idx[i, ]
  fac         <- as.character(row$fac)
  folder      <- as.character(row$folder_name)
  fname       <- as.character(row$filename)
  local_path  <- file.path(EXTRACT_DIR, folder, fname)

  # ── File check ──────────────────────────────────────────────────────────────
  if (!file.exists(local_path)) {
    log_warning("FAC %s: file not found — %s", fac, fname)
    return(data.frame(
      fac              = fac,
      hospital_name    = as.character(row$hospital_name),
      folder_name      = folder,
      filename         = fname,
      doc_date         = as.character(row$doc_date),
      file_size_kb     = as.numeric(row$file_size_kb),
      word_count       = NA_integer_,
      doc_class        = "file_missing",
      corpus_include   = FALSE,
      has_header       = NA,
      has_attendance   = NA,
      has_motions      = NA,
      has_close        = NA,
      has_consent_agenda = NA,
      meeting_type     = NA_character_,
      is_thin          = NA,
      qa_flags         = "file_missing",
      stringsAsFactors = FALSE
    ))
  }

  # ── Text extraction ─────────────────────────────────────────────────────────
  text_raw <- tryCatch(
    paste(pdftools::pdf_text(local_path), collapse = "\n\n"),
    error = function(e) {
      log_warning("FAC %s: pdf_text() failed — %s | %s", fac, fname, conditionMessage(e))
      ""
    }
  )

  text_clean <- str_squish(text_raw)
  word_count <- str_count(text_clean, "\\S+")

  # ── Classify ────────────────────────────────────────────────────────────────
  cls <- classify_document(text_clean, word_count)

  # ── QA flags ────────────────────────────────────────────────────────────────
  qa <- character(0)
  if (word_count < THIN_THRESHOLD && cls$doc_class != "needs_ocr") qa <- c(qa, "thin")
  if (grepl("_yearonly\\.pdf$", fname))                             qa <- c(qa, "yearonly_date")
  if (grepl("_v\\d+\\.pdf$", fname))                               qa <- c(qa, "version_suffix")

  if (i %% 100 == 0) log_info("Progress: %d / %d", i, nrow(idx))

  data.frame(
    fac               = fac,
    hospital_name     = as.character(row$hospital_name),
    folder_name       = folder,
    filename          = fname,
    doc_date          = as.character(row$doc_date),
    file_size_kb      = as.numeric(row$file_size_kb),
    word_count        = word_count,
    doc_class         = cls$doc_class,
    corpus_include    = cls$corpus_include,
    has_header        = cls$has_header,
    has_attendance    = cls$has_attendance,
    has_motions       = cls$has_motions,
    has_close         = cls$has_close,
    has_consent_agenda = cls$has_consent,
    meeting_type      = cls$meeting_type,
    is_thin           = word_count < THIN_THRESHOLD,
    qa_flags          = if (length(qa) == 0) "" else paste(qa, collapse = "; "),
    stringsAsFactors  = FALSE
  )
}))

# ── 6. Summary diagnostics ─────────────────────────────────────────────────────
log_info("Classification complete — %d rows", nrow(results))

cat("\n=== doc_class distribution ===\n")
print(table(results$doc_class))

cat("\n=== corpus_include ===\n")
print(table(results$corpus_include))

cat("\n=== QA flags (non-empty) ===\n")
print(table(results$qa_flags[results$qa_flags != ""]))

cat("\n=== needs_ocr by hospital ===\n")
ocr_cases <- results |>
  filter(doc_class == "needs_ocr") |>
  count(fac, hospital_name, name = "n_ocr") |>
  arrange(desc(n_ocr))
if (nrow(ocr_cases) > 0) print(ocr_cases) else cat("  None\n")

cat("\n=== corpus_include = FALSE summary ===\n")
print(results |>
  filter(!corpus_include) |>
  count(doc_class) |>
  arrange(desc(n)))

# ── 7. Write output ────────────────────────────────────────────────────────────
write.csv(results, AUDIT_FILE, row.names = FALSE)
log_info("Audit written to: %s", AUDIT_FILE)
log_info("Corpus-include rows: %d of %d (%.1f%%)",
         sum(results$corpus_include), nrow(results),
         100 * mean(results$corpus_include))
