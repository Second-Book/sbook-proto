# Database

## Local (Docker)

Dev environment uses Docker containers from `sbook-backend/docker-compose.yml`:

- **PostgreSQL 15-alpine** — container `textbook_postgres`, port `10543`, db/user/password: `textbook/textbook/textbook`
- **Redis 7-alpine** — container `textbook_redis`, port `16379`, AOF persistence

```bash
cd ../sbook-backend
docker compose up -d      # Start
docker compose down        # Stop (data preserved in volumes)
docker compose down -v     # Stop and DELETE all data
```

Docker volumes: `postgres_data`, `redis_data`.

## Production

- **PostgreSQL 16** — native systemd service, database `sbook`, standard port `5432`
- **Redis** — native systemd service, standard port `6379`
- **Server**: Ubuntu 24.04, `sbook@82.146.48.165`

## Backup Production Database

### Full dump

```bash
ssh sbook@82.146.48.165
pg_dump -U sbook -d sbook -F c -f /tmp/sbook_backup.dump
```

### Download to local machine

```bash
scp sbook@82.146.48.165:/tmp/sbook_backup.dump ./sbook_backup.dump
```

### Schema only (no data)

```bash
ssh sbook@82.146.48.165 "pg_dump -U sbook -d sbook --schema-only" > schema.sql
```

## Restore to Local Docker

```bash
# 1. Make sure Docker PostgreSQL is running
cd ../sbook-backend
docker compose up -d

# 2. Drop and recreate local database
docker exec textbook_postgres psql -U textbook -c "DROP DATABASE IF EXISTS textbook;"
docker exec textbook_postgres psql -U textbook -d postgres -c "CREATE DATABASE textbook OWNER textbook;"

# 3. Restore from dump
docker exec -i textbook_postgres pg_restore -U textbook -d textbook --no-owner --no-acl < sbook_backup.dump

# 4. Run migrations (in case local schema is ahead)
uv run python textbook_marketplace/manage.py migrate
```

### Restore from SQL (plain text)

```bash
docker exec -i textbook_postgres psql -U textbook -d textbook < schema.sql
```

## Restore to Production

```bash
ssh sbook@82.146.48.165

# Stop backend
sudo supervisorctl stop sbook-backend

# Restore
pg_dump -U sbook -d sbook -F c -f /tmp/sbook_pre_restore.dump   # safety backup
dropdb -U sbook sbook
createdb -U sbook sbook
pg_restore -U sbook -d sbook --no-owner /tmp/sbook_backup.dump

# Restart
sudo supervisorctl start sbook-backend
```

## Redis

Redis is used for Django Channels (WebSocket message broker). No persistent application data — safe to flush.

```bash
# Local
docker exec textbook_redis redis-cli FLUSHALL

# Production
ssh sbook@82.146.48.165 "redis-cli FLUSHALL"
```
