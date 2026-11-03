module Backtest
  # Batch driver for engine-mode runs: a built-in strategy decides, and the
  # replay executes. For each bar, the loop is:
  #
  #   step = replay.advance!            # the bar executes queued intents, then closes
  #   intents = strategy.on_bar(step)   # decided on the closed bar
  #   replay.queue_engine_intents!(...) # executed at the NEXT bar's open
  #
  # The loop only decides. The bar-by-bar mechanics, the fills, and the results
  # are the same ones an external bot gets over the API (Backtest::Replay).
  class Engine
    LOOKBACK = 500

    class Invalid < StandardError; end

    def initialize(run)
      @run = run
    end

    def call
      raise Invalid, "run #{@run.id} is #{@run.status}; only running runs can execute" unless @run.running?

      # A fresh execution starts from an empty account, so a re-run after a
      # failure cannot inherit the previous attempt's orders or balance.
      RunManager.clear!(@run)
      contract = Contract.from_dataset(@run.dataset)
      strategy = Strategies.build(@run.strategy_key, @run.strategy_params, contract: contract)
      replay = Replay.new(@run)
      history = []
      index = 0

      loop do
        step = replay.advance!
        break unless step

        history << step.bar
        history.shift if history.size > LOOKBACK
        context = Strategies::Base::StrategyContext.new(
          bar: step.bar, index: index, history: history, position: step.position,
          equity: step.equity, next_bar_at: step.next_bar_at, contract: contract
        )
        intents = strategy.on_bar(context)
        if step.finished
          # The decision has no next open: it is counted, not executed.
          replay.count_unexecuted!(intents.size)
        else
          replay.queue_engine_intents!(intents)
        end
        index += 1
        break if step.finished
      end

      @run.reload
    end
  end
end
