# Happy Server Docker Infrastructure

This directory contains complete Docker infrastructure for the Happy Server application with multi-stage production builds, comprehensive compose configurations, and Nginx reverse proxy setup.

## Files Overview

### Core Docker Files

1. **Dockerfile** - Multi-stage optimized build
   - Stage 1 (builder): Node 20-slim, installs FFmpeg/Python3, runs `yarn install` and `yarn generate`
   - Stage 2 (runner): Minimal runtime image with non-root user
   - Exposes ports 3000 (API) and 9090 (metrics)
   - Includes health checks on /health endpoint
   - Optimized layer caching for faster builds

2. **.dockerignore** - Build context optimization
   - Excludes unnecessary files (node_modules, .git, logs, test files, etc.)
   - Reduces build context size for faster builds

3. **docker-compose.yml** - Base production-ready configuration
   - PostgreSQL 15 with health checks
   - Redis 7 with health checks
   - MinIO S3-compatible storage
   - Happy Server application
   - Nginx reverse proxy
   - All services on dedicated bridge network (happy-network)
   - Proper dependency ordering with health conditions

4. **docker-compose.dev.yml** - Development overrides
   - Volume mounts for live code reloading (`..:/app`)
   - Exposed database ports (5432, 6379)
   - PgAdmin for database management (port 5050)
   - RedisInsight for Redis administration (port 8001)
   - NODE_ENV=development
   - Debug port exposure (9229)

5. **docker-compose.prod.yml** - Production optimizations
   - Resource limits (memory and CPU per service)
   - Optimized PostgreSQL configuration (shared_buffers, max_connections)
   - Redis memory policies and limits
   - Structured logging with rotation
   - Restart policies set to 'always'
   - No volume mounts or debug ports
   - Non-root user for security

### Nginx Configuration

1. **nginx/nginx.conf** - Base HTTP configuration
   - Load balancing with least_conn algorithm
   - WebSocket support with long timeouts
   - Rate limiting zones for general traffic
   - Gzip compression
   - Security headers
   - Socket.io specific routing

2. **nginx/nginx.dev.conf** - Development overrides
   - Disabled caching and gzip for easier debugging
   - Verbose logging with timing information
   - CORS headers for cross-origin development
   - Extended proxy timeouts (300s)
   - Debug-friendly configuration

3. **nginx/nginx.prod.conf** - Production hardened
   - SSL/TLS with TLSv1.2 and TLSv1.3
   - HTTP to HTTPS redirect
   - Strict rate limiting (5r/m for auth, 10r/s for API)
   - Connection limits
   - Advanced security headers including CSP
   - HSTS with preload
   - SSL stapling configuration
   - Optimized buffer settings

## Quick Start

### Development Setup

```bash
# Start all services with development overrides
docker-compose -f docker/docker-compose.yml -f docker/docker-compose.dev.yml up -d

# Check service status
docker-compose -f docker/docker-compose.yml -f docker/docker-compose.dev.yml ps

# View logs
docker-compose -f docker/docker-compose.yml -f docker/docker-compose.dev.yml logs -f happy-server

# Access services:
# - API: http://localhost:3000
# - Database: localhost:5432 (user: happy, pass: password)
# - Redis: localhost:6379
# - MinIO Console: http://localhost:9001 (user: minioadmin, pass: minioadmin)
# - PgAdmin: http://localhost:5050 (admin@happy.local / admin)
# - RedisInsight: http://localhost:8001
```

### Production Setup

```bash
# Build the image
docker build -f docker/Dockerfile -t happy-server:latest .

# Start services with production overrides
docker-compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml up -d

# Configure SSL certificates (required for HTTPS)
# Copy your certificates to docker/nginx/ssl/:
#   - ssl/cert.pem (public certificate)
#   - ssl/key.pem (private key)

# Check service status
docker-compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml ps

# View logs
docker-compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml logs -f
```

## Environment Variables

All environment variables are configured in `docker-compose.yml`. Override them by creating a `.env` file:

