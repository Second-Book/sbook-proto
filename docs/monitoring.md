# Monitoring and Service Management

Server: `sbook@82.146.48.165` (Ubuntu 24.04).

## Service Status

### Quick check — all services

```bash
ssh sbook@82.146.48.165 "sudo supervisorctl status; export PATH=\$HOME/.local/share/pnpm:\$PATH && pm2 list; sudo systemctl is-active postgresql redis-server nginx"
```

### Backend (Supervisor)

```bash
ssh sbook@82.146.48.165 "sudo supervisorctl status sbook-backend"
# RUNNING pid XXXXX, uptime X:XX:XX
```

### Frontend (PM2)

```bash
ssh sbook@82.146.48.165 "export PATH=\$HOME/.local/share/pnpm:\$PATH && pm2 list"
```

### System services

```bash
ssh sbook@82.146.48.165 "sudo systemctl status postgresql redis-server nginx"
```

## Restart Services

### Backend

```bash
ssh sbook@82.146.48.165 "sudo supervisorctl restart sbook-backend"
```

### Frontend

```bash
ssh sbook@82.146.48.165 "export PATH=\$HOME/.local/share/pnpm:\$PATH && pm2 restart sbook-frontend"
```

### Nginx

```bash
ssh sbook@82.146.48.165 "sudo nginx -t && sudo systemctl reload nginx"
```

### PostgreSQL / Redis

```bash
ssh sbook@82.146.48.165 "sudo systemctl restart postgresql"
ssh sbook@82.146.48.165 "sudo systemctl restart redis-server"
```

## Logs

### Backend application logs

```bash
ssh sbook@82.146.48.165

# Stdout (access)
tail -f /opt/sbook/backend/logs/access.log

# Stderr (errors)
tail -f /opt/sbook/backend/logs/error.log
```

### Frontend application logs

```bash
ssh sbook@82.146.48.165 "export PATH=\$HOME/.local/share/pnpm:\$PATH && pm2 logs sbook-frontend"

# Or raw files:
# /opt/sbook/frontend/logs/access.log
# /opt/sbook/frontend/logs/error.log
```

### Nginx logs

```bash
ssh sbook@82.146.48.165

tail -f /var/log/nginx/sbook-backend-access.log
tail -f /var/log/nginx/sbook-backend-error.log
tail -f /var/log/nginx/sbook-frontend-access.log
tail -f /var/log/nginx/sbook-frontend-error.log
```

### PostgreSQL logs

```bash
ssh sbook@82.146.48.165 "sudo tail -f /var/log/postgresql/postgresql-16-main.log"
```

## Health Checks

```bash
# Backend API
curl -f https://api.secondbook.digital/api/health/

# Frontend
curl -f https://secondbook.digital/

# From server (bypass nginx)
ssh sbook@82.146.48.165 "curl -f http://127.0.0.1:8000/api/health/ && curl -f http://127.0.0.1:3000/"
```

## Supervisor Config

Config: `/opt/sbook/conf/sbook-backend.supervisor.conf`
Symlink: `/etc/supervisor/conf.d/sbook-backend.conf`

After editing supervisor config:

```bash
ssh sbook@82.146.48.165 "sudo supervisorctl reread && sudo supervisorctl update && sudo supervisorctl restart sbook-backend"
```

## PM2 Config

Ecosystem file: `/opt/sbook/frontend/deploy/sbook-frontend.ecosystem.config.js`

PM2 binary: `/home/sbook/.local/share/pnpm/pm2` (needs `PATH` export).

After editing PM2 config:

```bash
ssh sbook@82.146.48.165 "export PATH=\$HOME/.local/share/pnpm:\$PATH && cd /opt/sbook/frontend && pm2 delete sbook-frontend && pm2 start deploy/sbook-frontend.ecosystem.config.js && pm2 save"
```
