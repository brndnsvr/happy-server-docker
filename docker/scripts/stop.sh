#!/bin/bash

###############################################################################
# stop.sh - Stop Happy Server Docker containers
#
# This script stops the running containers:
# - Gracefully stops all containers
# - Optionally removes volumes (--volumes flag)
# - Preserves images for faster restart
#
# Usage: ./docker/scripts/stop.sh [options]
#        ./docker/scripts/stop.sh            # Stop containers
#        ./docker/scripts/stop.sh --volumes  # Stop and remove volumes
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
  ./docker/scripts/stop.sh [options]

${BLUE}Options:${NC}
  --volumes    Remove volumes (persistent data will be deleted)
  -h, --help   Show this help message

${BLUE}Examples:${NC}
  ./docker/scripts/stop.sh             # Stop containers, keep volumes
  ./docker/scripts/stop.sh --volumes   # Stop containers and remove volumes

${BLUE}Notes:${NC}
  - Containers are stopped gracefully with a 30-second timeout
  - Without --volumes, data is preserved for next restart
  - Images are preserved for faster restart
  - To also remove images, use ./docker/scripts/clean.sh
EOF
}

# Check prerequisites
check_prerequisites() {
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
}

# Stop containers
stop_containers() {
    local remove_volumes=$1

    print_header "Stopping Containers"

    cd "$DOCKER_DIR"

    # Check if any containers are running
    if ! docker-compose ps 2>/dev/null | grep -q "Up"; then
        print_warning "No containers are currently running"
        return 0
    fi

    print_info "Stopping containers gracefully..."
    echo ""

    local cmd="docker-compose down"
    if [ "$remove_volumes" = "true" ]; then
        cmd="$cmd -v"
        print_warning "Volumes will be removed - data will be deleted"
    fi

    if eval "$cmd"; then
        print_success "Containers stopped successfully"
    else
        print_error "Failed to stop containers"
        return 1
    fi
}

# Show status after stopping
show_status() {
    cd "$DOCKER_DIR"

    print_header "Container Status"

    echo ""
    if docker-compose ps 2>/dev/null | grep -q "."; then
        docker-compose ps
    else
        print_success "No containers running"
    fi
    echo ""
}

# Show what was preserved
show_preserved_data() {
    print_header "Data Preservation"

    echo ""
    echo -e "${CYAN}Preserved (for next restart):${NC}"
    echo "  ✓ Docker images"
    echo "  ✓ Database volumes (if --volumes not used)"
    echo "  ✓ Redis data (if --volumes not used)"
    echo "  ✓ MinIO storage (if --volumes not used)"
    echo ""
}

# Show helpful next steps
show_next_steps() {
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo ""
    echo "To restart:"
    echo "  ./docker/scripts/start.sh"
    echo ""
    echo "To clean everything (images, containers, volumes):"
    echo "  ./docker/scripts/clean.sh"
    echo ""
    echo "To rebuild and restart:"
    echo "  ./docker/scripts/build.sh && ./docker/scripts/start.sh"
    echo ""
}

# Main execution
main() {
    local remove_volumes=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --volumes)
                remove_volumes=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    check_prerequisites
    stop_containers "$remove_volumes"
    show_status

    if [ "$remove_volumes" = "true" ]; then
        print_warning "Volumes and data have been removed"
    else
        show_preserved_data
    fi

    show_next_steps

    print_success "Stop completed successfully!"
}

main "$@"
