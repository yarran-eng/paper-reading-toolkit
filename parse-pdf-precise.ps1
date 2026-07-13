param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string[]]$InputPath,

  [string]$Output = "parsed",
  [string]$Lang = "ch",
  [int]$Workers = 4,
  [int]$Timeout = 900,

  [switch]$Ocr,
  [switch]$Chunk,
  [switch]$Stdout,
  [switch]$Json,
  [switch]$Split
)

$ErrorActionPreference = "Stop"

$ScriptPath = Join-Path $PSScriptRoot "parse-pdf.ps1"

# Use hashtable splatting (@Params) instead of array splatting (@Args).
# Array splatting fails when the target script declares [string[]]$InputPath
# because PowerShell mis-binds named parameters (like -Output) as positional
# arguments. Hashtable splatting maps keys to parameter names explicitly,
# eliminating the binding ambiguity.
$Params = @{
    InputPath = $InputPath
    Output    = $Output
    Api       = "standard"
    Model     = "vlm"
    Lang      = $Lang
    Workers   = $Workers
    Timeout   = $Timeout
}

if ($Ocr)    { $Params['Ocr']    = $true }
if ($Chunk)  { $Params['Chunk']  = $true }
if ($Stdout) { $Params['Stdout'] = $true }
if ($Json)   { $Params['Json']   = $true }
if ($Split)  { $Params['Split']  = $true }

& $ScriptPath @Params
