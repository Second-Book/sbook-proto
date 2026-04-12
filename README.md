# 🧩 sbook-proto

Workspace orchestration for **SecondBook** — textbook marketplace.

## Repos

| Alias | Repo | Description |
| --- | --- | --- |
| 🧩 proto | `Second-Book/sbook-proto` | Workspace config, docs |
| ⚙️ back | `Second-Book/sbook-backend` | Django REST API + WebSocket |
| 🎨 front | `Second-Book/sbook-frontend` | Next.js frontend |

## Quick Start

```bash
# Clone all repos into the same parent dir
mkdir -p ~/d/projects/sbook && cd ~/d/projects/sbook
git clone git@github.com:Second-Book/sbook-proto.git
git clone git@github.com:Second-Book/sbook-backend.git
git clone git@github.com:Second-Book/sbook-frontend.git

# Open workspace
code sbook-proto/sbook.code-workspace
```

**New to the project?** Start with [Onboarding](docs/onboarding.md) — project overview, stack, key concepts, and full setup checklist.

See [CLAUDE.md](CLAUDE.md) for architecture, API endpoints, and deployment reference.

## Docs

- [Onboarding](docs/onboarding.md) — project overview + new developer setup checklist
- [Database](docs/database.md) — backup, restore, local/production
- [Nginx](docs/nginx.md) — config, SSL, domains
- [Monitoring](docs/monitoring.md) — logs, service status, restart
- [Troubleshooting](docs/troubleshooting.md) — common issues and fixes

## Production

- Frontend: `https://secondbook.digital`
- Backend API: `https://api.secondbook.digital`
