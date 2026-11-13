<#
.SYNOPSIS
    Toggles the operational state (Enable or Disable) of the Wi-Fi network interface.

.DESCRIPTION
    Allows technicians and scheduled policies to programmatically disable wireless networking
    on docked clinical workstations to prevent dual-homing routing loops, or re-enable Wi-Fi
    on mobile laptops via NinjaOne pop-up parameters or CLI arguments.

.PARAMETER State
    Target adapter state: 'Disable' or 'Enable'. Defaults to $env:adapterState or 'Disable'.

.PARAMETER InterfaceName
    Name pattern for the wireless adapter. Defaults to $env:wifiInterfaceName or 'Wi-Fi'.

.EXAMPLE
    .\Switch-WiFiAdapterState.ps1 -State Disable
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Desired adapter state ('Disable' or 'Enable')")]
    [ValidateSet("Disable", "Enable")]
    [string]$State = $(if ($env:adapterState) { $env:adapterState } else { "Disable" }),

    [Parameter(Mandatory = $false, HelpMessage = "Interface name pattern")]
    [string]$InterfaceName = $(if ($env:wifiInterfaceName) { $env:wifiInterfaceName } else { "Wi-Fi" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to toggle network adapter state."
    exit 1
}

$adapter = Get-NetAdapter -Name $InterfaceName -ErrorAction SilentlyContinue

if (-not $adapter) {
    # Fallback search by description
    $adapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*Wireless*' -or $_.InterfaceDescription -like '*Wi-Fi*' } | Select-Object -First 1
}

if (-not $adapter) {
    Write-Warning "No wireless network adapter matching '$InterfaceName' was found on this system."
    exit 0
}

Write-Host "Found target wireless adapter: $($adapter.Name) [$($adapter.InterfaceDescription)] (Current Status: $($adapter.Status))" -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("$($adapter.Name)", "Switch state to '$State'")) {
    try {
        if ($State -eq "Disable") {
            Disable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            Write-Host "[SUCCESS] Adapter '$($adapter.Name)' has been disabled." -ForegroundColor Green
        } else {
            Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            Write-Host "[SUCCESS] Adapter '$($adapter.Name)' has been enabled." -ForegroundColor Green
        }
        exit 0
    }
    catch {
        Write-Error "Failed to change network adapter state: $_"
        exit 1
    }
}
