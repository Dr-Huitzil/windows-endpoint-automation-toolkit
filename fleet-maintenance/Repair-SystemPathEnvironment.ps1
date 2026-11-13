<#
.SYNOPSIS
    Verifies and repairs missing directory entries in the system-wide Machine environment PATH variable.

.DESCRIPTION
    Remediates broken system environments where critical paths (such as the 64-bit PowerShell v1.0 directory)
    were inadvertently omitted or wiped from the Machine-level PATH environment variable, which prevents
    NinjaOne background automation agents and scheduled tasks from locating CLI executables.

.PARAMETER TargetPath
    Directory path to verify and append if missing. Defaults to $env:targetSystemPath or standard PowerShell v1.0 directory.

.EXAMPLE
    .\Repair-SystemPathEnvironment.ps1 -TargetPath "%SYSTEMROOT%\System32\WindowsPowerShell\v1.0\"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "System PATH entry to verify and append")]
    [string]$TargetPath = $(if ($env:targetSystemPath) { $env:targetSystemPath } else { "%SYSTEMROOT%\System32\WindowsPowerShell\v1.0\" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to modify the Machine environment PATH."
    exit 1
}

$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$splitPaths = $currentPath -split ';'

Write-Host "Verifying Machine PATH environment for entry: '$TargetPath'..." -ForegroundColor Cyan

if ($splitPaths -contains $TargetPath -or $splitPaths -contains ($TargetPath.TrimEnd('\'))) {
    Write-Host "[VERIFIED] Path '$TargetPath' is already present in Machine PATH. No changes needed." -ForegroundColor Green
    exit 0
}

if ($PSCmdlet.ShouldProcess("Machine Environment", "Append '$TargetPath' to System PATH")) {
    try {
        $updatedPath = "$currentPath;$TargetPath"
        [Environment]::SetEnvironmentVariable("Path", $updatedPath, "Machine")
        Write-Host "[SUCCESS] Successfully appended '$TargetPath' to Machine PATH." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error "Failed to update Machine PATH environment: $_"
        exit 1
    }
}
