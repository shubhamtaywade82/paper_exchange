require 'rails_helper'

RSpec.describe PaperExchange::PaperPosition, type: :model do
  subject { build(:paper_position) }
  it { is_expected.to validate_presence_of(:symbol) }
  it { is_expected.to validate_presence_of(:side) }
  it { is_expected.to validate_numericality_of(:quantity).only_integer }
  it { is_expected.to validate_numericality_of(:avg_price).is_greater_than_or_equal_to(0).allow_nil }
  it { is_expected.to validate_numericality_of(:current_price).is_greater_than_or_equal_to(0).allow_nil }
end
