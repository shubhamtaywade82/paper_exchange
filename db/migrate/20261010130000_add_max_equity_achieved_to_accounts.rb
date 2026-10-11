# P1-1 fix: the max-drawdown risk gate previously compared current equity
# against the account's INITIAL margin, not its historical peak. An account
# that grew from 100k to 200k and then fell to 150k reported 0% drawdown
# (still above starting capital) when the real drawdown from peak is 25%.
#
# This migration adds a persisted high-water mark column that
# PortfolioProjection.summary updates lazily on read, and that
# MaxDrawdownValidator reads directly for its risk decision. Defaulting to
# the account's initial margin preserves backward compatibility (an account
# that never grew has max_equity_achieved == margin, same as the old formula).
class AddMaxEquityAchievedToAccounts < ActiveRecord::Migration[8.1]
  def up
    add_column :accounts, :max_equity_achieved, :decimal, precision: 36, scale: 18, null: false, default: 0.0

    # Backfill: every existing account's HWM starts at its current margin
    # (the old formula's baseline) so the drawdown calculation is stable
    # across the migration boundary.
    Account.reset_column_information
    Account.find_each do |account|
      account.update_columns(max_equity_achieved: [ account.current_equity.to_f, account.margin.to_f ].max)
    end
  end

  def down
    remove_column :accounts, :max_equity_achieved
  end
end
