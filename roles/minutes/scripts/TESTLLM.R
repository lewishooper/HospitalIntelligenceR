library(tesseract)
library(pdftools)
library(magick)

extract_text_ocr <- function(pdf_path, dpi = 300, language = "eng") {
  
  # Convert PDF pages to images
  pages <- image_read_pdf(pdf_path, density = dpi)
  
  # Run OCR on each page
  eng <- tesseract(language)
  
  page_texts <- lapply(pages, function(page) {
    ocr_result <- tesseract::ocr(page, engine = eng)
    ocr_result
  })
  
  # Collapse all pages to one string
  full_text <- paste(page_texts, collapse = "\n\n--- PAGE BREAK ---\n\n")
  
  return(full_text)
}

prepare_for_llm <- function(text, max_words = 700) {
  words <- unlist(strsplit(text, "\\s+"))
  if (length(words) > max_words) {
    words <- words[1:max_words]
  }
  paste(words, collapse = " ")
}



extract_and_classify <- function(pdf_path, ollama_url = "http://192.168.3.112:11434") {
  
  message("Extracting text from: ", basename(pdf_path))
  raw_text <- extract_text_ocr(pdf_path)
  
  message("Preparing text for LLM...")
  trimmed_text <- prepare_for_llm(raw_text, max_words = 700)
  
  message("Classifying...")
  result <- classify_document(trimmed_text, ollama_url)
  
  # Return everything together for inspection
  list(
    file = basename(pdf_path),
    text_preview = substr(trimmed_text, 1, 300),
    classification = result$classification,
    confidence = result$confidence,
    reasoning = result$reasoning
  )
}
result_1<-extract_and_classify("E:/HospitalIntelligenceR/roles/minutes/outputs/extracted/592_NAPANEE_LENNOX_ADDINGTON/2020-12-01_board_minutes.pdf")
result_2<-extract_and_classify("E:/HospitalIntelligenceR/roles/minutes/outputs/extracted/661_CAMBRIDGE_MEMORIAL_HOSPITAL/2012-03-20_board_minutes.pdf")
