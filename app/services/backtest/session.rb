module Backtest
  # Per-thread simulation context for one backtest run.
  #
  # The live accounting core (PaperExchange, PositionManager, MarginLedger,
  # Ledger, BrokerageCalculator, RiskManager) was written for a wall clock and
  # a Redis-backed mark price. A backtest reuses that core unchanged, and it
  # gets its own time and prices through this session:
  #
  #   * Session.now        replaces Time.current on every trading timestamp
  #                        (placed_at, filled_at, traded_at, occurred_at)
  #   * MarkPriceStore     reads and writes this session's in-memory marks
  #                        instead of Redis, so a run can never write a price
  #                        into the live feed
  #   * risk_gate?         lets a run disable the RiskManager checks (margin
  #                        lock still applies), for strategy research
  #
  # The session lives in Thread.current, so a run executing in one worker
  # thread cannot leak into live requests on other threads. Outside a run,
  # Session.current is nil and every seam falls through to live behaviour.
  class Session
    THREAD_KEY = :paper_exchange_backtest_session

    attr_accessor :at

    def self.current
      Thread.current[THREAD_KEY]
    end

    # Simulated time inside a run, wall-clock time everywhere else.
    def self.now
      current&.at || Time.current
    end

    def self.with(session)
      previous = Thread.current[THREAD_KEY]
      Thread.current[THREAD_KEY] = session
      yield session
    ensure
      Thread.current[THREAD_KEY] = previous
    end

    def initialize(risk_gate:)
      @risk_gate = risk_gate
      @marks = {}
      @at = nil
    end

    def risk_gate?
      @risk_gate
    end

    def set_mark(symbol, price)
      @marks[symbol] = price.to_f
    end

    def mark(symbol)
      @marks[symbol]
    end

    def marks
      @marks.dup
    end
  end
end
