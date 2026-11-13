<#
.SYNOPSIS
    Automates machine-wide application updates via Winget and triggers Windows Store app updates under SYSTEM.

.DESCRIPTION
    Bypasses standard SYSTEM account token restrictions that block Microsoft Store updates by directly
    triggering the native 'Automatic App Update' scheduled task. Also resolves the machine-wide winget.exe
    path in WindowsApps and executes silent upgrades for approved software packages.

.PARAMETER TargetPackageId
    Optional package ID to update specifically. If omitted, upgrades all machine-wide applications.

.EXAMPLE
    .\Invoke-WingetFleetUpdate.ps1 -TargetPackageId "Google.Chrome"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Winget Package ID to update")]
    [string]$TargetPackageId = $env:wingetPackageId
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to run machine-wide package updates."
    exit 1
}

Write-Host "Stage 1: Triggering native Windows Store Automatic App Update task (Bypassing SYSTEM token block)..." -ForegroundColor Cyan
$storeTask = Get-ScheduledTask -TaskPath "\Microsoft\Windows\WindowsUpdate\" -TaskName "Automatic App Update" -ErrorAction SilentlyContinue

if ($storeTask) {
    if ($PSCmdlet.ShouldProcess("Task: Automatic App Update", "Start background Store app patch")) {
        Start-ScheduledTask -TaskPath "\Microsoft\Windows\WindowsUpdate\" -TaskName "Automatic App Update"
        Write-Host "[SUCCESS] Windows Store update task initiated in background." -ForegroundColor Green
    }
} else {
    Write-Warning "Could not locate Automatic App Update task. Store updates may be managed via GPO."
}

Write-Host "`nStage 2: Resolving machine-wide Winget engine..." -ForegroundColor Cyan
$wingetPath = Get-ChildItem -Path "C:\Program Files\WindowsApps\" -Filter "winget.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

if ($wingetPath) {
    Write-Host "Winget located at: $wingetPath" -ForegroundColor DarkGray

    if (-not [string]::IsNullOrWhiteSpace($TargetPackageId)) {
        Write-Host "Targeted upgrade for package: '$TargetPackageId'..." -ForegroundColor Cyan
        $wingetArgs = "upgrade --id $TargetPackageId --scope machine --force --silent --accept-package-agreements --accept-source-agreements"
    } else {
        Write-Host "Executing machine-wide upgrade for all available Winget packages..." -ForegroundColor Cyan
        $wingetArgs = "upgrade --all --scope machine --silent --accept-package-agreements --accept-source-agreements"
    }

    if ($PSCmdlet.ShouldProcess("Winget Engine", "Execute '$wingetArgs'")) {
        $process = Start-Process -FilePath $wingetPath -ArgumentList $wingetArgs -Wait -NoNewWindow -PassThru
        Write-Host "Winget completed with exit code: $($process.ExitCode)" -ForegroundColor $(if ($process.ExitCode -eq 0) { "Green" } else { "Yellow" })
    }
} else {
    Write-Warning "Winget executable could not be resolved in C:\Program Files\WindowsApps."
}

exit 0
