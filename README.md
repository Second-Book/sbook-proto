# sbook-proto

Workspace configuration and development tools for Textbook Marketplace project.

## Purpose

This repository contains:

- Cursor workspace configuration (`sbook.code-workspace`)
- SQLTools database connection settings
- Shared development tooling and scripts

## Project Structure

Textbook Marketplace consists of three repositories:

1. **sbook-proto** (this repository): Workspace configuration
   - Path: `/home/arezvov/d/projects/sbook/sbook-proto`
2. **sbook-backend**: Django REST API
   - Path: `/home/arezvov/d/projects/sbook/sbook-backend`
   - README: `../sbook-backend/README.md`
3. **sbook-frontend**: Next.js application
   - Path: `/home/arezvov/d/projects/sbook/sbook-frontend`
   - README: `../sbook-frontend/README.md`

## Workspace Setup

### Opening Workspace

Open workspace in Cursor:

```bash
cursor sbook.code-workspace
```

Workspace includes all three project folders and SQLTools configuration.

### SQLTools Configuration

Database connection pre-configured:

- **Name**: `sbook`
- **Driver**: PostgreSQL
- **Host**: `localhost`
- **Port**: `10543`
- **Database**: `textbook`
- **Username**: `textbook`
- **Password**: `textbook`

MUST start backend database before using SQLTools (see Local Development Setup).

## Repository Setup

### Cloning Repositories

MUST clone all three repositories to the same parent directory:

```bash
# Create parent directory
mkdir -p ~/projects/sbook
cd ~/projects/sbook

# Clone repositories
git clone git@github.com:Second-Book/sbook-proto.git 
git clone git@github.com:Second-Book/sbook-backend.git 
git clone git@github.com:Second-Book/sbook-frontend.git 
```

Expected directory structure:

```text
~/projects/sbook/
├── sbook-proto/
├── sbook-backend/
└── sbook-frontend/
```

## Local Development Setup

### Prerequisites

MUST install:

- **Backend**: Python 3.12, uv, Docker, docker-compose
- **Frontend**: Node.js 18+, pnpm 8+

### Setup Order

1. **Backend setup** (MUST be first): See `../sbook-backend/README.md`
2. **Frontend setup**: See `../sbook-frontend/README.md`

### Service URLs

- **Backend API**: `http://localhost:8000`
- **Frontend**: `http://localhost:3000`
- **Django Admin**: `http://localhost:8000/admin/`
- **API Docs**: `http://localhost:8000/api/docs/`
- **PostgreSQL**: `localhost:10543`
- **Redis**: `localhost:16379`

## Files Reference

- [sbook.code-workspace](sbook.code-workspace) - Cursor workspace configuration
- [../sbook-backend/README.md](../sbook-backend/README.md) - Backend documentation
- [../sbook-frontend/README.md](../sbook-frontend/README.md) - Frontend documentation
