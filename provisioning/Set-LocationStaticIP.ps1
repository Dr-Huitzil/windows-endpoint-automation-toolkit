<#
.SYNOPSIS
    Assigns a site-specific static IPv4 address, default gateway, and DNS servers.

.DESCRIPTION
    Reads subnet/gateway mappings from a JSON site configuration file (supporting RMM environment
    variables or explicit CLI parameters). Aborts immediately if an active Wi-Fi adapter is up to
    prevent dual-homing routing conflicts.

.PARAMETER SiteName
    Site key defined inside the configuration file (falls back to $env:location).

.PARAMETER HostOctet
    Final IPv4 host octet (1-254) (falls back to $env:octet).

.PARAMETER ConfigPath
    Path to the JSON site subnet configuration file.

.EXAMPLE
    .\Set-LocationStaticIP.ps1 -SiteName "Site-North" -HostOctet 45 -ConfigPath "..\config\sites.sample.json"
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SiteName = $env:location,
    [ValidateRange(1, 254)]
    [int]$HostOctet = $(if ($env:octet) { [int]$env:octet } else { 0 }),
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath '..\config\sites.sample.json')
)

try {
    if ([string]::IsNullOrWhiteSpace($SiteName) -or $HostOctet -lt 1 -or $HostOctet -gt 254) {
        throw 'SiteName and a valid HostOctet (1-254) are required.'
    }

    if (-not (Test-Path -Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    # Prevent asymmetric routing / dual-homing when Wi-Fi is active
    $wifiActive = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -like '*Wi-Fi*' }
    if ($wifiActive) {
        Write-Warning "Active Wi-Fi adapter detected ($($wifiActive.Name)). Aborting static Ethernet assignment to prevent dual-homing."
        exit 1
    }

    $ethernet = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.Name -like '*Ethernet*' } | Select-Object -First 1
    if (-not $ethernet) {
        throw 'No active Ethernet adapter detected.'
    }

    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $site = $config.sites.$SiteName
    if (-not $site) {
        throw "Site '$SiteName' not found in $ConfigPath."
    }

    $ipAddress = "$($site.subnetPrefix)$HostOctet"
    $gateway = $site.gateway
    $prefixLength = [int]$config.prefixLength
    $dnsServers = @($config.dnsServers)

    if ($PSCmdlet.ShouldProcess($ethernet.Name, "Assign static IP $ipAddress/$prefixLength gw $gateway")) {
        $ethernet | Remove-NetIPAddress -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        Get-NetRoute -InterfaceIndex $ethernet.InterfaceIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
            Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

        New-NetIPAddress -InterfaceAlias $ethernet.Name -IPAddress $ipAddress -PrefixLength $prefixLength -AddressFamily IPv4 -ErrorAction Stop | Out-Null
        New-NetRoute -InterfaceAlias $ethernet.Name -DestinationPrefix '0.0.0.0/0' -NextHop $gateway -ErrorAction Stop | Out-Null
        $ethernet | Set-DnsClientServerAddress -ServerAddresses $dnsServers -ErrorAction Stop

        Write-Output "Configured $($ethernet.Name): $ipAddress/$prefixLength (GW: $gateway, DNS: $($dnsServers -join ', '))"
    }
}
catch {
    Write-Error "Static IP configuration failed: $_"
    exit 1
}
