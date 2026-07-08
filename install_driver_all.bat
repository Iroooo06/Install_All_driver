@echo off
setlocal DisableDelayedExpansion

:: Check for administrative privileges
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This script must be run as an Administrator!
    echo Right-click this .bat file and select 'Run as Administrator'.
    echo.
    pause
    exit /b 1
)

:: Safely change to the script's directory
cd /d "%~dp0"

:: Tell PowerShell to SKIP the first 25 lines of this file to completely avoid parser errors
powershell -NoProfile -ExecutionPolicy Bypass -Command "$code = (Get-Content -LiteralPath '%~f0' | Select-Object -Skip 25) -join [Environment]::NewLine; Invoke-Expression $code"

if %errorlevel% neq 0 (
    echo.
    echo [CRITICAL] The script engine completed with an error code: %errorlevel%
    pause
)
exit /b %errorlevel%

# ----------------------------------------------------------------------------
# POWERSHELL ENGINE STARTS HERE (LINE 26+)
# ----------------------------------------------------------------------------

[CmdletBinding()]
param(
    [string]$SourcePath = $PSScriptRoot,
    [string]$LogPath = "C:\Logs\DriverInstall",
    [switch]$NoRecurse,
    [int]$TimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"

# Fallback path if run from an unmapped directory
if ([string]::IsNullOrWhiteSpace($SourcePath)) { $SourcePath = Get-Location }
if (-not (Test-Path $LogPath)) { New-Item -Path $LogPath -ItemType Directory -Force | Out-Null }

$timestamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$scriptLog   = Join-Path $LogPath "DriverInstall_$timestamp.log"
$msiLogFolder = Join-Path $LogPath "msi_logs_$timestamp"
New-Item -Path $msiLogFolder -ItemType Directory -Force | Out-Null

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $scriptLog -Value $line
    switch ($Level) {
        "ERROR" { Write-Host $line -ForegroundColor Red }
        "WARN"  { Write-Host $line -ForegroundColor Yellow }
        "OK"    { Write-Host $line -ForegroundColor Green }
        default { Write-Host $line }
    }
}

Write-Log "=== Driver install run started ==="
Write-Log "Scanning Folder Path: $SourcePath"

# Discover Installers
$gciParams = @{
    Path    = $SourcePath
    Include = @("*.exe", "*.msi")
    File    = $true
}
if (-not $NoRecurse) { $gciParams["Recurse"] = $true }
$installers = Get-ChildItem @gciParams | Where-Object { $_.Name -notlike "*.bat*" } | Sort-Object FullName

if (-not $installers -or $installers.Count -eq 0) {
    Write-Log "No installation packages (.exe or .msi) found in '$SourcePath'." "WARN"
    Write-Host "`nNo installers found. Window locked open. Close manually when done." -ForegroundColor Yellow
    while ($true) { Start-Sleep -Seconds 3600 }
}

Write-Log "Found $($installers.Count) target deployment package(s)."

$results = New-Object System.Collections.Generic.List[Object]
$rebootRequired = $false
$commonExeSwitches = @("/s", "-s", "/S /norestart", "/s /norestart", "/silent /norestart", "/verysilent /norestart /suppressmsgboxes", "/quiet /norestart")

# Live Progress Runner
function Invoke-LiveInstaller {
    param(
        [string]$Binary,
        [string]$Arguments
    )
    try {
        $FullCommand = "`"$Binary`" $Arguments"
        Write-Host "Running live stream execution..." -ForegroundColor Cyan
        cmd.exe /c $FullCommand
        return $LASTEXITCODE
    }
    catch {
        Write-Log "Exception launching wrapper: $($_.Exception.Message)" "ERROR"
        return -999
    }
}

function Test-SuccessCode {
    param([int]$Code)
    return ($Code -eq 0 -or $Code -eq 3010)
}

# Main Loop
foreach ($installer in $installers) {
    $name    = $installer.Name
    $fullPath  = $installer.FullName
    $ext       = $installer.Extension.ToLowerInvariant()
    $status    = "Unknown"
    $exitCode  = $null
    $usedArgs  = $null

    Write-Host "`n=================================================================" -ForegroundColor Gray
    Write-Log "PROCESSING: $name" "INFO"
    Write-Host "=================================================================" -ForegroundColor Gray

    if ($ext -eq ".msi") {
        $msiLog   = Join-Path $msiLogFolder ("{0}.log" -f $installer.BaseName)
        $usedArgs = "/i `"$fullPath`" /passive /norestart /log `"$msiLog`""
        $exitCode = Invoke-LiveInstaller -Binary "msiexec.exe" -Arguments $usedArgs
    }
    elseif ($ext -eq ".exe") {
        $exitCode = $null
        foreach ($switchSet in $commonExeSwitches) {
            Write-Log "Testing parameters: $switchSet"
            $attemptCode = Invoke-LiveInstaller -Binary $fullPath -Arguments $switchSet
            
            if (Test-SuccessCode -Code $attemptCode) {
                $usedArgs = $switchSet
                $exitCode = $attemptCode
                break
            } else {
                Write-Log "Switch pattern failed with code $attemptCode." "WARN"
            }
        }
        if ($null -eq $exitCode) {
            $exitCode = $attemptCode
            $usedArgs = "ALL_PROBES_FAILED"
        }
    }

    if (Test-SuccessCode -Code $exitCode) {
        $status = "Success"
        if ($exitCode -eq 3010) { $rebootRequired = $true; $status = "Success (Reboot Required)" }
        Write-Log "'$name' finished successfully. Code: $exitCode" "OK"
    } else {
        $status = "Failed"
        Write-Log "'$name' execution failed. Code: $exitCode" "ERROR"
    }

    $results.Add([PSCustomObject]@{
        FileName  = $name
        Type      = $ext.TrimStart(".")
        ExitCode  = $exitCode
        Status    = $status
    })
}

Write-Host "`n"
Write-Log "=== Processing Summary ===" "INFO"
$results | Format-Table -AutoSize | Out-String | Write-Host

if ($rebootRequired) {
    Write-Log "A system reboot sequence is required to finalize your changes." "WARN"
}

# Changes applied strictly here: Window is held open infinitely and ignores keyboard keypresses
Write-Host "`nExecution completed. Kindly check and run-update drivers if it already up to Date. thank you !n." -ForegroundColor Green
while ($true) { Start-Sleep -Seconds 3600 }