<#
.SYNOPSIS
    Configures or reverts Wake-on-LAN across both 802.3 NIC drivers and Dell UEFI/BIOS settings.

.DESCRIPTION
    Synchronizes OS-level Ethernet adapter wake settings (Magic Packet, Pattern Match, Energy
    Efficient Ethernet, Ultra Low Power Mode) with motherboard ACPI power settings using the
    official DellBIOSProvider PowerShell module.

.PARAMETER Mode
    Target configuration state: 'Enable' or 'Disable'.

.EXAMPLE
    .\Set-DellWakeOnLan.ps1 -Mode Enable

.EXAMPLE
    .\Set-DellWakeOnLan.ps1 -Mode Disable
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Enable', 'Disable')]
    [string]$Mode
)

try {
    $enable = $Mode -eq 'Enable'
    $wakeVal = if ($enable) { 'Enabled' } else { 'Disabled' }
    $ecoVal = if ($enable) { 'Disabled' } else { 'Enabled' }
    $biosWol = if ($enable) { 'LanOnly' } else { 'Disabled' }
    $deepSleep = if ($enable) { 'Disabled' } else { 'Enabled' }
    $blockSleep = if ($enable) { 'Enabled' } else { 'Disabled' }

    Write-Output "1. Applying '$Mode' settings to physical 802.3 NICs..."
    $adapters = Get-NetAdapter -Physical | Where-Object { $_.MediaType -eq '802.3' }

    foreach ($nic in $adapters) {
        if ($PSCmdlet.ShouldProcess($nic.Name, "Configure WoL ($Mode)")) {
            Set-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName 'Wake on Magic Packet' -DisplayValue $wakeVal -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName 'Wake on pattern match' -DisplayValue $wakeVal -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName 'Energy Efficient Ethernet' -DisplayValue $ecoVal -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName 'Energy Efficient Ethernet' -DisplayValue $(if ($enable) { 'Off' } else { 'On' }) -ErrorAction SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName 'Ultra Low Power Mode' -DisplayValue $ecoVal -ErrorAction SilentlyContinue

            if ($enable) {
                Set-NetAdapterPowerManagement -Name $nic.Name -WakeOnMagicPacket Enabled -ErrorAction SilentlyContinue
                Enable-NetAdapterPowerManagement -Name $nic.Name -ErrorAction SilentlyContinue
            }
            else {
                Set-NetAdapterPowerManagement -Name $nic.Name -WakeOnMagicPacket Disabled -ErrorAction SilentlyContinue
                Disable-NetAdapterPowerManagement -Name $nic.Name -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Output "2. Applying '$Mode' settings to Dell UEFI/BIOS via DellBIOSProvider..."
    if ($null -eq (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    }
    if ($null -eq (Get-Module -ListAvailable -Name DellBIOSProvider)) {
        Install-Module -Name DellBIOSProvider -Force -Scope AllUsers | Out-Null
    }

    Import-Module DellBIOSProvider -ErrorAction SilentlyContinue
    if (Test-Path -Path 'DellSmbios:\PowerManagement') {
        if ($PSCmdlet.ShouldProcess('DellSmbios:\PowerManagement', "Set WakeOnLan=$biosWol")) {
            Set-Item -Path 'DellSmbios:\PowerManagement\WakeOnLan' -Value $biosWol -ErrorAction Stop
            Set-Item -Path 'DellSmbios:\PowerManagement\DeepSleepControl' -Value $deepSleep -ErrorAction SilentlyContinue
            Set-Item -Path 'DellSmbios:\PowerManagement\BlockSleep' -Value $blockSleep -ErrorAction SilentlyContinue
            Write-Output "Dell BIOS Wake-on-LAN configured ($biosWol)."
        }
    }
    else {
        Write-Warning 'DellSmbios:\PowerManagement drive unavailable (non-Dell or unsupported firmware).'
    }
}
catch {
    Write-Error "Wake-on-LAN configuration failed: $_"
    exit 1
}
