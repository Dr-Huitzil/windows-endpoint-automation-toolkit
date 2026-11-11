<#
.SYNOPSIS
    Identifies and removes stale local Windows user profiles inactive beyond a retention window.

.DESCRIPTION
    Builds an active-user whitelist from LocalSessionManager Event ID 21 logons within the
    retention period, evaluates non-special Win32_UserProfile objects, and removes dormant local
    profiles and ProfileList registry keys safely. Defaults to -WhatIf-friendly simulation unless
    -ExecuteDeletion is explicitly supplied.

.PARAMETER RetentionDays
    Inactivity threshold in days (default: 30).

.PARAMETER ExcludedUsers
    Accounts always retained regardless of recent logon history.

.PARAMETER ExecuteDeletion
    Performs live profile removal via Remove-CimInstance; otherwise runs in simulation mode.

.EXAMPLE
    .\Clear-StaleUserProfiles.ps1 -RetentionDays 30

.EXAMPLE
    .\Clear-StaleUserProfiles.ps1 -RetentionDays 45 -ExecuteDeletion -Confirm:$false
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateRange(1, 365)]
    [int]$RetentionDays = 30,
    [string[]]$ExcludedUsers = @('Administrator', 'localadmin', 'standarduser', 'Public', 'Default'),
    [switch]$ExecuteDeletion
)

try {
    $auditScript = Join-Path -Path $PSScriptRoot -ChildPath 'Get-InteractiveLogonAudit.ps1'
    $activeUsers = @()
    if (Test-Path -Path $auditScript) {
        $activeUsers = @(& $auditScript -DaysBack $RetentionDays -ExcludedUsers @() | Select-Object -ExpandProperty Username)
    }

    $profiles = Get-CimInstance -ClassName Win32_UserProfile | Where-Object { -not $_.Special }
    foreach ($profile in $profiles) {
        $profileName = Split-Path -Path $profile.LocalPath -Leaf

        if ($ExcludedUsers -contains $profileName) {
            Write-Output "SKIP (Excluded): $profileName"
            continue
        }
        if ($activeUsers -contains $profileName) {
            Write-Output "SKIP (Active within $RetentionDays days): $profileName"
            continue
        }

        if (-not $ExecuteDeletion) {
            Write-Output "[SIMULATION] Would remove dormant profile: $profileName ($($profile.LocalPath))"
            continue
        }

        if ($PSCmdlet.ShouldProcess($profile.LocalPath, "Remove stale profile '$profileName'")) {
            $profile | Remove-CimInstance -ErrorAction Stop
            Write-Output "REMOVED dormant profile: $profileName"
        }
    }
}
catch {
    Write-Error "Profile cleanup failed: $_"
    exit 1
}
