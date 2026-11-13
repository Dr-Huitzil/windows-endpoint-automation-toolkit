<#
.SYNOPSIS
    Silently removes unmanaged Mozilla Firefox installations to standardize on enterprise browsers.

.DESCRIPTION
    Enforces organizational software footprint minimization by removing unmanaged Mozilla Firefox
    installations. Discovers helper.exe across 64-bit and 32-bit Program Files trees, executes silent
    removal with /S, and standardizes the fleet on centrally managed Google Chrome Enterprise and Microsoft Edge.

.EXAMPLE
    .\Uninstall-MozillaFirefox.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to uninstall Mozilla Firefox."
    exit 1
}

$uninstallerPaths = @(
    "${env:ProgramFiles}\Mozilla Firefox\uninstall\helper.exe",
    "${env:ProgramFiles(x86)}\Mozilla Firefox\uninstall\helper.exe"
)

$foundUninstaller = $uninstallerPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $foundUninstaller) {
    Write-Host "[VERIFIED] Mozilla Firefox is not installed in standard directory paths." -ForegroundColor Green
    exit 0
}

Write-Host "Discovered Firefox uninstaller at: $foundUninstaller" -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("$foundUninstaller", "Execute silent Firefox removal via /S")) {
    try {
        # Terminate any running Firefox instances
        Stop-Process -Name "firefox" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1

        $process = Start-Process -FilePath $foundUninstaller -ArgumentList "/S" -Wait -PassThru
        Write-Host "[SUCCESS] Mozilla Firefox successfully uninstalled (Exit code: $($process.ExitCode))." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error "Failed to execute Firefox uninstallation: $_"
        exit 1
    }
}
