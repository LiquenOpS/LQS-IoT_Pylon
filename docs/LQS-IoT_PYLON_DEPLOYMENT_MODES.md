# Pylon Deployment Modes (North / South Split)

**Scope**: How to run Pylon in different network zones. North (Orion + Mongo) vs South (IOTA) can run on the same host (full-stack) or split across VLANs.

---

## 1. Modes Overview

| Mode | Compose | Services | Typical Location |
|------|---------|----------|------------------|
| **North** | docker-compose.north.yml | Orion, MongoDB | Intranet VLAN |
| **South** | docker-compose.south.yml | IoT Agent | IoT VLAN |
| **Full-stack** | north + south | All of the above | Single host (test/dev) |

**Rationale**: In production, Orion and MongoDB stay in Intranet; IOTA runs in IoT VLAN where devices can reach it. In test/dev, run full-stack on one host.

---

## 2. Setup and Run

```bash
# Setup: choose what to run on this host
./setup.sh   # option 1 → n) North / s) South / f) Full-stack

# Run (or use systemd)
./run.sh north
./run.sh south
./run.sh full   # default when PYLON_MODE=full
```

---

## 3. Split Deployment (North and South on Different Hosts)

**North host** (Intranet):
1. `./setup.sh` → Install essentials → **North**
2. Ensure Docker network exists (setup creates it)
3. North runs Orion + Mongo. MongoDB must be reachable from South (port 27017). Orion (1026) must be reachable for subscription registration.

**South host** (IoT VLAN):
1. Copy config; set `IOTA_CB_HOST` and `IOTA_MONGO_HOST` to North host IP/hostname
2. `./setup.sh` → Install essentials → **South**
3. Provision (service groups) runs on South host — POSTs to local IOTA

**Provision and subscription**:
- Provision: run on South host (POST to IOTA)
- Register subscription: run on North host (POST to Orion)

---

## 4. Config for Split

| Variable | North host | South host (split) |
|----------|------------|--------------------|
| IOTA_CB_HOST | orion (n/a) | North host IP |
| IOTA_MONGO_HOST | mongo-db (n/a) | North host IP |
| PYLON_MODE | north | south |

---

## 5. Network and Firewall

- IoT VLAN → Intranet: allow Orion (1026), MongoDB (27017)
- MongoDB on North: bind to interface reachable from South, or use tunnel
- Same Docker network name on both hosts if Odoo shares it; otherwise create network on each

---

## 6. Checklist for Split Deployment

- [ ] North host: `./setup.sh` → North; MongoDB listen on reachable interface
- [ ] South host: set `IOTA_CB_HOST`, `IOTA_MONGO_HOST` in config; `./setup.sh` → South
- [ ] Firewall: allow South → North on 1026, 27017
- [ ] Provision: run on South host after both are up
- [ ] Register subscription: run on North host
