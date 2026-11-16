# frozen_string_literal: true

class GetRiskEventsTool < ApplicationMCPTool
  tool_name "get_risk_events"
  description "Recent risk evaluation rejections and liquidation events recorded by the risk manager. Read-only."

  property :account_id, type: "string", description: "Filter by account identifier (optional)"
  property :event_type, type: "string", description: "Filter by event type (e.g. margin_exceeded, max_drawdown_breached, vix_gate_tripped)"
  property :limit, type: "integer", description: "Max events to return (default 20, max 100)"

  def perform
    scope = ::RiskEvent.all
    scope = scope.where(account_id: account_id) if account_id.present?
    scope = scope.where(event_type: event_type) if event_type.present?

    max_records = limit.present? ? limit.to_i.clamp(1, 100) : 20
    events = scope.order(created_at: :desc).limit(max_records).map do |r|
      {
        id: r.id,
        account_id: r.account_id,
        event_type: r.event_type,
        signal_id: r.signal_id,
        details: r.details,
        created_at: r.created_at.iso8601
      }
    end

    render_json(
      count: events.size,
      events: events
    )
  end
end
