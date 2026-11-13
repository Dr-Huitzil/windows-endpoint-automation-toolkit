<#
.SYNOPSIS
    Validates PowerShell script syntax across the repository using the .NET Abstract Syntax Tree (AST) parser.

.DESCRIPTION
    Scans PowerShell (.ps1) files and parses their Abstract Syntax Tree (AST) to detect syntax errors,
    unmatched braces, invalid keywords, and grammar issues prior to production RMM policy deployment.

.PARAMETER TargetPath
    Root directory to scan. Defaults to repository root.

.EXAMPLE
    .\Test-ScriptSyntaxAST.ps1 -TargetPath "..\provisioning"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Root path to validate")]
    [string]$TargetPath = "$PSScriptRoot\.."
)

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "POWERSHELL ABSTRACT SYNTAX TREE (AST) SYNTAX VALIDATOR" -ForegroundColor Cyan
Write-Host "Target Root: $(Resolve-Path $TargetPath)" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan

$scripts = Get-ChildItem -Path $TargetPath -Filter "*.ps1" -Recurse -File

if (-not $scripts) {
    Write-Warning "No .ps1 script files found in target path."
    exit 0
}

$hasErrors = $false
$totalValidated = 0
$failedCount = 0

foreach ($script in $scripts) {
    $totalValidated++
    $content = Get-Content -Path $script.FullName -Raw

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$tokens, [ref]$errors)

    if ($errors -and $errors.Count -gt 0) {
        $hasErrors = $true
        $failedCount++
        Write-Host "[FAIL] $($script.FullName)" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "  -> Line $($err.Extent.StartLineNumber), Col $($err.Extent.StartColumnNumber): $($err.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[PASS] $($script.Name)" -ForegroundColor Green
    }
}

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "AST VALIDATION COMPLETE: $totalValidated Total Scripts | $failedCount Failed" -ForegroundColor $(if ($hasErrors) { "Red" } else { "Green" })
Write-Host "====================================================================" -ForegroundColor Cyan

if ($hasErrors) {
    exit 1
} else {
    exit 0
}
