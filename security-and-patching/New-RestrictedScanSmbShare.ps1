<#
.SYNOPSIS
    Creates and hardens a scan-to-desktop directory and SMB share without 'Everyone' access.

.DESCRIPTION
    Provisions a local Scans folder for an endpoint user, disables NTFS inheritance, transfers
    ownership to Domain Admins, grants explicit Modify permissions solely to the target user and
    a dedicated scanner service account, and recreates an SMB share restricted to those identities.

.PARAMETER Domain
    Active Directory domain NetBIOS or FQDN prefix (e.g., 'CORP').

.PARAMETER Username
    Target workstation user account (falls back to $env:adUsername).

.PARAMETER ScannerAccount
    Dedicated AD service account used by network MFPs for SMB transmission.

.PARAMETER ShareName
    Folder and SMB share name (default: 'Scans').

.EXAMPLE
    .\New-RestrictedScanSmbShare.ps1 -Domain "CORP" -Username "jdoe" -ScannerAccount "svc_scanner"
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Domain,
    [string]$Username = $env:adUsername,
    [string]$ScannerAccount = 'svc_scanner',
    [string]$DomainAdminGroup = 'Domain Admins',
    [string]$ShareName = 'Scans'
)

try {
    if ([string]::IsNullOrWhiteSpace($Username)) {
        throw 'Target Username is required (pass -Username or set $env:adUsername).'
    }

    $folderPath = "C:\Users\$Username\Desktop\$ShareName"

    if (-not (Test-Path -Path $folderPath)) {
        if ($PSCmdlet.ShouldProcess($folderPath, 'Create directory')) {
            New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
        }
    }

    if ($PSCmdlet.ShouldProcess($folderPath, 'Harden NTFS ACLs (disable inheritance, restrict principals)')) {
        $acl = Get-Acl -Path $folderPath
        $acl.SetAccessRuleProtection($true, $false)

        $owner = New-Object System.Security.Principal.NTAccount("$Domain\$DomainAdminGroup")
        $acl.SetOwner($owner)

        $inheritance = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
            [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
        $propagation = [System.Security.AccessControl.PropagationFlags]::None

        $rules = @(
            New-Object System.Security.AccessControl.FileSystemAccessRule("$Domain\$DomainAdminGroup", 'FullControl', $inheritance, $propagation, 'Allow')
            New-Object System.Security.AccessControl.FileSystemAccessRule("$Domain\$Username", 'Modify', $inheritance, $propagation, 'Allow')
            New-Object System.Security.AccessControl.FileSystemAccessRule("$Domain\$ScannerAccount", 'Modify', $inheritance, $propagation, 'Allow')
        )

        foreach ($rule in $rules) {
            $acl.AddAccessRule($rule)
        }

        Set-Acl -Path $folderPath -AclObject $acl -ErrorAction Stop
        Write-Output "Applied restricted NTFS ACLs to $folderPath."
    }

    if ($PSCmdlet.ShouldProcess($ShareName, 'Recreate restricted SMB share')) {
        if (Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue) {
            Remove-SmbShare -Name $ShareName -Force -ErrorAction Stop
        }

        New-SmbShare -Name $ShareName `
            -Path $folderPath `
            -FullAccess "$Domain\$DomainAdminGroup" `
            -ChangeAccess "$Domain\$Username", "$Domain\$ScannerAccount" `
            -ErrorAction Stop | Out-Null

        Write-Output "Created hardened SMB share '$ShareName' -> $folderPath."
    }
}
catch {
    Write-Error "Scan SMB share provisioning failed: $_"
    exit 1
}
