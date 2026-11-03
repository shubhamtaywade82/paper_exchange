# Why an order was cancelled, so a withdrawn remainder is explained, not silent.
class AddCancelReasonToPaperExchangeOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :paper_exchange_orders, :cancel_reason, :string
  end
end
