module Strategy
  class OptionSelector
    def initialize(option_snapshot_repository: OptionSnapshot)
      @option_snapshot_repository = option_snapshot_repository
    end

    def select_for(underlying:, expiry_date:, option_type:, quantity: 1, filters: {})
      candidates = @option_snapshot_repository.where(
        underlying: underlying,
        expiry_date: expiry_date,
        option_type: option_type
      )

      candidates = candidates.where("oi >= ?", filters[:min_oi]) if filters[:min_oi]
      candidates = candidates.where("volume >= ?", filters[:min_volume]) if filters[:min_volume]
      candidates = candidates.where("iv <= ?", filters[:max_iv]) if filters[:max_iv]

      candidates.order(volume: :desc, oi: :desc).first
    end
  end
end
