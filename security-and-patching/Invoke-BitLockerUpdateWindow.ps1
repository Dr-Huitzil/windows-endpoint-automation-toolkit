<#
.SYNOPSIS
    Suspends BitLocker prior to BIOS/firmware updates and resumes protection post-update.

.DESCRIPTION
    Evaluates Win32_SystemEnclosure chassis codes to target portable devices only. In PreUpdate mode,
    verifies AC power connectivity and suspends BitLocker for a configurable reboot count. In PostUpdate
    mode, resumes suspended BitLocker protection immediately.

.PARAMETER Phase
    Execution phase: 'PreUpdate' or 'PostUpdate'.

.PARAMETER MountPoint
    Target OS volume (default: 'C:').

.PARAMETER RebootCount
    Number of reboots for PreUpdate suspension (1-15, default: 5).

.EXAMPLE
    .\Invoke-BitLockerUpdateWindow.ps1 -Phase PreUpdate -RebootCount 5

.EXAMPLE
    .\Invoke-BitLockerUpdateWindow.ps1 -Phase PostUpdate
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('PreUpdate', 'PostUpdate')]
    [string]$Phase,
    [string]$MountPoint = 'C:',
    [ValidateRange(1, 15)]
    [int]$RebootCount = 5
)

function Test-IsPortableChassis {
    $portableCodes = @(8, 9, 10, 11, 12, 14, 18, 21, 31, 32)
    $chassis = Get-CimInstance -ClassName Win32_SystemEnclosure
    foreach ($code in $chassis.ChassisTypes) {
        if ($portableCodes -contains $code) {
            return $true
        }
    }
    return $false
}

try {
    if (-not (Test-IsPortableChassis)) {
        Write-Output 'Non-portable desktop chassis detected. Bypassing BitLocker update window.'
        exit 0
    }

    $bitLocker = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction SilentlyContinue
    if ($null -eq $bitLocker) {
        Write-Output "BitLocker volume not configured on $MountPoint."
        exit 0
    }

    if ($Phase -eq 'PreUpdate') {
        Add-Type -AssemblyName System.Windows.Forms
        if ([System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus -ne 'Online') {
            throw 'Laptop is on battery power. Aborting update window to prevent mid-flash power loss.'
        }

        if ($bitLocker.ProtectionStatus -eq 'Off') {
            Write-Output 'BitLocker is already suspended or disabled.'
            exit 0
        }

        if ($PSCmdlet.ShouldProcess($MountPoint, "Suspend BitLocker for $RebootCount reboots")) {
            Suspend-BitLocker -MountPoint $MountPoint -RebootCount $RebootCount -ErrorAction Stop | Out-Null
            $verify = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction SilentlyContinue
            if ($verify.ProtectionStatus -ne 'Off') {
                throw 'Failed to verify BitLocker suspension; aborting firmware/OS update.'
            }
            Write-Output "BitLocker suspended on $MountPoint for $RebootCount reboots."
        }
    }
    else {
        if ($bitLocker.ProtectionStatus -eq 'Off') {
            if ($PSCmdlet.ShouldProcess($MountPoint, 'Resume BitLocker protection')) {
                Resume-BitLocker -MountPoint $MountPoint -ErrorAction Stop | Out-Null
                Write-Output "BitLocker protection resumed on $MountPoint."
            }
        }
        else {
            Write-Output "BitLocker is already active on $MountPoint."
        }
    }
}
catch {
    Write-Error "BitLocker update window ($Phase) failed: $_"
    exit 1
}
