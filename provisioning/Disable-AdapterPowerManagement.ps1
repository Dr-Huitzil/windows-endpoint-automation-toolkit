<#
.SYNOPSIS
    Disables OS selective power suspension on wireless network adapters.

.DESCRIPTION
    Identifies target network adapters (such as Realtek RTL8852BE Wi-Fi 6 chips) and disables
    power management sleep features that cause intermittent connection drops and roaming latency
    on modern enterprise endpoints.

.PARAMETER InterfacePattern
    Wildcard pattern matching the adapter description. Defaults to $env:interfacePattern or '*Realtek RTL8852BE*'.

.EXAMPLE
    .\Disable-AdapterPowerManagement.ps1 -InterfacePattern "*Realtek*"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Wildcard pattern for network adapter description")]
    [string]$InterfacePattern = $(if ($env:interfacePattern) { $env:interfacePattern } else { "*Realtek RTL8852BE*" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to modify network adapter power management."
    exit 1
}

$adapters = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like $InterfacePattern }

if (-not $adapters) {
    Write-Host "Target adapter matching '$InterfacePattern' not found on this system. No action needed." -ForegroundColor DarkGray
    exit 0
}

foreach ($adapter in $adapters) {
    Write-Host "Found adapter: $($adapter.Name) [$($adapter.InterfaceDescription)]" -ForegroundColor Cyan

    if ($PSCmdlet.ShouldProcess("$($adapter.Name)", "Disable Network Adapter Power Management")) {
        try {
            Disable-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction Stop
            Write-Host "[SUCCESS] Disabled power management for $($adapter.InterfaceDescription)." -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to disable power management on $($adapter.Name): $_"
        }
    }
}

exit 0
