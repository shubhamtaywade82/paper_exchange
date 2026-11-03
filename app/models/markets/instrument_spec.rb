# Trading parameters of an instrument, effective over [valid_from, valid_until).
# The database forbids overlapping windows for one instrument.
module Markets
  class InstrumentSpec < ApplicationRecord
    self.table_name = "instrument_specs"

    SETTLEMENT_TYPES = %w[cash physical none].freeze

    belongs_to :instrument, class_name: "Markets::Instrument", inverse_of: :specs

    validates :valid_from, :lot_size, :tick_size, :settlement_type, :source, :source_checksum, presence: true
    validates :settlement_type, inclusion: { in: SETTLEMENT_TYPES }
    validates :lot_size, :tick_size, numericality: { greater_than: 0 }
    validates :freeze_quantity, numericality: { greater_than: 0 }, allow_nil: true
    validate :window_ordered

    scope :in_force_at, lambda { |time|
      where("valid_from <= ? AND (valid_until IS NULL OR valid_until > ?)", time, time)
    }

    private

    def window_ordered
      return if valid_until.nil? || valid_from.nil? || valid_until > valid_from

      errors.add(:valid_until, "must be after valid_from")
    end
  end
end
