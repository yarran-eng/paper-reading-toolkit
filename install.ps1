<#
.SYNOPSIS
    One-click global installer for the Paper Reading Toolkit.
.DESCRIPTION
    Installs at user level only (no project-level configuration):
    - Adds parse-paper to user PATH
    - Installs paper-mineru-reader and literature-deep-reading skills
      to the user's AI agent skills directory (~/.agents/skills/)
    - Checks MINERU_TOKEN environment variable

    Compatible with any AI agent that reads skills from ~/.agents/skills/
    (ZCode, Codex, Claude Code, Trae Work, and others).
.PARAMETER ToolkitRoot
    The toolkit root path (auto-detected if not specified).
.PARAMETER MineruToken
    Set MINERU_TOKEN environment variable (user-level). Only set if provided.
.EXAMPLE
    .\install.ps1
    .\install.ps1 -MineruToken "your-token-here"
#>
param(
    [string]$ToolkitRoot,
    [string]$MineruToken
)

$ErrorActionPreference = "Stop"

# Auto-detect toolkit root
if (-not $ToolkitRoot) {
    $ToolkitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$ToolkitRoot = (Resolve-Path $ToolkitRoot).Path

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Paper Reading Toolkit Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Toolkit Root: $ToolkitRoot" -ForegroundColor Gray
Write-Host ""

# --- Step 1: Check MINERU_TOKEN ---
Write-Host "[1/4] Checking MINERU_TOKEN..." -ForegroundColor Yellow
$token = $env:MINERU_TOKEN
if ($MineruToken) {
    $token = $MineruToken
    [Environment]::SetEnvironmentVariable("MINERU_TOKEN", $MineruToken, "User")
    $env:MINERU_TOKEN = $MineruToken
    Write-Host "  [OK] MINERU_TOKEN set as user-level environment variable." -ForegroundColor Green
} elseif ($token) {
    Write-Host "  [OK] MINERU_TOKEN already configured ($($token.Length) chars)." -ForegroundColor Green
} else {
    Write-Host "  [WARN] MINERU_TOKEN not found!" -ForegroundColor Red
    Write-Host "  Obtain your token from: https://mineru.net/apiManage/token" -ForegroundColor Yellow
    Write-Host "  Then re-run: install.ps1 -MineruToken 'your-token'" -ForegroundColor Yellow
    Write-Host "  A token is required — the free Agent API is intentionally disabled to prevent quality degradation." -ForegroundColor Gray
}

# --- Step 2: Add parse-paper to user PATH ---
Write-Host ""
Write-Host "[2/4] Adding parse-paper to user PATH..." -ForegroundColor Yellow
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -split ";" -contains $ToolkitRoot) {
    Write-Host "  [SKIP] $ToolkitRoot already in user PATH." -ForegroundColor Gray
} else {
    $newPath = "$userPath;$ToolkitRoot"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Write-Host "  [OK] Added $ToolkitRoot to user PATH." -ForegroundColor Green
    Write-Host "  Restart your terminal for PATH changes to take effect." -ForegroundColor Yellow
}

# --- Step 3: Install skills (agent-agnostic, user-level) ---
Write-Host ""
Write-Host "[3/4] Installing skills for your AI agent..." -ForegroundColor Yellow

# ~/.agents/skills/ is the standard user-level skills directory shared by
# ZCode, Codex, Claude Code, Trae Work, and other AI agents.
$skillsDir = Join-Path $env:USERPROFILE ".agents\skills"

# Install paper-mineru-reader
$skillName1 = "paper-mineru-reader"
$skillSrc1 = Join-Path $ToolkitRoot "skills\paper-mineru-reader\SKILL.md"
$skillDst1 = Join-Path $skillsDir $skillName1

if (Test-Path $skillSrc1) {
    if (-not (Test-Path $skillDst1)) {
        New-Item -ItemType Directory -Path $skillDst1 -Force | Out-Null
    }
    Copy-Item $skillSrc1 $skillDst1 -Force
    Write-Host "  [OK] $skillName1 installed to: $skillDst1" -ForegroundColor Green
} else {
    Write-Host "  [WARN] SKILL.md not found: $skillSrc1" -ForegroundColor Red
}

# Install literature-deep-reading
$skillName2 = "literature-deep-reading"
$skillSrc2 = Join-Path $ToolkitRoot "skills\literature-deep-reading\SKILL.md"
$skillDst2 = Join-Path $skillsDir $skillName2

if (Test-Path $skillSrc2) {
    if (-not (Test-Path $skillDst2)) {
        New-Item -ItemType Directory -Path $skillDst2 -Force | Out-Null
    }
    Copy-Item $skillSrc2 $skillDst2 -Force
    Write-Host "  [OK] $skillName2 installed to: $skillDst2" -ForegroundColor Green
} else {
    Write-Host "  [WARN] SKILL.md not found: $skillSrc2" -ForegroundColor Red
}

# --- Step 4: Set PAPER_TOOLKIT_ROOT ---
Write-Host ""
Write-Host "[4/4] Setting PAPER_TOOLKIT_ROOT environment variable..." -ForegroundColor Yellow
$oldToolkitRoot = [Environment]::GetEnvironmentVariable("PAPER_TOOLKIT_ROOT", "User")
if ($oldToolkitRoot -ne $ToolkitRoot) {
    [Environment]::SetEnvironmentVariable("PAPER_TOOLKIT_ROOT", $ToolkitRoot, "User")
    $env:PAPER_TOOLKIT_ROOT = $ToolkitRoot
    Write-Host "  [OK] PAPER_TOOLKIT_ROOT set to: $ToolkitRoot" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] PAPER_TOOLKIT_ROOT already set to: $ToolkitRoot" -ForegroundColor Gray
}

# --- Summary ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Installed (user-level, global):" -ForegroundColor White
Write-Host "  - Global command:     parse-paper (restart terminal to use)" -ForegroundColor White
Write-Host "  - Skill:              paper-mineru-reader (restart your AI agent to load)" -ForegroundColor White
Write-Host "  - Skill:              literature-deep-reading (restart your AI agent to load)" -ForegroundColor White
Write-Host "  - Environment var:    PAPER_TOOLKIT_ROOT=$ToolkitRoot" -ForegroundColor White
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart your AI agent and terminal" -ForegroundColor White
Write-Host "  2. In your agent, input: 读文献：path\to\paper.pdf" -ForegroundColor White
Write-Host "  3. Or from terminal: parse-paper 'test.pdf' -Ocr -Chunk" -ForegroundColor White
Write-Host ""
