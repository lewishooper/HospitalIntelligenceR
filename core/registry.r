# core/registry.R
# Single source of truth access for the hospital registry.
# This is the ONLY module that reads from or writes to hospital_registry.yaml.
# All other modules interact with registry data through these functions.
#
# Note: leadership_url is currently a top-level field serving as a general-purpose
# seed URL for executives, board, and foundational crawling. Revisit when building
# roles/executives/ and roles/board/ — may need per-role URL fields at that point.

library(yaml)
library(purrr)
library(dplyr)
library(lubridate)

# --- Configuration ---

REGISTRY_PATH <- "registry/hospital_registry.yaml"

# --- Internal helpers ---

# Load the full registry from disk. Returns the hospitals list.
.load_registry <- function() {
  if (!file.exists(REGISTRY_PATH)) {
    stop(sprintf("Registry file not found at: %s", REGISTRY_PATH))
  }
  yaml.load_file(REGISTRY_PATH)$hospitals
}

# Write the full hospitals list back to disk.
# Internal only — external code uses update_hospital_status().
.write_registry <- function(hospitals) {
  write_yaml(list(hospitals = hospitals), REGISTRY_PATH)
  invisible(NULL)
}

# Find the index of a hospital in the list by FAC code.
.find_fac_index <- function(hospitals, fac) {
  fac <- as.character(fac)
  idx <- which(map_chr(hospitals, ~ as.character(.x$FAC)) == fac)
  if (length(idx) == 0) stop(sprintf("FAC '%s' not found in registry.", fac))
  if (length(idx) > 1) stop(sprintf("FAC '%s' appears more than once in registry.", fac))
  idx
}

# --- Public functions ---

#' Load all hospitals from the registry.
#' Returns a list of hospital entries.
load_registry <- function() {
  .load_registry()
}

#' Look up a single hospital by FAC code.
#' Returns the hospital entry as a list, or stops with an error if not found.
get_hospital <- function(fac) {
  hospitals <- .load_registry()
  idx <- .find_fac_index(hospitals, fac)
  hospitals[[idx]]
}

#' Update the status block for a specific role on a specific hospital.
#' Merges the provided fields into the existing status block — does not overwrite
#' fields that are not included in the update.
#'
#' @param fac         FAC code of the hospital to update (character or numeric)
#' @param role        One of: "strategy", "foundational", "executives", "board"
#' @param fields      Named list of fields to update within the role status block
#'
#' Example:
#'   update_hospital_status("592", "strategy", list(
#'     extraction_status    = "complete",
#'     last_extraction_date = as.character(Sys.Date())
#'   ))
update_hospital_status <- function(fac, role, fields) {
  valid_roles <- c("strategy", "foundational", "executives", "board")
  if (!role %in% valid_roles) {
    stop(sprintf("Invalid role '%s'. Must be one of: %s", role, paste(valid_roles, collapse = ", ")))
  }
  
  hospitals <- .load_registry()
  idx <- .find_fac_index(hospitals, fac)
  
  # Merge new fields into the existing status block for this role
  current_status <- hospitals[[idx]]$status[[role]]
  hospitals[[idx]]$status[[role]] <- modifyList(current_status, fields)
  
  .write_registry(hospitals)
  invisible(hospitals[[idx]])
}

#' Return hospitals that are due for extraction for a given role.
#' "Due" means extraction_status is not "complete", or last_extraction_date
#' is older than the role's cadence threshold relative to the reference date.
#'
#' @param role          One of: "strategy", "foundational", "executives", "board"
#' @param as_of         Reference date (default: today). Accepts Date or character "YYYY-MM-DD".
#' @param force_all     If TRUE, return all hospitals regardless of status (useful for resets)
#'
#' Cadence thresholds (approximate):
#'   strategy:     365 days
#'   foundational: 365 days
#'   executives:    30 days
#'   board:        180 days
get_hospitals_due <- function(role, as_of = Sys.Date(), force_all = FALSE) {
  valid_roles <- c("strategy", "foundational", "executives", "board")
  if (!role %in% valid_roles) {
    stop(sprintf("Invalid role '%s'. Must be one of: %s", role, paste(valid_roles, collapse = ", ")))
  }
  
  cadence_days <- list(
    strategy     = 365,
    foundational = 365,
    executives   =  30,
    board        = 180
  )
  
  as_of <- as.Date(as_of)
  threshold <- cadence_days[[role]]
  hospitals <- .load_registry()
  
  keep <- map_lgl(hospitals, function(h) {
    if (force_all) return(TRUE)
    
    status <- h$status[[role]]
    
    # Always include if never extracted
    # New — handles NULL, NA, and empty string
    led <- status$last_extraction_date
    if (is.null(led) || length(led) == 0 || is.na(led) || nchar(as.character(led)) == 0) return(TRUE)
    
    # Always include if flagged for review
    if (isTRUE(status$needs_review)) return(TRUE)
    
    # Skip if manually overridden (manual data is managed outside the workflow)
    if (isTRUE(status$manual_override) && status$extraction_status == "complete") return(FALSE)
    
    # Include if extraction date is missing or stale
    if (is.null(status$last_extraction_date) || nchar(status$last_extraction_date) == 0) return(TRUE)
    last_date <- suppressWarnings(as.Date(status$last_extraction_date))
    if (is.na(last_date)) return(TRUE)
    
    as.numeric(as_of - last_date) >= threshold
  })
  
  hospitals[keep]
}

#' Convenience: return a character vector of FAC codes from a hospital list.
#' Useful for logging and progress tracking.
get_fac_codes <- function(hospitals) {
  map_chr(hospitals, ~ as.character(.x$FAC))
}