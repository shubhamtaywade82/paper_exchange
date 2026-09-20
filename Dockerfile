# syntax = docker/dockerfile:1

# ==============================================================================
# Stage 1: Base Image (Shared between build and production)
# ==============================================================================
ARG RUBY_VERSION=3.4.2
FROM ruby:$RUBY_VERSION-slim-bookworm AS base

# Set environment variables
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test

# Install essential OS packages required for PostgreSQL and Redis clients
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libpq-dev build-essential libyaml-dev pkg-config netcat-openbsd && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set working directory
WORKDIR /rails

# ==============================================================================
# Stage 2: Build Stage (Install Gems)
# ==============================================================================
FROM base AS build

# Copy only Gemfile and Gemfile.lock to leverage Docker layer caching
COPY Gemfile Gemfile.lock ./

# Install gems (excluding dev/test groups)
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# ==============================================================================
# Stage 3: Production Stage (Final Image)
# ==============================================================================
FROM base AS production

# Copy installed gems from build stage
COPY --from=build /usr/local/bundle /usr/local/bundle

# Copy the rest of the application code
COPY . .

# Ensure the entrypoint script is executable
RUN chmod +x bin/docker-entrypoint

# Expose the Puma port
EXPOSE 3000

# Use the custom entrypoint to handle DB prep and server boot
ENTRYPOINT ["bin/docker-entrypoint"]

# Start the Puma server
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
