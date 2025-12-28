# Deployment Guide

## Server Prerequisites

### Required Software

**System Packages (Ubuntu 24.04):**

- Python 3.12+ (default python3 package)
- Node.js 20
- PostgreSQL (default package from Ubuntu repository)
- Redis (default redis-server package)
- Nginx
- Supervisor
- Git

**Package Managers:**

- `uv` (Python package manager)
- `pnpm` (Node.js package manager)
- `pm2` (global: `pnpm install -g pm2`)

### Installation Instructions

**Update package list:**

```bash
sudo apt update
```

**Install system packages:**

```bash
sudo apt install -y python3 python3-venv python3-pip postgresql postgresql-contrib redis-server nginx supervisor git curl rsync libmagic1
```

Note: `libmagic1` is required for `django-versatileimagefield` which uses `python-magic` library.

**Install Node.js 20 (using NodeSource repository):**

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

**Install uv (Python package manager):**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source $HOME/.local/bin/env
```

**Install pnpm:**

```bash
curl -fsSL https://get.pnpm.io/install.sh | sh -
source $HOME/.bashrc
```

**Install PM2:**

```bash
pnpm install -g pm2
```

**Verify installations:**

```bash
python3 --version
node --version
npm --version
pnpm --version
pm2 --version
uv --version
psql --version
redis-server --version
nginx -v
supervisord --version
```

### Initial Server Setup

**Create directory structure:**

```bash
sudo mkdir -p /opt/sbook/{backend,frontend,conf}
```

**Create symlinks:**

```bash
sudo ln -sf /opt/sbook/conf/sbook.nginx.conf /etc/nginx/sites-enabled/sbook.nginx.conf
sudo ln -sf /opt/sbook/conf/sbook-backend.supervisor.conf /etc/supervisor/conf.d/sbook-backend.conf
```

Note: Supervisor configuration is dynamically updated during deployment with `BACKEND_HOST` and `BACKEND_PORT` values via `sed`.

### Database Setup

**Start PostgreSQL service:**

```bash
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

**Create database and user:**

```bash
export DB_PASSWORD='your_password_here'

# Create database
sudo -u postgres psql -c "CREATE DATABASE sbook;"

# Create user with password
sudo -u postgres psql -c "CREATE USER sbook WITH PASSWORD '${DB_PASSWORD}';"

# Configure user settings
sudo -u postgres psql -c "ALTER ROLE sbook SET client_encoding TO 'utf8';"
sudo -u postgres psql -c "ALTER ROLE sbook SET default_transaction_isolation TO 'read committed';"
sudo -u postgres psql -c "ALTER ROLE sbook SET timezone TO 'UTC';"

# Grant privileges
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sbook TO sbook;"
sudo -u postgres psql -d sbook -c "GRANT ALL ON SCHEMA public TO sbook;"
```

**Test database connection:**

```bash
PGPASSWORD=${DB_PASSWORD} psql -U sbook -d sbook -h localhost -c "SELECT version();"
```

**Connection string format:**

```text
postgresql://sbook:${DB_PASSWORD}@localhost:5432/sbook
```

**Connect with psql:**

Using connection string:

```bash
psql postgresql://sbook:${DB_PASSWORD}@localhost:5432/sbook
```

Using environment variable:

```bash
PGPASSWORD=${DB_PASSWORD} psql -U sbook -d sbook -h localhost
```

**Start Redis service:**

