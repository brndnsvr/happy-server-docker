#!/bin/bash
# Common test helper functions for Happy Server Docker tests

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

# Test execution wrapper
run_test() {
    local test_function=$1
    local test_name=$2

    TESTS_RUN=$((TESTS_RUN + 1))

    log_info "Running: $test_name"

    if $test_function; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "✓ $test_name"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "✗ $test_name"
        return 1
    fi
}

# Skip test
skip_test() {
    local reason=$1
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    log_skip "$reason"
    return 0
}

# Assert functions
assert_equals() {
    local expected=$1
    local actual=$2
    local message=${3:-"Values should be equal"}

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        log_error "$message"
        log_error "Expected: $expected"
        log_error "Actual: $actual"
        return 1
    fi
}

assert_not_empty() {
    local value=$1
    local message=${2:-"Value should not be empty"}

    if [[ -n "$value" ]]; then
        return 0
    else
        log_error "$message"
        return 1
    fi
}

assert_contains() {
    local haystack=$1
    local needle=$2
    local message=${3:-"String should contain substring"}

    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        log_error "$message"
        log_error "Expected to find: $needle"
        log_error "In: $haystack"
        return 1
    fi
}

assert_command_success() {
    local command=$1
    local message=${2:-"Command should succeed"}

    if eval "$command" > /dev/null 2>&1; then
        return 0
    else
        log_error "$message"
        log_error "Command failed: $command"
        return 1
    fi
}

# Docker helper functions
is_container_running() {
    local container_name=$1
    docker ps --format '{{.Names}}' | grep -q "^${container_name}$"
}

wait_for_container() {
    local container_name=$1
    local max_wait=${2:-30}
    local elapsed=0

    while ! is_container_running "$container_name"; do
        if [[ $elapsed -ge $max_wait ]]; then
            log_error "Timeout waiting for container: $container_name"
            return 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    return 0
}

wait_for_healthy() {
    local container_name=$1
    local max_wait=${2:-60}
    local elapsed=0

    while true; do
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null)

        if [[ "$health" == "healthy" ]]; then
            return 0
        fi

        if [[ $elapsed -ge $max_wait ]]; then
            log_error "Timeout waiting for healthy: $container_name (status: $health)"
            return 1
        fi

        sleep 2
        elapsed=$((elapsed + 2))
    done
}

get_container_logs() {
    local container_name=$1
    local lines=${2:-50}
    docker logs --tail "$lines" "$container_name" 2>&1
}

exec_in_container() {
    local container_name=$1
    shift
    docker exec "$container_name" "$@"
}

# Network helper functions
wait_for_port() {
    local host=$1
    local port=$2
    local max_wait=${3:-30}
    local elapsed=0

    while ! nc -z "$host" "$port" 2>/dev/null; do
        if [[ $elapsed -ge $max_wait ]]; then
            log_error "Timeout waiting for port: $host:$port"
            return 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    return 0
}

# HTTP helper functions
http_get() {
    local url=$1
    local expected_status=${2:-200}

    local response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null)
    local body=$(echo "$response" | head -n -1)
    local status=$(echo "$response" | tail -n 1)

    if [[ "$status" == "$expected_status" ]]; then
        echo "$body"
        return 0
    else
        log_error "HTTP GET failed: $url (expected: $expected_status, got: $status)"
        return 1
    fi
}

http_post() {
    local url=$1
    local data=$2
    local expected_status=${3:-200}

    local response=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d "$data" "$url" 2>/dev/null)
    local body=$(echo "$response" | head -n -1)
    local status=$(echo "$response" | tail -n 1)

    if [[ "$status" == "$expected_status" ]]; then
        echo "$body"
        return 0
    else
        log_error "HTTP POST failed: $url (expected: $expected_status, got: $status)"
        return 1
    fi
}

# Test summary
print_test_summary() {
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Total:   $TESTS_RUN"
    echo -e "${GREEN}Passed:  $TESTS_PASSED${NC}"
    echo -e "${RED}Failed:  $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
    echo "=========================================="

    if [[ $TESTS_FAILED -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Cleanup function
cleanup_test_data() {
    log_info "Cleaning up test data..."
    # This can be extended by individual test files
}

# Check if container exists (running or stopped)
container_exists() {
    local container_name="$1"
    docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"
}

# Get container health status
get_container_status() {
    local container_name="$1"
    docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no healthcheck"
}

# Log passing test
log_pass() {
    local message="$1"
    echo -e "${GREEN}✓ PASS${NC}: $message"
    ((TESTS_PASSED++))
}

# Log failing test
log_fail() {
    local message="$1"
    echo -e "${RED}✗ FAIL${NC}: $message"
    ((TESTS_FAILED++))
}

# Export functions
export -f log_info log_success log_error log_warn log_skip
export -f run_test skip_test
export -f assert_equals assert_not_empty assert_contains assert_command_success
export -f is_container_running wait_for_container wait_for_healthy get_container_logs exec_in_container
export -f wait_for_port http_get http_post
export -f container_exists get_container_status log_pass log_fail
export -f print_test_summary cleanup_test_data
