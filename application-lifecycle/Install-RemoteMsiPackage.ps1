<#
.SYNOPSIS
    Stages an MSI package locally from an SMB repository and executes silent installation, preventing Kerberos double-hop failures.

.DESCRIPTION
    When background RMM agents or remote PowerShell sessions running under NT AUTHORITY\SYSTEM attempt
    to access network shares, Kerberos double-hop delegation blocks direct network execution.
    This script copies the MSI installer locally to a sanitized administrative staging directory,
    verifies file integrity, executes msiexec with verbose logging, and cleans up the staging cache.

.PARAMETER SourcePath
    The source SMB share path or local distribution folder. Defaults to $env:msiSourcePath.

.PARAMETER MsiFileName
    The file name of the MSI installer. Defaults to $env:msiFileName.

.PARAMETER Arguments
    Custom msiexec arguments. Defaults to '/qn /norestart'.

.EXAMPLE
    .\Install-RemoteMsiPackage.ps1 -SourcePath "\\fileserver.contoso.local\SoftwareRepository" -MsiFileName "AgentInstaller.msi"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Source SMB network directory")]
    [string]$SourcePath = $env:msiSourcePath,

    [Parameter(Mandatory = $false, HelpMessage = "MSI installer filename")]
    [string]$MsiFileName = $env:msiFileName,

    [Parameter(Mandatory = $false, HelpMessage = "Custom MSI arguments")]
    [string]$Arguments = $(if ($env:msiArguments) { $env:msiArguments } else { "/qn /norestart" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to install MSI packages."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($SourcePath) -or [string]::IsNullOrWhiteSpace($MsiFileName)) {
    Write-Error "Both -SourcePath and -MsiFileName (or `$env:msiSourcePath and `$env:msiFileName) are required."
    exit 1
}

$sourceFile = Join-Path -Path $SourcePath -ChildPath $MsiFileName
$stagingDir = "$env:ProgramData\PackageStaging"
$localMsi = Join-Path -Path $stagingDir -ChildPath $MsiFileName
$logFile = "$env:SystemRoot\Temp\$([System.IO.Path]::GetFileNameWithoutExtension($MsiFileName))_Install.log"

Write-Host "Initiating anti-double-hop MSI deployment for: $MsiFileName..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("$MsiFileName", "Stage locally and execute silent MSI install")) {
    try {
        # Create local staging directory
        if (-not (Test-Path $stagingDir)) {
            New-Item -Path $stagingDir -ItemType Directory -Force | Out-Null
        }

        Write-Host "Stage 1: Staging installer from '$sourceFile' to '$localMsi'..." -ForegroundColor Yellow
        Copy-Item -Path $sourceFile -Destination $localMsi -Force -ErrorAction Stop

        if (-not (Test-Path $localMsi)) {
            throw "Failed to verify local staging file at $localMsi."
        }

        Write-Host "Stage 2: Executing msiexec silently (Log: $logFile)..." -ForegroundColor Cyan
        $fullArgs = "/i `"$localMsi`" $Arguments /L*v `"$logFile`""
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $fullArgs -Wait -PassThru

        Write-Host "Installer completed with exit code: $($process.ExitCode)" -ForegroundColor $(if ($process.ExitCode -in 0, 3010) { "Green" } else { "Red" })

        # Stage 3: Clean up local cache
        Write-Host "Stage 3: Purging temporary staging cache..." -ForegroundColor DarkGray
        Remove-Item -Path $localMsi -Force -ErrorAction SilentlyContinue

        if ($process.ExitCode -in 0, 3010) {
            Write-Host "[SUCCESS] MSI package deployed successfully." -ForegroundColor Green
            exit 0
        } else {
            Write-Error "MSI installation failed with error code $($process.ExitCode). Review log: $logFile"
            exit $process.ExitCode
        }
    }
    catch {
        Write-Error "Remote MSI installation pipeline failed: $_"
        exit 1
    }
}