```bash
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

**Verify services:**

```bash
sudo systemctl status postgresql
sudo systemctl status redis-server
```

**Test Redis connection:**

```bash
redis-cli ping
```

## Pre-deployment Setup

Before first deployment, MUST complete:

1. **Configure GitHub Secrets and Variables**
2. **Configure Nginx**
3. **Run first deployment** (push to trigger branch, or use manual trigger via workflow_dispatch)

### GitHub Organization Secrets and Variables

**MUST configure at organization level** (<https://github.com/organizations/Second-Book/settings/secrets/actions>):

**Secrets (sensitive data):**

1. **Setup SSH key for GitHub Actions:**

   **Generate SSH key pair on server:**

   ```bash
   ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions_deploy -N ""
   ```

   **Add public key to authorized_keys:**

   ```bash
   cat ~/.ssh/github_actions_deploy.pub >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

   **Get private key:**

   ```bash
   cat ~/.ssh/github_actions_deploy
   ```

   Copy entire output (including `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----`).

   **Add to GitHub Organization secrets:**
   - Navigate to: <https://github.com/organizations/Second-Book/settings/secrets/actions>
   - Click "New organization secret"
   - Name: `SSH_PRIVATE_KEY`
   - Value: paste private key content
   - Repository access: select `sbook-backend` and `sbook-frontend`

2. **Other secrets:**

   **Requirements:**

   - `SSH_HOST` - Server IP address or hostname (e.g., `82.146.48.165`, `sbook-dev`)
   - `SSH_USER` - SSH username (e.g., `sbook`)
   - `DJANGO_SECRET_KEY` - Django secret key
     - Generate with: `python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'`
     - Requirements:
       - Minimum 50 characters
       - MUST contain letters, numbers, and special characters
       - MUST be unique for each environment (production, staging, development)
       - MUST NOT be committed to version control
       - MUST NOT be shared between environments
       - MUST be regenerated if compromised
   - `DB_PASSWORD` - PostgreSQL database password
     - Minimum 12 characters
     - MUST contain uppercase, lowercase, numbers, and special characters
     - MUST be unique and not reused
   - `DJANGO_SUPERUSER_PASSWORD` - Password for Django superuser (created automatically on deployment)

**Variables (non-sensitive data):**

