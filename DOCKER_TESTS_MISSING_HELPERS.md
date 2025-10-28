# Docker Test Suite - Missing Helper Functions

This document provides the exact code needed to fix the `wait-for-services.sh` dependency issue.

## Problem

The `wait-for-services.sh` script references 4 functions that don't exist in `test-helpers.sh`:
- `container_exists()` - Called 5 times (lines 66, 107, 149, 190, 242)
- `get_container_status()` - Called 4 times (lines 196, 341, 350, 359, 368, 378)
- `log_pass()` - Called 6 times (lines 33, 74, 115, 155, 207, 249, 322, 342, 351, 360, 369, 379)
- `log_fail()` - Called 5 times (lines 345, 354, 363, 372, 382)

## Solution

Add the following 4 functions to `/Users/bss/code/happy-server-docker/docker/tests/helpers/test-helpers.sh`

### Step 1: Add Functions After Line 196

Location: After the `wait_for_port()` function and before the "# HTTP helper functions" comment

```bash
#######################################
# Check if Docker container exists
# Arguments:
#   $1 - Container name
# Returns:
#   0 if container exists, 1 otherwise
#######################################
container_exists() {
    local container_name=$1
    docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"
}

#######################################
# Get Docker container status
# Arguments:
#   $1 - Container name
# Returns:
#   Container status (running, exited, dead, paused, etc.)
#######################################
get_container_status() {
    local container_name=$1
    docker ps -a --format '{{.Names}}|{{.State}}' | \
        grep "^${container_name}|" | \
        cut -d'|' -f2 | \
        head -1
}

#######################################
# Log a passing assertion/test
# Arguments:
#   $1 - Message
# Returns:
#   Always 0 (success)
#######################################
log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    return 0
}

#######################################
# Log a failing assertion/test
# Arguments:
#   $1 - Message
# Returns:
#   Always 1 (failure)
#######################################
log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    return 1
}
```

### Step 2: Update Exports (Line ~265)

Replace the existing export statement:

**BEFORE:**
```bash
export -f log_info log_success log_error log_warn log_skip
export -f run_test skip_test
export -f assert_equals assert_not_empty assert_contains assert_command_success
export -f is_container_running wait_for_container wait_for_healthy get_container_logs exec_in_container
export -f wait_for_port http_get http_post
export -f print_test_summary cleanup_test_data
```

**AFTER:**
```bash
export -f log_info log_success log_error log_warn log_skip log_pass log_fail
export -f run_test skip_test
export -f assert_equals assert_not_empty assert_contains assert_command_success
export -f is_container_running wait_for_container wait_for_healthy get_container_logs exec_in_container
export -f container_exists get_container_status
export -f wait_for_port http_get http_post
export -f print_test_summary cleanup_test_data
```

## Verification

After adding the functions, verify by running:

```bash
# Check functions are defined
grep -E "^(container_exists|get_container_status|log_pass|log_fail)\(\)" /Users/bss/code/happy-server-docker/docker/tests/helpers/test-helpers.sh

# Should output:
# container_exists()
# get_container_status()
# log_pass()
# log_fail()
```

Then test `wait-for-services.sh` can be sourced without errors:

```bash
cd /Users/bss/code/happy-server-docker/docker/tests
bash -n helpers/wait-for-services.sh && echo "Syntax OK"
```

## Line-by-Line Explanation

### `container_exists()`
```bash
docker ps -a --format '{{.Names}}' | \  # List all containers (running + stopped)
    grep -q "^${container_name}$"       # Match exact name (^ and $ for word boundaries)
```
- Returns 0 if container exists, 1 if not
- Uses `docker ps -a` to check both running and stopped containers

### `get_container_status()`
```bash
docker ps -a --format '{{.Names}}|{{.State}}' | \  # List containers with state
    grep "^${container_name}|" | \                  # Filter by name
    cut -d'|' -f2 | \                               # Extract state field
    head -1                                         # Take first match
```
- Returns status like "running", "exited", "dead", "paused"
- Uses `head -1` to ensure only one result

### `log_pass()`
```bash
echo -e "${GREEN}[PASS]${NC} $1"  # Green colored [PASS] prefix
return 0                           # Always succeeds
```
- Mirrors existing `log_success()` but for test assertions
- Uses green color for visual distinction
- Returns 0 for success

### `log_fail()`
```bash
echo -e "${RED}[FAIL]${NC} $1"  # Red colored [FAIL] prefix
return 1                         # Always fails
```
- Mirrors existing `log_error()` but for test assertions
- Uses red color for visual distinction
- Returns 1 for failure

## Implementation Time

- **Time to implement**: 5-10 minutes
- **Time to test**: 2-3 minutes
- **Total**: ~15 minutes

## Full Test-Helpers.sh Update

If you prefer, here's the complete updated export statement with all new functions:

```bash
# Export functions
export -f log_info log_success log_error log_warn log_skip log_pass log_fail
export -f run_test skip_test
export -f assert_equals assert_not_empty assert_contains assert_command_success
export -f is_container_running wait_for_container wait_for_healthy get_container_logs exec_in_container
export -f container_exists get_container_status
export -f wait_for_port http_get http_post
export -f print_test_summary cleanup_test_data
```

## Next Steps After Fix

Once these functions are added:

1. ✓ `wait-for-services.sh` will be fully functional
2. Can proceed with creating test-build.sh, test-services.sh, test-api.sh, etc.
3. All 7 test scripts can then use these helpers without issues
4. Final run-tests.sh orchestrator can be created

## Related Files

- **Target file**: `/Users/bss/code/happy-server-docker/docker/tests/helpers/test-helpers.sh`
- **Dependent file**: `/Users/bss/code/happy-server-docker/docker/tests/helpers/wait-for-services.sh`
- **Documentation**: `/Users/bss/code/happy-server-docker/DOCKER_TESTS_AUDIT_REPORT.md`

