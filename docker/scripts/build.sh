#!/bin/bash

###############################################################################
# build.sh - Build Docker images for Happy Server
#
# This script builds Docker images with support for multiple environments:
# - Builds application and supporting service images
# - Displays build progress and image sizes
# - Supports dev and prod environments
#
# Usage: ./docker/scripts/build.sh [environment]
#        ./docker/scripts/build.sh dev     # Default
#        ./docker/scripts/build.sh prod
###############################################################################

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${DOCKER_DIR}/.." && pwd)"

# Helper functions
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}!${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_header() { echo ""; echo -e "${BLUE}═══════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}═══════════════════════════════════════${NC}"; }

# Validate environment argument
validate_environment() {
    local env="${1:-dev}"

    case "$env" in
        dev|prod)
            echo "$env"
            ;;
        *)
            print_error "Invalid environment: $env"
            echo "Supported environments: dev, prod"
            exit 1
            ;;
    esac
}

# Format bytes as human-readable
format_bytes() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc -l)GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(echo "scale=2; $bytes / 1048576" | bc -l)MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(echo "scale=2; $bytes / 1024" | bc -l)KB"
    else
        echo "${bytes}B"
    fi
}

# Get image size
get_image_size() {
    local image_name=$1
    docker inspect "$image_name" \
        --format='{{.Size}}' 2>/dev/null || echo "0"
}

# Show usage information
show_usage() {
    cat << EOF
${BLUE}Usage:${NC}
  ./docker/scripts/build.sh [environment]

${BLUE}Arguments:${NC}
  environment   Build environment: dev (default) or prod

${BLUE}Examples:${NC}
  ./docker/scripts/build.sh          # Build dev images
  ./docker/scripts/build.sh dev      # Explicitly build dev
  ./docker/scripts/build.sh prod     # Build production images

${BLUE}Environment-Specific Behavior:${NC}
  - dev:  Includes development tools and hot-reload capabilities
  - prod: Optimized for production with minimal image size
EOF
}

# Build images
build_images() {
    local env=$1

    print_header "Building Docker Images ($env environment)"

    print_info "Building images from $DOCKER_DIR..."
    echo ""

    cd "$DOCKER_DIR"

    # Build using docker-compose
    if docker-compose -f docker-compose.yml build --progress=plain; then
        print_success "Images built successfully"
        return 0
    else
        print_error "Failed to build images"
        return 1
    fi
}

# Display image information
show_image_info() {
    print_header "Image Summary"

    echo ""
    echo -e "${CYAN}Built Images:${NC}"
    echo ""

    # Get images built by docker-compose
    local image_list=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "happy-server|postgres|redis" || echo "")

    if [ -z "$image_list" ]; then
        print_warning "Could not retrieve image information"
        return
    fi

    local total_size=0
    while IFS= read -r image; do
        local size=$(get_image_size "$image")
        local formatted=$(format_bytes "$size")
        total_size=$((total_size + size))
        printf "  %-40s %10s\n" "$image" "$formatted"
    done <<< "$image_list"

    echo ""
    echo -e "${CYAN}Total Size: $(format_bytes $total_size)${NC}"
    echo ""
}

# Show next steps
show_next_steps() {
    echo ""
    echo "Next steps:"
    echo "  1. Start services: ./docker/scripts/start.sh"
    echo "  2. View logs: ./docker/scripts/logs.sh"
    echo ""
}

# Main execution
main() {
    local env=$(validate_environment "${1:-dev}")

    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
    esac

    # Check docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi

    if ! docker info > /dev/null 2>&1; then
        print_error "Docker daemon is not running"
        exit 1
    fi

    # Build images
    if build_images "$env"; then
        show_image_info
        show_next_steps
        print_success "Build completed successfully!"
    else
        print_error "Build failed"
        exit 1
    fi
}

main "$@"
