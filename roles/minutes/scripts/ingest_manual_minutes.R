# roles/minutes/ingest_manual_minutes.R
#
# Ingests manually-acquired board minutes PDFs into minutes_index.csv.
# Used for hospitals where automated scraping is blocked (WAF, robots, etc.)
# and PDFs have been manually downloaded into the standard extracted/ folder.
#
# Reads existing index and skips any filenames already present for the FAC.
# Appends new rows with status = "manually_acquired".
# Adds one summary row per FAC to minutes_scrape_log.csv.
#
# Run from project root: E:/HospitalIntelligenceR
# source("roles/minutes/ingest_manual_minutes.R")
# ingest_manual_minutes(fac = "927")
# ingest_manual_minutes(fac = "966")

library(dplyr)
library(stringr)
library(lubridate)
library(readr)

# Source minutes_scrape.R to reuse infer_date(), make_filename(),
# deduplicate_filename() — do NOT run entry point
source("roles/minutes/scripts/minutes_scrape.R")

# ── Config ─────────────────────────────────────────────────────────────────────
INGEST_CONFIG <- list(
  extract_dir = "roles/minutes/outputs/extracted",
  index_file  = "roles/minutes/outputs/minutes_index.csv",
  log_file    = "roles/minutes/outputs/logs/minutes_scrape_log.csv"
)

