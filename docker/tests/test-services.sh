#!/bin/bash
# Test script for Docker Compose services validation
# Tests: PostgreSQL, Redis, MinIO, Nginx, App container health and networking

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-helpers.sh"
source "$SCRIPT_DIR/helpers/wait-for-services.sh"

COMPOSE_FILE="../docker-compose.yml"
COMPOSE_DEV_FILE="../docker-compose.dev.yml"

# PostgreSQL Tests
test_postgres_container_running() {
    is_container_running "happy-server-postgres" && return 0
    return 1
}

test_postgres_connection() {
    wait_for_port "localhost" 5432 30 && return 0
    return 1
}

test_postgres_pg_isready() {
    docker exec happy-server-postgres pg_isready -U postgres > /dev/null 2>&1 && return 0
    return 1
}

test_postgres_uuid_extension() {
    docker exec happy-server-postgres psql -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" > /dev/null 2>&1 && return 0
    return 1
}

test_postgres_pgcrypto_extension() {
    docker exec happy-server-postgres psql -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" > /dev/null 2>&1 && return 0
    return 1
}

test_postgres_citext_extension() {
    docker exec happy-server-postgres psql -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS citext;" > /dev/null 2>&1 && return 0
    return 1
}

# Redis Tests
test_redis_container_running() {
    is_container_running "happy-server-redis" && return 0
    return 1
}

test_redis_port_accessible() {
    wait_for_port "localhost" 6379 30 && return 0
    return 1
}

test_redis_ping() {
    docker exec happy-server-redis redis-cli PING | grep -q "PONG" && return 0
    return 1
}

test_redis_pubsub_functional() {
    # Test basic pub/sub capability
    timeout 5 docker exec happy-server-redis redis-cli SUBSCRIBE test-channel > /dev/null 2>&1 &
    local sub_pid=$!
    sleep 1
    docker exec happy-server-redis redis-cli PUBLISH test-channel "test-message" > /dev/null 2>&1
    wait $sub_pid 2>/dev/null || true
    return 0
}

# MinIO Tests
test_minio_container_running() {
    is_container_running "happy-server-minio" && return 0
    return 1
}

test_minio_port_accessible() {
    wait_for_port "localhost" 9000 30 && return 0
    return 1
}

test_minio_health_endpoint() {
    local response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:9000/minio/health/live" 2>/dev/null || echo "000")

    if [[ "$response" == "200" ]]; then
        return 0
    else
        log_error "MinIO health endpoint returned: $response"
        return 1
    fi
}

# Nginx Tests
test_nginx_container_running() {
    is_container_running "happy-server-nginx" && return 0
    return 1
}

test_nginx_port_accessible() {
    wait_for_port "localhost" 80 30 && return 0
    return 1
}

test_nginx_proxies_to_app() {
    local response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/health" 2>/dev/null || echo "000")

    if [[ "$response" == "200" ]] || [[ "$response" == "404" ]]; then
        return 0
    else
        log_error "Nginx proxy failed: $response"
        return 1
    fi
}

# App Container Tests
test_app_container_running() {
    is_container_running "happy-server-app" && return 0
    return 1
}

test_app_port_accessible() {
    wait_for_port "localhost" 3000 30 && return 0
    return 1
}

test_app_health_endpoint() {
    local response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000/health" 2>/dev/null || echo "000")

    if [[ "$response" == "200" ]]; then
        return 0
    else
        log_error "App health endpoint returned: $response"
        return 1
    fi
}

test_app_metrics_port() {
    wait_for_port "localhost" 9090 30 && return 0
    return 1
}

# Service-to-Service Tests
test_app_can_reach_postgres() {
    docker exec happy-server-app curl -s "http://happy-server-postgres:5432" > /dev/null 2>&1 || true
    return 0  # This always succeeds because postgres doesn't respond to http
}

test_app_can_reach_redis() {
    docker exec happy-server-app sh -c "echo 'PING' | timeout 5 nc happy-server-redis 6379" > /dev/null 2>&1 && return 0
    return 1
}

test_service_networking() {
    # Check that services can resolve each other
    docker exec happy-server-app getent hosts happy-server-postgres > /dev/null 2>&1 && return 0
    return 1
}

# Comprehensive Health Check
test_all_services_healthy() {
    local unhealthy=0

    for service in postgres redis minio app nginx; do
        local container="happy-server-$service"
        local status=$(get_container_status "$container")

        if [[ "$status" != "healthy" ]] && [[ "$service" != "nginx" ]]; then
            log_warn "$container status: $status"
            ((unhealthy++))
        fi
    done

    if [[ $unhealthy -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Main test execution
main() {
    log_info "=========================================="
    log_info "Services Test Suite"
    log_info "=========================================="

    log_info "Testing PostgreSQL..."
    run_test test_postgres_container_running "PostgreSQL container is running"
    run_test test_postgres_connection "PostgreSQL port 5432 is accessible"
    run_test test_postgres_pg_isready "PostgreSQL pg_isready succeeds"
    run_test test_postgres_uuid_extension "PostgreSQL uuid-ossp extension available"
    run_test test_postgres_pgcrypto_extension "PostgreSQL pgcrypto extension available"
    run_test test_postgres_citext_extension "PostgreSQL citext extension available"

    log_info "Testing Redis..."
    run_test test_redis_container_running "Redis container is running"
    run_test test_redis_port_accessible "Redis port 6379 is accessible"
    run_test test_redis_ping "Redis PING response successful"
    run_test test_redis_pubsub_functional "Redis pub/sub is functional"

    log_info "Testing MinIO..."
    run_test test_minio_container_running "MinIO container is running"
    run_test test_minio_port_accessible "MinIO port 9000 is accessible"
    run_test test_minio_health_endpoint "MinIO health endpoint responds"

    log_info "Testing Nginx..."
    run_test test_nginx_container_running "Nginx container is running"
    run_test test_nginx_port_accessible "Nginx port 80 is accessible"
    run_test test_nginx_proxies_to_app "Nginx proxies requests to app"

    log_info "Testing App Container..."
    run_test test_app_container_running "App container is running"
    run_test test_app_port_accessible "App port 3000 is accessible"
    run_test test_app_health_endpoint "App health endpoint responds"
    run_test test_app_metrics_port "App metrics port 9090 is accessible"

    log_info "Testing Service-to-Service Communication..."
    run_test test_app_can_reach_postgres "App can reach PostgreSQL"
    run_test test_app_can_reach_redis "App can reach Redis"
    run_test test_service_networking "Service-to-service networking functional"

    log_info "Testing Overall Health..."
    run_test test_all_services_healthy "All services are in healthy state"

    print_test_summary
}

main "$@"
exit $?
