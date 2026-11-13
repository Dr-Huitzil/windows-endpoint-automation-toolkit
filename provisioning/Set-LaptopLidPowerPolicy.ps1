<#
.SYNOPSIS
    Configures the laptop lid-close action power policy for docked operations.

.DESCRIPTION
    Modifies the active Windows power scheme to either keep the system awake ('DoNothing')
    or revert to standard sleep behavior ('Sleep') when the lid is closed, configuring both
    AC (plugged in) and DC (battery) power states via powercfg.

.PARAMETER Action
    The desired lid-close action: 'DoNothing' (0) or 'Sleep' (1).
    Defaults to $env:lidAction or 'DoNothing'.

.EXAMPLE
    .\Set-LaptopLidPowerPolicy.ps1 -Action DoNothing
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Desired lid close action (DoNothing or Sleep)")]
    [ValidateSet("DoNothing", "Sleep")]
    [string]$Action = $(if ($env:lidAction) { $env:lidAction } else { "DoNothing" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to modify system power configurations."
    exit 1
}

$settingValue = switch ($Action) {
    "DoNothing" { 0 }
    "Sleep"     { 1 }
}

Write-Host "Configuring active power plan lid-close action to: '$Action' (Value: $settingValue)..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("Active Power Scheme", "Set lid close action to $Action for AC and DC")) {
    try {
        # AC Power setting (plugged in)
        & powercfg /setacvalueindex scheme_current sub_buttons lidaction $settingValue
        # DC Power setting (on battery)
        & powercfg /setdcvalueindex scheme_current sub_buttons lidaction $settingValue

        # Apply changes immediately to active scheme
        & powercfg /setactive scheme_current

        Write-Host "[SUCCESS] Lid close action set to '$Action' for both AC and battery profiles." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error "Failed to update power scheme settings: $_"
        exit 1
    }
}
