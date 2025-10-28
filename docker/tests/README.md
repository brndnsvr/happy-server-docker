# Happy Server Docker Test Suite

Automated integration and validation tests for the Happy Server Docker infrastructure.

## Overview

This test suite validates that the Docker setup builds correctly, all services start properly, and the Happy Server API responds to requests as expected. The suite provides comprehensive coverage of build artifacts, service health, API endpoints, WebSocket connectivity, and end-to-end integration workflows.

### Test Coverage

- **Build Tests** (`test-build.sh`): Docker image validation, multi-stage build verification, dependency checking
- **Service Tests** (`test-services.sh`): Container health checks, inter-service networking, service connectivity
- **API Tests** (`test-api.sh`): HTTP endpoints, authentication flows, error handling, response validation
- **WebSocket Tests** (`test-websocket.sh`): Socket.io connectivity through Nginx, real-time messaging
- **Integration Tests** (`test-integration.sh`): End-to-end workflows, data persistence, cross-service interactions
- **Cleanup Tests** (`test-cleanup.sh`): Graceful shutdown, volume persistence, state preservation

## Quick Start

### Prerequisites

**Required:**
- Docker 20.10 or higher
- Docker Compose 2.0 or higher
- bash 4.0 or higher
- curl
- jq (for JSON parsing)
- nc (netcat, for port checking)

