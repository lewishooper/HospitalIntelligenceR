# patch_yaml_minutes_urls.R
# Patches hospital_registry.yaml board.minutes_url and board.minutes_found
# from BoardMinuteLocationrevisedv2.xlsx (the verified URL source).
#
# Run from project root: E:/HospitalIntelligenceR
# source("roles/minutes/patch_yaml_minutes_urls.R")
#
# SAFE TO RE-RUN: only modifies board.minutes_url, board.minutes_found, and base_url
# where the Excel has a confirmed https:// URL. All other YAML fields untouched.
# Creates a timestamped backup before writing.

library(readxl)
library(yaml)
library(stringr)
library(dplyr)

# ── Paths ──────────────────────────────────────────────────────────────────────
YAML_PATH  <- "E:/HospitalIntelligenceR/registry/hospital_registry.yaml"
EXCEL_PATH <- "roles/minutes/ResearchOnMinutes/BoardMinuteLocationrevisedv2.xlsx"
BACKUP_DIR <- "roles/minutes/outputs/yaml_backups"

# ── 1. Backup the YAML before touching it ─────────────────────────────────────
dir.create(BACKUP_DIR, recursive = TRUE, showWarnings = FALSE)
backup_path <- file.path(BACKUP_DIR,
  sprintf("hospital_registry_backup_%s.yaml", format(Sys.time(), "%Y%m%d_%H%M%S")))
file.copy(YAML_PATH, backup_path)
cat(sprintf("Backup written to: %s\n", backup_path))

# ── 2. Read Excel source ───────────────────────────────────────────────────────
excel <- read_excel(EXCEL_PATH, col_types = "text") |>
  rename(
    fac           = FAC,
    hospital_name = `Hospital Name`,
    base_url      = `Base URL`,
    minutes_found = `Minutes Found (Y/N)`,
    minutes_url   = `Minutes URL`,
    notes         = Notes
  ) |>
  mutate(
    fac           = str_trim(fac),
    minutes_found = str_to_upper(str_trim(minutes_found)),
    minutes_url   = str_trim(minutes_url),
    base_url      = str_trim(base_url),
    # Normalize base_url
    base_url      = case_when(
      !is.na(base_url) & base_url != "" & !str_starts(base_url, "http")
        ~ paste0("https://", base_url),
      TRUE ~ base_url
    )
  )

cat(sprintf("Excel rows loaded: %d\n", nrow(excel)))
cat(sprintf("Rows with minutes_url (https://): %d\n",
            sum(str_starts(excel$minutes_url, "https://"), na.rm = TRUE)))

# ── 3. Read YAML ───────────────────────────────────────────────────────────────
cat("Reading YAML...\n")
registry <- read_yaml(YAML_PATH)
hospitals <- registry$hospitals
cat(sprintf("Hospitals in YAML: %d\n\n", length(hospitals)))

# ── 4. Build lookup from Excel (FAC -> row) ────────────────────────────────────
excel_lookup <- split(excel, excel$fac)

# ── 5. Patch each hospital ─────────────────────────────────────────────────────
n_url_updated   <- 0L
n_found_updated <- 0L
n_base_updated  <- 0L
patch_log       <- list()

for (i in seq_along(hospitals)) {
  hosp <- hospitals[[i]]
  fac  <- as.character(hosp$FAC)

  if (!fac %in% names(excel_lookup)) next

  ex <- excel_lookup[[fac]]

  changed <- character(0)

  # ── base_url: update if Excel has a better (https://) value ─────────────────
  new_base <- ex$base_url[1]
  if (!is.na(new_base) && new_base != "" &&
      str_starts(new_base, "https://") &&
      !identical(hosp$base_url, new_base)) {
    hospitals[[i]]$base_url <- new_base
    n_base_updated <- n_base_updated + 1L
    changed <- c(changed, sprintf("base_url: '%s' → '%s'", hosp$base_url %||% "", new_base))
  }

  # ── minutes_found: update if Excel value differs ─────────────────────────────
  new_found <- ex$minutes_found[1]
  old_found <- str_to_upper(hosp$status$board$minutes_found %||% "")
  if (!is.na(new_found) && new_found != "" && !identical(old_found, new_found)) {
    hospitals[[i]]$status$board$minutes_found <- new_found
    n_found_updated <- n_found_updated + 1L
    changed <- c(changed, sprintf("minutes_found: '%s' → '%s'", old_found, new_found))
  }

  # ── minutes_url: update only if Excel has a proper https:// URL ──────────────
  new_url <- ex$minutes_url[1]
  old_url <- hosp$status$board$minutes_url %||% ""
  if (!is.na(new_url) && str_starts(new_url, "https?://")) {
    if (!identical(old_url, new_url)) {
      hospitals[[i]]$status$board$minutes_url <- new_url
      n_url_updated <- n_url_updated + 1L
      changed <- c(changed, sprintf("minutes_url: '%s' → '%s'", old_url, new_url))
    }
  }

  if (length(changed) > 0) {
    patch_log[[length(patch_log) + 1]] <- list(
      fac           = fac,
      hospital_name = hosp$name,
      changes       = paste(changed, collapse = " | ")
    )
  }
}

registry$hospitals <- hospitals

# ── 6. Write patched YAML ─────────────────────────────────────────────────────
cat("Writing patched YAML...\n")
write_yaml(registry, YAML_PATH,
           indent = 2,
           handlers = list(
             # Preserve character scalars as quoted strings
             character = function(x) {
               if (length(x) == 1) {
                 structure(x, class = "scalar")
               } else x
             }
           ))

# ── 7. Summary ────────────────────────────────────────────────────────────────
cat("\n=== PATCH SUMMARY ===\n")
cat(sprintf("base_url updated:     %d\n", n_base_updated))
cat(sprintf("minutes_found updated: %d\n", n_found_updated))
cat(sprintf("minutes_url updated:  %d\n", n_url_updated))
cat(sprintf("Hospitals changed:    %d\n\n", length(patch_log)))

if (length(patch_log) > 0) {
  log_df <- bind_rows(lapply(patch_log, as.data.frame, stringsAsFactors = FALSE))
  print(log_df)

  # Save patch log
  log_path <- file.path(BACKUP_DIR,
    sprintf("yaml_patch_log_%s.csv", format(Sys.time(), "%Y%m%d_%H%M%S")))
  write.csv(log_df, log_path, row.names = FALSE)
  cat(sprintf("\nPatch log saved to: %s\n", log_path))
}

cat("\nDone. Verify a few entries in hospital_registry.yaml before proceeding.\n")
cat("Backup is at: ", backup_path, "\n")
S
