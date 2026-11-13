<#
.SYNOPSIS
    Completely deprovisions a targeted local Windows user account, disk profile, and registry SID.

.DESCRIPTION
    Performs full endpoint cleanup when deprovisioning temporary local accounts (training profiles,
    former contractor logins). Unlike GUI account deletion, this script removes the local SAM object,
    purges the profile directory on disk (C:\Users\<Username>), and deregisters the ProfileList
    registry SID (HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList) via Win32_UserProfile.

.PARAMETER Username
    The target local username to purge. Defaults to $env:targetUsername.

.EXAMPLE
    .\Remove-LocalUserProfile.ps1 -Username "traininguser"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Target local username to delete")]
    [string]$Username = $env:targetUsername
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to deprovision local user profiles."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Username)) {
    Write-Error "Username is required. Pass -Username or supply `$env:targetUsername via NinjaOne."
    exit 1
}

Write-Host "Initiating complete profile and account deprovisioning for: '$Username'..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("$Username", "Delete SAM account, disk profile folder, and registry ProfileList SID")) {
    # Step 1: Identify local user account and profile SID
    $localUser = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
    $userProfile = $null

    if ($localUser) {
        $userSID = $localUser.SID.Value
        $userProfile = Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.SID -eq $userSID }
    } else {
        # Fallback: Locate profile by directory match if SAM account was already removed
        $userProfile = Get-CimInstance -Class Win32_UserProfile | Where-Object { $_.LocalPath -match "\\$Username`$" }
    }

    # Step 2: Purge profile directory and registry SID entry
    if ($userProfile) {
        Write-Host "Found profile at '$($userProfile.LocalPath)'. Purging files and registry keys..." -ForegroundColor Yellow
        try {
            $userProfile | Remove-CimInstance -ErrorAction Stop
            Write-Host "[SUCCESS] Profile data and registry entries wiped for '$Username'." -ForegroundColor Green
        }
        catch {
            Write-Warning "Could not purge Win32_UserProfile: $_"
        }
    } else {
        Write-Host "[SKIPPED] No profile folder or registry entry found for '$Username'." -ForegroundColor DarkGray
    }

    # Step 3: Remove the local SAM account object
    if ($localUser) {
        Write-Host "Deleting local SAM account object '$Username'..." -ForegroundColor Yellow
        try {
            Remove-LocalUser -Name $Username -ErrorAction Stop
            Write-Host "[SUCCESS] Local SAM user account '$Username' deleted." -ForegroundColor Green
        }
        catch {
            Write-Error "Could not delete local account object: $_"
            exit 1
        }
    } else {
        Write-Host "[SKIPPED] Local user account '$Username' does not exist in SAM database." -ForegroundColor DarkGray
    }

    exit 0
}
