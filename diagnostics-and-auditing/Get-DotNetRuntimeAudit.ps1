<#
.SYNOPSIS
    Scans program directories for runtimeconfig.json files to discover application .NET Core / Desktop dependencies.

.DESCRIPTION
    Audits installed applications in C:\Program Files and C:\Program Files (x86) for runtimeconfig.json files
    to identify software dependencies on Microsoft .NET Core / .NET Desktop Runtime (e.g., .NET 6, 7, 8).
    This audit prevents failed deployments and update loops for tools requiring modern .NET runtimes.

.PARAMETER SearchPaths
    Target directories to audit. Defaults to C:\Program Files and C:\Program Files (x86).

.EXAMPLE
    .\Get-DotNetRuntimeAudit.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$SearchPaths = @("C:\Program Files", "C:\Program Files (x86)")
)

Write-Host "Initiating .NET Desktop & Core runtime dependency audit across fleet directories..." -ForegroundColor Cyan

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($path in $SearchPaths) {
    if (Test-Path $path) {
        Write-Host "Scanning: $path..." -ForegroundColor DarkGray
        $configFiles = Get-ChildItem -Path $path -Filter "*.runtimeconfig.json" -Recurse -ErrorAction SilentlyContinue |
                       Where-Object { $_.FullName -notmatch "\\dotnet\\" }

        foreach ($file in $configFiles) {
            try {
                $rawContent = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
                $json = $rawContent | ConvertFrom-Json -ErrorAction Stop

                $frameworks = @()
                if ($json.runtimeOptions.framework) { $frameworks += $json.runtimeOptions.framework }
                if ($json.runtimeOptions.frameworks) { $frameworks += $json.runtimeOptions.frameworks }

                foreach ($fw in $frameworks) {
                    $results.Add([PSCustomObject]@{
                        Application = $file.Directory.Name
                        Framework   = $fw.name
                        Version     = $fw.version
                        ConfigPath  = $file.FullName
                    })
                }
            }
            catch {
                # Silently ignore unparseable or locked files
            }
        }
    }
}

if ($results.Count -eq 0) {
    Write-Host "[NOTICE] No external .NET runtime configuration files detected." -ForegroundColor Yellow
    exit 0
}

Write-Host "`n=== DETECTED APPLICATION .NET DEPENDENCIES ===" -ForegroundColor Green
$results | Sort-Object Application | Format-Table Application, Framework, Version, ConfigPath -AutoSize

Write-Host "`n=== SUMMARY BY FRAMEWORK VERSION ===" -ForegroundColor Cyan
$results | Group-Object Framework, Version | Select-Object Name, Count | Format-Table -AutoSize

exit 0
