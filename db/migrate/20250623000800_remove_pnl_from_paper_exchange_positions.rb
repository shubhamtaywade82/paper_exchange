class RemovePnlFromPaperExchangePositions < ActiveRecord::Migration[8.0]
  def change
    remove_column :paper_exchange_positions, :unrealized_pnl, :decimal
    remove_column :paper_exchange_positions, :realized_pnl, :decimal
  end
end
