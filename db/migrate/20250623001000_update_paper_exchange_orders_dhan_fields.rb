class UpdatePaperExchangeOrdersDhanFields < ActiveRecord::Migration[8.0]
  def change
    change_column_default :paper_exchange_orders, :instrument_type, from: "equity", to: "EQUITY"
    add_column :paper_exchange_orders, :exchange_segment, :integer
    add_column :paper_exchange_orders, :security_id, :string
    add_column :paper_exchange_orders, :series, :string
  end
end
