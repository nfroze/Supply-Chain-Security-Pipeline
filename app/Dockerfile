# ─────────────────────────────────────────────
# Stage 1: Install dependencies
# ─────────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /build

COPY package.json package-lock.json* ./
RUN npm ci --omit=dev --ignore-scripts && \
    npm cache clean --force

# ─────────────────────────────────────────────
# Stage 2: Production runtime
# ─────────────────────────────────────────────
FROM node:20-alpine AS runtime

# Security: run as non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# Copy only production dependencies and application code
COPY --from=deps --chown=appuser:appgroup /build/node_modules ./node_modules
COPY --chown=appuser:appgroup server.js ./
COPY --chown=appuser:appgroup package.json ./

# Build metadata labels (populated by CI)
ARG COMMIT_SHA="unknown"
ARG BUILD_TIMESTAMP="unknown"
ARG APP_VERSION="1.0.0"

LABEL org.opencontainers.image.title="supply-chain-demo" \
      org.opencontainers.image.description="Supply chain security pipeline demo" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${COMMIT_SHA}" \
      org.opencontainers.image.created="${BUILD_TIMESTAMP}" \
      org.opencontainers.image.source="https://github.com/nfroze/Supply-Chain-Security-Pipeline" \
      org.opencontainers.image.vendor="Noah Frost"

ENV NODE_ENV=production \
    PORT=3000 \
    APP_VERSION=${APP_VERSION} \
    COMMIT_SHA=${COMMIT_SHA} \
    BUILD_TIMESTAMP=${BUILD_TIMESTAMP}

# Security hardening
USER appuser
EXPOSE 3000

# Read-only root filesystem compatible
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["node", "-e", "const http=require('http');http.get('http://localhost:3000/healthz',(r)=>{process.exit(r.statusCode===200?0:1)}).on('error',()=>process.exit(1))"]

CMD ["node", "server.js"]
