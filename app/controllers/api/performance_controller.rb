module Api
  class PerformanceController < BaseController
    def show
      metrics = Projections::PerformanceMetrics.for(@account_id)
      render json: metrics
    end
  end
end
