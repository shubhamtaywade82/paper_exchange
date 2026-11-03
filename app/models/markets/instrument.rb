# Table `instruments`: identity of a tradeable contract. Its trading parameters
# (lot, tick, freeze, settlement) are versioned in Markets::InstrumentSpec.
module Markets
  class Instrument < ApplicationRecord
    self.table_name = "instruments"

    INSTRUMENT_TYPES = %w[EQUITY FUTIDX FUTSTK FUTCOM FUTCUR OPTIDX OPTSTK OPTFUT OPTCUR CRYPTO_PERPETUAL CRYPTO_OPTION].freeze
    OPTION_TYPES = %w[OPTIDX OPTSTK OPTFUT OPTCUR CRYPTO_OPTION].freeze

    belongs_to :exchange, class_name: "Markets::Exchange", inverse_of: :instruments
    belongs_to :underlying, class_name: "Markets::Instrument", optional: true
    has_many :specs, class_name: "Markets::InstrumentSpec", foreign_key: :instrument_id, inverse_of: :instrument,
      dependent: :restrict_with_exception

    validates :exchange_segment, :security_id, :symbol, :instrument_type, presence: true
    validates :instrument_type, inclusion: { in: INSTRUMENT_TYPES }
    validates :security_id, uniqueness: { scope: %i[exchange_id exchange_segment] }
  end
end
