param(
  [string]$Godot = 'godot',
  [Parameter(Mandatory = $true)][string]$BuildDirectory,
  [switch]$Graphics
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = (Resolve-Path -LiteralPath $BuildDirectory).Path
$executable = Join-Path $buildRoot 'Dark Alone.exe'
if (-not (Test-Path -LiteralPath $executable)) { throw 'BuildDirectory must contain Dark Alone.exe.' }
$validationRoot = Join-Path $projectRoot ('builds/validation-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $validationRoot | Out-Null
$validationExe = Join-Path $validationRoot 'Dark Alone Validation.exe'
$exportLog = & $Godot --headless --path $projectRoot --export-release 'Windows Validation' $validationExe 2>&1
$exportCode = $LASTEXITCODE
$exportLog | Set-Content -LiteralPath (Join-Path $validationRoot 'export.log')
if ($exportCode -ne 0 -or ($exportLog -match 'SCRIPT ERROR:|ERROR:|Parse Error:')) {
  throw "Validation export failed. See $validationRoot/export.log"
}

function Invoke-BuildCheck {
  param([string]$Executable, [string]$Log, [string[]]$ExtraArguments, [bool]$ExpectPlaythrough, [string]$ExpectedMarker = '', [bool]$Graphical = $false)
  $arguments = @('--log-file', ('"' + $Log + '"')) + $ExtraArguments
  if (-not $Graphical) { $arguments = @('--headless') + $arguments }
  $process = Start-Process -FilePath $Executable -ArgumentList $arguments -WorkingDirectory $validationRoot -WindowStyle Hidden -PassThru
  if (-not $process.WaitForExit(45000)) {
    $process.Kill()
    throw 'Exported application timed out.'
  }
  $process.Refresh()
  if (-not (Test-Path -LiteralPath $Log)) { throw 'Exported application did not create a log.' }
  $output = Get-Content -LiteralPath $Log
  if ($process.ExitCode -ne 0 -or ($output -match 'SCRIPT ERROR:|ERROR:|Parse Error:|FAIL:')) {
    $output | Write-Output
    throw "Exported application failed. See $Log"
  }
  if ($ExpectPlaythrough -and -not ($output -match 'PASS: full playthrough, [1-9][0-9]* checks, 0 failures')) {
    throw "Missing full playthrough result. See $Log"
  }
  if ($ExpectedMarker -and -not ($output -match [regex]::Escape($ExpectedMarker))) {
    throw "Missing validation result. See $Log"
  }
  $output | Write-Output
}

# Обычная сборка стартует со штатным Main; отдельная проверочная проходит весь цикл.
Invoke-BuildCheck -Executable $executable -Log (Join-Path $validationRoot 'startup.log') -ExtraArguments @('--quit-after', '5') -ExpectPlaythrough $false
Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'playthrough.log') -ExtraArguments @() -ExpectPlaythrough $true
Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'book.log') -ExtraArguments @('--', '--book-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: journal book,'
Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'display.log') -ExtraArguments @('--', '--display-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: display settings,'
Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'faces.log') -ExtraArguments @('--', '--faces-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: test faces,'
Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'checkpoint.log') -ExtraArguments @('--', '--checkpoint-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: shift checkpoint,'
Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'free-roam.log') -ExtraArguments @('--', '--free-roam-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: free roam,'
Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'bubbles.log') -ExtraArguments @('--', '--bubble-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: dialogue bubbles,'
Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'preferences.log') -ExtraArguments @('--', '--preference-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: preferences,'
Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'world-targets.log') -ExtraArguments @('--', '--world-target-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: world targeting,'
$preferenceDirectory = 'user://preference_tests/process_export_' + [guid]::NewGuid().ToString('N')
foreach ($phase in @('write', 'read')) {
  Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot ('preference-' + $phase + '.log')) -ExtraArguments @('--', '--preference-check', ('--preference-probe=' + $phase), ('--preference-directory=' + $preferenceDirectory)) -ExpectPlaythrough $false -ExpectedMarker ('PASS: preference probe ' + $phase)
}
$checkpointDirectory = 'user://checkpoint_tests/process_export_' + [guid]::NewGuid().ToString('N')
foreach ($phase in @('write', 'read')) {
  Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot ('checkpoint-' + $phase + '.log')) -ExtraArguments @('--', '--checkpoint-check', ('--checkpoint-probe=' + $phase), ('--checkpoint-directory=' + $checkpointDirectory)) -ExpectPlaythrough $false -ExpectedMarker ('PASS: checkpoint probe ' + $phase)
}
if ($Graphics) {
  Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'world-targets-graphical.log') -ExtraArguments @('--', '--world-target-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: world targeting,' -Graphical $true
  Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'preferences-graphical.log') -ExtraArguments @('--', '--preference-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: preferences,' -Graphical $true
  $graphicalPreferenceDirectory = 'user://preference_tests/process_graphics_' + [guid]::NewGuid().ToString('N')
  foreach ($phase in @('write', 'read')) {
    Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot ('preference-graphics-' + $phase + '.log')) -ExtraArguments @('--', '--preference-check', '--preference-graphics', ('--preference-probe=' + $phase), ('--preference-directory=' + $graphicalPreferenceDirectory)) -ExpectPlaythrough $false -ExpectedMarker ('PASS: preference probe ' + $phase) -Graphical $true
  }
  Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'bubbles-graphical.log') -ExtraArguments @('--', '--bubble-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: dialogue bubbles,' -Graphical $true
  Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'free-roam-graphical.log') -ExtraArguments @('--', '--free-roam-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: free roam,' -Graphical $true
  Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'checkpoint-graphical.log') -ExtraArguments @('--', '--checkpoint-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: shift checkpoint,' -Graphical $true
	Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'faces-graphical.log') -ExtraArguments @('--', '--faces-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: test faces,' -Graphical $true
  Invoke-BuildCheck -Executable $validationExe -Log (Join-Path $validationRoot 'image-detail.log') -ExtraArguments @('--', '--image-detail-check') -ExpectPlaythrough $false -ExpectedMarker 'PASS: image detail,' -Graphical $true
}
Write-Output "PASS: exported startup and full playthrough. Logs: $validationRoot"
