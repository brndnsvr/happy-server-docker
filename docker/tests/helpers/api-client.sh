#!/bin/bash
# API client helper functions for Happy Server Docker tests

# Default configuration
API_BASE_URL="http://localhost:3000"
API_TOKEN=""
LAST_RESPONSE=""
LAST_STATUS=""

# Set base URL
set_base_url() {
    API_BASE_URL=$1
}

# Set authentication token
set_api_token() {
    API_TOKEN=$1
}

# Make authenticated API request
api_request() {
    local method=$1
    local endpoint=$2
    local data=${3:-""}
    local expected_status=${4:-200}

    local url="${API_BASE_URL}${endpoint}"
    local auth_header=""

    if [[ -n "$API_TOKEN" ]]; then
        auth_header="-H \"Authorization: Bearer $API_TOKEN\""
    fi

    local response
    if [[ -n "$data" ]]; then
        response=$(eval curl -s -w "\n%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            $auth_header \
            -d "'$data'" \
            "$url" 2>/dev/null)
    else
        response=$(eval curl -s -w "\n%{http_code}" -X "$method" \
            $auth_header \
            "$url" 2>/dev/null)
    fi

    LAST_RESPONSE=$(echo "$response" | head -n -1)
    LAST_STATUS=$(echo "$response" | tail -n 1)

    if [[ "$LAST_STATUS" == "$expected_status" ]]; then
        echo "$LAST_RESPONSE"
        return 0
    else
        return 1
    fi
}

# Convenience methods
api_get() {
    api_request "GET" "$1" "" "${2:-200}"
}

api_post() {
    api_request "POST" "$1" "$2" "${3:-200}"
}

api_put() {
    api_request "PUT" "$1" "$2" "${3:-200}"
}

api_delete() {
    api_request "DELETE" "$1" "" "${2:-200}"
}

# Parse JSON response (requires jq)
json_get() {
    local json=$1
    local path=$2

    if command -v jq &> /dev/null; then
        echo "$json" | jq -r "$path"
    else
        echo ""
    fi
}

# Wait for API to be ready
wait_for_api() {
    local max_wait=${1:-60}
    local elapsed=0

    while true; do
        if curl -s -f "${API_BASE_URL}/health" > /dev/null 2>&1; then
            return 0
        fi

        if [[ $elapsed -ge $max_wait ]]; then
            log_error "Timeout waiting for API: ${API_BASE_URL}"
            return 1
        fi

        sleep 2
        elapsed=$((elapsed + 2))
    done
}

# Export functions
export -f set_base_url set_api_token
export -f api_request api_get api_post api_put api_delete
export -f json_get wait_for_api
