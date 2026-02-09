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
├── setup.sh                  # One-time setup (config, provision, subscription, systemd)
├── run.sh                    # Start stack (docker compose up -d)
├── ops/
│   ├── backup_db.sh          # MongoDB backup
│   ├── provision_service_group.sh
│   ├── register_subscription.sh
│   └── systemd/pylon.service # Systemd unit (start on boot)
│
└── README.md
```

### Quick start

1. **Run setup** (one-time)
   ```bash
   ./setup.sh
   ```
   This: copies `config.example` to `config`, creates Docker network, starts stack, provisions IoT Agent service groups, registers Orion subscription, optionally installs systemd.

2. **Start/restart** (after `docker compose down` or reboot)
   ```bash
   ./run.sh
   ```

3. **Check services**
   ```bash
   docker ps
   curl "http://localhost:1026/version"        # Orion
   curl "http://localhost:4041/iot/about"     # IoT Agent JSON
   ```

4. **Backup MongoDB**
   ```bash
   ./ops/backup_db.sh
   # Output: ./backups/mongo-backup-YYYYMMDD-HHMMSS.gz
   ```
