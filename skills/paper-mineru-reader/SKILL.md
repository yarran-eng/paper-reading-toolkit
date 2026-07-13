---
name: paper-mineru-reader
description: 'Trigger when the user inputs "读文献：" or "读文献:" followed by a PDF path, URL, or directory. Automatically parses the PDF with dual-engine (MinerU VLM + agent's PDF skill) for maximum accuracy, performs content-comparison fusion arbitration per unit, then applies the literature-deep-reading 4-stage methodology. Trigger keywords: "读文献", "用MinerU读论文", "MinerU读文献", "用MinerU解析文献", "用MinerU解析这篇论文", "parse paper", "read paper with MinerU"; also trigger when a PDF is present and the user asks to read, parse, summarize, or analyze it with MinerU.'
requires: literature-deep-reading
when_to_use: 'User says "读文献：<path>" or "读文献:<path>", or asks to read/parse/analyze a PDF with MinerU. Trigger keywords: 读文献, 用MinerU读论文, MinerU读文献, 用MinerU解析, parse paper, read paper with MinerU.'
---

# Paper MinerU Reader — Dual-Engine Fusion Parsing + 3-Stage Deep Reading

## Purpose

This skill is the **orchestration layer for reading academic papers**. It runs two independent PDF parsing engines in parallel, then merges their outputs by comparing actual content quality per unit — not by consulting a static lookup table. The fused result then feeds into `literature-deep-reading` for a rigorous 4-stage deep reading workflow.

- **Primary purpose**: Read academic papers with maximum PDF parsing accuracy
- **Core strategy**: Dual-engine parallel parsing → content-comparison fusion → 4-stage deep reading
- **Target users**: Masters students, PhD candidates, and researchers
- **Sole use case**: Reading academic papers and literature (not general PDF processing)

## Core Rules

