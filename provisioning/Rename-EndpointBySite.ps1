<#
.SYNOPSIS
    Standardizes Windows computer names using a <SITE>-<DEVICE>-<ASSET> schema.

.DESCRIPTION
    Resolves site abbreviations from a JSON configuration file, clears active SMB sessions to
    avoid computer-rename locks, and executes Rename-Computer using a supplied PSCredential.

.PARAMETER SiteName
    Target site key from config file (falls back to $env:location).

.PARAMETER DeviceType
    Device form factor ('Desktop' -> D, 'Laptop' -> L) (falls back to $env:deviceType).

.PARAMETER AssetNumber
    Asset tag identifier (falls back to $env:assetNumber).

.PARAMETER Credential
    Domain credential authorized to rename AD computer objects (prompted if omitted).

.PARAMETER ConfigPath
    Path to the JSON site metadata file.

.EXAMPLE
    $cred = Get-Credential
    .\Rename-EndpointBySite.ps1 -SiteName "Site-HQ" -DeviceType Desktop -AssetNumber "25014" -Credential $cred
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SiteName = $env:location,
    [ValidateSet('Desktop', 'Laptop')]
    [string]$DeviceType = $(if ($env:deviceType) { $env:deviceType } else { 'Desktop' }),
    [string]$AssetNumber = $env:assetNumber,
    [PSCredential]$Credential,
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath '..\config\sites.sample.json')
)

try {
    if ([string]::IsNullOrWhiteSpace($SiteName) -or [string]::IsNullOrWhiteSpace($AssetNumber)) {
        throw 'SiteName and AssetNumber are required.'
    }

    if (-not (Test-Path -Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $site = $config.sites.$SiteName
    if (-not $site) {
        throw "Site '$SiteName' not found in $ConfigPath."
    }

    $devCode = if ($DeviceType -eq 'Laptop') { 'L' } else { 'D' }
    $targetName = "$($site.code)-$devCode-$AssetNumber".ToUpper()
    $currentName = $env:COMPUTERNAME

    if ($currentName -eq $targetName) {
        Write-Output "Device is already named '$targetName'. No changes required."
        exit 0
    }

    if (-not $Credential) {
        $Credential = Get-Credential -Message "Enter domain credentials authorized to rename $currentName to $targetName"
    }

    if ($PSCmdlet.ShouldProcess($currentName, "Rename computer to $targetName")) {
        Write-Output 'Clearing cached SMB sessions before rename...'
        cmd.exe /c 'net use * /delete /y' | Out-Null
        Start-Sleep -Seconds 2

        Rename-Computer -NewName $targetName -DomainCredential $Credential -Force -ErrorAction Stop
        Write-Output "Renamed '$currentName' to '$targetName'. Reboot required to complete domain update."
    }
}
catch {
    Write-Error "Computer rename failed: $_"
    exit 1
}
