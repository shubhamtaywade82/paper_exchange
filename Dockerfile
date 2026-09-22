# syntax = docker/dockerfile:1

# ==============================================================================
# Stage 1: Base — common OS packages, no Ruby env yet
# ==============================================================================
ARG RUBY_VERSION=3.4.2
FROM ruby:$RUBY_VERSION-slim-bookworm AS base

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      curl libpq-dev build-essential libyaml-dev pkg-config \
      postgresql-client redis-tools nodejs npm && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

WORKDIR /rails

ENV BUNDLE_PATH=/usr/local/bundle \
    RAILS_ENV=development

# ==============================================================================
# Stage 2: build — install all gems (including dev/test)
# ==============================================================================
FROM base AS build

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# ==============================================================================
# Stage 3: development — what docker compose runs locally
# Boots a single Puma with dev-mode reloading and SSH-style code mounting.
# ==============================================================================
FROM build AS development

# Smoke-test deps (TypeScript + axios + BigNumber) — README's smoke-test.ts
# Needs devDependencies for ts-node/tsx, so install everything.
COPY package.json package-lock.json* ./
RUN npm install

COPY . .

RUN chmod +x bin/docker-entrypoint

ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]

# ==============================================================================
# Stage 4: production — minimal, no dev/test gems, no source tree beyond app
# ponytail: real production image; secrets come from env vars, never baked in.
# ==============================================================================
FROM base AS production

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test

COPY --from=build /usr/local/bundle /usr/local/bundle

COPY . .

RUN chmod +x bin/docker-entrypoint && \
    SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile || true

ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
