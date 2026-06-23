require 'rails_helper'

RSpec.describe Exchange::LatencyEngine, type: :service do
  it 'delays and then yields' do
    engine = described_class.new
    start = Time.now
    engine.delay(100) { :done }
    expect(Time.now - start).to be >= 0.09
  end
end
