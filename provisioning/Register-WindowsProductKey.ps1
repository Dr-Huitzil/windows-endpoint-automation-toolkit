<#
.SYNOPSIS
    Queries the motherboard ACPI table in UEFI for the embedded OEM Windows product key and activates the OS.

.DESCRIPTION
    Automates Windows OEM activation during thin-image provisioning. Extracts the embedded
    OA3xOriginalProductKey from firmware, registers it via slmgr.vbs /ipk, and triggers
    online activation via slmgr.vbs /ato without requiring manual key entry or KMS host binding.

.PARAMETER ProductKey
    Optional manual product key override. Defaults to $env:productKey or firmware ACPI embedded key.

.EXAMPLE
    .\Register-WindowsProductKey.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Manual product key override")]
    [string]$ProductKey = $env:productKey
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to register product keys and activate Windows."
    exit 1
}

# If no manual key supplied, query the motherboard firmware ACPI table
if ([string]::IsNullOrWhiteSpace($ProductKey)) {
    Write-Host "Querying UEFI/BIOS firmware ACPI table for embedded OEM product key..." -ForegroundColor Cyan
    try {
        $licenseObj = Get-CimInstance -ClassName SoftwareLicensingService -ErrorAction Stop
        $ProductKey = $licenseObj.OA3xOriginalProductKey
    }
    catch {
        Write-Warning "Could not query SoftwareLicensingService: $_"
    }
}

if ([string]::IsNullOrWhiteSpace($ProductKey)) {
    Write-Warning "No embedded OEM product key found in BIOS/UEFI firmware and no manual key supplied. Aborting."
    exit 0
}

# Mask key for secure logging
$maskedKey = "XXXXX-XXXXX-XXXXX-XXXXX-" + $ProductKey.Substring($ProductKey.Length - 5)
Write-Host "Product key detected: $maskedKey. Installing license key..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("Local Computer", "Install key $maskedKey and activate online")) {
    try {
        # /ipk installs the product key
        $ipkOutput = & cscript.exe //nologo "$env:SystemRoot\system32\slmgr.vbs" /ipk $ProductKey
        Write-Host "Key registration output: $ipkOutput" -ForegroundColor DarkGray

        Write-Host "Initiating online activation check..." -ForegroundColor Cyan
        # /ato forces online activation against Microsoft licensing servers
        $atoOutput = & cscript.exe //nologo "$env:SystemRoot\system32\slmgr.vbs" /ato
        Write-Host "Activation check output: $atoOutput" -ForegroundColor Green

        Write-Host "[SUCCESS] Windows activation sequence completed." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error "Failed to install product key or activate Windows: $_"
        exit 1
    }
}
