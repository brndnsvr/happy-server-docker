#!/bin/bash

###############################################################################
# clean.sh - Clean up all Docker resources for Happy Server
#
# This script completely removes all Docker resources:
# - Removes all containers
# - Removes all volumes (data will be permanently deleted)
# - Removes all networks
# - Optionally removes all images
#
# WARNING: This operation cannot be undone!
#
# Usage: ./docker/scripts/clean.sh
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

# Show warning
show_warning() {
    print_header "WARNING - Destructive Operation"

    echo ""
    echo -e "${RED}This operation will permanently delete:${NC}"
    echo "  ✗ All Docker containers"
    echo "  ✗ All volumes (including databases, caches, and files)"
    echo "  ✗ All networks"
    echo "  ✗ All images"
    echo ""
    echo -e "${RED}This operation CANNOT be undone!${NC}"
    echo ""
}

# Confirm with user
confirm_cleanup() {
    echo -e "${YELLOW}Type 'yes' to confirm cleanup:${NC}"
    read -r confirmation

    if [ "$confirmation" != "yes" ]; then
        print_info "Cleanup cancelled"
        exit 0
    fi

    echo ""
    echo -e "${YELLOW}Are you absolutely sure? Type 'yes-i-am-sure' to continue:${NC}"
    read -r double_confirmation

    if [ "$double_confirmation" != "yes-i-am-sure" ]; then
        print_info "Cleanup cancelled"
        exit 0
    fi
}

# Stop and remove containers
cleanup_containers() {
    print_header "Removing Containers & Volumes"

    cd "$DOCKER_DIR"

    print_info "Removing containers, volumes, and networks..."
    echo ""

    if docker-compose down -v --rmi all 2>/dev/null || true; then
        print_success "Containers, volumes, and networks removed"
    fi
}

# Remove dangling resources
cleanup_dangling() {
    print_header "Cleaning Up Dangling Resources"

    print_info "Removing dangling images..."
    local dangling_count=$(docker images -f "dangling=true" -q | wc -l)

    if [ "$dangling_count" -gt 0 ]; then
        docker rmi $(docker images -f "dangling=true" -q) 2>/dev/null || true
        print_success "Removed $dangling_count dangling images"
    else
        print_info "No dangling images to remove"
    fi

    print_info "Removing unused volumes..."
    docker volume prune -f 2>/dev/null || true
    print_success "Volume cleanup completed"

    print_info "Removing unused networks..."
    docker network prune -f 2>/dev/null || true
    print_success "Network cleanup completed"
}

# Show cleanup summary
show_cleanup_summary() {
    print_header "Cleanup Summary"

    echo ""
    echo -e "${CYAN}Docker System Status:${NC}"
    echo ""

    local image_count=$(docker images -q | wc -l)
    local container_count=$(docker ps -aq | wc -l)
    local volume_count=$(docker volume ls -q | wc -l)
    local network_count=$(docker network ls -q | wc -l)

    echo "  Images:     $image_count"
    echo "  Containers: $container_count"
    echo "  Volumes:    $volume_count"
    echo "  Networks:   $network_count"
    echo ""

    print_success "All resources have been cleaned up"
}

# Show next steps
show_next_steps() {
    print_header "Next Steps"

    echo ""
    echo "To start fresh:"
    echo "  1. Run setup: ./docker/scripts/setup.sh"
    echo "  2. Build images: ./docker/scripts/build.sh"
    echo "  3. Start services: ./docker/scripts/start.sh"
    echo ""
}

# Main execution
main() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi

    show_warning
    confirm_cleanup
    cleanup_containers
    cleanup_dangling
    show_cleanup_summary
    show_next_steps

    print_success "Cleanup completed successfully!"
}

main
