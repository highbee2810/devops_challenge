# syntax=docker/dockerfile:1

# ---- deps: production dependencies only ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# ---- test: runs the unit tests; the build fails if they fail ----
FROM node:22-alpine AS test
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY src ./src
COPY test ./test
RUN npm test

# ---- runtime: small, non-root, no dev dependencies ----
FROM node:22-alpine AS runtime
ARG APP_VERSION=dev
ENV NODE_ENV=production \
    PORT=3000 \
    APP_VERSION=${APP_VERSION}
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
USER node
EXPOSE 3000
CMD ["node", "src/server.js"]
