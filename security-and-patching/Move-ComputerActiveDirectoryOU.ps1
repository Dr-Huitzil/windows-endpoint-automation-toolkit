<#
.SYNOPSIS
    Locates the local domain-joined computer object via ADSI and moves it to a target Active Directory OU.

.DESCRIPTION
    Uses native ADSI searcher ([ADSISearcher]) to identify the local computer object in Active Directory
    without requiring RSAT or the ActiveDirectory PowerShell module installed on endpoints.
    Compares the current distinguished name against the target OU path, migrates the object if mismatched,
    and forces a Group Policy update.

.PARAMETER TargetOUPath
    Target Organizational Unit distinguished name.
    Defaults to $env:targetOUPath or a configurable baseline.

.EXAMPLE
    .\Move-ComputerActiveDirectoryOU.ps1 -TargetOUPath "OU=Laptops,OU=Endpoints,DC=corp,DC=example,DC=com"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Target Active Directory OU Distinguished Name")]
    [string]$TargetOUPath = $(if ($env:targetOUPath) { $env:targetOUPath } else { "OU=Laptops,OU=Workstations,DC=corp,DC=contoso,DC=local" })
)

Write-Host "Initiating Active Directory OU placement for endpoint: $env:COMPUTERNAME..." -ForegroundColor Cyan

try {
    # Native ADSI LDAP searcher (runs natively on any domain-joined Windows endpoint)
    $searcher = [ADSISearcher]"(sAMAccountName=$env:COMPUTERNAME`$)"
    $result = $searcher.FindOne()

    if (-not $result) {
        Write-Error "Could not locate '$env:COMPUTERNAME' in Active Directory domain. Verify domain membership."
        exit 1
    }

    $computerEntry = $result.GetDirectoryEntry()
    $currentPath = $computerEntry.Path

    Write-Host "Current AD Location: $currentPath" -ForegroundColor DarkGray
    Write-Host "Target OU Location : LDAP://$TargetOUPath" -ForegroundColor Cyan

    if ($currentPath -notmatch [regex]::Escape($TargetOUPath)) {
        if ($PSCmdlet.ShouldProcess("$env:COMPUTERNAME", "Move AD object to $TargetOUPath")) {
            Write-Host "Migrating $env:COMPUTERNAME to target OU: $TargetOUPath..." -ForegroundColor Yellow
            $targetOU = [ADSI]"LDAP://$TargetOUPath"
            $computerEntry.MoveTo($targetOU)
            Write-Host "[SUCCESS] $env:COMPUTERNAME successfully moved to target OU." -ForegroundColor Green
        }
    } else {
        Write-Host "[VERIFIED] $env:COMPUTERNAME is already in target OU. No movement required." -ForegroundColor Green
    }

    # Refresh Group Policy for new OU policies
    Write-Host "Triggering background Group Policy update..." -ForegroundColor Cyan
    & gpupdate.exe /force | Out-Null
    Write-Host "[SUCCESS] Group policy refresh complete." -ForegroundColor Green
    exit 0
}
catch {
    Write-Error "Active Directory OU migration failed: $_"
    exit 1
}
