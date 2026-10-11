require 'rails_helper'

# Architecture alignment (target architecture §5): PositionProtection specs.
# Durable SL/TP/trailing-stop policies that survive process restarts and
# continue to function when the trading bot is offline.
RSpec.describe PositionProtection, type: :model do
  let(:account) { create(:account, account_id: 'ACC-PROT') }
  let(:position) do
    create(:paper_position,
      account_id: account.account_id,
      symbol: 'BTCUSDT',
      side: :long,
      quantity: 1,
      avg_price: 60_000.0,
      current_price: 60_000.0,
      leverage: 10)
  end

  describe 'validations' do
    it 'is valid with a stop_loss and trigger_price' do
      protection = described_class.new(
        paper_position: position,
        account_id: account.account_id,
        venue: 'paper',
        instrument_id: 'BTCUSDT',
        protection_type: 'stop_loss',
        trigger_price: 54_000.0,
        quantity: 1
      )
      expect(protection).to be_valid
    end

    it 'is invalid without a trigger_price for stop_loss' do
      protection = described_class.new(
        paper_position: position,
        account_id: account.account_id,
        venue: 'paper', instrument_id: 'BTCUSDT',
        protection_type: 'stop_loss', quantity: 1
      )
      expect(protection).not_to be_valid
      expect(protection.errors[:trigger_price]).to include('is required for stop_loss')
    end

    it 'is invalid without trailing_distance for trailing_stop' do
      protection = described_class.new(
        paper_position: position,
        account_id: account.account_id,
        venue: 'paper', instrument_id: 'BTCUSDT',
        protection_type: 'trailing_stop', quantity: 1
      )
      expect(protection).not_to be_valid
      expect(protection.errors[:trailing_distance]).to include('is required for trailing_stop')
    end
  end

  describe '#breached?' do
    it 'triggers a long stop_loss when price falls below trigger' do
      protection = described_class.create!(
        paper_position: position,
        account_id: account.account_id,
        venue: 'paper', instrument_id: 'BTCUSDT',
        protection_type: 'stop_loss', trigger_price: 54_000.0, quantity: 1
      )
      expect(protection.breached?(53_000.0)).to be true
      expect(protection.breached?(55_000.0)).to be false
    end

    it 'triggers a long take_profit when price rises above trigger' do
      protection = described_class.create!(
        paper_position: position,
        account_id: account.account_id,
        venue: 'paper', instrument_id: 'BTCUSDT',
        protection_type: 'take_profit', trigger_price: 66_000.0, quantity: 1
      )
      expect(protection.breached?(67_000.0)).to be true
      expect(protection.breached?(65_000.0)).to be false
    end
  end

  describe '#update_water_mark!' do
    it 'updates the trailing stop trigger as the price moves favorably' do
      protection = described_class.create!(
        paper_position: position,
        account_id: account.account_id,
        venue: 'paper', instrument_id: 'BTCUSDT',
        protection_type: 'trailing_stop',
        trailing_distance: 2_000.0, quantity: 1
      )

      # Price moves up to 65k → HWM = 65k, trigger = 63k
      protection.update_water_mark!(65_000.0)
      expect(protection.high_water_mark.to_f).to eq(65_000.0)
      expect(protection.trigger_price.to_f).to eq(63_000.0)

      # Price drops to 62k → HWM stays 65k, trigger stays 63k
      protection.update_water_mark!(62_000.0)
      expect(protection.high_water_mark.to_f).to eq(65_000.0)
      expect(protection.trigger_price.to_f).to eq(63_000.0)
      expect(protection.breached?(62_000.0)).to be true
    end
  end

  describe '#trigger! with OCO' do
    it 'cancels OCO siblings when one protection triggers' do
      oco_id = 'oco-123'
      sl = described_class.create!(
        paper_position: position,
        account_id: account.account_id,
        venue: 'paper', instrument_id: 'BTCUSDT',
        protection_type: 'stop_loss', trigger_price: 54_000.0,
        quantity: 1, oco_group_id: oco_id
      )
      tp = described_class.create!(
        paper_position: position,
        account_id: account.account_id,
        venue: 'paper', instrument_id: 'BTCUSDT',
        protection_type: 'take_profit', trigger_price: 66_000.0,
        quantity: 1, oco_group_id: oco_id
      )

      tp.trigger!

      expect(tp.reload.status).to eq('triggered')
      expect(sl.reload.status).to eq('cancelled')
    end
  end
end
