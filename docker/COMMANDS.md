# Docker Commands Reference

Quick reference for common Docker operations for Happy Server.

## Development Environment

### Start Development Stack
```bash
cd docker
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

### View Development Logs
```bash
# All services
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

# Specific service
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f happy-server
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f postgres
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f redis
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f nginx
```

### Stop Development Stack
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down
```

### Rebuild Development Image
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache happy-server
```

### Access Running Container
```bash
# Execute command in happy-server
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec happy-server bash

# Execute command in postgres
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec postgres psql -U happy -d happy_server

# Execute command in redis
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec redis redis-cli
```

### Run Database Migrations
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec happy-server yarn migrate
```

### View Service Status
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml ps
```

---

## Production Environment

### Build Production Image
```bash
cd ..
docker build -f docker/Dockerfile -t happy-server:latest .
docker build -f docker/Dockerfile -t happy-server:1.0.0 .
```

### Start Production Stack
```bash
cd docker
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### View Production Logs
```bash
# All services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs -f

# Specific service
docker-compose -f docker-compose.yml -f docker-compose.prod.yml logs -f happy-server
```

### Stop Production Stack
```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down
```

### Graceful Shutdown
```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down --timeout=30
```

### Run Database Migrations (Production)
```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml exec happy-server yarn migrate
```

### Scale Services (Production)
```bash
# Note: Application state should be stateless for scaling
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d --scale happy-server=3
```

---

## Monitoring & Debugging

### Check Service Health
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml ps

# Example output:
# NAME              COMMAND              SERVICE       STATUS       PORTS
# happy-postgres    postgres             postgres      Up (healthy) 5432/tcp
# happy-redis       redis-server         redis         Up (healthy) 6379/tcp
# happy-minio       minio server /data   minio         Up (healthy) 9000/tcp, 9001/tcp
# happy-server      yarn start           happy-server  Up (healthy) 0.0.0.0:3000->3000/tcp
# happy-nginx       nginx -g daemon off  nginx         Up            0.0.0.0:80->80/tcp
```

### View Container Logs with Timestamps
```bash
# Last 100 lines with timestamps
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs --timestamps --tail=100 happy-server

# Follow logs in real-time
docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f --timestamps happy-server
```

### Inspect Service Configuration
```bash
# View actual running configuration
docker-compose -f docker-compose.yml -f docker-compose.dev.yml config

# View specific service
docker-compose -f docker-compose.yml -f docker-compose.dev.yml config | grep -A 30 "happy-server:"
```

### Check Resource Usage
```bash
# CPU, memory, network I/O
docker stats

# Specific container
docker stats happy-server
```

### View Container Processes
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml top happy-server
```

---

## Database Operations

### PostgreSQL Backup
```bash
# Create backup
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec postgres \
  pg_dump -U happy happy_server > backup.sql

# Restore backup
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec -T postgres \
  psql -U happy happy_server < backup.sql
```

### Connect to PostgreSQL
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec postgres \
  psql -U happy -d happy_server
```

### PostgreSQL Commands
```bash
# List tables
\dt

# Describe table
\d+ table_name

# Run query
SELECT * FROM table_name LIMIT 10;

# Exit
\q
```

### Redis Operations
```bash
# Connect to Redis CLI
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec redis redis-cli

# Get all keys
KEYS *

# Flush all data (WARNING: destroys all data)
FLUSHALL

# Exit
EXIT or CTRL+D
```

### Redis Monitoring
```bash
# Monitor incoming commands in real-time
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec redis redis-cli MONITOR
```

---

## Volume Management

### View Volumes
```bash
docker volume ls | grep happy
```

### Inspect Volume
```bash
docker volume inspect docker_postgres_data
docker volume inspect docker_redis_data
docker volume inspect docker_minio_data
```

### Backup Volume
```bash
# PostgreSQL data
docker run --rm -v docker_postgres_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/postgres_data.tar.gz -C /data .

# Redis data
docker run --rm -v docker_redis_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/redis_data.tar.gz -C /data .
```

### Remove Volumes (WARNING: Deletes all data)
```bash
docker volume rm docker_postgres_data docker_redis_data docker_minio_data
```

---

## Network Debugging

### Check Network
```bash
docker network ls | grep happy
docker network inspect docker_happy-network
```

### Test Connectivity Between Services
```bash
# From happy-server container, test postgres connection
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec happy-server \
  curl -i postgresql://postgres:5432

# Test redis connection
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec happy-server \
  curl -i redis://redis:6379
```

---

## Image Management

### List Images
```bash
docker images | grep happy
```

### Remove Image
```bash
docker rmi happy-server:latest
docker rmi happy-server:1.0.0
```

### Tag Image
```bash
docker tag happy-server:latest myregistry/happy-server:1.0.0
```

### Push to Registry
```bash
docker push myregistry/happy-server:1.0.0
```

### Build with BuildKit
```bash
DOCKER_BUILDKIT=1 docker build -f docker/Dockerfile -t happy-server:latest .
```

---

## Container Cleanup

### Remove Stopped Containers
```bash
docker container prune

# Specific to our compose
docker-compose -f docker-compose.yml down
```

### Remove Unused Images
```bash
docker image prune
docker image prune -a  # Remove all unused images
```

### Remove Unused Volumes
```bash
docker volume prune
```

### Full System Cleanup
```bash
docker system prune -a --volumes
```

---

## Troubleshooting

### Rebuild Everything from Scratch
```bash
# Development
docker-compose -f docker-compose.yml -f docker-compose.dev.yml down -v
docker-compose -f docker-compose.yml -f docker-compose.dev.yml build --no-cache
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml down -v
docker build -f docker/Dockerfile --no-cache -t happy-server:latest .
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Check Dockerfile Syntax
```bash
docker build -f docker/Dockerfile --no-cache --progress=plain -t happy-server:test . 2>&1 | head -50
```

### Docker Compose Validation
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml config --quiet
docker-compose -f docker-compose.yml -f docker-compose.prod.yml config --quiet
```

### View Docker Events
```bash
docker events --filter 'name=happy'
```

### Debug Network Issues
```bash
# Get container IP
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' happy-server

# Ping from another container
docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec happy-server \
  ping postgres
```

---

## Performance Profiling

### Monitor Container Performance
```bash
# Real-time stats
watch -n 1 'docker stats --no-stream'

# CPU and memory usage
docker stats happy-server --no-stream
```

### Check Build Time
```bash
time docker build -f docker/Dockerfile -t happy-server:latest .
```

### View Image Layers
```bash
docker history happy-server:latest
docker history happy-server:latest --no-trunc
```

---

## Update & Maintenance

### Pull Latest Base Images
```bash
docker pull node:20-slim
docker pull postgres:15-alpine
docker pull redis:7-alpine
docker pull minio/minio:latest
docker pull nginx:alpine
```

### Rebuild with Latest Base Images
```bash
docker build -f docker/Dockerfile --pull --no-cache -t happy-server:latest .
```

### Update docker-compose
```bash
# Get latest version
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o docker-compose
chmod +x docker-compose

# Or use Docker plugin (newer versions)
docker compose version
```
