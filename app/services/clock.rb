# The one source of trading time for financial code: orders, fills, ledger
# entries, charges, protections, funding and expiry.
#
# Live: wall-clock time, in UTC. A backtest or replay run reads its simulated
# time through Backtest::Session, the only place simulated time is set. Money
# code calls Clock.now and never Time.current, Time.now or Date.today.
module Clock
  def self.now
    Backtest::Session.now.utc
  end

  # The calendar date an exchange-local instant falls on. Expiry and session
  # decisions use this, never the server's date.
  def self.exchange_date(zone:, at: now)
    at.in_time_zone(zone).to_date
  end
end
