# Pylon Deployment Modes (VLAN Split)

**Scope**: How to run Pylon in different network zones using Docker Compose profiles. Supports Intranet-only, IoT-only, and full-stack (test/dev).

---

## 1. Modes Overview

| Mode | Profile | Services | Typical Location |
|------|---------|----------|------------------|
| **Intranet** | `intranet` | Orion, MongoDB | Intranet VLAN |
| **IoT** | `iot` | IoT Agent, Discovery (future) | IoT VLAN |
| **Full-stack (test/dev)** | (none, or both) | All of the above | Single host |

**Rationale**: In production, Orion and MongoDB stay in Intranet; IOTA and discovery run in IoT VLAN where devices can reach them (or be discovered). In test/dev, everything runs together on one host for simplicity.

---

## 2. Profile Usage

```bash
# Intranet only (Orion + MongoDB)
docker compose --profile intranet up -d

# IoT only (IOTA + discovery) — IOTA needs Orion/Mongo reachable via config
docker compose --profile iot up -d

# Test/dev: all services
docker compose --profile intranet --profile iot up -d
# or: docker compose up -d   (if default is full-stack)
```

---

## 3. Network Flow (Split Deployment)

When split across VLANs:

- **Intranet host**: Orion, MongoDB. No direct device traffic.
- **IoT host**: IOTA, discovery. Devices talk to IOTA and discovery only.

IOTA on the IoT host must reach:
- Orion (Context Broker) — `IOTA_CB_HOST` → Intranet host IP/hostname
- MongoDB (device registry) — `IOTA_MONGO_HOST` → Intranet host IP/hostname

Ensure firewall/routing allows: IoT VLAN → Intranet VLAN on Orion port (1026) and MongoDB port (27017).

---

## 4. Concerns and Mitigations

| Concern | Mitigation |
|---------|------------|
| **Config per host** | Intranet host: Orion/Mongo use localhost/service names. IoT host: env overrides for `IOTA_CB_HOST`, `IOTA_MONGO_HOST` pointing to Intranet. |
| **MongoDB accessibility** | MongoDB on Intranet must listen on a reachable interface (or via tunnel). Restrict source IPs to IoT VLAN. |
| **Discovery placement** | Discovery service goes in `iot` profile (device-facing). |
| **Test/dev parity** | Full-stack mode uses internal hostnames (`orion`, `mongo-db`). Same compose file; profile selects services. |
| **Volume persistence** | MongoDB volume: when split, only Intranet host has it. IOTA has no persistent volume by default (device config in MongoDB). |

---

## 5. Recommended Profile Layout (Draft)

```
services:
  orion:
    profiles: [intranet]
    # ...

  mongo-db:
    profiles: [intranet]
    # ...

  iot-agent-json:
    profiles: [iot]
    depends_on: []   # when split, no container dependency; relies on network
    environment:
      - IOTA_CB_HOST=${IOTA_CB_HOST:-orion}      # override on IoT host
      - IOTA_MONGO_HOST=${IOTA_MONGO_HOST:-mongo-db}
    # ...

  # discovery:   # future
  #   profiles: [iot]
  #   ...
```

For full-stack (both profiles): `orion` and `mongo-db` exist, so `IOTA_CB_HOST=orion` and `IOTA_MONGO_HOST=mongo-db` work. For IoT-only: set `IOTA_CB_HOST` and `IOTA_MONGO_HOST` in config to the Intranet host.

---

## 6. Checklist for Split Deployment

- [ ] Intranet host: run with `--profile intranet`
- [ ] IoT host: set `IOTA_CB_HOST`, `IOTA_MONGO_HOST` in config; run with `--profile iot`
- [ ] Network: allow IoT → Intranet on Orion (1026) and MongoDB (27017)
- [ ] MongoDB: bind to interface reachable from IoT, or use appropriate network config
