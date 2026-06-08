# minutes_url_resolve.R
# Hybrid URL resolver for BoardMinuteLocationFile_v2.xlsx
#
# For each Y row where minutes_url is a page title rather than a proper URL:
#   1. Normalises base_url (adds https:// if missing)
#   2. Fetches the base page via fetcher.R infrastructure
#   3. Fuzzy-matches all same-domain <a> links against the known page title
#   4. Returns best candidate URL with confidence label
#
# Output: minutes_url_review.xlsx  (open directly in RStudio / Excel)
#   HIGH   (score >= 75) — safe to auto-apply
#   MEDIUM (score >= 50) — review before applying
#   LOW    (score <  50) — JS-rendered or blocked; manual URL lookup needed
#
# After review run minutes_url_apply.R to write confirmed URLs back to both
# the location file and hospital_registry.yaml.
#
# Run from RStudio with working directory set to the folder below, OR
# just source the file — paths are set explicitly.

library
library(tidyverse)
library(readxl)
library(rvest)
library(robotstxt)
library(stringr)
library(dplyr)
library(readxl)
library(writexl)

# ── Paths ──────────────────────────────────────────────────────────────────────
BASE_DIR      <- "E:/HospitalIntelligenceR/roles/minutes/ResearchOnMinutes/"
INPUT_FILE    <- file.path(BASE_DIR, "BoardMinuteLocationFile_v2.xlsx")
OUTPUT_FILE   <- file.path(BASE_DIR, "minutes_url_review.xlsx")

# fetcher.R lives in the shared core folder
source("E:/HospitalIntelligenceR/core/fetcher.R")

# ── Config ─────────────────────────────────────────────────────────────────────
HIGH_THRESH   <- 75
MEDIUM_THRESH <- 50

# ── Helpers ────────────────────────────────────────────────────────────────────

# Ensure base_url has https:// scheme
normalise_base_url <- function(url) {
  url <- str_trim(url)
  if (is.na(url) || url == "") return(NA_character_)
  if (!str_starts(url, "http")) url <- paste0("https://", url)
  url
}

# Strip site-name suffixes ("|  Site Name", "– Site Name"), lowercase,
# keep alphanumeric + space only, collapse whitespace
normalise_title <- function(s) {
  s <- str_replace(s, "[|\\u2013\\u2014].*$", "")
  s <- str_to_lower(s)
  s <- str_replace_all(s, "[^a-z0-9 ]", " ")
  str_squish(s)
}

# Order-independent word-overlap score, 0–100
token_set_ratio <- function(a, b) {
  a_words <- unique(str_split(a, " ")[[1]])
  b_words <- unique(str_split(b, " ")[[1]])
  if (length(a_words) == 0 || length(b_words) == 0) return(0L)
  n_intersection <- length(intersect(a_words, b_words))
  n_union        <- length(union(a_words, b_words))
  as.integer(round(100 * n_intersection / n_union))
}

# Extract same-domain links from a fetched rvest html_document
extract_links <- function(page, base_url) {
  base_domain <- str_extract(base_url, "(?<=https?://)([^/]+)")
  nodes <- html_elements(page, "a[href]")
  hrefs <- html_attr(nodes, "href")
  texts <- html_text2(nodes)
  
  full_urls <- sapply(hrefs, function(h) {
    h <- str_trim(h)
    if (is.na(h) || h == "" || str_starts(h, "#") || str_starts(h, "mailto")) {
      return(NA_character_)
    }
    if (str_starts(h, "http"))  return(h)
    if (str_starts(h, "//"))    return(paste0("https:", h))
    if (str_starts(h, "/"))     return(paste0("https://", base_domain, h))
    paste0(str_replace(base_url, "/$", ""), "/", h)
  }, USE.NAMES = FALSE)
  
  data.frame(href = full_urls, text = texts, stringsAsFactors = FALSE) |>
    filter(
      !is.na(href),
      str_detect(href, fixed(base_domain, ignore_case = TRUE)),
      str_length(str_trim(text)) > 2
    ) |>
    distinct(href, .keep_all = TRUE)
}

# Find best-matching link for a given page title
find_best_match <- function(links_df, target_title) {
  target_norm    <- normalise_title(target_title)
  links_df$norm  <- sapply(links_df$text, normalise_title)
  links_df$score <- sapply(links_df$norm,
                           function(t) token_set_ratio(target_norm, t))
  best <- links_df |> arrange(desc(score)) |> slice(1)
  if (nrow(best) == 0 || best$score == 0) {
    return(list(url = NA_character_, score = 0L, matched_text = NA_character_))
  }
  list(url = best$href, score = best$score, matched_text = best$text)
}

# ── Main ───────────────────────────────────────────────────────────────────────

