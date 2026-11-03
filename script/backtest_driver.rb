#!/usr/bin/env ruby
# frozen_string_literal: true

# Reference bot for a bot-driven backtest. It uses only the paper_exchange API:
#
#   1. uploads a CSV of closed bars as a dataset
#   2. creates an external run with benchmarks and a manifest
#   3. replays it bar by bar with POST /advance; its SMA-crossover decisions are
#      placed as orders on the run's account (POST /api/orders, X-Account-Id)
#   4. prints the stored metrics and verdict
#
# Orders the bot places after bar k execute at bar k+1's open. The bot only ever
# sees bars the replay has reached.
#
# Usage:
#   PAPER_EXCHANGE_API_KEY=... bin/rails runner script/backtest_driver.rb data.csv
#   (or BASE_URL=http://localhost:3100 ruby script/backtest_driver.rb data.csv)

require "csv"
require "json"
require "net/http"
require "uri"

BASE_URL = ENV.fetch("BASE_URL", "http://localhost:3100")
API_KEY = ENV.fetch("PAPER_EXCHANGE_API_KEY")
FAST = Integer(ENV.fetch("FAST", "9"))
SLOW = Integer(ENV.fetch("SLOW", "21"))
STOP_PCT = Float(ENV.fetch("STOP_PCT", "1.0"))
QUANTITY = Float(ENV.fetch("QUANTITY", "10"))
CAPITAL = Float(ENV.fetch("CAPITAL", "100000"))

class PaperExchangeApi
  def initialize(base_url, api_key)
    @base = URI(base_url)
    @api_key = api_key
  end

  def call(method, path, body: nil, account: nil)
    uri = @base.dup
    uri.path = path
    request = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
    request["X-API-Key"] = @api_key
    request["X-Account-Id"] = account if account
    if body
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body)
    end
    response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
    parsed = response.body.to_s.empty? ? {} : JSON.parse(response.body)
    raise "#{method.upcase} #{path} -> #{response.code}: #{parsed}" unless response.code.to_i < 300

    parsed
  end
end

def sma(values, period)
  return nil if values.size < period

  values.last(period).sum / period.to_f
end

csv_path = ARGV.fetch(0) { abort "usage: backtest_driver.rb bars.csv" }
api = PaperExchangeApi.new(BASE_URL, API_KEY)

dataset = api.call(:post, "/api/backtest_datasets", body: {
  name: "driver #{File.basename(csv_path)}", symbol: "SOLUSDT", instrument_type: "CRYPTO_PERPETUAL",
  timeframe: "5m", csv: File.read(csv_path)
})
puts "dataset #{dataset['id']}: #{dataset['bars_count']} bars"

run = api.call(:post, "/api/backtest_runs", body: {
  dataset_id: dataset["id"], name: "sma #{FAST}/#{SLOW} driver", mode: "external",
  initial_capital: CAPITAL, leverage: 1,
  benchmarks: { min_trades: 5, min_profit_factor: 1.2, max_drawdown_pct: 20, beat_buy_and_hold: true },
  manifest: { strategy: "sma_cross", version: "driver-1", params: { fast: FAST, slow: SLOW, stop_pct: STOP_PCT } }
})
account = run["account_id"]
puts "run #{run['id']} on account #{account}"

closes = []
position = nil
loop do
  step = api.call(:post, "/api/backtest_runs/#{run['id']}/advance")
  closes << step["bar"]["close"]
  fast = sma(closes, FAST)
  slow = sma(closes, SLOW)
  previous_fast = sma(closes[0...-1], FAST)
  previous_slow = sma(closes[0...-1], SLOW)

  position = step["position"]
  if fast && slow && previous_fast && previous_slow
    if position.nil? && previous_fast <= previous_slow && fast > slow
      stop = (step["bar"]["close"] * (1 - STOP_PCT / 100.0)).round(4)
      api.call(:post, "/api/orders", account: account, body: {
        symbol: "SOLUSDT", side: "buy", quantity: QUANTITY, order_type: "market",
        instrument_type: "CRYPTO_PERPETUAL", stop_loss: stop
      })
    elsif position && position["side"] == "long" && previous_fast >= previous_slow && fast < slow
      api.call(:post, "/api/orders", account: account, body: {
        symbol: "SOLUSDT", side: "sell", quantity: position["quantity"], order_type: "market",
        instrument_type: "CRYPTO_PERPETUAL", reduce_only: true
      })
    end
  end

  step["fills"].each { |fill| puts "  #{step['bar']['bar_at']} fill #{fill['side']} #{fill['quantity']} @ #{fill['price']} (#{fill['reason'] || fill['role']})" }
  break if step["finished"]
end

result = api.call(:get, "/api/backtest_runs/#{run['id']}")
puts "status: #{result['status']}"
puts "metrics: #{JSON.pretty_generate(result['metrics'].slice('total_trades', 'net_profit', 'profit_factor', 'max_drawdown_pct', 'percent_profitable', 'buy_and_hold_return_pct', 'equity_change_pct'))}"
puts "verdict: #{JSON.pretty_generate(result['verdict'])}"
