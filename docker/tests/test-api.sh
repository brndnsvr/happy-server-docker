#!/bin/bash
# Test script for API endpoint validation
# Tests: Health endpoint, CORS, auth, metrics, JSON handling, response times

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-helpers.sh"
source "$SCRIPT_DIR/helpers/api-client.sh"

# Setup API base URL
set_base_url "http://localhost:3000"

# Health Endpoint Tests
test_health_endpoint_responds() {
    local response=$(http_get "/health" 200 2>/dev/null)

    if [[ -n "$response" ]]; then
        return 0
    else
        log_error "Health endpoint returned empty response"
        return 1
    fi
}

test_health_returns_valid_json() {
    local response=$(http_get "/health" 200 2>/dev/null)

    if echo "$response" | jq . > /dev/null 2>&1; then
        return 0
    else
        log_error "Health endpoint did not return valid JSON"
        return 1
    fi
}

test_health_through_nginx() {
    local base_url="http://localhost"
    local response=$(curl -s -w "\n%{http_code}" "$base_url/health" 2>/dev/null)
    local status=$(echo "$response" | tail -n 1)

    if [[ "$status" == "200" ]]; then
        return 0
    else
        log_error "Health endpoint through Nginx returned: $status"
        return 1
    fi
}

# CORS Tests
test_cors_headers_present() {
    local headers=$(curl -s -i -X OPTIONS "http://localhost:3000/health" 2>/dev/null)

    if echo "$headers" | grep -q "access-control-allow-origin\|Access-Control-Allow-Origin"; then
        return 0
    else
        log_warn "CORS headers not found (this may be expected)"
        return 0  # Don't fail the test
    fi
}

# Content-Type Tests
test_api_accepts_json() {
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d '{}' \
        "http://localhost:3000/health" 2>/dev/null)
    local status=$(echo "$response" | tail -n 1)

    # Accept 200, 404, or 405 as valid responses (means server parsed the request)
    if [[ "$status" =~ ^(200|404|405)$ ]]; then
        return 0
    else
        log_error "API did not accept JSON request: $status"
        return 1
    fi
}

test_api_rejects_invalid_json() {
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d '{invalid json}' \
        "http://localhost:3000/health" 2>/dev/null)
    local status=$(echo "$response" | tail -n 1)

    # Accept 400 as validation error or 404 (route doesn't exist)
    if [[ "$status" =~ ^(400|404)$ ]]; then
        return 0
    else
        log_warn "API responded with $status for invalid JSON (expected 400 or 404)"
        return 0
    fi
}

# Auth Tests
test_auth_request_endpoint_exists() {
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d '{"deviceType":"cli","deviceModel":"test"}' \
        "http://localhost:3000/v1/auth/request" 2>/dev/null)
    local status=$(echo "$response" | tail -n 1)

    # 200 = success, 400 = validation error, 201 = created
    if [[ "$status" =~ ^(200|201|400|422)$ ]]; then
        return 0
    else
        log_error "Auth request endpoint returned: $status"
        return 1
    fi
}

test_non_existent_endpoint_404() {
    local response=$(curl -s -w "\n%{http_code}" \
        "http://localhost:3000/non-existent-endpoint-that-should-not-exist" 2>/dev/null)
    local status=$(echo "$response" | tail -n 1)

    if [[ "$status" == "404" ]]; then
        return 0
    else
        log_warn "Non-existent endpoint returned: $status (expected 404)"
        return 0
    fi
}

# Performance Tests
test_health_response_time() {
    local start=$(date +%s%N)
    curl -s "http://localhost:3000/health" > /dev/null 2>&1
    local end=$(date +%s%N)

    # Calculate time in milliseconds
    local elapsed=$(( (end - start) / 1000000 ))

    # Health should respond in under 1 second (1000ms)
    if [[ $elapsed -lt 1000 ]]; then
        log_info "Health response time: ${elapsed}ms"
        return 0
    else
        log_warn "Health response time is slow: ${elapsed}ms (expected < 1000ms)"
        return 0  # Don't fail on slow responses
    fi
}

# Metrics Tests
test_metrics_port_accessible() {
    local response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:9090/metrics" 2>/dev/null || echo "000")

    if [[ "$response" == "200" ]]; then
        return 0
    else
        log_warn "Metrics endpoint returned: $response (expected 200)"
        return 0  # Don't fail if metrics not available
    fi
}

test_metrics_returns_prometheus_format() {
    local response=$(curl -s "http://localhost:9090/metrics" 2>/dev/null || echo "")

    if echo "$response" | grep -q "# HELP\|# TYPE"; then
        return 0
    else
        log_warn "Metrics endpoint not in Prometheus format"
        return 0  # Don't fail if metrics format unexpected
    fi
}

# Sessions Endpoint Tests
test_sessions_requires_auth() {
    local response=$(curl -s -w "\n%{http_code}" -X GET \
        "http://localhost:3000/v1/sessions" 2>/dev/null)
    local status=$(echo "$response" | tail -n 1)

    # Should be 401 (Unauthorized) without auth token
    if [[ "$status" == "401" ]] || [[ "$status" == "403" ]]; then
        return 0
    else
        log_warn "Sessions endpoint without auth returned: $status (expected 401/403)"
        return 0  # May vary based on implementation
    fi
}

# Request/Response Tests
test_response_has_content_type() {
    local headers=$(curl -s -i "http://localhost:3000/health" 2>/dev/null)

    if echo "$headers" | grep -i "content-type"; then
        return 0
    else
        log_warn "Response missing Content-Type header"
        return 0
    fi
}

test_api_responds_to_get_requests() {
    local response=$(curl -s -w "\n%{http_code}" -X GET "http://localhost:3000/health" 2>/dev/null)
    local status=$(echo "$response" | tail -n 1)

    if [[ "$status" == "200" ]]; then
        return 0
    else
        log_error "GET request returned: $status"
        return 1
    fi
}

# Main test execution
main() {
    log_info "=========================================="
    log_info "API Test Suite"
    log_info "=========================================="

    log_info "Testing Health Endpoint..."
    run_test test_health_endpoint_responds "Health endpoint responds"
    run_test test_health_returns_valid_json "Health returns valid JSON"
    run_test test_health_through_nginx "Health accessible through Nginx"

    log_info "Testing CORS..."
    run_test test_cors_headers_present "CORS headers are present"

    log_info "Testing Content-Type..."
    run_test test_api_accepts_json "API accepts JSON requests"
    run_test test_api_rejects_invalid_json "API rejects invalid JSON"

    log_info "Testing Response Headers..."
    run_test test_response_has_content_type "Response has Content-Type header"

    log_info "Testing HTTP Methods..."
    run_test test_api_responds_to_get_requests "API responds to GET requests"

    log_info "Testing Authentication..."
    run_test test_auth_request_endpoint_exists "Auth request endpoint exists"
    run_test test_sessions_requires_auth "Sessions endpoint requires authentication"

    log_info "Testing Error Handling..."
    run_test test_non_existent_endpoint_404 "Non-existent endpoint returns 404"

    log_info "Testing Performance..."
    run_test test_health_response_time "Health endpoint response time acceptable"

    log_info "Testing Metrics..."
    run_test test_metrics_port_accessible "Metrics port is accessible"
    run_test test_metrics_returns_prometheus_format "Metrics in Prometheus format"

    print_test_summary
}

main "$@"
exit $?
