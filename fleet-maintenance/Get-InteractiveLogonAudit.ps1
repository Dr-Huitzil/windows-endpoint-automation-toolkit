<#
.SYNOPSIS
    Audits recent interactive user logons from TerminalServices LocalSessionManager Event ID 21.

.DESCRIPTION
    Queries the quiet LocalSessionManager Operational log over a configurable lookback window,
    parses interactive user accounts, strips OS service identities, excludes specified service/admin
    accounts, and emits the latest logon timestamp per unique user.

.PARAMETER DaysBack
    Number of days to inspect (default: 30).

.PARAMETER ExcludedUsers
    Account names omitted from audit output.

.EXAMPLE
    .\Get-InteractiveLogonAudit.ps1 -DaysBack 30
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [ValidateRange(1, 365)]
    [int]$DaysBack = 30,
    [string[]]$ExcludedUsers = @('Administrator', 'localadmin')
)

try {
    $startTime = (Get-Date).AddDays(-$DaysBack)
    $events = Get-WinEvent -FilterHashtable @{
        LogName   = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'
        Id        = 21
        StartTime = $startTime
    } -ErrorAction SilentlyContinue

    $results = foreach ($event in $events) {
        $userLine = ($event.Message -split "`r`n") | Where-Object { $_ -match 'User:' } | Select-Object -First 1
        if (-not $userLine) { continue }

        $rawUser = ($userLine -split 'User:\s*')[1].Trim()
        $username = ($rawUser -split '\\')[-1]

        if ($username -notmatch 'SYSTEM|LOCAL SERVICE|NETWORK SERVICE|DWM-|UMFD-|ANONYMOUS' -and
            $ExcludedUsers -notcontains $username) {
            [PSCustomObject]@{
                Username  = $username
                LogonTime = $event.TimeCreated
                LogonType = 'Interactive'
            }
        }
    }

    if ($results) {
        $results |
            Group-Object Username |
            ForEach-Object { $_.Group | Sort-Object LogonTime -Descending | Select-Object -First 1 } |
            Sort-Object LogonTime -Descending
    }
    else {
        Write-Output "No interactive user logons found in the past $DaysBack days."
    }
}
catch {
    Write-Error "Logon audit failed: $_"
    exit 1
}
