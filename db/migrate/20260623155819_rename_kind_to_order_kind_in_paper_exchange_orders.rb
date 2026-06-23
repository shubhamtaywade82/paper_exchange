class RenameKindToOrderKindInPaperExchangeOrders < ActiveRecord::Migration[8.1]
  def change
    rename_column :paper_exchange_orders, :kind, :order_kind if column_exists?(:paper_exchange_orders, :kind)
  end
end
