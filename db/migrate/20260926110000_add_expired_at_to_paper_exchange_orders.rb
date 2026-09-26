# Audit S2 (T3.2): PaperOrder#expired! writes an `expired_at` column that
# never existed — expire_order raised ActiveRecord::UnknownAttributeError on
# every call. This adds the column; the recurring ExpireOrdersJob sweep
# (config/recurring.yml) uses it to release margin parked against orders
# that never filled.
class AddExpiredAtToPaperExchangeOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :paper_exchange_orders, :expired_at, :datetime
  end
end
