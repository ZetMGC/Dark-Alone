param(
  [string]$Godot = 'godot',
  [switch]$Graphics
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$expectedVersion = (Get-Content -LiteralPath (Join-Path $projectRoot '.godot-version') -Raw).Trim()
$actualVersion = & $Godot --version
if ($LASTEXITCODE -ne 0 -or -not ([string]$actualVersion).StartsWith("$expectedVersion.stable")) {
  throw "Expected Godot $expectedVersion stable, received $actualVersion"
}
$resultRoot = Join-Path $projectRoot ('artifacts/drink-core-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $resultRoot | Out-Null
foreach ($phase in @('import', 'headless', 'lab')) {
  $engineArguments = @('--headless', '--path', $projectRoot)
  if ($phase -eq 'import') { $engineArguments += @('--editor', '--import') }
  elseif ($phase -eq 'headless') { $engineArguments += '--script', 'res://tests/parallel/bar/drink_core_test.gd' }
  else { $engineArguments += '--script', 'res://tests/parallel/bar/drink_lab_test.gd' }
  $output = & $Godot @engineArguments 2>&1
  $resultCode = $LASTEXITCODE
  $output | Set-Content -LiteralPath (Join-Path $resultRoot ($phase + '.log'))
  if ($resultCode -ne 0 -or ($output -match 'SCRIPT ERROR:|ERROR:|Parse Error:') -or ($phase -eq 'headless' -and -not ($output -match 'PASS: drink core')) -or ($phase -eq 'lab' -and -not ($output -match 'PASS: drink lab'))) {
    throw "Drink core $phase failed. Logs: $resultRoot"
  }
  Write-Output "PASS: Drink core $phase"
}
if ($Graphics) {
  foreach ($size in @('normal', 'small')) {
    $log = Join-Path $resultRoot ($size + '.log')
    $capture = Join-Path $resultRoot $size
    $engineArguments = @('--path', ('"' + $projectRoot + '"'), '--script', 'res://tests/parallel/bar/drink_lab_test.gd', '--log-file', ('"' + $log + '"'), '--', ('--capture-dir="' + $capture + '"'))
    if ($size -eq 'small') { $engineArguments += '--small' }
    $process = Start-Process -FilePath $Godot -ArgumentList $engineArguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(45000)) {
      $process.Kill()
      throw "Drink core $size timed out. Logs: $resultRoot"
    }
    $output = Get-Content -LiteralPath $log
    if ($process.ExitCode -ne 0 -or ($output -match 'SCRIPT ERROR:|ERROR:|Parse Error:') -or -not ($output -match 'PASS: drink lab')) {
      throw "Drink core $size failed. Logs: $resultRoot"
    }
    Write-Output "PASS: Drink core graphics $size"
  }
}
Write-Output "PASS: drink core checks. Logs: $resultRoot"