cat("Reading:", INPUT_FILE, "\n")
loc      <- read_excel(INPUT_FILE)
loc$fac  <- as.character(as.integer(loc$fac))

# Normalise base_url for all rows before filtering
loc$base_url <- sapply(loc$base_url, normalise_base_url)

# Rows needing resolution: Y, minutes_url not a proper URL
to_resolve <- loc |>
  filter(
    minutes_found == "Y",
    !str_starts(coalesce(as.character(minutes_url), ""), "http")
  )

cat(sprintf("Rows to resolve: %d\n\n", nrow(to_resolve)))

results <- vector("list", nrow(to_resolve))

for (i in seq_len(nrow(to_resolve))) {
  row      <- to_resolve[i, ]
  fac      <- row$fac
  base_url <- row$base_url
  title    <- as.character(row$minutes_url)
  
  cat(sprintf("[%d/%d] FAC %s — %s\n",
              i, nrow(to_resolve), fac, str_trunc(row$hospital_name, 45)))
  
  # Minimal hospital stub for fetcher.R (robots check uses robots_allowed field)
  hospital_stub <- list(
    FAC           = fac,
    name          = row$hospital_name,
    base_url      = base_url,
    robots_allowed = "yes"
  )
  
  # No base URL — skip
  if (is.na(base_url)) {
    cat("  SKIP: no base_url\n")
    results[[i]] <- tibble(
      fac = fac, hospital_name = row$hospital_name,
      base_url = NA_character_, original_title = title,
      resolved_url = NA_character_, confidence_score = 0L,
      confidence_label = "LOW", matched_text = NA_character_,
      status = "no_base_url"
    )
    next
  }
  
  # Fetch base page using fetcher.R infrastructure
  fetch_result <- fetch_html(fac, base_url, hospital_stub)
  
  if (!fetch_result$success) {
    cat(sprintf("  SKIP: fetch failed — %s\n",
                coalesce(fetch_result$skip_reason, "unknown")))
    results[[i]] <- tibble(
      fac = fac, hospital_name = row$hospital_name,
      base_url = base_url, original_title = title,
      resolved_url = NA_character_, confidence_score = 0L,
      confidence_label = "LOW", matched_text = NA_character_,
      status = coalesce(fetch_result$skip_reason, "fetch_failed")
    )
    next
  }
  
  links <- extract_links(fetch_result$content, base_url)
  cat(sprintf("  Links found: %d\n", nrow(links)))
  
  if (nrow(links) == 0) {
    cat("  SKIP: no links extracted (likely JS-rendered)\n")
    results[[i]] <- tibble(
      fac = fac, hospital_name = row$hospital_name,
      base_url = base_url, original_title = title,
      resolved_url = NA_character_, confidence_score = 0L,
      confidence_label = "LOW", matched_text = NA_character_,
      status = "no_links_found"
    )
    next
  }
  
  match <- find_best_match(links, title)
  
  label <- case_when(
    match$score >= HIGH_THRESH   ~ "HIGH",
    match$score >= MEDIUM_THRESH ~ "MEDIUM",
    TRUE                         ~ "LOW"
  )
  
  cat(sprintf("  Score: %d [%s]\n", match$score, label))
  if (!is.na(match$url)) cat(sprintf("  → %s\n", str_trunc(match$url, 90)))
  
  results[[i]] <- tibble(
    fac              = fac,
    hospital_name    = row$hospital_name,
    base_url         = base_url,
    original_title   = title,
    resolved_url     = match$url,
    confidence_score = match$score,
    confidence_label = label,
    matched_text     = match$matched_text,
    status           = ifelse(is.na(match$url), "no_match", "matched")
  )
}

results_df <- bind_rows(results)

# ── Summary ────────────────────────────────────────────────────────────────────
cat("\n=== Resolution Summary ===\n")
cat(sprintf("HIGH   (auto-apply):   %d\n",
            sum(results_df$confidence_label == "HIGH",   na.rm = TRUE)))
cat(sprintf("MEDIUM (review):       %d\n",
            sum(results_df$confidence_label == "MEDIUM", na.rm = TRUE)))
cat(sprintf("LOW    (manual):       %d\n",
            sum(results_df$confidence_label == "LOW",    na.rm = TRUE)))

# Instructions column for reviewer
results_df <- results_df |>
  mutate(reviewer_action = case_when(
    confidence_label == "HIGH"   ~ "Auto-apply — verify if desired",
    confidence_label == "MEDIUM" ~ "Check resolved_url; correct or set to SKIP",
    TRUE                         ~ "Enter correct URL in resolved_url, or set to SKIP"
  ))

write_xlsx(results_df, OUTPUT_FILE)
cat(sprintf("\nReview file written: %s\n", OUTPUT_FILE))
cat("Next: review MEDIUM/LOW rows, then run minutes_url_apply.R\n")