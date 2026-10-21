# Verify pipeline for the "Fat Fish Rice Catch" Godot 4.7 project.
#
#   & .\tools\verify.ps1                 # import / full script compile / boot smoke / gameplay chain
#   & .\tools\verify.ps1 -Shot           # plus: open a window and capture 3 PNGs (menu / battle / game over)
#   & .\tools\verify.ps1 -GodotExe 'C:\Users\win11\scoop\apps\godot1\4.5\godot.exe'
#
# Measured facts this file is built on (all of them cost a debugging round):
#   - `--import` must run first, or cross-file class_name lookups fail and the full check lies.
#   - check_all.gd's exit code is NOT sufficient: load() returns non-null for scripts that failed to parse.
#     Authoritative verdict = scan the log for SCRIPT ERROR / Parse Error / Could not find / Failed to load script.
#   - Godot needs a writable APPDATA, otherwise user://logs creation crashes the process (signal 11).
#   - Windows PowerShell 5.1: native stdout/stderr capture through the pipeline is unreliable
#     (`*>` produced empty logs and a lost $LASTEXITCODE here). So every engine run goes through a
#     generated .bat file with `> log 2>&1`, and the real exit code comes from cmd's %ERRORLEVEL%.
#   - This script is ASCII-only on purpose: PS 5.1 reads BOM-less .ps1 as ANSI, which turns any
#     Chinese literal in here into mojibake. Chinese lives in the game code / logs, not in this file.

param(
    [string]$GodotExe = 'C:\Users\win11\scoop\apps\godot1\4.7\godot.exe',
    [string]$Project = '',
    [switch]$Shot
)

if (-not $Project) { $Project = Split-Path -Parent $PSScriptRoot }
if (-not (Test-Path $GodotExe)) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $GodotExe = $cmd.Source }
}

$workspaceRoot = Split-Path -Parent $Project
$tmpDir = Join-Path $workspaceRoot 'tmp'
$env:APPDATA = Join-Path $tmpDir 'godot_userdata'
if (-not (Test-Path $env:APPDATA)) { New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null }
$logDir = Join-Path $tmpDir 'verify_logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$shotDir = Join-Path $tmpDir 'shots'

# Known noise in a sandboxed Windows environment; never a code failure.
$noise = 'root certificate store|editor_doc_cache|certificate store|CategoryInfo|FullyQualifiedErrorId|^\s*\+|At line:|RemoteException|ObjectDB instances leaked|resources still in use'

function Find-Error([string]$text) {
    if (-not $text) { return '' }
    $hit = ($text -split "`n") |
        Where-Object { $_.Trim() -ne '' -and $_ -notmatch $noise } |
        Select-String -Pattern 'SCRIPT ERROR|Parse Error|Could not find|Failed to load script|Failed loading|Invalid call|Invalid access' |
        Select-Object -First 1
    if ($hit) { return ($hit.Line -replace '\s+', ' ').Trim() }
    return ''
}

# Run godot once via a generated .bat. Returns @(exitCode, logText).
function Run-Godot([string]$tag, [string[]]$Arguments) {
    $log = Join-Path $logDir ($tag + '.log')
    $bat = Join-Path $logDir ($tag + '.bat')
    if (Test-Path $log) { Remove-Item $log -Force }
    $quoted = @()
    foreach ($a in $Arguments) {
        if ($a -match '\s') { $quoted += ('"' + $a + '"') } else { $quoted += $a }
    }
    $lines = @(
        '@echo off',
        ('"' + $GodotExe + '" ' + ($quoted -join ' ') + ' > "' + $log + '" 2>&1')
    )
    Set-Content -Path $bat -Value $lines -Encoding ASCII
    & cmd.exe /c $bat | Out-Null
    $rc = $LASTEXITCODE
    $text = if (Test-Path $log) { Get-Content $log -Raw -Encoding UTF8 } else { '' }
    return @($rc, $text)
}

function Show-Lines([string]$text, [string]$pattern) {
    if (-not $text) { return }
    ($text -split "`n") | Where-Object { $_ -match $pattern } | ForEach-Object {
        Write-Output ("   " + $_.Trim())
    }
}

$verRun = Run-Godot 'version' @('--version')
$ver = (($verRun[1] -split "`n") | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1)
Write-Output ("engine  : " + $ver.Trim())
Write-Output ("exe     : " + $GodotExe)
Write-Output ("project : " + $Project)
Write-Output ("appdata : " + $env:APPDATA)

if ($ver -notmatch '^\s*4\.[7-9]\.') {
    Write-Output ("RESULT: FAIL - this project declares 4.7, engine is " + $ver.Trim())
    exit 1
}

$fail = @()

# 1) Refresh import + class cache
$r = Run-Godot 'import' @('--headless', '--path', $Project, '--import')
$e = Find-Error $r[1]
Write-Output ("import  : rc=" + $r[0] + $(if ($e) { "  <-- $e" } else { "" }))
if ($r[0] -ne 0 -or $e) { $fail += "import" }

# 2) Full compile of every script (verdict is the log scan, not the exit code)
$r = Run-Godot 'check' @('--headless', '--path', $Project, '--script', 'res://tools/check_all.gd')
$e = Find-Error $r[1]
$summary = (($r[1] -split "`n") | Where-Object { $_ -match '\[check_all\]' } | Select-Object -First 1)
$summaryText = if ($summary) { $summary.Trim() } else { '(no check_all summary line!)' }
Write-Output ("check   : rc=" + $r[0] + "  " + $summaryText + $(if ($e) { "  <-- $e" } else { "" }))
if ($r[0] -ne 0 -or $e -or -not $summary) { $fail += "check" }

# 3) Boot smoke
$r = Run-Godot 'smoke' @('--headless', '--path', $Project, '--quit')
$e = Find-Error $r[1]
Write-Output ("smoke   : rc=" + $r[0] + $(if ($e) { "  <-- $e" } else { "" }))
if ($r[0] -ne 0 -or $e) { $fail += "smoke" }
Show-Lines $r[1] '\[rice\]'

# 4) Gameplay chain: start a round, advance the sim, force game over (quits itself)
$r = Run-Godot 'demo' @('--headless', '--path', $Project, '--', '--demo')
$e = Find-Error $r[1]
Write-Output ("demo    : rc=" + $r[0] + $(if ($e) { "  <-- $e" } else { "" }))
if ($r[0] -ne 0 -or $e) { $fail += "demo" }
Show-Lines $r[1] '\[rice\]'

# 5) Visual self-check (optional: needs a window and a GPU)
if ($Shot) {
    if (Test-Path $shotDir) { Remove-Item (Join-Path $shotDir '*.png') -Force -ErrorAction SilentlyContinue }
    $r = Run-Godot 'shot' @('--path', $Project, '--', '--shot', $shotDir.Replace('\', '/'))
    $e = Find-Error $r[1]
    Write-Output ("shot    : rc=" + $r[0] + $(if ($e) { "  <-- $e" } else { "" }))
    if ($r[0] -ne 0 -or $e) { $fail += "shot" }
    Show-Lines $r[1] '\[shot\]|\[rice\]'
    $pngs = Get-ChildItem $shotDir -Filter *.png -ErrorAction SilentlyContinue
    if (-not $pngs) {
        Write-Output "   (no PNG produced)"
        $fail += "shot-png"
    }
    $pngs | ForEach-Object { Write-Output ("   png: " + $_.Name + "  " + $_.Length + "B") }
}

if ($fail.Count -gt 0) {
    Write-Output ("RESULT: FAIL - steps: " + ($fail -join ', '))
    exit 1
}
Write-Output "RESULT: OK"
