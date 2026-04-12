# CLAUDE.md — sbook-proto (workspace root)

This is the workspace orchestration repo for the SecondBook project. It contains workspace configuration, shared tooling, and acts as the Claude Code entry point for cross-repo work.

## Workspace Layout

```
~/d/projects/sbook/
├── sbook-proto/     # This repo — workspace config, shared CLAUDE.md
├── sbook-backend/   # Django REST API + WebSocket (Second-Book/sbook-backend)
└── sbook-frontend/  # Next.js frontend (Second-Book/sbook-frontend)
```

## Per-Repo CLAUDE.md

Each sub-repo has its own CLAUDE.md with detailed commands, architecture, and deployment info:

- **Backend**: `../sbook-backend/CLAUDE.md`
- **Frontend**: `../sbook-frontend/CLAUDE.md` (create when needed)

## Quick Reference

### Backend (sbook-backend/)

- Package manager: `uv`
- Dev server: `uv run python textbook_marketplace/manage.py runserver`
- Tests: `cd textbook_marketplace && uv run pytest`
- Docker services: `docker compose up -d` (PostgreSQL :10543, Redis :16379)

### Frontend (sbook-frontend/)

- Package manager: `pnpm`
- Dev server: `pnpm dev`
- Build: `pnpm build`
- Tests: `pnpm test`

### Deployment

Both repos deploy via GitHub Actions on push to `main`. Merge `dev` into `main` and push.

### Production

- Frontend: https://sb.maria.rezvov.com (PM2)
- Backend API: https://api.sb.maria.rezvov.com (Daphne/Supervisor)
- Server: `/opt/sbook/`
