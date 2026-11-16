# frozen_string_literal: true

require "ipaddr"

# Loopback clients on this machine need no token. Remote clients
# need `Authorization: Bearer $MCP_API_TOKEN`. Unset token = open in dev/test, closed in production.
class ApplicationGateway < ActionMCP::Gateway
  class TokenIdentifier < ActionMCP::GatewayIdentifier
    identifier :user
    authenticates :mcp_token

    def resolve
      return "local_client" if local_request?

      expected = ENV.fetch("MCP_API_TOKEN", "").presence
      return "mcp_client" if expected.nil? && !Rails.env.production?
      raise Unauthorized, "MCP_API_TOKEN not configured" unless expected

      provided = extract_bearer_token.to_s
      raise Unauthorized, "Invalid MCP token" unless ActiveSupport::SecurityUtils.secure_compare(provided, expected)

      "mcp_client"
    end

    private

    # Raw socket peer, not request.remote_ip: a reverse proxy would make remote clients look local,
    # so any forwarding header disqualifies loopback trust.
    def local_request?
      return false if @request.headers["X-Forwarded-For"].present? || @request.headers["Forwarded"].present?

      IPAddr.new(@request.remote_addr.to_s).loopback?
    rescue IPAddr::InvalidAddressError
      false
    end
  end

  identified_by TokenIdentifier
end
