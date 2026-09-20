require 'rails_helper'

RSpec.describe Exchange::MarginEngine, type: :service do
  let(:account) { create(:account, account_id: 'ACC-MARGIN-ENGINE', margin: 100_000.0) }

  describe '.sync_position!' do
    it 'locks the position notional / leverage as initial margin and computes a liquidation price' do
      position = create(:paper_position,
        account_id: account.account_id,
        symbol: 'BTCUSDT',
        side: :long,
        quantity: 1,
        avg_price: 60_000.0,
        current_price: 60_000.0,
        leverage: 10,
        margin_type: 'cross')

      described_class.sync_position!(position, account_id: account.account_id)
      position.reload
      account.reload

      expect(position.initial_margin).to eq(6_000.0) # 60_000 notional / 10x
      expect(position.liquidation_price).to be < position.avg_price
      expect(account.locked_margin).to eq(6_000.0)
      expect(account.available_balance).to eq(94_000.0)
    end

    it 'unlocks the delta when the position shrinks' do
      position = create(:paper_position,
        account_id: account.account_id,
        symbol: 'BTCUSDT',
        side: :long,
        quantity: 2,
        avg_price: 60_000.0,
        current_price: 60_000.0,
        leverage: 10)
      described_class.sync_position!(position, account_id: account.account_id) # locks 12_000

      position.update!(quantity: 1)
      described_class.sync_position!(position, account_id: account.account_id)
      account.reload

      expect(account.locked_margin).to eq(6_000.0)
    end

    it 'releases all margin and clears the liquidation price once the position is flat' do
      position = create(:paper_position,
        account_id: account.account_id,
        symbol: 'BTCUSDT',
        side: :long,
        quantity: 1,
        avg_price: 60_000.0,
        current_price: 60_000.0,
        leverage: 10)
      described_class.sync_position!(position, account_id: account.account_id)

      position.update!(quantity: 0)
      described_class.sync_position!(position, account_id: account.account_id)
      position.reload
      account.reload

      expect(position.initial_margin).to eq(0.0)
      expect(position.liquidation_price).to be_nil
      expect(account.locked_margin).to eq(0.0)
      expect(account.available_balance).to eq(100_000.0)
    end

    it 'leaves initial_margin at zero for unleveraged positions' do
      position = create(:paper_position,
        account_id: account.account_id,
        symbol: 'RELIANCE',
        side: :long,
        quantity: 10,
        avg_price: 2_500.0,
        current_price: 2_500.0,
        leverage: 1)

      described_class.sync_position!(position, account_id: account.account_id)
      position.reload

      expect(position.initial_margin).to eq(0.0)
      expect(position.liquidation_price).to be_nil
    end
  end
end
