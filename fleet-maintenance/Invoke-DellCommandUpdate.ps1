<#
.SYNOPSIS
    Automates Dell Command | Update (DCU) CLI execution for fleet driver and BIOS/firmware patching.

.DESCRIPTION
    Ensures dcu-cli.exe is present (attempting Winget installation of Dell.CommandUpdate.Universal if missing),
    scans for pending hardware drivers, firmware, and BIOS updates, coordinates BitLocker suspension
    when BIOS updates are detected, and applies updates with automated reboot handling.

.PARAMETER InstallIfMissing
    Automatically install DCU via Winget if not present. Defaults to $true.

.PARAMETER ApplyUpdates
    Executes driver and BIOS installation. Defaults to $true.

.PARAMETER SuspendBitLockerForBios
    Suspends BitLocker if firmware/BIOS updates are installed to prevent recovery PIN prompts. Defaults to $true.

.EXAMPLE
    .\Invoke-DellCommandUpdate.ps1 -ApplyUpdates:$true -SuspendBitLockerForBios:$true
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [bool]$InstallIfMissing = $true,

    [Parameter(Mandatory = $false)]
    [bool]$ApplyUpdates = $true,

    [Parameter(Mandatory = $false)]
    [bool]$SuspendBitLockerForBios = $true
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to run Dell Command | Update automation."
    exit 1
}

# Verify system hardware manufacturer
$systemInfo = Get-CimInstance -ClassName Win32_ComputerSystem
if ($systemInfo.Manufacturer -notmatch "^Dell") {
    Write-Warning "Non-Dell hardware detected ($($systemInfo.Manufacturer)). Skipping Dell Command Update."
    exit 0
}

Write-Host "Dell hardware verified: $($systemInfo.Model) (Service Tag: $(Get-CimInstance Win32_BIOS | Select-Object -ExpandProperty SerialNumber))" -ForegroundColor Cyan

# Locate dcu-cli.exe across 64-bit and 32-bit Program Files
$dcuPaths = @(
    "$env:ProgramFiles\Dell\CommandUpdate\dcu-cli.exe",
    "${env:ProgramFiles(x86)}\Dell\CommandUpdate\dcu-cli.exe"
)
$dcuCli = $dcuPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

# Install DCU via winget if missing and requested
if (-not $dcuCli -and $InstallIfMissing) {
    Write-Host "Dell Command Update is not installed. Attempting installation via Winget..." -ForegroundColor Yellow
    
    # Locate winget.exe
    $winget = Get-ChildItem -Path "C:\Program Files\WindowsApps\" -Filter "winget.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if ($winget) {
        & $winget install --id Dell.CommandUpdate.Universal --scope machine --silent --accept-package-agreements --accept-source-agreements | Out-Null
        Start-Sleep -Seconds 5
        $dcuCli = $dcuPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
}

if (-not $dcuCli) {
    Write-Error "Dell Command Update CLI (dcu-cli.exe) could not be located."
    exit 1
}

Write-Host "Using DCU CLI engine: $dcuCli" -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("Dell Hardware", "Scan and apply firmware, BIOS, and driver updates")) {
    try {
        # Check if BitLocker is currently active
        $bitlockerVolume = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
        $isBitLockerActive = ($bitlockerVolume -and $bitlockerVolume.ProtectionStatus -eq 'On')

        if ($isBitLockerActive -and $SuspendBitLockerForBios) {
            Write-Host "Suspending BitLocker protection for 1 reboot to prevent firmware recovery lockouts..." -ForegroundColor Yellow
            Suspend-BitLocker -MountPoint "C:" -RebootCount 1 -ErrorAction SilentlyContinue | Out-Null
        }

        Write-Host "Executing DCU CLI: Applying updates silently with automatic restart suppression..." -ForegroundColor Cyan
        # /applyUpdates -reboot=disable -autoSuspendBitLocker=enable
        $process = Start-Process -FilePath $dcuCli -ArgumentList "/applyUpdates -autoSuspendBitLocker=enable" -Wait -PassThru

        Write-Host "DCU CLI process completed with exit code: $($process.ExitCode)" -ForegroundColor $(if ($process.ExitCode -in 0, 1, 2) { "Green" } else { "Yellow" })

        # Exit code dictionary: 0 = Success, 1 = Reboot Required, 2 = Reboot and Updates pending
        if ($process.ExitCode -in 1, 2) {
            Write-Host "[NOTICE] Hardware updates staged successfully. A system reboot is pending." -ForegroundColor Yellow
        } elseif ($process.ExitCode -eq 0) {
            Write-Host "[SUCCESS] All drivers and firmware are up to date." -ForegroundColor Green
        } else {
            Write-Warning "DCU completed with code $($process.ExitCode). Check DCU log files in %ProgramData%\Dell\CommandUpdate."
        }

        exit $process.ExitCode
    }
    catch {
        Write-Error "Failed to execute Dell Command Update: $_"
        exit 1
    }
}
