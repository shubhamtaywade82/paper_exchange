module Api
  # Architecture alignment (target architecture §6): position protection
  # endpoint. Allows the trading bot (or an operator) to attach durable
  # stop-loss, take-profit, and trailing-stop policies to an open position.
  # These survive process restarts — the ProtectionMonitor job continues
  # to evaluate them even when the bot is offline.
  class ProtectionsController < BaseController
    before_action :set_position

    def create
      protection = ::PositionProtection.new(protection_params.merge(
        paper_position_id: @position.id,
        account_id: @account_id,
        venue: @position.venue,
        instrument_id: @position.symbol
      ))

      if protection.save
        render json: protection_json(protection), status: :created
      else
        render_error(:unprocessable_content, protection.errors.full_messages.join(", "))
      end
    end

    def index
      protections = ::PositionProtection
        .where(account_id: @account_id, paper_position_id: @position.id)
        .order(created_at: :desc)
      render json: protections.map { |p| protection_json(p) }
    end

    def destroy
      protection = ::PositionProtection.find_by!(
        id: params[:id],
        account_id: @account_id,
        paper_position_id: @position.id
      )
      protection.cancel!
      render json: protection_json(protection)
    end

    private

    def set_position
      @position = ::PaperExchange::PaperPosition.find_by!(
        id: params[:position_id],
        account_id: @account_id
      )
    rescue ActiveRecord::RecordNotFound
      render_error(:not_found, "Position not found")
    end

    def protection_params
      params.require(:protection).permit(
        :protection_type, :trigger_price, :trailing_distance,
        :quantity, :oco_group_id
      )
    end

    def protection_json(protection)
      {
        id: protection.id,
        position_id: protection.paper_position_id,
        venue: protection.venue,
        instrument_id: protection.instrument_id,
        protection_type: protection.protection_type,
        trigger_price: protection.trigger_price,
        trailing_distance: protection.trailing_distance,
        quantity: protection.quantity,
        status: protection.status,
        oco_group_id: protection.oco_group_id,
        high_water_mark: protection.high_water_mark,
        low_water_mark: protection.low_water_mark,
        triggered_at: protection.triggered_at,
        cancelled_at: protection.cancelled_at
      }
    end
  end
end
