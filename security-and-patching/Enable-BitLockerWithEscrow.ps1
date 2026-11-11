<#
.SYNOPSIS
    Enables BitLocker TPM+PIN encryption after safely backing up and archiving the recovery key.

.DESCRIPTION
    Verifies access to a secure key escrow share, generates a recovery password protector,
    archives any existing recovery key for the device serial number with a timestamp, writes
    the active recovery key to the escrow share, strips conflicting TPM protectors, and activates
    BitLocker with TPM+PIN protection.

.PARAMETER KeyBackupPath
    UNC or local path where recovery keys are escrowed by device serial number.

.PARAMETER Pin
    SecureString pre-boot PIN for BitLocker TPM+PIN protection.

.PARAMETER DriveLetter
    Target OS volume mount point (default: 'C:').

.EXAMPLE
    $pin = Read-Host -Prompt "Enter BitLocker PIN" -AsSecureString
    .\Enable-BitLockerWithEscrow.ps1 -KeyBackupPath "\\fileserver\BitLockerKeys$" -Pin $pin
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$KeyBackupPath,
    [Parameter(Mandatory = $true)]
    [SecureString]$Pin,
    [string]$DriveLetter = 'C:'
)

try {
    Write-Output '0. Running pre-flight checks...'
    if (-not (Test-Path -Path $KeyBackupPath)) {
        throw "Cannot access key backup path: $KeyBackupPath"
    }

    Write-Output '1. Generating and escrowing recovery password...'
    Add-BitLockerKeyProtector -MountPoint $DriveLetter -RecoveryPasswordProtector -ErrorAction SilentlyContinue | Out-Null

    $recoveryKey = (Get-BitLockerVolume -MountPoint $DriveLetter).KeyProtector |
        Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' } |
        Select-Object -ExpandProperty RecoveryPassword -First 1

    if ([string]::IsNullOrWhiteSpace($recoveryKey)) {
        throw 'Failed to generate or retrieve a BitLocker recovery password.'
    }

    $serialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber.Trim()
    $backupFile = Join-Path -Path $KeyBackupPath -ChildPath "$serialNumber.txt"

    if ((Test-Path -Path $backupFile) -and $PSCmdlet.ShouldProcess($backupFile, 'Archive existing recovery key')) {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $archiveName = "${serialNumber}_bak_${timestamp}.txt"
        Rename-Item -Path $backupFile -NewName $archiveName -ErrorAction Stop
        Write-Output "Archived previous key to $archiveName"
    }

    if ($PSCmdlet.ShouldProcess($backupFile, 'Write active BitLocker recovery key')) {
        $recoveryKey | Out-File -FilePath $backupFile -ErrorAction Stop
        Write-Output "Escrowed recovery key to $backupFile"
    }

    Write-Output '2. Clearing conflicting TPM protectors...'
    $tpmProtectors = (Get-BitLockerVolume -MountPoint $DriveLetter).KeyProtector |
        Where-Object { $_.KeyProtectorType -match 'Tpm' }

    foreach ($protector in $tpmProtectors) {
        if ($PSCmdlet.ShouldProcess($protector.KeyProtectorId, 'Remove conflicting TPM protector')) {
            Remove-BitLockerKeyProtector -MountPoint $DriveLetter -KeyProtectorId $protector.KeyProtectorId -ErrorAction SilentlyContinue | Out-Null
        }
    }

    Write-Output '3. Enabling TPM+PIN BitLocker protection...'
    if ($PSCmdlet.ShouldProcess($DriveLetter, 'Enable-BitLocker (TpmAndPinProtector)')) {
        Enable-BitLocker -MountPoint $DriveLetter -Pin $Pin -TpmAndPinProtector -SkipHardwareTest -ErrorAction Stop | Out-Null
        Write-Output "BitLocker protection enabled on $DriveLetter."
    }
}
catch {
    Write-Error "BitLocker provisioning failed: $_"
    exit 1
}
