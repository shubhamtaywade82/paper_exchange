require 'rails_helper'

RSpec.describe LedgerEntry, type: :model do
  it { is_expected.to validate_presence_of(:account_id) }
  it { is_expected.to validate_presence_of(:event_type) }
  it { is_expected.to validate_presence_of(:occurred_at) }
  it { is_expected.to validate_numericality_of(:debit).is_greater_than_or_equal_to(0) }
  it { is_expected.to validate_numericality_of(:credit).is_greater_than_or_equal_to(0) }
end
