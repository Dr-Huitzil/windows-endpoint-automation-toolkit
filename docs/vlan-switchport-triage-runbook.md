# Runbook: Layer 1/Layer 2 VLAN Switchport Mismatch Triage

Standardized field diagnostic workflow for resolving endpoint connectivity failures caused by switchport VLAN misconfigurations (e.g., moving a segmented network printer onto an unconfigured wall jack).

---

## Diagnostic Signature

- Endpoint NIC and wall jack display **active physical Ethernet link lights**.
- Device fails to pull DHCP from the expected subnet, drops all ICMP pings, and shows offline in print/management servers.
- Typical root cause: the physical wall drop is patched into an access switchport broadcasting the default corporate VLAN rather than the segmented device VLAN (e.g., `VLAN 200` for print infrastructure).

---

## Step-by-Step Triage

1. **Logical Port Trace (SNMP Monitoring):**
   - Query the network monitoring platform (e.g., Auvik / switch MAC table) to map the device MAC address to its exact switch and interface ID.
2. **Physical Cable Verification (MDF Toning):**
   - When an endpoint fails to register a MAC address upstream, attach a **tone generator** to the wall jack and trace the drop inside the MDF patch panel to document the exact patch port and switchport number.
3. **VLAN Re-Assignment & Boundary Handoff:**
   - Escalate verified `<Switch> / <Port> -> Target VLAN` mapping to network administration (maintaining least-privilege RBAC separation between field operations and switch configuration).
4. **Client Policy & Queue Refresh:**
   - Once the switchport VLAN is updated and the device receives a valid lease, trigger `gpupdate` (and purge stale cached client drivers if applicable) across affected workstations.
