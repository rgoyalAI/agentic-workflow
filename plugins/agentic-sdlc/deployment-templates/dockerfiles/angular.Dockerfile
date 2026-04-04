# Multi-stage Angular SPA — Node build, nginx static serve
# Replace `my-app` with your Angular project folder if monorepo.

ARG NODE_VERSION=20-alpine
ARG NGINX_VERSION=alpine

# --- Build ---
FROM node:${NODE_VERSION} AS builder
WORKDIR /app

ENV CI=true

COPY package.json package-lock.json* ./
RUN npm ci

COPY . .
RUN npx ng build --configuration production

# --- Runtime: nginx non-root ---
FROM nginxinc/nginx-unprivileged:${NGINX_VERSION} AS runtime

# Default Angular output: dist/<project>/browser (Angular 17+) or dist/<project>
COPY --from=builder /app/dist/my-app/browser /usr/share/nginx/html

# Optional: SPA routing
# COPY nginx/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/ || exit 1

LABEL org.opencontainers.image.title="angular-spa" \
      org.opencontainers.image.description="Angular production build on nginx unprivileged"
