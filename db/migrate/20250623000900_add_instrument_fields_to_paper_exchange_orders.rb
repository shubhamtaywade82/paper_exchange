class AddInstrumentFieldsToPaperExchangeOrders < ActiveRecord::Migration[8.0]
  def change
    # instrument metadata
    add_column :paper_exchange_orders, :instrument_type, :string, default: "equity", null: false unless column_exists?(:paper_exchange_orders, :instrument_type)
    add_column :paper_exchange_orders, :option_type, :string unless column_exists?(:paper_exchange_orders, :option_type)
    add_column :paper_exchange_orders, :strike_price, :decimal, precision: 18, scale: 2 unless column_exists?(:paper_exchange_orders, :strike_price)
    add_column :paper_exchange_orders, :expiry_date, :date unless column_exists?(:paper_exchange_orders, :expiry_date)

    # Dhan-centric exchange mapping fields
    add_column :paper_exchange_orders, :exchange_segment, :string unless column_exists?(:paper_exchange_orders, :exchange_segment)
    add_column :paper_exchange_orders, :security_id, :string unless column_exists?(:paper_exchange_orders, :security_id)
    add_column :paper_exchange_orders, :series, :string unless column_exists?(:paper_exchange_orders, :series)

    add_index :paper_exchange_orders, [:instrument_type, :option_type, :strike_price, :expiry_date], name: "index_paper_orders_instrument" unless index_exists?(:paper_exchange_orders, [:instrument_type, :option_type, :strike_price, :expiry_date], name: "index_paper_orders_instrument")
  end
end
