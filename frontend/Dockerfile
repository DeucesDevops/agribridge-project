# syntax=docker/dockerfile:1
FROM node:22.23.4-bookworm-slim@sha256:4b150b48b4116e2a22f2c39cc27025fbf4f153e2078fd3b14d159fdb5c7279da AS build
WORKDIR /app
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run build
FROM nginx/nginx-unprivileged:1.31.10-alpine@sha256:86628f2c9eaa5e84e3b98d25e26563c4a4f9b0ead9cf5656da4731d86e0621de AS runtime
USER root
RUN apk upgrade --no-cache
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
