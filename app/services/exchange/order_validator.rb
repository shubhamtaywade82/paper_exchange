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

      validated = result.to_h
      validate_crypto_option!(validated) if validated[:instrument_type] == CryptoInstrumentCatalog::OPTION
      validated
    end

    # Long-premium-only crypto options. The contract fields must agree with
    # the symbol (the position's contract identity is built from them, so a
    # mismatch would book the fill against the wrong contract), leverage is
    # meaningless for a fully paid premium, and a sell is only ever a close:
    # writing an option would expose the account to unbounded loss.
    def self.validate_crypto_option!(attrs)
      parsed = CryptoInstrumentCatalog.parse_option_symbol(attrs[:symbol])
      raise OrderValidationError, "CRYPTO_OPTION symbol must look like BTC-261030-81000-C, got #{attrs[:symbol]}" unless parsed

      if attrs[:option_type] != parsed.option_type
        raise OrderValidationError, "CRYPTO_OPTION option_type #{attrs[:option_type].inspect} does not match #{attrs[:symbol]} (#{parsed.option_type})"
      end
      if attrs[:strike_price].nil? || BigDecimal(attrs[:strike_price].to_s) != parsed.strike
        raise OrderValidationError, "CRYPTO_OPTION strike_price #{attrs[:strike_price].inspect} does not match #{attrs[:symbol]} (#{parsed.strike.to_s('F')})"
      end
      if attrs[:expiry_date] != parsed.expiry_date
        raise OrderValidationError, "CRYPTO_OPTION expiry_date #{attrs[:expiry_date].inspect} does not match #{attrs[:symbol]} (#{parsed.expiry_date})"
      end
      if attrs[:leverage] && attrs[:leverage] != 1
        raise OrderValidationError, "CRYPTO_OPTION premium is paid in full: leverage must be 1, got #{attrs[:leverage]}"
      end
      if attrs[:side] == "sell" && !attrs[:reduce_only]
        raise OrderValidationError, "CRYPTO_OPTION sell must be reduce_only: option writing (sell to open) is not supported"
      end
      if attrs[:side] == "buy" && Time.now.utc >= CryptoInstrumentCatalog.option_expires_at(parsed.expiry_date)
        raise OrderValidationError, "CRYPTO_OPTION #{attrs[:symbol]} has expired; it cannot be bought"
      end
    end
  end
end
