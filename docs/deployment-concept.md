# Deployment Concept

## Repository Structure

Three separate GitHub repositories:

- `sbook-backend` - Django backend application
- `sbook-frontend` - Next.js frontend application
- `sbook-proto` - Shared configuration and documentation

## Deployment Trigger

Automatic deployment on push to `main` branch:

- Backend: Deploys when `sbook-backend` main branch is updated
- Frontend: Deploys when `sbook-frontend` main branch is updated
- Independent deployments (can deploy one without the other)

## Deployment Flow

```mermaid
graph LR
    A[Push to main] --> B[GitHub Actions Triggered]
    B --> C[Build & Test]
    C --> D[SSH to Server]
    D --> E[Deploy Files]
    E --> F[Run Migrations]
    F --> G[Restart Services]
    G --> H[Health Check]
```

## Server Architecture

### Directory Structure

```
/opt/sbook/
├── backend/                    # Django application
│   ├── textbook_marketplace/   # Application code
│   ├── media/                   # User uploads (persistent)
│   ├── staticfiles/           # Collected static files
│   └── logs/                  # Application logs
├── frontend/                   # Next.js application
│   ├── .next/                 # Build output
│   ├── node_modules/          # Dependencies
│   └── logs/                  # Application logs
└── conf/                       # Configuration files
    ├── sbook.nginx.conf             # Nginx configuration
    └── sbook-backend.supervisor.conf # Supervisor configuration
```

### Configuration Symlinks

Configuration files stored in `/opt/sbook/conf/` with symlinks to system directories:

```bash
/etc/nginx/sites-enabled/sbook → /opt/sbook/conf/sbook.nginx.conf
/etc/supervisor/conf.d/sbook-backend.conf → /opt/sbook/conf/sbook-backend.supervisor.conf
```

Benefits:

- Centralized configuration management
- Version control for configurations
- Easy updates via deployment
- No manual editing of system configs

## Deployment Process

### Backend Deployment

**GitHub Actions Workflow Steps:**

1. Checkout code (clone repository, checkout main branch)
2. Setup environment (Python 3.12, uv package manager, install dependencies: `uv sync`)
3. Build & test (optional: `uv run pytest`, collect static files: `python manage.py collectstatic --noinput`)
4. Deploy to server:
   - SSH connection to server
   - Copy application files to `/opt/sbook/backend/`
   - Install dependencies: `uv sync`
   - Run database migrations: `python manage.py migrate`
   - Collect static files: `python manage.py collectstatic --noinput`
   - Update supervisor configuration
   - Reload supervisor: `supervisorctl reread && supervisorctl update && supervisorctl restart sbook-backend`
5. Health check: verify backend responding: `curl http://127.0.0.1:8000/api/health/`

**Supervisor Configuration:**

- Process name: `sbook-backend`
- Command: `daphne -b 127.0.0.1 -p 8000 textbook_marketplace.asgi:application`
- Working directory: `/opt/sbook/backend/textbook_marketplace`
- Auto-restart: `true`
- Logs: `/opt/sbook/backend/logs/`

### Frontend Deployment

**GitHub Actions Workflow Steps:**

1. Checkout code (clone repository, checkout main branch)
2. Setup environment (Node.js 18+ or 20, install pnpm, install dependencies: `pnpm install`)
3. Build application (build Next.js: `pnpm build`, creates `.next/` directory)
4. Deploy to server:
   - SSH connection to server
   - Copy built application to `/opt/sbook/frontend/`
   - Install production dependencies: `pnpm install --prod`
   - Update PM2 configuration
   - Restart PM2 process: `pm2 restart sbook-frontend`
5. Health check: verify frontend responding: `curl http://127.0.0.1:3000`

**PM2 Configuration:**

- Process name: `sbook-frontend`
- Command: `pnpm start`
- Working directory: `/opt/sbook/frontend`
- Instances: 1 (can be scaled)
- Auto-restart: `true`
- Logs: `/opt/sbook/frontend/logs/`

## Configuration Management

### Environment Variables

**GitHub Secrets (sensitive data):**

- `SSH_PRIVATE_KEY` - Private SSH key for server access
- `SSH_HOST` - Server IP address or hostname
- `SSH_USER` - SSH username
- `DJANGO_SECRET_KEY` - Django secret key
- `DB_PASSWORD` - PostgreSQL database password

**GitHub Variables (non-sensitive):**

- `DEPLOY_PATH` - `/opt/sbook`
- `BACKEND_PORT` - `8000`
- `FRONTEND_PORT` - `3000`
- `NODE_VERSION` - `18` or `20`
- `PYTHON_VERSION` - `3.12`

**Server Environment Files:**

- Backend: `/opt/sbook/backend/.env`
- Frontend: `/opt/sbook/frontend/.env`

Environment files managed on server (not in repository) and contain:

- Database connection strings
- API keys and secrets
- Service URLs
- Feature flags

### Nginx Configuration

**Location:** `/opt/sbook/conf/sbook.nginx.conf`

**Features:**

- SSL/TLS termination
- Reverse proxy for frontend (port 3000)
- Reverse proxy for backend API (port 8000)
- WebSocket proxy support for chat
- Static file serving for media
- Security headers
- Rate limiting

**Domains:**

- Frontend: `https://sb.maria.rezvov.com`
- Backend API: `https://api.sb.maria.rezvov.com`

## Zero-Downtime Deployment

### Strategy

**Backend:**

- Supervisor handles graceful restarts
- Old process continues until new one is ready
- Minimal downtime during restart (< 1 second)

**Frontend:**

- PM2 handles graceful restarts
- Zero-downtime restart with `pm2 reload`
- Old process serves requests until new one is ready

## Database Migrations

### Automatic Migration Strategy

**Backend deployment includes:**

1. Backup current database (optional, recommended for production)
2. Run migrations: `python manage.py migrate`
3. Verify migration success
4. If migration fails, deployment is aborted

**Migration Requirements:**

- Migrations MUST be backward-compatible when possible
- Data migrations MUST be tested in staging
- Critical migrations MAY require manual intervention
- Migration rollback plan MUST be documented

## Security

### SSH Access

- SSH key authentication (no passwords)
- Private key stored in GitHub Secrets
- Server firewall: only SSH (22) and HTTP/HTTPS (80/443) ports open
- Internal services (Django, Next.js) bind to 127.0.0.1

### Secrets Management

- Secrets stored in GitHub Secrets (encrypted)
- Environment variables on server (`.env` files)
- DO NOT store secrets in repository or deployment scripts
- Secrets rotation process MUST be documented

### Network Security

- HTTPS/TLS for all external traffic
- Internal services not exposed to internet
- Nginx as single entry point
- CORS configuration restricts origins

## Monitoring and Logging

### Log Management

**Backend Logs:**

- Location: `/opt/sbook/backend/logs/`
- Format: JSON (structured logging)
- Rotation: Managed by Supervisor
- Levels: INFO, WARNING, ERROR

**Frontend Logs:**

- Location: `/opt/sbook/frontend/logs/`
- Format: Standard Next.js logs
- Rotation: Managed by PM2
- Levels: INFO, WARN, ERROR

**Nginx Logs:**

- Access: `/var/log/nginx/sbook-access.log`
- Error: `/var/log/nginx/sbook-error.log`

### Health Monitoring

**Health Check Endpoints:**

- Backend: `https://api.sb.maria.rezvov.com/api/health/`
- Frontend: `https://sb.maria.rezvov.com` (HTTP 200)

**Monitoring Strategy:**

- Post-deployment health checks in GitHub Actions
- External monitoring (optional): Uptime monitoring service
- Log aggregation (optional): Centralized logging system
