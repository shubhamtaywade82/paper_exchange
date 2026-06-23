class RenameOrderTypeToKindInPaperOrders < ActiveRecord::Migration[8.1]
  def change
    rename_column :paper_exchange_orders, :order_type, :kind if column_exists?(:paper_exchange_orders, :order_type)
  end
end
