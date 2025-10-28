# Happy Server Docker Deployment Guide

Complete guide for deploying Happy Server using Docker and Docker Compose.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Development Guide](#development-guide)
6. [Production Deployment](#production-deployment)
7. [Service Details](#service-details)
8. [Environment Variables](#environment-variables)
9. [Scripts Reference](#scripts-reference)
10. [Troubleshooting](#troubleshooting)
11. [Advanced Usage](#advanced-usage)
12. [Backup and Restore](#backup-and-restore)

---

## Overview

This Docker setup provides a complete containerized environment for Happy Server with the following services:

- **happy-server**: The main Node.js application (Fastify + Socket.io)
- **postgres**: PostgreSQL database with Prisma ORM
- **redis**: Redis for caching and pub/sub
- **minio**: S3-compatible object storage
- **nginx**: Reverse proxy with WebSocket support
- **pgadmin** (dev only): Database management interface
- **redisinsight** (dev only): Redis monitoring and management

### Architecture Diagram

```
                                    ┌─────────────────┐
                                    │   Internet      │
                                    └────────┬────────┘
                                             │
                                    ┌────────▼────────┐
                                    │     Nginx       │
                                    │  (Port 80/443)  │
                                    └────────┬────────┘
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    │                        │                        │
           ┌────────▼────────┐      ┌───────▼───────┐       ┌───────▼───────┐
           │  Happy Server   │      │   WebSocket   │       │    Static     │
           │   (Fastify)     │      │  (Socket.io)  │       │    Assets     │
           │   Port 3000     │      │               │       │               │
           └────────┬────────┘      └───────────────┘       └───────────────┘
                    │
    ┌───────────────┼───────────────┐
    │               │               │
┌───▼────┐    ┌────▼─────┐    ┌───▼────┐
│ Postgres│   │  Redis   │    │  MinIO │
│ Port 5432│  │ Port 6379│    │Port 9000│
└─────────┘   └──────────┘    └────────┘
```

---

## Prerequisites

### Required Software

- **Docker**: Version 20.10 or higher
- **Docker Compose**: Version 2.0 or higher
- **Git**: For cloning the repository

### System Requirements

**Development:**
- 4GB RAM minimum
- 10GB disk space

**Production:**
- 8GB RAM minimum
- 50GB disk space (depends on data volume)
- SSL certificates (for HTTPS)

### Verify Installation

```bash
docker --version
docker compose version
```

Expected output:
```
Docker version 24.0.0 or higher
Docker Compose version v2.0.0 or higher
```

---

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/slopus/happy-server.git
cd happy-server/docker
```

### 2. Run Setup Script

```bash
./scripts/setup.sh
```

This script will:
- Copy `.env.example` to `.env`
- Create required directories
- Set proper permissions
- Display next steps

### 3. Edit Environment Variables

```bash
nano .env  # or use your preferred editor
```

**Important:** Change at least these values:
- `HANDY_MASTER_SECRET`: Use a strong random value
- `POSTGRES_PASSWORD`: Change from default
- `MINIO_ROOT_PASSWORD`: Change from default

Generate secure secrets:
```bash
openssl rand -base64 32
```

### 4. Start Services

```bash
./scripts/start.sh
```

### 5. Run Database Migrations

```bash
./scripts/migrate.sh
```

### 6. Access Services

- **Happy Server API**: http://localhost:80
- **MinIO Console**: http://localhost:9001
- **pgAdmin** (dev): http://localhost:5050
- **RedisInsight** (dev): http://localhost:8001

---

## Development Guide

### Starting the Stack

```bash
./scripts/start.sh
```

This starts all services in development mode with:
- Hot reloading enabled
- Verbose logging
- Development tools (pgAdmin, RedisInsight)
- CORS enabled
- Extended timeouts for debugging

### Viewing Logs

**All services:**
```bash
./scripts/logs.sh
```

**Specific service:**
```bash
./scripts/logs.sh happy-server
./scripts/logs.sh postgres
./scripts/logs.sh redis
```

**Follow logs in real-time:**
```bash
docker compose logs -f happy-server
```

### Running Database Migrations

**Apply pending migrations:**
```bash
./scripts/migrate.sh
```

**Create a new migration:**
```bash
docker compose exec happy-server yarn migrate:create
```

**Generate Prisma Client:**
```bash
docker compose exec happy-server yarn generate
```

### Accessing Container Shell

**Happy Server:**
```bash
./scripts/shell.sh happy-server
```

**PostgreSQL:**
```bash
./scripts/shell.sh postgres
# Then connect to database:
psql -U happy -d happy_server
```

**Redis:**
```bash
./scripts/shell.sh redis
# Then use Redis CLI:
redis-cli
```

### Stopping Services

**Stop all services:**
```bash
./scripts/stop.sh
```

**Stop specific service:**
```bash
docker compose stop happy-server
```

**Restart a service:**
```bash
docker compose restart happy-server
```

### Cleaning Up

**Remove containers (keeps volumes):**
```bash
docker compose down
```

**Remove containers and volumes (WARNING: deletes data):**
```bash
docker compose down -v
```

**Clean everything including images:**
```bash
./scripts/clean.sh
```

---

## Production Deployment

### Pre-Deployment Checklist

Before deploying to production, ensure you have:

- [ ] Changed all default passwords and secrets
- [ ] Generated strong `HANDY_MASTER_SECRET`
- [ ] Obtained SSL certificates
- [ ] Configured firewall rules
- [ ] Set up monitoring and alerting
- [ ] Configured automated backups
- [ ] Tested disaster recovery procedures
- [ ] Reviewed security settings
- [ ] Disabled development tools (pgAdmin, RedisInsight)
- [ ] Set `NODE_ENV=production`

### SSL Certificate Setup

**Option 1: Let's Encrypt (Recommended)**

```bash
# Install certbot
sudo apt-get update
sudo apt-get install certbot

# Generate certificates
sudo certbot certonly --standalone -d yourdomain.com

# Certificates will be at:
# /etc/letsencrypt/live/yourdomain.com/fullchain.pem
# /etc/letsencrypt/live/yourdomain.com/privkey.pem
```

Update `docker-compose.prod.yml` to mount certificates:
```yaml
volumes:
  - /etc/letsencrypt/live/yourdomain.com/fullchain.pem:/etc/ssl/certs/happy-server.crt:ro
  - /etc/letsencrypt/live/yourdomain.com/privkey.pem:/etc/ssl/private/happy-server.key:ro
```

**Option 2: Self-Signed Certificate (Testing Only)**

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout docker/nginx/ssl/key.pem \
  -out docker/nginx/ssl/cert.pem
```

### Environment Configuration

Create production `.env` file:

```bash
cp .env.example .env.production
nano .env.production
```

**Critical production settings:**

```bash
NODE_ENV=production
HANDY_MASTER_SECRET=<use-openssl-rand-base64-32>
POSTGRES_PASSWORD=<strong-password>
MINIO_ROOT_PASSWORD=<strong-password>
DANGEROUSLY_LOG_TO_SERVER_FOR_AI_AUTO_DEBUGGING=false
```

### Building Production Images

```bash
./scripts/build.sh prod
```

This builds optimized production images with:
- Multi-stage builds
- Minimal base images
- No development dependencies
- Optimized layer caching

### Starting Production Stack

```bash
./scripts/start-prod.sh
```

This uses `docker-compose.prod.yml` which:
- Uses production Nginx configuration
- Enables SSL/HTTPS
- Removes development tools
- Optimizes resource limits
- Enables health checks
- Configures restart policies

### Pushing to Registry

**Docker Hub:**
```bash
./scripts/push.sh
```

**Private Registry:**
```bash
export DOCKER_REGISTRY=registry.yourcompany.com
./scripts/push.sh
```

### Deploying to Server

**Via SSH:**
```bash
# On your local machine
./scripts/build.sh prod
./scripts/push.sh

# On production server
ssh user@production-server
cd /opt/happy-server
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

**Via CI/CD Pipeline:**

Create a `.github/workflows/deploy.yml`:
```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build and push
        run: |
          docker compose -f docker-compose.prod.yml build
          docker compose -f docker-compose.prod.yml push
      - name: Deploy
        run: |
          ssh deploy@server 'cd /opt/happy-server && docker compose -f docker-compose.prod.yml pull && docker compose -f docker-compose.prod.yml up -d'
```

### Monitoring Production

**Check service health:**
```bash
docker compose ps
docker compose -f docker-compose.prod.yml ps
```

**Monitor resource usage:**
```bash
docker stats
```

**Check application logs:**
```bash
docker compose logs -f --tail=100 happy-server
```

**Health check endpoint:**
```bash
curl https://yourdomain.com/health
```

---

## Service Details

### happy-server

The main Node.js application built with Fastify and Socket.io.

**Ports:**
- `3000`: HTTP API
- `9090`: Prometheus metrics

**Health Check:**
```bash
curl http://localhost:3000/health
```

**Environment Variables:**
- `NODE_ENV`: Runtime environment (development/production)
- `PORT`: HTTP server port
- `HANDY_MASTER_SECRET`: Master secret for auth
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis connection string
- `S3_ENDPOINT`: MinIO endpoint
- `S3_ACCESS_KEY`: MinIO access key
- `S3_SECRET_KEY`: MinIO secret key
- `S3_BUCKET`: Default bucket name

**Volumes:**
- `./sources:/app/sources`: Source code (dev only)
- `./.logs:/app/.logs`: Application logs

**Dependencies:**
- PostgreSQL (required)
- Redis (required)
- MinIO (required)

---

### postgres

PostgreSQL 15 database with Prisma ORM.

**Port:** `5432`

**Credentials:**
- Username: `POSTGRES_USER` (default: `happy`)
- Password: `POSTGRES_PASSWORD` (default: `password`)
- Database: `POSTGRES_DB` (default: `happy_server`)

**Connection String:**
```
postgresql://happy:password@localhost:5432/happy_server
```

**Data Persistence:**
- Volume: `postgres_data`
- Location: `/var/lib/postgresql/data`

**Initialization:**
- Script: `docker/postgres/init.sql`
- Extensions: `uuid-ossp`, `pgcrypto`, `citext`

**Accessing Database:**
```bash
# Via psql in container
docker compose exec postgres psql -U happy -d happy_server

# Via pgAdmin
http://localhost:5050
```

**Backup:**
```bash
docker compose exec postgres pg_dump -U happy happy_server > backup.sql
```

**Restore:**
```bash
cat backup.sql | docker compose exec -T postgres psql -U happy happy_server
```

---

### redis

Redis 7 for caching and pub/sub messaging.

**Port:** `6379`

**Connection String:**
```
redis://localhost:6379
```

**Data Persistence:**
- Volume: `redis_data`
- Location: `/data`
- Strategy: AOF (Append-Only File)

**Configuration:**
- Max memory: 256MB
- Eviction policy: `allkeys-lru`

**Accessing Redis:**
```bash
# Via redis-cli in container
docker compose exec redis redis-cli

# Via RedisInsight (dev only)
http://localhost:8001
```

**Common Commands:**
```bash
# Check connection
redis-cli ping

# Monitor commands
redis-cli monitor

# Get all keys
redis-cli keys '*'

# Clear all data (WARNING: destructive)
redis-cli flushall
```

---

### minio

MinIO S3-compatible object storage.

**Ports:**
- `9000`: S3 API
- `9001`: Web Console

**Credentials:**
- Access Key: `MINIO_ROOT_USER` (default: `minioadmin`)
- Secret Key: `MINIO_ROOT_PASSWORD` (default: `minioadmin`)

**Web Console:**
```
http://localhost:9001
```

**Data Persistence:**
- Volume: `minio_data`
- Location: `/data`

**Default Bucket:**
- Name: `S3_BUCKET` (default: `happy-server`)
- Auto-created by `docker/minio/init.sh`

**Initialization:**
```bash
# The init script automatically:
# - Creates default bucket
# - Enables versioning
# - Sets policies (optional)
```

**Using MinIO Client (mc):**
```bash
# Access container
docker compose exec minio sh

# Configure alias
mc alias set happy http://localhost:9000 minioadmin minioadmin

# List buckets
mc ls happy

# Upload file
mc cp file.txt happy/happy-server/

# Download file
mc cp happy/happy-server/file.txt .
```

**AWS CLI Compatibility:**
```bash
aws --endpoint-url http://localhost:9000 \
    --access-key-id minioadmin \
    --secret-access-key minioadmin \
    s3 ls s3://happy-server/
```

---

### nginx

Nginx reverse proxy with WebSocket support and SSL termination.

**Ports:**
- `80`: HTTP (redirects to HTTPS in production)
- `443`: HTTPS (production only)

**Configuration Files:**
- `docker/nginx/nginx.conf`: Base configuration
- `docker/nginx/nginx.dev.conf`: Development overrides
- `docker/nginx/nginx.prod.conf`: Production with SSL

**Features:**
- WebSocket support for Socket.io
- Rate limiting (production)
- Gzip compression
- Static asset caching
- Security headers
- SSL/TLS termination (production)

**Logs:**
```bash
docker compose logs nginx
```

**Reload Configuration:**
```bash
docker compose exec nginx nginx -s reload
```

**Test Configuration:**
```bash
docker compose exec nginx nginx -t
```

---

### pgadmin (Development Only)

Web-based PostgreSQL management interface.

**Port:** `5050`

**Credentials:**
- Email: `PGADMIN_DEFAULT_EMAIL` (default: `admin@happy.local`)
- Password: `PGADMIN_DEFAULT_PASSWORD` (default: `admin`)

**Access:**
```
http://localhost:5050
```

**Adding Server:**
1. Log in to pgAdmin
2. Right-click "Servers" → "Create" → "Server"
3. General tab: Name = `Happy Server`
4. Connection tab:
   - Host: `postgres`
   - Port: `5432`
   - Database: `happy_server`
   - Username: `happy`
   - Password: `password`
5. Click "Save"

**Note:** Disabled in production for security.

---

### redisinsight (Development Only)

Redis monitoring and management interface.

**Port:** `8001`

**Access:**
```
http://localhost:8001
```

**Adding Connection:**
1. Open RedisInsight
2. Click "Add Redis Database"
3. Connection Details:
   - Host: `redis`
   - Port: `6379`
   - Name: `Happy Server Redis`
4. Click "Add Database"

**Note:** Disabled in production for security.

---

## Environment Variables

### Complete Reference

#### Application Settings

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `NODE_ENV` | No | `development` | Runtime environment (development, production, test) |
| `PORT` | No | `3000` | Happy Server HTTP port |
| `HANDY_MASTER_SECRET` | Yes | - | Master secret for authentication and encryption |
| `METRICS_PORT` | No | `9090` | Prometheus metrics endpoint port |

#### Database Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | Yes | - | Full PostgreSQL connection string |
| `POSTGRES_DB` | Yes | `happy_server` | PostgreSQL database name |
| `POSTGRES_USER` | Yes | `happy` | PostgreSQL username |
| `POSTGRES_PASSWORD` | Yes | - | PostgreSQL password |

#### Redis Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `REDIS_URL` | Yes | `redis://redis:6379` | Redis connection string |

#### S3/MinIO Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `S3_ENDPOINT` | Yes | `http://minio:9000` | S3-compatible storage endpoint |
| `S3_ACCESS_KEY` | Yes | `minioadmin` | S3 access key |
| `S3_SECRET_KEY` | Yes | `minioadmin` | S3 secret key |
| `S3_BUCKET` | Yes | `happy-server` | Default bucket name |
| `S3_REGION` | No | `us-east-1` | AWS region (for compatibility) |
| `MINIO_ROOT_USER` | Yes | `minioadmin` | MinIO admin username |
| `MINIO_ROOT_PASSWORD` | Yes | `minioadmin` | MinIO admin password (min 8 chars) |

#### Development Tools

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PGADMIN_DEFAULT_EMAIL` | No | `admin@happy.local` | pgAdmin login email |
| `PGADMIN_DEFAULT_PASSWORD` | No | `admin` | pgAdmin login password |

#### Optional Features

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DANGEROUSLY_LOG_TO_SERVER_FOR_AI_AUTO_DEBUGGING` | No | `false` | Enable remote logging (DEBUG ONLY) |

#### Production Settings

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SSL_CERT_PATH` | Prod Only | - | Path to SSL certificate |
| `SSL_KEY_PATH` | Prod Only | - | Path to SSL private key |
| `TRUSTED_PROXY_IPS` | No | - | Comma-separated list of trusted proxy IPs |

### Security Notes

1. **Always change default passwords in production**
2. **Use strong secrets** (32+ random characters)
3. **Never commit `.env` to version control**
4. **Rotate secrets regularly**
5. **Use environment-specific `.env` files**
6. **Disable debug logging in production**

---

## Scripts Reference

All scripts are located in `docker/scripts/` directory.

| Script | Description | Usage |
|--------|-------------|-------|
| `setup.sh` | Initial setup and configuration | `./scripts/setup.sh` |
| `start.sh` | Start development stack | `./scripts/start.sh` |
| `start-prod.sh` | Start production stack | `./scripts/start-prod.sh` |
| `stop.sh` | Stop all services | `./scripts/stop.sh` |
| `logs.sh` | View service logs | `./scripts/logs.sh [service]` |
| `shell.sh` | Access container shell | `./scripts/shell.sh <service>` |
| `migrate.sh` | Run database migrations | `./scripts/migrate.sh` |
| `build.sh` | Build Docker images | `./scripts/build.sh [dev\|prod]` |
| `push.sh` | Push images to registry | `./scripts/push.sh` |
| `clean.sh` | Clean up containers and images | `./scripts/clean.sh` |
| `backup.sh` | Backup database and files | `./scripts/backup.sh` |
| `restore.sh` | Restore from backup | `./scripts/restore.sh <backup-file>` |

### Script Examples

**View logs for specific service:**
```bash
./scripts/logs.sh happy-server
```

**Shell access to Happy Server:**
```bash
./scripts/shell.sh happy-server
```

**Build production images:**
```bash
./scripts/build.sh prod
```

**Backup database:**
```bash
./scripts/backup.sh
```

---

## Troubleshooting

### Common Issues

#### 1. Services Not Starting

**Symptoms:**
- Containers exit immediately
- Error messages in logs

**Solutions:**

```bash
# Check service status
docker compose ps

# View logs
./scripts/logs.sh

# Check for port conflicts
lsof -i :80
lsof -i :5432

# Restart services
docker compose down
docker compose up -d
```

#### 2. Database Connection Failed

**Symptoms:**
- `ECONNREFUSED` errors
- "Response from the Engine was empty"

**Solutions:**

```bash
# Check if PostgreSQL is running
docker compose ps postgres

# Verify connection string
docker compose exec happy-server printenv DATABASE_URL

# Test connection
docker compose exec postgres pg_isready -U happy

# Check PostgreSQL logs
docker compose logs postgres

# Restart PostgreSQL
docker compose restart postgres
```

#### 3. Migrations Failing

**Symptoms:**
- Migration errors during startup
- Schema mismatch

**Solutions:**

```bash
# Check migration status
docker compose exec happy-server yarn prisma migrate status

# Reset database (WARNING: deletes data)
docker compose exec happy-server yarn prisma migrate reset

# Apply migrations manually
./scripts/migrate.sh

# Generate Prisma client
docker compose exec happy-server yarn generate
```

#### 4. Redis Connection Issues

**Symptoms:**
- Event bus not working
- Caching failures

**Solutions:**

```bash
# Check Redis status
docker compose ps redis

# Test connection
docker compose exec redis redis-cli ping

# View Redis logs
docker compose logs redis

# Clear Redis data
docker compose exec redis redis-cli flushall
```

#### 5. MinIO/S3 Upload Failures

**Symptoms:**
- File upload errors
- "Bucket not found"

**Solutions:**

```bash
# Check MinIO status
docker compose ps minio

# Verify bucket exists
docker compose exec minio mc ls happy

# Recreate bucket
docker compose exec minio mc mb happy/happy-server

# Check credentials
docker compose exec happy-server printenv | grep S3_
```

#### 6. WebSocket Connection Dropping

**Symptoms:**
- "User disconnected" messages
- Socket instability

**Solutions:**

```bash
# Check Nginx configuration
docker compose exec nginx nginx -t

# View Nginx logs
docker compose logs nginx

# Increase timeouts in nginx.conf
# proxy_read_timeout 7d;
# proxy_send_timeout 7d;

# Reload Nginx
docker compose exec nginx nginx -s reload
```

#### 7. High Memory Usage

**Symptoms:**
- Services becoming slow
- OOM (Out of Memory) errors

**Solutions:**

```bash
# Check resource usage
docker stats

# Limit service memory
# In docker-compose.yml:
# deploy:
#   resources:
#     limits:
#       memory: 512M

# Clear Redis cache
docker compose exec redis redis-cli flushall

# Restart services
docker compose restart
```

### Health Check Commands

```bash
# Check all service status
docker compose ps

# Happy Server health
curl http://localhost/health

# PostgreSQL health
docker compose exec postgres pg_isready -U happy

# Redis health
docker compose exec redis redis-cli ping

# MinIO health
curl http://localhost:9000/minio/health/live

# Nginx health
docker compose exec nginx nginx -t
```

### Log Locations

**Container logs:**
```bash
docker compose logs [service]
```

**Application logs:**
```bash
# Happy Server logs (if DANGEROUSLY_LOG_TO_SERVER_FOR_AI_AUTO_DEBUGGING=true)
tail -f .logs/*.log
```

**Nginx logs:**
```bash
docker compose exec nginx tail -f /var/log/nginx/access.log
docker compose exec nginx tail -f /var/log/nginx/error.log
```

### Getting Help

1. **Check logs first:**
   ```bash
   ./scripts/logs.sh
   ```

2. **Verify configuration:**
   ```bash
   cat .env
   docker compose config
   ```

3. **Check documentation:**
   - [Happy Server GitHub](https://github.com/slopus/happy-server)
   - [Docker Documentation](https://docs.docker.com)
   - [Nginx Documentation](https://nginx.org/en/docs/)

4. **Search for similar issues:**
   - GitHub Issues
   - Stack Overflow
   - Docker Community Forums

---

## Advanced Usage

### Scaling Services

**Scale Happy Server horizontally:**

```yaml
# docker-compose.yml
services:
  happy-server:
    deploy:
      replicas: 3
```

Or dynamically:
```bash
docker compose up -d --scale happy-server=3
```

**Update Nginx upstream:**
```nginx
upstream happy_server {
    server happy-server:3000;
    # Add more instances
    server happy-server-2:3000;
    server happy-server-3:3000;
}
```

### Custom Nginx Configuration

**Override configuration:**

```yaml
# docker-compose.override.yml
services:
  nginx:
    volumes:
      - ./my-nginx.conf:/etc/nginx/nginx.conf:ro
```

**Add custom locations:**

Create `docker/nginx/custom.conf`:
```nginx
location /custom {
    proxy_pass http://custom-service:8080;
}
```

Mount in docker-compose.yml:
```yaml
volumes:
  - ./docker/nginx/custom.conf:/etc/nginx/conf.d/custom.conf:ro
```

### Database Performance Tuning

**PostgreSQL settings:**

Create `docker/postgres/postgresql.conf`:
```
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 4MB
min_wal_size = 1GB
max_wal_size = 4GB
```

Mount in docker-compose.yml:
```yaml
services:
  postgres:
    volumes:
      - ./docker/postgres/postgresql.conf:/etc/postgresql/postgresql.conf:ro
    command: postgres -c config_file=/etc/postgresql/postgresql.conf
```

### Redis Configuration

**Custom Redis config:**

Create `docker/redis/redis.conf`:
```
maxmemory 512mb
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec
save 900 1
save 300 10
save 60 10000
```

Mount in docker-compose.yml:
```yaml
services:
  redis:
    volumes:
      - ./docker/redis/redis.conf:/usr/local/etc/redis/redis.conf:ro
    command: redis-server /usr/local/etc/redis/redis.conf
```

### Monitoring with Prometheus

**Add Prometheus service:**

```yaml
# docker-compose.monitoring.yml
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9091:9090"
    volumes:
      - ./docker/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'

volumes:
  prometheus_data:
```

**Prometheus config:**

Create `docker/prometheus/prometheus.yml`:
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'happy-server'
    static_configs:
      - targets: ['happy-server:9090']
```

### Network Optimization

**Custom Docker network:**

```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No external access

services:
  nginx:
    networks:
      - frontend
      - backend

  happy-server:
    networks:
      - backend

  postgres:
    networks:
      - backend
```

---

## Backup and Restore

### Automated Backups

**Backup script (`docker/scripts/backup.sh`):**

```bash
#!/bin/bash
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup PostgreSQL
docker compose exec -T postgres pg_dump -U happy happy_server > \
    $BACKUP_DIR/postgres_$TIMESTAMP.sql

# Backup MinIO
docker compose exec minio mc mirror happy/happy-server \
    $BACKUP_DIR/minio_$TIMESTAMP/

# Backup Redis (if needed)
docker compose exec redis redis-cli --rdb /data/dump.rdb
docker cp $(docker compose ps -q redis):/data/dump.rdb \
    $BACKUP_DIR/redis_$TIMESTAMP.rdb

echo "Backup completed: $TIMESTAMP"
```

### Restore from Backup

**Restore script (`docker/scripts/restore.sh`):**

```bash
#!/bin/bash
BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: ./restore.sh <backup-file>"
    exit 1
fi

# Restore PostgreSQL
cat $BACKUP_FILE | docker compose exec -T postgres psql -U happy happy_server

echo "Restore completed"
```

### Continuous Backups

**Cron job for daily backups:**

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /path/to/happy-server/docker && ./scripts/backup.sh
```

### Backup Best Practices

1. **Backup regularly** (at least daily for production)
2. **Store backups off-site** (S3, cloud storage)
3. **Test restores periodically**
4. **Keep multiple backup generations**
5. **Document restore procedures**
6. **Encrypt sensitive backups**
7. **Monitor backup success**

---

## Security Best Practices

### Production Security Checklist

- [ ] Change all default passwords
- [ ] Use strong random secrets (32+ characters)
- [ ] Enable SSL/HTTPS with valid certificates
- [ ] Configure firewall rules
- [ ] Limit container resource usage
- [ ] Use Docker secrets for sensitive data
- [ ] Regularly update base images
- [ ] Scan images for vulnerabilities
- [ ] Disable unnecessary services (pgadmin, redisinsight)
- [ ] Configure rate limiting
- [ ] Enable security headers
- [ ] Set up intrusion detection
- [ ] Implement proper logging and monitoring
- [ ] Restrict network access between services
- [ ] Use read-only volumes where possible

### Docker Security

**Use Docker secrets:**

```yaml
secrets:
  db_password:
    file: ./secrets/db_password.txt

services:
  happy-server:
    secrets:
      - db_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
```

**Run as non-root:**

```dockerfile
USER node
```

**Read-only filesystem:**

```yaml
services:
  happy-server:
    read_only: true
    tmpfs:
      - /tmp
```

---

## Performance Optimization

### Database Optimization

1. **Connection pooling** (already configured in Prisma)
2. **Indexing** (add indexes for frequently queried columns)
3. **Query optimization** (use `EXPLAIN ANALYZE`)
4. **Regular VACUUM** (automatic in PostgreSQL)

### Redis Optimization

1. **Memory management** (set appropriate maxmemory)
2. **Eviction policy** (allkeys-lru for cache)
3. **Persistence** (AOF for durability, RDB for backups)
4. **Connection pooling** (in application code)

### Nginx Optimization

1. **Worker processes** (auto scales with CPU cores)
2. **Connection limits** (worker_connections)
3. **Buffer sizes** (optimize for your use case)
4. **Caching** (static assets, API responses)
5. **Gzip compression** (reduce bandwidth)

### Application Optimization

1. **Horizontal scaling** (multiple Happy Server instances)
2. **Load balancing** (Nginx upstream)
3. **Async operations** (already using Fastify's async patterns)
4. **Caching strategy** (Redis for frequently accessed data)
5. **CDN integration** (for static assets)

---

## Additional Resources

### Documentation Links

- [Happy Server GitHub](https://github.com/slopus/happy-server)
- [Docker Documentation](https://docs.docker.com)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/documentation)
- [MinIO Documentation](https://docs.min.io/)
- [Fastify Documentation](https://www.fastify.io/docs/latest/)
- [Prisma Documentation](https://www.prisma.io/docs/)

### Community

- [Happy Server Discussions](https://github.com/slopus/happy-server/discussions)
- [Docker Community Forums](https://forums.docker.com/)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/docker)

---

## License

This Docker configuration is part of Happy Server, licensed under MIT License.

---

## Support

For issues, questions, or contributions:

1. **GitHub Issues**: [Report bugs or request features](https://github.com/slopus/happy-server/issues)
2. **GitHub Discussions**: [Ask questions or share ideas](https://github.com/slopus/happy-server/discussions)
3. **Documentation**: Review this README and other docs in the repository

---

**Last Updated**: 2025-10-28

**Version**: 1.0.0
