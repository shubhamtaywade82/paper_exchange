module Exchange
  class OrderValidator
    Schema = Dry::Schema.Params do
      required(:account_id).filled(:string)
      required(:symbol).filled(:string)
      required(:side).filled(:string, included_in?: %w[buy sell])
      required(:quantity).filled(:integer, gt?: 0)
      required(:order_kind).filled(:string, included_in?: %w[market bounded stop_loss])
      required(:instrument_type).filled(:string)
      optional(:option_type).maybe(:string, included_in?: %w[CE PE])
      optional(:strike_price).maybe(:decimal)
      optional(:expiry_date).maybe(:date)
      optional(:ltp).maybe(:decimal)
      optional(:price).maybe(:decimal, gt?: 0)
      optional(:trigger_price).maybe(:decimal, gt?: 0)
      optional(:context).maybe(:hash)
    end

    def self.call(attrs)
      # ActionController::Parameters returns string keys; Dry::Schema expects symbols
      symbolized = attrs.is_a?(Hash) ? attrs.to_h.symbolize_keys : attrs.to_h.symbolize_keys
      result = Schema.call(symbolized)
      return [false, result.errors.to_h] unless result.errors.empty?

      symbol = attrs[:symbol].to_s.upcase.strip
      if !%w[FUTIDX OPTIDX].include?(attrs[:instrument_type]) && Exchange::DhanInstrumentCatalog.index_underlying?(symbol)
        errors = { instrument_type: "Indices must be traded via F&O derivatives only (FUTIDX/OPTIDX). Got: #{attrs[:instrument_type]}" }
        return [false, errors]
      end

      [true, result.to_h]
    end

    def self.margin_ok?(attrs)
      account = Account.find_by(account_id: attrs[:account_id])
      return true unless account

      price = (attrs[:ltp] || attrs[:price] || 0).to_f
      required = BrokerageCalculator.new.margin_required_for(
        trade_price: price,
        quantity: attrs[:quantity],
        side: attrs[:side],
        symbol: attrs[:symbol],
        instrument_type: (attrs[:instrument_type] || "EQUITY")
      )
      required <= account.margin
    end
  end
end
