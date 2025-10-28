#!/bin/bash

###############################################################################
# setup.sh - Initial Happy Server Docker setup
#
# This script initializes the Docker environment for Happy Server:
# - Checks Docker and Docker Compose prerequisites
# - Configures environment variables
# - Builds Docker images
# - Guides user through next steps
#
# Usage: ./docker/scripts/setup.sh
###############################################################################

set -e

# Color output for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCKER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Print colored output
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
}

# Check if Docker is installed
check_docker() {
    print_header "Checking Docker Installation"

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        echo "Please install Docker from https://www.docker.com/products/docker-desktop"
        exit 1
    fi

    print_success "Docker is installed: $(docker --version)"

    # Check if Docker daemon is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker daemon is not running"
        echo "Please start Docker and try again"
        exit 1
    fi

    print_success "Docker daemon is running"
}

# Check if Docker Compose is installed
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        echo "Please install Docker Compose from https://docs.docker.com/compose/install/"
        exit 1
    fi

    print_success "Docker Compose is installed: $(docker-compose --version)"
}

# Setup environment file
setup_env_file() {
    print_header "Configuring Environment Variables"

    local env_file="${PROJECT_ROOT}/.env"
    local env_example="${PROJECT_ROOT}/.env.dev"

    if [ -f "$env_file" ]; then
        print_warning ".env file already exists"
        read -p "Do you want to overwrite it? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping existing .env file"
            return
        fi
    fi

    if [ ! -f "$env_example" ]; then
        print_error ".env.dev example file not found at $env_example"
        exit 1
    fi

    cp "$env_example" "$env_file"
    print_success "Created .env file from .env.dev template"

    print_info "Review and update the following settings in .env:"
    echo "  - DATABASE_URL (if using non-local database)"
    echo "  - HANDY_MASTER_SECRET (generate a strong secret key)"
    echo "  - S3_* settings (MinIO credentials)"

    read -p "Have you reviewed and updated .env? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Please edit .env and run setup again:"
        echo "  $env_file"
        exit 1
    fi

    print_success "Environment variables configured"
}

# Build Docker images
build_images() {
    print_header "Building Docker Images"

    print_info "Building Happy Server Docker image..."
    print_info "This may take a few minutes on first run..."
    echo ""

    cd "$DOCKER_DIR"

    if docker-compose build; then
        print_success "Docker images built successfully"
    else
        print_error "Failed to build Docker images"
        exit 1
    fi
}

# Display next steps
show_next_steps() {
    print_header "Setup Complete!"

    echo ""
    echo "Next steps to get Happy Server running:"
    echo ""
    echo "1. Start the development environment:"
    echo "   ${BLUE}./docker/scripts/start.sh${NC}"
    echo ""
    echo "2. Run database migrations:"
    echo "   ${BLUE}./docker/scripts/migrate.sh${NC}"
    echo ""
    echo "3. View logs:"
    echo "   ${BLUE}./docker/scripts/logs.sh${NC}"
    echo ""
    echo "Available services will be running at:"
    echo "  - Happy Server API: http://localhost:3005"
    echo "  - PostgreSQL: localhost:5432"
    echo "  - Redis: localhost:6379"
    echo "  - MinIO: http://localhost:9000"
    echo ""
    echo "For more help, see:"
    echo "  - Start: ./docker/scripts/start.sh --help"
    echo "  - Stop: ./docker/scripts/stop.sh --help"
    echo "  - Logs: ./docker/scripts/logs.sh --help"
    echo ""
}

# Main execution
main() {
    print_header "Happy Server Docker Setup"

    check_docker
    check_docker_compose
    setup_env_file
    build_images
    show_next_steps

    print_success "Setup completed successfully!"
}

main
