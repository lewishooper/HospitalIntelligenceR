# =============================================================================
# core/claude_api.R
# HospitalIntelligenceR — Claude API Interface
#
# Responsibilities:
#   - Single function call_claude() used by all role extraction modules
#   - Retry logic with exponential backoff (up to 3 attempts)
#   - Cost calculation from token counts
#   - Audit log: one CSV row per API call for cost tracking
#   - API key read from environment variable ANTHROPIC_API_KEY
#
# Dependencies: httr2, jsonlite (base R otherwise)
# Called by: all role phase2_extract.R modules
#
# Usage:
#   source("core/claude_api.R")
#
#   result <- call_claude(
#     user_message  = "Extract the strategic plan from: ...",
#     system_prompt = "You are a precise data extraction assistant...",
#     model         = "claude-sonnet-4-20250514",
#     max_tokens    = 16000L,
#     temperature   = 0
#   )
#
#   result$response_text   # character — Claude's response
#   result$input_tokens    # integer
#   result$output_tokens   # integer
#   result$cost            # numeric — USD
#   result$error           # character or NULL — NULL means success
# =============================================================================

suppressPackageStartupMessages({
  library(httr2)
  library(jsonlite)
})


# =============================================================================
# 1. Cost table
#    Prices in USD per million tokens.
#    Update this table when Anthropic changes pricing.
#    Source: https://www.anthropic.com/pricing
# =============================================================================

.CLAUDE_PRICING <- list(
  "claude-sonnet-4-20250514" = list(input = 3.00,  output = 15.00),
  "claude-opus-4-20250514"   = list(input = 15.00, output = 75.00),
  "claude-haiku-4-20250307"  = list(input = 0.80,  output = 4.00)
)

.calculate_cost <- function(model, input_tokens, output_tokens) {
  pricing <- .CLAUDE_PRICING[[model]]
  if (is.null(pricing)) {
    # Unknown model — return NA with a warning rather than silently zero
    warning(sprintf("claude_api.R: no pricing entry for model '%s' — cost logged as NA", model))
    return(NA_real_)
  }
  (input_tokens  / 1e6 * pricing$input) +
  (output_tokens / 1e6 * pricing$output)
}


# =============================================================================
# 2. Audit log
#    Written to logs/api_audit.csv — one row per call.
#    Columns: timestamp, role, fac, model, input_tokens, output_tokens, cost_usd, status
# =============================================================================

.AUDIT_LOG_PATH <- "logs/api_audit.csv"

