module Exchange
  class OrderValidator
    Schema = Dry::Schema.Params do
      required(:account_id).filled(:string)
      required(:symbol).filled(:string)
      required(:side).filled(:string, included_in?: %w[buy sell])
      required(:quantity).filled(:integer, gt?: 0)
      required(:order_type).filled(:string, included_in?: %w[market limit stop_loss])
      required(:instrument_type).filled(:string, included_in?: DhanInstrumentCatalog::INSTRUMENT_TYPES)
      optional(:option_type).maybe(:string, included_in?: %w[CE PE])
      optional(:strike_price).maybe(:decimal)
      optional(:expiry_date).maybe(:date)
      optional(:ltp).maybe(:decimal)
      optional(:price).maybe(:decimal, gt?: 0)
      optional(:trigger_price).maybe(:decimal, gt?: 0)
      optional(:context).maybe(:hash)

      # Hard rule from Dhan scrip master: indices are derivative-only.
      # Allowed instrument types for indices: FUTIDX, OPTIDX only.
      rule(:symbol, :instrument_type) do
        values[:symbol] = values[:symbol].to_s.upcase.strip
        if DhanInstrumentCatalog.index_underlying?(values[:symbol])
          allowed = %w[FUTIDX OPTIDX]
          unless allowed.include?(values[:instrument_type])
            key.failure("Indices must be traded via F&O derivatives only (FUTIDX/OPTIDX). Got: #{values[:instrument_type]}")
          end
        end
      end
    end

    def self.call(attrs)
      result = Schema.call(attrs)
      if result.errors.empty?
        [true, result.to_h]
      else
        [false, result.errors.to_h]
      end
    end
  end
end
