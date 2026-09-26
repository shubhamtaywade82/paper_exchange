module Api
  class RiskEventsController < BaseController
    # Audit N6 (T5.4): keyset pagination on (created_at, id) DESC —
    # see Api::CursorPagination for the envelope and cursor contract.
    def index
      events, next_cursor = paginate(RiskEvent.where(account_id: @account_id), :created_at)
      render json: { data: events.map { |e| event_json(e) }, next_cursor: next_cursor }
    end

    private

    def event_json(event)
      {
        id: event.id,
        event_type: event.event_type,
        details: event.details,
        created_at: event.created_at
      }
    end
  end
end
