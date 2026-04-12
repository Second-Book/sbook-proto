# CLAUDE.md — 🧩 proto (workspace root)

Orchestration repo for **SecondBook** — textbook marketplace (Django + Next.js).

## Workspace

```text
~/d/projects/sbook/
├── sbook-proto/     →  🧩 proto   # This repo — workspace config, docs, orchestration
├── sbook-backend/   →  ⚙️ back    # Django REST API + WebSocket
└── sbook-frontend/  →  🎨 front   # Next.js frontend
```

Per-repo CLAUDE.md files contain **only** repo-specific commands and architecture.
All cross-cutting docs (setup, deployment, architecture overview) live here.

GitHub org: `Second-Book` — repos: `sbook-proto`, `sbook-backend`, `sbook-frontend`.

## Quick Commands

### ⚙️ back

```bash
cd ../sbook-backend
uv sync                                                      # Install deps
uv run python textbook_marketplace/manage.py runserver        # Dev server :8000
uv run python textbook_marketplace/manage.py migrate          # Apply migrations
cd textbook_marketplace && uv run pytest                      # Run tests
docker compose up -d                                          # PostgreSQL :10543, Redis :16379
```

### 🎨 front

```bash
cd ../sbook-frontend
pnpm install          # Install deps
pnpm dev              # Dev server :3000 (Turbopack)
pnpm build            # Production build
pnpm test             # Jest unit tests
pnpm lint             # ESLint
```

## Architecture Overview

### Stack

- **Backend**: Django 5, DRF, Django Channels (ASGI/Daphne), PostgreSQL 16, Redis
- **Frontend**: Next.js 16, React 19, TypeScript, Tailwind CSS v4, Zustand
- **Auth**: JWT (`simplejwt`) for REST, JWT in query param for WebSocket
- **Real-time**: WebSocket via Django Channels + Redis channel layer

### Front ↔ Back Interaction

- Frontend Axios client (`src/services/api.ts`) → Backend REST API at `/api/`
- Auto token refresh on 401 via Axios interceptor
- WebSocket singleton (`src/services/websocketService.ts`) → `ws://<host>/ws/chat/?token=<jwt>`
- `NEXT_PUBLIC_API_BASE_URL` must NOT include `/api` suffix — service paths already include it

### API Endpoints

REST API base: `/api/`

| Endpoint | Description |
| --- | --- |
| `/api/signup/` | Registration |
| `/api/token/`, `/api/token/refresh/` | JWT obtain/refresh |
| `/api/users/me/` | Current user profile |
| `/api/users/{username}/block/` | Block/unblock user |
| `/api/textbooks/` | CRUD (IsOwner permission) |
| `/api/wishlist/` | List saved textbooks |
| `/api/wishlist/{id}/` | Add (POST) / Remove (DELETE) |
| `/api/wishlist/{id}/check/` | Check if in wishlist |
| `/api/chat/`, `/api/chat/conversation/{username}/` | Messages |
| `/api/docs/` | Swagger UI (drf-spectacular) |
| `/api/health/` | Health check |
| `ws/chat/?token=<jwt>` | WebSocket |

### Environment Variables

**Backend** `.env` (see `../sbook-backend/env.example`):

- `DJANGO_SECRET_KEY` (required), `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`
- `REDIS_HOST`, `REDIS_PORT`, `FRONTEND_URL`, `MEDIA_HOST`, `DEBUG`

**Frontend** `.env` (see `../sbook-frontend/env.example`):

- `NEXT_PUBLIC_API_BASE_URL` (default `http://127.0.0.1:8000`) — **no `/api` suffix**
- `NEXT_PUBLIC_WS_URL` (default `ws://localhost:8000`)

Note: `NEXT_PUBLIC_*` vars are baked into the build — must rebuild after changes.

## Local Development Setup

### Prerequisites

- Python 3.12 + `uv`
- Node.js 18+ + `pnpm` 8+
- Docker + docker compose

### Step-by-Step

```bash
# 1. Clone repos (all into the same parent dir)
mkdir -p ~/d/projects/sbook && cd ~/d/projects/sbook
git clone git@github.com:Second-Book/sbook-proto.git
git clone git@github.com:Second-Book/sbook-backend.git
git clone git@github.com:Second-Book/sbook-frontend.git

# 2. Start PostgreSQL and Redis
cd sbook-backend
docker compose up -d                  # PostgreSQL :10543, Redis :16379

# 3. Backend setup
cp env.example .env                   # Edit .env if needed (defaults work with Docker)
uv sync
uv run python textbook_marketplace/manage.py migrate
uv run python textbook_marketplace/manage.py createsuperuser  # Optional

# 4. Generate test data
uv run python textbook_marketplace/manage.py generate_realistic_data --textbooks 50

# 5. Start backend
uv run python textbook_marketplace/manage.py runserver 0.0.0.0:8000

# 6. Frontend (new terminal)
cd ../sbook-frontend
cp env.example .env                   # NEXT_PUBLIC_API_BASE_URL="http://127.0.0.1:8000"
pnpm install
pnpm dev                              # http://localhost:3000
```

### Local Service URLs

| Service | URL |
| --- | --- |
| Frontend | `http://localhost:3000` |
| Backend API | `http://localhost:8000` |
| Swagger docs | `http://localhost:8000/api/docs/` |
| Django Admin | `http://localhost:8000/admin/` |
| PostgreSQL | `localhost:10543` |
| Redis | `localhost:16379` |

### Test Data

