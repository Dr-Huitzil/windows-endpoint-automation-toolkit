<#
.SYNOPSIS
    Automates staging and silent installation of Fujitsu ScandAll PRO for fi-series document scanners.

.DESCRIPTION
    Stages installation assets for Fujitsu fi-7160 / fi-7180 production document scanners from a network
    software share to local disk cache, invokes msiexec silently with verbose logging (/L*v),
    validates installation exit codes (0, 3010), and purges temporary installation files.

.PARAMETER SourcePath
    SMB network path holding the ScandAll PRO installer files. Defaults to $env:scandallSourcePath.

.PARAMETER DestinationPath
    Local staging folder. Defaults to $env:scandallDestinationPath or 'C:\ProgramData\PackageStaging\ScandAll'.

.EXAMPLE
    .\Install-FujitsuScandAllPro.ps1 -SourcePath "\\fileserver.contoso.local\Software\Fujitsu"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "SMB network source path")]
    [string]$SourcePath = $env:scandallSourcePath,

    [Parameter(Mandatory = $false, HelpMessage = "Local staging folder")]
    [string]$DestinationPath = $(if ($env:scandallDestinationPath) { $env:scandallDestinationPath } else { "C:\ProgramData\PackageStaging\ScandAll" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to install scanner software."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    Write-Error "Source path is required. Pass -SourcePath or supply `$env:scandallSourcePath via NinjaOne."
    exit 1
}

$msiLog = "$env:SystemRoot\Temp\ScandAllPRO_MSI.log"

Write-Host "Initiating Fujitsu ScandAll PRO scanner deployment pipeline..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("Local System", "Deploy ScandAll PRO MSI to $DestinationPath")) {
    try {
        if (-not (Test-Path $DestinationPath)) {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }

        Write-Host "Stage 1: Staging ScandAll PRO installation files from '$SourcePath'..." -ForegroundColor Yellow
        Copy-Item -Path "$SourcePath\*" -Destination $DestinationPath -Recurse -Force

        # Locate the MSI installer
        $msiFile = Get-ChildItem -Path $DestinationPath -Filter "*.msi" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

        if (-not $msiFile) {
            throw "No MSI package was found inside $DestinationPath."
        }

        Write-Host "Stage 2: Installing $($msiFile.Name) silently (Log: $msiLog)..." -ForegroundColor Cyan
        $msiArgs = "/i `"$($msiFile.FullName)`" /qn /norestart /L*v `"$msiLog`""
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru

        # Cleanup staging cache
        Remove-Item -Path $DestinationPath -Recurse -Force -ErrorAction SilentlyContinue

        if ($process.ExitCode -in 0, 3010) {
            Write-Host "[SUCCESS] Fujitsu ScandAll PRO installed successfully (Exit code: $($process.ExitCode))." -ForegroundColor Green
            exit 0
        } else {
            Write-Warning "Installation exited with unexpected code: $($process.ExitCode). Review log: $msiLog"
            exit $process.ExitCode
        }
    }
    catch {
        Write-Error "ScandAll PRO deployment failed: $_"
        exit 1
    }
}
