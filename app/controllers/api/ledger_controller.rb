module Api
  class LedgerController < BaseController
    def index
      entries = LedgerEntry.where(account_id: @account_id)
        .order(occurred_at: :desc)
        .limit(500)
      render json: entries.map { |e| entry_json(e) }
    end

    private

    def entry_json(entry)
      {
        id: entry.id,
        event_type: entry.event_type,
        payload: entry.payload,
        debit: entry.debit,
        credit: entry.credit,
        reference_id: entry.reference_id,
        occurred_at: entry.occurred_at,
        created_at: entry.created_at
      }
    end
  end
end
