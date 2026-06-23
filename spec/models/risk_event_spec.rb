require 'rails_helper'

RSpec.describe RiskEvent, type: :model do
  it { is_expected.to validate_presence_of(:account_id) }
  it { is_expected.to validate_presence_of(:event_type) }
end
