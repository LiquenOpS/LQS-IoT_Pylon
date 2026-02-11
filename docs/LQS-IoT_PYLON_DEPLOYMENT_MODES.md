# Pylon Deployment Modes

**Scope**: Four deployment scenarios for Odoo + Pylon North + Pylon South. Pylon uses its own Docker network (`pylon-net`); no changes to Odoo compose required.

---

## 1. Four Scenarios

| # | Odoo | North | South | ODOO_HOST | IOTA_CB_HOST / IOTA_MONGO_HOST |
|---|------|-------|-------|-----------|---------------------------------|
| 1 | A | A | A | host.docker.internal | orion, mongo-db |
| 2 | A | A | B | host.docker.internal | North host IP |
| 3 | A | B | B | Odoo host IP | orion, mongo-db |
| 4 | A | B | C | Odoo host IP | North host IP |

Same letter = same host. All services run in Docker.

---

## 2. Same-Host Odoo: Why host.docker.internal?

When Odoo and Pylon are on the same host, Orion (in Docker) must reach Odoo (in Docker). We use the host's published port instead of a shared Docker network:

- Odoo publishes 8069 to the host
- Orion curls `host.docker.internal:8069` → host forwards to Odoo
- **No Odoo compose changes**. Pylon North adds `extra_hosts: host.docker.internal:host-gateway`

---

## 3. Linux and WSL2

| Platform | host.docker.internal |
|----------|----------------------|
| Docker Desktop (Mac/Windows) | Built-in |
| Linux (Docker 20.10+) | Via `extra_hosts: host-gateway` — Pylon North adds this |
| WSL2 + Docker in WSL2 | Same as Linux — works |
| WSL2 + Docker Desktop (WSL2 backend) | Built-in |

Pylon North compose includes `extra_hosts` so Orion can reach the host on all supported platforms.

---

## 4. Scenario Details

### Scenario 1: All on same host (A)

- ODOO_HOST=host.docker.internal
- IOTA_CB_HOST=orion, IOTA_MONGO_HOST=mongo-db
- Setup: Full-stack
- Pylon uses pylon-net. Odoo uses its own network. No shared network.

### Scenario 2: Odoo+North on A, South on B

- Host A: Odoo, North. ODOO_HOST=host.docker.internal
- Host B: South. IOTA_CB_HOST=A's IP, IOTA_MONGO_HOST=A's IP
- Firewall: B → A on 1026, 27017

### Scenario 3: Odoo on A, North+South on B

- Host A: Odoo
- Host B: North, South. ODOO_HOST=A's IP. IOTA_CB_HOST=orion, IOTA_MONGO_HOST=mongo-db
- Firewall: B → A on 8069 (if Odoo needs to be reached)

### Scenario 4: All separate (A, B, C)

- ODOO_HOST=A's IP
- IOTA_CB_HOST=B's IP, IOTA_MONGO_HOST=B's IP
- Firewall: C → B on 1026, 27017; B → A on 8069 as needed

---

## 5. Config Summary

| Variable | Scenario 1 | 2 | 3 | 4 |
|----------|------------|---|---|---|
| ODOO_HOST | host.docker.internal | host.docker.internal | A's IP | A's IP |
| IOTA_CB_HOST | orion | North IP | orion | North IP |
| IOTA_MONGO_HOST | mongo-db | North IP | mongo-db | North IP |

---

## 6. Checklist

- [ ] Set PYLON_MODE (north / south / full) in setup
- [ ] Set ODOO_HOST per scenario
- [ ] Set IOTA_CB_HOST, IOTA_MONGO_HOST when South is on a different host
- [ ] Provision: run on South host
- [ ] Register subscription: run on North host
