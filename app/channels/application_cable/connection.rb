module ApplicationCable
  # #8: the fills stream carries the same data as the REST API, so the WebSocket
  # uses the same single-operator trust boundary. The shared key is compared in
  # constant time, as in Api::BaseController#authenticate_api_key!. A browser
  # cannot set custom headers on a WebSocket, so the key may also be passed as
  # the `api_key` query parameter.
  class Connection < ActionCable::Connection::Base
    identified_by :operator

    # Pure check, so it can be tested without a socket.
    def self.authorized?(provided)
      expected = ENV["PAPER_EXCHANGE_API_KEY"].to_s
      !expected.empty? && ActiveSupport::SecurityUtils.secure_compare(provided.to_s, expected)
    end

    def connect
      provided = request.headers["X-API-Key"].to_s.presence || request.params["api_key"].to_s
      reject_unauthorized_connection unless self.class.authorized?(provided)

      self.operator = "operator"
    end
  end
end
