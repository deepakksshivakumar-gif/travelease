FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine AS production
WORKDIR /app
RUN addgroup -g 1001 -S nodejs && adduser -S nodeuser -u 1001
COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/
COPY package*.json ./
USER nodeuser
EXPOSE 3003
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3003/health || exit 1
CMD ["node", "src/index.js"]
