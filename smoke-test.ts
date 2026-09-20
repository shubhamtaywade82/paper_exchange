import axios, { type AxiosInstance } from 'axios';
import BigNumber from 'bignumber.js';

// Configure BigNumber to prevent floating-point drift during assertions
BigNumber.config({ DECIMAL_PLACES: 18, ROUNDING_MODE: BigNumber.ROUND_HALF_UP });

const PORT = process.env.PORT || '3001';
const BASE_URL = process.env.API_BASE_URL || `http://localhost:${PORT}/api/v1`;
const ACCOUNT_ID = process.env.ACCOUNT_ID || 'test-account-1';
const SYMBOL = 'BTCUSDT';
const EPSILON = new BigNumber('1e-8'); // Tolerance for DB scale rounding

const http: AxiosInstance = axios.create({
  baseURL: BASE_URL,
  headers: {
    'X-Account-Id': ACCOUNT_ID,
    'Content-Type': 'application/json'
  }
});

function assertEqual(actual: string | number, expected: string | number, message: string) {
  const a = new BigNumber(actual);
  const e = new BigNumber(expected);
  const diff = a.minus(e).abs();

  if (diff.isGreaterThan(EPSILON)) {
    console.error(`\n❌ FAIL: ${message}`);
    console.error(`   Expected: ${e.toFixed(8)}`);
    console.error(`   Actual:   ${a.toFixed(8)}`);
    console.error(`   Diff:     ${diff.toFixed(8)}`);
    process.exit(1);
  } else {
    console.log(`✅ PASS: ${message} (${a.toFixed(4)})`);
  }
}