Configure at organization level (<https://github.com/organizations/Second-Book/settings/variables/actions>):

- `DEPLOY_PATH` - `/opt/sbook`
- `BACKEND_HOST` - Backend bind address (optional, default: `127.0.0.1`)
- `BACKEND_PORT` - `8000` (default, can be overridden)
- `FRONTEND_PORT` - `3000` (default, can be overridden)
- `NEXT_PUBLIC_API_BASE_URL` - `https://api.sb.maria.rezvov.com`
- `NEXT_PUBLIC_WS_URL` - `wss://api.sb.maria.rezvov.com`
- `DB_NAME` - `sbook` (PostgreSQL database name)
- `DB_USER` - `sbook` (PostgreSQL user name)
- `DB_HOST` - `localhost` (PostgreSQL host)
- `DB_PORT` - `5432` (PostgreSQL port)
- `REDIS_HOST` - `localhost` (Redis host)
- `REDIS_PORT` - `6379` (Redis port)
- `FRONTEND_URL` - `https://sb.maria.rezvov.com` (Frontend URL for CORS)
- `DJANGO_SUPERUSER_EMAIL` - Email address for Django superuser (created automatically on deployment)

### Nginx Configuration

**Copy nginx config to server (HTTP only, HTTPS will be added by certbot):**

```bash
# From local machine (from sbook-proto directory):
cd /home/arezvov/projects/sbook/sbook-proto
scp deploy/sbook.nginx.conf sbook-dev:/opt/sbook/conf/sbook.nginx.conf
```

**Create symlink and test HTTP configuration:**

```bash
ssh sbook-dev
sudo ln -sf /opt/sbook/conf/sbook.nginx.conf /etc/nginx/sites-enabled/sbook.nginx.conf
sudo nginx -t
sudo systemctl reload nginx
```

**Install and configure SSL certificates with certbot:**

```bash
ssh sbook-dev
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d sb.maria.rezvov.com -d api.sb.maria.rezvov.com
```

Certbot automatically:

- Creates SSL certificates
- Adds HTTPS server blocks with SSL configuration
- Adds HTTP to HTTPS redirects
- Updates nginx configuration
- Tests nginx configuration
- Reloads nginx

**Verify nginx configuration after certbot:**

```bash
sudo nginx -t
sudo systemctl status nginx
```

Nginx is now configured with HTTP and HTTPS. Next step: run first deployment (see Automated Deployment section below).

## Automated Deployment

### GitHub Actions Setup

**Backend repository (`sbook-backend`):**

- Workflow file: `.github/workflows/deploy.yml`
- Triggers:
  - Push to `feature/github_deploy` branch (automatic deployment)
  - Manual trigger via `workflow_dispatch` (for testing/debugging)
- Workflow steps:
  1. Run tests with PostgreSQL and Redis services
  2. Build (collect static files)
  3. Generate `.env` file from GitHub Secrets/Variables
  4. Deploy `.env` to server with `chmod 600`
  5. Execute deployment script: `deploy/deploy.sh`:
     - Check system dependencies (python3, curl, sudo, uv) - fail fast if missing
     - Create `static` directory before running collectstatic
     - Dynamically update supervisor configuration with `BACKEND_HOST` and `BACKEND_PORT` via sed
- First deployment runs automatically on first push to trigger branch

**Frontend repository (`sbook-frontend`):**

- Workflow file: `.github/workflows/deploy.yml`
- Triggers:
  - Push to `main` branch (automatic deployment)
  - Manual trigger via `workflow_dispatch` (for testing/debugging)
- Uses SSH deployment script: `deploy/deploy.sh`:
  - Check system dependencies (node, curl, pnpm, pm2) - fail fast if missing
  - Uses `pnpm install --no-frozen-lockfile` to handle pnpm version differences
  - Updates PM2 configuration with `FRONTEND_PORT` environment variable
- First deployment runs automatically on first push to `main`

**Manual deployment for debugging:**

Deploy from any branch using workflow_dispatch:

**Backend:**

1. Go to: <https://github.com/Second-Book/sbook-backend/actions>
2. Select "Deploy to Production" workflow in left sidebar
3. Click "Run workflow" dropdown (top right)
4. Select branch to deploy from
5. Click green "Run workflow" button

**Frontend:**

1. Go to: <https://github.com/Second-Book/sbook-frontend/actions>
2. Select "Deploy to Production" workflow in left sidebar
3. Click "Run workflow" dropdown (top right)
4. Select branch to deploy from
5. Click green "Run workflow" button

Workflow deploys code from selected branch. Use for testing changes before merging to `main`.

**Superuser creation:**

Superuser is created automatically during deployment using the `ensure_superuser` management command. The command is idempotent - it will only create the superuser if it doesn't already exist. Credentials are taken from GitHub Variables and Secrets:

- `DJANGO_SUPERUSER_EMAIL` (Variable)
- `DJANGO_SUPERUSER_PASSWORD` (Secret)

If superuser needs to be created manually:

```bash
ssh sbook-dev
cd /opt/sbook/backend/textbook_marketplace
uv run python manage.py ensure_superuser
```

Note: This requires `.env` file to be present with `DJANGO_SUPERUSER_EMAIL` and `DJANGO_SUPERUSER_PASSWORD` variables.

## Updating Server

### Backend Update

**Manual update steps:**

1. SSH to server
2. Pull latest code: `cd /opt/sbook/backend && git pull origin feature/github_deploy` (or current branch)
3. Install dependencies: `uv sync`
4. Run migrations: `cd textbook_marketplace && uv run python manage.py migrate` (reads `.env` from parent directory)
5. Collect static files: `uv run python manage.py collectstatic --noinput`
6. Ensure superuser exists: `uv run python manage.py ensure_superuser`
7. Restart supervisor: `supervisorctl restart sbook-backend`
8. Verify health: `curl http://127.0.0.1:8000/api/health/`

Note: `.env` file must be present in `/opt/sbook/backend/.env` with proper permissions (`chmod 600`).

**Automated update:**

- Push to `feature/github_deploy` branch triggers GitHub Actions (temporary, will be changed to `main`)
- Deployment script handles all steps automatically

### Frontend Update

**Manual update steps:**

1. SSH to server
2. Pull latest code: `cd /opt/sbook/frontend && git pull origin main`
3. Install dependencies: `pnpm install --no-frozen-lockfile` (allows lockfile regeneration if pnpm versions differ)
4. Build application: `pnpm build`
5. Restart PM2: `pm2 restart sbook-frontend`
6. Verify health: `curl http://127.0.0.1:3000` (or use `${FRONTEND_PORT}` if custom port)

**Automated update:**

- Push to `main` branch triggers GitHub Actions
- Deployment script handles all steps automatically

### Configuration Update

**Nginx configuration:**

1. Edit `/opt/sbook/conf/sbook.nginx.conf`
2. Test configuration: `sudo nginx -t`
3. Reload nginx: `sudo systemctl reload nginx`

**Supervisor configuration:**

1. Edit `/opt/sbook/conf/sbook-backend.supervisor.conf`
2. Reload supervisor: `supervisorctl reread && supervisorctl update && supervisorctl restart sbook-backend`

## Troubleshooting

### Deployment Fails

**Check:**

- SSH connection: `ssh $SSH_USER@$SSH_HOST`
- Server disk space: `df -h`
- Application logs: `/opt/sbook/backend/logs/` (backend), `/opt/sbook/frontend/logs/` (frontend)
- Environment variables: verify `.env` file exists at `/opt/sbook/backend/.env` with proper permissions (`chmod 600`)
- Check `.env` file: `ls -la /opt/sbook/backend/.env` (should show `-rw-------` permissions)

### Service Won't Start

**Backend (Supervisor):**

- Check logs: `supervisorctl tail -f sbook-backend`
- Verify config: `supervisorctl status sbook-backend`
- Check port availability: `netstat -tuln | grep 8000`
- Verify dependencies: `cd /opt/sbook/backend && uv sync`

**Frontend (PM2):**

- Check logs: `pm2 logs sbook-frontend`
- Verify status: `pm2 status`
- Check port availability: `netstat -tuln | grep 3000`
- Verify dependencies: `cd /opt/sbook/frontend && pnpm install`

### Database Migration Fails

**Check:**

- Database connection: verify database credentials are correct
- Migration files: `ls -la /opt/sbook/backend/textbook_marketplace/*/migrations/`
- Database permissions: verify user has CREATE/ALTER permissions
- Migration logs: check Django output during migration

### Nginx Issues

**Check:**

- Configuration syntax: `sudo nginx -t`
- Error logs: `sudo tail -f /var/log/nginx/sbook-error.log`
- Access logs: `sudo tail -f /var/log/nginx/sbook-access.log`
- SSL certificates: verify paths and permissions

### Health Check Fails

**If backend health check fails after deployment:**

1. Check service status:
   ```bash
   sudo supervisorctl status sbook-backend
   ```

2. Check logs for errors:
   ```bash
   sudo supervisorctl tail -f sbook-backend stderr
   ```

3. Verify service is listening:
   ```bash
   curl -v http://127.0.0.1:8000/api/health/
   ```

4. If service is down, check:
   - Database connectivity
   - Redis connectivity
   - `.env` file exists and has correct permissions
   - Dependencies installed: `cd /opt/sbook/backend && uv sync`

5. If health check continues to fail, consider rollback (see Rollback section below)

**If frontend health check fails after deployment:**

1. Check PM2 status:
   ```bash
   pm2 status
   pm2 logs sbook-frontend --lines 50
   ```

2. Verify service is listening:
   ```bash
   curl -v http://127.0.0.1:3000
   ```

3. If service is down, check:
   - Dependencies installed: `cd /opt/sbook/frontend && pnpm install`
   - Build artifacts exist: `ls -la /opt/sbook/frontend/.next`
   - Port not in use: `netstat -tuln | grep 3000`

4. If health check continues to fail, consider rollback (see Rollback section below)

### Rollback Procedure

**Backend rollback:**

1. SSH to server:
   ```bash
   ssh ${SSH_USER}@${SSH_HOST}
   ```

2. Navigate to backend directory:
   ```bash
   cd /opt/sbook/backend
   ```

3. Check git log for previous working commit:
   ```bash
   git log --oneline -10
   ```

4. Checkout previous working commit:
   ```bash
   git checkout <previous-commit-hash>
   ```

5. Install dependencies and run migrations:
   ```bash
   uv sync
   cd textbook_marketplace
   uv run python manage.py migrate
   uv run python manage.py collectstatic --noinput
   ```

6. Restart service:
   ```bash
   sudo supervisorctl restart sbook-backend
   ```

7. Verify health:
   ```bash
   curl http://127.0.0.1:8000/api/health/
   ```

**Frontend rollback:**

1. SSH to server:
   ```bash
   ssh ${SSH_USER}@${SSH_HOST}
   ```

2. Navigate to frontend directory:
   ```bash
   cd /opt/sbook/frontend
   ```

3. Check git log for previous working commit:
   ```bash
   git log --oneline -10
   ```

4. Checkout previous working commit:
   ```bash
   git checkout <previous-commit-hash>
   ```

5. Rebuild and restart:
   ```bash
   pnpm install
   pnpm build
   pm2 restart sbook-frontend
   ```

6. Verify health:
   ```bash
   curl http://127.0.0.1:3000
   ```

## Maintenance

### Log Rotation

**Backend logs:**

- Managed by Supervisor
- Location: `/opt/sbook/backend/logs/`
- Rotation: configured in supervisor config

**Frontend logs:**

- Managed by PM2
- Location: `/opt/sbook/frontend/logs/`
- Rotation: configured in PM2 config

### Database Backup

**Manual backup:**

```bash
pg_dump -U $DB_USER -d $DB_NAME > /opt/sbook/backups/db_$(date +%Y%m%d_%H%M%S).sql
```

**Restore:**

```bash
psql -U $DB_USER -d $DB_NAME < /opt/sbook/backups/db_TIMESTAMP.sql
```

### Media Files Backup

**Backup:**

```bash
tar -czf /opt/sbook/backups/media_$(date +%Y%m%d_%H%M%S).tar.gz /opt/sbook/backend/textbook_marketplace/media/
```

**Restore:**

```bash
tar -xzf /opt/sbook/backups/media_TIMESTAMP.tar.gz -C /
```

### SSL Certificate Renewal

Certbot automatically renews SSL certificates, but manual renewal can be triggered:

**Check certificate expiration:**

```bash
sudo certbot certificates
```

**Renew certificates manually:**

```bash
sudo certbot renew
```

**Test renewal (dry run):**

```bash
sudo certbot renew --dry-run
```

**After renewal, reload nginx:**

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Certbot typically sets up automatic renewal via systemd timer. Verify:

```bash
sudo systemctl status certbot.timer
```

### Staging Environment

For testing deployments before production, set up a staging environment:

**Requirements:**

- Separate server or separate directories on same server
- Separate GitHub Secrets/Variables with `_STAGING` suffix
- Separate database and Redis instances
- Different domain names (e.g., `staging.sb.maria.rezvov.com`)

**Setup steps:**

1. Create staging deployment path: `/opt/sbook-staging/`
2. Configure GitHub Variables with staging values:
   - `DEPLOY_PATH_STAGING=/opt/sbook-staging`
   - `FRONTEND_URL_STAGING=https://staging.sb.maria.rezvov.com`
3. Use separate workflow or workflow inputs to deploy to staging
4. Test deployments on staging before promoting to production

## Health Checks

### Backend Health Check

**Command:**

```bash
curl http://127.0.0.1:8000/api/health/
```

**Expected response:**

```json
{"status": "ok"}
```

### Frontend Health Check

**Command:**

```bash
curl http://127.0.0.1:3000
```

**Expected response:**

- HTTP 200 status code
- HTML content

### Service Status

**Check Supervisor:**

```bash
supervisorctl status
```

**Check PM2:**

```bash
pm2 status
```

**Check Nginx:**

```bash
sudo systemctl status nginx
```
