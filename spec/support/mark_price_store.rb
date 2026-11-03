# MarketData::MarkPriceStore keeps a process-level cache and a Redis mirror
# shared by every process. Both survive across examples and across test runs,
# so a price one example writes would leak into the next and change its results.
# Clear both before every example, so specs are independent of order and of
# earlier runs.
RSpec.configure do |config|
  config.before do
    MarketData::MarkPriceStore.clear
  end
end
