## LQS-IoT_Pylon

LQS-IoT_Pylon is the "steel pylon" of factory digitalisation—a lightweight infrastructure component library built for Industrial IoT (IIoT). It simplifies the FIWARE ecosystem into modular Docker components that act as the data hub (Context Broker) between field devices (PLCs, access control, sensors) and upper-layer applications (ERP, digital signage, WebApp).

### Features

- **Component-based design**: One service per folder; pick only the modules you need for POC or production.
- **Digital Twin**: FIWARE Orion at the core for standardised device state modelling and real-time sync.
- **Deployment-friendly**: Copy `config.example` to `config`, run `ops/init-pylon.sh`, and you have an industrial-grade data exchange platform.
- **Extensible**: Structure is ready for future additions (MQTT, Node-RED, time-series DB).

### Layout

```txt
LQS-IoT_Pylon/
├── docker-compose.yml        # Assembly: Orion / IoT Agent / MongoDB on the Pylon
│
├── components/               # Core components (one service per folder)
│   ├── orion/                # FIWARE Orion Context Broker
│   ├── iota-json/            # IoT Agent for JSON (device ingress/egress)
│   └── mongodb/              # MongoDB for Orion and IoT Agent
│
├── config.example/           # Config template (copy to config/ when deploying)
│   └── config.env            # Global env (ports, hosts, FIWARE headers, Odoo URL)
│
├── ops/                      # Ops and deployment
│   ├── init-pylon.sh         # Init: Docker network, stack up, provision & subscription
│   ├── backup-db.sh          # MongoDB backup
│   ├── provision_service_group.sh  # IoT Agent service group provisioning
│   └── register_subscription.sh    # Orion subscription (notify Odoo)
│
└── README.md
```

### Quick start

1. **Prepare config**
   ```bash
   cp -r config.example config
   # Edit config/config.env (ports, Odoo host, etc.)
   ```

2. **Initialise Pylon**
   ```bash
   ./ops/init-pylon.sh
   ```

   This script will:
   - Ensure Docker external network `odobundle-codebase_odoo-net` exists (create if missing)
   - Run `docker compose up -d` (Orion, IoT Agent JSON, MongoDB)
   - Run `ops/provision_service_group.sh` (Signage / NeoPixel service groups)
   - Run `ops/register_subscription.sh` (Orion subscription → Odoo `/update_last_seen`)

3. **Check services**
   ```bash
   docker ps
   curl "http://localhost:1026/version"        # Orion
   curl "http://localhost:4041/iot/about"     # IoT Agent JSON
   ```

4. **Backup MongoDB**
   ```bash
   ./ops/backup-db.sh
   # Output: ./backups/mongo-backup-YYYYMMDD-HHMMSS.gz
   ```
