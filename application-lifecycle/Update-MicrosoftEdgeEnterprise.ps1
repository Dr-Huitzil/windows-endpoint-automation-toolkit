<#
.SYNOPSIS
    Automates silent background patching of Microsoft Edge via Winget and native EdgeUpdate.

.DESCRIPTION
    Forces silent background patching of Microsoft Edge to resolve weekly Chromium CVE releases.
    Attempts machine-wide upgrade via Winget under SYSTEM context first; falls back to invoking the
    native Microsoft Edge Update engine (MicrosoftEdgeUpdate.exe /silent /update).

.EXAMPLE
    .\Update-MicrosoftEdgeEnterprise.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to update Microsoft Edge Enterprise."
    exit 1
}

Write-Host "Initiating Microsoft Edge Enterprise silent update pipeline..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("Microsoft Edge", "Trigger silent background update")) {
    $updatedViaWinget = $false

    # Stage 1: Try Winget Machine-Wide
    $winget = Get-ChildItem -Path "C:\Program Files\WindowsApps\" -Filter "winget.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if ($winget) {
        Write-Host "Attempting machine-wide Edge upgrade via Winget..." -ForegroundColor Cyan
        $wingetArgs = "upgrade --id Microsoft.Edge --source winget --scope machine --force --silent --accept-package-agreements --accept-source-agreements"
        $proc = Start-Process -FilePath $winget -ArgumentList $wingetArgs -Wait -NoNewWindow -PassThru

        if ($proc.ExitCode -eq 0) {
            Write-Host "[SUCCESS] Microsoft Edge updated successfully via Winget." -ForegroundColor Green
            $updatedViaWinget = $true
        }
    }

    # Stage 2: Trigger Native EdgeUpdate Engine
    if (-not $updatedViaWinget) {
        Write-Host "Triggering native Microsoft Edge Update engine check..." -ForegroundColor Cyan
        $edgeUpdatePaths = @(
            "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe",
            "$env:ProgramFiles\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe"
        )
        $edgeExe = $edgeUpdatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

        if ($edgeExe) {
            $edgeProc = Start-Process -FilePath $edgeExe -ArgumentList "/silent /update" -Wait -PassThru
            Write-Host "[SUCCESS] Microsoft Edge update command dispatched to native updater." -ForegroundColor Green
            exit 0
        } else {
            Write-Error "Microsoft Edge Update engine could not be resolved."
            exit 1
        }
    }

    exit 0
}
