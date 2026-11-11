<#
.SYNOPSIS
    Safely uninstalls a specific Windows Cumulative Update via DISM CBS package inspection.

.DESCRIPTION
    Filters Component Based Servicing (CBS) registry entries exclusively for RollupFix packages
    while excluding protected core OS packages (Composition, Language, WOW64, merged, Foundation).
    Identifies the package matching the specified KB identifier and executes quiet DISM removal.

.PARAMETER KBNumber
    Numeric KB identifier (with or without 'KB' prefix, e.g., '5027648').

.EXAMPLE
    .\Uninstall-WindowsCumulativeUpdate.ps1 -KBNumber "5027648" -WhatIf
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^(KB)?\d+$')]
    [string]$KBNumber
)

try {
    $kbDigits = $KBNumber -replace '^KB', ''
    $cbsPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages'

    Write-Output "Searching CBS RollupFix packages for KB$kbDigits..."
    $safePackages = Get-ChildItem -Path $cbsPath -ErrorAction Stop | Where-Object {
        ($_.PSChildName -like '*RollupFix*') -and
        ($_.PSChildName -notmatch 'Composition|Language|WOW64|merged|Foundation')
    }

    $targetPackage = $null
    foreach ($pkg in $safePackages) {
        $props = Get-ItemProperty -Path $pkg.PSPath -ErrorAction SilentlyContinue | Out-String
        if ($props -match $kbDigits) {
            $targetPackage = $pkg.PSChildName
            break
        }
    }

    if (-not $targetPackage) {
        Write-Warning "No eligible RollupFix package found matching KB$kbDigits."
        exit 0
    }

    Write-Output "Matched CBS package: $targetPackage"
    if ($PSCmdlet.ShouldProcess($targetPackage, 'DISM /Remove-Package')) {
        $dismArgs = "/Online /Remove-Package /PackageName:$targetPackage /Quiet /NoRestart"
        $proc = Start-Process -FilePath 'dism.exe' -ArgumentList $dismArgs -Wait -NoNewWindow -PassThru

        switch ($proc.ExitCode) {
            0 { Write-Output "Successfully removed KB$kbDigits." }
            3010 { Write-Output "Successfully removed KB$kbDigits. Reboot required to finalize." }
            default { throw "DISM removal failed with exit code $($proc.ExitCode)." }
        }
    }
}
catch {
    Write-Error "Cumulative update rollback failed: $_"
    exit 1
}
