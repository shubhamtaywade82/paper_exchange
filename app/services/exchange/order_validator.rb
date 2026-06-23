module Exchange
  class OrderValidator
    Schema = Dry::Schema.Params do
      required(:account_id).filled(:string)
      required(:symbol).filled(:string)
      required(:side).filled(:string, included_in?: %w[buy sell])
      required(:quantity).filled(:integer, gt?: 0)
      required(:order_type).filled(:string, included_in?: %w[market limit stop_loss])
      optional(:instrument_type).filled(:string, included_in?: %w[equity future option])
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
      if result.errors.empty?
        [true, result.to_h]
      else
        [false, result.errors.to_h]
      end
    end
  end
end
