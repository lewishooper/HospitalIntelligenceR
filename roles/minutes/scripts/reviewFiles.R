# ReviewFile.R
# Purpose: Diagnostic sampling tool for manual review of PDF classifications.
#          Given a FAC, picks a random sample of files from the extraction folder
#          and displays key classification fields plus the opening text of each PDF.
#
# Usage:   Set FAC, N_SAMPLE, and N_WORDS below, then source the script.
# Output:  Console display only — no files written.
#
# Run from: E:/HospitalIntelligenceR (project root)

rm(list = ls())

library(dplyr)
library(stringr)
library(pdftools)
rm(list=ls())
# ── Parameters — adjust these ──────────────────────────────────────────────────
FAC      <- "935"   # FAC code to review (character)
N_SAMPLE <- 3       # Number of files to sample (set to Inf to see all)
N_WORDS  <- 500     # Number of words to extract from the start of each PDF
SEED     <- 42      # Random seed for reproducibility (change to reshuffle)
# ──────────────────────────────────────────────────────────────────────────────

EXTRACT_DIR <- "E:/HospitalIntelligenceR/roles/minutes/outputs/extracted"
AUDIT_FILE  <- "E:/HospitalIntelligenceR/roles/minutes/outputs/minutes_corpus_audit.csv"

# ── Load audit for classification context ─────────────────────────────────────
audit <- read.csv(AUDIT_FILE, stringsAsFactors = FALSE) |>
  mutate(fac = as.character(fac))

# ── Find extraction folder for this FAC ───────────────────────────────────────
all_folders <- list.dirs(EXTRACT_DIR, full.names = FALSE, recursive = FALSE)
fac_folders <- all_folders[str_starts(all_folders, paste0(FAC, "_"))]

if (length(fac_folders) == 0) {
  stop(sprintf("No extraction folder found for FAC %s", FAC))
}

# Use the folder with the most files if duplicates exist
folder_counts <- sapply(fac_folders, function(f) {
  length(list.files(file.path(EXTRACT_DIR, f)))
})
fac_folder <- fac_folders[which.max(folder_counts)]

cat(sprintf("FAC %s — folder: %s\n", FAC, fac_folder))

# ── Get file list ─────────────────────────────────────────────────────────────
all_files <- list.files(file.path(EXTRACT_DIR, fac_folder), pattern = "\\.pdf$")

if (length(all_files) == 0) {
  stop(sprintf("No PDF files found in folder: %s", fac_folder))
}

cat(sprintf("Total PDFs in folder: %d\n", length(all_files)))

# ── Sample ────────────────────────────────────────────────────────────────────
set.seed(SEED)
n <- min(N_SAMPLE, length(all_files))
sampled_files <- sample(all_files, n)

cat(sprintf("Sampling %d file(s) — seed %d\n\n", n, SEED))
cat(strrep("=", 80), "\n\n")

# ── Process each sampled file ─────────────────────────────────────────────────
for (fname in sampled_files) {
  
  full_path <- file.path(EXTRACT_DIR, fac_folder, fname)
  
  # Pull classification from audit
  audit_row <- audit |>
    filter(fac == FAC, filename == fname)
  
  if (nrow(audit_row) == 0) {
    doc_class      <- "NOT IN AUDIT"
    corpus_include <- NA
    has_header     <- NA
    has_attendance <- NA
    has_motions    <- NA
    has_consent    <- NA
    meeting_type   <- NA
    hospital_name  <- "unknown"
    word_count     <- NA
  } else {
    doc_class      <- audit_row$doc_class[1]
    corpus_include <- audit_row$corpus_include[1]
    has_header     <- audit_row$has_header[1]
    has_attendance <- audit_row$has_attendance[1]
    has_motions    <- audit_row$has_motions[1]
    has_consent    <- audit_row$has_consent_agenda[1]
    meeting_type   <- audit_row$meeting_type[1]
    hospital_name  <- audit_row$hospital_name[1]
    word_count     <- audit_row$word_count[1]
  }
  
  # Extract text
  text_raw <- tryCatch(
    paste(pdftools::pdf_text(full_path), collapse = "\n\n"),
    error = function(e) ""
  )
  text_clean <- str_squish(text_raw)          # used for word count only
  text_display <- str_trim(text_raw)          # preserves structure for display
  
  # Truncate display text to approximately N_WORDS
  # Split on whitespace for counting but reconstruct from display version
  words      <- str_split(text_clean, "\\s+")[[1]]
  word_limit <- min(N_WORDS, length(words))
  # Find the character position of the Nth word in the display text
  char_limit <- str_locate_all(text_display, "\\S+")[[1]][word_limit, "end"]
  text_shown <- str_sub(text_display, 1, char_limit)
  
  # ── Display ────────────────────────────────────────────────────────────────
  cat(sprintf("FAC:           %s\n", FAC))
  cat(sprintf("Hospital:      %s\n", hospital_name))
  cat(sprintf("File:          %s\n", fname))
  cat(sprintf("doc_class:     %s\n", doc_class))
  cat(sprintf("corpus_include:%s\n", corpus_include))
  cat(sprintf("meeting_type:  %s\n", meeting_type))
  cat(sprintf("word_count:    %s\n", word_count))
  cat(sprintf("has_header:    %s  |  has_attendance: %s  |  has_motions: %s  |  has_consent: %s\n",
              has_header, has_attendance, has_motions, has_consent))
  cat("\n--- Opening text ---\n\n")
  cat(text_shown)
  cat(sprintf("\n\n[showing %d of %d words]\n", min(N_WORDS, length(words)), length(words)))
  cat("\n", strrep("-", 80), "\n\n")
}

cat("Review complete.\n")