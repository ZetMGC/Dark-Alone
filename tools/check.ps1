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
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/camera_horizon_test.gd')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--script', 'res://tools/validate_content.gd')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/dialogue_content_test.gd')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/dialogue_runtime_test.gd')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/guest_service_test.gd')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/shift_clock_test.gd')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/presentation_test.gd')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/environment_camera_test.gd')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/commute_test.gd')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/home_test.gd')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/journal_core_test.gd')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, 'res://tests/book_test.tscn')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, 'res://tests/display_test.tscn')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, 'res://tests/faces_test.tscn')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, 'res://tests/checkpoint_test.tscn')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, 'res://tests/free_roam_test.tscn')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, 'res://tests/dialogue_bubble_test.tscn')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, 'res://tests/preference_test.tscn')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, 'res://tests/world_target_test.tscn')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, 'res://tests/home_target_test.tscn')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, 'res://tests/parallel/home/house_layout_test.tscn')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, 'res://tests/journal_ink_test.tscn')
$preferenceDirectory = 'user://preference_tests/process_' + [guid]::NewGuid().ToString('N')
foreach ($phase in @('write', 'read')) {
  Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, 'res://tests/preference_test.tscn', '--', ('--preference-probe=' + $phase), ('--preference-directory=' + $preferenceDirectory))
}
$checkpointDirectory = 'user://checkpoint_tests/process_' + [guid]::NewGuid().ToString('N')
foreach ($phase in @('write', 'read')) {
  Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, 'res://tests/checkpoint_test.tscn', '--', ('--checkpoint-probe=' + $phase), ('--checkpoint-directory=' + $checkpointDirectory))
}
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, 'res://tests/playthrough_entry.tscn')
Invoke-GodotCheck -EngineArguments @('--headless', '--path', $projectRoot, '--quit-after', '5')
Write-Output 'PASS: import, smoke, navigation, content, dialogue, service, shift, playthrough, and startup.'
