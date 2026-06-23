source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache and Active Job
gem "solid_cache"
gem "solid_queue"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# ─────────────────────────────────────────────────────────────────────────────
# Authentication
# ─────────────────────────────────────────────────────────────────────────────
gem "devise"
gem "devise-jwt"

# ─────────────────────────────────────────────────────────────────────────────
# API
# ─────────────────────────────────────────────────────────────────────────────
gem "rack-cors"
gem "oj"
gem "blueprinter"

# ─────────────────────────────────────────────────────────────────────────────
# Validation
# ─────────────────────────────────────────────────────────────────────────────
gem "dry-validation"

# ─────────────────────────────────────────────────────────────────────────────
# Background Jobs
# ─────────────────────────────────────────────────────────────────────────────
gem "sidekiq"

# ─────────────────────────────────────────────────────────────────────────────
# WebSockets / Market Feed
# ─────────────────────────────────────────────────────────────────────────────
gem "async-websocket"
gem "websocket-client-simple"

# ─────────────────────────────────────────────────────────────────────────────
# Trading
# ─────────────────────────────────────────────────────────────────────────────
gem "faraday"
gem "faraday-retry"

# ─────────────────────────────────────────────────────────────────────────────
# Environment
# ─────────────────────────────────────────────────────────────────────────────
gem "dotenv-rails"

# ─────────────────────────────────────────────────────────────────────────────
# Search
# ─────────────────────────────────────────────────────────────────────────────
gem "ransack"

# Backtest / real-time ingest
gem "redis"

# ─────────────────────────────────────────────────────────────────────────────
# Monitoring (development & test only — overhead not needed in production)
# ─────────────────────────────────────────────────────────────────────────────
group :development, :test do
  # Debugging
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Security auditing
  gem "bundler-audit", require: false
  gem "brakeman", require: false

  # Linting
  gem "rubocop-rails-omakase", require: false

  # N+1 query detection
  gem "bullet"

  # Request profiling
  gem "rack-mini-profiler"
end

# ─────────────────────────────────────────────────────────────────────────────
# Testing (development & test only)
# ─────────────────────────────────────────────────────────────────────────────
group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "webmock"
  gem "vcr"
end
