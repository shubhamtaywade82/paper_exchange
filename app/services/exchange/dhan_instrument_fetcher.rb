module Exchange
  class DhanInstrumentFetcher
    DhanBaseUrl = "https://api.dhan.co/v2/instrument/".freeze

    def self.fetch_segment(exchange_segment)
      url = "#{DhanBaseUrl}#{exchange_segment}"
      response = Faraday.get(url)
      raise "Dhan instrument fetch failed: #{response.status}" unless response.success?

      JSON.parse(response.body)
    rescue Faraday::Error => e
      raise "Dhan instrument fetch error: #{e.message}"
    end
  end
end
