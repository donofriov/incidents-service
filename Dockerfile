# syntax=docker/dockerfile:1.19.0

FROM ruby:3.4.6-alpine@sha256:d594d5debffa14c591c4fe03b9d0d79cdc28f30d594f47be748e642746057fec AS base

ARG BUILD_DATE
ARG VCS_REF
ARG BUNDLER_VERSION=2.7.2

LABEL org.opencontainers.image.title="incidents-service" \
      org.opencontainers.image.description="Ruby WEBrick service that reports recent incidents" \
      org.opencontainers.image.authors="Vincent D'Onofrio <donofriov@gmail.com>" \
      org.opencontainers.image.source="https://github.com/donofriov/incidents-service" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="MIT"

RUN set -eux; \
    apk add --no-cache tini curl ca-certificates; \
    update-ca-certificates

# Install exact Bundler version the lockfile expects
RUN gem install bundler -v "${BUNDLER_VERSION}" --no-document

WORKDIR /app

FROM base AS deps

RUN apk add --no-cache --virtual .build-deps build-base

COPY app/Gemfile app/Gemfile.lock /app/

# Bundler settings
ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development test" \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3

# Install using the locked Bundler version, to the explicit path
RUN --mount=type=cache,target=/root/.bundle \
    --mount=type=cache,target=/usr/local/bundle/cache \
    bundle _${BUNDLER_VERSION}_ config set path "${BUNDLE_PATH}" && \
    bundle _${BUNDLER_VERSION}_ install

FROM base

RUN addgroup -S -g 10001 app && \
    adduser  -S -D -h /home/app -u 10001 -G app -s /sbin/nologin app


COPY --from=deps /usr/local/bundle /usr/local/bundle

COPY --chown=app:app app/ /app/

ENV PORT=3000 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development test"

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${PORT}/" >/dev/null || exit 1

USER app
STOPSIGNAL SIGINT
ENTRYPOINT ["/sbin/tini","--"]
CMD ["bundle","exec","ruby","incidents.rb"]
