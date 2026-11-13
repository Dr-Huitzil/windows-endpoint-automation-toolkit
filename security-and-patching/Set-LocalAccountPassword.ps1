<#
.SYNOPSIS
    Updates the password for a designated local user or administrator account.

.DESCRIPTION
    Safely resets the local password for a specified local user or administrator account
    using environment variables supplied by NinjaOne RMM form pop-ups or standard CLI inputs.

.PARAMETER AccountType
    The target account tier: 'User' or 'Administrator'. Defaults to $env:account.

.PARAMETER Username
    Direct local username override. If omitted, derives from AccountType or $env:targetUsername.

.PARAMETER Password
    The new password string. Defaults to $env:password.

.EXAMPLE
    .\Set-LocalAccountPassword.ps1 -AccountType "Administrator" -Password "NewComp1exP@ss!"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Account tier ('User' or 'Administrator')")]
    [ValidateSet("User", "Administrator")]
    [string]$AccountType = $(if ($env:account) { $env:account } else { "User" }),

    [Parameter(Mandatory = $false, HelpMessage = "Specific local username override")]
    [string]$Username = $env:targetUsername,

    [Parameter(Mandatory = $false, HelpMessage = "New password string")]
    [string]$Password = $env:password
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to reset local passwords."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Password)) {
    Write-Error "Password is required. Provide -Password or configure `$env:password via NinjaOne."
    exit 1
}

# Resolve username based on account tier if not explicitly provided
if ([string]::IsNullOrWhiteSpace($Username)) {
    $Username = switch ($AccountType) {
        "User"          { if ($env:localStandardUser) { $env:localStandardUser } else { "StandardLocalUser" } }
        "Administrator" { if ($env:localAdminUser) { $env:localAdminUser } else { "LocalAdmin" } }
    }
}

$targetUser = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue
if (-not $targetUser) {
    Write-Error "Target local account '$Username' does not exist on this machine."
    exit 1
}

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force

Write-Host "Updating password for local account '$Username'..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("$Username", "Reset local account password")) {
    try {
        Set-LocalUser -Name $Username -Password $securePassword -ErrorAction Stop
        Write-Host "[SUCCESS] Password for '$Username' has been successfully updated." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error "Failed to update password for '$Username': $_"
        exit 1
    }
}
