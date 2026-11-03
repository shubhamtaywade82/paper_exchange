# Executes one backtest run off the request path. The API enqueues it on
# POST /api/backtest_runs/:id/execute and returns 202, so a long run never
# holds a web thread.
#
# Claiming the run is a row-locked transition from pending to running, so a
# duplicate delivery of this job is a no-op. Any failure is recorded on the
# run, with its reason, before the job re-raises.
class BacktestRunJob < ApplicationJob
  queue_as :default

  def perform(run_id)
    run = Backtest::Run.find_by(id: run_id)
    return unless run && Backtest::RunManager.claim!(run)

    Backtest::Engine.new(run).call
  rescue Backtest::UnsupportedScenario, Backtest::Engine::Invalid, Backtest::Strategies::InvalidParams => e
    # Expected, explained failures: the run is marked failed and the job
    # completes, so the scheduler does not retry a run that can never succeed.
    Backtest::RunManager.fail!(run, e) if run
  rescue StandardError => e
    Backtest::RunManager.fail!(run, e) if run
    raise
  end
end
