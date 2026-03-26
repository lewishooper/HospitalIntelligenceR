# =============================================================================
# registry_patch_march24.R
#
# Applies the 16 status updates from the March 24, 2026 session to the
# hospital registry. Run once from the project root. Safe to re-run —
# update_hospital_status() merges fields, it does not overwrite the full block.
#
# Source: SessionSummaryMarch242026.md, Section 4
# =============================================================================

source("core/registry.R")

cat("Applying March 24 registry patch...\n\n")

# --- COMPLETE (manual download, protected from re-run) ---

update_hospital_status("958", "strategy", list(
  extraction_status = "complete",
  manual_override   = TRUE,
  needs_review      = FALSE
))
cat("FAC 958 Ottawa — complete\n")

update_hospital_status("968", "strategy", list(
  extraction_status = "complete",
  manual_override   = TRUE,
  needs_review      = FALSE
))
cat("FAC 968 Huntsville — complete\n")

update_hospital_status("771", "strategy", list(
  extraction_status = "complete",
  manual_override   = TRUE,
  needs_review      = FALSE
))
cat("FAC 771 Peterborough — complete\n")

update_hospital_status("724", "strategy", list(
  extraction_status = "complete",
  manual_override   = TRUE,
  needs_review      = FALSE
))
cat("FAC 724 Mattawa — complete\n")

# --- HTML ONLY (no PDF exists — terminal, protected from re-run) ---

update_hospital_status("850", "strategy", list(
  extraction_status = "html_only",
  manual_override   = TRUE,
  needs_review      = FALSE
))
cat("FAC 850 Runnymede — html_only\n")

update_hospital_status("824", "strategy", list(
  extraction_status = "html_only",
  manual_override   = TRUE,
  needs_review      = FALSE
))
cat("FAC 824 Tillsonburg — html_only\n")

update_hospital_status("932", "strategy", list(
  extraction_status = "html_only",
  manual_override   = TRUE,
  needs_review      = FALSE
))
cat("FAC 932 Bruyere — html_only\n")

update_hospital_status("936", "strategy", list(
  extraction_status = "html_only",
  manual_override   = TRUE,
  needs_review      = FALSE
))
cat("FAC 936 London Health Sciences — html_only\n")

# --- NOT YET PUBLISHED (plan under development — protected from re-run) ---

update_hospital_status("930", "strategy", list(
  extraction_status = "not_yet_published",
  manual_override   = TRUE,
  needs_review      = FALSE
))
cat("FAC 930 Grand River — not_yet_published\n")

update_hospital_status("699", "strategy", list(
  extraction_status = "not_yet_published",
  manual_override   = TRUE,
  needs_review      = FALSE
))
cat("FAC 699 St Mary's Kitchener — not_yet_published\n")

# --- NOT PUBLISHED (exists but not online — outreach in progress) ---

update_hospital_status("719", "strategy", list(
  extraction_status = "not_published",
  manual_override   = TRUE,
  needs_review      = FALSE
))
cat("FAC 719 Manitouwadge — not_published\n")

# --- NO PLAN (confirmed via direct contact) ---

update_hospital_status("910", "strategy", list(
  extraction_status = "no_plan",
  manual_override   = TRUE,
  needs_review      = FALSE
))
cat("FAC 910 Casey House — no_plan\n")

# --- DOWNLOADED (pipeline successes — will re-run on annual cadence) ---

update_hospital_status("763", "strategy", list(
  extraction_status = "downloaded",
  needs_review      = FALSE
))
cat("FAC 763 Pembroke — downloaded\n")

update_hospital_status("950", "strategy", list(
  extraction_status = "downloaded",
  needs_review      = FALSE
))
cat("FAC 950 Halton Healthcare — downloaded\n")

update_hospital_status("975", "strategy", list(
  extraction_status = "downloaded",
  needs_review      = FALSE
))
cat("FAC 975 Trillium — downloaded\n")

update_hospital_status("627", "strategy", list(
  extraction_status = "downloaded",
  needs_review      = FALSE
))
cat("FAC 627 Chapleau — downloaded\n")

cat("\nPatch complete. Upload updated hospital_registry.yaml to project repository.\n")