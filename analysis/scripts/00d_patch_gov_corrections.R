# =============================================================================
# analysis/scripts/00d_patch_gov_corrections.R
# HospitalIntelligenceR — Manual Correction: GOV Reclassifications
#
# PURPOSE:
#   Apply manual corrections to theme_classifications.csv for the two rows
#   that were misclassified as GOV. GOV has been retired from the taxonomy.
#
# CORRECTIONS:
#   FAC 882 — "Accountability"
#     primary:   GOV → FIN  (content is fiscal stewardship, not governance)
#     secondary: FIN → ORG  (ethical decisions, community relationship = org values)
#     notes:     updated to reflect corrected rationale
#
#   FAC 932 — "Fostering Bold Leadership"
#     primary:   GOV → PAR  (external-facing system leadership = partnerships)
#     secondary: PAR → RES  (explicit research mention warrants RES secondary)
#     notes:     updated to reflect corrected rationale
#
# USAGE:
#   Run once after full classification run. Safe to re-run — corrections are
#   applied by row_id match so duplicate runs produce the same result.
#
# OUTPUT:
#   Overwrites analysis/data/theme_classifications.csv in place.
#   Rebuild strategy_classified.csv by re-running 00c after this script.
# =============================================================================
#
rm(classifications)
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

PATH <- "analysis/data/theme_classifications.csv"

classifications <- read_csv(
  PATH,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)

cat(sprintf("Loaded: %d rows from %s\n", nrow(classifications), PATH))

# Confirm GOV rows are present before patching
gov_rows <- classifications %>% filter(primary_theme == "GOV")
cat(sprintf("GOV rows found: %d (expected 2)\n", nrow(gov_rows)))
if (nrow(gov_rows) > 0) {
  print(gov_rows %>% select(fac, direction_name, primary_theme, secondary_theme))
}


# =============================================================================
# Apply corrections
# =============================================================================

corrections <- tibble(
  fac = c("882", "932"),
  checks = c(
    "Accountability",
    "Fostering bold leadership"
  ),
  new_primary   = c("FIN", "PAR"),
  new_secondary = c("ORG", "RES"),
  new_notes = c(
    "Corrected from GOV: content is fiscal stewardship and resource accountability (FIN primary). Ethical decision-making and community relationship reflect organizational values (ORG secondary). 'Accountability' label triggered GOV incorrectly.",
    "Corrected from GOV: direction is external-facing system leadership across regional/provincial/national scope (PAR primary). Research explicitly mentioned as area of leadership (RES secondary). 'Bold leadership' label triggered GOV incorrectly."
  )
)

for (i in seq_len(nrow(corrections))) {
  fac_target  <- corrections$fac[i]
  name_check  <- corrections$checks[i]

  match_idx <- which(
    classifications$fac == fac_target &
    tolower(classifications$direction_name) == tolower(name_check)
  )

  if (length(match_idx) == 0) {
    cat(sprintf("WARNING: No match found for FAC %s '%s' — skipping.\n",
                fac_target, name_check))
    next
  }
  if (length(match_idx) > 1) {
    cat(sprintf("WARNING: Multiple matches for FAC %s '%s' — skipping.\n",
                fac_target, name_check))
    next
  }

  # Apply correction
  old_primary <- classifications$primary_theme[match_idx]
  old_secondary <- classifications$secondary_theme[match_idx]

  classifications$primary_theme[match_idx]          <- corrections$new_primary[i]
  classifications$secondary_theme[match_idx]        <- corrections$new_secondary[i]
  classifications$classification_notes[match_idx]   <- corrections$new_notes[i]
  classifications$classification_confidence[match_idx] <- "high"
  classifications$classification_status[match_idx]  <- "ok"

  cat(sprintf(
    "FAC %s '%s': %s/%s → %s/%s\n",
    fac_target, name_check,
    old_primary, coalesce(old_secondary, "—"),
    corrections$new_primary[i], corrections$new_secondary[i]
  ))
}


# =============================================================================
# Verify no GOV rows remain
# =============================================================================

remaining_gov <- sum(classifications$primary_theme == "GOV", na.rm = TRUE)

if (remaining_gov > 0) {
  cat(sprintf("\nWARNING: %d GOV rows still present — review required.\n",
              remaining_gov))
} else {
  cat("\nVerified: 0 GOV rows remain in classifications.\n")
}


# =============================================================================
# Write corrected file
# =============================================================================
write_csv(classifications, "analysis/data/theme_classifications_test.csv")

write_csv(classifications, PATH)
cat(sprintf("Written: %s (%d rows)\n", PATH, nrow(classifications)))
cat("\nRe-run 00c_build_strategy_classified.R to rebuild the merged review table.\n")