async function runSmokeTest() {
  console.log('🚀 Starting Paper-Exchange Smoke Test...\n');

  // 1. INITIAL STATE
  console.log('--- Step 1: Initial State ---');
  let account = (await http.get('/account')).data;
  assertEqual(account.wallet.available, '10000.0', 'Initial Available Balance');
  assertEqual(account.wallet.locked, '0.0', 'Initial Locked Margin');

  // 2. PUSH INITIAL MARK PRICE
  console.log('\n--- Step 2: Push Mark Price (60,000) ---');
  await http.post('/mark-prices', { prices: { [SYMBOL]: '60000.0' } });

  // 3. OPEN POSITION (Market Buy 0.1 BTC @ 60,000, 10x Leverage)
  console.log('\n--- Step 3: Open Position (Buy 0.1 BTC) ---');
  // Notional: 6000. Margin: 600. Fee (0.04%): 2.4. Total Deducted: 602.4
  await http.post('/orders', {
    symbol: SYMBOL, side: 'BUY', type: 'MARKET', quantity: '0.1',
    leverage: 10, client_order_id: 'smoke-test-1', execution_price: '60000.0'
  });

  account = (await http.get('/account')).data;
  assertEqual(account.wallet.available, '9397.6', 'Available after Open (10000 - 600 margin - 2.4 fee)');
  assertEqual(account.wallet.locked, '0.0', 'Locked should be 0 after fill');

  const getPositions = async () => {
    const res = (await http.get('/positions')).data;
    return Array.isArray(res) ? res : res.positions;
  };

  let positions = await getPositions();
  let btcPos = positions.find((p: any) => p.symbol === SYMBOL);
  assertEqual(btcPos.quantity, '0.1', 'Position Quantity');
  assertEqual(btcPos.entry_price, '60000.0', 'Position Entry Price');
  assertEqual(btcPos.margin_used, '600.0', 'Position Margin Used');

  // 4. UPDATE MARK PRICE & CHECK uPnL
  console.log('\n--- Step 4: Mark Price Update (61,000) ---');
  await http.post('/mark-prices', { prices: { [SYMBOL]: '61000.0' } });
  account = (await http.get('/account')).data;
  // uPnL = (61000 - 60000) * 0.1 = +100
  assertEqual(account.unrealized_pnl, '100.0', 'Unrealized PnL @ 61k');

  // 5. ADD TO POSITION (Market Buy 0.1 BTC @ 62,000, 10x Leverage)
  console.log('\n--- Step 5: Add to Position (Buy 0.1 BTC @ 62k) ---');
  // Notional: 6200. Margin: 620. Fee: 2.48. Total Deducted: 622.48
  await http.post('/orders', {
    symbol: SYMBOL, side: 'BUY', type: 'MARKET', quantity: '0.1',
    leverage: 10, client_order_id: 'smoke-test-2', execution_price: '62000.0'
  });

  positions = await getPositions();
  btcPos = positions.find((p: any) => p.symbol === SYMBOL);
  // Avg Entry = (6000 + 6200) / 0.2 = 61000
  assertEqual(btcPos.quantity, '0.2', 'Total Quantity after Add');
  assertEqual(btcPos.entry_price, '61000.0', 'Weighted Average Entry Price');
  assertEqual(btcPos.margin_used, '1220.0', 'Total Margin Used (600 + 620)');

  account = (await http.get('/account')).data;
  assertEqual(account.wallet.available, '8775.12', 'Available after Add (9397.6 - 622.48)');

  // 6. REDUCE POSITION (Market Sell 0.15 BTC @ 63,000)
  console.log('\n--- Step 6: Reduce Position (Sell 0.15 BTC @ 63k) ---');
  // Notional: 9450. Fee: 3.78. 
  // Realized PnL = (63000 - 61000) * 0.15 = +300
  // Margin Released = (1220 / 0.2) * 0.15 = 915
  // Net Available Change = +915 (margin) + 300 (PnL) - 3.78 (fee) = +1211.22
  await http.post('/orders', {
    symbol: SYMBOL, side: 'SELL', type: 'MARKET', quantity: '0.15',
    leverage: 10, client_order_id: 'smoke-test-3', execution_price: '63000.0'
  });

  positions = await getPositions();
  btcPos = positions.find((p: any) => p.symbol === SYMBOL);
  assertEqual(btcPos.quantity, '0.05', 'Remaining Quantity after Reduce');
  assertEqual(btcPos.margin_used, '305.0', 'Remaining Margin Used (1220 - 915)');

  account = (await http.get('/account')).data;
  assertEqual(account.wallet.available, '9986.34', 'Available after Reduce (8775.12 + 1211.22)');
  assertEqual(account.realized_pnl, '300.0', 'Realized PnL accumulated');

  // 7. FUNDING RATE EVENT
  console.log('\n--- Step 7: Funding Rate Event (0.01% @ 63k) ---');
  // Notional: 0.05 * 63000 = 3150. Funding Fee = 3150 * 0.0001 = 0.315
  // funding_time is the idempotency key — agent retries don't double-charge.
  await http.post('/funding_events?sync=true', {
    symbol: SYMBOL, funding_rate: '0.0001', mark_price: '63000.0',
    funding_time: '2026-09-20T08:00:00Z'
  });

  account = (await http.get('/account')).data;
  assertEqual(account.wallet.available, '9986.025', 'Available after Funding Fee Deduction');

  // 8. LEDGER RECONCILIATION CHECK
  console.log('\n--- Step 8: Ledger & Cash Invariant Check ---');
  // Total Cash = Available + Locked + Position Margin
  const totalCash = new BigNumber(account.wallet.available)
    .plus(account.wallet.locked)
    .plus(btcPos.margin_used);

  // Expected Total Cash = Initial (10000) + Realized PnL (300) - Fees (2.4 + 2.48 + 3.78 + 0.315)
  // Expected Total Cash = 10300 - 8.975 = 10291.025
  assertEqual(totalCash.toFixed(8), '10291.025', 'Total Wallet Cash Invariant (Initial + PnL - Fees)');

  console.log('\n🎉 ALL SMOKE TESTS PASSED! The broker accounting engine is mathematically correct.');
}

runSmokeTest().catch(err => {
  console.error('🔥 Smoke test crashed:', err.response?.data || err.message);
  process.exit(1);
});
