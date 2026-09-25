module Api
  class PositionsController < BaseController
    def index
      positions = Projections::PositionProjection.for_account(@account_id)
      render json: positions
    end

    def show
      position = Projections::PositionProjection.for_id(@account_id, params[:id])
      # M7 regression guard: early return — the old code fell through to a
      # second render when the position was missing (double-render on top of
      # the Integer == String comparison that always 404'd).
      return render_error(:not_found, "Position not found") unless position

      render json: position
    end
  end
end
