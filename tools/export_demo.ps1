# Export the demo build and verify the EXPORTED binary (not the project).
# ASCII-ONLY: Windows PowerShell 5.1 reads BOM-less UTF-8 scripts as ANSI and mangles non-ASCII.
#
#   .\export_demo.ps1                    # kill stale processes, export, --demo, --shot
#   .\export_demo.ps1 -NoShot            # skip the windowed screenshot pass
#
# Traps baked in (both hit for real):
#   1. A leftover FatFishRice.exe process locks the output file and the export dies at the very end
#      with "PCK embed: failed to rename FatFishRice.tmp" (exit code 1) while the OLD exe stays on
#      disk -- so a later --demo run silently tests the previous build. Always kill first.
#   2. Godot needs a writable APPDATA or it cannot create user:// and the process dies with signal 11.

param(
    [string]$GodotExe = 'C:\Users\win11\scoop\apps\godot1\4.7\godot.exe',
    [string]$Project = '',
    [string]$OutDir = '',
    [switch]$NoShot
)

$ErrorActionPreference = 'Continue'

if (-not $Project) { $Project = Split-Path -Parent $PSScriptRoot }
if (-not $OutDir) { $OutDir = Join-Path (Split-Path -Parent $Project) 'demo' }
$workspaceRoot = Split-Path -Parent $Project
$tmpDir = Join-Path $workspaceRoot 'tmp'
$env:APPDATA = Join-Path $tmpDir 'godot_userdata'
$logDir = Join-Path $tmpDir 'export_logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$exePath = Join-Path $OutDir 'FatFishRice.exe'
$shotDir = Join-Path $tmpDir 'demo_shots'

Write-Output "== 0. kill stale game processes (they lock the output file) =="
$stale = Get-Process -Name 'FatFishRice' -ErrorAction SilentlyContinue
if ($stale) {
    $stale | ForEach-Object { Write-Output ("   kill pid " + $_.Id); Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 800
} else {
    Write-Output "   none"
}

Write-Output "== 1. export =="
$log = Join-Path $logDir 'export.log'
& cmd.exe /c "`"$GodotExe`" --headless --path `"$Project`" --export-release `"Windows Desktop`" `"$($exePath.Replace('\','/'))`" > `"$log`" 2>&1" | Out-Null
$rc = $LASTEXITCODE
$errs = Get-Content $log -Encoding UTF8 -ErrorAction SilentlyContinue |
    Where-Object { $_ -match 'ERROR' -and $_ -notmatch 'certificate|editor_doc_cache' } |
    Select-Object -First 5
Write-Output ("   rc=" + $rc)
if ($errs) { $errs | ForEach-Object { Write-Output ("   " + $_.Trim()) } }
if ($rc -ne 0) { Write-Output "FAIL: export exited $rc"; exit 1 }
if (-not (Test-Path $exePath)) { Write-Output "FAIL: $exePath missing"; exit 1 }
$info = Get-Item $exePath
Write-Output ("   built: " + $info.Name + "  " + [math]::Round($info.Length / 1MB, 2) + " MB  " + $info.LastWriteTime)

Write-Output "== 2. exported build: headless gameplay chain =="
$demoLog = Join-Path $logDir 'demo.log'
& cmd.exe /c "`"$exePath`" --headless -- --demo > `"$demoLog`" 2>&1" | Out-Null
Write-Output ("   rc=" + $LASTEXITCODE)
Get-Content $demoLog -Encoding UTF8 -ErrorAction SilentlyContinue |
    Where-Object { $_ -match '\[rice\]' } | ForEach-Object { Write-Output ("   " + $_.Trim()) }
if ($LASTEXITCODE -ne 0) { Write-Output "FAIL: exported --demo exited $LASTEXITCODE"; exit 1 }

if (-not $NoShot) {
    Write-Output "== 3. exported build: screenshots =="
    if (Test-Path $shotDir) { Remove-Item (Join-Path $shotDir '*.png') -Force -ErrorAction SilentlyContinue }
    $shotLog = Join-Path $logDir 'shot.log'
    & cmd.exe /c "`"$exePath`" -- --shot `"$($shotDir.Replace('\','/'))`" > `"$shotLog`" 2>&1" | Out-Null
    Write-Output ("   rc=" + $LASTEXITCODE)
    Get-Content $shotLog -Encoding UTF8 -ErrorAction SilentlyContinue |
        Where-Object { $_ -match '\[shot\]' } | ForEach-Object { Write-Output ("   " + $_.Trim()) }
    # the shot run may leave the process alive for a moment; make sure the next export is not blocked
    Get-Process -Name 'FatFishRice' -ErrorAction SilentlyContinue |
        ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
    Get-ChildItem $shotDir -Filter *.png -ErrorAction SilentlyContinue |
        ForEach-Object { Write-Output ("   png: " + $_.Name + "  " + [math]::Round($_.Length / 1KB) + " KB") }
}

Write-Output "DONE"
