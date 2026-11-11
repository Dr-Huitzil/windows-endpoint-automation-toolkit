# Object-Oriented Policy Inheritance Provisioning Architecture

Replacing monolithic golden disk images with a layered **Policy Inheritance Engine** keeps OS images thin while allowing automated, hardware-aware provisioning across diverse clinical and enterprise fleets.

---

## Provisioning Flow

```mermaid
flowchart TD
    A["PXE / Bootable USB Imaging<br/>(Windows 11 Golden WIM + AutoUnattend.xml)"] --> B["OOBE Bypass & Unattended Domain Join<br/>(2-Cycle Auto-Logon + Debloat)"]
    B --> C["RMM Staging Location<br/>(Inherits Universal Base Policy)"]
    C --> D{"Hardware Chassis / Role Routing"}
    D -->|"Desktop"| E["Desktop Policy<br/>Scanner Drivers, VDI Client, WoL"]
    D -->|"Laptop"| F["Mobile Policy<br/>Laptops OU Move, BitLocker TPM+PIN, Lid Power"]
    D -->|"Specialized Station"| G["Operatory / Cart Policy<br/>Static IP Injection, Wake-on-AC, Peripherals"]
    E --> H["Production Site Assignment<br/>&lt;SITE&gt;-&lt;DEV&gt;-&lt;ASSET&gt; Rename"]
    F --> H
    G --> H
```

---

## Key Architectural Principles

1. **Thin Golden Image + Dynamic Policy Layering:** Only core OS, storage controller validation (`NVMe / AHCI` rather than `RAID ON` during WinPE), and baseline runtime dependencies live inside the WIM. Role-specific drivers and software deploy dynamically from RMM policies.
2. **Two-Cycle Auto-Logon Window:** `AutoUnattend.xml` configures `LogonCount=2` so first-boot AppX debloating (`Invoke-WindowsDebloat.ps1`), OEM driver/BIOS pulls, and initial RMM payloads complete unattended before end-user handover.
3. **Staging-to-Production Separation:** Devices enroll into an isolated staging location during imaging, execute chassis-specific hardening (e.g., AD OU migration before BitLocker escrow), and are renamed/reassigned to their physical site (`<SITE>-<DEV>-<ASSET>`) at deployment.
4. **Automated Lifecycle Decommissioning:** Retired endpoints follow an explicit reverse pipeline—AD disable + `Decommissioned` OU move, RMM/EDR agent removal, multi-seat M365 license release, and physical SSD removal/destruction before e-waste disposal.
