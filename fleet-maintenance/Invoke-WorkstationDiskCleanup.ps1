<#
.SYNOPSIS
    Automates multi-tier workstation storage reclamation and silent cleanmgr execution.

.DESCRIPTION
    Measures initial available drive capacity, flushes the system Recycle Bin for all users,
    purges Windows Temp and all user profile AppData Temp folders, configures cleanmgr VolumeCaches
    registry flags (StateFlags7777), and triggers cleanmgr.exe /sagerun:7777 silently.
    Calculates and logs total gigabytes recovered to resolve Auvik 80%+ storage threshold alerts.

.EXAMPLE
    .\Invoke-WorkstationDiskCleanup.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to run automated workstation disk cleanup."
    exit 1
}

try {
    # Step 1: Measure initial free storage
    $drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $beforeFreeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
    Write-Host "Free disk space before maintenance: $beforeFreeGB GB" -ForegroundColor Cyan

    if ($PSCmdlet.ShouldProcess("Drive C:", "Purge Recycle Bin, Temp Caches, and execute cleanmgr /sagerun:7777")) {
        Write-Host "Stage 1: Flushing Recycle Bin and Temporary Directories..." -ForegroundColor Yellow
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue

        # Purge Windows system temp
        Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

        # Purge all user profile temp caches
        Get-ChildItem "C:\Users\*\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "Stage 2: Setting automated cleanmgr VolumeCaches flags (StateFlags7777)..." -ForegroundColor Yellow
        $volumeCaches = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        foreach ($cache in $volumeCaches) {
            Set-ItemProperty -Path $cache.PSPath -Name "StateFlags7777" -Value 2 -ErrorAction SilentlyContinue
        }

        Write-Host "Stage 3: Running cleanmgr.exe silently via /sagerun:7777..." -ForegroundColor Cyan
        $cleanProcess = Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:7777" -Wait -WindowStyle Hidden -PassThru

        # Step 4: Verify recovered storage
        $driveAfter = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
        $afterFreeGB = [math]::Round($driveAfter.FreeSpace / 1GB, 2)
        $recoveredGB = [math]::Round(($afterFreeGB - $beforeFreeGB), 2)

        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Free space before cleanup : $beforeFreeGB GB"
        Write-Host "Free space after cleanup  : $afterFreeGB GB"
        Write-Host "Total storage recovered   : $recoveredGB GB" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Error "Workstation disk cleanup failed: $_"
    exit 1
}
