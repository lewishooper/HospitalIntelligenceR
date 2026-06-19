# ── In-camera quarantine patch ─────────────────────────────────────────────
# Applied June 19, 2026 — two confirmed in-camera documents identified
# and separated from general corpus. Tracked for potential parallel analysis.

library(dplyr)

AUDIT_FILE <- "roles/minutes/outputs/minutes_corpus_audit.csv"

audit <- read.csv(AUDIT_FILE, stringsAsFactors = FALSE)
audit$fac <- as.character(audit$fac)

# Confirm targets before patching
targets <- audit |>
  filter(meeting_type == "in_camera")

cat("=== Rows to be patched ===\n")
print(targets |> select(fac, hospital_name, filename, doc_class, corpus_include, qa_flags))

# Apply quarantine
audit <- audit |>
  mutate(
    corpus_include = ifelse(meeting_type == "in_camera", FALSE, corpus_include),
    qa_flags = ifelse(
      meeting_type == "in_camera",
      ifelse(qa_flags == "", "in_camera_quarantine",
             paste(qa_flags, "in_camera_quarantine", sep = "; ")),
      qa_flags
    )
  )

# Verify
cat("\n=== Post-patch verification ===\n")
audit |>
  filter(meeting_type == "in_camera") |>
  select(fac, hospital_name, filename, doc_class, corpus_include, qa_flags) |>
  print()

cat("\n=== Corpus include totals after patch ===\n")
print(table(audit$corpus_include))

# Write
write.csv(audit, AUDIT_FILE, row.names = FALSE)
cat("\nAudit written.\n")
