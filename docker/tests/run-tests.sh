#!/bin/bash
# Main test orchestrator for Happy Server Docker tests
# Manages test execution workflow, prerequisite validation, service lifecycle, and reporting

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers/test-helpers.sh"

# Configuration
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
COMPOSE_DEV_FILE="$PROJECT_ROOT/docker-compose.dev.yml"
ENV_FILE="$PROJECT_ROOT/.env"
START_TIME=$(date +%s)
KEEP_CONTAINERS=false
VERBOSE=false
CLEANUP_FIRST=false
TEST_MODE="default"  # default, dev, prod, quick

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Initialize test suite tracking
SUITE_RESULTS=()
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Helper functions
print_banner() {
    echo ""
    echo -e "${BLUE}=========================================="
    echo "  Happy Server Docker Test Suite"
    echo "==========================================${NC}"
    echo ""
}

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    --dev              Run tests against dev compose file
    --prod             Run tests against prod compose file (default: dev)
    --quick            Run quick test subset (build, services, api)
    --verbose          Enable verbose output
    --keep             Keep containers running after tests
    --clean            Clean up before running tests
    --help             Show this help message

Examples:
    $0                 # Run full test suite
    $0 --quick         # Run quick test subset
    $0 --dev --clean   # Clean then run full tests
    $0 --prod --keep   # Run on prod config, keep containers
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dev)
                TEST_MODE="dev"
                shift
                ;;
            --prod)
                TEST_MODE="prod"
                shift
                ;;
            --quick)
                TEST_MODE="quick"
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --keep)
                KEEP_CONTAINERS=true
                shift
                ;;
            --clean)
                CLEANUP_FIRST=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
}

validate_prerequisites() {
    log_info "Validating prerequisites..."

    local missing=0

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found"
        ((missing++))
    fi

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose not found"
        ((missing++))
    fi

    # Check jq
    if ! command -v jq &> /dev/null; then
        log_warn "jq not found (required for JSON parsing)"
        ((missing++))
    fi

    # Check curl
    if ! command -v curl &> /dev/null; then
        log_error "curl not found"
        ((missing++))
    fi

    # Check nc (netcat)
    if ! command -v nc &> /dev/null; then
        log_warn "nc (netcat) not found (required for port checks)"
        # Don't fail on this
    fi

    if [[ $missing -gt 0 ]]; then
        log_error "Prerequisites validation failed"
        return 1
    fi

    log_success "All prerequisites validated"
    return 0
}

check_port_availability() {
    log_info "Checking port availability..."

    local ports=(3000 5432 6379 9000 80 9090)
    local unavailable=0

    for port in "${ports[@]}"; do
        if nc -z localhost "$port" > /dev/null 2>&1; then
            log_warn "Port $port is already in use"
            ((unavailable++))
        fi
    done

    if [[ $unavailable -eq 0 ]]; then
        log_success "All ports are available"
        return 0
    else
        log_error "$unavailable ports are already in use"
        return 1
    fi
}

verify_config_files() {
    log_info "Verifying configuration files..."

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "docker-compose.yml not found at $COMPOSE_FILE"
        return 1
    fi

    if [[ ! -f "$ENV_FILE" ]]; then
        log_error ".env file not found at $ENV_FILE"
        return 1
    fi

    # Validate compose file syntax
    if ! docker-compose -f "$COMPOSE_FILE" config > /dev/null 2>&1; then
        log_error "docker-compose.yml has syntax errors"
        return 1
    fi

    log_success "Configuration files verified"
    return 0
}

cleanup_services() {
    log_info "Cleaning up existing services..."

    docker-compose -f "$COMPOSE_FILE" down -v > /dev/null 2>&1 || true
    sleep 2

    log_success "Cleanup completed"
}

build_images() {
    log_info "Building Docker images..."

    if [[ "$TEST_MODE" == "dev" ]]; then
        docker-compose -f "$COMPOSE_FILE" -f "$COMPOSE_DEV_FILE" build > /dev/null 2>&1
    else
        docker-compose -f "$COMPOSE_FILE" build > /dev/null 2>&1
    fi

    if [[ $? -eq 0 ]]; then
        log_success "Images built successfully"
        return 0
    else
        log_error "Image build failed"
        return 1
    fi
}

start_services() {
    log_info "Starting Docker services..."

    if [[ "$TEST_MODE" == "dev" ]]; then
        docker-compose -f "$COMPOSE_FILE" -f "$COMPOSE_DEV_FILE" up -d > /dev/null 2>&1
    else
        docker-compose -f "$COMPOSE_FILE" up -d > /dev/null 2>&1
    fi

    if [[ $? -eq 0 ]]; then
        log_success "Services started"
        return 0
    else
        log_error "Failed to start services"
        return 1
    fi
}

