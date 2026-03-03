# =============================================================================
# core/logger.R
# HospitalIntelligenceR — Shared Logging Infrastructure
#
# Responsibilities:
#   - Timestamped log entries at INFO / WARNING / ERROR levels
#   - Role-specific log files written to logs/<role>/
#   - Run summary: hospitals attempted, succeeded, failed, API cost
#   - Failure CSV: one row per failure, for manual triage
#
# Dependencies: none (base R only)
# Called by: all role extract.R modules
# =============================================================================


# -----------------------------------------------------------------------------
# 1. Session state
#    A single environment holds state for the current run so callers don't
#    need to pass a session object around.
# -----------------------------------------------------------------------------

.log_env <- new.env(parent = emptyenv())

.log_env$initialized  <- FALSE
.log_env$role         <- NULL
.log_env$run_id       <- NULL
.log_env$log_file     <- NULL
.log_env$failure_file <- NULL
.log_env$log_dir      <- NULL

# Counters (updated via log_outcome())
.log_env$n_attempted  <- 0L
.log_env$n_succeeded  <- 0L
.log_env$n_failed     <- 0L
.log_env$n_skipped    <- 0L
.log_env$total_cost   <- 0.0
.log_env$start_time   <- NULL


# -----------------------------------------------------------------------------
# 2. init_logger()
#    Call once at the top of each role's extract.R before processing begins.
#
#    role      : character — "strategy", "foundational", "executives",
#                            "board", or "minutes"
#    log_root  : character — path to the project-level logs/ directory
#                            (default: "logs" relative to working dir)
#    echo      : logical   — also write to console (default TRUE)
# -----------------------------------------------------------------------------

init_logger <- function(role,
                        log_root = "logs",
                        echo     = TRUE) {

  stopifnot(is.character(role), length(role) == 1L, nchar(role) > 0)

  run_id  <- format(Sys.time(), "%Y%m%d_%H%M%S")
  log_dir <- file.path(log_root, role)

  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  }

  log_file     <- file.path(log_dir, paste0("run_", run_id, ".log"))
  failure_file <- file.path(log_dir, paste0("failures_", run_id, ".csv"))

  # Write failure CSV header immediately so the file exists even for clean runs
  write.csv(
    data.frame(
      timestamp     = character(),
      fac           = character(),
      hospital_name = character(),
      failure_type  = character(),
      error_message = character(),
      url           = character(),
      context       = character(),
      stringsAsFactors = FALSE
    ),
    failure_file,
    row.names = FALSE
  )

  # Persist state
  .log_env$initialized  <- TRUE
  .log_env$role         <- role
  .log_env$run_id       <- run_id
  .log_env$log_file     <- log_file
  .log_env$failure_file <- failure_file
  .log_env$log_dir      <- log_dir
  .log_env$echo         <- echo
  .log_env$n_attempted  <- 0L
  .log_env$n_succeeded  <- 0L
  .log_env$n_failed     <- 0L
  .log_env$n_skipped    <- 0L
  .log_env$total_cost   <- 0.0
  .log_env$start_time   <- Sys.time()

  .write_log_line("INFO", sprintf(
    "Logger initialised | role: %s | run_id: %s", role, run_id
  ))

  invisible(list(
    role         = role,
    run_id       = run_id,
    log_file     = log_file,
    failure_file = failure_file
  ))
}


# -----------------------------------------------------------------------------
# 3. Core logging functions
#    log_info()    — routine progress messages
#    log_warning() — recoverable issues worth noting
#    log_error()   — non-recoverable per-hospital failures
# -----------------------------------------------------------------------------

log_info <- function(...) {
  .write_log_line("INFO", paste0(...))
}

log_warning <- function(...) {
  .write_log_line("WARNING", paste0(...))
}

log_error <- function(...) {
  .write_log_line("ERROR", paste0(...))
}

# Internal writer — not exported
.write_log_line <- function(level, message) {
  .assert_initialized()

  ts   <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  line <- sprintf("[%s] [%s] %s", ts, level, message)

  # Append to log file
  cat(line, "\n", file = .log_env$log_file, append = TRUE, sep = "")

  # Mirror to console if requested
  if (isTRUE(.log_env$echo)) {
    prefix <- switch(level,
      INFO    = "",
      WARNING = "  \u26a0 ",    # ⚠
      ERROR   = "  \u2717 ",    # ✗
      ""
    )
    cat(prefix, line, "\n", sep = "")
  }

  invisible(NULL)
}


# -----------------------------------------------------------------------------
# 4. log_outcome()
#    Called once per hospital after processing completes.
#    Updates session counters and — on failure — appends to the failure CSV.
#
#    fac          : FAC code (character)
#    hospital_name: display name (character)
#    outcome      : one of "success" / "failure" / "skipped"
#    cost         : numeric API cost in USD (0 for non-API steps)
#    failure_type : character — used only when outcome == "failure"
#                   Suggested values:
#                     "robots_disallowed"  — robots.txt blocked access
#                     "fetch_error"        — HTTP error from fetcher.R
#                     "crawl_no_candidate" — crawler found no usable URLs
#                     "api_error"          — Claude API call failed
#                     "parse_error"        — Claude response unparseable
#                     "empty_result"       — Claude returned no usable data
#                     "manual_override"    — hospital flagged for manual work
#    error_message: free-text error detail (character, optional)
#    url          : URL attempted at point of failure (character, optional)
#    context      : any extra diagnostic note (character, optional)
# -----------------------------------------------------------------------------

