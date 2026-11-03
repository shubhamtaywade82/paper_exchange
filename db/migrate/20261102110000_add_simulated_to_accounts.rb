# Backtest accounts share tables with live accounts. Live recurring jobs
# (matching worker, order expiry, option settlement, funding, protection
# monitor, liquidation cache, market-data subscriptions) query across all
# accounts, so a backtest account would otherwise be matched, expired,
# settled or funded at live prices. `simulated` marks those accounts, and the
# live queries are scoped to `simulated = false`.
class AddSimulatedToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :simulated, :boolean, null: false, default: false
  end
end
