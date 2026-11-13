<#
.SYNOPSIS
    Queries Windows System, Application, and PrintService event logs over a 7-day window to triage print subsystem failures.

.DESCRIPTION
    Correlates print spooler and driver errors across clinical endpoints by querying:
    1. System Log Event ID 7011 (Service timeout anomalies during spooler communication).
    2. Application Log Event ID 1002 (Application hang events triggered by stalled driver dialogs).
    3. Microsoft-Windows-PrintService/Admin Log (Level 2 Errors and Level 3 Warnings).

.PARAMETER DaysToLookBack
    Number of days of event history to inspect. Defaults to $env:daysToLookBack or 7.

.EXAMPLE
    .\Get-PrintSpoolerDiagnostic.ps1 -DaysToLookBack 14
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Days of event history to query")]
    [int]$DaysToLookBack = $(if ($env:daysToLookBack) { [int]$env:daysToLookBack } else { 7 })
)

$startDate = (Get-Date).AddDays(-$DaysToLookBack)

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "PRINT SUBSYSTEM 7-DAY EVENT LOG DIAGNOSTIC (Since: $startDate)" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan

# 1. System Log: Service Timeouts (Event ID 7011)
Write-Host "`n1. SYSTEM LOG: Service Timeout Events (Event ID 7011)" -ForegroundColor Yellow
$timeoutEvents = Get-WinEvent -FilterHashtable @{LogName='System'; Id=7011; StartTime=$startDate} -ErrorAction SilentlyContinue |
                 Where-Object { $_.Message -like "*spooler*" -or $_.Message -like "*print*" }

if ($timeoutEvents) {
    $timeoutEvents | Select-Object TimeCreated, Id, Message | Format-Table -AutoSize -Wrap
} else {
    Write-Host "No print-related service timeout events recorded." -ForegroundColor DarkGray
}

# 2. Application Log: App Hangs (Event ID 1002)
Write-Host "`n2. APPLICATION LOG: Application Hang Events (Event ID 1002)" -ForegroundColor Yellow
$hangEvents = Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1002; StartTime=$startDate} -ErrorAction SilentlyContinue |
              Where-Object { $_.Message -like "*splwow64*" -or $_.Message -like "*print*" }

if ($hangEvents) {
    $hangEvents | Select-Object TimeCreated, Message | Format-Table -AutoSize -Wrap
} else {
    Write-Host "No print-related application hang events recorded." -ForegroundColor DarkGray
}

# 3. Microsoft-Windows-PrintService/Admin: Errors & Warnings
Write-Host "`n3. PRINTSERVICE ADMIN LOG: Driver Errors & Port Faults (Level 2 & 3)" -ForegroundColor Yellow
$printServiceEvents = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PrintService/Admin'; Level=2,3; StartTime=$startDate} -ErrorAction SilentlyContinue

if ($printServiceEvents) {
    $printServiceEvents | Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-Table -AutoSize -Wrap
} else {
    Write-Host "No PrintService Admin error or warning events recorded." -ForegroundColor DarkGray
}

Write-Host "`n[DIAGNOSTIC COMPLETE]" -ForegroundColor Green
exit 0
