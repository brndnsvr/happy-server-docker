# Stage 1: Builder
FROM node:20-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    ffmpeg \
    make \
    g++ \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy package files
COPY package.json yarn.lock ./
COPY ./prisma ./prisma

# Install dependencies
RUN yarn install --frozen-lockfile --ignore-engines

# Copy TypeScript configuration
COPY ./tsconfig.json ./tsconfig.json
COPY ./vitest.config.ts ./vitest.config.ts

# Copy source code
COPY ./sources ./sources

# Type check and generate Prisma client
RUN yarn build && yarn generate

# Stage 2: Runtime
FROM node:20-slim AS runner

WORKDIR /app

# Install runtime dependencies (FFmpeg and Python3)
RUN apt-get update && apt-get install -y \
    python3 \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 node

# Set environment to production
ENV NODE_ENV=production

# Copy necessary files from builder
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/yarn.lock ./yarn.lock
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/sources ./sources
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/tsconfig.json ./tsconfig.json

# Change ownership to node user
RUN chown -R node:node /app

# Switch to non-root user
USER node

# Expose main application port
EXPOSE 3000

# Expose metrics port
EXPOSE 9090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Start the application
CMD ["yarn", "start"]
