<#
.SYNOPSIS
    Remotely extracts interactive user PrintTicketXML printer configurations via WinRM, bypassing Session 0 isolation.

.DESCRIPTION
    In Windows, interactive printer tray mappings, form selections, and paper routing reside within
    the logged-on user's profile and cannot be queried directly from Session 0 (SYSTEM).
    This script connects to a remote computer via WinRM, determines the active interactive user,
    registers a temporary scheduled task that executes Get-PrintConfiguration under that user's token,
    exports the XML ticket, transfers it back over the network, and cleans up the temporary artifacts.

.PARAMETER ComputerName
    The target remote hostname or IP. Defaults to $env:targetComputerName.

.PARAMETER PrinterName
    The exact name of the installed printer queue. Defaults to $env:targetPrinterName.

.PARAMETER ExportDirectory
    Local administrative destination folder for the XML configuration. Defaults to '.\Exports\Printers'.

.EXAMPLE
    .\Export-RemotePrinterConfigurationXml.ps1 -ComputerName "CLINIC-PC-01" -PrinterName "RX_Receipt_Printer"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Target remote computer name")]
    [string]$ComputerName = $env:targetComputerName,

    [Parameter(Mandatory = $false, HelpMessage = "Target printer queue name")]
    [string]$PrinterName = $env:targetPrinterName,

    [Parameter(Mandatory = $false, HelpMessage = "Destination export directory")]
    [string]$ExportDirectory = $(if ($env:printerExportDir) { $env:printerExportDir } else { ".\Exports\Printers" })
)

if ([string]::IsNullOrWhiteSpace($ComputerName)) {
    $ComputerName = Read-Host "Enter the remote hostname"
}

if ([string]::IsNullOrWhiteSpace($PrinterName)) {
    $PrinterName = Read-Host "Enter the exact printer queue name"
}

if (-not (Test-Path $ExportDirectory)) {
    New-Item -ItemType Directory -Path $ExportDirectory -Force | Out-Null
}

$destinationFile = Join-Path -Path $ExportDirectory -ChildPath "${ComputerName}_$($PrinterName -replace '\W', '_')_Config.xml"

Write-Host "Connecting to remote computer: $ComputerName via WinRM..." -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("$ComputerName", "Export PrintTicketXML for '$PrinterName'")) {
    try {
        $xmlContent = Invoke-Command -ComputerName $ComputerName -ArgumentList @($PrinterName) -ScriptBlock {
            param($Printer)

            # Identify the currently logged-on interactive user
            $loggedOnUser = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName
            if (-not $loggedOnUser) {
                throw "No active interactive user is currently logged into $env:COMPUTERNAME."
            }

            $guid = [guid]::NewGuid().ToString()
            $taskName = "ExportPrinterXML_$guid"
            $tempFile = "$env:PUBLIC\Documents\PrinterConfig_$guid.xml"

            # Register temporary scheduled task to run in the interactive user's security context
            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command `"Get-PrintConfiguration -PrinterName '$Printer' | Select-Object -ExpandProperty PrintTicketXML | Out-File -FilePath '$tempFile' -Encoding UTF8 -Force`""
            $principal = New-ScheduledTaskPrincipal -UserId $loggedOnUser -LogonType Interactive -RunLevel Highest

            Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal | Out-Null
            Start-ScheduledTask -TaskName $taskName | Out-Null

            # Poll for file creation
            $timeoutSeconds = 15
            $timer = [System.Diagnostics.Stopwatch]::StartNew()
            while (-not (Test-Path $tempFile) -and ($timer.Elapsed.TotalSeconds -lt $timeoutSeconds)) {
                Start-Sleep -Milliseconds 500
            }
            $timer.Stop()

            $capturedXml = $null
            if (Test-Path $tempFile) {
                $capturedXml = Get-Content -Path $tempFile -Raw
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            }

            # Unregister temporary scheduled task
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

            return $capturedXml
        }

        if (-not [string]::IsNullOrWhiteSpace($xmlContent)) {
            Set-Content -Path $destinationFile -Value $xmlContent -Encoding UTF8 -Force
            Write-Host "[SUCCESS] Print configuration XML captured and saved to: $destinationFile" -ForegroundColor Green
            exit 0
        } else {
            Write-Error "Failed to retrieve printer XML configuration from $ComputerName."
            exit 1
        }
    }
    catch {
        Write-Error "Printer configuration export failed: $_"
        exit 1
    }
}
