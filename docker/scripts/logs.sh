#!/bin/bash

###############################################################################
# logs.sh - View Docker container logs for Happy Server
#
# This script displays logs from Docker containers:
# - View logs from all services or specific services
# - Follow logs in real-time with -f flag
# - Includes helpful filtering and formatting
#
# Usage: ./docker/scripts/logs.sh [service] [options]
#        ./docker/scripts/logs.sh                    # All services
#        ./docker/scripts/logs.sh happy-server       # App only
#        ./docker/scripts/logs.sh postgres           # Database only
#        ./docker/scripts/logs.sh happy-server -f    # Follow app logs
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

# Show usage
show_usage() {
    cat << EOF
${BLUE}Usage:${NC}
  ./docker/scripts/logs.sh [service] [options]

${BLUE}Services:${NC}
  happy-server   Application container
  postgres       PostgreSQL database
  redis          Redis cache
  minio          MinIO S3 storage
  nginx          Nginx reverse proxy
  pgadmin        PostgreSQL admin interface
  redisinsight   Redis admin interface
  (leave blank)  All services

${BLUE}Options:${NC}
  -f, --follow   Follow logs in real-time (Ctrl+C to exit)
  -n, --lines N  Show last N lines (default: 100)
  --tail N       Show last N lines (same as -n)
  -h, --help     Show this help message

${BLUE}Examples:${NC}
  ./docker/scripts/logs.sh                    # View all logs
  ./docker/scripts/logs.sh happy-server       # View app logs
  ./docker/scripts/logs.sh happy-server -f    # Follow app logs
  ./docker/scripts/logs.sh -f                 # Follow all logs
  ./docker/scripts/logs.sh postgres -n 50     # Last 50 lines of DB
  ./docker/scripts/logs.sh redis --follow     # Follow Redis logs

${BLUE}Tips:${NC}
  - Use -f to watch logs in real-time as events happen
  - Use -n to see more or fewer lines of history
  - Combine service name + -f for focused monitoring
  - Press Ctrl+C to exit follow mode
  - Pipe to grep for filtering: ./docker/scripts/logs.sh | grep error
EOF
}

# Validate service name
validate_service() {
    local service=$1

    case "$service" in
        happy-server|postgres|redis|minio|nginx|pgadmin|redisinsight|"")
            echo "$service"
            ;;
        *)
            print_error "Unknown service: $service"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Get container name
get_container_name() {
    local service=$1

    if [ -z "$service" ]; then
        echo ""
        return
    fi

    # Docker-compose prefixes container names with project directory name
    local prefix=$(basename "$DOCKER_DIR")
    echo "${prefix}_${service}_1"
}

# View logs
view_logs() {
    local service=$1
    shift
    local args=("$@")

    cd "$DOCKER_DIR"

    # Check if containers are running
    if ! docker-compose ps 2>/dev/null | grep -q "Up"; then
        print_warning "No containers are currently running"
        echo "Start containers with: ./docker/scripts/start.sh"
        exit 0
    fi

    if [ -z "$service" ]; then
        # All services
        if [ ${#args[@]} -gt 0 ]; then
            docker-compose logs "${args[@]}"
        else
            docker-compose logs --tail 100
        fi
    else
        # Specific service
        if [ ${#args[@]} -gt 0 ]; then
            docker-compose logs "$service" "${args[@]}"
        else
            docker-compose logs --tail 100 "$service"
        fi
    fi
}

# Show available containers
show_available_services() {
    print_header "Available Services"

    cd "$DOCKER_DIR"

    echo ""
    echo -e "${CYAN}Running Containers:${NC}"
    echo ""

    if docker-compose ps 2>/dev/null | grep -q "Up"; then
        docker-compose ps | grep "Up" | awk '{print "  " $1}' || true
        echo ""
    else
        print_warning "No containers are running"
        echo ""
    fi
}

# Show helpful tips
show_helpful_tips() {
    echo ""
    echo -e "${CYAN}Helpful Monitoring Commands:${NC}"
    echo ""
    echo "  # Watch for errors in real-time"
    echo "  ./docker/scripts/logs.sh happy-server -f | grep -i error"
    echo ""
    echo "  # Monitor database queries"
    echo "  ./docker/scripts/logs.sh postgres -f"
    echo ""
    echo "  # Watch Redis activity"
    echo "  ./docker/scripts/logs.sh redis -f"
    echo ""
    echo "  # Show last 200 lines of app logs"
    echo "  ./docker/scripts/logs.sh happy-server -n 200"
    echo ""
    echo "  # Follow all logs simultaneously"
    echo "  ./docker/scripts/logs.sh -f"
    echo ""
}

# Main execution
main() {
    local service=""
    local args=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -f|--follow)
                args+=("--follow")
                shift
                ;;
            -n|--lines|--tail)
                args+=("--tail" "$2")
                shift 2
                ;;
            -*)
                print_error "Unknown option: $1"
                echo ""
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$service" ]; then
                    service=$(validate_service "$1")
                    shift
                else
                    args+=("$1")
                    shift
                fi
                ;;
        esac
    done

    # Show available services if just asking for help
    if [ ${#args[@]} -eq 0 ] && [ -z "$service" ]; then
        show_available_services
    fi

    # Check docker-compose availability
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi

    # View logs
    view_logs "$service" "${args[@]}"

    # Show tips on exit from follow mode
    if [[ " ${args[@]} " =~ " --follow " ]]; then
        show_helpful_tips
    fi
}

main "$@"
