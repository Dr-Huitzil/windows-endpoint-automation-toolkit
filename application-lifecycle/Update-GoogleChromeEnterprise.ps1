<#
.SYNOPSIS
    Automates silent background patching of Google Chrome Enterprise via direct MSI package deployment.

.DESCRIPTION
    Releases active process locks by terminating hung chrome instances during scheduled maintenance windows,
    downloads the latest Google Chrome 64-bit Enterprise MSI directly from Google's distribution CDN,
    verifies file integrity, and executes a silent msiexec upgrade to rapidly remediate weekly zero-day CVEs.

.PARAMETER ForceProcessTermination
    Whether to forcefully close active Chrome processes before installation. Defaults to $true.

.EXAMPLE
    .\Update-GoogleChromeEnterprise.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [bool]$ForceProcessTermination = $true
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to update Google Chrome Enterprise."
    exit 1
}

$downloadUrl = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
$tempMsi = "$env:TEMP\GoogleChromeEnterprise64.msi"

Write-Host "Initiating Google Chrome Enterprise silent update sequence..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("Google Chrome Enterprise", "Download latest MSI from Google CDN and install silently")) {
    try {
        if ($ForceProcessTermination) {
            Write-Host "Releasing application file locks by terminating active Chrome processes..." -ForegroundColor Yellow
            Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }

        # Clear any stale download fragment
        if (Test-Path $tempMsi) { Remove-Item -Path $tempMsi -Force }

        Write-Host "Downloading Google Chrome Enterprise MSI from official CDN..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempMsi -UseBasicParsing -ErrorAction Stop

        # Validate download size (> 50MB)
        if (-not (Test-Path $tempMsi) -or (Get-Item $tempMsi).Length -lt 50000000) {
            throw "Downloaded MSI package is invalid or corrupted (Length: $((Get-Item $tempMsi).Length) bytes)."
        }

        Write-Host "Executing silent MSI upgrade via msiexec.exe /i /qn /norestart..." -ForegroundColor Cyan
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$tempMsi`" /qn /norestart" -Wait -PassThru

        # Cleanup downloaded installer
        Remove-Item -Path $tempMsi -Force -ErrorAction SilentlyContinue

        if ($process.ExitCode -in 0, 3010) {
            Write-Host "[SUCCESS] Google Chrome Enterprise updated successfully (Exit code: $($process.ExitCode))." -ForegroundColor Green
            exit 0
        } else {
            Write-Warning "Chrome MSI installer exited with code $($process.ExitCode)."
            exit $process.ExitCode
        }
    }
    catch {
        Write-Error "Google Chrome Enterprise update failed: $_"
        exit 1
    }
}
