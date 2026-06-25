classify_document <- function(text, ollama_url = "http://YOUR_UBUNTU_IP:11434") {
  
  prompt <- paste0(
    "You are classifying municipal documents.\n\n",
    "Classify the following document as either:\n",
    "- BoardMinutes: the document contains ONLY board meeting minutes\n",
    "- NotJustMinutes: the document contains other content (agendas, reports, etc.),",
    " with or without minutes\n\n",
    "Respond ONLY with valid JSON in this exact format:\n",
    '{"classification": "BoardMinutes or NotJustMinutes", ',
    '"confidence": "high or medium or low", ',
    '"reasoning": "one sentence"}\n\n',
    "Document text:\n", text
  )
  
  body <- list(
    model = "llama3.1:8b",
    prompt = prompt,
    stream = FALSE
  )
  
  resp <- request(paste0(ollama_url, "/api/generate")) |>
    req_body_json(body) |>
    req_timeout(60) |>
    req_perform()
  
  raw <- resp |> resp_body_json()
  fromJSON(raw$response)
}

tesseract_info()

#rm(list=ls())