**Optional (for WebSocket tests):**
- wscat (`npm install -g wscat`)
- websocat (see: https://github.com/vi/websocat)

### Installation

```bash
# Verify Docker installation
docker --version
docker compose version

# Ensure jq is installed (macOS)
brew install jq

# Optional: Install wscat for WebSocket testing
npm install -g wscat

# From project root
cd docker/tests
```

### Running Tests

```bash
# Run full test suite (development mode)
./run-tests.sh --dev

# Run quick smoke tests
./run-tests.sh --dev --quick

# Run with verbose output
./run-tests.sh --dev --verbose

# Run production configuration tests
./run-tests.sh --prod

# Keep containers running after tests
./run-tests.sh --dev --keep

# Show help
./run-tests.sh --help
```

## Test Suite Structure

```
tests/
├── run-tests.sh                      # Main test orchestrator script
├── test-build.sh                     # Docker build validation tests
├── test-services.sh                  # Service health and connectivity tests
├── test-api.sh                       # API endpoint and HTTP tests
├── test-websocket.sh                 # WebSocket/Socket.io tests
├── test-integration.sh               # End-to-end integration tests
├── test-cleanup.sh                   # Cleanup and persistence tests
├── helpers/
│   ├── test-helpers.sh               # Assertion and logging functions
│   ├── wait-for-services.sh          # Service readiness utilities
│   └── api-client.sh                 # HTTP client wrapper functions
├── fixtures/
│   ├── test-user.json                # Mock user data for testing
│   ├── test-session.json             # Sample session data
│   └── expected-responses/
│       └── health.json               # Expected API response schemas
└── README.md                         # This file
```

## Usage Guide

### Full Test Suite

```bash
./run-tests.sh [options]
```

**Options:**
- `--dev` - Use development configuration (default)
- `--prod` - Use production configuration with stricter requirements
- `--quick` - Run only essential smoke tests (faster execution)
- `--verbose` - Show detailed output from all test suites
- `--keep` - Keep containers running after tests complete
- `--clean` - Remove existing containers before starting
- `-h, --help` - Show usage information

### Examples

```bash
# Development workflow: quick tests with verbose output
./run-tests.sh --dev --quick --verbose

# CI/CD pipeline: production configuration with clean state
./run-tests.sh --prod --clean

# Debugging: keep containers running for manual inspection
./run-tests.sh --dev --verbose --keep

# Quick sanity check: run only essential smoke tests
./run-tests.sh --dev --quick
```

## Test Suites Detail

### Build Tests (`test-build.sh`)

Validates Docker image creation and Dockerfile configuration.

**Tests included:**
- Dockerfile exists and is readable
- Docker image builds successfully with all layers
- Multi-stage build produces correct final image
- Image size is within acceptable range
- All required binaries are present in final image
- Node.js version matches requirements
- TypeScript compilation succeeds
- Dependencies resolve without conflicts

**Exit codes:**
- 0 = All build tests passed
- 1 = Build validation failed

### Service Tests (`test-services.sh`)

Validates all services start properly and are healthy.

**Tests included:**
- PostgreSQL database starts and is responsive
- PostgreSQL accepts connections with configured credentials
- Redis cache starts and responds to PING
- MinIO object storage starts and health check passes
- Happy Server API starts without errors
- Nginx reverse proxy starts successfully
- All services can communicate over happy-network
- Port mappings are correctly configured
- Container restart policies are honored

**Service health checks:**
- PostgreSQL: `pg_isready` command
- Redis: `redis-cli PING` command
- MinIO: HTTP health endpoint
- Happy Server: `/health` endpoint response
- Nginx: TCP port accessibility

### API Tests (`test-api.sh`)

Validates HTTP endpoints respond correctly.

**Tests included:**
- Health endpoint returns 200 OK
- Health endpoint response matches expected schema
- All required services report as connected
- Timestamp field is numeric
- Version field is a string
- Additional endpoint validation for configured routes
- Proper HTTP status codes for various scenarios
- Content-type headers are correct
- CORS headers are properly set

**Endpoints tested:**
- `GET /health` - Service health and status

### WebSocket Tests (`test-websocket.sh`)

Validates Socket.io connectivity through Nginx.

**Tests included:**
- WebSocket connection establishes through Nginx (port 80)
- Socket.io protocol handshake completes
- Message delivery works in both directions
- Disconnection is handled gracefully
- Connection state is properly tracked
- Binary data transmission works correctly

**Requirements:**
- wscat or websocat must be installed for testing

### Integration Tests (`test-integration.sh`)

End-to-end workflow validation.

**Tests included:**
- User data can be created and persisted
- Session data persists across requests
- Cross-service data consistency
- Event pub/sub works end-to-end
- Cache operations function correctly
- Storage operations work with MinIO
- Database transactions complete successfully
- State recovery after simulated failures

### Cleanup Tests (`test-cleanup.sh`)

Validates graceful shutdown and data persistence.

**Tests included:**
- Containers shut down gracefully
- Volume data persists after shutdown
- Database data recovers on restart
- Cache state is recovered from Redis
- Storage objects remain in MinIO
- Clean restart produces consistent state

## Test Execution Flow

```
1. Validation Phase
   ├─ Check Docker/Compose availability
   ├─ Verify required tools installed
   ├─ Validate .env configuration
   └─ Check available disk space

2. Setup Phase
   ├─ Clean existing containers (if --clean)
   ├─ Build Docker images
   ├─ Create volumes
   ├─ Start all services (docker-compose up)
   └─ Wait for services to be ready

3. Wait Phase
   ├─ Wait for PostgreSQL (max 30s)
   ├─ Wait for Redis (max 10s)
   ├─ Wait for MinIO (max 30s)
   ├─ Wait for Happy Server health check (max 60s)
   ├─ Wait for Nginx (max 10s)
   └─ Total max wait: 120 seconds

4. Test Phase
   ├─ Run build tests (if building)
   ├─ Run service tests (always)
   ├─ Run API tests (always)
   ├─ Run WebSocket tests (if wscat available)
   ├─ Run integration tests (if --quick not set)
   └─ Run cleanup tests (at end)

5. Report Phase
   ├─ Count passed/failed/skipped tests
   ├─ Display test summary
   ├─ Report execution time
   └─ Show recommendations for failures

6. Cleanup Phase
   ├─ Stop containers (unless --keep)
   ├─ Remove test artifacts
   ├─ Clean up temporary files
   └─ Preserve volumes (unless --clean)
```

## Expected Runtime

- **Full test suite**: 3-5 minutes
  - Build: 1-2 minutes
  - Service startup: 1-2 minutes
  - Tests: 1 minute

- **Quick smoke tests**: 1-2 minutes
  - Service startup: 1-2 minutes
  - Tests: 30 seconds

- **Individual suite**: 30-60 seconds
  - Depends on which suite is running

## Exit Codes

- `0` - All tests passed
- `1` - One or more tests failed
- `2` - Setup or prerequisite error
- `3` - Container startup timeout
- `4` - Service health check failed
- `5` - Missing required tools

## Test Helpers

### Assertions (test-helpers.sh)

These functions help validate test results:

```bash
# Assert equality
assert_equal <expected> <actual> <message>

# Assert string contains substring
assert_contains <haystack> <needle> <message>

# Assert HTTP status code
assert_http_status <expected_code> <actual_code> <message>

# Assert service is healthy
assert_service_healthy <service_name> <timeout>

# Assert file exists
assert_file_exists <file_path> <message>

# Assert value is not empty
assert_not_empty <value> <message>

# Assert JSON field matches
assert_json_field <json_string> <field_path> <expected_value> <message>
```

### Service Waiters (wait-for-services.sh)

These functions wait for services to become ready:

```bash
# Wait for TCP port to be accessible
wait_for_port <host> <port> <timeout_seconds>

# Wait for PostgreSQL to accept connections
wait_for_postgres <timeout_seconds>

# Wait for Redis to respond to PING
wait_for_redis <timeout_seconds>

# Wait for MinIO health endpoint
wait_for_minio <timeout_seconds>

# Wait for Happy Server API health check
wait_for_api_health <timeout_seconds>

# Wait for Nginx to be accessible
wait_for_nginx <timeout_seconds>

# Wait for all services to be healthy
wait_for_all <timeout_seconds>
```

### API Client (api-client.sh)

Wrapper functions for HTTP requests:

```bash
# Set base URL for subsequent requests
set_base_url <url>

# Set authorization token
set_api_token <token>

# Make GET request
api_get <endpoint> [headers_json]
# Example: api_get "/health" '{"X-Custom": "value"}'

# Make POST request with data
api_post <endpoint> <data_json> [headers_json]
# Example: api_post "/users" '{"name": "test"}' '{"X-Custom": "value"}'

# Make DELETE request
api_delete <endpoint> [headers_json]

# Extract field from JSON response
extract_json_field <json_string> <field_path>
# Example: extract_json_field "$response" ".data.user.id"
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Docker Tests
on: [push, pull_request]

jobs:
  docker-tests:
    runs-on: ubuntu-latest
    services:
      docker:
        image: docker:latest
        options: --privileged

    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker
        run: |
          docker --version
          docker compose version

      - name: Run Docker tests
        run: |
          cd docker/tests
          ./run-tests.sh --prod --clean

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: docker/tests/.test-results/
```

### GitLab CI

```yaml
docker-tests:
  image: docker:latest
  services:
    - docker:dind
  variables:
    DOCKER_DRIVER: overlay2
    DOCKER_TLS_CERTDIR: "/certs"

  script:
    - apk add --no-cache bash curl jq
    - cd docker/tests
    - ./run-tests.sh --prod --clean

  artifacts:
    paths:
      - docker/tests/.test-results/
    expire_in: 1 week
    when: always
```

### Jenkins Pipeline

```groovy
pipeline {
  agent any

  stages {
    stage('Run Docker Tests') {
      steps {
        sh '''
          cd docker/tests
          ./run-tests.sh --prod --clean
        '''
      }
    }

    stage('Archive Results') {
      steps {
        archiveArtifacts artifacts: 'docker/tests/.test-results/**'
      }
    }
  }

  post {
    always {
      junit 'docker/tests/.test-results/results.xml'
    }
  }
}
```

## Troubleshooting

### Tests Fail to Start Services

**Problem**: Services don't start or exit immediately

```bash
# Check if ports are already in use
netstat -tuln | grep -E ':(3000|5432|6379|9000|80)'
# or on macOS
lsof -i -P -n | grep LISTEN | grep -E ':(3000|5432|6379|9000|80)'

# Clean up existing containers
cd /Users/bss/code/happy-server-docker/docker
docker-compose down -v
rm -rf postgres_data redis_data minio_data

# Try again with verbose output
cd tests
./run-tests.sh --dev --verbose
```

### Tests Timeout Waiting for Services

**Problem**: "Timeout waiting for service X" error

```bash
# Check container logs for errors
docker-compose logs happy-server | tail -50
docker-compose logs postgres | tail -50
docker-compose logs redis | tail -50

# Check if services are running
docker-compose ps

# Increase timeout in run-tests.sh
# Edit the WAIT_TIMEOUT variable (default 120 seconds)
```

### WebSocket Tests Skipped

**Problem**: WebSocket tests are skipped during test run

```bash
# Install wscat for WebSocket testing
npm install -g wscat

# Verify installation
wscat --version

# Or install websocat as alternative
# See: https://github.com/vi/websocat
```

### Database Connection Issues

**Problem**: "Response from the Engine was empty" or connection timeouts

```bash
# Check PostgreSQL is running and healthy
docker ps | grep postgres
docker exec happy-postgres pg_isready -U happy

# Check database logs
docker-compose logs postgres

# Verify DATABASE_URL environment variable
grep DATABASE_URL docker/docker-compose.yml
grep DATABASE_URL ../.env

# Reset database (warning: deletes all data)
docker-compose down -v
docker volume rm happy-server-postgres_data
docker-compose up postgres
```

### Redis Connection Issues

**Problem**: Redis tests fail or pub/sub not working

```bash
# Check Redis is running
docker ps | grep redis
docker exec happy-redis redis-cli ping

# Check Redis logs
docker-compose logs redis

# Test Redis manually
redis-cli -h localhost -p 6379
PING

# Clear Redis data (if needed)
docker exec happy-redis redis-cli FLUSHALL
```

### MinIO Storage Issues

**Problem**: Storage operations fail or bucket not accessible

```bash
# Check MinIO is running
docker ps | grep minio

# Access MinIO console
open http://localhost:9001
# Default credentials: minioadmin / minioadmin

# Check if bucket exists
docker exec happy-minio mc ls local/

# Create bucket if missing
docker exec happy-minio \
  mc mb local/happy --ignore-existing
```

### Nginx Connection Issues

**Problem**: Requests to localhost:80 fail or WebSocket doesn't work through Nginx

```bash
# Check Nginx is running
docker ps | grep nginx

# Check Nginx logs
docker-compose logs nginx

# Verify Nginx configuration
docker exec happy-nginx nginx -t

# Check if upstream server is accessible
docker exec happy-nginx \
  curl -v http://happy-server:3000/health
```

### All Tests Pass Locally but Fail in CI

**Problem**: Tests work on machine but fail in GitHub Actions/GitLab CI

```bash
# Ensure .env file is in docker/ directory
ls -la docker/.env*

# Check CI environment has enough resources
# CI might have less RAM/CPU - increase timeouts

# Run with more verbose logging in CI
./run-tests.sh --prod --verbose

# Check for differences in container networking
docker network ls
docker network inspect happy-network
```

## Writing New Tests

### Adding a Test Function

Create a function following this pattern:

```bash
test_my_new_feature() {
    # Arrange: Set up test data
    local expected="expected_value"
    local test_endpoint="/v1/my-endpoint"

    # Act: Execute the test
    local response=$(curl -s "http://localhost:3000${test_endpoint}")
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://localhost:3000${test_endpoint}")

    # Assert: Validate the results
    assert_http_status 200 "$http_code" "My feature returns 200"
    assert_contains "$response" "$expected" "Response contains expected value"
}
```

### Adding to Test Suite

```bash
# In the appropriate test-*.sh file

main() {
    log_info "Running my tests..."

    run_test test_my_new_feature "My feature description"
    run_test test_my_edge_case "Handle edge case"

    log_info "My tests completed"
}

main "$@"
```

### Using Helper Functions

```bash
test_with_helpers() {
    # Wait for service to be ready
    wait_for_api_health 30

    # Set up API client
    set_base_url "http://localhost:3000"

    # Make API request
    local response=$(api_get "/health")

    # Extract and validate field
    local status=$(extract_json_field "$response" ".status")
    assert_equal "ok" "$status" "Health status is ok"
}
```

## Best Practices

### Test Design

1. **Idempotency**: Tests should be runnable multiple times without side effects
   ```bash
   # Good: Creates unique data each time
   local user_id="test-user-$(date +%s)"

   # Bad: Depends on previous test state
   local user_id="test-user"
   ```

2. **Independence**: Tests should not depend on each other
   ```bash
   # Good: Each test sets up its own data
   test_create_session() {
       create_test_user
       create_test_session
   }

   # Bad: Depends on test_create_user running first
   ```

3. **Cleanup**: Always clean up test data
   ```bash
   # Good: Clean up after test
   test_temporary_data() {
       local data_id=$(create_test_data)
       assert_data_created "$data_id"
       delete_test_data "$data_id"
   }
   ```

4. **Timeouts**: Use reasonable timeouts
   ```bash
   # Good: Service-specific timeout
   wait_for_postgres 30

   # Bad: Arbitrary long timeout
   sleep 300
   ```

### Error Messages

1. **Be specific**: Include context in assertion messages
   ```bash
   # Good
   assert_equal "200" "$code" "Health endpoint should return 200 OK, got: $code"

   # Bad
   assert_equal "200" "$code" "Test failed"
   ```

2. **Include actual values**: Show what was received
   ```bash
   # Good: Shows the actual response for debugging
   assert_contains "$response" "connected" "Expected service to be connected, got: $response"
   ```

### Performance

1. **Parallel execution**: Run independent tests in parallel if possible
2. **Caching**: Cache test fixtures to avoid repeated creation
3. **Skip expensive tests**: Use `--quick` flag to skip integration tests

## Contributing

When adding new tests:

1. **Follow naming conventions**:
   - Test files: `test-*.sh`
   - Test functions: `test_descriptive_name`
   - Helper functions: `helper_descriptive_name`

2. **Add documentation**:
   - Add test to appropriate suite
   - Update this README with test description
   - Document any new fixtures needed

3. **Test both success and failure**:
   - Test happy path
   - Test error conditions
   - Test edge cases

4. **Use helper functions**:
   - Leverage `test-helpers.sh` functions
   - Create reusable helpers for common patterns
   - Keep tests DRY (Don't Repeat Yourself)

5. **Update CI/CD**:
   - Ensure new tests run in CI/CD pipelines
   - Add any new tool requirements to documentation

## Environment Variables

### Test Configuration

```bash
# Run tests with custom timeout
WAIT_TIMEOUT=180 ./run-tests.sh --dev

# Run with custom log directory
TEST_LOG_DIR=/tmp/test-logs ./run-tests.sh --dev

# Run specific test suite only
TEST_SUITE=api ./run-tests.sh --dev

# Enable debug mode
DEBUG=1 ./run-tests.sh --dev
```

### Docker Compose Variables

Tests use variables from `docker/.env`:

- `POSTGRES_DB` - Database name (default: happy_server)
- `POSTGRES_USER` - Database user (default: happy)
- `POSTGRES_PASSWORD` - Database password (default: password)
- `POSTGRES_PORT` - PostgreSQL port (default: 5432)
- `REDIS_PORT` - Redis port (default: 6379)
- `MINIO_ROOT_USER` - MinIO user (default: minioadmin)
- `MINIO_ROOT_PASSWORD` - MinIO password (default: minioadmin)
- `MINIO_API_PORT` - MinIO API port (default: 9000)
- `PORT` - Happy Server port (default: 3000)

## Support and Resources

### Documentation

- Main Docker setup: See `../README.md`
- Docker Compose configuration: See `../docker-compose.yml`
- Service architecture: See `../DOCKER_SETUP.md`

### Commands Reference

- Full commands guide: See `../COMMANDS.md`
- Scripts reference: See `../SCRIPTS_README.md`

### Useful Commands

```bash
# View all test logs
tail -f .test-results/*.log

# Check Docker Compose status
docker-compose ps
docker-compose logs -f

# Restart a specific service
docker-compose restart happy-server

# Access database directly
docker exec -it happy-postgres psql -U happy -d happy_server

# Monitor Redis
docker exec -it happy-redis redis-cli MONITOR

# Access MinIO console
open http://localhost:9001
```

## License

This test suite is part of the Happy Server project and is licensed under the MIT License.