- **Output language**: Always output analysis in Chinese unless the user explicitly requests otherwise. All system instructions below are in English; the content delivered to the user must be in Chinese.
- **No direct PDF read**: Never use the Read tool to ingest a PDF directly. Always route through Engine A (MinerU VLM). Also route through Engine B (agent's PDF skill) when available.
- **Dual-engine parallel**: Engine A (MinerU VLM) and Engine B (agent's PDF skill) start simultaneously.
- **Content-comparison fusion**: After both engines finish, compare their actual outputs per content unit. Use the capability table as an initial guideline only — the final decision must be based on real output quality.
- **Source transparency**: Every content unit in the fused output must carry a source annotation.
- **Stage control**: The 4-stage deep reading follows a strict state machine; never advance stages without the explicit trigger phrase.
- **Graceful degradation**: Both engines run in parallel. If one fails, retry once; if it still fails, skip it and proceed with the remaining engine. The tool works with one engine. Never fall back to pdfplumber, PyMuPDF, or any raw extraction library — their bare text output cannot complement MinerU VLM and only adds noise.
- **Cloud awareness**: MinerU uploads documents to a cloud API. Warn the user before uploading confidential files.
- **Agent agnostic**: This skill works with any AI agent that supports skill/plugin invocation. Use the agent's native mechanism to call PDF capabilities for Engine B. The skill has been tested with various agents (ZCode, Codex, Claude Code, Trae Work, and others) but is not tied to any specific platform.

---

## Complete Workflow

```
[1] Extract path from user input
    ↓
[2B] Engine B starts (typically fast)
    │  Invoke the agent's PDF skill (built-in or user-installed) for text/tables/images
    │  Retry once on failure; skip if unavailable
    ↓  (simultaneously)
[2A] Engine A starts (1-5 minutes, cloud)
    │  MinerU VLM: Direct Python call
    ↓
[3] Read both engine outputs
    │  Determine PDF type (text-based / scanned / mixed)
    ↓
[4] Content-comparison fusion (critical — never skip)
    │  Compare actual outputs per content unit → quality judgment → merge
    │  Generate fused Markdown with source annotations
    ↓
[5] 3-Stage Deep Reading
    │  Feed fused Markdown into literature-deep-reading skill
```

---

## Step 1: Extract Path

Extract the PDF path or URL from the user's input. Supports:

- Absolute path: `C:\Users\...\paper.pdf`
- Relative path: relative to current working directory
- URL: online PDF link
- Directory: batch-parse all PDFs in a directory (process each PDF through the full pipeline individually)

If no path is provided, ask the user for a file path, URL, or DOI.

---

## Step 2A: Engine A — MinerU VLM (Cloud Visual Model)

Tell the user: "正在用 MinerU VLM 解析 PDF（引擎 A），可能需要 1-5 分钟，请稍候。"

### Locating the Toolkit Root

Before calling Engine A, locate the paper-reading-toolkit root directory using (in priority order):

1. **`PAPER_TOOLKIT_ROOT` environment variable**
2. **Search known installation paths**:
   - `<user home>/Skill/paper-reading-toolkit`
   - `<project root>/Skill/paper-reading-toolkit`
   - `/opt/paper-reading-toolkit` (Linux/macOS shared installs)

Once found, the MinerU script is at: `<TOOLKIT_ROOT>/MinerU-Skill/scripts/mineru.py`

---

### Direct Python Call

Call `mineru.py` directly with Python — no wrapper scripts needed.

**Step A — Find a Python interpreter:**
```bash
# Priority order:
# 1. PAPER_TOOLKIT_PYTHON environment variable
# 2. sys.executable (the Python running the current process)
# 3. Windows: newest Python3* under %LOCALAPPDATA%/Programs/Python/
# 4. python3 or python on PATH
```

**Step B — Call mineru.py directly:**
```bash
<PYTHON> "<TOOLKIT_ROOT>/MinerU-Skill/scripts/mineru.py" \
  "<PDF_PATH>" \
  --output "<WORK_DIR>/parsed" \
  --ocr \
  --chunk \
  --lang ch
```

**Token notes:**
- A `MINERU_TOKEN` is **required** — this ensures Standard API VLM (highest parsing accuracy).
- Obtain a token from: https://mineru.net/apiManage/token
- Set it as an environment variable: `MINERU_TOKEN`
- The free Agent API is intentionally not used — it produces lower-quality output.

---

**Output structure:**
```
parsed/
  <filename>/
    <filename>.md          ← Main Markdown
    <filename>_origin.md   ← Original Markdown
    images/                ← Extracted images
    <filename>_chunks.json ← Chunked file (if --chunk enabled)
```

**Troubleshooting:**
- If MinerU reports "token not set": set the `MINERU_TOKEN` environment variable. Obtain from https://mineru.net/apiManage/token

---

## Step 2B: Engine B — Agent's PDF Skill

Start simultaneously with Engine A. Engine B is typically fast.

Check what PDF-capable skills the current agent has available. This includes both **built-in PDF skills** (e.g., `Skill("pdf")`) and **user-installed skills** from skill stores, plugin marketplaces, or GitHub (e.g., `document-skills:pdf`, document analysis skills, PDF extraction skills). Invoke the best available one using the agent's native skill/plugin mechanism.

Apply these extraction strategies (use whichever the agent's PDF skill supports — skip unsupported ones):

- **Text extraction**: Use the most layout-aware method available (e.g., `layout=True` with tight tolerance). If the PDF skill lacks layout options, use its default text extraction.
- **Over-long token repair**: If extracted tokens are abnormally long, fall back to word-level extraction and repair missing whitespace
- **Garbage cleanup**: Strip `(cid:xxx)` garbage tokens and control characters
- **Table extraction**: Attempt table extraction if the PDF skill supports it. Use line-and-text strategies with borderless-table fallback where available.
- **Image extraction**: Extract embedded images in the best quality the PDF skill supports
- **Long-document awareness**: For papers >20 pages, the PDF skill may need multiple calls to cover all pages

Both engines are expected to work — Engine A via the MinerU cloud API, Engine B via the agent's PDF skill. If Engine B fails to start or produces no usable output, retry once; if it still fails, skip it and note in the fusion summary: "Engine B unavailable — using MinerU VLM output only."

**Never fall back to pdfplumber, PyMuPDF, or any raw extraction library.** These tools produce bare text without layout understanding, formula recognition, or table structuring — their output cannot complement MinerU VLM and only adds noise.

---

## Step 3: Read Dual-Engine Outputs

After both engines complete (or one fails), read their outputs:

1. **Engine A output**: Read `parsed/<filename>/<filename>.md` (main Markdown). Read the full file — it contains the complete parsed document.
2. **Engine B output**: Read the output produced by the agent's PDF skill. The format depends on the specific skill used — adapt accordingly. Read the full output — the fusion step requires both engines' outputs for corresponding sections. If the paper is too long for a single context window, process it in batches of 5-10 pages at a time, running fusion incrementally per batch.

If Engine B was skipped (no PDF skill available), there is no Engine B output to read — proceed to Step 4 with Engine A output only.

If an engine's output directory is missing or empty, mark that engine as "failed" and skip its output.

### Step 3.1: Determine PDF Type

Based on Engine B's text extraction results, classify the PDF. If Engine B was skipped (no PDF skill available), determine PDF type from Engine A's output alone, or mark as "unknown" and proceed with Engine A only.

| PDF Type | Criterion | Text Preference | Table Preference |
|---|---|---|---|
| **text-based** | Most pages have extractable text | Both engines viable — compare actual quality | Both engines viable — compare actual quality |
| **scanned** | Most pages have no text layer | Expect Engine A stronger (OCR), Engine B may be empty | Expect Engine A stronger |
| **mixed** | Both types present | Per-page decision | Per-page decision |

This classification is **informational only** — it sets an expectation but does NOT automatically choose a winner. The final decision always comes from comparing actual outputs.

---

## Step 4: Content-Comparison Fusion (Core Innovation — Never Skip)

This is the heart of the dual-engine approach. Do NOT consult a static lookup table and blindly pick a predetermined winner. Instead, **compare the actual parsed content** from both engines for every content unit and make a quality-based judgment.

### Step 4.1: Identify Content Units

Segment the paper into logical content units. A content unit may be:
- A paragraph of body text
- A table (with caption)
- A formula / equation block
- A figure (with caption)
- A section header

### Step 4.2: Per-Unit Comparison Process

For **each content unit**, follow this decision process:

```
For each content unit:
├── Both Engine A and Engine B have it → QUALITY COMPARISON (Step 4.3)
├── Only Engine A has it → Use A, mark <!-- source: MinerU -->
├── Only Engine B has it → Use B, mark <!-- source: PDF skill -->
└── Neither has it → Mark <!-- unparseable -->
```

### Step 4.3: Quality Comparison (When Both Engines Have the Unit)

When both engines produced output for the same content unit, **read and compare the actual text**. Do not assume one engine is better based on content type alone. Judge based on these criteria, in priority order:

1. **Completeness** — Which output contains more of the expected content? Is one missing sentences, rows, or data points that the other includes?

2. **Correctness** — Which output has fewer errors? Look for:
   - Garbled characters / mojibake
   - OCR noise (random symbols, split words)
   - Missing or duplicated content
   - Correct number of rows × columns in tables
   - Formula integrity (LaTeX that actually compiles)

3. **Structure preservation** — Which output preserves the document structure better? Consider:
   - Reading order (especially for multi-column layouts)
   - Section hierarchy
   - Table structure (merged cells, headers)
   - Caption-to-figure association

4. **Fidelity** — Which output is truer to the original? Consider:
   - Numerical precision in tables (exact values vs. OCR approximations)
   - Special characters and symbols
   - Whitespace and formatting that affects meaning

### Step 4.4: Making the Decision

After comparing, choose ONE of these outcomes per content unit:

| Decision | When to Apply |
|---|---|
| **Use A** | Engine A's output is clearly superior on the criteria above |
| **Use B** | Engine B's output is clearly superior |
| **Merge A+B** | Both have strengths: take complementary parts. E.g., A has better formula rendering but B has more precise table numbers — include both, annotate the merge |
| **Flag conflict** | The outputs disagree on factual content (e.g., different numbers in a table cell). Include both values and flag: `<!-- CONFLICT: MinerU=X, PDF skill=Y, please verify against original PDF -->` |
| **Mark unparseable** | Neither output is usable for this unit |

### Step 4.5: Capability Reference (Guideline Only)

The table below describes the *typical* strengths of each engine. Use it to **inform your comparison** — it tells you what to pay attention to — but it is **not a substitute for comparing actual output**.

| Capability | Engine A (MinerU VLM) | Engine B (Built-in PDF) |
|---|---|---|
| Body text (text-based PDF) | Good, may have minor OCR noise | Typically excellent (direct text layer) |
| Body text (scanned PDF) | Strong (VLM OCR) | Fails (no text layer) |
| Bordered tables | Good | Typically excellent (precise values) |
| Borderless / 3-line tables | Strong (VLM understanding) | Weak (may miss entirely) |
| Cross-page tables | Strong | Fails (page-by-page only) |
| Formula → LaTeX | Strong | Not supported |
| Figure data understanding | Strong (semantic extraction) | Not supported |
| Embedded image extraction | Good (may recompress) | Excellent (lossless original) |
| Complex / multi-column layout | Strong | May misorder |

> **Key principle**: This table tells you "Engine B usually handles bordered tables well." But if for *this specific table* Engine B's output is garbled and Engine A's is clean, you choose A — even though the table says B is "typically excellent." **The actual output always overrides the guideline.**

### Step 4.6: Generate and Save Fused Markdown

Assemble the final fused Markdown and **write it to a file** at `<WORK_DIR>/fused/<filename>_fused.md`

- **Structure**: Follow the document structure from whichever engine preserved it better. Judge section hierarchy, heading levels, and reading order quality from both engines equally.
- **Content**: Insert the winning content for each unit
- **Source annotations**: Every content unit carries one of:
  - `<!-- source: MinerU -->`
  - `<!-- source: PDF skill -->`
  - `<!-- source: merged (A+B) -->`
  - `<!-- source: unparseable -->`
- **Conflict annotations**: When values disagree:
  - `<!-- CONFLICT: MinerU reports X, PDF skill reports Y. Please verify against the original PDF. -->`
- **Fusion summary header**: Prepend this summary at the top of the fused Markdown:
  ```
  ## Fusion Summary
  - PDF type: text-based / scanned / mixed
  - Engine A (MinerU VLM): succeeded / failed — N content units captured
  - Engine B (PDF skill): succeeded / failed / unavailable — N content units captured
  - Fusion result: total N units → MinerU X, PDF skill Y, merged Z, unparseable W
  ```

### Outcome Handling

| Scenario | Action |
|---|---|
| Both engines succeed | Full content-comparison fusion |
| Engine A succeeds, Engine B fails | Use Engine A only; note "Engine B failed (after retry)" |
| Engine A fails, Engine B succeeds | Use Engine B only; note "Engine A failed — formulas and figure semantics may be missing" |
| Engine A succeeds, Engine B unavailable | Use Engine A only; note "Engine B unavailable (agent lacks a PDF skill)" |
| Both fail | Inform user; suggest checking MINERU_TOKEN, Python availability, and PDF file integrity |

---

## Step 5: 4-Stage Deep Reading

Read the fused Markdown from `<WORK_DIR>/fused/<filename>_fused.md`. Pass its full content as the source text when invoking the `literature-deep-reading` skill via the agent's skill mechanism (e.g., `Skill("literature-deep-reading")`). The fused Markdown is already the authoritative source — it will be used directly for the 4-stage analysis.

Strictly follow the `literature-deep-reading` 4-stage state machine:

1. **Initial trigger** → Output Stage 1 only (Macro Skeleton & Full-Paper Map)
2. User inputs "进入阶段二" → Output Stage 2 (Mechanism Deep Dive)
3. User inputs "进入阶段三" → Output Stage 3 (Knowledge Internalization & Reproduction Roadmap)
4. User inputs "进入阶段四" → Output Stage 4 (Self-Contained Conclusion)
5. Inter-stage questions → Answer at current-stage depth; do not auto-advance

---

## Notes

- MinerU's cloud VLM delivers far superior parsing quality vs. direct PDF reads (especially for tables, formulas, and scanned documents)
- Cross-verify table values from parsing results against the original PDF before citing
- For confidential files, always ask the user before uploading to the cloud
- This skill works across all projects and all compatible AI agents — it is not tied to any specific working directory or agent platform
- The dual-engine advantage is complementary: MinerU excels at formulas, complex tables, and VLM-level semantic understanding but may introduce OCR noise; the agent's PDF skill (built-in or user-installed) provides precise text-layer access and lossless image extraction. Fusion captures the best of both. Raw extraction libraries (pdfplumber, PyMuPDF) are intentionally excluded — they lack the layout intelligence and structural understanding needed to complement MinerU VLM.
- **Environment variables**: `PAPER_TOOLKIT_ROOT` (toolkit location), `PAPER_TOOLKIT_PYTHON` (Python interpreter override), `MINERU_TOKEN` (MinerU Standard API token — **required**; obtain from https://mineru.net/apiManage/token)
