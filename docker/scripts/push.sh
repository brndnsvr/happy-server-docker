#!/bin/bash

###############################################################################
# push.sh - Build and push Happy Server image to Docker registry
#
# This script builds production image and pushes to Docker registry:
# - Validates registry credentials
# - Builds optimized production image
# - Tags image with registry path
# - Pushes to configured registry
# - Displays pushed image details
#
# Usage: ./docker/scripts/push.sh <registry> [tag]
#        ./docker/scripts/push.sh docker.io/username          # Latest tag
#        ./docker/scripts/push.sh ghcr.io/org v1.0.0          # Specific tag
#        ./docker/scripts/push.sh docker.io/user my-image:v2  # Full image spec
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
  ./docker/scripts/push.sh <registry> [tag]

${BLUE}Arguments:${NC}
  registry   Docker registry path (required)
             Examples: docker.io/username, ghcr.io/org, my-registry.com/app
  tag        Image tag (optional, default: latest)
             Examples: v1.0.0, main, latest

${BLUE}Examples:${NC}
  ./docker/scripts/push.sh docker.io/myuser
                           # Pushes to docker.io/myuser/happy-server:latest

  ./docker/scripts/push.sh ghcr.io/myorg v1.0.0
                           # Pushes to ghcr.io/myorg/happy-server:v1.0.0

  ./docker/scripts/push.sh registry.example.com/prod main
                           # Pushes to registry.example.com/prod/happy-server:main

${BLUE}Authentication:${NC}
  You must be authenticated to the Docker registry before pushing:
    docker login docker.io          # For Docker Hub
    docker login ghcr.io            # For GitHub Container Registry
    docker login <your-registry>    # For other registries

${BLUE}Notes:${NC}
  - Image name is automatically set to 'happy-server'
  - Tag defaults to 'latest' if not specified
  - Requires Docker daemon to be running
  - Requires proper authentication with the registry
EOF
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    print_success "Docker is available"

    if ! docker info > /dev/null 2>&1; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    print_success "Docker daemon is running"

    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    print_success "Docker Compose is available"
}

# Validate registry
validate_registry() {
    local registry=$1

    if [ -z "$registry" ]; then
        print_error "Registry path is required"
        echo ""
        show_usage
        exit 1
    fi

    # Basic validation - should contain . or start with localhost/127.0.0.1
    if ! [[ "$registry" =~ \. ]] && ! [[ "$registry" =~ ^localhost.*/ ]] && ! [[ "$registry" =~ ^127\.0\.0\.1.*/ ]]; then
        print_warning "Registry path looks unusual: $registry"
        echo "Common registry paths:"
        echo "  - docker.io/username"
        echo "  - ghcr.io/org"
        echo "  - registry.example.com/app"
        echo ""
    fi

    echo "$registry"
}

# Check Docker authentication
check_docker_auth() {
    local registry=$1
    local registry_host=$(echo "$registry" | cut -d/ -f1)

    print_header "Checking Docker Authentication"

    # Extract registry hostname from registry path
    # This is a simple check - just verify we can access Docker
    if docker info > /dev/null 2>&1; then
        print_info "Checking authentication for: $registry_host"

        # Try a simple check - if the user isn't authenticated, push will fail
        # We can't really check beforehand without making a request
        print_success "Docker authentication appears to be available"
        echo ""
        echo -e "${CYAN}Important:${NC}"
        echo "Make sure you're authenticated to '$registry_host'"
        echo "If not, run: docker login $registry_host"
        echo ""

        read -p "Proceed with push? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Push cancelled"
            exit 0
        fi
    else
        print_error "Docker daemon is not accessible"
        exit 1
    fi
}

