module Exchange
  class OrderValidator
    Schema = Dry::Schema.Params do
      required(:account_id).filled(:string)
      required(:symbol).filled(:string)
      required(:side).filled(:string, included_in?: %w[buy sell])
      required(:quantity).filled(:integer, gt?: 0)
      required(:order_kind).filled(:string, included_in?: %w[market limit stop_loss])
      required(:instrument_type).filled(:string, included_in?: DhanInstrumentCatalog::INSTRUMENT_TYPES)
      optional(:option_type).maybe(:string, included_in?: %w[CE PE])
      optional(:strike_price).maybe(:decimal)
      optional(:expiry_date).maybe(:date)
      optional(:ltp).maybe(:decimal)
      optional(:price).maybe(:decimal, gt?: 0)
      optional(:trigger_price).maybe(:decimal, gt?: 0)
      optional(:context).maybe(:hash)
    end

    def self.call(attrs)
      result = Schema.call(attrs)
      return [false, result.errors.to_h] unless result.errors.empty?

      symbol = attrs[:symbol].to_s.upcase.strip
      if DhanInstrumentCatalog.index_underlying?(symbol) && attrs[:instrument_type] && !%w[FUTIDX OPTIDX].include?(attrs[:instrument_type])
        errors = { instrument_type: "Indices must be traded via F&O derivatives only (FUTIDX/OPTIDX). Got: #{attrs[:instrument_type]}" }
        return [false, errors]
      end

      [true, result.to_h]
    end
  end
end
