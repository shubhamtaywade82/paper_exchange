# Explicitly require exchange catalog services so Zeitwerk can map them
# despite nested acronyms that may trip up default autoloading.
require Rails.root.join("app/services/exchange/binance_usdm_futures_catalog")
require Rails.root.join("app/services/exchange/coindcx_futures_catalog")