```bash
# Full realistic dataset (users, textbooks, messages, orders, blocks, reports)
uv run python textbook_marketplace/manage.py generate_realistic_data --textbooks N

# For N=1000: ~333 users, 1000 textbooks, ~900 messages, ~65 blocks, ~40 reports, ~125 orders

# Individual generators
uv run python textbook_marketplace/manage.py generate_fake_users N
uv run python textbook_marketplace/manage.py generate_fake_textbooks N
uv run python textbook_marketplace/manage.py generate_fake_messages N
```

### Notes

- Backend uses `settings.py` (PostgreSQL) by default. Tests use `settings_dev.py` (SQLite) via `pytest.ini`.
- `settings_dev.py` has broken SQLite config (missing `NAME`) — always use Docker PostgreSQL for local dev.
- `MEDIA_HOST` defaults to `http://127.0.0.1:8000`; on production set to `https://api.secondbook.digital`.

## Production Server

- **SSH**: `ssh sbook@82.146.48.165` (alias `sbook-dev` in SSH config — has `RemoteCommand`, not for scripting)
- **Project root**: `/opt/sbook/` (`backend/`, `frontend/`, `conf/`)
- **Frontend**: `https://secondbook.digital` — Next.js via PM2 (`sbook-frontend`) on :3000
- **Backend API**: `https://api.secondbook.digital` — Daphne ASGI via Supervisor (`sbook-backend`) on :8000
- **Legacy domains**: `sb.maria.rezvov.com` → 301 → `secondbook.digital`, `api.sb.maria.rezvov.com` → 301 → `api.secondbook.digital`
- **Nginx**: reverse proxy, config at `/opt/sbook/conf/sbook.nginx.conf`
- **DB/Redis**: native systemd services (PostgreSQL 16, Redis), NOT Docker
- **SSL**: Let's Encrypt, cert at `/etc/letsencrypt/live/secondbook.digital/`
- **Logs**: backend `/opt/sbook/backend/logs/`, frontend `pm2 logs sbook-frontend`
- **PM2**: needs `export PATH=$HOME/.local/share/pnpm:$PATH`

## Git Workflow

All work happens on `dev` branch (or feature branches off `dev`). Production deploys from `main`.

```text
feature/xxx  →  dev  →  (PR)  →  main  →  auto-deploy to production
```

### Day-to-day

1. Work on `dev` or create a feature branch from `dev`
2. Push to `dev` (or merge feature branch into `dev` via PR)
3. When ready to deploy: create a PR from `dev` → `main`
4. Merge the PR — GitHub Actions automatically deploys to production

### Branch rules

- `dev` — active development, always up to date
- `main` — production, only updated via PRs from `dev`
- Feature branches — `feature/xxx`, `fix/xxx` from `dev`, merged back via PR

### Deploy commands (manual shortcut)

```bash
# Deploy backend
cd ../sbook-backend
git checkout main && git merge dev && git push origin main

# Deploy frontend
cd ../sbook-frontend
git checkout main && git merge dev && git push origin main
```

## CI/CD Pipelines

Both repos deploy via **GitHub Actions** on push to `main` (or manual `workflow_dispatch`).

### ⚙️ back Pipeline (`.github/workflows/deploy.yml`)

1. Runs pytest with PostgreSQL/Redis service containers
2. Collects static files
3. Generates `.env` from GitHub Secrets/Vars, deploys via SCP
4. `deploy/deploy.sh`: rsync → `uv sync` → `migrate` → `collectstatic` → restart Supervisor → health check `/api/health/`

### 🎨 front Pipeline (`.github/workflows/deploy.yml`)

1. Builds with `pnpm build` (bakes `NEXT_PUBLIC_*` vars)
2. Rsync to `/opt/sbook/frontend/`
3. `pnpm install` → restart PM2 → health check `http://127.0.0.1:3000`

### GitHub Secrets & Vars

**Secrets**: `SSH_PRIVATE_KEY`, `SSH_HOST`, `SSH_USER`, `DJANGO_SECRET_KEY`, `DB_PASSWORD`, `DJANGO_SUPERUSER_PASSWORD`

**Vars**: `DB_NAME`, `DB_USER`, `DB_HOST`, `DB_PORT`, `REDIS_HOST`, `REDIS_PORT`, `FRONTEND_URL`, `MEDIA_HOST`, `BACKEND_DOMAIN`, `DEPLOY_PATH`

## SSH Setup for New Dev Machine

### 1. Generate SSH key

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# Save to default ~/.ssh/id_ed25519
```

### 2. Add key to GitHub

```bash
cat ~/.ssh/id_ed25519.pub
# Copy output → GitHub → Settings → SSH and GPG keys → New SSH key
```

Test connection:

```bash
ssh -T git@github.com
# "Hi username! You've successfully authenticated..."
```

### 3. Add production server access

Add your public key to the server:

```bash
ssh-copy-id sbook@82.146.48.165
# Or manually append to /home/sbook/.ssh/authorized_keys
```

### 4. Configure SSH alias (optional)

Add to `~/.ssh/config`:

```text
Host sbook-dev
    Hostname 82.146.48.165
    User sbook
    RemoteCommand cd /opt/sbook; bash --login
    RequestTTY yes
```

### 5. Clone and open workspace

```bash
mkdir -p ~/d/projects/sbook && cd ~/d/projects/sbook
git clone git@github.com:Second-Book/sbook-proto.git
git clone git@github.com:Second-Book/sbook-backend.git
git clone git@github.com:Second-Book/sbook-frontend.git

# Open in VS Code / Cursor
code sbook-proto/sbook.code-workspace
```

Then follow "Local Development Setup" above.