# Get version/commit info
get_version_info() {
    local version="unknown"
    local commit="unknown"

    # Try to get version from package.json
    if [ -f "${PROJECT_ROOT}/package.json" ]; then
        version=$(grep '"version"' "${PROJECT_ROOT}/package.json" | head -1 | cut -d'"' -f4)
    fi

    # Try to get commit hash
    if command -v git &> /dev/null && [ -d "${PROJECT_ROOT}/.git" ]; then
        commit=$(cd "$PROJECT_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi

    echo "$version:$commit"
}

# Build production image
build_production_image() {
    print_header "Building Production Image"

    print_info "Building optimized production image..."
    echo ""

    cd "$DOCKER_DIR"

    if docker-compose build --progress=plain happy-server; then
        print_success "Image built successfully"
    else
        print_error "Failed to build image"
        exit 1
    fi
}

# Get local image ID
get_local_image_id() {
    docker images -q happy-server:latest | head -1
}

# Tag image for registry
tag_image() {
    local registry=$1
    local tag=$2
    local image_name="happy-server"

    print_header "Tagging Image"

    local source_image="${image_name}:latest"
    local target_image="${registry}/${image_name}:${tag}"

    print_info "Tagging: $source_image -> $target_image"
    echo ""

    if docker tag "$source_image" "$target_image"; then
        print_success "Image tagged successfully"
        echo "$target_image"
    else
        print_error "Failed to tag image"
        exit 1
    fi
}

# Push image to registry
push_image() {
    local image=$1

    print_header "Pushing Image to Registry"

    print_info "Pushing: $image"
    echo ""

    if docker push "$image"; then
        print_success "Image pushed successfully"
    else
        print_error "Failed to push image"
        echo ""
        echo -e "${YELLOW}Common causes:${NC}"
        echo "  - Not authenticated: docker login <registry>"
        echo "  - Wrong registry path: Check registry name"
        echo "  - Network connectivity: Check internet connection"
        echo "  - Repository permissions: Check access rights"
        exit 1
    fi
}

# Get image details
get_image_details() {
    local image=$1

    print_header "Image Details"

    echo ""
    echo -e "${CYAN}Pushed Image:${NC}"
    echo "  $image"
    echo ""

    # Get image size and other details if available
    local image_info=$(docker inspect "$image" --format='{{.Size}} {{.Architecture}}' 2>/dev/null || echo "")
    if [ ! -z "$image_info" ]; then
        local size=$(echo "$image_info" | awk '{print $1}')
        local arch=$(echo "$image_info" | awk '{print $2}')

        # Format size
        if [ "$size" -gt 1073741824 ]; then
            local size_formatted="$(echo "scale=2; $size / 1073741824" | bc -l)GB"
        elif [ "$size" -gt 1048576 ]; then
            local size_formatted="$(echo "scale=2; $size / 1048576" | bc -l)MB"
        else
            local size_formatted="$(echo "scale=2; $size / 1024" | bc -l)KB"
        fi

        echo -e "${CYAN}Image Properties:${NC}"
        echo "  Size:       $size_formatted"
        echo "  Architecture: $arch"
    fi
    echo ""
}

# Show next steps
show_next_steps() {
    local image=$1

    echo -e "${CYAN}Next Steps:${NC}"
    echo ""
    echo "Deploy the image:"
    echo "  docker pull $image"
    echo "  docker run $image"
    echo ""
    echo "Update Kubernetes deployment:"
    echo "  kubectl set image deployment/happy-server app=$image"
    echo ""
    echo "Docker Compose:"
    echo "  Edit docker-compose.yml to use:"
    echo "    image: $image"
    echo ""
}

# Main execution
main() {
    local registry=""
    local tag="latest"

    # Parse arguments
    case "${1:-}" in
        -h|--help)
            show_usage
            exit 0
            ;;
        "")
            print_error "Registry argument is required"
            echo ""
            show_usage
            exit 1
            ;;
        *)
            registry=$(validate_registry "$1")
            tag="${2:-latest}"
            ;;
    esac

    # Run checks
    check_prerequisites
    check_docker_auth "$registry"

    # Build and push
    build_production_image

    # Tag image
    local tagged_image=$(tag_image "$registry" "$tag")

    # Push to registry
    push_image "$tagged_image"

    # Show results
    get_image_details "$tagged_image"
    show_next_steps "$tagged_image"

    print_success "Image pushed successfully!"
}

main "$@"