# ── Main ingestion function ────────────────────────────────────────────────────
ingest_manual_minutes <- function(fac) {

  fac <- as.character(fac)

  # ── Step 1: Locate the hospital folder ──────────────────────────────────────
  all_folders <- list.files(INGEST_CONFIG$extract_dir)
  match       <- all_folders[str_starts(all_folders, paste0(fac, "_"))]

  if (length(match) == 0) {
    stop(sprintf("No folder found in extracted/ starting with '%s_'", fac))
  }
  if (length(match) > 1) {
    stop(sprintf("Multiple folders found for FAC %s: %s", fac, paste(match, collapse = ", ")))
  }

  folder_name <- match
  folder_path <- file.path(INGEST_CONFIG$extract_dir, folder_name)

  # Derive hospital name from folder — strip FAC prefix, replace _ with space
  hospital_name <- str_remove(folder_name, paste0("^", fac, "_")) |>
    str_replace_all("_", " ")

  cat(sprintf("\n── Ingesting FAC %s: %s ──\n", fac, hospital_name))
  cat(sprintf("   Folder: %s\n", folder_path))

  # ── Step 2: Scan for PDF files ───────────────────────────────────────────────
  pdf_files <- list.files(folder_path, pattern = "\\.pdf$", ignore.case = TRUE)

  if (length(pdf_files) == 0) {
    cat(sprintf("   No PDF files found in folder — nothing to ingest.\n"))
    return(invisible(NULL))
  }

  cat(sprintf("   PDFs found on disk: %d\n", length(pdf_files)))

  # ── Step 3: Load existing index — skip already-present filenames ─────────────
  if (file.exists(INGEST_CONFIG$index_file)) {
    index_existing <- read.csv(INGEST_CONFIG$index_file,
                               stringsAsFactors = FALSE,
                               colClasses = c(fac = "character"))
  } else {
    index_existing <- NULL
  }

  already_indexed <- if (!is.null(index_existing)) {
    index_existing |>
      filter(fac == !!fac) |>
      pull(filename)
  } else {
    character(0)
  }

  cat(sprintf("   Already in index for FAC %s: %d rows\n", fac, length(already_indexed)))

  # ── Step 4: Build index rows for new files ───────────────────────────────────
  new_rows     <- list()
  used_names   <- already_indexed  # dedup within this FAC across existing + new
  unknown_seq  <- sum(str_starts(already_indexed, "UNKNOWN_DATE"))

  for (fname in pdf_files) {

    # Skip if already in index
    if (fname %in% already_indexed) {
      cat(sprintf("   [skip] %s — already indexed\n", fname))
      next
    }

    # Infer date from filename — no href or title_attr available
    date_str    <- infer_date(fname, fname, NA_character_)
    if (is.na(date_str)) unknown_seq <- unknown_seq + 1L

    # Build canonical filename using same logic as scraper
    # If the file on disk already has the right naming convention, use it directly;
    # otherwise generate the canonical name
    canonical   <- make_filename(date_str, unknown_seq, fname)
    final_fname <- deduplicate_filename(canonical, used_names)
    used_names  <- c(used_names, final_fname)

    # Rename file on disk if canonical name differs from current name
    if (final_fname != fname) {
      old_path <- file.path(folder_path, fname)
      new_path <- file.path(folder_path, final_fname)
      if (!file.exists(new_path)) {
        file.rename(old_path, new_path)
        cat(sprintf("   [renamed] %s → %s\n", fname, final_fname))
      } else {
        cat(sprintf("   [rename skipped] target already exists: %s\n", final_fname))
        final_fname <- fname  # keep original name to avoid data/disk mismatch
      }
    }

    local_path <- file.path(folder_path, final_fname)
    size_kb    <- round(file.info(local_path)$size / 1024, 1)

    new_rows[[length(new_rows) + 1]] <- list(
      fac           = fac,
      hospital_name = hospital_name,
      folder_name   = folder_name,
      filename      = final_fname,
      doc_date      = date_str %||% NA_character_,
      source_url    = NA_character_,
      download_date = NA_character_,
      file_size_kb  = size_kb,
      status        = "manually_acquired"
    )
  }

  if (length(new_rows) == 0) {
    cat(sprintf("   All PDFs already indexed — nothing to append.\n"))
    return(invisible(NULL))
  }

  cat(sprintf("   New rows to append: %d\n", length(new_rows)))

  # ── Step 5: Append to index ──────────────────────────────────────────────────
  new_df <- bind_rows(lapply(new_rows, as.data.frame, stringsAsFactors = FALSE)) |>
    mutate(fac = as.character(fac), file_size_kb = as.numeric(file_size_kb))

  if (!is.null(index_existing)) {
    index_existing <- index_existing |>
      mutate(
        fac           = as.character(fac),
        download_date = as.character(download_date),
        file_size_kb  = as.numeric(file_size_kb)
      )
    index_final <- bind_rows(index_existing, new_df)
  } else {
    index_final <- new_df
  }

  write.csv(index_final, INGEST_CONFIG$index_file, row.names = FALSE)
  cat(sprintf("   minutes_index.csv updated: %d total rows\n", nrow(index_final)))

  # ── Step 6: Append one row to scrape log ─────────────────────────────────────
  log_row <- data.frame(
    fac           = fac,
    hospital_name = hospital_name,
    minutes_url   = NA_character_,
    status        = "manual",
    n_pdfs_found  = length(pdf_files),
    n_downloaded  = length(new_rows),
    notes         = sprintf("Manually acquired; %d files ingested %s",
                            length(new_rows), Sys.Date()),
    stringsAsFactors = FALSE
  )

  if (file.exists(INGEST_CONFIG$log_file)) {
    log_existing <- read.csv(INGEST_CONFIG$log_file,
                             stringsAsFactors = FALSE,
                             colClasses = c(fac = "character"))
    # Replace any prior log row for this FAC, append new one
    log_final <- bind_rows(
      log_existing |> filter(fac != !!fac),
      log_row
    )
  } else {
    log_final <- log_row
  }

  write.csv(log_final, INGEST_CONFIG$log_file, row.names = FALSE)
  cat(sprintf("   minutes_scrape_log.csv updated.\n"))

  cat(sprintf("\n── FAC %s ingestion complete ──\n", fac))
  invisible(new_df)
}

# ── Null-coalescing operator (if not already loaded) ──────────────────────────
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (!is.null(a) && !is.na(a) && length(a) > 0) a else b
}
