<#
.SYNOPSIS
    Configures static IPv4 address, prefix length, gateway, and DNS servers on the active Ethernet adapter.

.DESCRIPTION
    Dynamically assigns static IP network properties supplied via NinjaOne environment variables
    or direct CLI parameters. Detects and aborts if an active Wi-Fi interface is detected to prevent
    dual-homed routing conflicts, flushes conflicting routes and existing IP addresses, and applies
    the new network baseline.

.PARAMETER IPAddress
    The static IPv4 address to assign. Defaults to $env:ipAddress.

.PARAMETER PrefixLength
    Subnet prefix length (e.g., 24 for 255.255.255.0). Defaults to $env:prefixLength or '24'.

.PARAMETER Gateway
    Default gateway IPv4 address. Defaults to $env:gateway.

.PARAMETER DNS1
    Primary DNS server address. Defaults to $env:dns1.

.PARAMETER DNS2
    Secondary DNS server address. Defaults to $env:dns2.

.EXAMPLE
    .\Set-EndpointStaticIP.ps1 -IPAddress "10.0.12.45" -PrefixLength 24 -Gateway "10.0.12.1" -DNS1 "10.0.50.10" -DNS2 "10.0.10.10"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Static IPv4 Address")]
    [string]$IPAddress = $env:ipAddress,

    [Parameter(Mandatory = $false, HelpMessage = "Subnet Prefix Length (e.g. 24)")]
    [string]$PrefixLength = $(if ($env:prefixLength) { $env:prefixLength } else { "24" }),

    [Parameter(Mandatory = $false, HelpMessage = "Default Gateway IPv4 Address")]
    [string]$Gateway = $env:gateway,

    [Parameter(Mandatory = $false, HelpMessage = "Primary DNS Server")]
    [string]$DNS1 = $env:dns1,

    [Parameter(Mandatory = $false, HelpMessage = "Secondary DNS Server")]
    [string]$DNS2 = $env:dns2
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to configure network interfaces."
    exit 1
}

# Validate required IP address
if ([string]::IsNullOrWhiteSpace($IPAddress)) {
    Write-Error "No IP address provided. Pass -IPAddress or populate `$env:ipAddress via NinjaOne."
    exit 1
}

# Step 1: Check for active Wi-Fi connections to prevent dual-homed conflicts
$wifiActive = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -like '*Wi-Fi*' }
if ($wifiActive) {
    Write-Warning "Active Wi-Fi connection detected on '$($wifiActive.Name)'. Script aborted to prevent dual-homing conflicts."
    exit 1
}

# Step 2: Identify primary active Ethernet adapter
$ethernet = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and ($_.Name -like '*Ethernet*' -or $_.InterfaceDescription -notlike '*Wi-Fi*') } | Select-Object -First 1
if (-not $ethernet) {
    Write-Error "No active Ethernet connection detected. Connect a wired network cable and retry."
    exit 1
}

Write-Host "Target Ethernet adapter found: $($ethernet.Name) [$($ethernet.InterfaceDescription)]" -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("$($ethernet.Name)", "Set Static IP $IPAddress/$PrefixLength, GW: $Gateway, DNS: $DNS1, $DNS2")) {
    try {
        Write-Host "Flushing existing IP addresses and default routes..." -ForegroundColor Yellow
        $ethernet | Remove-NetIPAddress -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        Get-NetRoute -InterfaceIndex $ethernet.InterfaceIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false

        Write-Host "Applying Static IPv4 address: $IPAddress/$PrefixLength with Gateway: $Gateway" -ForegroundColor Cyan
        if (-not [string]::IsNullOrWhiteSpace($Gateway)) {
            New-NetIPAddress -InterfaceIndex $ethernet.InterfaceIndex -IPAddress $IPAddress -PrefixLength ([int]$PrefixLength) -DefaultGateway $Gateway -AddressFamily IPv4 -ErrorAction Stop | Out-Null
        } else {
            New-NetIPAddress -InterfaceIndex $ethernet.InterfaceIndex -IPAddress $IPAddress -PrefixLength ([int]$PrefixLength) -AddressFamily IPv4 -ErrorAction Stop | Out-Null
        }

        # Apply DNS Configuration
        $dnsServers = @()
        if (-not [string]::IsNullOrWhiteSpace($DNS1)) { $dnsServers += $DNS1 }
        if (-not [string]::IsNullOrWhiteSpace($DNS2)) { $dnsServers += $DNS2 }

        if ($dnsServers.Count -gt 0) {
            Write-Host "Configuring DNS servers: $($dnsServers -join ', ')" -ForegroundColor Cyan
            Set-DnsClientServerAddress -InterfaceIndex $ethernet.InterfaceIndex -ServerAddresses $dnsServers -ErrorAction Stop
        }

        Write-Host "[SUCCESS] Static IP configuration successfully applied to $($ethernet.Name)." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error "Failed to apply static IP configuration: $_"
        exit 1
    }
}
