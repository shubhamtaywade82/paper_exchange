module Api
  class LedgerController < BaseController
    # Audit N6 (T5.4): keyset pagination on (occurred_at, id) DESC —
    # see Api::CursorPagination for the envelope and cursor contract.
    def index
      entries, next_cursor = paginate(LedgerEntry.where(account_id: @account_id), :occurred_at)
      render json: { data: entries.map { |e| entry_json(e) }, next_cursor: next_cursor }
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
