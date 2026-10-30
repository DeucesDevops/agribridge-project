# syntax=docker/dockerfile:1
FROM node:22.22.0-bookworm-slim AS build
WORKDIR /app
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run build
FROM nginxinc/nginx-unprivileged:1.28.2-alpine AS runtime
ARG APP_VERSION=dev
ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown
ARG IMAGE_TAG=local
LABEL org.opencontainers.image.revision=$GIT_SHA org.opencontainers.image.version=$APP_VERSION org.opencontainers.image.created=$BUILD_DATE org.opencontainers.image.ref.name=$IMAGE_TAG
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
ENV API_UPSTREAM=api:3000
USER 101:101
EXPOSE 8080
