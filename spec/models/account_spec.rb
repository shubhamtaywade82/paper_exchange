require 'rails_helper'

RSpec.describe Account, type: :model do
  it { is_expected.to validate_presence_of(:account_id) }
  it { is_expected.to validate_uniqueness_of(:account_id) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:currency) }
  it { is_expected.to allow_value('INR').for(:currency) }
  it { is_expected.to allow_value('USD').for(:currency) }
  it { is_expected.not_to allow_value('EUR').for(:currency) }
  it { is_expected.to validate_numericality_of(:margin).is_greater_than_or_equal_to(0) }
end
