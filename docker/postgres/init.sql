-- =============================================================================
-- PostgreSQL Initialization Script for Happy Server
-- =============================================================================
-- This script runs once when the database is first created.
-- Note: Prisma migrations handle most schema management, so this file
-- primarily sets up extensions and initial configuration.
-- =============================================================================

-- Enable UUID generation extension (useful for generating UUIDs)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable pgcrypto for cryptographic functions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enable citext for case-insensitive text columns (useful for emails, usernames)
CREATE EXTENSION IF NOT EXISTS "citext";

-- Log successful initialization
DO $$
BEGIN
    RAISE NOTICE 'Happy Server database initialized successfully';
    RAISE NOTICE 'Extensions enabled: uuid-ossp, pgcrypto, citext';
    RAISE NOTICE 'Run Prisma migrations to create the schema: yarn migrate';
END $$;

-- =============================================================================
-- Optional: Create additional databases or schemas
-- =============================================================================
-- Uncomment if you need separate databases for testing or other purposes
-- CREATE DATABASE happy_server_test;
-- GRANT ALL PRIVILEGES ON DATABASE happy_server_test TO happy;

-- =============================================================================
-- Performance Tuning Recommendations
-- =============================================================================
-- Consider adjusting these PostgreSQL settings in postgresql.conf or via
-- environment variables in docker-compose.yml:
--
-- shared_buffers = 256MB              # 25% of system RAM
-- effective_cache_size = 1GB          # 50-75% of system RAM
-- maintenance_work_mem = 64MB         # For VACUUM, CREATE INDEX
-- checkpoint_completion_target = 0.9  # Spread out checkpoint writes
-- wal_buffers = 16MB                  # WAL buffer size
-- default_statistics_target = 100     # Query planner statistics
-- random_page_cost = 1.1              # For SSD storage
-- effective_io_concurrency = 200      # For SSD storage
-- work_mem = 4MB                      # Per-query memory
-- min_wal_size = 1GB
-- max_wal_size = 4GB
-- =============================================================================
