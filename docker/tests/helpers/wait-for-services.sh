#!/bin/bash

# wait-for-services.sh - Service readiness polling utilities
# Provides functions to wait for various services to be ready

# Source test helpers for logging
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

# Default timeout
DEFAULT_TIMEOUT=60

#######################################
# Wait for TCP port to be available
# Arguments:
#   $1 - Host
#   $2 - Port
#   $3 - Timeout in seconds (default: 60)
# Returns:
#   0 if port is open, 1 if timeout
#######################################
wait_for_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-$DEFAULT_TIMEOUT}"
    local elapsed=0

    log_info "Waiting for $host:$port to be available..."

    while [ $elapsed -lt $timeout ]; do
        # Try to connect to the port
        if timeout 1 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
            log_pass "$host:$port is available"
            return 0
        fi

        sleep 2
        ((elapsed+=2))

        # Show progress every 10 seconds
        if [ $((elapsed % 10)) -eq 0 ]; then
            log_info "Still waiting for $host:$port... (${elapsed}s/${timeout}s)"
        fi
    done

    log_error "$host:$port not available after ${timeout}s"
    return 1
}

#######################################
# Wait for PostgreSQL to be ready
# Arguments:
#   $1 - Timeout in seconds (default: 60)
# Returns:
#   0 if ready, 1 if timeout
#######################################
wait_for_postgres() {
    local timeout="${1:-$DEFAULT_TIMEOUT}"
    local elapsed=0
    local container="postgres"

    log_info "Waiting for PostgreSQL to be ready..."

    while [ $elapsed -lt $timeout ]; do
        # Check if container exists
        if ! container_exists "$container"; then
            log_error "PostgreSQL container not found"
            return 1
        fi

        # Try to connect using pg_isready
        if docker exec "$container" pg_isready -U postgres >/dev/null 2>&1; then
            log_pass "PostgreSQL is ready"
            return 0
        fi

        sleep 2
        ((elapsed+=2))

        # Show progress every 10 seconds
        if [ $((elapsed % 10)) -eq 0 ]; then
            log_info "Still waiting for PostgreSQL... (${elapsed}s/${timeout}s)"
        fi
    done

    log_error "PostgreSQL not ready after ${timeout}s"
    get_container_logs "$container" 20
    return 1
}

#######################################
# Wait for Redis to be ready
# Arguments:
#   $1 - Timeout in seconds (default: 60)
# Returns:
#   0 if ready, 1 if timeout
#######################################
wait_for_redis() {
    local timeout="${1:-$DEFAULT_TIMEOUT}"
    local elapsed=0
    local container="redis"

    log_info "Waiting for Redis to be ready..."

    while [ $elapsed -lt $timeout ]; do
        # Check if container exists
        if ! container_exists "$container"; then
            log_error "Redis container not found"
            return 1
        fi

        # Try to ping Redis
        if docker exec "$container" redis-cli ping 2>/dev/null | grep -q "PONG"; then
            log_pass "Redis is ready"
            return 0
        fi

        sleep 2
        ((elapsed+=2))

        # Show progress every 10 seconds
        if [ $((elapsed % 10)) -eq 0 ]; then
            log_info "Still waiting for Redis... (${elapsed}s/${timeout}s)"
        fi
    done

    log_error "Redis not ready after ${timeout}s"
    get_container_logs "$container" 20
    return 1
}

#######################################
# Wait for MinIO to be ready
# Arguments:
#   $1 - Timeout in seconds (default: 60)
# Returns:
#   0 if ready, 1 if timeout
#######################################
wait_for_minio() {
    local timeout="${1:-$DEFAULT_TIMEOUT}"
    local elapsed=0
    local container="minio"

    log_info "Waiting for MinIO to be ready..."

    while [ $elapsed -lt $timeout ]; do
        # Check if container exists
        if ! container_exists "$container"; then
            log_error "MinIO container not found"
            return 1
        fi

        # Try to hit the health endpoint
        if curl -sf http://localhost:9000/minio/health/live >/dev/null 2>&1; then
            log_pass "MinIO is ready"
            return 0
        fi

        sleep 2
        ((elapsed+=2))

        # Show progress every 10 seconds
        if [ $((elapsed % 10)) -eq 0 ]; then
            log_info "Still waiting for MinIO... (${elapsed}s/${timeout}s)"
        fi
    done

    log_error "MinIO not ready after ${timeout}s"
    get_container_logs "$container" 20
    return 1
}

#######################################
# Wait for API health endpoint
# Arguments:
#   $1 - Timeout in seconds (default: 120)
# Returns:
#   0 if ready, 1 if timeout
#######################################
wait_for_api_health() {
    local timeout="${1:-120}"
    local elapsed=0
    local container="happy-server"
    local health_url="http://localhost:3000/health"

    log_info "Waiting for API health endpoint..."

    while [ $elapsed -lt $timeout ]; do
        # Check if container exists
        if ! container_exists "$container"; then
            log_error "Happy Server container not found"
            return 1
        fi

        # Check container status
        local status=$(get_container_status "$container")
        if [ "$status" == "exited" ] || [ "$status" == "dead" ]; then
            log_error "Happy Server container exited unexpectedly"
            get_container_logs "$container" 50
            return 1
        fi

        # Try to hit the health endpoint
        local http_code=$(curl -sf -o /dev/null -w "%{http_code}" "$health_url" 2>/dev/null)

        if [ "$http_code" == "200" ]; then
            log_pass "API health endpoint is ready"
            return 0
        fi

        sleep 3
        ((elapsed+=3))

        # Show progress every 15 seconds
        if [ $((elapsed % 15)) -eq 0 ]; then
            log_info "Still waiting for API... (${elapsed}s/${timeout}s) [HTTP: ${http_code:-timeout}]"
        fi
    done

    log_error "API not ready after ${timeout}s"
    get_container_logs "$container" 50
    return 1
}

