# Deployment Concept

## Repository Structure

Three separate GitHub repositories:

- `sbook-backend` - Django backend application
- `sbook-frontend` - Next.js frontend application
- `sbook-proto` - Shared configuration and documentation

## Deployment Trigger

Automatic deployment:

- Backend: Deploys when `sbook-backend` `main` branch is updated
- Frontend: Deploys when `sbook-frontend` `main` branch is updated
- Independent deployments (can deploy one without the other)

## Deployment Flow

```mermaid
graph LR
    A[Push to branch] --> B[GitHub Actions Triggered]
    B --> C[Run Tests]
    C --> D[Build]
    D --> E[Generate .env]
    E --> F[Deploy .env to Server]
    F --> G[SSH to Server]
    G --> H[Deploy Files]
    H --> I[Run Migrations]
    I --> J[Ensure Superuser]
    J --> K[Restart Services]
    K --> L[Health Check]
```

## Server Architecture

### Directory Structure

```
/opt/sbook/
├── backend/                    # Django application
│   ├── textbook_marketplace/   # Application code
│   │   ├── .env               # Symlink to ../.env (for python-decouple)
│   │   ├── media/             # User uploads (persistent)
│   │   └── staticfiles/       # Collected static files
│   ├── deploy/                # Deployment scripts
│   ├── .env                   # Environment variables (generated on deploy, chmod 600)
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

1. Checkout code (clone repository, checkout trigger branch)
2. Setup environment (Python 3.12, uv package manager, install dependencies: `uv sync`)
3. Run tests (`uv run pytest` with PostgreSQL and Redis services)
4. Collect static files: `python manage.py collectstatic --noinput`
5. Generate `.env` file from GitHub Secrets/Variables
6. Deploy `.env` to server (`/opt/sbook/backend/.env`) with `chmod 600`
7. Deploy to server:
   - SSH connection to server
   - Copy application files to `/opt/sbook/backend/` (rsync, excludes `.env`)
   - Install dependencies: `uv sync`
   - Create symlink from `textbook_marketplace/.env` to `../.env` (for python-decouple)
   - Run database migrations: `python manage.py migrate` (reads `.env` automatically)
   - Collect static files: `python manage.py collectstatic --noinput`
   - Ensure superuser exists: `python manage.py ensure_superuser` (idempotent)
   - Update supervisor configuration
   - Reload supervisor: `supervisorctl reread && supervisorctl update && supervisorctl restart sbook-backend`
8. Health check: verify backend responding: `curl http://127.0.0.1:8000/api/health/`

**Supervisor Configuration:**

- Process name: `sbook-backend`
- Command: `/home/sbook/.local/bin/uv run daphne -b ${BACKEND_HOST} -p ${BACKEND_PORT} textbook_marketplace.asgi:application`
- Working directory: `/opt/sbook/backend/textbook_marketplace`
- Environment variables: `BACKEND_HOST` (default: `127.0.0.1`), `BACKEND_PORT` (default: `8000`)
- Auto-restart: `true`
- Logs: `/opt/sbook/backend/logs/`

Supervisor directly runs daphne via uv with environment variables passed through `environment=` configuration. Django reads `.env` file automatically using `python-decouple` library.

### Frontend Deployment

**GitHub Actions Workflow Steps:**

1. Checkout code (clone repository, checkout trigger branch)
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
- Command: `pnpm start` (configured via `sbook-frontend.ecosystem.config.js`)
- Working directory: `/opt/sbook/frontend`
- Port: configured via `FRONTEND_PORT` environment variable (default: `3000`)
- Instances: 1 (can be scaled)
- Auto-restart: `true`
- Logs: `/opt/sbook/frontend/logs/`

## Configuration Management

### Environment Variables

See [deployment-guide.md](deployment-guide.md#github-organization-secrets-and-variables) for complete configuration instructions.

**Summary:**

- **GitHub Secrets**: SSH keys, database passwords, Django secret key, superuser credentials
- **GitHub Variables**: Deployment paths, ports, database/Redis hosts, frontend URLs
- **Server `.env` files**: Generated automatically from GitHub Secrets/Variables during deployment
- **Backend `.env`**: Located at `/opt/sbook/backend/.env`, symlinked to `textbook_marketplace/.env` for Django management commands

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
2. Run migrations: `python manage.py migrate` (reads `.env` automatically)
3. Ensure superuser exists: `python manage.py ensure_superuser` (idempotent, creates if missing)
4. Verify migration success
5. If migration fails, deployment is aborted

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
- `.env` file generated automatically from GitHub Secrets/Variables during deployment
- `.env` file deployed to server with restricted permissions (`chmod 600`)
- Environment variables passed through supervisor `environment=` configuration, Django reads `.env` via `python-decouple`
- DO NOT store secrets in repository or deployment scripts
- DO NOT manually edit `.env` on server - it is regenerated on each deployment
- Secrets rotation: update GitHub Secrets, then redeploy to regenerate `.env`
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
