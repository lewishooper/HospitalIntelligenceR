# HospitalIntelligenceR
## Session Summary — June 22, 2026
## Board Minutes — Local LLM Evaluation (Sessions 1 & 2)
*For Claude Project Knowledge Repository*

---

## Next Session — Start Here

**Current priority:** Decide whether to proceed with the local LLM approach or
continue with the keyword-based `extract_minutes.R` build. The feasibility test
work plan (`BoardMinutes_LLM_FeasibilityTestPlan.md`) defines the evaluation
steps. A go/no-go decision is required before either path advances.

**First action:** Review `BoardMinutes_LLM_FeasibilityTestPlan.md` and confirm
which test phase to begin. If proceeding with LLM evaluation, the first
executable step is prompt tuning — revise the classification prompt per the
draft in that document and test against 20 hand-labelled documents (10 per
class). If reverting to the keyword extractor, pick up from the June 21
carry-forward list.

**Watch out for:**
- The LLM sessions referenced in this summary were conducted outside the normal
  project session pattern. Their summaries (`BoardMinutes_LLM_Session2_Summary.md`
  and a Session 1 summary, format unknown) do not follow project conventions and
  are not in the knowledge repository. This summary consolidates them. The
  original files should be retained locally but do not need to be uploaded.
- The Ubuntu IP address in the R code (`UBUNTU_IP`) is a placeholder. Substitute
  the actual LAN IP before any test run.
- GNOME RDP is still consuming ~789 MiB VRAM on the Ubuntu machine. This headroom
  is recoverable once the KVM switch is installed and RDP is stopped.
- The classification accuracy target (>90% at high/medium confidence) must be
  validated before Phase 2 build begins — do not skip this gate.

### Carry-Forward Items

| Item | Status | Notes |
|---|---|---|
| Prompt tuning — classification prompt | READY TO EXECUTE | Draft revised prompt in feasibility plan; test against 20 labelled docs |
| Build 20-document validation set | READY TO EXECUTE | 10 BoardMinutes + 10 NotJustMinutes; hand-label before running model |
| OCR quality check — DPI 400 fallback | READY TO EXECUTE | Try on garbled documents identified in Session 2 smoke test |
| KVM switch installation | PENDING HARDWARE | Will reclaim ~789 MiB VRAM; disable GNOME RDP after install |
| Phase 2 R pipeline (batch classification) | NOT STARTED | Blocked on Phase 1 prompt validation |
| Phase 3 R pipeline (text extraction) | NOT STARTED | Blocked on Phase 2 |
| LLM feasibility go/no-go decision | DECISION REQUIRED | Informs whether keyword extractor or LLM path proceeds |
| `extract_minutes.R` keyword extractor (original path) | ON HOLD | Resume if LLM approach fails feasibility test |
| All June 21 carry-forward items | ON HOLD | Superseded by LLM evaluation priority; revisit at go/no-go |

---

## Session Objectives

These two sessions (conducted June 21–22, 2026, outside the normal project
session pattern) evaluated whether a locally-hosted LLM could replace or
augment the keyword-based `extract_minutes.R` approach for board minutes
classification and extraction. Session 1 established infrastructure. Session 2
completed the network bridge and ran the first live classification tests.

---

## Work Completed

### 1. Architecture Decision — R Stays on Windows

The original assumption that R and Ollama would co-locate on the Ubuntu machine
was revised and rejected.

Final architecture: R/RStudio remains on Windows (existing mature setup, PDF
corpus, all output pipelines). Ubuntu runs Ollama as a dedicated GPU inference
server only. R calls the Ollama API over the 5 Gb LAN via `http://UBUNTU_IP:11434`.

Rationale: network latency over 5 Gb LAN adds 1–5 ms per document. LLM
inference takes 2–8 seconds per document. Network overhead is noise. Duplicating
R infrastructure on Ubuntu adds maintenance burden for no meaningful benefit.

### 2. Ubuntu Infrastructure — Ollama Network Exposure

Ollama configured to listen on all interfaces rather than localhost only:

