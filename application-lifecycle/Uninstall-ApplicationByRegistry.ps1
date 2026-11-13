<#
.SYNOPSIS
    Discovers installed software in 64-bit and 32-bit registry hives and invokes automated silent removal.

.DESCRIPTION
    Dynamically scans HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall and WOW6432Node
    for applications matching a specified name pattern. Evaluates whether the product is an MSI GUID
    or an executable uninstaller, synthesizes silent flags, executes removal, and logs transcripts.

.PARAMETER AppNameMatch
    Target software display name wildcard. Defaults to $env:appNameMatch or 'TSPrint'.

.EXAMPLE
    .\Uninstall-ApplicationByRegistry.ps1 -AppNameMatch "TSPrint"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Application display name pattern to match")]
    [string]$AppNameMatch = $(if ($env:appNameMatch) { $env:appNameMatch } else { "TSPrint" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to uninstall system software."
    exit 1
}

$logFile = "$env:SystemRoot\Temp\Uninstall_$($AppNameMatch -replace '\W', '_').log"
Write-Host "Scanning 64-bit and 32-bit registry uninstall hives for: '$AppNameMatch'..." -ForegroundColor Cyan

$regHives = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$matchingApps = Get-ItemProperty -Path $regHives -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$AppNameMatch*" }

if (-not $matchingApps) {
    Write-Host "[VERIFIED] No installed application matching '$AppNameMatch' found in registry hives." -ForegroundColor Green
    exit 0
}

foreach ($app in $matchingApps) {
    Write-Host "Discovered: $($app.DisplayName) [Version: $($app.DisplayVersion)]" -ForegroundColor Yellow

    if ($PSCmdlet.ShouldProcess("$($app.DisplayName)", "Execute silent uninstallation")) {
        try {
            $uninstallString = $app.UninstallString
            $guidMatch = [regex]::Match($app.PSChildName, '^{[A-F0-9-]{36}}$')

            if ($guidMatch.Success) {
                # Product is an MSI GUID
                $guid = $guidMatch.Value
                Write-Host "Invoking msiexec silent uninstallation for GUID: $guid..." -ForegroundColor Cyan
                $msiArgs = "/x `"$guid`" /qn /norestart /L*v `"$logFile`""
                $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
            } elseif (-not [string]::IsNullOrWhiteSpace($uninstallString)) {
                # Executable uninstaller
                Write-Host "Invoking executable uninstaller string: $uninstallString..." -ForegroundColor Cyan
                if ($uninstallString -match 'msiexec') {
                    $cleanArgs = ($uninstallString -replace 'msiexec\.exe', '') + " /qn /norestart"
                    $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList $cleanArgs -Wait -PassThru
                } else {
                    # Generic silent flags for InnoSetup, NSIS, or InstallShield
                    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$uninstallString`" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /S /q" -Wait -PassThru
                }
            }

            Write-Host "Uninstaller process exited with code: $($proc.ExitCode)" -ForegroundColor $(if ($proc.ExitCode -in 0, 3010) { "Green" } else { "Yellow" })
        }
        catch {
            Write-Error "Failed to uninstall $($app.DisplayName): $_"
        }
    }
}

exit 0