wait_for_services() {
    log_info "Waiting for all services to be healthy (timeout: 120s)..."

    source "$SCRIPT_DIR/helpers/wait-for-services.sh"
    if wait_for_all 120; then
        log_success "All services are healthy"
        return 0
    else
        log_error "Services did not become healthy"
        return 1
    fi
}

run_test_suite() {
    local suite_name=$1
    local test_script=$2

    TOTAL_SUITES=$((TOTAL_SUITES + 1))

    log_info "Running $suite_name..."
    echo ""

    if [[ ! -f "$test_script" ]]; then
        log_error "Test script not found: $test_script"
        SUITE_RESULTS+=("$suite_name: MISSING")
        FAILED_SUITES=$((FAILED_SUITES + 1))
        return 1
    fi

    if bash "$test_script"; then
        SUITE_RESULTS+=("$suite_name: PASSED")
        PASSED_SUITES=$((PASSED_SUITES + 1))
        return 0
    else
        SUITE_RESULTS+=("$suite_name: FAILED")
        FAILED_SUITES=$((FAILED_SUITES + 1))
        return 1
    fi
}

run_all_tests() {
    log_info "=========================================="
    log_info "Running Test Suites"
    log_info "=========================================="
    echo ""

    case "$TEST_MODE" in
        quick)
            log_info "Running QUICK test subset..."
            run_test_suite "Build Tests" "$SCRIPT_DIR/test-build.sh"
            run_test_suite "Services Tests" "$SCRIPT_DIR/test-services.sh"
            run_test_suite "API Tests" "$SCRIPT_DIR/test-api.sh"
            ;;
        dev|prod|default)
            run_test_suite "Build Tests" "$SCRIPT_DIR/test-build.sh"
            run_test_suite "Services Tests" "$SCRIPT_DIR/test-services.sh"
            run_test_suite "API Tests" "$SCRIPT_DIR/test-api.sh"
            run_test_suite "WebSocket Tests" "$SCRIPT_DIR/test-websocket.sh"
            run_test_suite "Integration Tests" "$SCRIPT_DIR/test-integration.sh"
            run_test_suite "Cleanup Tests" "$SCRIPT_DIR/test-cleanup.sh"
            ;;
    esac
}

print_final_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    echo ""
    echo -e "${BLUE}=========================================="
    echo "Test Execution Summary"
    echo "==========================================${NC}"
    echo ""

    for result in "${SUITE_RESULTS[@]}"; do
        if [[ "$result" == *"PASSED"* ]]; then
            echo -e "${GREEN}✓ $result${NC}"
        elif [[ "$result" == *"FAILED"* ]]; then
            echo -e "${RED}✗ $result${NC}"
        else
            echo -e "${YELLOW}? $result${NC}"
        fi
    done

    echo ""
    echo "Test Suites Summary:"
    echo "  Total:   $TOTAL_SUITES"
    echo -e "  Passed:  ${GREEN}$PASSED_SUITES${NC}"
    echo -e "  Failed:  ${RED}$FAILED_SUITES${NC}"
    echo ""
    echo "Execution Time: ${minutes}m ${seconds}s"
    echo -e "${BLUE}==========================================${NC}"
    echo ""

    if [[ $FAILED_SUITES -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}

cleanup_final() {
    if [[ "$KEEP_CONTAINERS" != true ]]; then
        log_info "Stopping and cleaning up services..."
        docker-compose -f "$COMPOSE_FILE" down > /dev/null 2>&1 || true
    else
        log_info "Containers kept running (use 'docker-compose down' to stop)"
    fi
}

# Main execution
main() {
    parse_arguments "$@"

    print_banner
    log_info "Test Mode: $TEST_MODE"
    log_info "Verbose: $VERBOSE"
    log_info "Keep Containers: $KEEP_CONTAINERS"
    echo ""

    # Phase 1: Prerequisites and validation
    if ! validate_prerequisites; then
        log_error "Prerequisite validation failed"
        exit 1
    fi

    if ! verify_config_files; then
        log_error "Configuration verification failed"
        exit 1
    fi

    if ! check_port_availability; then
        log_error "Some required ports are not available"
        exit 1
    fi

    # Phase 2: Setup
    if [[ "$CLEANUP_FIRST" == true ]]; then
        cleanup_services
    fi

    if ! build_images; then
        log_error "Image build phase failed"
        exit 1
    fi

    if ! start_services; then
        log_error "Service startup phase failed"
        exit 1
    fi

    if ! wait_for_services; then
        log_error "Services did not become healthy"
        exit 1
    fi

    # Phase 3: Test execution
    run_all_tests

    # Phase 4: Reporting and cleanup
    print_final_summary
    TEST_RESULT=$?

    cleanup_final

    exit $TEST_RESULT
}

# Trap for cleanup on exit
trap "cleanup_final" EXIT

main "$@"
