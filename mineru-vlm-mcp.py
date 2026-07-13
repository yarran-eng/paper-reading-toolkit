#!/usr/bin/env python3
"""MCP server exposing one high-accuracy MinerU VLM paper parser tool."""

from __future__ import annotations

import glob
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MINERU_SCRIPT = ROOT / "MinerU-Skill" / "scripts" / "mineru.py"

PROTOCOL_VERSION = "2024-11-05"
SERVER_INFO = {"name": "mineru-vlm-paper-parser", "version": "2.0.0"}

TOOL = {
    "name": "parse_pdf_mineru",
    "description": (
        "Parse PDF with MinerU VLM."
    ),
    "inputSchema": {
        "type": "object",
        "properties": {
            "input": {"type": "string", "description": "Absolute PDF path, directory path, or URL."},
            "output_dir": {"type": "string", "description": "Output directory. Default: parsed."},
            "ocr": {"type": "boolean", "description": "Enable OCR. Default: true."},
            "chunk": {"type": "boolean", "description": "Emit RAG-friendly chunks. Default: true."},
            "workers": {"type": "integer", "description": "Parallel workers for batches. Default: 4."},
            "timeout": {"type": "integer", "description": "Per-input timeout in seconds. Default: 900."},
        },
        "required": ["input"],
    },
}


def _find_python() -> str | None:
    """Locate a Python interpreter, preferring user-configured paths."""
    # 1) Explicit override via environment variable
    env_python = os.environ.get("PAPER_TOOLKIT_PYTHON")
    if env_python and Path(env_python).is_file():
        return env_python

    # 2) The Python that is running this MCP server
    if Path(sys.executable).is_file():
        return sys.executable

    # 3) Windows: scan user-local Python installations (e.g. Python312, Python313)
    if sys.platform == "win32":
        local_app_data = os.environ.get("LOCALAPPDATA", "")
        if local_app_data:
            pattern = os.path.join(
                local_app_data, "Programs", "Python", "Python3*", "python.exe"
            )
            # Sort by numeric version (Python39 < Python312), newest first
            def _py_version(p: str) -> int:
                import re
                m = re.search(r'Python3(\d+)', p)
                return int(m.group(1)) if m else 0
            candidates = sorted(glob.glob(pattern), key=_py_version, reverse=True)
            for candidate in candidates:
                if Path(candidate).is_file():
                    return candidate

    # 4) Generic discovery via PATH
    for name in ("python3", "python"):
        found = shutil.which(name)
        if found:
            return found

    return None


def text_result(text: str, is_error: bool = False) -> dict:
    return {"content": [{"type": "text", "text": text}], "isError": is_error}


def call_parser(arguments: dict) -> dict:
    if not MINERU_SCRIPT.exists():
        return text_result(f"Parser script not found: {MINERU_SCRIPT}", True)

    # Require MINERU_TOKEN — no fallback to free Agent API.
    # This ensures every parse uses Standard API VLM (highest quality).
    if not os.environ.get("MINERU_TOKEN"):
        return text_result(
            "MINERU_TOKEN is required. This tool uses Standard API VLM for maximum "
            "parsing accuracy — the free Agent API is intentionally disabled to "
            "prevent quality degradation.\n"
            "Obtain a token from: https://mineru.net/apiManage/token",
            True,
        )

    python = _find_python()
    if python is None:
        return text_result(
            "No Python interpreter found. Set PAPER_TOOLKIT_PYTHON environment variable "
            "or ensure python3/python is on PATH.",
            True,
        )

    input_path = arguments["input"]
    output_dir = arguments.get("output_dir") or str(ROOT / "parsed")
    workers = str(arguments.get("workers") or 4)
    timeout = int(arguments.get("timeout") or 900)
    ocr = arguments.get("ocr", True)
    chunk = arguments.get("chunk", True)

    # Build command — call mineru.py directly (no PowerShell wrappers)
    cmd = [
        python,
        str(MINERU_SCRIPT),
        input_path,
        "--output", output_dir,
        "--engine", "cloud",
        "--model", "vlm",
        "--lang", "ch",
        "--workers", workers,
        "--timeout", str(timeout),
        "--resume",
    ]
    if ocr:
        cmd.append("--ocr")
    if chunk:
        cmd.append("--chunk")

    try:
        completed = subprocess.run(
            cmd,
            cwd=str(ROOT),
            text=True,
            capture_output=True,
            timeout=timeout + 60,
        )
    except subprocess.TimeoutExpired:
        return text_result(f"MinerU parse timed out after {timeout + 60}s.", True)
    except FileNotFoundError:
        return text_result(
            f"Python interpreter not found at: {python}. "
            "Set PAPER_TOOLKIT_PYTHON to a valid Python path.",
            True,
        )

    stdout = (completed.stdout or "").strip()
    stderr = (completed.stderr or "").strip()

    if completed.returncode != 0:
        return text_result(
            f"MinerU parse failed (exit code {completed.returncode}).\n\n{stdout}\n{stderr}",
            True,
        )

    return text_result(
        f"MinerU VLM parse completed.\nOutput directory: {output_dir}\n\n{stdout}"
    )


def route(method: str, params: dict) -> dict:
    if method == "initialize":
        return {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {"tools": {}},
            "serverInfo": SERVER_INFO,
        }
    if method == "tools/list":
        return {"tools": [TOOL]}
    if method == "tools/call":
        if params.get("name") != TOOL["name"]:
            return text_result(f"Unknown tool: {params.get('name')}", True)
        return call_parser(params.get("arguments") or {})
    raise KeyError(method)


def main() -> int:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
            result = route(request.get("method"), request.get("params") or {})
            if "id" in request:
                print(
                    json.dumps(
                        {"jsonrpc": "2.0", "id": request["id"], "result": result},
                        ensure_ascii=False,
                    ),
                    flush=True,
                )
        except Exception as exc:
            if "request" in locals() and "id" in request:
                print(
                    json.dumps(
                        {
                            "jsonrpc": "2.0",
                            "id": request["id"],
                            "error": {"code": -32603, "message": str(exc)},
                        },
                        ensure_ascii=False,
                    ),
                    flush=True,
                )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
