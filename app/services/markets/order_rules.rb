module Markets
  # Checks an order against the exchange's rules before it is accepted
  # (MULTI_MARKET_SPEC §4 I9, I10, §8).
  #
  # Always on: instrument types whose rules are not loaded are refused.
  # Enforced when Markets::Enforcement.enforce? is true: the instrument must exist
  # and be unambiguous; quantity must be a lot multiple and within the freeze
  # quantity; a limit or trigger price must sit on the tick; the spec must be in
  # force at the time; and the trading calendar must show an open session.
  class OrderRules
    # Refusals use the order validator's error, so they reach the caller as the
    # same 422 as any other rejected order.
    # OrderValidationError is defined in order_validator.rb, which Zeitwerk loads
    # only once that file is referenced.
    ::Exchange::OrderValidator
    class Refused < ::Exchange::OrderValidationError; end

    NOT_LOADED = %w[FUTCOM FUTCUR OPTFUT OPTCUR].freeze
    INDIA_TYPES = %w[EQUITY FUTIDX FUTSTK OPTIDX OPTSTK].freeze

    def self.validate!(attrs, at: Clock.now)
      new(attrs, at).validate!
    end

    def initialize(attrs, at)
      @attrs = attrs
      @at = at
      @type = attrs[:instrument_type]
      @symbol = attrs[:symbol].to_s.upcase
    end

    def validate!
      if NOT_LOADED.include?(@type)
        refuse!("#{@type} is not supported until its exchange rules are loaded")
      end
      return unless INDIA_TYPES.include?(@type) && Enforcement.enforce?

      instrument = find_instrument
      spec = instrument.specs.in_force_at(@at).first
      refuse!("#{@symbol} has no instrument spec in force at #{@at}") if spec.nil?

      check_quantity!(spec)
      check_price!(spec)
      check_session!(instrument)
      nil
    end

    private

    def find_instrument
      matches = Markets::Instrument.where(symbol: @symbol, instrument_type: @type,
        expiry_date: @attrs[:expiry_date], option_type: @attrs[:option_type])
      matches = matches.where(strike_price: @attrs[:strike_price]) if @attrs[:strike_price]
      refuse!("no instrument master entry for #{@symbol} #{@type}") if matches.empty?
      refuse!("#{@symbol} #{@type} matches more than one instrument; the exchange must be unambiguous") if matches.size > 1

      matches.first
    end

    def check_quantity!(spec)
      quantity = BigDecimal(@attrs[:quantity].to_s)
      unless (quantity % spec.lot_size).zero?
        refuse!("quantity #{num(quantity)} is not a multiple of the lot size #{num(spec.lot_size)}")
      end
      return if spec.freeze_quantity.nil? || quantity <= spec.freeze_quantity

      refuse!("quantity #{num(quantity)} exceeds the freeze quantity #{num(spec.freeze_quantity)}; split the order")
    end

    def check_price!(spec)
      %i[price trigger_price].each do |field|
        value = @attrs[field]
        next if value.nil?
        next if (BigDecimal(value.to_s) % spec.tick_size).zero?

        refuse!("#{field} #{value} is not on the tick size #{num(spec.tick_size)}")
      end
    end

    # The exchange's trading day, in the exchange's zone, must be open and the
    # instant must fall inside its session. A missing day is unknown, so refused.
    def check_session!(instrument)
      exchange = instrument.exchange
      day = Clock.exchange_date(zone: exchange.time_zone, at: @at)
      calendar = Markets::TradingCalendarDay.find_by(exchange: exchange, segment: instrument.exchange_segment, trade_date: day)
      refuse!("no trading calendar entry for #{exchange.code} #{instrument.exchange_segment} on #{day}") if calendar.nil?
      refuse!("#{exchange.code} #{instrument.exchange_segment} is closed on #{day}") if calendar.status == "closed"
      return if calendar.session_open_at <= @at && @at < calendar.session_close_at

      refuse!("outside the #{exchange.code} #{instrument.exchange_segment} session on #{day}")
    end

    # Whole numbers print without a fractional zero, so a message reads 1800, not 1800.0.
    def num(value)
      value.to_d.to_s("F").delete_suffix(".0")
    end

    def refuse!(reason)
      raise Refused, "order refused: #{reason}"
    end
  end
end
