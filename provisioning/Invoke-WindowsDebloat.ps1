<#
.SYNOPSIS
    Removes consumer AppX bloatware, uninstalls OneDrive, and cleans the Windows component store.

.DESCRIPTION
    Designed for post-imaging first-logon execution via AutoUnattend.xml or RMM SYSTEM context.
    Removes both provisioned packages (preventing installation for future profiles) and existing
    installed packages across all user profiles.

.PARAMETER SkipOneDrive
    Retains the default OneDrive sync client if required by tenant policy.

.PARAMETER SkipComponentCleanup
    Skips the final DISM /StartComponentCleanup pass for faster lab testing.

.EXAMPLE
    .\Invoke-WindowsDebloat.ps1 -Verbose

.EXAMPLE
    .\Invoke-WindowsDebloat.ps1 -WhatIf
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$SkipOneDrive,
    [switch]$SkipComponentCleanup
)

$ErrorActionPreference = 'Continue'

$BloatwarePackages = @(
    'Clipchamp.Clipchamp'
    'Microsoft.BingNews'
    'Microsoft.BingSearch'
    'Microsoft.BingWeather'
    'Microsoft.GamingApp'
    'Microsoft.GetHelp'
    'Microsoft.Edge.GameAssist'
    'Microsoft.MicrosoftOfficeHub'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.Office.ActionsServer'
    'Microsoft.OneDrive'
    'Microsoft.OneDriveSync'
    'Microsoft.OutlookForWindows'
    'Microsoft.PowerAutomateDesktop'
    'Microsoft.StartExperiencesApp'
    'Microsoft.Todos'
    'Microsoft.WidgetsPlatformRuntime'
    'Microsoft.Windows.DevHome'
    'Microsoft.WindowsAlarms'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.WindowsSoundRecorder'
    'Microsoft.Xbox.TCUI'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    'Microsoft.YourPhone'
    'Microsoft.ZuneMusic'
    'MicrosoftCorporationII.QuickAssist'
    'MicrosoftWindows.Client.WebExperience'
    'MicrosoftWindows.CrossDevice'
    'MSTeams'
    'MicrosoftTeams'
)

try {
    if (-not $SkipOneDrive) {
        $oneDriveSetup = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
        if (-not (Test-Path -Path $oneDriveSetup)) {
            $oneDriveSetup = "$env:SystemRoot\System32\OneDriveSetup.exe"
        }

        if ((Test-Path -Path $oneDriveSetup) -and $PSCmdlet.ShouldProcess($oneDriveSetup, 'Uninstall OneDrive')) {
            Write-Output 'Uninstalling consumer OneDrive client...'
            Start-Process -FilePath $oneDriveSetup -ArgumentList '/uninstall' -NoNewWindow -Wait
        }
    }

    Write-Output "Evaluating $($BloatwarePackages.Count) AppX package patterns..."
    $provisioned = Get-AppxProvisionedPackage -Online

    foreach ($pattern in $BloatwarePackages) {
        $matchedProv = $provisioned | Where-Object { $_.DisplayName -like "*$pattern*" }
        foreach ($pkg in $matchedProv) {
            if ($PSCmdlet.ShouldProcess($pkg.PackageName, 'Remove-AppxProvisionedPackage')) {
                Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction SilentlyContinue | Out-Null
            }
        }

        $matchedUsers = Get-AppxPackage -Name "*$pattern*" -AllUsers -ErrorAction SilentlyContinue
        foreach ($pkg in $matchedUsers) {
            if ($PSCmdlet.ShouldProcess($pkg.PackageFullName, 'Remove-AppxPackage (AllUsers)')) {
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }

    if (-not $SkipComponentCleanup -and $PSCmdlet.ShouldProcess('DISM Component Store', 'StartComponentCleanup')) {
        Write-Output 'Running DISM component store cleanup...'
        $proc = Start-Process -FilePath 'dism.exe' -ArgumentList '/online /cleanup-image /startcomponentcleanup' -NoNewWindow -Wait -PassThru
        if ($proc.ExitCode -ne 0) {
            Write-Warning "DISM cleanup exited with code $($proc.ExitCode)."
        }
    }

    Write-Output 'Endpoint debloat complete.'
}
catch {
    Write-Error "Debloat failed: $_"
    exit 1
}
