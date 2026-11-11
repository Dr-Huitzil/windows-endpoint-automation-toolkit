# Root-Cause Analysis: Dual-WAN Failover Failure During Carrier NTU Outages

Generalized architectural analysis and field triage guide for enterprise hub-and-spoke networks experiencing failover stalls when a primary managed fiber circuit degrades at the carrier Network Termination Unit (NTU).

---

## Problem Statement

In dual-WAN firewall deployments (primary dedicated fiber MIS via carrier NTU + secondary broadband failover circuit), carrier NTU processor lockups or upstream optical drops can leave the firewall's physical Ethernet link electrically **Up**, preventing automated failover from triggering and dropping branch site connectivity.

---

## Root Causes Identified

1. **Physical Link-State Monitoring vs. Logical Health Probes:**
   - If the firewall WAN health monitor tracks only physical Ethernet link state (`UP/DOWN`) rather than active ICMP/TCP reachability probes (`1.1.1.1`, `8.8.8.8`, upstream next-hop), a frozen carrier NTU keeps the link electrically up while silently black-holing packets.
2. **Stateful NAT / Session Pinning Drops:**
   - Hosted RDS/EHR sessions maintain stateful TCP flows bound to the primary WAN public IP. Even after failover activates, existing flows drop abruptly when outbound NAT shifts to the secondary WAN IP.
3. **Overlay / MPLS Circuit Asymmetry:**
   - Private carrier Ethernet meshes (e.g., branch circuits terminating back at HQ) cannot traverse a standalone secondary commercial broadband circuit unless backup IPsec tunnels or SD-WAN overlays are provisioned per branch site.

---

## Field Triage & Recovery Workflow

1. **Physical NTU Inspection (MDF):** Verify power, `OPTICAL / FIBER` signal LEDs (solid vs. blinking/unlit fiber cut), and `ETH / LINE` link status to the firewall WAN port.
2. **Firewall Console Manual Override:** Connect locally to the management interface, inspect WAN Load Balancing (WLB) group health, and manually promote the secondary interface if the primary circuit is silently dropping packets.
3. **Carrier Escalation & Offline Continuity:** Escalate with circuit ID and NTU serial for optical diagnostics while triggering site downtime/cellular hotspot contingency procedures.

---

## Preventive Engineering Recommendations

- Switch firewall WLB failover triggers from **Physical Link State** to **Logical Probes** (multi-target ICMP/TCP probes every 5s with 3 retries).
- Deploy IPsec backup tunnels or SD-WAN overlays across branch edge routers so branch-to-HQ traffic survives primary private-circuit outages.
