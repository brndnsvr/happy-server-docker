#!/bin/bash

###############################################################################
# migrate.sh - Run Prisma database migrations in Docker
#
# This script runs Prisma migrations:
# - Ensures database is running
# - Executes pending migrations
# - Shows migration status
# - Handles errors gracefully
#
# Usage: ./docker/scripts/migrate.sh
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

    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    print_success "Docker Compose is available"

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_success "Docker is available"
}

# Check if database is running
check_database_running() {
    print_header "Checking Database Status"

    cd "$DOCKER_DIR"

    local db_status=$(docker-compose ps postgres 2>/dev/null | grep postgres || echo "")

    if [ -z "$db_status" ]; then
        print_warning "Database container is not running"
        print_info "Starting database..."
        echo ""

        if docker-compose up -d postgres; then
            print_success "Database started"
            sleep 5
        else
            print_error "Failed to start database"
            exit 1
        fi
    elif echo "$db_status" | grep -q "Up\|running"; then
        print_success "Database is running"
    else
        print_warning "Database is not responding"
        print_info "Restarting database..."
        docker-compose restart postgres
        sleep 5
    fi
}

# Wait for database to be ready
wait_for_database() {
    local timeout=60
    local elapsed=0
    local interval=2

    print_info "Waiting for database to be ready..."

    while [ $elapsed -lt $timeout ]; do
        if docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then
            print_success "Database is ready"
            return 0
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
        printf "  Waiting... ${elapsed}s elapsed\r"
    done

    print_error "Database did not become ready within ${timeout}s"
    exit 1
}

# Run migrations
run_migrations() {
    print_header "Running Migrations"

    cd "$DOCKER_DIR"

    print_info "Executing Prisma migrations..."
    echo ""

    # Check if app container exists, if not use postgres for migrations
    if docker-compose ps happy-server 2>/dev/null | grep -q happy-server; then
        # Use app container to run migrations
        if docker-compose exec -T happy-server yarn migrate; then
            print_success "Migrations completed successfully"
            return 0
        else
            print_error "Migrations failed"
            return 1
        fi
    else
        print_warning "App container not running, running migrations locally..."
        echo ""

        # Run migrations locally
        cd "$PROJECT_ROOT"

        if [ ! -f ".env" ]; then
            print_error ".env file not found"
            exit 1
        fi

        # Export environment variables from .env
        set -a
        source .env
        set +a

        if command -v yarn &> /dev/null; then
            if yarn migrate; then
                print_success "Migrations completed successfully"
                return 0
            else
                print_error "Migrations failed"
                return 1
            fi
        else
            print_error "Yarn is not installed locally"
            echo "Please start the app container or install dependencies locally"
            exit 1
        fi
    fi
}

# Show migration status
show_migration_status() {
    print_header "Migration Status"

    echo ""
    print_info "Recent migrations applied successfully"

    cd "$DOCKER_DIR"

    # Try to show migration history if possible
    if docker-compose exec -T postgres psql -U postgres -d handy -c "\dt" > /dev/null 2>&1; then
        echo ""
        echo -e "${CYAN}Database Tables Created:${NC}"
        docker-compose exec -T postgres psql -U postgres -d handy -c "\dt" 2>/dev/null | grep -v "^-" | tail -n +2 || true
    fi

    echo ""
}

# Show helpful information
show_helpful_info() {
    print_header "Migration Information"

    echo ""
    echo -e "${CYAN}About Migrations:${NC}"
    echo "  - Migrations are defined in the Prisma schema"
    echo "  - Each migration creates a migration file in prisma/migrations/"
    echo "  - Migrations are applied in order to the database"
    echo "  - Migration history is tracked in the _prisma_migrations table"
    echo ""
    echo -e "${CYAN}Common Scenarios:${NC}"
    echo "  - New schema changes: Already applied via setup"
    echo "  - Revert to specific state: Contact database administrator"
    echo "  - Check pending migrations: ./docker/scripts/logs.sh | grep migration"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    check_database_running
    wait_for_database
    run_migrations
    show_migration_status
    show_helpful_info

    print_success "Database migrations completed successfully!"
}

main
