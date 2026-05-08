# Stage 1: Builder - installs ALL dependencies including devDependencies
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Production image - only copies what's needed
# This keeps the final image small and secure
FROM node:18-alpine AS production
WORKDIR /app

# Create non-root user - CRITICAL security practice
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001

COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/
COPY package*.json ./

# Switch to non-root user before running
USER nodeuser

EXPOSE 3001

# Healthcheck baked into image - Kubernetes uses this
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3001/health || exit 1

CMD ["node", "src/index.js"]
