# Onboarding — New Developer

## What is SecondBook?

SecondBook is a second-hand textbook marketplace. Give textbooks a second life instead of throwing them away — better for students' wallets and the environment. Users list used textbooks for sale, buyers search and communicate with sellers in real time via chat.

### Stack

- **Backend** (⚙️ back): Django 5 + DRF + Django Channels (WebSocket), PostgreSQL, Redis
- **Frontend** (🎨 front): Next.js 16 + React 19 + TypeScript + Tailwind CSS + Zustand
- **Auth**: JWT (access/refresh tokens), WebSocket auth via query param
- **Real-time**: chat via WebSocket (Django Channels + Redis channel layer)

### Where to look first

| What | Where |
| --- | --- |
| Architecture, API endpoints, env vars | [CLAUDE.md](../CLAUDE.md) — main reference |
| Backend code structure | `sbook-backend/textbook_marketplace/` — Django apps: `marketplace`, `chat`, `api` |
| Frontend code structure | `sbook-frontend/src/` — App Router, stores, services |
| API docs (interactive) | `http://localhost:8000/api/docs/` (Swagger UI, after starting backend) |
| Database schema | `sbook-backend/textbook_marketplace/marketplace/models.py`, `chat/models.py` |
| Deploy pipelines | `.github/workflows/deploy.yml` in each repo |
| Server config | [docs/nginx.md](nginx.md), [docs/monitoring.md](monitoring.md) |

### Key concepts

- **User model** (`marketplace.User`): extends Django `AbstractUser` — has `telegram_id`, `telephone`, `is_seller`
- **Textbook**: main entity — title, author, price, images, condition, owner (seller)
- **Wishlist**: buyers save textbooks they're interested in
- **Chat**: real-time messaging between buyer and seller, bidirectional blocking
- **Orders**: purchase flow between buyer and seller
- **Reports**: users can report inappropriate content

### Production

- Frontend: `https://secondbook.digital`
- Backend API: `https://api.secondbook.digital`
- Server: `sbook@82.146.48.165` (Ubuntu 24.04)

## Prerequisites

Install these tools:

- [ ] **Git**
- [ ] **Python 3.12** — [python.org](https://www.python.org/downloads/) or `pyenv`
- [ ] **uv** — `curl -LsSf https://astral.sh/uv/install.sh | sh`
- [ ] **Node.js 18+** — [nodejs.org](https://nodejs.org/) or `nvm`
- [ ] **pnpm 8+** — `corepack enable && corepack prepare pnpm@latest --activate`
- [ ] **Docker** + docker compose — [docs.docker.com](https://docs.docker.com/engine/install/)
- [ ] **VS Code** or **Cursor** editor

## SSH Setup

### 1. Generate SSH key

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

### 2. Add key to GitHub

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy output → [GitHub SSH keys](https://github.com/settings/keys) → "New SSH key".

Test: `ssh -T git@github.com`

### 3. Get access to GitHub org

- [ ] Ask the project owner to invite you to the [Second-Book](https://github.com/Second-Book) GitHub organization
- [ ] Accept the invitation at [github.com/orgs/Second-Book/invitation](https://github.com/orgs/Second-Book/invitation)

### 4. Production server access (optional)

Ask the project owner to add your public key to the server:

```bash
# Owner runs on the server:
echo "YOUR_PUBLIC_KEY" >> /home/sbook/.ssh/authorized_keys
```

Add SSH alias to your `~/.ssh/config`:

```text
Host sbook-dev
    Hostname 82.146.48.165
    User sbook
    RemoteCommand cd /opt/sbook; bash --login
    RequestTTY yes
```

Test: `ssh sbook@82.146.48.165 "echo ok"`

## Clone and Setup

```bash
# 1. Clone repos
mkdir -p ~/d/projects/sbook && cd ~/d/projects/sbook
git clone git@github.com:Second-Book/sbook-proto.git
git clone git@github.com:Second-Book/sbook-backend.git
git clone git@github.com:Second-Book/sbook-frontend.git

# 2. Open workspace
code sbook-proto/sbook.code-workspace
```

## Backend Setup

```bash
cd sbook-backend

# Start Docker services
docker compose up -d

# Install deps
uv sync

# Copy env (defaults work with Docker — just set DJANGO_SECRET_KEY)
cp env.example .env
# Edit .env: generate secret key with:
#   uv run python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'

# Apply migrations
uv run python textbook_marketplace/manage.py migrate

# Create admin user (optional)
uv run python textbook_marketplace/manage.py createsuperuser

# Generate test data
uv run python textbook_marketplace/manage.py generate_realistic_data --textbooks 50

# Start server
uv run python textbook_marketplace/manage.py runserver 0.0.0.0:8000
```

## Frontend Setup

```bash
cd sbook-frontend

# Copy env
cp env.example .env
# Default: NEXT_PUBLIC_API_BASE_URL=http://localhost:8000

# Install and run
pnpm install
pnpm dev
```

## Verify

- [ ] Frontend at `http://localhost:3000` — loads, shows textbooks
- [ ] Backend API at `http://localhost:8000/api/docs/` — Swagger UI opens
- [ ] Admin at `http://localhost:8000/admin/` — login works
- [ ] Registration — create user via frontend, login works
- [ ] Chat — open two browser tabs, send messages between users

## CI/CD Access (for deploying)

To enable GitHub Actions deployment, the following must be configured in each repo's Settings → Secrets and Variables:

**Secrets**: `SSH_PRIVATE_KEY`, `SSH_HOST`, `SSH_USER`, `DJANGO_SECRET_KEY`, `DB_PASSWORD`, `DJANGO_SUPERUSER_PASSWORD`

**Variables**: `DB_NAME`, `DB_USER`, `DB_HOST`, `DB_PORT`, `REDIS_HOST`, `REDIS_PORT`, `FRONTEND_URL`, `MEDIA_HOST`, `BACKEND_DOMAIN`, `DEPLOY_PATH`

These are already configured. New developers don't need to touch them unless setting up a new server.
