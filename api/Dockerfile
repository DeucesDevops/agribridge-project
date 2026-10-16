# syntax=docker/dockerfile:1
FROM node:24-bookworm-slim@sha256:a5f4366e834695d5f363b920c104953a535d3a9864d1bdf74566a0ebe01daee5 AS base
WORKDIR /app

FROM base AS production-deps
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev

FROM base AS test
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY --chown=1000:1000 src ./src
COPY --chown=1000:1000 test ./test
COPY eslint.config.js vitest.config.js ./
RUN mkdir -p /app/node_modules/.vite && chown 1000:1000 /app /app/node_modules/.vite
USER 1000:1000
CMD ["npm", "run", "test:coverage"]

FROM base AS runtime
ARG APP_VERSION=1.0.0
ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown
ARG IMAGE_TAG=local
ENV APP_VERSION=${APP_VERSION} GIT_SHA=${GIT_SHA} BUILD_DATE=${BUILD_DATE} IMAGE_TAG=${IMAGE_TAG}
LABEL org.opencontainers.image.version=${APP_VERSION} \
      org.opencontainers.image.revision=${GIT_SHA} \
      org.opencontainers.image.created=${BUILD_DATE}
COPY --from=production-deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
USER 1000:1000
EXPOSE 3000
STOPSIGNAL SIGTERM
CMD ["node", "src/server.js"]
