# Recurring sweep (audit S2/T3.2): expires open orders whose fill never
# arrived — the order book had no price at placement and never got one, or
# the agent died between placement and fill — so their locked margin is
# released instead of resting forever. The state guard in expired! makes a
# raced order (filled/cancelled elsewhere between selection and expiry) a
# loud-but-skippable StateError.
#
# TTL is env-tunable via PAPER_EXCHANGE_ORDER_TTL_MINUTES (default 60).
class ExpireOrdersJob < ApplicationJob
  queue_as :default

  def perform
    ttl_minutes = ENV.fetch("PAPER_EXCHANGE_ORDER_TTL_MINUTES", "60").to_f
    cutoff = ttl_minutes.minutes.ago

    ::PaperExchange::PaperOrder
      .where(status: :open)
      .where("placed_at < ?", cutoff)
      .find_each do |order|
        begin
          Exchange::PaperExchange.new(account_id: order.account_id).expire_order(order.id)
        rescue ::PaperExchange::PaperOrder::StateError, ActiveRecord::RecordNotFound
          # Raced a concurrent fill/cancel/expiry — the winner already moved
          # the order to a terminal state; nothing to release.
          next
        end
      end
  end
end