log_outcome <- function(fac,
                        hospital_name,
                        outcome,
                        cost          = 0.0,
                        failure_type  = NA_character_,
                        error_message = NA_character_,
                        url           = NA_character_,
                        context       = NA_character_) {

  .assert_initialized()

  stopifnot(outcome %in% c("success", "failure", "skipped"))

  .log_env$n_attempted <- .log_env$n_attempted + 1L
  .log_env$total_cost  <- .log_env$total_cost  + cost

  switch(outcome,
    success = {
      .log_env$n_succeeded <- .log_env$n_succeeded + 1L
      log_info(sprintf("FAC %s (%s) — SUCCESS | cost: $%.4f", fac, hospital_name, cost))
    },
    failure = {
      .log_env$n_failed <- .log_env$n_failed + 1L
      log_error(sprintf(
        "FAC %s (%s) — FAILURE | type: %s | %s",
        fac, hospital_name,
        ifelse(is.na(failure_type), "unknown", failure_type),
        ifelse(is.na(error_message), "", error_message)
      ))
      # Append row to failure CSV
      row <- data.frame(
        timestamp     = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        fac           = as.character(fac),
        hospital_name = as.character(hospital_name),
        failure_type  = as.character(ifelse(is.na(failure_type), "unknown", failure_type)),
        error_message = as.character(ifelse(is.na(error_message), "", error_message)),
        url           = as.character(ifelse(is.na(url), "", url)),
        context       = as.character(ifelse(is.na(context), "", context)),
        stringsAsFactors = FALSE
      )
      write.table(
        row,
        file      = .log_env$failure_file,
        sep       = ",",
        col.names = FALSE,
        row.names = FALSE,
        append    = TRUE,
        qmethod   = "double"
      )
    },
    skipped = {
      .log_env$n_skipped <- .log_env$n_skipped + 1L
      log_info(sprintf("FAC %s (%s) — SKIPPED | %s", fac, hospital_name,
                       ifelse(is.na(context), "", context)))
    }
  )

  invisible(NULL)
}


# -----------------------------------------------------------------------------
# 5. log_run_summary()
#    Call at the end of a role's extract.R to write the session summary
#    to the log file and print it to the console.
#
#    Returns the summary invisibly as a named list.
# -----------------------------------------------------------------------------

log_run_summary <- function() {
  .assert_initialized()

  end_time     <- Sys.time()
  elapsed_mins <- as.numeric(difftime(end_time, .log_env$start_time, units = "mins"))

  success_rate <- if (.log_env$n_attempted > 0) {
    round(.log_env$n_succeeded / .log_env$n_attempted * 100, 1)
  } else {
    NA_real_
  }

  summary_lines <- c(
    strrep("=", 72),
    sprintf("  RUN SUMMARY — role: %s | run_id: %s", .log_env$role, .log_env$run_id),
    strrep("=", 72),
    sprintf("  Attempted : %d", .log_env$n_attempted),
    sprintf("  Succeeded : %d", .log_env$n_succeeded),
    sprintf("  Failed    : %d", .log_env$n_failed),
    sprintf("  Skipped   : %d", .log_env$n_skipped),
    sprintf("  Success%%  : %s", ifelse(is.na(success_rate), "n/a",
                                        paste0(success_rate, "%"))),
    sprintf("  Total cost: $%.4f", .log_env$total_cost),
    sprintf("  Elapsed   : %.1f minutes", elapsed_mins),
    sprintf("  Log file  : %s", .log_env$log_file),
    sprintf("  Failures  : %s", .log_env$failure_file),
    strrep("=", 72)
  )

  block <- paste(summary_lines, collapse = "\n")

  # Write to log file
  cat(block, "\n", file = .log_env$log_file, append = TRUE, sep = "")

  # Always print summary to console regardless of echo setting
  cat(block, "\n", sep = "")

  invisible(list(
    role         = .log_env$role,
    run_id       = .log_env$run_id,
    n_attempted  = .log_env$n_attempted,
    n_succeeded  = .log_env$n_succeeded,
    n_failed     = .log_env$n_failed,
    n_skipped    = .log_env$n_skipped,
    success_rate = success_rate,
    total_cost   = .log_env$total_cost,
    elapsed_mins = elapsed_mins,
    log_file     = .log_env$log_file,
    failure_file = .log_env$failure_file
  ))
}


# -----------------------------------------------------------------------------
# 6. get_failure_log()
#    Convenience function to read the current run's failure CSV back into R
#    for inspection or downstream processing.
# -----------------------------------------------------------------------------

get_failure_log <- function() {
  .assert_initialized()
  read.csv(.log_env$failure_file, stringsAsFactors = FALSE)
}


# -----------------------------------------------------------------------------
# 7. Internal guard
# -----------------------------------------------------------------------------

.assert_initialized <- function() {
  if (!isTRUE(.log_env$initialized)) {
    stop("logger.R: call init_logger() before using any logging functions.")
  }
}
