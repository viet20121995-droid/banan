# Multi-stage build for the Banan NestJS API.
# Final image runs migrations on boot and serves the API on :3000.

# ─── Stage 1: install dependencies ────────────────────────────────────────
FROM node:20-alpine AS deps
RUN apk add --no-cache libc6-compat openssl
RUN corepack enable && corepack prepare pnpm@9.0.0 --activate
WORKDIR /app

COPY package.json pnpm-lock.yaml ./
COPY prisma ./prisma
RUN pnpm install --frozen-lockfile

# ─── Stage 2: build TS → dist/ ────────────────────────────────────────────
FROM node:20-alpine AS builder
RUN apk add --no-cache libc6-compat openssl
RUN corepack enable && corepack prepare pnpm@9.0.0 --activate
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN pnpm prisma:generate
RUN pnpm build
# (Skipping the prod-prune — keeps the prisma CLI available for runtime
#  `migrate deploy`. Image ends up ~250 MB instead of ~150 MB; fine for now.)

# ─── Stage 3: minimal runtime ─────────────────────────────────────────────
FROM node:20-alpine AS runner
RUN apk add --no-cache libc6-compat openssl tini
WORKDIR /app

ENV NODE_ENV=production \
    PORT=3000

# Non-root user for the runtime.
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nestjs -u 1001 -G nodejs

COPY --from=builder --chown=nestjs:nodejs /app/dist ./dist
COPY --from=builder --chown=nestjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nestjs:nodejs /app/prisma ./prisma
COPY --from=builder --chown=nestjs:nodejs /app/package.json ./package.json

# Uploads volume — overridden by S3/R2 in production via S3_* env vars.
RUN mkdir -p /app/uploads && chown -R nestjs:nodejs /app/uploads
VOLUME ["/app/uploads"]

USER nestjs
EXPOSE 3000

# tini = proper signal handling so the container shuts down cleanly.
# Migrations run on every boot; they're no-ops once applied (idempotent).
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/src/main.js"]
