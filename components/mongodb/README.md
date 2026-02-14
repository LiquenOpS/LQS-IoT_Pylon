## MongoDB Component

This folder is the home for **MongoDB** specific notes and configuration.

- The running instance is defined in the root `docker-compose.north.yml` as service `mongo-orion`.
- Data is persisted in the named Docker volume `mongo-orion`.
- The `ops/backup_db.sh` script uses this instance (container name `db-mongo-orion`) as its source.

