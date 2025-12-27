# System Architecture

## Components

SecondBook platform consists of three components:

- Backend: Django REST API with WebSocket support
- Frontend: Next.js 16 SSR application
- Infrastructure: PostgreSQL, Redis, Nginx reverse proxy

## Backend (`sbook-backend`)

### Technology Stack

- Django 5.1.7 (Python 3.12)
- Django REST Framework 3.15.2
- Django Channels 4.2.0 (ASGI with Daphne)
- PostgreSQL (database)
- Redis (channel layers for WebSockets)
- Gunicorn (production WSGI server)
- WhiteNoise (static file serving)

### Architecture

- ASGI application for HTTP and WebSocket support
- RESTful API endpoints
- JWT authentication (Simple JWT)
- WebSocket chat functionality
- Image processing (VersatileImageField)

### Applications

**marketplace:**

- User management (custom User model)
- Textbook listings (CRUD operations)
- Orders management
- User blocking and reporting
- Image upload and processing

**chat:**

- WebSocket connections
- JWT authentication middleware
- Message storage and delivery

### Features

- REST API with OpenAPI documentation (drf-spectacular)
- CORS support for frontend integration
- Rate limiting (django-ratelimit)
- Structured logging (structlog)
- Image optimization and thumbnails
- Content sanitization (bleach)

### API Endpoints

- `/api/` - REST API base
- `/api/health/` - Health check
- `/ws/chat/` - WebSocket chat endpoint
- `/media/` - Media files (images)
- `/static/` - Static files

## Frontend (`sbook-frontend`)

### Technology Stack

- Next.js 16.1 (App Router)
- React 19
- TypeScript 5.8
- Tailwind CSS 4.0
- Zustand 5.0 (state management)
- Axios 1.8 (HTTP client)
- React Hot Toast (notifications)

### Architecture

- Server-Side Rendering (SSR) with Next.js
- App Router architecture
- Client-side state management (Zustand)
- API service layer abstraction
- WebSocket service for real-time chat

### Pages

- `/` - Homepage (latest textbooks)
- `/textbooks` - Textbook listings with filters
- `/textbook/[id]` - Textbook detail page
- `/login` - User authentication
- `/signup` - User registration
- `/profile/*` - User profile sections:
  - `/profile/my-listings` - User's textbook listings
  - `/profile/messages` - Chat messages
  - `/profile/saved-items` - Saved textbooks
  - `/profile/edit` - Profile editing
  - `/profile/edit-listing/[id]` - Edit listing

### Features

- Responsive design (mobile and desktop)
- Search and filtering
- Image optimization (Next.js Image component)
- Token-based authentication with auto-refresh
- Real-time WebSocket chat integration
- Form validation (Zod schemas)

## Infrastructure

### Database

- PostgreSQL 15
- Stores: users, textbooks, orders, messages, blocks, reports

### Cache/Message Broker

- Redis 7
- Channel layers for WebSocket connections
- Optional caching layer

### Web Server

- Nginx (reverse proxy)
- SSL/TLS termination
- Static file serving
- WebSocket proxy support

### Process Management

- Supervisor (Django backend)
- PM2 (Next.js frontend)

## Data Flow

### HTTP Request Flow

```
Client → Nginx → Backend (Daphne) → Django → Database
                              ↓
                         Redis (if needed)
```

### WebSocket Flow

```
Client → Nginx (WebSocket upgrade) → Daphne ASGI → Channels → Redis → Consumer
```

### Frontend Request Flow

```
Browser → Next.js SSR → API Service → Backend API
                ↓
         Client-side State (Zustand)
```

## Deployment Architecture

### Server Structure

```
/opt/sbook/
├── backend/              # Django application
│   ├── textbook_marketplace/
│   ├── media/           # User-uploaded files
│   ├── staticfiles/     # Collected static files
│   └── logs/            # Application logs
├── frontend/             # Next.js application
│   ├── .next/           # Build output
│   ├── node_modules/    # Dependencies
│   └── logs/            # Application logs
└── conf/                 # Configuration files
    ├── sbook.nginx.conf
    └── sbook-backend.supervisor.conf
```

### Network Architecture

```
Internet
   ↓
Nginx (Port 80/443)
   ├── https://sb.maria.rezvov.com → http://127.0.0.1:3000 (Frontend)
   └── https://api.sb.maria.rezvov.com → http://127.0.0.1:8000 (Backend)
                                          ├── /api/* (REST API)
                                          ├── /ws/* (WebSocket)
                                          └── /media/* (Media files)
```

### Process Management

**Backend (Supervisor):**

- Command: `/opt/sbook/backend/deploy/run.sh` (wrapper script)
- Wrapper script runs: `daphne -b ${BACKEND_HOST} -p ${BACKEND_PORT} textbook_marketplace.asgi:application`
- Host and port configured via environment variables: `BACKEND_HOST` (default: `127.0.0.1`), `BACKEND_PORT` (default: `8000`)
- Environment variables passed through supervisor `environment=` configuration
- Auto-restart: enabled
- Logs: `/opt/sbook/backend/logs/`

**Frontend (PM2):**

- Command: `node_modules/.bin/next start` (configured via `sbook-frontend.ecosystem.config.js`)
- Port: configured via `FRONTEND_PORT` environment variable (default: `3000`)
- Auto-restart: enabled
- Logs: `/opt/sbook/frontend/logs/`

## Security Architecture

### Authentication

- JWT tokens (access + refresh)
- Token storage: HTTP-only cookies (recommended) or localStorage
- Automatic token refresh on 401 responses
- WebSocket authentication: JWT in query parameters

### Authorization

- Django permissions system
- REST Framework permissions
- User-level access control (own resources)

### Network Security

- HTTPS/TLS encryption
- CORS configuration (allowed origins)
- Rate limiting on API endpoints
- Input validation and sanitization

### Data Security

- Password hashing (Django default)
- SQL injection protection (ORM)
- XSS protection (bleach for content)
- CSRF protection (Django middleware)

## Scalability

### Current Architecture (Single Server)

- All components on one server
- Suitable for small to medium traffic
- Database and Redis on same server

### Scaling Options

**Horizontal Scaling:**

- Multiple backend instances behind load balancer
- Shared Redis for WebSocket connections
- Database replication (read replicas)

**Vertical Scaling:**

- Increase server resources
- Database connection pooling
- Redis memory optimization

**Caching Strategy:**

- Redis caching layer for frequently accessed data
- CDN for static assets
- Next.js ISR (Incremental Static Regeneration)

## Monitoring and Logging

### Logging

- Structured logging (structlog)
- JSON log format
- Log levels: INFO, WARNING, ERROR
- Log rotation: Supervisor/PM2

### Health Checks

- Backend: `/api/health/` endpoint
- Frontend: Next.js built-in health checks
- Database: Connection pool monitoring
- Redis: Connection status

## Development vs Production

### Development

- Backend: Django development server (port 8000)
- Frontend: Next.js dev server (port 3000)
- Database: Docker Compose (PostgreSQL + Redis)
- Debug mode: enabled

### Production

- Backend: Daphne ASGI server (port 8000, internal)
- Frontend: Next.js production server (port 3000, internal)
- Database: PostgreSQL on server
- Redis: Running on server
- Nginx: Reverse proxy (ports 80/443)
- Debug mode: disabled
- Static files: WhiteNoise (backend) + Nginx (frontend)
