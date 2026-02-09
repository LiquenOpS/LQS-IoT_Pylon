# LQS-IoT Provisioning Guide (Intent-Only, RESTful)

**Scope**: How to provision the FIWARE stack and devices in alignment with [Intent-Only Best Practices](./LQS-IoT_INTENT_ONLY_BEST_PRACTICES.md). (Pylon = Orion + IoT Agent + MongoDB.)

"Provisioning" here follows FIWARE terminology: creating service groups and registering devices with the IoT Agent.

---

## 1. Three Distinct Provision Operations

| # | Operation | Example | What changes |
|---|-----------|---------|--------------|
| **1** | **New device type** | Adding Yardmaster from scratch (never existed) | Service group + provision template (commands, attributes) |
| **2** | **Existing type + new features** | Yardmaster gains lipstick machine support (same Yardmaster, new capability) | Provision template only; re-provision instances |
| **3** | **New device instance** | Adding another physical Glimmer+Yardmaster unit | New device_id, endpoint; same type and template |

**Discovery** (planned, not yet implemented): applies to (3). See [§6 Discovery Plan](#6-discovery-plan-planned).

---

## 2. User Entry Points (No Direct `ops/` Execution)

Users only run `./setup.sh` or `./run.sh` at the repo root. `ops/` scripts are internal. `setup.sh` is interactive — choose **Install essentials**, **Provision**, or **Install systemd** as needed. Run Install essentials first; edit config; then Provision.

**Config and prompts**:
- `config.example/` holds templates with sensible defaults. `setup.sh` copies to `config/` if missing.
- Pylon: user may edit `config/config.env` (ports, Odoo host). Provision reads from config; no extra prompts.
- Yardmaster: setup prompts for `DEVICE_ID`, `DEVICE_NAME`, capabilities (Signage/Anthias, LED-strip/Glimmer — Yardmaster-internal). `config/config.env` needs `IOTA_HOST`, `YARDMASTER_HOST`, `YARDMASTER_PORT`, `API_KEY` (must match Pylon service group: `YardmasterKey`). Example defaults: `IOTA_HOST=localhost`, `YARDMASTER_HOST=host.docker.internal`, `YARDMASTER_PORT=8080`.

**Pylon only knows Yardmaster**: The FIWARE entity type is always Yardmaster. Signage, LED-strip, Glimmer, Anthias are capabilities below Yardmaster; Pylon does not model them.

---

## 3. Fresh Deployment: From Zero to First Device

For a brand-new deployment, the flow is 1 → 2 (if needed) → 3:

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Platform up                                                   │
│    Pylon: ./setup.sh  (stack + service groups + subscription)    │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. (1) New device type: Yardmaster                               │
│    - Service group in provision_service_group.sh (in Pylon)      │
│    - Provision template in ops/provision_device.sh (in Yardmaster)│
│    Already done by setup if type exists in codebase.             │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. (2) If type evolves before first instance: update template    │
│    e.g. Yardmaster + lipstick machine — add to provision payload │
│    (For initial deploy, template has Yardmaster commands for LED-strip + Signage)   │
└─────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. (3) First device instance                                     │
│    Yardmaster: ./setup.sh on this machine                        │
│    Prompts: Device ID, Device Name. Edit config for IOTA_HOST,   │
│    YARDMASTER_HOST (this unit's reachable address).              │
└─────────────────────────────────────────────────────────────────┘
```

**Concrete steps (fresh deploy)**:

1. Pylon: `./setup.sh` → **Install essentials**. Edit config when prompted. Then → **Provision**.
2. Yardmaster (first unit): `./setup.sh` → **Install essentials**. Answer prompts; ensure `config/config.env` has correct `IOTA_HOST`, `YARDMASTER_HOST`. Then → **Provision**.

---

## 4. Operation Details

### 4.1 (1) New Device Type

**Example**: Yardmaster did not exist; now we add it.

| Step | Action | Where |
|------|--------|-------|
| 1 | Add service group for entity_type (e.g. Yardmaster) | Pylon `ops/provision_service_group.sh` |
| 2 | Create provision script with commands and attributes for this type | Device repo `ops/provision_device.sh` |
| 3 | Pylon: `./setup.sh` → **Provision** | Pylon |
| 4 | (Optional) Run Yardmaster setup for first instance — see (3) | Device repo |

### 4.2 (2) Existing Type + New Features

**Example**: Yardmaster already exists; we add lipstick machine support.

| Step | Action | Where |
|------|--------|-------|
| 1 | Extend Yardmaster app: new handler, commands, attributes | LQS-IoT_Yardmaster |
| 2 | Update provision payload: add new commands/attrs | `ops/provision_device.sh` |
| 3 | On each Yardmaster unit: `./setup.sh` → **Provision** | Yardmaster repo (per instance) |

No change to Pylon service groups. Only IOTA device registration is updated.

### 4.3 (3) New Device Instance

**Example**: Another physical Yardmaster+Glimmer unit. Same type, same features.

Adding a new instance requires two steps; each step has two possible methods:

| Step | Purpose | Method A | Method B |
|------|---------|----------|----------|
| **1** | Obtain device endpoint | **Discovery**: device registers with Discovery service | **Run script**: manually set config (YARDMASTER_HOST, PORT, etc.) |
| **2** | Execute provision (POST to IOTA) | **Adopt in Odoo**: click Adopt in Fleet; backend calls provision API | **Run script**: `./setup.sh` → **Provision** |

Both steps are required. Typical combinations: (Discovery + Adopt) for full automation; (Run script + Run script) for manual; (Discovery + Run script) if Discovery exists but Adopt not yet wired.

**Manual (current)** — both steps via script:
| Step | Action |
|------|--------|
| 1 | On the new unit: `./setup.sh` → **Install essentials**. |
| 2 | When prompted: enter new `DEVICE_ID`, `DEVICE_NAME` (different from existing units). |
| 3 | Ensure `config/config.env` has correct `YARDMASTER_HOST` (this machine's reachable address) and `YARDMASTER_PORT`. |
| 4 | `./setup.sh` → **Provision**. |

**Discovery + Adopt (planned)**: Step 1 via Discovery; Step 2 via Adopt in Odoo. See [§6](#6-discovery-plan-planned).

---

## 5. Background: apikey and Provision Flow

**apikey**: Routing key in FIWARE IoT Agent. The Yardmaster service group uses `YardmasterKey`. Yardmaster config must use the same apikey. Device and service group must match.

**Admin-run, not self-registration**: The device does not contact IOTA to register. `setup.sh` (or its internal `ops/` scripts) reads config (IOTA location + device endpoint) and POSTs to IOTA. Endpoint flows: device config → provision script → IOTA (MongoDB).

---

## 6. Discovery Plan (Planned)

Discovery applies to operation (3) — adding new device instances. Per the 2x2 in [§4.3](#43-3-new-device-instance): Discovery covers Step 1 (obtain endpoint); Adopt in Odoo covers Step 2 (execute provision). Goal: UniFi-style "plug in, go to Odoo Fleet, click Adopt."

**Planned flow** (Discovery + Adopt):
1. Device (Yardmaster) boots and registers with a Discovery service: "I'm device X, my endpoint is http://…".
2. Discovery service (runs in IoT VLAN per [Deployment Modes](./LQS-IoT_PYLON_DEPLOYMENT_MODES.md)) stores pending devices.
3. Odoo Fleet queries Discovery, shows "pending" devices.
4. User clicks **Adopt** → backend triggers provision with the discovered endpoint.
5. Device is now provisioned; IOTA can push commands to it.

**Options for discovery** (to be decided):
- **Discovery API**: Device POSTs to a known URL (configurable per deployment). Simple; requires device to know Discovery URL.
- **mDNS / DNS-SD**: Device advertises; scanner (on IoT VLAN) discovers. Same-LAN only.
- **MQTT**: Device publishes to broker; Odoo/Discovery subscribes. Works across networks if broker is reachable.

**Constraints**: IOTA must be able to reach the device endpoint for downlink. If device is behind NAT, consider MQTT transport (device subscribes) or device-initiated tunnel (e.g. Cloudflare Tunnel).

**Status**: Not implemented. Manual provision via `./setup.sh` is the current path.

---

## 7. Handling an Already-Running Pylon (Operations 1–3)

### 7.1 (1) Add New Device Type

1. Edit `ops/provision_service_group.sh`; add new service to payload.
2. Pylon: `./setup.sh` → **Provision**.
3. Create provision script in new device repo; add `./setup.sh` entry point.

### 7.2 (2) Update Existing Type (New Features)

1. Update device provision script (new commands/attributes).
2. On each Yardmaster unit: `./setup.sh` → **Provision**. No Pylon restart.

### 7.3 (3) Add New Instance

1. On the new unit: `./setup.sh` → **Install essentials** then **Provision**, with new DEVICE_ID, DEVICE_NAME, correct YARDMASTER_HOST.
2. No Pylon change.

### 7.4 Change Device Endpoint

1. Update device config (e.g. `YARDMASTER_PORT`, host).
2. Restart device process: `./run.sh`.
3. `./setup.sh` → **Provision** so IOTA has the new endpoint.

### 7.5 Remove Device or Service Group

- Device: `DELETE /iot/devices/{deviceId}` (if supported) or manual MongoDB.
- Service group: Depends on IoT Agent; some support DELETE.

---

## 8. Declarative and Idempotent Provision

- **Service groups**: Payload = full desired set. Re-run = idempotent.
- **Devices**: Payload = full desired device config. Re-run = update or create. Document IoT Agent behaviour (POST update vs conflict).

---

## 9. RESTful API Summary (FIWARE IoT Agent North)

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/iot/services` | Create/update service groups |
| GET | `/iot/services` | List service groups |
| POST | `/iot/devices` | Register device (create or overwrite, agent-dependent) |
| PATCH | `/iot/devices/{id}` | Update device (if supported) |
| GET | `/iot/devices` | List devices |
| DELETE | `/iot/devices/{id}` | Remove device (if supported) |

All require FIWARE service and servicepath headers.

---

## 10. Checklist Summary

| Operation | User action |
|-----------|-------------|
| (1) New type | Edit ops; Pylon `./setup.sh` → **Provision**; add device repo setup |
| (2) Type + features | Edit provision payload; `./setup.sh` → **Provision** on each unit |
| (3) New instance | `./setup.sh` → **Install essentials** then **Provision** on new unit (manual). Later: Discovery + Adopt (planned) |