```bash
# /etc/systemd/system/ollama.service.d/override.conf
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

Firewall opened to the Windows machine only:

```bash
sudo ufw allow from WINDOWS_IP to any port 11434
sudo systemctl restart ollama
```

**Infrastructure status at session end:**

| Component | Status |
|---|---|
| Ubuntu 24.04 | Running — headless preferred |
| NVIDIA GTX 1060 6 GB | GPU inference confirmed — 4678 MiB used by model |
| Ollama v0.7.20 | Running, network-exposed, listening on 0.0.0.0:11434 |
| llama3.1:8b | Loaded and responding |
| Firewall | Port 11434 open to Windows IP only |
| KVM switch | Ordered — not yet installed |
| GNOME RDP | Still running — consuming ~789 MiB VRAM (stop after KVM) |
| R on Windows | Working — existing mature setup |
| Tesseract 5.3.2 | Installed on Windows — English confirmed |
| R packages | httr2, jsonlite, tesseract, pdftools, magick — all working |
| Cross-machine API call | Smoke test passed |

### 3. OCR Decision — Tesseract for All Documents

PDFs in the corpus are a mix of text-based and scanned. Decision: use Tesseract
OCR for all documents as the default extraction method. This avoids conditional
logic mid-pipeline. It is slightly slower but consistent and reliable.

Default settings: `dpi = 300`, English language data. Fallback: `dpi = 400` for
documents where OCR quality is visibly poor.

### 4. Core R Functions Built and Tested

Four functions written and confirmed working in a smoke test against two sample
documents:

`extract_text_ocr()` — converts PDF pages to images, runs Tesseract OCR,
collapses to a single string with page-break markers.

`prepare_for_llm()` — trims extracted text to approximately 700 words to fit
within the llama3.1:8b 8k context window safely.

`classify_document()` — sends trimmed text to Ollama, returns parsed JSON with
`classification`, `confidence`, and `reasoning` fields.

`extract_and_classify()` — combined pipeline wrapper calling all three in
sequence. Returns a list with file name, text preview, and classification result.

Full working code is documented in the Session 2 summary file
(`BoardMinutes_LLM_Session2_Summary.md`), retained locally.

### 5. First Live Classification Results

Two documents tested end-to-end:

| File | Expected | Got | Confidence | Correct? |
|---|---|---|---|---|
| 2020-12-01_board_minutes.pdf | BoardMinutes | NotJustMinutes | high | ❌ |
| 2012-03-20_board_minutes.pdf | NotJustMinutes | NotJustMinutes | high | ✅ |

**Result 1 — misclassification analysis:** The model correctly identified
structural complexity (committees, reports, regional updates) but
over-classified. The document is pure minutes that contain committee reports as
embedded content within the minutes record — not a mixed package where minutes
are one section among separate primary documents. The prompt must draw this
distinction more explicitly.

**Result 2 — correct classification:** OCR text preview showed agenda-style
formatting, a meeting header for a future date, and virtual join instructions —
clearly not pure minutes. Some OCR garbling was noted (`"sea Creating salsa
Lonwanunten"`); this document may be a lower-quality scan. Monitor OCR quality
across the validation set.

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| R stays on Windows; Ubuntu = inference server only | No performance benefit from moving R; existing pipeline is mature; network latency is negligible relative to LLM inference time |
| Tesseract OCR for all documents (not conditional) | Consistent approach beats conditional text/scan logic; avoids mid-pipeline branching |
| 700-word trim for LLM input | Safe headroom within 8k context; classification signals (header, date, attendance) appear in the first page |
| `dpi = 300` default; `dpi = 400` fallback | Good quality/speed balance at 300; 400 reserved for confirmed poor-quality scans |
| KVM over RDP for Ubuntu access | Better experience; frees ~789 MiB VRAM currently consumed by GNOME remote session |
| No R on Ubuntu | Unnecessary duplication of a mature environment |
| Classification target: >90% at high/medium confidence before Phase 2 | Gate prevents building a batch pipeline on a poorly-calibrated prompt |

---

## Files Produced or Modified

| File | Location | Change |
|---|---|---|
| Ollama systemd override | Ubuntu: `/etc/systemd/system/ollama.service.d/override.conf` | Created — network exposure configuration |
| R functions (extract_text_ocr, prepare_for_llm, classify_document, extract_and_classify) | Windows: working R session | Written and smoke-tested — not yet saved as a named script |
| `BoardMinutes_LLM_Session2_Summary.md` | Local only — not in knowledge repository | Source document for this summary; retain locally |
| `SessionSummaryJune222026_LLM_Evaluation.md` | Upload to knowledge repository | This file |

---

## GitHub Commit Instructions

Nothing to commit this session. The R functions are not yet in a named script
file. Commit will occur after feasibility test phase is complete and a go/no-go
decision is made.

---

## Session End Checklist

- [ ] Upload `SessionSummaryJune222026_LLM_Evaluation.md` to knowledge repository
- [ ] Confirm Ubuntu IP and substitute into R code before next test run
- [ ] Review `BoardMinutes_LLM_FeasibilityTestPlan.md` and confirm go/no-go evaluation path
- [ ] Retain `BoardMinutes_LLM_Session2_Summary.md` locally — do not need to upload to knowledge repository (this summary supersedes it)
