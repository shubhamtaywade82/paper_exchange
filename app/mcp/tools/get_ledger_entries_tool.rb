# frozen_string_literal: true

class GetLedgerEntriesTool < ApplicationMCPTool
  tool_name "get_ledger_entries"
  description "Recent entries from the append-only margin and cash ledger for an account. Read-only."

  property :account_id, type: "string", description: "Account identifier (default: test-account-1)"
  property :event_type, type: "string", description: "Filter by event type (e.g. TRADE, MARGIN_LOCKED, MARGIN_UNLOCKED, FEE, REALIZED_PNL, FUNDING_FEE)"
  property :limit, type: "integer", description: "Max entries to return (default 20, max 100)"

  def perform
    acc_id = account_id.presence || "test-account-1"
    scope = ::LedgerEntry.where(account_id: acc_id)
    scope = scope.where(event_type: event_type.upcase) if event_type.present?

    max_records = limit.present? ? limit.to_i.clamp(1, 100) : 20
    entries = scope.order(occurred_at: :desc).limit(max_records).map do |e|
      {
        id: e.id,
        account_id: e.account_id,
        event_type: e.event_type,
        debit: e.debit.to_s,
        credit: e.credit.to_s,
        balance_after: e.balance_after&.to_s,
        currency: e.currency,
        reference_id: e.reference_id,
        payload: e.payload,
        occurred_at: e.occurred_at.iso8601
      }
    end

    render_json(
      account_id: acc_id,
      count: entries.size,
      entries: entries
    )
  end
end
