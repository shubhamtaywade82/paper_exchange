module Backtest
  # Creates and deletes datasets. Creation validates the bars first and then
  # writes the dataset and its bars in one transaction.
  module DatasetManager
    class Conflict < StandardError; end

    INSERT_BATCH = 1_000

    module_function

    def create!(payload)
      parsed = DatasetValidator.call(payload)

      Dataset.transaction do
        dataset = Dataset.create!(parsed[:attributes])
        parsed[:candles].each_slice(INSERT_BATCH) do |slice|
          DatasetBar.insert_all(
            slice.map do |candle|
              {
                backtest_dataset_id: dataset.id,
                bar_at: candle.bar_at,
                open: candle.open,
                high: candle.high,
                low: candle.low,
                close: candle.close,
                volume: candle.volume
              }
            end
          )
        end
        dataset
      end
    end

    def destroy!(dataset)
      raise Conflict, "dataset #{dataset.id} is used by #{dataset.runs.count} run(s); delete those runs first" if dataset.runs.exists?

      Dataset.transaction do
        dataset.bars.delete_all
        dataset.destroy!
      end
    end
  end
end
