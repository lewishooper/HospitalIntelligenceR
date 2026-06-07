# minutes_url_apply.R
# Applies confirmed resolved URLs back to BoardMinuteLocationFile_v2.xlsx
# and hospital_registry.yaml after manual review of minutes_url_review.csv.
#
# Workflow:
#   1. Run minutes_url_resolve.R → produces minutes_url_review.csv
#   2. Open minutes_url_review.csv; for MEDIUM/LOW rows either:
#        - Set resolved_url to the correct URL manually, OR
#        - Set confidence_label to "SKIP" to leave unchanged
#   3. Run this script — it applies all non-SKIP rows with a resolved_url
#
# Dependencies: readxl, writexl, yaml, dplyr, stringr

library(readxl)
library(writexl)
library(yaml)
library(dplyr)
library(stringr)

LOCATION_FILE  <- "BoardMinuteLocationFile_v2.xlsx"
REVIEW_FILE    <- "minutes_url_review.csv"
REGISTRY_FILE  <- "hospital_registry.yaml"
REVIEW_DATE    <- as.character(Sys.Date())   # YYYY-MM-DD

# --- Load files ---
cat("Loading files...\n")
loc     <- read_excel(LOCATION_FILE)
review  <- read.csv(REVIEW_FILE, stringsAsFactors = FALSE)
registry <- read_yaml(REGISTRY_FILE)

loc$fac     <- as.character(as.integer(loc$fac))
review$fac  <- as.character(review$fac)

# --- Identify rows to apply ---
# Apply where: not SKIP, resolved_url is a proper URL
to_apply <- review |>
  filter(
    confidence_label != "SKIP",
    !is.na(resolved_url),
    str_starts(resolved_url, "http")
  )

cat(sprintf("Rows to apply: %d\n", nrow(to_apply)))
if (nrow(to_apply) == 0) {
  stop("No rows to apply. Check review file.")
}

# --- Apply to location file ---
loc_updated <- loc
n_applied <- 0

for (i in seq_len(nrow(to_apply))) {
  row <- to_apply[i, ]
  idx <- which(loc_updated$fac == row$fac)

  if (length(idx) == 0) {
    warning(sprintf("FAC %s not found in location file", row$fac))
    next
  }

  old_url <- loc_updated$minutes_url[idx]
  loc_updated$minutes_url[idx]   <- row$resolved_url
  loc_updated$last_reviewed[idx] <- REVIEW_DATE
  n_applied <- n_applied + 1

  cat(sprintf("  FAC %s [%s]: %s\n    → %s\n",
              row$fac, row$confidence_label,
              str_trunc(old_url, 60),
              str_trunc(row$resolved_url, 80)))
}

cat(sprintf("\nApplied %d URL updates to location file.\n", n_applied))

# --- Apply to registry ---
cat("\nUpdating registry...\n")
n_reg <- 0

for (j in seq_along(registry$hospitals)) {
  h   <- registry$hospitals[[j]]
  fac <- as.character(h$FAC)
  match_row <- to_apply[to_apply$fac == fac, ]

  if (nrow(match_row) == 0) next

  registry$hospitals[[j]]$status$board$minutes_url <- match_row$resolved_url[1]
  n_reg <- n_reg + 1
  cat(sprintf("  Registry FAC %s updated.\n", fac))
}

cat(sprintf("Applied %d URL updates to registry.\n", n_reg))

# --- Write outputs ---
# Backup originals first
file.copy(LOCATION_FILE, str_replace(LOCATION_FILE, "\\.xlsx$", "_pre_url_fix.xlsx"),
          overwrite = TRUE)
file.copy(REGISTRY_FILE, str_replace(REGISTRY_FILE, "\\.yaml$", "_pre_url_fix.yaml"),
          overwrite = TRUE)
cat("\nBackups created.\n")

write_xlsx(loc_updated, LOCATION_FILE)
write_yaml(registry, REGISTRY_FILE)

cat(sprintf("\nLocation file updated: %s\n", LOCATION_FILE))
cat(sprintf("Registry updated: %s\n", REGISTRY_FILE))
cat("\nDone. Upload both files to the project knowledge repository.\n")
