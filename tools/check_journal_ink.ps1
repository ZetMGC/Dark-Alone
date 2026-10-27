param([string]$Godot = 'godot', [switch]$Graphics)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
function Invoke-InkCheck {
  param([string[]]$EngineArguments)
  $output = & $Godot @EngineArguments 2>&1
  $resultCode = $LASTEXITCODE
  $output | ForEach-Object { Write-Output $_ }
  if ($resultCode -ne 0 -or ($output -match 'SCRIPT ERROR:|ERROR:|Parse Error:|FAIL:')) {
    throw "Journal ink check failed (exit $resultCode)."
  }
}
Invoke-InkCheck @('--headless', '--path', $projectRoot, '--editor', '--import')
Invoke-InkCheck @('--headless', '--path', $projectRoot, 'res://tests/journal_ink_test.tscn')
Invoke-InkCheck @('--headless', '--path', $projectRoot, 'res://tests/book_test.tscn')
Invoke-InkCheck @('--headless', '--path', $projectRoot, 'res://tests/checkpoint_test.tscn')
if ($Graphics) {
  foreach ($size in @('normal', 'small')) {
    $engineArguments = @('--path', $projectRoot, 'res://tests/journal_ink_test.tscn', '--', ('--capture-dir=' + (Join-Path $projectRoot ('artifacts/journal-ink/' + $size))))
    if ($size -eq 'small') { $engineArguments += '--small' }
    Invoke-InkCheck $engineArguments
  }
}
