module Backtest
  # Raised when a run reaches a situation the engine does not model, so the
  # run fails loudly instead of producing a silently wrong result. Example: an
  # option position is still open after its expiry date, and expiry
  # settlement is not implemented for backtests.
  class UnsupportedScenario < StandardError; end
end