#######################################
# Wait for Nginx to be ready
# Arguments:
#   $1 - Timeout in seconds (default: 60)
# Returns:
#   0 if ready, 1 if timeout
#######################################
wait_for_nginx() {
    local timeout="${1:-$DEFAULT_TIMEOUT}"
    local elapsed=0
    local container="nginx"

    log_info "Waiting for Nginx to be ready..."

    while [ $elapsed -lt $timeout ]; do
        # Check if container exists
        if ! container_exists "$container"; then
            log_error "Nginx container not found"
            return 1
        fi

        # Try to connect to Nginx
        if curl -sf -o /dev/null http://localhost:80 2>/dev/null; then
            log_pass "Nginx is ready"
            return 0
        fi

        sleep 2
        ((elapsed+=2))

        # Show progress every 10 seconds
        if [ $((elapsed % 10)) -eq 0 ]; then
            log_info "Still waiting for Nginx... (${elapsed}s/${timeout}s)"
        fi
    done

    log_error "Nginx not ready after ${timeout}s"
    get_container_logs "$container" 20
    return 1
}

#######################################
# Wait for all services to be ready
# Arguments:
#   $1 - Total timeout in seconds (default: 180)
# Returns:
#   0 if all ready, 1 if any failed
#######################################
wait_for_all() {
    local total_timeout="${1:-180}"
    local service_timeout=$((total_timeout / 5))  # Divide timeout among services
    local start_time=$(date +%s)

    log_info "Waiting for all services (total timeout: ${total_timeout}s)..."
    echo ""

    # Wait for PostgreSQL
    if ! wait_for_postgres "$service_timeout"; then
        return 1
    fi
    echo ""

    # Wait for Redis
    if ! wait_for_redis "$service_timeout"; then
        return 1
    fi
    echo ""

    # Wait for MinIO
    if ! wait_for_minio "$service_timeout"; then
        return 1
    fi
    echo ""

    # Calculate remaining time for API (the most critical service)
    local elapsed=$(($(date +%s) - start_time))
    local remaining=$((total_timeout - elapsed))

    if [ $remaining -lt 60 ]; then
        remaining=60  # Minimum 60s for API
    fi

    # Wait for API
    if ! wait_for_api_health "$remaining"; then
        return 1
    fi
    echo ""

    # Wait for Nginx (if it exists)
    if docker ps --format '{{.Names}}' | grep -q "^nginx$"; then
        if ! wait_for_nginx 30; then
            log_warn "Nginx not ready, but continuing (non-critical)"
        fi
        echo ""
    fi

    local total_elapsed=$(($(date +%s) - start_time))
    log_pass "All services ready in ${total_elapsed}s"

    return 0
}

#######################################
# Check all services are healthy
# Arguments:
#   None
# Returns:
#   0 if all healthy, 1 if any unhealthy
#######################################
check_all_services_healthy() {
    local all_healthy=0

    log_info "Checking service health status..."
    echo ""

    # Check PostgreSQL
    local pg_status=$(get_container_status "postgres")
    if [ "$pg_status" == "running" ] || [ "$pg_status" == "healthy" ]; then
        log_pass "PostgreSQL: $pg_status"
    else
        log_fail "PostgreSQL: $pg_status"
        all_healthy=1
    fi

    # Check Redis
    local redis_status=$(get_container_status "redis")
    if [ "$redis_status" == "running" ] || [ "$redis_status" == "healthy" ]; then
        log_pass "Redis: $redis_status"
    else
        log_fail "Redis: $redis_status"
        all_healthy=1
    fi

    # Check MinIO
    local minio_status=$(get_container_status "minio")
    if [ "$minio_status" == "running" ] || [ "$minio_status" == "healthy" ]; then
        log_pass "MinIO: $minio_status"
    else
        log_fail "MinIO: $minio_status"
        all_healthy=1
    fi

    # Check Happy Server
    local server_status=$(get_container_status "happy-server")
    if [ "$server_status" == "running" ] || [ "$server_status" == "healthy" ]; then
        log_pass "Happy Server: $server_status"
    else
        log_fail "Happy Server: $server_status"
        all_healthy=1
    fi

    # Check Nginx (if exists)
    if docker ps --format '{{.Names}}' | grep -q "^nginx$"; then
        local nginx_status=$(get_container_status "nginx")
        if [ "$nginx_status" == "running" ] || [ "$nginx_status" == "healthy" ]; then
            log_pass "Nginx: $nginx_status"
        else
            log_fail "Nginx: $nginx_status"
            all_healthy=1
        fi
    fi

    echo ""
    return $all_healthy
}

# Export functions for use in other scripts
export -f wait_for_port
export -f wait_for_postgres
export -f wait_for_redis
export -f wait_for_minio
export -f wait_for_api_health
export -f wait_for_nginx
export -f wait_for_all
export -f check_all_services_healthy
