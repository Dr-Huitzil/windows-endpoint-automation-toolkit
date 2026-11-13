<#
.SYNOPSIS
    Automates deployment of dental clinical imaging software, Visual C++ dependencies, and public desktop shortcuts.

.DESCRIPTION
    Stages clinical imaging application suites (such as Apteryx XVCapture / XVWeb) from central network
    repositories to local disk, executes silent prerequisites (Visual C++ Redistributable /install /quiet /norestart),
    installs the web capture connector, and provisions public desktop shortcuts for operatory workstations.

.PARAMETER SourcePath
    SMB network software share holding the imaging package assets. Defaults to $env:imagingSourcePath.

.PARAMETER DestinationPath
    Local installation directory. Defaults to $env:imagingDestinationPath or 'C:\ProgramData\ImagingSuite'.

.EXAMPLE
    .\Install-ImagingSuite.ps1 -SourcePath "\\fileserver.contoso.local\Software\Imaging"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "SMB network source directory")]
    [string]$SourcePath = $env:imagingSourcePath,

    [Parameter(Mandatory = $false, HelpMessage = "Local destination folder")]
    [string]$DestinationPath = $(if ($env:imagingDestinationPath) { $env:imagingDestinationPath } else { "C:\ProgramData\ImagingSuite" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to deploy clinical imaging software."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    Write-Error "Source path is required. Pass -SourcePath or supply `$env:imagingSourcePath via NinjaOne."
    exit 1
}

Write-Host "Initiating clinical imaging software deployment pipeline..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("Local System", "Deploy Imaging Suite from $SourcePath to $DestinationPath")) {
    try {
        if (-not (Test-Path $DestinationPath)) {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }

        # Stage files from network
        Write-Host "Stage 1: Staging software assets from '$SourcePath'..." -ForegroundColor Yellow
        Copy-Item -Path "$SourcePath\*" -Destination $DestinationPath -Recurse -Force

        # Locate Visual C++ Redistributable dependency
        $vcRedist = Get-ChildItem -Path $DestinationPath -Filter "*vc_redist*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($vcRedist) {
            Write-Host "Stage 2: Installing Microsoft Visual C++ Redistributable ($($vcRedist.Name))..." -ForegroundColor Cyan
            $vcProc = Start-Process -FilePath $vcRedist.FullName -ArgumentList "/install", "/quiet", "/norestart" -Wait -PassThru
            Write-Host "VC++ Redistributable exited with code: $($vcProc.ExitCode)" -ForegroundColor $(if ($vcProc.ExitCode -in 0, 3010) { "Green" } else { "Yellow" })
        }

        # Locate secondary installers (e.g. Web extension)
        $webInstaller = Get-ChildItem -Path $DestinationPath -Filter "*WebInstaller*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($webInstaller) {
            Write-Host "Stage 3: Executing Web Extension installer ($($webInstaller.Name))..." -ForegroundColor Cyan
            $webProc = Start-Process -FilePath $webInstaller.FullName -ArgumentList "/silent /norestart" -Wait -PassThru
            Write-Host "Web Extension installer exited with code: $($webProc.ExitCode)" -ForegroundColor $(if ($webProc.ExitCode -in 0, 3010) { "Green" } else { "Yellow" })
        }

        # Provision Public Desktop Shortcut
        $mainExe = Get-ChildItem -Path $DestinationPath -Filter "*Capture*.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($mainExe) {
            Write-Host "Stage 4: Creating Public Desktop shortcut for $($mainExe.Name)..." -ForegroundColor Cyan
            $shortcutPath = "$env:PUBLIC\Desktop\$($mainExe.BaseName).lnk"
            $wshShell = New-Object -ComObject WScript.Shell
            $shortcut = $wshShell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = $mainExe.FullName
            $shortcut.WorkingDirectory = $mainExe.DirectoryName
            $shortcut.Save()
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($wshShell) | Out-Null
        }

        Write-Host "[SUCCESS] Clinical imaging suite deployed successfully." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error "Clinical imaging deployment failed: $_"
        exit 1
    }
}
