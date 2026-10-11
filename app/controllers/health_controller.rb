# Prod-hardening (NEW-16): the default /up endpoint only verifies that Rails
# booted — it returns 200 even when Postgres is unreachable or Redis is down,
# which is exactly when liquidations silently stop running. A load balancer
# probing /up would happily route traffic to a half-broken replica.
#
# /health runs a deeper probe: Postgres connectivity, Redis connectivity, and
# Solid Queue table reachability. It returns 200 + {"status":"ok"} only when
# every dependency answers, and 503 + {"status":"degraded","checks":{...}}
# otherwise. This route is intentionally NOT under /api — it is unauthenticated
# so load balancers and external probes can hit it without the operator key.
# The response body is intentionally minimal (ok/degraded + per-check booleans)
# so it leaks nothing about the deployment beyond "is each dependency up".
class HealthController < ApplicationController
  def show
    checks = {
      postgres: postgres_ok?,
      redis: redis_ok?,
      solid_queue: solid_queue_ok?
    }
    healthy = checks.values.all?

    status = healthy ? :ok : :service_unavailable
    body = { status: healthy ? "ok" : "degraded", checks: checks }
    render json: body, status: status
  end

  private

  def postgres_ok?
    ActiveRecord::Base.connection.active?
  rescue StandardError
    false
  end

  def redis_ok?
    MarketData::MarkPriceStore.redis_healthy?
  rescue StandardError
    false
  end

  # Solid Queue stores jobs in a separate database (config.queue.yml). A
  # reachable jobs table means enqueued LiquidationJob/FundingJob/ExpireOrdersJob
  # will eventually run; an unreachable one means jobs silently stall. In test
  # and dev the active_job adapter is often :test / :async (no queue DB), so
  # there is nothing to probe — treat as healthy and only run the real probe
  # when Solid Queue is actually the configured adapter.
  def solid_queue_ok?
    return true unless ActiveJob::Base.queue_adapter_name.to_s == "solid_queue"
    return true unless defined?(SolidQueue::Job)

    SolidQueue::Job.connection.execute("SELECT 1")
    true
  rescue StandardError
    false
  end
end
