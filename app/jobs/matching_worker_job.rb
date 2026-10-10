# Thin Solid Queue wrapper around Exchange::MatchingWorker. The recurring
# job config in config/recurring.yml schedules this every 2 seconds so the
# matching worker runs promptly without needing a dedicated long-lived
# process. A full deployment would run MatchingWorker as a standalone
# consumer of the Redis tick stream (see MarketData::ConnectionSupervisor),
# but this recurring-job mode keeps the single-server Solid Queue topology
# simple while still making PaperExchange autonomous.
class MatchingWorkerJob < ApplicationJob
  queue_as :default

  def perform
    Exchange::MatchingWorker.process_pending(batch_size: 50)
  end
end
