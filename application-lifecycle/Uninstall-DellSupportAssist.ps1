<#
.SYNOPSIS
    Systematically removes all variants of Dell SupportAssist, background agent services, and UWP AppX packages.

.DESCRIPTION
    Comprehensive enterprise deprovisioning script for Dell SupportAssist across clinical workstations.
    SupportAssist is decommissioned fleet-wide to remediate recurring critical CVE vulnerabilities,
    reduce background CPU/RAM consumption, and eliminate update conflicts with Dell Command | Update.
    Terminates conflicting background processes, invokes MSI quiet uninstalls for both business and client
    editions, removes OS recovery plugins, and deregisters modern UWP AppX packages.

.EXAMPLE
    .\Uninstall-DellSupportAssist.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to uninstall Dell SupportAssist."
    exit 1
}

Write-Host "Initiating fleet uninstallation for Dell SupportAssist components..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("Local System", "Terminate SupportAssist processes and purge all software packages")) {
    # Step 1: Force terminate conflicting background processes
    $processesToKill = @(
        "SupportAssistAgent",
        "SupportAssistAppWire",
        "SupportAssistClientUI",
        "SupportAssistHardwareDiags",
        "DellSupportAssistRemediationService"
    )

    Write-Host "Stage 1: Terminating conflicting SupportAssist background processes..." -ForegroundColor Yellow
    foreach ($procName in $processesToKill) {
        $found = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($found) {
            Write-Host "Killing process: $procName (PID: $($found.Id -join ', '))" -ForegroundColor DarkGray
            Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
        }
    }

    # Step 2: Remove modern UWP AppX packages
    Write-Host "Stage 2: Purging provisioned and per-user Dell SupportAssist AppX packages..." -ForegroundColor Yellow
    $appxPackages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*DellSupportAssist*" }
    foreach ($pkg in $appxPackages) {
        Write-Host "Removing AppX package: $($pkg.PackageFullName)" -ForegroundColor DarkGray
        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
    }

    $provisionedAppx = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*DellSupportAssist*" }
    foreach ($provPkg in $provisionedAppx) {
        Write-Host "Removing Provisioned AppX: $($provPkg.DisplayName)" -ForegroundColor DarkGray
        Remove-AppxProvisionedPackage -Online -PackageName $provPkg.PackageName -ErrorAction SilentlyContinue | Out-Null
    }

    # Step 3: Discover and uninstall Win32 / MSI programs via registry
    Write-Host "Stage 3: Discovering and uninstalling Dell SupportAssist Win32 applications..." -ForegroundColor Yellow
    $regHives = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $supportAssistApps = Get-ItemProperty -Path $regHives -ErrorAction SilentlyContinue | Where-Object { 
        $_.DisplayName -like "*Dell SupportAssist*" -or $_.DisplayName -like "*Dell Update / SupportAssist*"
    }

    foreach ($app in $supportAssistApps) {
        Write-Host "Uninstalling Win32 component: $($app.DisplayName)..." -ForegroundColor Cyan
        $guidMatch = [regex]::Match($app.PSChildName, '^{[A-F0-9-]{36}}$')

        if ($guidMatch.Success) {
            $guid = $guidMatch.Value
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/x `"$guid`" /qn /norestart" -Wait -PassThru | Out-Null
        } elseif (-not [string]::IsNullOrWhiteSpace($app.UninstallString)) {
            $cleanCmd = $app.UninstallString -replace 'msiexec\.exe', ''
            if ($app.UninstallString -match 'msiexec') {
                Start-Process -FilePath "msiexec.exe" -ArgumentList "$cleanCmd /qn /norestart" -Wait -PassThru | Out-Null
            } else {
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$($app.UninstallString)`" /s /q /quiet /norestart" -Wait -PassThru | Out-Null
            }
        }
    }

    Write-Host "[SUCCESS] Dell SupportAssist decommission sequence complete." -ForegroundColor Green
    exit 0
}
