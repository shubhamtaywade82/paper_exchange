module Api
  # Keyset (cursor) pagination for the list endpoints (audit N6 / T5.4):
  # a plain `limit(N)` silently truncated history for active accounts.
  #
  # Pages are ordered (sort_column DESC, id DESC) and the cursor is the
  # opaque Base64url encoding of "<sort_column ISO8601>|<id>" taken from
  # the last item of a page. The next page is the keyset predicate
  # `(sort_column, id) < (cursor_ts, cursor_id)` — a total order even
  # when many rows share one timestamp, unlike a bare `WHERE ts < ?`.
  #
  # Callers pass the sort column as a literal symbol from an allowlist
  # (placed_at / occurred_at / created_at) — never from params.
  #
  # Response envelope: { "data": [...], "next_cursor": "..." | null }.
  # `next_cursor` is null when the page was the last one. `limit` is
  # clamped to 1..MAX_LIMIT (default DEFAULT_LIMIT).
  module CursorPagination
    class InvalidCursorError < StandardError; end

    DEFAULT_LIMIT = 100
    MAX_LIMIT = 500

    def paginate(scope, column)
      limit = page_limit
      scope = apply_cursor(scope, column) if params[:cursor].present?
      items = scope.order(column => :desc, id: :desc).limit(limit + 1).to_a
      more = items.size > limit
      items.pop if more
      [ items, more ? encode_cursor(items.last, column) : nil ]
    end

    private

    def page_limit
      requested = Integer(params[:limit], exception: false)
      return DEFAULT_LIMIT if requested.nil? || requested < 1

      requested.clamp(1, MAX_LIMIT)
    end

    def apply_cursor(scope, column)
      ts, id = decode_cursor
      table = scope.table_name
      scope.where("(#{table}.#{column}, #{table}.id) < (:ts, :id)", ts: ts, id: id)
    end

    def decode_cursor
      decoded = begin
        Base64.urlsafe_decode64(params[:cursor].to_s)
      rescue ArgumentError
        raise InvalidCursorError, "cursor is not a valid cursor token"
      end

      ts_raw, id_raw = decoded.to_s.split("|", 2)
      raise InvalidCursorError, "cursor is malformed" if ts_raw.blank? || id_raw.blank?

      id = Integer(id_raw, exception: false)
      raise InvalidCursorError, "cursor is malformed" if id.nil?

      [ Time.iso8601(ts_raw), id ]
    rescue ArgumentError
      raise InvalidCursorError, "cursor timestamp is not ISO8601"
    end

    def encode_cursor(item, column)
      Base64.urlsafe_encode64("#{item.public_send(column).iso8601(6)}|#{item.id}")
    end
  end
end
