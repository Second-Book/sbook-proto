# Troubleshooting

## Local Development

### Port already in use

```text
Error: That port is already in use.
```

Find and kill the process:

```bash
# Backend (port 8000)
lsof -i :8000
kill -9 <PID>

# Frontend (port 3000)
lsof -i :3000
kill -9 <PID>

# Docker PostgreSQL (port 10543)
docker compose down && docker compose up -d
```

### Docker containers won't start

```bash
# Check status
docker compose ps

# Check logs
docker compose logs postgres
docker compose logs redis

# Nuclear option — recreate from scratch
docker compose down -v
docker compose up -d
```

### Migrations fail

```text
django.db.utils.OperationalError: could not connect to server
```

Check Docker PostgreSQL is running:

```bash
docker compose ps   # Should show textbook_postgres as healthy
docker exec textbook_postgres pg_isready -U textbook
```

If using wrong settings (SQLite instead of PostgreSQL):

```bash
# manage.py uses settings.py (PostgreSQL) by default
# settings_dev.py has broken SQLite config (missing NAME) — don't use it for local dev
# Tests use settings_dev.py via pytest.ini — that's fine, tests don't need Docker
```

### CORS errors in browser

```text
Access to XMLHttpRequest has been blocked by CORS policy
```

- Check `FRONTEND_URL` in backend `.env` matches the frontend origin (`http://localhost:3000`)
- In dev, `settings.py` restricts CORS to `FRONTEND_URL`. If you need to allow all: temporarily use `settings_dev.py`
- Make sure `NEXT_PUBLIC_API_BASE_URL` in frontend `.env` does NOT include `/api` suffix

### WebSocket connection fails

```text
WebSocket connection to 'ws://...' failed
```

- Check Redis is running: `docker exec textbook_redis redis-cli ping` → `PONG`
- Check `NEXT_PUBLIC_WS_URL` in frontend `.env` (should be `ws://localhost:8000`)
- Check backend runs with `settings.py` (has Redis channel layer config), not `settings_dev.py`

### Frontend env vars not taking effect

`NEXT_PUBLIC_*` variables are baked into the build at compile time.

- In dev (`pnpm dev`): restart dev server after `.env` changes
- In production: must rebuild (`pnpm build`) and restart PM2

### `uv` command not found

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# Then restart shell or: export PATH="$HOME/.local/bin:$PATH"
```

### `pnpm` command not found

```bash
corepack enable
corepack prepare pnpm@latest --activate
# Or: curl -fsSL https://get.pnpm.io/install.sh | sh -
```

## Production

### Backend not responding

```bash
ssh sbook@82.146.48.165

# Check status
sudo supervisorctl status sbook-backend

# Check logs
tail -50 /opt/sbook/backend/logs/error.log

# Restart
sudo supervisorctl restart sbook-backend

# Health check
curl -f http://127.0.0.1:8000/api/health/
```

### Frontend not responding

```bash
ssh sbook@82.146.48.165
export PATH=$HOME/.local/share/pnpm:$PATH

# Check status
pm2 list

# Check logs
pm2 logs sbook-frontend --lines 50

# Restart
pm2 restart sbook-frontend

# Health check
curl -f http://127.0.0.1:3000/
```

### 502 Bad Gateway

Nginx can't reach the upstream service:

```bash
ssh sbook@82.146.48.165

# Check if services are actually running
curl -f http://127.0.0.1:8000/api/health/   # backend
curl -f http://127.0.0.1:3000/               # frontend

# Check nginx error log
tail -20 /var/log/nginx/sbook-backend-error.log
tail -20 /var/log/nginx/sbook-frontend-error.log
```

### SSL certificate expired

Certbot auto-renews via systemd timer, but if it fails:

```bash
ssh sbook@82.146.48.165

# Check cert status
sudo certbot certificates

# Force renewal
sudo certbot renew --force-renewal
sudo systemctl reload nginx
```

### Deployment failed in GitHub Actions

1. Check the Actions tab in the failing repo on GitHub
2. Common causes:
   - **Tests fail**: fix tests locally, push again
   - **SSH connection refused**: check `SSH_HOST`, `SSH_PRIVATE_KEY` secrets
   - **Health check fails**: SSH into server, check logs (see above)
   - **Disk full**: `ssh sbook@82.146.48.165 "df -h"`
