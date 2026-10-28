param(
  [Parameter(Mandatory = $true)][ValidatePattern('^v\d+\.\d+\.\d+-(alpha|beta|rc)\.\d+$')][string]$Tag,
  [string]$Godot = 'godot'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (& git -C $projectRoot status --porcelain) { throw 'Commit or preserve local changes before preparing a release.' }
& git -C $projectRoot fetch origin
if ($LASTEXITCODE -ne 0) { throw 'Cannot refresh origin/main.' }
$revision = & git -C $projectRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve HEAD.' }
$mainRevision = & git -C $projectRoot rev-parse origin/main
if ($LASTEXITCODE -ne 0 -or $revision -ne $mainRevision) { throw 'Merge the tested changes first, then check out the exact origin/main revision.' }
$releaseRoot = Join-Path $projectRoot ('builds/releases/' + $Tag)
if (Test-Path -LiteralPath $releaseRoot) { throw 'This release directory already exists; use a new version or inspect it manually.' }
& (Join-Path $PSScriptRoot 'check.ps1') -Godot $Godot
# Исключения внутри проверок останавливают скрипт; LASTEXITCODE также проверяется для внешнего движка.
if ($LASTEXITCODE -ne 0) { throw 'Source checks failed.' }
$buildOutput = & (Join-Path $PSScriptRoot 'build_windows.ps1') -Godot $Godot
$buildOutput | Write-Output
$buildLine = $buildOutput | Where-Object { $_ -like 'PASS: Windows build: *' } | Select-Object -Last 1
if (-not $buildLine) { throw 'Cannot locate the created build.' }
$buildRoot = ([string]$buildLine).Substring('PASS: Windows build: '.Length)
& (Join-Path $PSScriptRoot 'check_windows_export.ps1') -Godot $Godot -BuildDirectory $buildRoot
$manifest = Get-Content -LiteralPath (Join-Path $buildRoot 'build-manifest.json') -Raw | ConvertFrom-Json
if ($manifest.source_dirty -or $manifest.source_revision -ne $revision) { throw 'The build must match the clean release revision.' }
New-Item -ItemType Directory -Path $releaseRoot -Force | Out-Null
$assetName = 'Dark-Alone-' + $Tag + '-windows-x86_64.zip'
$asset = Join-Path $releaseRoot $assetName
Copy-Item -LiteralPath ($buildRoot + '.zip') -Destination $asset
Copy-Item -LiteralPath (Join-Path $buildRoot 'build-manifest.json') -Destination $releaseRoot
$checksum = (Get-FileHash -LiteralPath $asset -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath (Join-Path $releaseRoot 'SHA256SUMS.txt') -Value ($checksum + '  ' + $assetName) -Encoding utf8
$notes = Get-Content -LiteralPath (Join-Path $projectRoot 'docs/releases/NEXT.md') -Raw -Encoding utf8
$notes = $notes.Replace('{{TAG}}', $Tag).Replace('{{REVISION}}', [string]$revision)
Set-Content -LiteralPath (Join-Path $releaseRoot 'release-notes.md') -Value $notes -Encoding utf8
Write-Output "PASS: release files prepared: $releaseRoot"
Write-Output "Create a GitHub pre-release with tag $Tag targeting $revision; attach ZIP, SHA256SUMS.txt and build-manifest.json."
