# syntax=docker/dockerfile:1
FROM node:22.23.4-bookworm-slim@sha256:4b150b48b4116e2a22f2c39cc27025fbf4f153e2078fd3b14d159fdb5c7279da AS dependencies
WORKDIR /app
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev
FROM node:22.23.4-bookworm-slim@sha256:4b150b48b4116e2a22f2c39cc27025fbf4f153e2078fd3b14d159fdb5c7279da AS runtime
# Apply available OS fixes and omit build-only package managers from runtime.
RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/* /usr/local/lib/node_modules/npm \
        /usr/local/lib/node_modules/corepack /opt/yarn-v* \
        /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
        /usr/local/bin/yarn /usr/local/bin/yarnpkg /usr/local/bin/pnpm /usr/local/bin/pnpx
WORKDIR /app
ARG APP_VERSION=dev
ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown
ARG IMAGE_TAG=local
ENV NODE_ENV=production APP_VERSION=$APP_VERSION GIT_SHA=$GIT_SHA BUILD_DATE=$BUILD_DATE IMAGE_TAG=$IMAGE_TAG
LABEL org.opencontainers.image.revision=$GIT_SHA org.opencontainers.image.version=$APP_VERSION org.opencontainers.image.created=$BUILD_DATE
COPY --from=dependencies --chown=1000:1000 /app/node_modules ./node_modules
COPY --chown=1000:1000 package.json ./
COPY --chown=1000:1000 src ./src
USER 1000:1000
EXPOSE 3000
CMD ["node", "src/server.js"]
