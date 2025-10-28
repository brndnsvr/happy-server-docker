#!/bin/bash
# =============================================================================
# MinIO Initialization Script
# =============================================================================
# This script initializes MinIO with the required buckets and configurations.
# It is designed to be idempotent - safe to run multiple times.
# =============================================================================

set -e

echo "=========================================="
echo "MinIO Initialization"
echo "=========================================="

# Configuration
MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://minio:9000}"
MINIO_ALIAS="${MINIO_ALIAS:-happy}"
BUCKET_NAME="${S3_BUCKET:-happy-server}"
ACCESS_KEY="${MINIO_ROOT_USER:-minioadmin}"
SECRET_KEY="${MINIO_ROOT_PASSWORD:-minioadmin}"

# Wait for MinIO to be ready
echo "Waiting for MinIO to be ready..."
max_attempts=30
attempt=0

until curl -sf "${MINIO_ENDPOINT}/minio/health/live" > /dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        echo "ERROR: MinIO did not become ready in time"
        exit 1
    fi
    echo "Attempt ${attempt}/${max_attempts}: MinIO not ready yet, waiting..."
    sleep 2
done

echo "✓ MinIO is ready!"

# Configure mc (MinIO Client) alias
echo "Configuring MinIO client alias..."
mc alias set ${MINIO_ALIAS} ${MINIO_ENDPOINT} ${ACCESS_KEY} ${SECRET_KEY} --api S3v4

# Check if alias is working
if ! mc admin info ${MINIO_ALIAS} > /dev/null 2>&1; then
    echo "ERROR: Failed to connect to MinIO"
    exit 1
fi

echo "✓ MinIO client configured successfully"

# Create bucket if it doesn't exist
echo "Checking if bucket '${BUCKET_NAME}' exists..."
if mc ls ${MINIO_ALIAS}/${BUCKET_NAME} > /dev/null 2>&1; then
    echo "✓ Bucket '${BUCKET_NAME}' already exists"
else
    echo "Creating bucket '${BUCKET_NAME}'..."
    mc mb ${MINIO_ALIAS}/${BUCKET_NAME}
    echo "✓ Bucket '${BUCKET_NAME}' created successfully"
fi

# Set bucket policy to allow public read access (optional - adjust as needed)
# Uncomment the following lines if you want public read access
# echo "Setting bucket policy..."
# mc anonymous set download ${MINIO_ALIAS}/${BUCKET_NAME}
# echo "✓ Bucket policy set"

# Enable versioning (optional)
echo "Checking bucket versioning..."
if mc version info ${MINIO_ALIAS}/${BUCKET_NAME} | grep -q "Versioning is enabled"; then
    echo "✓ Versioning already enabled"
else
    echo "Enabling versioning..."
    mc version enable ${MINIO_ALIAS}/${BUCKET_NAME}
    echo "✓ Versioning enabled"
fi

# Set lifecycle policy (optional - example: delete old versions after 30 days)
# Uncomment and modify as needed
# echo "Setting lifecycle policy..."
# mc ilm add ${MINIO_ALIAS}/${BUCKET_NAME} \
#     --expiry-days 30 \
#     --noncurrentversion-expiration-days 7
# echo "✓ Lifecycle policy set"

# Display bucket information
echo ""
echo "=========================================="
echo "MinIO Configuration Complete"
echo "=========================================="
echo "Endpoint:    ${MINIO_ENDPOINT}"
echo "Bucket:      ${BUCKET_NAME}"
echo "Access Key:  ${ACCESS_KEY}"
echo "Console:     http://localhost:9001 (if exposed)"
echo "=========================================="
echo ""

# List all buckets
echo "Available buckets:"
mc ls ${MINIO_ALIAS}

echo ""
echo "✓ MinIO initialization completed successfully!"
