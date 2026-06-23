class UpdatePaperExchangeOrdersDhanFields < ActiveRecord::Migration[8.0]
  def change
    change_column_default :paper_exchange_orders, :instrument_type, from: "equity", to: "EQUITY"

    change_column :paper_exchange_orders, :exchange_segment, :string, default: "EQUITY", null: false if column_exists?(:paper_exchange_orders, :exchange_segment) && !column_default(:paper_exchange_orders, :exchange_segment)

    add_column :paper_exchange_orders, :security_id, :string unless column_exists?(:paper_exchange_orders, :security_id)
    add_column :paper_exchange_orders, :series, :string unless column_exists?(:paper_exchange_orders, :series)
  end
end