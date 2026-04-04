# Multi-stage React (Vite/CRA) SPA — Node build, nginx static serve
# Adjust npm script and output folder (dist vs build).

ARG NODE_VERSION=20-alpine
ARG NGINX_VERSION=alpine
ARG APP_UID=1001
ARG APP_GID=1001

# --- Build ---
FROM node:${NODE_VERSION} AS builder
WORKDIR /app

ENV CI=true

COPY package.json package-lock.json* ./
RUN npm ci

COPY . .
RUN npm run build

# --- Runtime: nginx non-root ---
FROM nginxinc/nginx-unprivileged:${NGINX_VERSION} AS runtime

ARG APP_UID
ARG APP_GID

# nginx-unprivileged defaults to uid 101; image is designed for non-root.
COPY --from=builder /app/dist /usr/share/nginx/html

# Optional: custom nginx config for SPA fallback
# COPY nginx/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

# nginx-unprivileged listens on 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/ || exit 1

LABEL org.opencontainers.image.title="react-spa" \
      org.opencontainers.image.description="React static assets served by nginx unprivileged"
