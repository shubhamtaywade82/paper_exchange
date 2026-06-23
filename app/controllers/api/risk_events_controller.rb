module Api
  class RiskEventsController < BaseController
    def index
      events = RiskEvent.where(account_id: @account_id)
        .order(created_at: :desc)
        .limit(200)
      render json: events.map { |e| event_json(e) }
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
