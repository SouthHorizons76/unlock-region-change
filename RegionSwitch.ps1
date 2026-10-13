<#
.SYNOPSIS
    Keeps the BSG Launcher's "Change region" button available while Escape from Tarkov is running.

.DESCRIPTION
    The launcher hides its whole top button row when the game state becomes "inGame"
    (Content/js/app/games/stateHandler.js). This script adds two lines to that file:
      1. In the "inGame" case, it makes the Change region button visible again.
      2. At the start of each redraw, it clears that override so other states
         (queue, updating, ...) behave exactly as before.
    Every added line ends with a marker comment, so -Undo can remove them even if
    the backup is missing. Nothing else in the launcher or the game is touched.

    Launcher updates replace Content/, which removes the patch; run this again afterwards.
    Restart the launcher after patching or undoing so it reloads the page.

.EXAMPLE
    .\RegionSwitch.ps1            # apply the patch
    .\RegionSwitch.ps1 -Undo      # remove the patch
    .\RegionSwitch.ps1 -Status    # show whether the patch is applied
#>
[CmdletBinding(DefaultParameterSetName = 'Patch')]
param(
    [Parameter(ParameterSetName = 'Undo')]   [switch]$Undo,
    [Parameter(ParameterSetName = 'Status')] [switch]$Status,
    [string]$LauncherDir = 'C:\Battlestate Games\BsgLauncher'
)

$ErrorActionPreference = 'Stop'
$Marker = '// REGION-SWITCH-PATCH'
$Target = Join-Path $LauncherDir 'Content\js\app\games\stateHandler.js'
$Backup = "$Target.region-switch.bak"

function Read-Target {
    $bytes = [IO.File]::ReadAllBytes($Target)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $text = (New-Object Text.UTF8Encoding($false)).GetString($bytes)
    if ($hasBom) { $text = $text.Substring(1) }
    $eol = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    [pscustomobject]@{ Text = $text; Eol = $eol; HasBom = $hasBom }
}

function Write-Target($file, [string[]]$lines) {
    $enc = New-Object Text.UTF8Encoding($file.HasBom)
    [IO.File]::WriteAllText($Target, ($lines -join $file.Eol), $enc)
}

function Test-Patched($file) { $file.Text.Contains($Marker) }

function Warn-IfLauncherRunning {
    if (Get-Process -Name 'BsgLauncher' -ErrorAction SilentlyContinue) {
        Write-Host 'The launcher is running. Restart it (fully exit from the tray icon) so the change takes effect.' -ForegroundColor Yellow
    }
}

if (-not (Test-Path -LiteralPath $Target)) {
    throw "Launcher file not found: $Target`nUse -LauncherDir to point at your BsgLauncher folder."
}

$file = Read-Target

if ($Status) {
    if (Test-Patched $file) { Write-Host 'Patched: Change region stays available while the game is running.' -ForegroundColor Green }
    else { Write-Host 'Not patched (stock launcher behaviour).' }
    exit 0
}

if ($Undo) {
    if (-not (Test-Patched $file)) {
        Write-Host 'Nothing to undo: the patch is not applied.'
        exit 0
    }
    $lines = $file.Text -split "`r?`n"
    $kept = @($lines | Where-Object { -not $_.Contains($Marker) })
    Write-Target $file $kept
    if (Test-Path -LiteralPath $Backup) { Remove-Item -LiteralPath $Backup }
    Write-Host "Patch removed ($($lines.Count - $kept.Count) lines)." -ForegroundColor Green
    Warn-IfLauncherRunning
    exit 0
}

# --- Patch ---
if (Test-Patched $file) {
    Write-Host 'Already patched. Nothing to do.' -ForegroundColor Green
    exit 0
}

$lines = [Collections.Generic.List[string]]($file.Text -split "`r?`n")

# Anchors live inside drawMainScreenGameState(); stop scanning at the next top-level function.
$start = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^function drawMainScreenGameState\(') { $start = $i; break }
}
if ($start -lt 0) { throw 'Could not find drawMainScreenGameState() - the launcher has changed. No changes made.' }
$end = $lines.Count
for ($i = $start + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^(async\s+)?function\s') { $end = $i; break }
}

$resetLine = -1; $inGameCase = -1; $hideLine = -1
for ($i = $start; $i -lt $end; $i++) {
    if ($resetLine -lt 0 -and $lines[$i] -match '^\s*resetGameBlock\(\)\s*;?\s*$') { $resetLine = $i }
    if ($inGameCase -lt 0 -and $lines[$i] -match '^\s*case\s+"inGame"\s*:') { $inGameCase = $i; continue }
    if ($inGameCase -ge 0 -and $hideLine -lt 0) {
        if ($lines[$i] -match '^\s*break\b') { break }
        if ($lines[$i] -match "\.top_buttons'\)\.css\(\{\s*visibility:\s*`"hidden`"\s*\}\)") { $hideLine = $i }
    }
}
if ($resetLine -lt 0 -or $inGameCase -lt 0 -or $hideLine -lt 0) {
    throw 'Could not find the expected code in stateHandler.js - the launcher has changed. No changes made.'
}

$indentOf = { param($s) [regex]::Match($s, '^\s*').Value }
$showLine  = (& $indentOf $lines[$hideLine])  + "game_main.find('.top_buttons .config-matching').css({visibility: `"visible`"}) $Marker"
$clearLine = (& $indentOf $lines[$resetLine]) + "game_main.find('.top_buttons .config-matching').css({visibility: `"`"}) $Marker"

Copy-Item -LiteralPath $Target -Destination $Backup -Force

# Insert the later line first so the earlier index stays valid.
$lines.Insert($hideLine + 1, $showLine)
$lines.Insert($resetLine + 1, $clearLine)
Write-Target $file $lines.ToArray()

Write-Host 'Patched: Change region stays available while the game is running.' -ForegroundColor Green
Write-Host "Backup of the original: $Backup"
Write-Host 'Undo any time with RegionSwitch-Undo.cmd (or .\RegionSwitch.ps1 -Undo).'
Warn-IfLauncherRunning
