param(
  [string]$Godot = 'godot'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$expectedVersion = (Get-Content -LiteralPath (Join-Path $projectRoot '.godot-version') -Raw).Trim()
$actualVersion = & $Godot --version
if ($LASTEXITCODE -ne 0 -or -not ([string]$actualVersion).StartsWith("$expectedVersion.stable")) {
  throw "Expected Godot $expectedVersion stable, received $actualVersion"
}

function Invoke-Engine {
  param([string[]]$EngineArguments)
  $output = & $Godot @EngineArguments 2>&1
  $resultCode = $LASTEXITCODE
  $output | ForEach-Object { Write-Output $_ }
  if ($resultCode -ne 0 -or ($output -match 'SCRIPT ERROR:|ERROR:|Parse Error:')) {
    throw "Build failed (exit $resultCode)."
  }
}

# Каждый запуск пишет в новую папку и не удаляет предыдущие сборки.
$buildId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$outputRoot = Join-Path $projectRoot ('builds/windows-' + $buildId)
New-Item -ItemType Directory -Path $outputRoot | Out-Null
Set-Content -LiteralPath (Join-Path $projectRoot 'builds/.gdignore') -Value ''
Invoke-Engine -EngineArguments @('--headless', '--path', $projectRoot, '--editor', '--import')
$executable = Join-Path $outputRoot 'Dark Alone.exe'
Invoke-Engine -EngineArguments @('--headless', '--path', $projectRoot, '--export-release', 'Windows Desktop', $executable)
if (-not (Test-Path -LiteralPath $executable) -or -not (Test-Path -LiteralPath (Join-Path $outputRoot 'Dark Alone.pck'))) {
  throw 'Missing exported executable or PCK.'
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/PLAYTEST.md') -Destination (Join-Path $outputRoot 'START-HERE.md')
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/legal') -Destination $outputRoot -Recurse
$revision = & git -C $projectRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot determine source revision.' }
$sourceDirty = [bool](& git -C $projectRoot status --porcelain)
$files = Get-ChildItem -LiteralPath $outputRoot -File -Recurse | ForEach-Object {
  [ordered]@{ path = $_.FullName.Substring($outputRoot.Length + 1).Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
}
[ordered]@{
  source_revision = [string]$revision
  source_dirty = $sourceDirty
  godot = [string]$actualVersion
  platform = 'Windows x86_64'
  preset = 'Windows Desktop'
  built_at_utc = [DateTime]::UtcNow.ToString('o')
  files = @($files)
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outputRoot 'build-manifest.json') -Encoding utf8
$archive = $outputRoot + '.zip'
Compress-Archive -LiteralPath $outputRoot -DestinationPath $archive
Write-Output "PASS: Windows build: $outputRoot"
Write-Output "Archive: $archive"
