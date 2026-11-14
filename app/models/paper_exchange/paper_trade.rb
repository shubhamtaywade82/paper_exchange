module PaperExchange
  class PaperTrade < ApplicationRecord
    self.table_name = "paper_exchange_trades"

    belongs_to :paper_order, class_name: "PaperExchange::PaperOrder"
    belongs_to :paper_position, class_name: "PaperExchange::PaperPosition", optional: true

    validates :side, presence: true
    validates :quantity,
      presence: true,
      numericality: { greater_than: 0 }
    validates :price, presence: true
    validates :price, numericality: { greater_than: 0 }, unless: :option_close?
    # An option that expires out of the money is closed at a premium of
    # exactly 0 (OptionExpiryJob); every other fill must carry a real price.
    validates :price, numericality: { greater_than_or_equal_to: 0 }, if: :option_close?
    validates :traded_at, presence: true

    # #8: push each fill to FillsChannel once the transaction commits, so a
    # rolled-back fill is never broadcast. The fill paths link the trade to its
    # position inside that same transaction, so paper_position_id is set when
    # the broadcast runs.
    after_create_commit :broadcast_fill

    private

    def option_close?
      side.to_s == "sell" && paper_order&.option_type.present?
    end

    # Best effort. The trade has already committed, so a broadcast failure (for
    # example Redis down in production) must not surface as an error for a fill
    # that happened. The agent can still read the trade over REST.
    def broadcast_fill
      ActionCable.server.broadcast(FillsChannel.stream_name_for(paper_order.account_id), fill_payload)
    rescue StandardError => e
      Rails.logger.error("[PaperTrade] fills broadcast failed for trade #{id}: #{e.class}: #{e.message}")
    end

    def fill_payload
      {
        trade_id: id,
        order_id: paper_order_id,
        paper_position_id: paper_position_id,
        account_id: paper_order.account_id,
        symbol: paper_order.symbol,
        side: side,
        quantity: quantity.to_s,
        price: price.to_s,
        total_charges: total_charges.to_s,
        traded_at: traded_at&.iso8601(6)
      }
    end
  end
end