```env
# Database
POSTGRES_DB=happy_server
POSTGRES_USER=happy
POSTGRES_PASSWORD=your_secure_password

# Application
PORT=3000
HANDY_MASTER_SECRET=your_super_secret_key
NODE_ENV=production

# Redis
REDIS_PORT=6379

# S3/MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin
MINIO_API_PORT=9000
MINIO_CONSOLE_PORT=9001
S3_BUCKET=happy
S3_PUBLIC_URL=http://localhost:9000/happy

# Metrics
METRICS_ENABLED=true
METRICS_PORT=9090

# Logging
DANGEROUSLY_LOG_TO_SERVER_FOR_AI_AUTO_DEBUGGING=false
```

## Health Checks

All services include health checks:

- **PostgreSQL**: Uses `pg_isready` (30s interval, 10s timeout, 3 retries)
- **Redis**: Uses `redis-cli ping` (30s interval, 10s timeout, 3 retries)
- **MinIO**: Uses HTTP health endpoint (30s interval, 10s timeout, 3 retries)
- **Happy Server**: Uses `/health` HTTP endpoint (30s interval, 10s timeout, 3 retries)

Application only starts when dependencies are healthy (`condition: service_healthy`).

## Architecture

### Network
- All services connected via `happy-network` bridge network
- Enables service-to-service communication using service names
- Database URL: `postgresql://happy:password@postgres:5432/happy_server`
- Redis URL: `redis://redis:6379`
- S3 Endpoint: `http://minio:9000`

### Volumes
- `postgres_data`: PostgreSQL data persistence
- `redis_data`: Redis data persistence
- `minio_data`: MinIO object storage

### Service Dependencies
```
happy-server -> postgres (healthy)
happy-server -> redis (healthy)
happy-server -> minio (healthy)
nginx -> happy-server
```

## Building the Image

### For Local Development
```bash
# Building with development context (larger image)
docker build -f docker/Dockerfile -t happy-server:dev .
```

### For Production
```bash
# Building with production optimizations
docker build -f docker/Dockerfile \
  --build-arg NODE_ENV=production \
  -t happy-server:latest .
```

## Troubleshooting

### Containers won't start
```bash
# Check logs
docker-compose -f docker/docker-compose.yml logs

# Verify health status
docker-compose -f docker/docker-compose.yml ps

# Rebuild images
docker-compose -f docker/docker-compose.yml build --no-cache
```

### Database connection issues
```bash
# Check PostgreSQL is ready
docker-compose -f docker/docker-compose.yml exec postgres pg_isready -U happy

# Check if database exists
docker-compose -f docker/docker-compose.yml exec postgres psql -U happy -d happy_server -c "\dt"
```

### Redis connection issues
```bash
# Test Redis connectivity
docker-compose -f docker/docker-compose.yml exec redis redis-cli ping

# Check Redis info
docker-compose -f docker/docker-compose.yml exec redis redis-cli info server
```

### Nginx routing issues
```bash
# Verify upstream configuration
docker-compose -f docker/docker-compose.yml exec nginx nginx -T

# Check proxy logs
docker-compose -f docker/docker-compose.yml logs nginx
```

## Production SSL/TLS Setup

1. Obtain SSL certificates from Let's Encrypt or your provider
2. Create `docker/nginx/ssl/` directory:
   ```bash
   mkdir -p docker/nginx/ssl
   ```
3. Place certificate and key:
   - `ssl/cert.pem` - Full certificate chain
   - `ssl/key.pem` - Private key
4. Update nginx.prod.conf certificate paths if needed
5. Restart Nginx:
   ```bash
   docker-compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml restart nginx
   ```

## Performance Notes

- Multi-stage Dockerfile minimizes final image size
- Non-root user improves security
- Health checks ensure service readiness
- Rate limiting protects API endpoints
- Nginx gzip compression reduces bandwidth
- Connection pooling with Redis and PostgreSQL
- Least-conn load balancing for optimal distribution

## Database Migrations

Run migrations before starting the application:

```bash
# In development (if using local database)
docker-compose -f docker/docker-compose.yml -f docker/docker-compose.dev.yml exec \
  happy-server yarn migrate

# In production
docker-compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml exec \
  happy-server yarn migrate
```

## Security Considerations

- Containers run as non-root user (node:1000)
- Sensitive environment variables via .env file
- Database ports not exposed in production
- Rate limiting enabled for API endpoints
- Security headers configured in Nginx
- HTTPS enforced in production
- SSL/TLS with modern ciphers
- Health checks validate service readiness
