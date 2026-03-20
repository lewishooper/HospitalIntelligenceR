source("core/registry.R")
hosp <- get_hospital("905")
cat("905 strategy_url:", hosp$status$strategy$strategy_url, "\n")

hosp <- get_hospital("979")
cat("979 strategy_url:", hosp$status$strategy$strategy_url, "\n")

hosp <- get_hospital("724")
cat("724 override_reason:", hosp$status$strategy$override_reason, "\n")

hosp <- get_hospital("930")
cat("930 extraction_status:", hosp$status$strategy$extraction_status, "\n")
