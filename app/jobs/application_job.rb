class ApplicationJob < ActiveJob::Base
  # Prod-hardening (NEW-11): Postgres deadlocks are rare under the lock-ordering
  # discipline enforced in MarginLedger/PositionManager, but a future caller that
  # breaks ordering would surface as a 500 to the client. Retrying a deadlocked
  # job with backoff almost always succeeds on the second attempt because the
  # contending transaction has committed. Polynomial backoff avoids thundering
  # herds under sustained contention.
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_long, attempts: 3

  # Most jobs are safe to ignore if the underlying records are no longer
  # available — e.g. LiquidationJob racing a manual close. Per-job discard_on
  # declarations make this explicit (see LiquidationJob, FundingJob).
  discard_on ActiveJob::DeserializationError
end
