#!/bin/bash

###############################################################################
# start-prod.sh - Start Happy Server in production mode
#
# This script starts the production environment:
# - Starts optimized containers
# - Waits for services to be healthy
# - Displays app URL
# - Shows important security reminders
#
# Usage: ./docker/scripts/start-prod.sh
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
        print_error "Docker daemon is not running. Please start Docker"
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

# Check production configuration
check_production_config() {
    print_header "Validating Production Configuration"

    local errors=0

    # Check HANDY_MASTER_SECRET is set and not default
    if grep -q "your-super-secret-key-for-local-development" "${PROJECT_ROOT}/.env"; then
        print_error "HANDY_MASTER_SECRET is still using the default value"
        echo "Please update .env with a strong secret key"
        errors=$((errors + 1))
    else
        print_success "HANDY_MASTER_SECRET is configured"
    fi

    # Check NODE_ENV is not set to development
    if grep -q "NODE_ENV=development" "${PROJECT_ROOT}/.env"; then
        print_warning "NODE_ENV is set to development (should be production)"
    else
        print_success "NODE_ENV is properly configured"
    fi

    if [ $errors -gt 0 ]; then
        echo ""
        print_error "Production configuration has issues. Please fix before deploying"
        exit 1
    fi
}

# Start services
start_services() {
    print_header "Starting Production Environment"

    cd "$DOCKER_DIR"

    print_info "Starting containers in production mode..."
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

    print_info "Waiting for $service..."

    while [ $elapsed -lt $timeout ]; do
        if docker-compose -f "$DOCKER_DIR/docker-compose.yml" ps "$service" 2>/dev/null | grep -q "healthy\|running"; then
            print_success "$service is running"
            return 0
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done

    print_warning "$service startup taking longer than expected"
    return 0
}

# Display service information
show_service_info() {
    print_header "Production Deployment Running"

    echo ""
    echo -e "${CYAN}Application URL:${NC}"
    echo "  Happy Server API:  ${BLUE}http://localhost:3000${NC}"
    echo ""
    echo -e "${CYAN}Internal Services:${NC}"
    echo "  PostgreSQL:        localhost:5432"
    echo "  Redis:             localhost:6379"
    echo ""
}

# Show service status
show_service_status() {
    cd "$DOCKER_DIR"

    echo ""
    echo -e "${CYAN}Running Containers:${NC}"
    echo ""
    docker-compose -f docker-compose.yml ps
    echo ""
}

# Show security reminders
show_security_info() {
    print_header "Security Reminders"

    echo ""
    echo -e "${YELLOW}IMPORTANT - Before Going Live:${NC}"
    echo ""
    echo "✓ Ensure HANDY_MASTER_SECRET is a strong, randomly generated key"
    echo "✓ Update DATABASE_URL to point to your production database"
    echo "✓ Set NODE_ENV=production in .env"
    echo "✓ Configure SSL/TLS with a reverse proxy (nginx, AWS ELB, etc.)"
    echo "✓ Enable HTTPS (never send data over plain HTTP in production)"
    echo "✓ Set up proper database backups"
    echo "✓ Configure monitoring and alerting"
    echo "✓ Review and update Redis configuration for production"
    echo "✓ Set up log aggregation and monitoring"
    echo ""
    echo -e "${YELLOW}Sensitive Data:${NC}"
    echo "✓ Never commit .env files to version control"
    echo "✓ Use a secrets manager for production secrets"
    echo "✓ Rotate secrets regularly"
    echo "✓ Monitor access logs for suspicious activity"
    echo ""
}

# Show helpful commands
show_helpful_commands() {
    print_header "Useful Commands"

    echo ""
    echo -e "${CYAN}Monitor Services:${NC}"
    echo "  ./docker/scripts/logs.sh              # View logs"
    echo "  ./docker/scripts/logs.sh -f           # Follow logs"
    echo ""
    echo -e "${CYAN}Stop Services:${NC}"
    echo "  ./docker/scripts/stop.sh              # Stop all containers"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    check_production_config
    start_services

    # Wait for key services
    print_header "Checking Service Health"
    echo ""

    wait_for_health "postgres" 60
    wait_for_health "redis" 30
    wait_for_health "happy-server" 30

    show_service_status
    show_service_info
    show_security_info
    show_helpful_commands

    print_success "Production environment started successfully!"
}

main
