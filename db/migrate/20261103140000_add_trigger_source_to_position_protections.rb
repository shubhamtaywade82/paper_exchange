# Each protection declares the price it is evaluated on (MULTI_MARKET_SPEC §4 I3).
# Existing rows get `mark`, the source the monitor has always read first. Mark is
# the quote's mark, then the mark store that the paper and agent flows write to,
# which is the same declared source. Last trade and bid/ask never stand in for it.
class AddTriggerSourceToPositionProtections < ActiveRecord::Migration[8.1]
  def change
    add_column :position_protections, :trigger_source, :string, null: false, default: "mark"
    add_check_constraint :position_protections,
      "trigger_source IN ('last_trade','bid_ask','mark','index')",
      name: "position_protections_trigger_source_valid"
  end
end
