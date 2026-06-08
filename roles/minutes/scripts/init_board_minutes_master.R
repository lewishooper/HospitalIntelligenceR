# init_board_minutes_master.R
# Purpose: Load BoardMinuteLocationrevisedv2.xlsx into a clean master dataframe,
#          save as RDS, and create one output folder per hospital.
#
# Run from: E:/HospitalIntelligenceR  (project root)
# Output RDS: roles/minutes/outputs/Master_Board_Minutes_062026.rds
# Output folders: roles/minutes/outputs/extracted/FAC_HOSPITALNAME/
rm(list=ls())

library(readxl)
library(dplyr)
library(stringr)

# ── Paths ──────────────────────────────────────────────────────────────────────
INPUT_FILE  <- "E:/HospitalIntelligenceR/roles/minutes/ResearchOnMinutes/BoardMinuteLocationrevisedv2.xlsx"
OUTPUT_RDS  <- "E:/HospitalIntelligenceR/roles/minutes/outputs/Master_Board_Minutes_062026.rds"
EXTRACT_DIR <- "E:/HospitalIntelligenceR/roles/minutes/outputs/extracted"

# ── 1. Read Excel ──────────────────────────────────────────────────────────────
cat("Reading:", INPUT_FILE, "\n")

raw <- read_excel(
  INPUT_FILE,
  col_types = "text",   # read everything as character; prevents date coercion
  trim_ws   = TRUE
)
## lets drop the 4 rows at the bottom
raw<-raw[1:138,]
cat("Rows read:", nrow(raw), "\n")
cat("Columns:  ", paste(names(raw), collapse = ", "), "\n\n")

# ── 2. Standardize column names ────────────────────────────────────────────────
df <- raw %>%
  rename(
    fac               = FAC,
    hospital_name     = `Hospital Name`,
    hospital_group    = `Hospital Group`,
    base_url          = `Base URL`,
    minutes_found     = `Minutes Found (Y/N)`,
    minutes_url       = `Minutes URL`,
    notes             = Notes,
    link              = Link,
    searched          = searched,
    found             = found
  ) %>%
  mutate(
    fac           = str_pad(str_trim(fac), width = 3, side = "left", pad = "0"),
    hospital_name = str_trim(hospital_name),
    minutes_found = str_to_upper(str_trim(minutes_found)),
    minutes_url   = str_trim(minutes_url),
    base_url      = str_trim(base_url)
  )

# ── 3. Normalize base_url: add https:// if missing ────────────────────────────
df <- df %>%
  mutate(
    base_url = case_when(
      !is.na(base_url) & !str_starts(base_url, "http") ~ paste0("https://", base_url),
      TRUE ~ base_url
    )
  )

# ── 4. Build folder name: FAC_HOSPITALNAME (caps, spaces → underscores) ───────
make_folder_name <- function(fac, name) {
  name_clean <- name %>%
    str_to_upper() %>%
    str_replace_all("[^A-Z0-9 ]", "") %>%   # strip non-alphanumeric except space
    str_replace_all("\\s+", "_") %>%        # spaces to underscores
    str_trim()
  paste0(fac, "_", name_clean)
}

df <- df %>%
  mutate(folder_name = make_folder_name(fac, hospital_name))

# ── 5. Save RDS ────────────────────────────────────────────────────────────────
saveRDS(df, OUTPUT_RDS)
cat("RDS saved to:", OUTPUT_RDS, "\n")
cat("Rows:", nrow(df), "| Columns:", ncol(df), "\n\n")

# ── 6. Create output folders ───────────────────────────────────────────────────
if (!dir.exists(EXTRACT_DIR)) {
  dir.create(EXTRACT_DIR, recursive = TRUE)
  cat("Created extract root:", EXTRACT_DIR, "\n")
}

created  <- 0L
skipped  <- 0L
failed   <- character(0)

for (i in seq_len(nrow(df))) {
  folder_path <- file.path(EXTRACT_DIR, df$folder_name[i])
  if (dir.exists(folder_path)) {
    skipped <- skipped + 1L
  } else {
    ok <- tryCatch({
      dir.create(folder_path, recursive = TRUE)
      TRUE
    }, error = function(e) {
      message("  ERROR creating: ", folder_path, " — ", conditionMessage(e))
      FALSE
    })
    if (ok) created <- created + 1L else failed <- c(failed, df$folder_name[i])
  }
}

cat("Folders created:", created, "\n")
cat("Folders skipped (already existed):", skipped, "\n")
if (length(failed) > 0) {
  cat("FAILED to create", length(failed), "folder(s):\n")
  cat(paste0("  ", failed, collapse = "\n"), "\n")
}

# ── 7. Quick summary ───────────────────────────────────────────────────────────
cat("\n=== Master summary ===\n")
cat("Total hospitals:      ", nrow(df), "\n")
cat("Minutes found (Y):    ", sum(df$minutes_found == "Y", na.rm = TRUE), "\n")
cat("Minutes not found (N):", sum(df$minutes_found == "N", na.rm = TRUE), "\n")
cat("Minutes URL present:  ", sum(!is.na(df$minutes_url) & df$minutes_url != ""), "\n")
cat("Searched:             ", sum(df$searched == "1", na.rm = TRUE), "\n")

cat("\nDone. Inspect Master_Board_Minutes_062026.rds before proceeding.\n")

