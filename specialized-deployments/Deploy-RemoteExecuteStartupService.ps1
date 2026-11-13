<#
.SYNOPSIS
    Deploys helper executables and hidden configuration files to the all-users Startup folder.

.DESCRIPTION
    Copies remote execution helper binaries and configuration files from a network share to the
    common Startup folder (%ProgramData%\Microsoft\Windows\Start Menu\Programs\Startup), sets the Hidden
    file attribute on the configuration file, and launches the process if not currently running.

.PARAMETER SourcePath
    SMB network path holding the service binaries. Defaults to $env:remoteExecuteSourcePath.

.PARAMETER ExeFileName
    The executable filename to register. Defaults to $env:serviceExeName or 'RemoteExecuteService.exe'.

.PARAMETER ConfigFileName
    The configuration filename to stage. Defaults to $env:serviceConfigName or 'RemoteExecuteService.exe.config'.

.EXAMPLE
    .\Deploy-RemoteExecuteStartupService.ps1 -SourcePath "\\fileserver.contoso.local\Software\RemoteExecute"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "SMB network source path")]
    [string]$SourcePath = $env:remoteExecuteSourcePath,

    [Parameter(Mandatory = $false, HelpMessage = "Service executable filename")]
    [string]$ExeFileName = $(if ($env:serviceExeName) { $env:serviceExeName } else { "RemoteExecuteService.exe" }),

    [Parameter(Mandatory = $false, HelpMessage = "Service configuration filename")]
    [string]$ConfigFileName = $(if ($env:serviceConfigName) { $env:serviceConfigName } else { "RemoteExecuteService.exe.config" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to configure startup services."
    exit 1
}

$startupFolder = [System.IO.Path]::Combine($env:ProgramData, "Microsoft\Windows\Start Menu\Programs\Startup")
$targetExe = [System.IO.Path]::Combine($startupFolder, $ExeFileName)
$targetConfig = [System.IO.Path]::Combine($startupFolder, $ConfigFileName)

Write-Host "Configuring startup helper service: $ExeFileName..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("Startup Folder", "Deploy $ExeFileName and $ConfigFileName from $SourcePath")) {
    try {
        if (-not (Test-Path $targetExe) -or -not (Test-Path $targetConfig)) {
            if ([string]::IsNullOrWhiteSpace($SourcePath)) {
                Write-Error "Files not found in startup and no -SourcePath was supplied."
                exit 1
            }

            Write-Host "Copying files from '$SourcePath' into startup folder..." -ForegroundColor Yellow
            Copy-Item -Path (Join-Path $SourcePath $ExeFileName) -Destination $targetExe -Force -ErrorAction Stop
            Copy-Item -Path (Join-Path $SourcePath $ConfigFileName) -Destination $targetConfig -Force -ErrorAction Stop
        }

        # Apply Hidden attribute to config file to prevent end-user tampering
        if (Test-Path $targetConfig) {
            $configItem = Get-Item -Path $targetConfig -Force
            if (-not ($configItem.Attributes.HasFlag([System.IO.FileAttributes]::Hidden))) {
                $configItem.Attributes += [System.IO.FileAttributes]::Hidden
                Write-Host "Applied Hidden attribute to: $ConfigFileName" -ForegroundColor DarkGray
            }
        }

        # Verify whether process is actively running; launch if stopped
        $procName = [System.IO.Path]::GetFileNameWithoutExtension($ExeFileName)
        if (-not (Get-Process -Name $procName -ErrorAction SilentlyContinue)) {
            Write-Host "Starting background helper process: $ExeFileName..." -ForegroundColor Cyan
            Start-Process -FilePath $targetExe
        }

        Write-Host "[SUCCESS] Startup helper service deployed and initialized." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error "Failed to deploy startup service helper: $_"
        exit 1
    }
}
