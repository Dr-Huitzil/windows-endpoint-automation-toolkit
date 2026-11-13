<#
.SYNOPSIS
    Provisions a standardized Windows Internet Shortcut (.url) on the Public Desktop for all users.

.DESCRIPTION
    Creates an enterprise URL shortcut accessible to every user signing into the endpoint.
    Used for standardized clinical portals, web EHR links, and compliance training portals.

.PARAMETER ShortcutName
    Name of the shortcut without extension. Defaults to $env:shortcutName or 'Enterprise Portal'.

.PARAMETER TargetUrl
    Destination web URL. Defaults to $env:targetUrl or 'https://portal.example.com'.

.PARAMETER DestinationPath
    Directory where the shortcut is created. Defaults to $env:destinationPath or the Public Desktop.

.EXAMPLE
    .\New-PublicDesktopShortcut.ps1 -ShortcutName "Staff Portal" -TargetUrl "https://staff.contoso.com"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Name of the shortcut")]
    [string]$ShortcutName = $(if ($env:shortcutName) { $env:shortcutName } else { "Enterprise Portal" }),

    [Parameter(Mandatory = $false, HelpMessage = "Destination URL")]
    [string]$TargetUrl = $(if ($env:targetUrl) { $env:targetUrl } else { "https://portal.example.com" }),

    [Parameter(Mandatory = $false, HelpMessage = "Destination folder path")]
    [string]$DestinationPath = $(if ($env:destinationPath) { $env:destinationPath } else { "$env:PUBLIC\Desktop" })
)

# Enforce Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Administrator privileges are required to write to the Public Desktop."
    exit 1
}

$shortcutFile = Join-Path -Path $DestinationPath -ChildPath "$ShortcutName.url"

$shortcutContent = @"
[InternetShortcut]
URL=$TargetUrl
"@

Write-Host "Configuring desktop shortcut '$ShortcutName' -> $TargetUrl at $shortcutFile" -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess("$shortcutFile", "Create Internet Shortcut to $TargetUrl")) {
    try {
        if (-not (Test-Path $DestinationPath)) {
            New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        }
        Set-Content -Path $shortcutFile -Value $shortcutContent -Encoding ASCII -Force
        Write-Host "[SUCCESS] Shortcut created successfully at $shortcutFile." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error "Failed to create internet shortcut: $_"
        exit 1
    }
}
