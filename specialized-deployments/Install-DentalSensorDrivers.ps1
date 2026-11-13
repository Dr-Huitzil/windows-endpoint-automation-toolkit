<#
.SYNOPSIS
    Automates unattended staging and installation of digital radiography intraoral sensor drivers and InstallShield packages.

.DESCRIPTION
    Deploys intraoral sensor drivers and Twain acquisition software across clinical dental operatories.
    Applies silent parameters for GxPicture (/_ua /_gxtwain /_intraoral=all /_noreboot /L1033) and
    chains KaVo legacy IO sensor driver installation utilizing an InstallShield silent response file (setup.iss).

.PARAMETER SourcePath
    SMB network repository path holding sensor driver binaries. Defaults to $env:sensorDriverSourcePath.

.PARAMETER ResponseFilePath
    Path to the setup.iss InstallShield response file. Defaults to '.\setup.sample.iss'.

.EXAMPLE
    .\Install-DentalSensorDrivers.ps1 -SourcePath "\\fileserver.contoso.local\Software\DentalSensors"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "SMB network source path")]
    [string]$SourcePath = $env:sensorDriverSourcePath,

    [Parameter(Mandatory = $false, HelpMessage = "InstallShield response file path")]
    [string]$ResponseFilePath = $(if ($env:installShieldResponsePath) { $env:installShieldResponsePath } else { "$PSScriptRoot\setup.sample.iss" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to install device sensor drivers."
    exit 1
}

$stagingDir = "$env:ProgramData\PackageStaging\DentalSensors"

Write-Host "Initiating digital radiography sensor driver deployment pipeline..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("Local System", "Deploy GxPicture and KaVo intraoral sensor drivers")) {
    try {
        if (-not (Test-Path $stagingDir)) {
            New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null
        }

        # Stage files if remote source provided
        if (-not [string]::IsNullOrWhiteSpace($SourcePath) -and (Test-Path $SourcePath)) {
            Write-Host "Staging driver installer packages from: $SourcePath..." -ForegroundColor Yellow
            Copy-Item -Path "$SourcePath\*" -Destination $stagingDir -Recurse -Force
        }

        # 1. GxPicture Unattended Installation
        $gxInstaller = Get-ChildItem -Path $stagingDir -Filter "*GxPicture.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($gxInstaller) {
            Write-Host "Installing GxPicture intraoral sensor package ($($gxInstaller.Name))..." -ForegroundColor Cyan
            $gxArgs = "/_ua /_gxtwain /_intraoral=all /_noreboot /L1033"
            $gxProc = Start-Process -FilePath $gxInstaller.FullName -ArgumentList $gxArgs -Wait -PassThru
            Write-Host "GxPicture exited with code: $($gxProc.ExitCode)" -ForegroundColor $(if ($gxProc.ExitCode -eq 0) { "Green" } else { "Yellow" })
        } else {
            Write-Warning "GxPicture installer not found in $stagingDir. Skipping GxPicture phase."
        }

        # 2. KaVo Legacy Sensor InstallShield Deployment
        $kavoInstaller = Get-ChildItem -Path $stagingDir -Filter "*IO-Sensor*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($kavoInstaller -and (Test-Path $ResponseFilePath)) {
            Write-Host "Installing KaVo Legacy Sensor drivers via InstallShield response file ($ResponseFilePath)..." -ForegroundColor Cyan
            $kavoArgs = "/s /f1`"$ResponseFilePath`""
            $kavoProc = Start-Process -FilePath $kavoInstaller.FullName -ArgumentList $kavoArgs -Wait -PassThru
            Write-Host "KaVo installer exited with code: $($kavoProc.ExitCode)" -ForegroundColor $(if ($kavoProc.ExitCode -eq 0) { "Green" } else { "Yellow" })
        }

        Write-Host "[SUCCESS] Sensor driver installation sequence finished." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error "Dental sensor driver deployment failed: $_"
        exit 1
    }
}
