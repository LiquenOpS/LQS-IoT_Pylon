## LQS-IoT_Pylon

LQS-IoT_Pylon is the "steel pylon" of factory digitalisation—a lightweight infrastructure component library built for Industrial IoT (IIoT). It simplifies the FIWARE ecosystem into modular Docker components that act as the data hub (Context Broker) between field devices (PLCs, access control, sensors) and upper-layer applications (ERP, digital signage, WebApp).

### Features

- **Component-based design**: One service per folder; pick only the modules you need for POC or production.
- **Digital Twin**: FIWARE Orion at the core for standardised device state modelling and real-time sync.
- **Deployment-friendly**: Run `./setup.sh` once; use `./run.sh` to start/restart the stack.
- **Extensible**: Structure is ready for future additions (MQTT, Node-RED, time-series DB).

### Layout

```txt
LQS-IoT_Pylon/
├── docker-compose.north.yml  # Orion + MongoDB (Intranet)
├── docker-compose.south.yml  # IoT Agent (device-facing)
│
├── components/               # Core components (one service per folder)
│   ├── orion/                # FIWARE Orion Context Broker
│   ├── iota-json/            # IoT Agent for JSON (device ingress/egress)
│   └── mongodb/              # MongoDB for Orion and IoT Agent
│
├── config.example/
│   └── config.env
├── setup.sh                  # Install North / South / Full-stack
├── run.sh                    # Start stack (north | south | full)
├── ops/
│   ├── stop.sh               # Stop stack (reads PYLON_MODE)
│   ├── backup_db.sh
│   ├── provision_service_group.sh
│   ├── register_subscription.sh
│   └── systemd/pylon.service
├── debug/
│   ├── logs.sh               # View logs (use --env-file, no "variable not set" warnings)
│   └── menu.sh               # Interactive: list, delete, send command (all-in-one)
│
└── README.md
```

### Quick start

1. **Run setup** (one-time)
   ```bash
   ./setup.sh
   ```
   Choose: North / South / Full-stack. This creates config, network, starts stack.

2. **Start/restart**
   ```bash
   ./run.sh [--mode north|south|full]   # default: PYLON_MODE from config
   ```

3. **Check services**
   ```bash
   docker ps
   curl "http://localhost:1026/version"        # Orion
   curl "http://localhost:4041/iot/about"     # IoT Agent JSON
   ```

4. **Debug menu** (interactive)
   ```bash
   ./debug/menu.sh            # List entities/devices/services, delete, send command
   ```

5. **Backup MongoDB**
   ```bash
   ./ops/backup_db.sh
   # Output: ./backups/mongo-backup-YYYYMMDD-HHMMSS.gz
   ```

### Deployment scenarios

Odoo, North, South can be on 1–3 hosts. Pylon uses its own network (`pylon-net`); no Odoo compose changes.

| Scenario | Odoo | North | South | ODOO_HOST | IOTA_CB_HOST |
|----------|------|-------|-------|-----------|--------------|
| 1 | A | A | A | host.docker.internal | orion |
| 2 | A | A | B | host.docker.internal | North IP |
| 3 | A | B | B | Odoo IP | orion |
| 4 | A | B | C | Odoo IP | North IP |

**Same-host Odoo**: Orion reaches Odoo via `host.docker.internal` (host published port). Linux/WSL2 supported (North compose adds `extra_hosts`).

See [docs/LQS-IoT_PYLON_DEPLOYMENT_MODES.md](docs/LQS-IoT_PYLON_DEPLOYMENT_MODES.md).
