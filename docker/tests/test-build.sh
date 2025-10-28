#!/bin/bash
# Test script for Docker image build validation
# Tests: Dockerfile syntax, multi-stage build, image size, required binaries, user setup, build artifacts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/test-helpers.sh"

IMAGE_NAME="happy-server:test"
MAX_IMAGE_SIZE=838860800  # 800MB in bytes

# Test: Validate Dockerfile syntax
test_dockerfile_syntax() {
    assert_command_success "docker build --dry-run -f Dockerfile -t $IMAGE_NAME ." \
        "Dockerfile syntax should be valid"
}

# Test: Build multi-stage image completes successfully
test_build_completes() {
    assert_command_success "docker build -f Dockerfile -t $IMAGE_NAME ." \
        "Docker image build should complete successfully"
}

# Test: Image exists after build
test_image_exists() {
    docker image ls | grep -q "happy-server.*test" && return 0
    return 1
}

# Test: Image size is reasonable
test_image_size() {
    local size=$(docker inspect -f '{{.Size}}' "$IMAGE_NAME" 2>/dev/null || echo "0")

    if [[ $size -lt $MAX_IMAGE_SIZE ]] && [[ $size -gt 0 ]]; then
        log_info "Image size: $(numfmt --to=iec $size 2>/dev/null || echo "$size bytes")"
        return 0
    else
        log_error "Image size check failed: $size bytes (max: $MAX_IMAGE_SIZE)"
        return 1
    fi
}

# Test: Required binaries exist in image
test_node_binary() {
    docker run --rm "$IMAGE_NAME" which node > /dev/null && return 0
    return 1
}

test_yarn_binary() {
    docker run --rm "$IMAGE_NAME" which yarn > /dev/null && return 0
    return 1
}

test_curl_binary() {
    docker run --rm "$IMAGE_NAME" which curl > /dev/null && return 0
    return 1
}

test_ffmpeg_binary() {
    docker run --rm "$IMAGE_NAME" which ffmpeg > /dev/null && return 0
    return 1
}

test_python_binary() {
    docker run --rm "$IMAGE_NAME" which python3 > /dev/null && return 0
    return 1
}

# Test: Non-root user exists (uid 1000)
test_non_root_user() {
    local uid=$(docker run --rm "$IMAGE_NAME" id -u appuser 2>/dev/null || echo "")

    if [[ "$uid" == "1000" ]]; then
        return 0
    else
        log_error "Non-root user not found or wrong UID: $uid"
        return 1
    fi
}

# Test: No npm usage (only yarn)
test_no_npm_usage() {
    docker run --rm "$IMAGE_NAME" test ! -f /app/package-lock.json && return 0
    return 1
}

# Test: Healthcheck is configured
test_healthcheck_configured() {
    local healthcheck=$(docker inspect -f '{{json .Config.Healthcheck}}' "$IMAGE_NAME" 2>/dev/null)

    if [[ "$healthcheck" != "null" ]] && [[ -n "$healthcheck" ]]; then
        return 0
    else
        log_error "Healthcheck not configured"
        return 1
    fi
}

# Test: Required ports are exposed
test_app_port_exposed() {
    docker inspect -f '{{json .Config.ExposedPorts}}' "$IMAGE_NAME" | grep -q "3000" && return 0
    return 1
}

test_metrics_port_exposed() {
    docker inspect -f '{{json .Config.ExposedPorts}}' "$IMAGE_NAME" | grep -q "9090" && return 0
    return 1
}

# Test: Prisma client is generated
test_prisma_client_generated() {
    docker run --rm "$IMAGE_NAME" test -d /app/node_modules/.prisma/client && return 0
    return 1
}

# Test: Working directory is set correctly
test_working_directory() {
    local workdir=$(docker inspect -f '{{.Config.WorkingDir}}' "$IMAGE_NAME" 2>/dev/null)

    if [[ "$workdir" == "/app" ]]; then
        return 0
    else
        log_error "Working directory is not /app: $workdir"
        return 1
    fi
}

# Test: Environment variables are set
test_node_env_production() {
    docker run --rm "$IMAGE_NAME" sh -c 'test "$NODE_ENV" = "production"' && return 0
    return 1
}

# Main test execution
main() {
    log_info "=========================================="
    log_info "Build Test Suite"
    log_info "=========================================="

    run_test test_dockerfile_syntax "Dockerfile syntax validation"
    run_test test_build_completes "Docker image builds successfully"
    run_test test_image_exists "Docker image exists after build"
    run_test test_image_size "Docker image size is reasonable"

    log_info "Checking required binaries..."
    run_test test_node_binary "Node.js binary exists"
    run_test test_yarn_binary "Yarn binary exists"
    run_test test_curl_binary "curl binary exists"
    run_test test_ffmpeg_binary "ffmpeg binary exists"
    run_test test_python_binary "Python3 binary exists"

    log_info "Checking user and permissions..."
    run_test test_non_root_user "Non-root appuser exists with uid 1000"
    run_test test_no_npm_usage "npm not used (only yarn)"

    log_info "Checking configuration..."
    run_test test_healthcheck_configured "Healthcheck is configured"
    run_test test_app_port_exposed "Application port 3000 is exposed"
    run_test test_metrics_port_exposed "Metrics port 9090 is exposed"
    run_test test_working_directory "Working directory is /app"
    run_test test_node_env_production "NODE_ENV set to production"

    log_info "Checking build artifacts..."
    run_test test_prisma_client_generated "Prisma client is generated"

    print_test_summary
}

main "$@"
exit $?
