# run pipeline
rm(list=ls())
getwd() 
# should be "E:/HospitalIntelligenceR"
# then run steps sequentially one at a time check for issues

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