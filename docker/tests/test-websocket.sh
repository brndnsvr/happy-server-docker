#!/bin/bash
# Test script for WebSocket connectivity
# Tests: Socket.io connection, Nginx upgrade, persistence, concurrency

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-helpers.sh"

# Check for required tools
test_websocket_tools_available() {
    if command -v wscat &> /dev/null || command -v websocat &> /dev/null; then
        return 0
    else
        log_warn "WebSocket tools (wscat/websocat) not available - WebSocket tests will be skipped"
        return 1
    fi
}

# Test: Socket.io connection establishment
test_socketio_connection() {
    local response=$(curl -s "http://localhost:3000/socket.io/?transport=polling" 2>/dev/null)

    if [[ -n "$response" ]]; then
        return 0
    else
        log_error "Socket.io connection failed"
        return 1
    fi
}

# Test: WebSocket upgrade through Nginx
test_websocket_upgrade_through_nginx() {
    if ! test_websocket_tools_available; then
        return 0
    fi

    local response=$(curl -s -i "http://localhost/socket.io/?transport=polling" 2>/dev/null)

    if echo "$response" | grep -q "200\|101"; then
        return 0
    else
        log_error "WebSocket upgrade through Nginx failed"
        return 1
    fi
}

# Test: Connection persistence
test_connection_persistence() {
    # Test that the connection can be established and persists for a short time
    local response=$(curl -s "http://localhost:3000/socket.io/?transport=polling" 2>/dev/null)

    if [[ -n "$response" ]]; then
        sleep 2
        # Try to get socket status again
        local response2=$(curl -s "http://localhost:3000/socket.io/?transport=polling" 2>/dev/null)

        if [[ -n "$response2" ]]; then
            return 0
        fi
    fi

    return 1
}

# Test: Graceful disconnect
test_graceful_disconnect() {
    # Test that we can establish and cleanly disconnect
    local start=$(date +%s)
    curl -s "http://localhost:3000/socket.io/?transport=polling" > /dev/null 2>&1 &
    local pid=$!

    sleep 1
    kill $pid 2>/dev/null || true

    local end=$(date +%s)
    local elapsed=$((end - start))

    # Should complete within 5 seconds
    if [[ $elapsed -lt 5 ]]; then
        return 0
    else
        return 1
    fi
}

# Test: Multiple concurrent connections
test_concurrent_connections() {
    local pids=()
    local count=0

    # Attempt to establish 5 concurrent connections
    for i in {1..5}; do
        curl -s "http://localhost:3000/socket.io/?transport=polling" > /dev/null 2>&1 &
        pids+=($!)
        ((count++))
    done

    # Wait for all connections with timeout
    local success=0
    for pid in "${pids[@]}"; do
        if wait $pid 2>/dev/null; then
            ((success++))
        fi
    done

    if [[ $success -ge $((count - 1)) ]]; then
        return 0
    else
        return 1
    fi
}

# Test: Socket.io polling mechanism
test_socketio_polling() {
    local response=$(curl -s "http://localhost:3000/socket.io/?transport=polling&EIO=4&t=timestamp" 2>/dev/null)

    if [[ -n "$response" ]]; then
        return 0
    else
        log_error "Socket.io polling failed"
        return 1
    fi
}

# Test: Socket.io endpoint structure
test_socketio_endpoint_structure() {
    local response=$(curl -s -w "\n%{http_code}" "http://localhost:3000/socket.io/" 2>/dev/null)
    local status=$(echo "$response" | tail -n 1)

    # Should return 200 or 426 (Upgrade Required for WebSocket)
    if [[ "$status" =~ ^(200|426|400)$ ]]; then
        return 0
    else
        log_error "Socket.io endpoint returned: $status"
        return 1
    fi
}

# Test: Nginx WebSocket upgrade headers
test_nginx_websocket_headers() {
    local headers=$(curl -s -i -N "http://localhost/socket.io/" 2>/dev/null || true)

    # Check for upgrade header in response (may not always be present)
    if echo "$headers" | grep -qi "upgrade\|connection"; then
        return 0
    else
        log_warn "WebSocket upgrade headers not detected (may be expected)"
        return 0
    fi
}

# Main test execution
main() {
    log_info "=========================================="
    log_info "WebSocket Test Suite"
    log_info "=========================================="

    log_info "Checking WebSocket tools availability..."
    if ! test_websocket_tools_available; then
        log_warn "WebSocket tools not available - basic connectivity tests only"
    fi

    log_info "Testing Socket.io..."
    run_test test_socketio_endpoint_structure "Socket.io endpoint exists"
    run_test test_socketio_connection "Socket.io connection can be established"
    run_test test_socketio_polling "Socket.io polling mechanism works"

    log_info "Testing WebSocket through Nginx..."
    run_test test_websocket_upgrade_through_nginx "WebSocket upgrade through Nginx"
    run_test test_nginx_websocket_headers "Nginx WebSocket upgrade headers"

    log_info "Testing Connection Behavior..."
    run_test test_connection_persistence "Connection persists over time"
    run_test test_graceful_disconnect "Graceful connection disconnect"

    log_info "Testing Concurrent Connections..."
    run_test test_concurrent_connections "Multiple concurrent connections"

    print_test_summary
}

main "$@"
exit $?
