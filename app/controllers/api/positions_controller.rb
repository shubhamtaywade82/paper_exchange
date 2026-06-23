module Api
  class PositionsController < BaseController
    def index
      positions = Projections::PositionProjection.for_account(@account_id)
      render json: positions
    end

    def show
      positions = Projections::PositionProjection.for_account(@account_id)
      position = positions.find { |p| p[:id] == params[:id] }
      render_error(:not_found, "Position not found") unless position
      render json: position
    end
  end
end
