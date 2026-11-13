<#
.SYNOPSIS
    Silently removes legacy dental sensor utilities and background tray connectors causing driver collisions.

.DESCRIPTION
    Silently uninstalls obsolete or conflicting vendor utilities (such as DEXIS Connect) via its MSI Product Code GUID.
    Prevents background sensor port lockouts, reduces startup RAM consumption, and resolves driver conflicts
    with primary digital acquisition suites (such as XVWeb and Apteryx).

.PARAMETER ProductGuid
    Target MSI Product Code GUID. Defaults to $env:targetProductGuid or standard legacy utility GUID.

.EXAMPLE
    .\Uninstall-LegacySensorUtility.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "MSI Product Code GUID")]
    [string]$ProductGuid = $(if ($env:targetProductGuid) { $env:targetProductGuid } else { "{F0DB8348-DE5F-4065-BBC0-07DAF3718B68}" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to uninstall system utilities."
    exit 1
}

Write-Host "Initiating silent removal of legacy sensor utility (GUID: $ProductGuid)..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("$ProductGuid", "Execute silent msiexec uninstallation")) {
    try {
        $msiArgs = "/x `"$ProductGuid`" /qn /norestart"
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru

        # 0 = Success, 1605 = Action valid only for currently installed products (already gone)
        if ($process.ExitCode -in 0, 1605) {
            Write-Host "[SUCCESS] Legacy sensor utility removed successfully (Exit code: $($process.ExitCode))." -ForegroundColor Green
            exit 0
        } else {
            Write-Warning "Uninstaller exited with code: $($process.ExitCode)"
            exit $process.ExitCode
        }
    }
    catch {
        Write-Error "Failed to uninstall legacy sensor utility: $_"
        exit 1
    }
}
