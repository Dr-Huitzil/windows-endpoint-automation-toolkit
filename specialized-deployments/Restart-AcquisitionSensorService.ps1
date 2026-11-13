<#
.SYNOPSIS
    Recycles digital radiography sensor tray services to recover stuck USB/COM intraoral sensor acquisitions.

.DESCRIPTION
    Triage script for digital dental operatories where intraoral sensors become unresponsive or freeze
    during acquisition. Calls gxstop.exe to terminate the tray engine, pauses to release serial/USB port
    memory buffers, and relaunches gxstart.exe to restore acquisition without requiring a system reboot.

.PARAMETER VendorToolsDirectory
    Directory containing vendor acquisition control executables. Defaults to 'C:\Program Files (x86)\Gendex\VixCfg'.

.EXAMPLE
    .\Restart-AcquisitionSensorService.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Vendor tools directory path")]
    [string]$VendorToolsDirectory = $(if ($env:sensorToolsDir) { $env:sensorToolsDir } else { "C:\Program Files (x86)\Gendex\VixCfg" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to recycle hardware acquisition services."
    exit 1
}

$stopTool = Join-Path $VendorToolsDirectory "gxstop.exe"
$startTool = Join-Path $VendorToolsDirectory "gxstart.exe"

if (-not (Test-Path $stopTool) -or -not (Test-Path $startTool)) {
    Write-Warning "Acquisition tools not found in '$VendorToolsDirectory'. This machine may not have intraoral sensor software installed."
    exit 0
}

Write-Host "Initiating acquisition sensor recovery cycle..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("Acquisition Sensors", "Stop and restart radiography tray services")) {
    try {
        Write-Host "Stage 1: Terminating unresponsive sensor background process via gxstop.exe..." -ForegroundColor Yellow
        Start-Process -FilePath $stopTool -Wait

        Write-Host "Stage 2: Pausing 4 seconds to allow Windows kernel to release USB/COM serial handles..." -ForegroundColor DarkGray
        Start-Sleep -Seconds 4

        Write-Host "Stage 3: Relaunching tray acquisition application via gxstart.exe..." -ForegroundColor Cyan
        Start-Process -FilePath $startTool
        Start-Sleep -Seconds 3

        # Secondary launch confirmation
        Start-Process -FilePath $startTool

        Write-Host "[SUCCESS] Digital radiography acquisition service recycled successfully." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error "Failed to recycle sensor service: $_"
        exit 1
    }
}
