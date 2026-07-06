# run_batch_prescreen_tests.R
# Runs minutes_extract_prescreen.R once per flagged document, each in its
# own fresh Rscript process (avoids the target script's rm(list=ls())
# wiping out TEST_FAC/TEST_FILENAME set by this driver). Full console
# output — including print_page_diagnostics() — is captured to a log file
# per case and also echoed here.
#
# Run from: E:/HospitalIntelligenceR (project root)

test_cases <- list(
  list(fac = "661", filename = "2024-06-26_board_minutes_v2.pdf"),
  list(fac = "661", filename = "2024-06-05_board_minutes.pdf"),
  list(fac = "933", filename = "2024-07-01_board_minutes_v4.pdf"),
  list(fac = "933", filename = "2023-06-01_board_minutes_v2.pdf"),
  list(fac = "933", filename = "UNKNOWN_DATE_001_board_minutes.pdf"),
  list(fac = "939", filename = "2023-06-01_board_minutes.pdf")
)

log_dir <- "roles/minutes/outputs/prescreen_test_logs"
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
for (tc in test_cases) {
  log_file <- file.path(
    log_dir,
    sprintf("test_%s_%s.txt", tc$fac, tools::file_path_sans_ext(tc$filename))
  )
  
  cat(sprintf("\n\n############################################################\n"))
  cat(sprintf("  FAC %s -- %s\n", tc$fac, tc$filename))
  cat(sprintf("############################################################\n"))
  
  Sys.setenv(TEST_FAC = tc$fac, TEST_FILENAME = tc$filename)
  
  output <- system2(
    "Rscript",
    args   = shQuote("roles/minutes/minutes_extract_prescreen.R"),
    stdout = TRUE, stderr = TRUE
  )
  
  writeLines(output, log_file)
  cat(paste(output, collapse = "\n"))
}

Sys.unsetenv(c("TEST_FAC", "TEST_FILENAME"))

cat("\n\nAll six test cases complete. Logs written to:", log_dir, "\n")



