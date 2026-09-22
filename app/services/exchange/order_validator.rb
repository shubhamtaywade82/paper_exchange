module Exchange
  class OrderValidationError < StandardError; end

  class OrderValidator
    Schema = Dry::Schema.Params do
      required(:account_id).filled(:string)
      required(:symbol).filled(:string)
      required(:side).filled(:string, included_in?: %w[buy sell])
      required(:quantity).filled(:decimal, gt?: 0)
      required(:order_kind).filled(:string, included_in?: %w[market bounded stop_loss])
      required(:instrument_type).filled(:string)
      optional(:option_type).maybe(:string, included_in?: %w[CE PE])
      optional(:strike_price).maybe(:decimal)
      optional(:expiry_date).maybe(:date)
      optional(:ltp).maybe(:decimal)
      optional(:price).maybe(:decimal, gt?: 0)
      optional(:trigger_price).maybe(:decimal, gt?: 0)
      optional(:leverage).maybe(:integer, gteq?: 1)
      optional(:margin_type).maybe(:string, included_in?: %w[cross isolated])
      optional(:client_order_id).maybe(:string)
      optional(:execution_price).maybe(:decimal, gt?: 0)
      optional(:reduce_only).maybe(:bool)
      optional(:context).maybe(:hash)
    end

    def self.call(attrs)
      # ActionController::Parameters#to_h returns only the *permitted* keys,
      # which drops :order_kind/:account_id the controller sets AFTER permit.
      # Use to_unsafe_h for Parameters; fall back to to_h for plain Hashes.
      symbolized = attrs.respond_to?(:to_unsafe_h) ? attrs.to_unsafe_h.symbolize_keys : attrs.to_h.symbolize_keys
      result = Schema.call(symbolized)
      raise OrderValidationError, result.errors.to_h.inspect unless result.errors.empty?

      symbol = symbolized[:symbol].to_s.upcase.strip
      if !%w[FUTIDX OPTIDX].include?(symbolized[:instrument_type]) && Exchange::DhanInstrumentCatalog.index_underlying?(symbol)
        raise OrderValidationError, "Indices must be traded via F&O derivatives only (FUTIDX/OPTIDX). Got: #{symbolized[:instrument_type]}"
      end

      result.to_h
    end
  end
end
