require 'rails_helper'

RSpec.describe Strategy::OptionSelector, type: :service do
  it 'selects top option by volume and oi' do
    create(:option_snapshot, underlying: 'NIFTY', expiry_date: Date.today + 30, option_type: 'CE', volume: 100, oi: 500)
    selector = described_class.new
    result = selector.select_for(underlying: 'NIFTY', expiry_date: Date.today + 30, option_type: 'CE')
    expect(result).to be_present
  end
end
