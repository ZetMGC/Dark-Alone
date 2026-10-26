param(
  [string]$Godot = 'godot',
  [Parameter(Mandatory = $true)][string]$BuildDirectory
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
  param([string]$Executable, [string]$Log, [string[]]$ExtraArguments, [bool]$ExpectPlaythrough, [string]$ExpectedMarker = '')
  $arguments = @('--headless', '--log-file', ('"' + $Log + '"')) + $ExtraArguments
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
Write-Output "PASS: exported startup and full playthrough. Logs: $validationRoot"
