param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string[]]$InputPath,

  [string]$Output = "parsed",

  [ValidateSet("cloud", "local", "auto")]
  [string]$Engine = "cloud",

  [ValidateSet("auto", "agent", "standard")]
  [string]$Api = "auto",

  [ValidateSet("pipeline", "vlm", "MinerU-HTML")]
  [string]$Model = "vlm",

  [string]$Lang = "ch",
  [int]$Workers = 4,
  [int]$Timeout = 900,

  [switch]$Ocr,
  [switch]$Chunk,
  [switch]$Stdout,
  [switch]$Json,
  [switch]$Split,
  [switch]$NoFormula,
  [switch]$NoTable
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$MinerUScript = Join-Path $Root "MinerU-Skill\scripts\mineru.py"

if (-not (Test-Path -LiteralPath $MinerUScript)) {
  throw "MinerU Skill script not found: $MinerUScript"
}

$BundledPython = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"

# Locate the newest user-installed Python 3 under LOCALAPPDATA (if any)
$LocalPython = $null
if ($env:LOCALAPPDATA) {
  $PyDir = Join-Path $env:LOCALAPPDATA "Programs\Python"
  if (Test-Path $PyDir) {
    $LocalPython = (Get-ChildItem (Join-Path $PyDir "Python3*\python.exe") -ErrorAction SilentlyContinue |
      Sort-Object { [int]($_.Directory.Name -replace 'Python3','') } -Descending |
      Select-Object -First 1).FullName
  }
}

# Windows py launcher (pre-installed with modern Python on Windows)
$PyLauncher = $null
try { $PyLauncher = (& py -3 -c "import sys; print(sys.executable)" 2>$null) } catch { }

$PythonCandidates = @(
  $env:PAPER_TOOLKIT_PYTHON,
  $LocalPython,
  $PyLauncher,
  $env:CODEX_PYTHON,
  $BundledPython,
  "python"
) | Where-Object { $_ -and $_.Trim().Length -gt 0 }

$Python = $null
foreach ($Candidate in $PythonCandidates) {
  if ($Candidate -eq "python") {
    $Python = $Candidate
    break
  }
  if (Test-Path -LiteralPath $Candidate) {
    $Python = $Candidate
    break
  }
}

if (-not $Python) {
  throw "No Python executable found. Set PAPER_TOOLKIT_PYTHON or install Python 3.8+."
}

$Args = @()
$Args += $InputPath
$Args += @("--output", $Output)
$Args += @("--engine", $Engine)
$Args += @("--api", $Api)
$Args += @("--model", $Model)
$Args += @("--lang", $Lang)
$Args += @("--workers", [string]$Workers)
$Args += @("--timeout", [string]$Timeout)
$Args += "--resume"

if ($Ocr) { $Args += "--ocr" }
if ($Chunk) { $Args += "--chunk" }
if ($Stdout) { $Args += "--stdout" }
if ($Json) { $Args += "--json" }
if ($Split) { $Args += "--split" }
if ($NoFormula) { $Args += "--no-formula" }
if ($NoTable) { $Args += "--no-table" }

& $Python $MinerUScript @Args
