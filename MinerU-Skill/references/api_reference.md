# MinerU API Reference

Official docs: https://mineru.net/apiManage/docs · Token: https://mineru.net/apiManage/token

MinerU exposes **two** document-parsing APIs. This skill auto-routes between them.

| | 🎯 Standard API | ⚡ Agent API (lightweight) |
|---|---|---|
| Base URL | `https://mineru.net/api/v4` | `https://mineru.net/api/v1/agent` |
| Token | **required** (`Bearer`) | **none** (IP rate-limited) |
| Models | `pipeline` / `vlm` / `MinerU-HTML` | fixed lightweight `pipeline` |
| File size | ≤ 200 MB | ≤ 10 MB |
| Pages | ≤ 200 | ≤ 20 |
| Batch | ≤ 50 per request | single file only |
| Output | zip (Markdown + JSON, optional DOCX/HTML/LaTeX) | Markdown only (CDN link) |
| Designed for | high-accuracy / complex / batch | AI-agent / quick / no-login |

Free Standard-API quota: **1000 pages/day at highest priority** (overflow is lower priority).

---

## Authentication (Standard API)

```
Authorization: Bearer YOUR_API_TOKEN
```

Get a token at https://mineru.net/apiManage/token.

> **Response envelopes.** Business endpoints return `{"code":0,"data":{…},"msg":"ok"}`.
> The auth/gateway layer returns a *different* shape on failure:
> `{"success":false,"msgCode":"A0202","msg":"user authenticate failed"}`.
> Clients must handle both — this skill maps `msgCode` to the same error hints.

---

## Standard API endpoints (`/api/v4`)

### Single URL — `POST /extract/task`

```json
{
  "url": "https://example.com/doc.pdf",
  "model_version": "vlm",
  "is_ocr": false,
  "enable_formula": true,
  "enable_table": true,
  "language": "ch",
  "page_ranges": "1-10",
  "extra_formats": ["docx", "html"],
  "data_id": "my-document"
}
```
Response → `{ "code": 0, "data": { "task_id": "…" } }`. HTML inputs require `model_version: "MinerU-HTML"`.

### Get task result — `GET /extract/task/{task_id}`

```json
{ "code": 0, "data": { "task_id": "…", "state": "done", "full_zip_url": "https://…", "err_msg": "" } }
```

### Batch local upload — `POST /file-urls/batch`

Returns signed upload URLs; PUT each file (no `Content-Type`). Up to **50** files / request.

```json
{ "files": [ { "name": "doc.pdf", "data_id": "doc" } ], "model_version": "vlm" }
```
Response → `{ "code": 0, "data": { "batch_id": "…", "file_urls": ["https://…"] } }`.

### Batch URL — `POST /extract/task/batch`

```json
{ "files": [ { "url": "https://…/doc.pdf", "data_id": "doc" } ], "model_version": "vlm" }
```

### Batch results — `GET /extract-results/batch/{batch_id}`

```json
{ "code": 0, "data": { "batch_id": "…", "extract_result": [
  { "file_name": "doc.pdf", "state": "done", "full_zip_url": "https://…" }
] } }
```

---

## Agent API endpoints (`/api/v1/agent`) — no token

### URL — `POST /parse/url`

```json
{ "url": "https://…/doc.pdf", "language": "ch", "enable_table": true, "is_ocr": false, "enable_formula": true, "page_range": "1-10" }
```
`page_range` accepts `from-to` or a single page only (no commas). Returns `{ "code": 0, "data": { "task_id": "…" } }`.

### File — `POST /parse/file`

```json
{ "file_name": "doc.pdf", "language": "ch" }
```
Response → `{ "data": { "task_id": "…", "file_url": "https://oss…" } }`; PUT the file to `file_url`.

### Result — `GET /parse/{task_id}`

```json
{ "code": 0, "data": { "task_id": "…", "state": "done", "markdown_url": "https://cdn…/full.md" } }
```

---

## Task states

`pending` (queued) · `running` (parsing) · `converting` (format conversion) ·
`uploading` (downloading source, Agent) · `waiting-file` (awaiting upload) ·
`done` (complete) · `failed` (error).

---

## Parameters

| Parameter | Type | Default | Notes |
|-----------|------|---------|-------|
| `model_version` | string | `pipeline` | `pipeline`, `vlm` (recommended), `MinerU-HTML` (HTML only) |
| `is_ocr` | bool | `false` | OCR for scanned docs (pipeline/vlm) |
| `enable_formula` | bool | `true` | Formula recognition |
| `enable_table` | bool | `true` | Table recognition |
| `language` | string | `ch` | OCR language (see official `language` table) |
| `page_ranges` | string | all | Standard: `"2,4-6"`; Agent `page_range`: `"1-10"` only |
| `extra_formats` | array | `[]` | `docx` / `html` / `latex` (Standard only) |
| `data_id` | string | – | `[A-Za-z0-9_.-]`, ≤ 128 chars |
| `no_cache` | bool | `false` | Bypass URL cache (Standard) |
| `cache_tolerance` | int | `900` | Cache TTL seconds (Standard) |

---

## Limits

| | Standard | Agent |
|---|---|---|
| File size | 200 MB | 10 MB |
| Pages | 200 | 20 |
| Batch | 50 / request | 1 |
| Quota | 1000 pages/day priority | IP rate-limited (HTTP 429) |

Supported types: PDF, images (png/jpg/jpeg/jp2/webp/gif/bmp), Doc(x), Ppt(x), Xls(x); HTML is Standard-only.

---

## Error codes

| Code | Meaning |
|------|---------|
| `A0202` | Invalid token |
| `A0211` | Token expired |
| `-500` | Parameter error |
| `-10001` / `-10002` | Service error / invalid params |
| `-60002` | Unsupported file format |
| `-60003` / `-60004` | File read failed / empty file |
| `-60005` | File too large (> 200 MB) |
| `-60006` | Too many pages (> 200) |
| `-60008` | File read timeout (URL unreachable) |
| `-60010` | Parse failed |
| `-60015` / `-60016` | File / format conversion failed |
| `-60018` | Daily quota reached |
| `-60022` | Web page read failed (rate-limited) |
| **Agent API** | |
| `-30001` | Exceeds Agent 10 MB limit → use Standard API |
| `-30002` | Unsupported file type for Agent |
| `-30003` | Exceeds Agent 20-page limit → use Standard API or `--pages` |
| `-30004` | Invalid request parameters |
