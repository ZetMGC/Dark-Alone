param([string]$Godot = 'godot', [switch]$Graphics)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
function Invoke-HomeCheck {
  param([string[]]$EngineArguments)
  $output = & $Godot @EngineArguments 2>&1
  $resultCode = $LASTEXITCODE
  $output | ForEach-Object { Write-Output $_ }
  if ($resultCode -ne 0 -or ($output -match 'SCRIPT ERROR:|ERROR:|Parse Error:|FAIL:')) {
    throw "Home target check failed (exit $resultCode)."
  }
}
Invoke-HomeCheck @('--headless', '--path', $projectRoot, '--editor', '--import')
Invoke-HomeCheck @('--headless', '--path', $projectRoot, 'res://tests/home_target_test.tscn')
Invoke-HomeCheck @('--headless', '--path', $projectRoot, '--script', 'res://tests/home_test.gd')
Invoke-HomeCheck @('--headless', '--path', $projectRoot, 'res://tests/parallel/home/house_layout_test.tscn')
if ($Graphics) {
  foreach ($size in @('normal', 'small')) {
    $engineArguments = @('--path', $projectRoot, 'res://tests/home_target_test.tscn', '--', ('--capture-dir=' + (Join-Path $projectRoot ('artifacts/da062/' + $size))))
    if ($size -eq 'small') { $engineArguments += '--small' }
    Invoke-HomeCheck $engineArguments
    $houseArguments = @('--path', $projectRoot, 'res://tests/parallel/home/house_layout_test.tscn', '--', ('--capture-dir=' + (Join-Path $projectRoot ('artifacts/house/' + $size))))
    if ($size -eq 'small') { $houseArguments += '--small' }
    Invoke-HomeCheck $houseArguments
  }
}
