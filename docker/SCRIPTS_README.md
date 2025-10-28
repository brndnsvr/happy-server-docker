# Happy Server Docker Scripts

Production-ready bash scripts for managing Happy Server Docker environment.

## Scripts Overview

All scripts are located in `docker/scripts/` and are fully executable.

### 1. **setup.sh** - Initial Setup
Initializes Docker environment with prerequisites checks and configuration.

```bash
./docker/scripts/setup.sh
```

**What it does:**
- Checks Docker and Docker Compose installation
- Sets up `.env` configuration file
- Builds Docker images
- Displays next steps and service URLs

**When to use:**
- First time setup after cloning the repository
- Setting up development environment on a new machine

---

### 2. **build.sh** - Build Images
Builds Docker images for development or production.

```bash
./docker/scripts/build.sh [environment]
./docker/scripts/build.sh        # Build dev (default)
./docker/scripts/build.sh prod   # Build production
```

**What it does:**
- Validates environment argument
- Builds optimized Docker images
- Displays image sizes and build summary
- Shows next steps

**When to use:**
- After updating dependencies in `package.json`
- After modifying Dockerfile
- Before deploying to production

---

### 3. **start.sh** - Start Development Environment
Starts all development services.

```bash
./docker/scripts/start.sh
```

**What it does:**
- Checks prerequisites (Docker, .env file)
- Starts all containers (app, database, redis, etc.)
- Waits for services to be healthy
- Displays service URLs and helpful commands

**Services started:**
- Happy Server API (port 3005)
- PostgreSQL (port 5432)
- Redis (port 6379)
- MinIO S3 (port 9000)
- PgAdmin (port 5050)
- Redis Insight (port 8001)
- MinIO Console (port 9001)

---

### 4. **start-prod.sh** - Start Production Environment
Starts production-optimized environment.

```bash
./docker/scripts/start-prod.sh
```

**What it does:**
- Validates production configuration
- Starts production containers
- Shows security reminders
- Displays app URL only (cleaner output)

**Important:**
- Checks HANDY_MASTER_SECRET is configured
- Shows production checklist
- Includes security best practices reminder

---

### 5. **stop.sh** - Stop Containers
Stops running containers gracefully.

```bash
./docker/scripts/stop.sh              # Stop containers
./docker/scripts/stop.sh --volumes    # Stop and remove volumes
```

**What it does:**
- Gracefully stops all containers
- Optionally removes volumes (--volumes flag)
- Preserves images for faster restart
- Shows preserved data info

**Options:**
- `--volumes`: Also remove volumes (data will be deleted)

---

### 6. **clean.sh** - Clean All Resources
Completely removes all Docker resources (destructive!).

```bash
./docker/scripts/clean.sh
```

**What it does:**
- Shows destructive operation warning
- Requires double confirmation
- Removes containers, volumes, networks, images
- Cleans up dangling resources

**Warning:** This cannot be undone!

---

### 7. **migrate.sh** - Database Migrations
Runs Prisma database migrations.

```bash
./docker/scripts/migrate.sh
```

**What it does:**
- Checks if database is running (starts if needed)
- Waits for database to be ready
- Executes pending migrations
- Shows migration status
- Shows helpful information

**When to use:**
- First time setup (after setup.sh)
- After pulling code with new migrations
- After schema changes

---

### 8. **logs.sh** - View Container Logs
Displays logs from Docker containers.

```bash
./docker/scripts/logs.sh                    # All services
./docker/scripts/logs.sh happy-server       # App only
./docker/scripts/logs.sh happy-server -f    # Follow app logs
./docker/scripts/logs.sh postgres -n 50     # Last 50 lines
```

**Services available:**
- happy-server (application)
- postgres (database)
- redis (cache)
- minio (object storage)
- nginx (reverse proxy)
- pgadmin (database UI)
- redisinsight (redis UI)

**Options:**
- `-f, --follow`: Follow logs in real-time
- `-n, --lines N`: Show last N lines
- `--tail N`: Same as -n

---

### 9. **push.sh** - Push to Docker Registry
Builds and pushes image to Docker registry.

```bash
./docker/scripts/push.sh <registry> [tag]
./docker/scripts/push.sh docker.io/username          # Latest tag
./docker/scripts/push.sh ghcr.io/org v1.0.0          # Specific tag
```

