#!/bin/bash

###############################################################################
# start.sh - Start Happy Server Docker environment
#
# This script starts the development environment with all services:
# - Starts containers (app, database, redis, etc.)
# - Waits for services to be healthy
# - Displays service URLs and credentials
# - Provides helpful next-step commands
#
# Usage: ./docker/scripts/start.sh
###############################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${DOCKER_DIR}/.." && pwd)"

# Helper functions
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}!${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_header() { echo ""; echo -e "${BLUE}═══════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}═══════════════════════════════════════${NC}"; }

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_success "Docker is available"

    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    print_success "Docker Compose is available"

    # Check Docker daemon
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker daemon is not running. Please start Docker and try again"
        exit 1
    fi
    print_success "Docker daemon is running"

    # Check for .env file
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        print_error ".env file not found at ${PROJECT_ROOT}/.env"
        echo "Run ./docker/scripts/setup.sh first"
        exit 1
    fi
    print_success "Environment file configured"
}

# Start services
start_services() {
    print_header "Starting Services"

    cd "$DOCKER_DIR"

    print_info "Starting containers..."
    echo ""

    if docker-compose -f docker-compose.yml up -d; then
        print_success "Containers started"
    else
        print_error "Failed to start containers"
        exit 1
    fi
}

# Wait for service to be healthy
wait_for_health() {
    local service=$1
    local timeout=${2:-60}
    local elapsed=0
    local interval=2

    print_info "Waiting for $service to be healthy (${timeout}s timeout)..."

    while [ $elapsed -lt $timeout ]; do
        if docker-compose -f "$DOCKER_DIR/docker-compose.yml" ps "$service" 2>/dev/null | grep -q "healthy\|running"; then
            if [ "$(docker-compose -f "$DOCKER_DIR/docker-compose.yml" ps "$service" 2>/dev/null | grep -c 'healthy')" -gt 0 ] || \
               [ "$service" = "happy-server" ]; then
                print_success "$service is healthy"
                return 0
            fi
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
        printf "  Waiting... ${elapsed}s elapsed\r"
    done

    print_warning "$service didn't report healthy within ${timeout}s (may still be running)"
    return 0
}

# Display service URLs and information
show_service_info() {
    print_header "Services Running"

    echo ""
    echo -e "${CYAN}Application URLs:${NC}"
    echo "  Happy Server API:     ${BLUE}http://localhost:3005${NC}"
    echo ""
    echo -e "${CYAN}Data Services:${NC}"
    echo "  PostgreSQL:           localhost:5432"
    echo "  Redis:                localhost:6379"
    echo "  MinIO S3:             ${BLUE}http://localhost:9000${NC}"
    echo ""
    echo -e "${CYAN}Development Tools:${NC}"
    echo "  PgAdmin:              ${BLUE}http://localhost:5050${NC}"
    echo "  Redis Insight:        ${BLUE}http://localhost:8001${NC}"
    echo "  MinIO Console:        ${BLUE}http://localhost:9001${NC}"
    echo ""

    # Get credentials from .env if available
    if [ -f "${PROJECT_ROOT}/.env" ]; then
        local db_url=$(grep DATABASE_URL "${PROJECT_ROOT}/.env" | cut -d= -f2)
        if [ ! -z "$db_url" ]; then
            echo -e "${CYAN}Database Connection:${NC}"
            echo "  URL: $db_url"
            echo ""
        fi
    fi
}

# Show service status
show_service_status() {
    print_header "Service Status"

    cd "$DOCKER_DIR"

    echo ""
    docker-compose -f docker-compose.yml ps
    echo ""
}

# Show helpful commands
show_helpful_commands() {
    print_header "Helpful Commands"

    echo ""
    echo -e "${CYAN}View Logs:${NC}"
    echo "  ./docker/scripts/logs.sh              # View all logs"
    echo "  ./docker/scripts/logs.sh happy-server # View app logs only"
    echo "  ./docker/scripts/logs.sh -f           # Follow logs in real-time"
    echo ""
    echo -e "${CYAN}Database & Migrations:${NC}"
    echo "  ./docker/scripts/migrate.sh           # Run database migrations"
    echo ""
    echo -e "${CYAN}Stop Services:${NC}"
    echo "  ./docker/scripts/stop.sh              # Stop all containers"
    echo "  ./docker/scripts/stop.sh --volumes    # Stop and remove volumes"
    echo ""
    echo -e "${CYAN}Clean Up:${NC}"
    echo "  ./docker/scripts/clean.sh             # Remove all containers, images, volumes"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    start_services

    # Wait for key services
    print_header "Checking Service Health"
    echo ""

    wait_for_health "postgres" 60
    wait_for_health "redis" 30
    wait_for_health "happy-server" 30

    show_service_status
    show_service_info
    show_helpful_commands

    print_success "Happy Server is running! Happy coding!"
}

main
