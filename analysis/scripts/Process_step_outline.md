Three things to do before starting:

rm(list = ls()) to clear stale environment objects before sourcing 00_prepare_data.R
Confirm working directory is the project root (getwd())
strategy_master.csv should not be open in any other application — file lock will kill the write steps

What to watch for at each step:
StepKey confirmation line00_prepare_dataAnalytical master: 574 rows, 125 unique FACs and Spine: 134 
00cCohort output: 119 hospitals, 17/43/48/11 type split
01bAnalytical cohort: N directions across 119 hospitals
01cSame cohort, GOV 3 of 48 Small (6.2%) unchanged
03bEra breakdown: 12 / 41 / 65
03cNo error on pivot — if you get NA pivot warning, stop and paste output
04aJaccard summary prints cleanly
04bAll API cells succeed; cost prints at end

# Step 1 — Rebuild analytical master and spine
source("analysis/scripts/00_prepare_data.R")

# Step 2 — Rebuild strategy_classified (no reclassification needed —
#           theme_classifications.csv is already patched via 00d)
source("analysis/scripts/00c_build_strategy_classified.R")

# Step 3 — Theme distribution tables and figures
source("analysis/scripts/01b_direction_types.R")

# Step 4 — Concentration table (already validated, re-run to confirm
#           it picks up any changes from Steps 1-2)
source("analysis/scripts/01c_theme_concentration.R")

# Step 5 — Temporal theme trends
source("analysis/scripts/03b_theme_trends.R")

# Step 6 — Era x type interaction
source("analysis/scripts/03c_theme_by_era_type.R")

# Step 7 — Homogeneity (Jaccard + breadth)
source("analysis/scripts/04a_homogeneity.R")

# Step 8 — Distinctive directions (calls Claude API ~$0.20)
source("analysis/scripts/04b_unique_strategies.R")