**What it does:**
- Validates registry path
- Checks Docker authentication
- Builds optimized production image
- Tags image for registry
- Pushes to Docker registry
- Shows image details and next steps

**Requirements:**
- Docker authentication configured (`docker login`)
- Write access to registry

---

## Quick Start Guide

### First Time Setup (5 minutes)

```bash
# 1. Run initial setup
./docker/scripts/setup.sh

# 2. Start services
./docker/scripts/start.sh

# 3. Run migrations
./docker/scripts/migrate.sh

# 4. View logs
./docker/scripts/logs.sh happy-server -f
```

### Daily Development Workflow

```bash
# Start your day
./docker/scripts/start.sh

# View logs while developing
./docker/scripts/logs.sh happy-server -f

# When done, stop services
./docker/scripts/stop.sh
```

### Database Debugging

```bash
# View database logs
./docker/scripts/logs.sh postgres -f

# View database logs with filtering
./docker/scripts/logs.sh postgres | grep error

# Monitor queries
./docker/scripts/logs.sh postgres -n 200
```

### Production Deployment

```bash
# Build production image
./docker/scripts/build.sh prod

# Push to registry
./docker/scripts/push.sh docker.io/username v1.0.0

# Or start production environment locally
./docker/scripts/start-prod.sh
```

---

## Script Features

### Quality Standards

- ✓ Production-ready code quality
- ✓ Comprehensive error handling
- ✓ Color-coded output (green=success, red=error, yellow=warning, blue=info)
- ✓ Helpful usage messages and tips
- ✓ Prerequisite validation
- ✓ Bash syntax validation passes
- ✓ Proper shebang and set -e

### User Experience

- ✓ Clear, descriptive output
- ✓ Progress indicators for long operations
- ✓ Helpful next-step suggestions
- ✓ Context-aware error messages
- ✓ Inline help with -h/--help flags
- ✓ Service status display
- ✓ Colored output for easy scanning

### Reliability

- ✓ Prerequisite checks before running
- ✓ Graceful error handling
- ✓ Service health checks
- ✓ Timeout handling
- ✓ Clear failure messages with solutions
- ✓ Double-confirmation for destructive operations

---

## Common Tasks

### I want to see what's happening in the app
```bash
./docker/scripts/logs.sh happy-server -f
```

### I want to restart everything
```bash
./docker/scripts/stop.sh
./docker/scripts/start.sh
```

### I want to check if database is responding
```bash
./docker/scripts/logs.sh postgres -n 50
```

### I accidentally stopped everything and need to restart
```bash
./docker/scripts/start.sh
```

### I want to see all running services
```bash
./docker/scripts/logs.sh
# Or: ./docker/scripts/start.sh (shows status)
```

### I'm deploying to production
```bash
./docker/scripts/push.sh docker.io/myuser v1.0.0
```

### I want to clean everything and start fresh
```bash
./docker/scripts/clean.sh  # Warning: deletes all data!
./docker/scripts/setup.sh  # Setup again
```

---

## File Locations

All scripts are in:
```
docker/scripts/
├── setup.sh          # 5.2 KB - Initial setup
├── build.sh          # 5.0 KB - Build images
├── start.sh          # 6.0 KB - Start dev environment
├── start-prod.sh     # 6.6 KB - Start prod environment
├── stop.sh           # 4.8 KB - Stop containers
├── clean.sh          # 4.6 KB - Clean all resources
├── migrate.sh        # 6.1 KB - Run migrations
├── logs.sh           # 6.8 KB - View logs
└── push.sh           # 9.7 KB - Push to registry
```

---

## Troubleshooting

### "Docker is not running"
Start Docker Desktop or Docker daemon.

### ".env file not found"
Run `./docker/scripts/setup.sh` first.

### "Database is not responding"
Run `./docker/scripts/logs.sh postgres -f` to debug.

### "Port already in use"
Check for other services: `lsof -i :3005` (for app port).

### "Build failed"
Check Docker disk space: `docker system df`.

### "Image push failed"
Verify authentication: `docker login <registry>`.

---

## Support

For issues with scripts:
1. Check error message
2. Review prerequisites
3. Check logs with `./docker/scripts/logs.sh`
4. Consult CLAUDE.md for project-specific info
5. Review script help with `-h` flag