.write_audit_row <- function(role, fac, model,
                              input_tokens, output_tokens, cost_usd, status) {
  row <- data.frame(
    timestamp     = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    role          = as.character(role   %||% "unknown"),
    fac           = as.character(fac    %||% "unknown"),
    model         = as.character(model),
    input_tokens  = as.integer(input_tokens),
    output_tokens = as.integer(output_tokens),
    cost_usd      = round(as.numeric(cost_usd), 6),
    status        = as.character(status),
    stringsAsFactors = FALSE
  )

  # Ensure log directory exists
  log_dir <- dirname(.AUDIT_LOG_PATH)
  if (!dir.exists(log_dir)) {
    dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Write header only if file is new
  write_header <- !file.exists(.AUDIT_LOG_PATH)
  write.table(
    row,
    file      = .AUDIT_LOG_PATH,
    sep       = ",",
    col.names = write_header,
    row.names = FALSE,
    append    = !write_header,
    qmethod   = "double"
  )

  invisible(NULL)
}


# =============================================================================
# 3. call_claude()
#    The single public function exported by this module.
#
#    Parameters:
#      user_message  : character — the user turn content
#      system_prompt : character or NULL — system prompt (optional)
#      model         : character — Anthropic model string
#      max_tokens    : integer — maximum output tokens
#      temperature   : numeric — 0 for deterministic, up to 1
#      max_retries   : integer — number of retry attempts on transient failure
#      role          : character — calling role name, for audit log only
#      fac           : character — FAC code being processed, for audit log only
#
#    Returns a list:
#      $response_text  — character, Claude's response text (NULL on failure)
#      $input_tokens   — integer
#      $output_tokens  — integer
#      $cost           — numeric USD (NA if model pricing unknown)
#      $error          — character error message, or NULL on success
# =============================================================================

call_claude <- function(user_message,
                        system_prompt = NULL,
                        model         = "claude-sonnet-4-20250514",
                        max_tokens    = 16000L,
                        temperature   = 0,
                        max_retries   = 3L,
                        role          = NULL,
                        fac           = NULL) {

  # --- Resolve API key ---
  api_key <- Sys.getenv("ANTHROPIC_API_KEY")
  if (nchar(api_key) == 0) {
    stop(paste(
      "ANTHROPIC_API_KEY environment variable is not set.",
      "Add it to your .Renviron file: ANTHROPIC_API_KEY=sk-ant-...",
      "Then restart R or call readRenviron('~/.Renviron').",
      sep = "\n"
    ))
  }

  # --- Build request body ---
  body <- list(
    model       = model,
    max_tokens  = as.integer(max_tokens),
    temperature = temperature,
    messages    = list(
      list(role = "user", content = user_message)
    )
  )
  if (!is.null(system_prompt) && nchar(trimws(system_prompt)) > 0) {
    body$system <- system_prompt
  }

  # --- Retry loop with exponential backoff ---
  attempt    <- 1L
  last_error <- NULL

  while (attempt <= max_retries) {

    if (attempt > 1L) {
      wait_secs <- 2^(attempt - 1L)   # 2s, 4s, 8s
      log_info(sprintf(
        "claude_api: retry %d/%d for FAC %s — waiting %ds",
        attempt, max_retries, fac %||% "?", wait_secs
      ))
      Sys.sleep(wait_secs)
    }

    result <- tryCatch({

      resp <- request("https://api.anthropic.com/v1/messages") |>
        req_headers(
          "x-api-key"         = api_key,
          "anthropic-version" = "2023-06-01",
          "content-type"      = "application/json"
        ) |>
        req_body_raw(toJSON(body, auto_unbox = TRUE), type = "application/json") |>
        req_error(is_error = function(resp) FALSE) |>  # handle errors manually
        req_perform()

      http_status <- resp_status(resp)
      resp_body   <- resp_body_string(resp)
      resp_json   <- fromJSON(resp_body, simplifyVector = FALSE)

      # --- Non-200 responses ---
      if (http_status != 200L) {
        err_msg <- resp_json$error$message %||%
                   resp_json$error$type    %||%
                   sprintf("HTTP %d", http_status)

        # 429 and 529 are rate-limit / overload — always worth retrying
        # 5xx are server errors — retry
        # 4xx (except 429) are client errors — don't retry
        is_retryable <- http_status %in% c(429L, 529L) ||
                        (http_status >= 500L && http_status < 600L)

        if (!is_retryable) {
          # Return immediately — retrying won't help
          last_error <- sprintf("Non-retryable API error (HTTP %d): %s",
                                http_status, err_msg)
          return(list(terminal = TRUE, error = last_error))
        }

        last_error <- sprintf("API error (HTTP %d): %s", http_status, err_msg)
        return(list(terminal = FALSE, error = last_error))
      }

      # --- Parse successful response ---
      content_blocks <- resp_json$content
      response_text  <- paste(
        sapply(content_blocks, function(b) if (!is.null(b$text)) b$text else ""),
        collapse = "\n"
      )

      usage         <- resp_json$usage
      input_tokens  <- as.integer(usage$input_tokens  %||% 0L)
      output_tokens <- as.integer(usage$output_tokens %||% 0L)
      cost          <- .calculate_cost(model, input_tokens, output_tokens)

      .write_audit_row(role, fac, model, input_tokens, output_tokens,
                       cost %||% 0, "success")

      list(
        terminal      = FALSE,
        success       = TRUE,
        response_text = response_text,
        input_tokens  = input_tokens,
        output_tokens = output_tokens,
        cost          = cost,
        error         = NULL
      )

    }, error = function(e) {
      # Network-level or httr2 error
      last_error <<- conditionMessage(e)
      list(terminal = FALSE, error = last_error)
    })

    # --- Evaluate result ---
    if (isTRUE(result$terminal)) {
      # Non-retryable — bail immediately
      .write_audit_row(role, fac, model, 0L, 0L, 0, "terminal_error")
      return(list(
        response_text = NULL,
        input_tokens  = 0L,
        output_tokens = 0L,
        cost          = 0.0,
        error         = result$error
      ))
    }

    if (isTRUE(result$success)) {
      return(list(
        response_text = result$response_text,
        input_tokens  = result$input_tokens,
        output_tokens = result$output_tokens,
        cost          = result$cost,
        error         = NULL
      ))
    }

    # Retryable failure — loop
    attempt <- attempt + 1L
  }

  # --- All retries exhausted ---
  .write_audit_row(role, fac, model, 0L, 0L, 0, "all_retries_failed")
  list(
    response_text = NULL,
    input_tokens  = 0L,
    output_tokens = 0L,
    cost          = 0.0,
    error         = sprintf("All %d attempts failed. Last error: %s",
                             max_retries, last_error %||% "unknown")
  )
}


# =============================================================================
# 4. call_claude_images()
#    Identical contract to call_claude() but accepts a list of base64-encoded
#    PNG images (rendered PDF pages) rather than a text string.
#
#    Parameters:
#      images        : list of named lists, each with:
#                        $data       — base64-encoded PNG string
#                        $media_type — always "image/png" here
#      system_prompt : character or NULL
#      model         : character
#      max_tokens    : integer
#      temperature   : numeric
#      max_retries   : integer
#      role          : character (audit log)
#      fac           : character (audit log)
#
#    Returns the same list structure as call_claude().
# =============================================================================

call_claude_images <- function(images,
                               system_prompt = NULL,
                               model         = "claude-sonnet-4-20250514",
                               max_tokens    = 16000L,
                               temperature   = 0,
                               max_retries   = 3L,
                               role          = NULL,
                               fac           = NULL) {
  
  # --- Resolve API key ---
  api_key <- Sys.getenv("ANTHROPIC_API_KEY")
  if (nchar(api_key) == 0) {
    stop(paste(
      "ANTHROPIC_API_KEY environment variable is not set.",
      "Add it to your .Renviron file: ANTHROPIC_API_KEY=sk-ant-...",
      "Then restart R or call readRenviron('~/.Renviron').",
      sep = "\n"
    ))
  }
  
  # --- Build content blocks: one image block per page ---
  image_blocks <- lapply(images, function(img) {
    list(
      type   = "image",
      source = list(
        type       = "base64",
        media_type = img$media_type,
        data       = img$data
      )
    )
  })
  
  # Append a text block instructing Claude to extract from the images
  content_blocks <- c(image_blocks, list(
    list(
      type = "text",
      text = "Extract the strategic plan information from the document pages shown above."
    )
  ))
  
  body <- list(
    model      = model,
    max_tokens = as.integer(max_tokens),
    temperature = temperature,
    messages   = list(
      list(role = "user", content = content_blocks)
    )
  )
  if (!is.null(system_prompt) && nchar(trimws(system_prompt)) > 0) {
    body$system <- system_prompt
  }
  
  # --- Retry loop — identical structure to call_claude() ---
  attempt    <- 1L
  last_error <- NULL
  
  while (attempt <= max_retries) {
    
    if (attempt > 1L) {
      wait_secs <- 2^(attempt - 1L)
      log_info(sprintf(
        "claude_api: image-mode retry %d/%d for FAC %s — waiting %ds",
        attempt, max_retries, fac %||% "?", wait_secs
      ))
      Sys.sleep(wait_secs)
    }
    
    result <- tryCatch({
      
      resp <- request("https://api.anthropic.com/v1/messages") |>
        req_headers(
          "x-api-key"         = api_key,
          "anthropic-version" = "2023-06-01",
          "content-type"      = "application/json"
        ) |>
        req_body_raw(toJSON(body, auto_unbox = TRUE), type = "application/json") |>
        req_error(is_error = function(resp) FALSE) |>
        req_perform()
      
      http_status <- resp_status(resp)
      resp_body   <- resp_body_string(resp)
      resp_json   <- fromJSON(resp_body, simplifyVector = FALSE)
      
      if (http_status != 200L) {
        err_msg <- resp_json$error$message %||%
          resp_json$error$type    %||%
          sprintf("HTTP %d", http_status)
        
        is_retryable <- http_status %in% c(429L, 529L) ||
          (http_status >= 500L && http_status < 600L)
        
        if (!is_retryable) {
          last_error <- sprintf("Non-retryable API error (HTTP %d): %s",
                                http_status, err_msg)
          return(list(terminal = TRUE, error = last_error))
        }
        
        last_error <- sprintf("API error (HTTP %d): %s", http_status, err_msg)
        return(list(terminal = FALSE, error = last_error))
      }
      
      content_blocks_resp <- resp_json$content
      response_text <- paste(
        sapply(content_blocks_resp,
               function(b) if (!is.null(b$text)) b$text else ""),
        collapse = "\n"
      )
      
      usage         <- resp_json$usage
      input_tokens  <- as.integer(usage$input_tokens  %||% 0L)
      output_tokens <- as.integer(usage$output_tokens %||% 0L)
      cost          <- .calculate_cost(model, input_tokens, output_tokens)
      
      .write_audit_row(role, fac, model, input_tokens, output_tokens,
                       cost %||% 0, "success_image_mode")
      
      list(
        terminal      = FALSE,
        success       = TRUE,
        response_text = response_text,
        input_tokens  = input_tokens,
        output_tokens = output_tokens,
        cost          = cost,
        error         = NULL
      )
      
    }, error = function(e) {
      last_error <<- conditionMessage(e)
      list(terminal = FALSE, error = last_error)
    })
    
    if (isTRUE(result$terminal)) {
      .write_audit_row(role, fac, model, 0L, 0L, 0, "terminal_error_image_mode")
      return(list(
        response_text = NULL,
        input_tokens  = 0L,
        output_tokens = 0L,
        cost          = 0.0,
        error         = result$error
      ))
    }
    
    if (isTRUE(result$success)) {
      return(list(
        response_text = result$response_text,
        input_tokens  = result$input_tokens,
        output_tokens = result$output_tokens,
        cost          = result$cost,
        error         = NULL
      ))
    }
    
    attempt <- attempt + 1L
  }
  
  .write_audit_row(role, fac, model, 0L, 0L, 0, "all_retries_failed_image_mode")
  list(
    response_text = NULL,
    input_tokens  = 0L,
    output_tokens = 0L,
    cost          = 0.0,
    error         = sprintf("All %d attempts failed. Last error: %s",
                            max_retries, last_error %||% "unknown")
  )
}


# =============================================================================
# 5. read_audit_log()
#    Convenience function — returns the full audit log as a data frame.
#    Useful for cost inspection between runs.
# =============================================================================

read_audit_log <- function() {
  if (!file.exists(.AUDIT_LOG_PATH)) {
    message("No audit log found at: ", .AUDIT_LOG_PATH)
    return(invisible(NULL))
  }
  read.csv(.AUDIT_LOG_PATH, stringsAsFactors = FALSE)
}


# =============================================================================
# 5. Null-coalescing operator (if not already defined by another module)
# =============================================================================

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (!is.null(a) && length(a) > 0) a else b
}
