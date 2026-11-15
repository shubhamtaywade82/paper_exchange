# Writes to a live account present that account's lease, the way the Agent does. A spec takes the lease through
# AccountLeases and presents the headers a writer sends. One holder per account per example, so every write in one
# example is made by the same writer.
module AccountLeaseHelpers
  def lease_headers_for(account_id)
    @lease_headers_by_account ||= {}
    @lease_headers_by_account[account_id] ||= begin
      holder_id = SecureRandom.uuid
      lease = AccountLeases.acquire!(
        account_id: account_id,
        holder_id: holder_id,
        label: "rspec",
        ttl_seconds: AccountLeases::MAX_TTL_SECONDS
      )
      { "X-Lease-Holder" => holder_id, "X-Lease-Fence" => lease.fence.to_s }
    end
  end
end

RSpec.configure do |config|
  config.include AccountLeaseHelpers
end
