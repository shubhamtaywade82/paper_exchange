# MarketData::MarkPriceStore keeps a process-level in-memory cache by design
# (see its class docs) so it survives across requests within one process.
# In the test process that cache would otherwise leak a symbol's price from
# one example into the next — reset it before every example so specs stay
# order-independent regardless of which other specs ran first.
RSpec.configure do |config|
  config.before do
    MarketData::MarkPriceStore.instance_variable_set(:@local_cache, nil)
  end
end
