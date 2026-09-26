# Fail fast at boot (audit M2): a Rails API that boots without an API key
# configured is silently fully unauthenticated — every account readable and
# every order mutable by anyone who can reach the port. Refusing to boot is
# the loud failure that prevents deploying that state by accident.
# Set PAPER_EXCHANGE_API_KEY in the environment (see .env.example).
if Rails.env.production? && ENV["PAPER_EXCHANGE_API_KEY"].blank?
  raise "PAPER_EXCHANGE_API_KEY must be set in production — the API refuses to boot unauthenticated (audit M2)"
end
