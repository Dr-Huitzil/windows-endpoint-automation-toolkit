<#
.SYNOPSIS
    Provisions and enforces standardized local accounts and credential baselines.

.DESCRIPTION
    Creates or updates a standardized local SAM user account, enforcing non-expiring passwords,
    restricting password modification, and ensuring proper local group membership ('Users' or 'Administrators').

.PARAMETER Username
    Target local account name. Defaults to $env:localUsername or 'StandardLocalUser'.

.PARAMETER Password
    Account password string. Defaults to $env:localPassword.

.PARAMETER FullName
    Display name for the local user. Defaults to $env:localFullName or 'Standard Local User'.

.PARAMETER Role
    Local group assignment: 'User' (Users group) or 'Administrator' (Administrators group).
    Defaults to $env:accountRole or 'User'.

.EXAMPLE
    .\Initialize-StandardLocalAccounts.ps1 -Username "labuser" -Password "SecureInitP@ss1" -Role "User"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Local account username")]
    [string]$Username = $(if ($env:localUsername) { $env:localUsername } else { "StandardLocalUser" }),

    [Parameter(Mandatory = $false, HelpMessage = "Account password")]
    [string]$Password = $env:localPassword,

    [Parameter(Mandatory = $false, HelpMessage = "Full display name")]
    [string]$FullName = $(if ($env:localFullName) { $env:localFullName } else { "Standard Local User" }),

    [Parameter(Mandatory = $false, HelpMessage = "Group role ('User' or 'Administrator')")]
    [ValidateSet("User", "Administrator")]
    [string]$Role = $(if ($env:accountRole) { $env:accountRole } else { "User" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to manage local user accounts."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Password)) {
    Write-Error "Password is required. Provide -Password or configure `$env:localPassword via NinjaOne parameter."
    exit 1
}

$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$targetGroup = if ($Role -eq "Administrator") { "Administrators" } else { "Users" }

Write-Host "Standardizing local account '$Username' [Role: $Role -> Group: $targetGroup]..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("$Username", "Configure account attributes and assign to $targetGroup")) {
    try {
        $existingUser = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue

        if ($existingUser) {
            Write-Host "Account '$Username' already exists. Synchronizing password and account flags..." -ForegroundColor Yellow
            Set-LocalUser -Name $Username -FullName $FullName -Description "$FullName Baseline Account" -Password $securePassword -PasswordNeverExpires -AccountNeverExpires -ErrorAction Stop
        } else {
            Write-Host "Creating new local account '$Username'..." -ForegroundColor Green
            New-LocalUser -Name $Username -FullName $FullName -Description "$FullName Baseline Account" -Password $securePassword -PasswordNeverExpires -AccountNeverExpires -ErrorAction Stop | Out-Null
        }

        # Prevent user from changing their password
        & net.exe user $Username /PasswordChg:No | Out-Null

        # Ensure membership in designated group
        Add-LocalGroupMember -Group $targetGroup -Member $Username -ErrorAction SilentlyContinue

        Write-Host "[SUCCESS] Local account '$Username' successfully standardized in $targetGroup." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error "Failed to standardize local account '$Username': $_"
        exit 1
    }
}
