## MongoDB Component

This folder is the home for **MongoDB** specific notes and configuration.

- The running instance is defined in the root `docker-compose.yml` as service `mongo-db`.
- Data is persisted in the named Docker volume `mongo-db`.
- The `ops/backup_db.sh` script uses this instance (container name `db-mongo`) as its source.

