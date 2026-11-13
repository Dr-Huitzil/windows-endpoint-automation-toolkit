<#
.SYNOPSIS
    Automates silent downloading and updating of the standalone VMware Horizon Client for VDI access.

.DESCRIPTION
    Terminates active vmware-view and vmware-remotemks background processes to prevent file locks,
    downloads the standalone 64-bit client executable from vendor CDN or internal repository,
    forces unattended installation with /s /v"/qn REBOOT=ReallySuppress", validates exit codes,
    and purges downloaded installer binaries.

.PARAMETER DownloadUrl
    Direct download URL for the VMware Horizon Client. Defaults to $env:vmwareClientUrl.

.EXAMPLE
    .\Update-VMwareHorizonClient.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Download URL for VMware Horizon Client executable")]
    [string]$DownloadUrl = $(if ($env:vmwareClientUrl) { $env:vmwareClientUrl } else { "https://download3.vmware.com/software/view/viewclients/CART25FQ1/VMware-Horizon-Client-2406-8.13.0-23910332.exe" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to install or update VMware Horizon Client."
    exit 1
}

$tempSetup = "$env:TEMP\VMwareHorizonClientSetup.exe"

Write-Host "Initiating VMware Horizon Client silent upgrade pipeline..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("VMware Horizon Client", "Terminate active sessions and apply silent upgrade")) {
    try {
        Write-Host "Stage 1: Terminating active Horizon Client and RemoteMKS worker processes..." -ForegroundColor Yellow
        Stop-Process -Name "vmware-view" -Force -ErrorAction SilentlyContinue
        Stop-Process -Name "vmware-remotemks" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        # Purge stale installer fragment
        if (Test-Path $tempSetup) { Remove-Item -Path $tempSetup -Force }

        Write-Host "Stage 2: Downloading latest Horizon Client binary from vendor repository..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $tempSetup -UseBasicParsing -ErrorAction Stop

        if (-not (Test-Path $tempSetup) -or (Get-Item $tempSetup).Length -lt 10000000) {
            throw "Downloaded Horizon Client installer is invalid or incomplete."
        }

        Write-Host "Stage 3: Forcing silent upgrade via /s /v`"/qn REBOOT=ReallySuppress`"..." -ForegroundColor Cyan
        $process = Start-Process -FilePath $tempSetup -ArgumentList '/s /v"/qn REBOOT=ReallySuppress"' -Wait -PassThru

        # Cleanup downloaded installer
        Remove-Item -Path $tempSetup -Force -ErrorAction SilentlyContinue

        if ($process.ExitCode -in 0, 3010) {
            Write-Host "[SUCCESS] VMware Horizon Client successfully updated (Exit code: $($process.ExitCode))." -ForegroundColor Green
            exit 0
        } else {
            Write-Warning "Horizon Client installer exited with non-standard code: $($process.ExitCode)"
            exit $process.ExitCode
        }
    }
    catch {
        Write-Error "VMware Horizon Client update pipeline failed: $_"
        exit 1
    }
}
