module Api
  # OHLC datasets for the backtesting engine. A dataset is immutable: to
  # change the bars, upload a new dataset.
  class BacktestDatasetsController < BaseController
    before_action :set_dataset, only: %i[show destroy]

    def index
      datasets, next_cursor = paginate(Backtest::Dataset.all, :created_at)
      render json: { data: datasets.map { |d| dataset_json(d) }, next_cursor: next_cursor }
    end

    def show
      render json: dataset_json(@dataset)
    end

    # Body: { name, symbol, instrument_type, timeframe, currency?, venue?,
    #         option_type?, strike_price?, expiry_date?,
    #         bars: [{ bar_at, open, high, low, close, volume? }, ...] | [[ts, o, h, l, c, v], ...],
    #         csv?: "bar_at,open,high,low,close,volume\n..." }
    def create
      dataset = Backtest::DatasetManager.create!(params.to_unsafe_h)
      render json: dataset_json(dataset), status: :created
    rescue Backtest::DatasetValidator::Invalid => e
      render json: { error: "invalid dataset", details: e.errors }, status: :unprocessable_content
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: "invalid dataset", details: e.record.errors.full_messages }, status: :unprocessable_content
    end

    def destroy
      Backtest::DatasetManager.destroy!(@dataset)
      head :no_content
    rescue Backtest::DatasetManager::Conflict => e
      render_error(:conflict, e.message)
    end

    private

    def set_dataset
      @dataset = Backtest::Dataset.find_by(id: params[:id])
      render_error(:not_found, "Dataset not found") unless @dataset
    end

    def dataset_json(dataset)
      {
        id: dataset.id,
        name: dataset.name,
        symbol: dataset.symbol,
        venue: dataset.venue,
        instrument_type: dataset.instrument_type,
        currency: dataset.currency,
        timeframe: dataset.timeframe,
        option_type: dataset.option_type,
        strike_price: dataset.strike_price&.to_f,
        expiry_date: dataset.expiry_date,
        bars_count: dataset.bars_count,
        first_bar_at: dataset.first_bar_at,
        last_bar_at: dataset.last_bar_at,
        fingerprint: dataset.fingerprint,
        created_at: dataset.created_at
      }
    end
  end
end
