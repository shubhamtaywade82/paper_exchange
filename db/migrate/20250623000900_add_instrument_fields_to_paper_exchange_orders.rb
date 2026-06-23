class AddInstrumentFieldsToPaperExchangeOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :paper_exchange_orders, :instrument_type, :string, default: "equity", null: false
    add_column :paper_exchange_orders, :option_type, :string
    add_column :paper_exchange_orders, :strike_price, :decimal, precision: 18, scale: 2
    add_column :paper_exchange_orders, :expiry_date, :date
    add_index :paper_exchange_orders, [:instrument_type, :option_type, :strike_price, :expiry_date], name: "index_paper_orders_instrument"
  end
end
