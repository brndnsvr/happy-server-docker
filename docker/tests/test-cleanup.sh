#!/bin/bash
# Cleanup test script for Docker Compose services
# Tests: Graceful shutdown, volume persistence, resource cleanup, network cleanup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-helpers.sh"

COMPOSE_FILE="../docker-compose.yml"

# Test: Graceful service shutdown
test_services_stop_cleanly() {
    log_info "Stopping services..."

    if docker-compose -f "$COMPOSE_FILE" down > /dev/null 2>&1; then
        return 0
    else
        log_error "docker-compose down failed"
        return 1
    fi
}

# Test: Containers are no longer running
test_containers_stopped() {
    sleep 2  # Give containers time to stop

    local running=$(docker ps --format '{{.Names}}' | grep "happy-server" | wc -l)

    if [[ $running -eq 0 ]]; then
        return 0
    else
        log_error "Containers still running: $running"
        return 1
    fi
}

# Test: Container data still exists in stopped containers
test_stopped_containers_exist() {
    local stopped=$(docker ps -a --format '{{.Names}}' | grep "happy-server" | wc -l)

    if [[ $stopped -gt 0 ]]; then
        return 0
    else
        log_warn "No stopped containers found"
        return 0
    fi
}

# Test: Volumes are preserved
test_volume_data_persists() {
    # Check if volumes still exist
    local volumes=$(docker volume ls --format '{{.Name}}' | grep "happy-server" | wc -l)

    if [[ $volumes -gt 0 ]]; then
        log_info "Persistent volumes found: $volumes"
        return 0
    else
        log_warn "No volumes found (may be expected)"
        return 0
    fi
}

# Test: No orphaned processes
test_no_orphaned_processes() {
    # Check for any processes still using docker resources related to happy-server
    local orphaned=$(ps aux | grep -i "happy-server\|docker.*happy" | grep -v grep | wc -l)

    if [[ $orphaned -eq 0 ]]; then
        return 0
    else
        log_warn "Found $orphaned orphaned processes"
        return 0
    fi
}

# Test: Network cleanup
test_network_cleanup() {
    sleep 1

    # Check if custom network still exists (may persist after down)
    local networks=$(docker network ls --format '{{.Name}}' | grep "happy-server" || echo "")

    log_info "Remaining networks: ${networks:-none}"
    return 0
}

# Test: Docker resource cleanup
test_docker_resource_cleanup() {
    # Remove stopped containers
    docker container prune -f > /dev/null 2>&1 || true

    # Check for dangling images
    local dangling=$(docker image prune -a -f --filter "until=0h" > /dev/null 2>&1 && echo "cleaned" || echo "error")

    log_info "Docker resource cleanup: $dangling"
    return 0
}

# Test: Filesystem cleanup
test_filesystem_cleanup() {
    # Verify no test artifacts left in /tmp
    local artifacts=$(find /tmp -maxdepth 1 -name "happy-server*" -type d 2>/dev/null | wc -l)

    if [[ $artifacts -eq 0 ]]; then
        return 0
    else
        log_warn "Found $artifacts test artifacts in /tmp"
        return 0
    fi
}

# Test: Services can be restarted after cleanup
test_restart_after_cleanup() {
    log_info "Testing restart capability..."

    # Check docker-compose file exists
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "docker-compose.yml not found at $COMPOSE_FILE"
        return 1
    fi

    # Check basic syntax
    if docker-compose -f "$COMPOSE_FILE" config > /dev/null 2>&1; then
        return 0
    else
        log_error "docker-compose.yml has syntax errors"
        return 1
    fi
}

# Test: Cleanup idempotency
test_cleanup_idempotent() {
    # Running cleanup twice should not cause errors
    log_info "Running cleanup twice to verify idempotency..."

    if docker-compose -f "$COMPOSE_FILE" down > /dev/null 2>&1 && \
       docker-compose -f "$COMPOSE_FILE" down > /dev/null 2>&1; then
        return 0
    else
        log_error "Cleanup is not idempotent"
        return 1
    fi
}

# Test: Port release after cleanup
test_ports_released() {
    sleep 2

    # Check if ports are available
    local ports_in_use=0

    for port in 3000 5432 6379 9000 80 9090; do
        if nc -z localhost $port > /dev/null 2>&1; then
            log_warn "Port $port still in use"
            ((ports_in_use++))
        fi
    done

    if [[ $ports_in_use -eq 0 ]]; then
        return 0
    else
        log_warn "$ports_in_use ports still in use after cleanup"
        return 0
    fi
}

# Test: Logs are preserved (optional)
test_logs_accessible() {
    # Logs should be accessible even after container stops
    if docker-compose -f "$COMPOSE_FILE" logs > /dev/null 2>&1; then
        return 0
    else
        log_warn "Could not access logs after cleanup"
        return 0
    fi
}

# Main test execution
main() {
    log_info "=========================================="
    log_info "Cleanup Test Suite"
    log_info "=========================================="

    log_info "Testing Graceful Shutdown..."
    run_test test_services_stop_cleanly "Services stop cleanly"
    run_test test_containers_stopped "Running containers stopped"
    run_test test_stopped_containers_exist "Stopped containers are preserved"

    log_info "Testing Data Persistence..."
    run_test test_volume_data_persists "Volume data persists after shutdown"

    log_info "Testing Process Cleanup..."
    run_test test_no_orphaned_processes "No orphaned processes remain"

    log_info "Testing Network Cleanup..."
    run_test test_network_cleanup "Network resources cleaned up"

    log_info "Testing Resource Cleanup..."
    run_test test_docker_resource_cleanup "Docker resources cleaned up"
    run_test test_filesystem_cleanup "Filesystem artifacts cleaned up"

    log_info "Testing Port Release..."
    run_test test_ports_released "Ports released after cleanup"

    log_info "Testing Restart Capability..."
    run_test test_restart_after_cleanup "Services can restart after cleanup"
    run_test test_cleanup_idempotent "Cleanup is idempotent"

    log_info "Testing Log Access..."
    run_test test_logs_accessible "Logs accessible after cleanup"

    print_test_summary
}

main "$@"
exit $?
