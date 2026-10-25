param(
  [string]$Godot = 'godot'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$expectedVersion = (Get-Content -LiteralPath (Join-Path $projectRoot '.godot-version') -Raw).Trim()
$actualVersion = & $Godot --version
if ($LASTEXITCODE -ne 0) { throw 'Cannot determine Godot version.' }
if (-not ([string]$actualVersion).StartsWith("$expectedVersion.stable")) {
  throw "Expected Godot $expectedVersion stable, received $actualVersion"
}

# Godot may return 0 for some script/resource errors. Inspect logs as well.
function Invoke-GodotCheck {
  param([string[]]$EngineArguments)
  $output = & $Godot @EngineArguments 2>&1
  $resultCode = $LASTEXITCODE
  $output | ForEach-Object { Write-Output $_ }
  if ($resultCode -ne 0 -or ($output -match 'SCRIPT ERROR:|ERROR:|Parse Error:')) {
    throw "Godot check failed (exit $resultCode)."
  }
}

Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--editor', '--import')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/smoke_test.gd')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/navigation_test.gd')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--quit-after', '5')
Write-Output 'PASS: import, main scene smoke test, M1 navigation, and startup.'
