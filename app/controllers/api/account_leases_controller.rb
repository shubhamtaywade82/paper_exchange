module Api
  # The lease for the account named in X-Account-Id. Reading it is open to any authenticated caller. Acquiring, renewing and
  # releasing it is how a writer takes and gives back the single-writer right that every write to a live account requires.
  # The account must be named explicitly: a lease is never taken on the implicit "default" account.
  class AccountLeasesController < BaseController
    skip_before_action :require_account_for_writes
    skip_around_action :fence_live_writes
    before_action :require_named_account!

    def show
      row = AccountLease.find_by(venue: AccountLeases::VENUE, account_id: @account_id)
      return render_error(:not_found, "no lease has been granted for this account") unless row

      render json: lease_json(row).merge(live: live?(row))
    end

    # Body: holder_id (the caller's own id; reuse it on a retry), holder_label (for operators), ttl_seconds (10 to 600, default 30)
    def create
      holder_id = params[:holder_id].to_s.strip
      return render_error(:bad_request, "holder_id is required, at most 64 characters") unless holder_id.match?(/\A.{1,64}\z/)

      ttl = AccountLeases.ttl_seconds(params[:ttl_seconds])
      return render_error(:bad_request, "ttl_seconds must be a whole number from #{AccountLeases::MIN_TTL_SECONDS} to #{AccountLeases::MAX_TTL_SECONDS}") unless ttl

      row = AccountLeases.acquire!(account_id: @account_id, holder_id: holder_id, label: label_param, ttl_seconds: ttl)
      render json: lease_json(row).merge(live: true), status: :created
    rescue AccountLeases::Held => e
      render json: { error: "lease_held", holder_label: e.holder_label, expires_at: e.expires_at&.iso8601(3) }, status: :conflict
    end

    def update
      ttl = AccountLeases.ttl_seconds(params[:ttl_seconds])
      return render_error(:bad_request, "ttl_seconds must be a whole number from #{AccountLeases::MIN_TTL_SECONDS} to #{AccountLeases::MAX_TTL_SECONDS}") unless ttl

      row = AccountLeases.heartbeat!(account_id: @account_id, holder_id: lease_holder, fence: lease_fence, ttl_seconds: ttl)
      render json: lease_json(row).merge(live: true)
    rescue AccountLeases::Required => e
      render_lease_error(:lease_required, e.message)
    rescue AccountLeases::Lost => e
      render_lease_error(:lease_lost, e.message)
    end

    def destroy
      released = AccountLeases.release!(account_id: @account_id, holder_id: lease_holder, fence: lease_fence)
      render json: { released: released }
    rescue AccountLeases::Required => e
      render_lease_error(:lease_required, e.message)
    end

    private

    def require_named_account!
      return if request.headers["X-Account-Id"].present?

      render_error(:bad_request, "account_required: name the account in X-Account-Id")
    end

    def lease_holder
      request.headers["X-Lease-Holder"]
    end

    def lease_fence
      request.headers["X-Lease-Fence"]
    end

    def label_param
      label = params[:holder_label].to_s.strip
      label.empty? ? nil : label.first(120)
    end

    def live?(row)
      AccountLease.where(id: row.id).where("expires_at > now()").exists? && row.holder_id.present?
    end

    def render_lease_error(code, message)
      render json: { error: code.to_s, message: message }, status: :conflict
    end

    def lease_json(row)
      {
        account_id: row.account_id,
        venue: row.venue,
        holder_id: row.holder_id,
        holder_label: row.holder_label,
        fence: row.fence,
        acquired_at: row.acquired_at&.iso8601(3),
        heartbeat_at: row.heartbeat_at&.iso8601(3),
        expires_at: row.expires_at&.iso8601(3),
        released_at: row.released_at&.iso8601(3)
      }
    end
  end
end
