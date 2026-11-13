<#
.SYNOPSIS
    Stops update services, purges corrupted SoftwareDistribution caches, and forces an update rebuild.

.DESCRIPTION
    Resolves recurring Windows Update error codes (0x80240034, 0x80070002, 0x80240020) by stopping
    wuauserv, bits, and cryptsvc, renaming the SoftwareDistribution directory to force an OS rebuild,
    restarting background services, and initiating a fresh scan via UsoClient.

.EXAMPLE
    .\Reset-WindowsUpdateDatabase.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to reset the Windows Update database."
    exit 1
}

Write-Host "Initiating deep clean of Windows Update database and services..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("Windows Update Services", "Stop services, archive SoftwareDistribution, and restart")) {
    try {
        Write-Host "Stage 1: Stopping Windows Update, BITS, and Cryptographic services..." -ForegroundColor Yellow
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
        Stop-Service -Name cryptsvc -Force -ErrorAction SilentlyContinue

        $softwareDist = "$env:SystemRoot\SoftwareDistribution"
        $backupName = "$env:SystemRoot\SoftwareDistribution.old"

        Write-Host "Stage 2: Archiving SoftwareDistribution directory to force OS database rebuild..." -ForegroundColor Yellow
        if (Test-Path $backupName) {
            Remove-Item -Path $backupName -Recurse -Force -ErrorAction SilentlyContinue
        }

        if (Test-Path $softwareDist) {
            Rename-Item -Path $softwareDist -NewName "SoftwareDistribution.old" -Force -ErrorAction Stop
            Write-Host "SoftwareDistribution successfully renamed to SoftwareDistribution.old" -ForegroundColor Green
        }

        Write-Host "Stage 3: Restarting update pipeline services..." -ForegroundColor Cyan
        Start-Service -Name cryptsvc -ErrorAction SilentlyContinue
        Start-Service -Name bits -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue

        Write-Host "Stage 4: Triggering background Windows Update scan via UsoClient..." -ForegroundColor Cyan
        & UsoClient.exe StartScan | Out-Null

        Write-Host "[SUCCESS] Windows Update database clean complete. Background scan initiated." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error "Failed to reset Windows Update database: $_"
        exit 1
    }
}
