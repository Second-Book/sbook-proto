# Nginx

## Overview

Nginx serves as reverse proxy for both frontend and backend on production.

| Domain | Upstream | Purpose |
| --- | --- | --- |
| `secondbook.digital` | `127.0.0.1:3000` | Next.js frontend (PM2) |
| `api.secondbook.digital` | `127.0.0.1:8000` | Django backend (Daphne/Supervisor) |
| `sb.maria.rezvov.com` | 301 redirect | Legacy → `secondbook.digital` |
| `api.sb.maria.rezvov.com` | 301 redirect | Legacy → `api.secondbook.digital` |

All HTTP requests redirect to HTTPS.

## Config Location

```text
Production config:  /opt/sbook/conf/sbook.nginx.conf
Symlink:            /etc/nginx/sites-enabled/sbook.nginx.conf → /opt/sbook/conf/sbook.nginx.conf
```

The config is managed manually (not via CI/CD). Edit on server directly.

## Backend Routes

| Location | Behavior |
| --- | --- |
| `/api/` | Proxy to Daphne |
| `/ws/` | WebSocket proxy (timeout 86400s) |
| `/admin/` | Django admin proxy |
| `/media/` | Static files from `/opt/sbook/backend/textbook_marketplace/media/`, cache 30d |
| `/static/` | Static files from `/opt/sbook/backend/textbook_marketplace/staticfiles/`, cache 30d |
| `/api/health/` | Health check, no access log |

## Common Operations

### Test config syntax

```bash
ssh sbook@82.146.48.165 "sudo nginx -t"
```

### Reload after config change

```bash
ssh sbook@82.146.48.165 "sudo nginx -t && sudo systemctl reload nginx"
```

### View logs

```bash
ssh sbook@82.146.48.165

# Frontend
tail -f /var/log/nginx/sbook-frontend-access.log
tail -f /var/log/nginx/sbook-frontend-error.log

# Backend
tail -f /var/log/nginx/sbook-backend-access.log
tail -f /var/log/nginx/sbook-backend-error.log
```

## SSL Certificates

Let's Encrypt via certbot, auto-renewed by systemd timer (`certbot.timer`).

```text
Certificate:  /etc/letsencrypt/live/secondbook.digital/fullchain.pem
Private key:  /etc/letsencrypt/live/secondbook.digital/privkey.pem
Domains:      secondbook.digital, api.secondbook.digital, sb.maria.rezvov.com, api.sb.maria.rezvov.com
```

### Check certificate status

```bash
ssh sbook@82.146.48.165 "sudo certbot certificates"
```

### Force renewal

```bash
ssh sbook@82.146.48.165 "sudo certbot renew --force-renewal && sudo systemctl reload nginx"
```

## Rate Limiting

Backend API has rate limiting at nginx level:

```nginx
limit_req zone=api_limit burst=20 nodelay;
```

The `api_limit` zone is defined in the main nginx config (`/etc/nginx/nginx.conf`).

## Limits

- `client_max_body_size 10M` — max upload size for both frontend and backend
