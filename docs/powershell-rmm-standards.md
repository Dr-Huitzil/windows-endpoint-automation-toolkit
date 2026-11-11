# Enterprise PowerShell & RMM Automation Standards

Conventions enforced across all PowerShell automation scripts deployed via Remote Monitoring & Management (RMM) tooling.

---

## 1. Execution Context & Privileges
- Scripts deployed via RMM execute in the **64-bit PowerShell 5.1+ engine** under `NT AUTHORITY\SYSTEM` or elevated local Administrator (`#Requires -RunAsAdministrator`).
- Destructive scripts implement `[CmdletBinding(SupportsShouldProcess = $true)]` or explicit simulation flags so fleet changes can be dry-run validated (`-WhatIf`) before production rollout.

## 2. Explicit Error Signaling for RMM Alerting
- Wrap critical operations in `try { ... } catch { ... }` blocks and emit explicit non-zero exit codes (`exit 1`) on failure so RMM automation policies flag failed runs accurately.

## 3. Avoid PowerShell Aliases in Automation (REST API Pitfall)
- Never rely on interactive shell aliases inside automated scripts—most notably `curl`, which aliases to `Invoke-WebRequest` in Windows PowerShell 5.1.
- When querying REST APIs (such as **Cisco Meraki Dashboard API v1**) from Windows PowerShell, either use native `Invoke-RestMethod` or call `curl.exe` explicitly so HTTP headers (`Authorization: Bearer <token>`) are not split and parsed as hostnames.

## 4. Prevent SMB Double-Hop Failures
- When executing MSI/EXE installers hosted on network shares under `SYSTEM` or remote sessions, stage the installer package locally (`C:\Temp\...`) before launching `msiexec.exe` / `Start-Process` to avoid Kerberos double-hop delegation failures.

## 5. Zero Hardcoded Credentials
- Never embed domain admin credentials, API keys, or Base64 passwords in source control. Pass secrets at runtime via RMM secure variables, encrypted credential stores, or `PSCredential` parameters.
