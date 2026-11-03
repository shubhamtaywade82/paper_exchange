# Table `exchanges`. Inside Markets, `Exchange` means this model; code in the
# Exchange module must refer to ::Exchange explicitly.
module Markets
  class Exchange < ApplicationRecord
    self.table_name = "exchanges"

    has_many :instruments, class_name: "Markets::Instrument", foreign_key: :exchange_id, inverse_of: :exchange,
      dependent: :restrict_with_exception

    validates :code, presence: true, uniqueness: true
    validates :time_zone, presence: true
    validate :time_zone_is_known

    private

    def time_zone_is_known
      return if time_zone.blank? || ActiveSupport::TimeZone[time_zone]

      errors.add(:time_zone, "is not a known IANA zone")
    end
  end
end
