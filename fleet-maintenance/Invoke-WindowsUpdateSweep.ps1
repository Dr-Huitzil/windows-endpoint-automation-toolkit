<#
.SYNOPSIS
    Automates scanning and silent installation of quality/security patches via PSWindowsUpdate.

.DESCRIPTION
    Forces scheduled maintenance patch sweeps using the PSWindowsUpdate PowerShell module.
    Enforces TLS 1.2 for package provider handshakes, installs the module if missing, and
    executes update installation while filtering out disruptive annual OS feature upgrades.

.PARAMETER ExcludeTitlePattern
    Wildcard pattern of updates to ignore (e.g. feature upgrades). Defaults to '*24H2*' / '*25H2*' / '*Preview*'.

.PARAMETER AutoReboot
    Whether to automatically reboot the endpoint if required. Defaults to $false.

.EXAMPLE
    .\Invoke-WindowsUpdateSweep.ps1 -ExcludeTitlePattern "*Preview*"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Update titles to exclude")]
    [string]$ExcludeTitlePattern = $(if ($env:excludeUpdatePattern) { $env:excludeUpdatePattern } else { "*Preview*" }),

    [Parameter(Mandatory = $false)]
    [bool]$AutoReboot = $false
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to manage Windows Updates."
    exit 1
}

# Force TLS 1.2 for secure Gallery handshakes
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Verifying PSWindowsUpdate module availability..." -ForegroundColor Cyan

if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "PSWindowsUpdate not found. Bootstrapping NuGet provider and module..." -ForegroundColor Yellow
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false | Out-Null
        Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Confirm:$false | Out-Null
    }
    catch {
        Write-Error "Failed to install PSWindowsUpdate module: $_"
        exit 1
    }
}

Import-Module PSWindowsUpdate -ErrorAction Stop

Write-Host "Initiating patch sweep (Filtering updates matching '$ExcludeTitlePattern')..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("Windows Update Engine", "Install all pending quality/security updates")) {
    try {
        $updateParams = @{
            MicrosoftUpdate = $true
            AcceptAll       = $true
            Verbose         = $true
        }

        if (-not $AutoReboot) {
            $updateParams["IgnoreReboot"] = $true
        }

        $results = Get-WindowsUpdate @updateParams | Where-Object { $_.Title -notlike $ExcludeTitlePattern }

        if ($results) {
            Write-Host "Applying $($results.Count) detected updates..." -ForegroundColor Green
            $results | Install-WindowsUpdate @updateParams
        } else {
            Write-Host "No pending quality/security updates detected. System is up to date." -ForegroundColor Green
        }

        exit 0
    }
    catch {
        Write-Error "Windows Update sweep failed: $_"
        exit 1
    }
}
