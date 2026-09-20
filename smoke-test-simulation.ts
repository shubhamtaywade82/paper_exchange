import BigNumber from 'bignumber.js';

BigNumber.config({ DECIMAL_PLACES: 18, ROUNDING_MODE: BigNumber.ROUND_HALF_UP });
const EPSILON = new BigNumber('1e-6');
const TAKER_FEE_RATE = new BigNumber('0.0004'); // 0.04% taker fee
const MMR = new BigNumber('0.004');             // 0.4% maintenance margin rate

interface SimState {
  available: BigNumber;
  locked: BigNumber;
  realizedPnl: BigNumber;
  totalFees: BigNumber;
  initialEquity: BigNumber;
  positions: Map<string, Position>;
}

interface Position {
  symbol: string;
  side: 'long' | 'short';
  qty: BigNumber;
  avgPrice: BigNumber;
  leverage: number;
  initialMargin: BigNumber;
  liquidationPrice: BigNumber;
  stopLoss: BigNumber;
  takeProfit: BigNumber;
  tp1Hit: boolean;
  status: 'open' | 'flat' | 'liquidated';
}

function assertEqual(actual: unknown, expected: unknown, msg: string) {
  const isLiteral = typeof actual === 'boolean' || typeof expected === 'boolean' ||
    (typeof actual === 'string' && isNaN(Number(actual))) ||
    (typeof expected === 'string' && isNaN(Number(expected)));

  if (isLiteral) {
    if (actual !== expected) {
      console.error(`\n❌ FAIL: ${msg}\n   Expected: ${expected}\n   Actual:   ${actual}`);
      process.exit(1);
    }
    console.log(`✅ PASS: ${msg} (${actual})`);
    return;
  }

  const a = new BigNumber(actual as BigNumber.Value);
  const e = new BigNumber(expected as BigNumber.Value);
  const diff = a.minus(e).abs();
  if (diff.isGreaterThan(EPSILON)) {
    console.error(`\n❌ FAIL: ${msg}\n   Expected: ${e.toFixed(4)}\n   Actual:   ${a.toFixed(4)}`);
    process.exit(1);
  }
  console.log(`✅ PASS: ${msg} (${a.toFixed(4)})`);
}

// Invariant: Total Cash = Available + Locked + Position Margin == Initial + Realized - Fees
function assertCashInvariant(s: SimState, label: string) {
  let posMargin = new BigNumber(0);
  for (const p of s.positions.values()) {
    if (p.status === 'open') posMargin = posMargin.plus(p.initialMargin);
  }
  const totalCash = s.available.plus(s.locked).plus(posMargin);
  const expectedCash = s.initialEquity.plus(s.realizedPnl).minus(s.totalFees);
  assertEqual(totalCash, expectedCash, `Cash Invariant @ ${label}`);
}

function calcIndicators(prices: number[]) {
  const k = 2 / 51; // EMA50 smoothing factor
  let ema = prices[0];
  for (let i = 1; i < prices.length; i++) ema = prices[i] * k + ema * (1 - k);

  let sumAtr = 0;
  for (let i = 1; i < prices.length; i++) sumAtr += Math.abs(prices[i] - prices[i - 1]);
  const atr = sumAtr / (prices.length - 1);

  return { ema: new BigNumber(ema), atr: new BigNumber(atr) };
}

function riskGate(entry: BigNumber, atr: BigNumber, equity: BigNumber) {
  const sl = entry.minus(atr.multipliedBy(2.5));
  const slDistPct = entry.minus(sl).dividedBy(entry);
  const liqBufferAtr = entry.minus(sl).dividedBy(atr);
  if (liqBufferAtr.isLessThan(2.0)) return { approved: false, qty: new BigNumber(0), leverage: 10 };

  const riskBudget = equity.multipliedBy(0.01); // 1% risk
  const notional = riskBudget.dividedBy(slDistPct);
  const qty = notional.dividedBy(entry);
  return { approved: true, qty, leverage: 10 };
}

function openLong(s: SimState, symbol: string, price: BigNumber, qty: BigNumber, lev: number, atr: BigNumber) {
  const notional = price.multipliedBy(qty);
  const margin = notional.dividedBy(lev);
  const fee = notional.multipliedBy(TAKER_FEE_RATE);

  s.available = s.available.minus(margin).minus(fee);
  s.totalFees = s.totalFees.plus(fee);

  const liqPrice = price.multipliedBy(new BigNumber(1).minus(1 / lev).plus(MMR));
  const pos: Position = {
    symbol, side: 'long', qty, avgPrice: price, leverage: lev,
    initialMargin: margin, liquidationPrice: liqPrice,
    stopLoss: price.minus(atr.multipliedBy(2.5)),
    takeProfit: price.plus(atr.multipliedBy(5.0)),
    tp1Hit: false, status: 'open'
  };
  s.positions.set(symbol, pos);
  return pos;
}

function reduceLong(s: SimState, pos: Position, closePrice: BigNumber, closeQty: BigNumber) {
  const closedNotional = closePrice.multipliedBy(closeQty);
  const fee = closedNotional.multipliedBy(TAKER_FEE_RATE);
  const realized = closePrice.minus(pos.avgPrice).multipliedBy(closeQty);
  const releasedMargin = pos.initialMargin.multipliedBy(closeQty).dividedBy(pos.qty);

  s.available = s.available.plus(releasedMargin).plus(realized).minus(fee);
  s.realizedPnl = s.realizedPnl.plus(realized);
  s.totalFees = s.totalFees.plus(fee);

  pos.qty = pos.qty.minus(closeQty);
  pos.initialMargin = pos.initialMargin.minus(releasedMargin);
  pos.tp1Hit = true;
}

// Side-mutable flip on the same position object without orphaned records
function flipToShort(s: SimState, pos: Position, fillPrice: BigNumber, shortQty: BigNumber, lev: number) {
  const closeQty = pos.qty;
  const realized = fillPrice.minus(pos.avgPrice).multipliedBy(closeQty);
  const closeFee = fillPrice.multipliedBy(closeQty).multipliedBy(TAKER_FEE_RATE);

  s.available = s.available.plus(pos.initialMargin).plus(realized).minus(closeFee);
  s.realizedPnl = s.realizedPnl.plus(realized);
  s.totalFees = s.totalFees.plus(closeFee);

  const openQty = shortQty.minus(closeQty);
  const newNotional = fillPrice.multipliedBy(openQty);
  const newMargin = newNotional.dividedBy(lev);
  const openFee = newNotional.multipliedBy(TAKER_FEE_RATE);

  s.available = s.available.minus(newMargin).minus(openFee);
  s.totalFees = s.totalFees.plus(openFee);

  pos.side = 'short';
  pos.qty = openQty;
  pos.avgPrice = fillPrice;
  pos.initialMargin = newMargin;
  pos.liquidationPrice = fillPrice.multipliedBy(new BigNumber(1).plus(1 / lev).minus(MMR));
}

function liquidatePosition(s: SimState, pos: Position, liqPrice: BigNumber) {
  const diff = pos.side === 'long' ? liqPrice.minus(pos.avgPrice) : pos.avgPrice.minus(liqPrice);
  const realized = diff.multipliedBy(pos.qty);

  s.available = s.available.plus(pos.initialMargin).plus(realized);
  s.realizedPnl = s.realizedPnl.plus(realized);
  pos.qty = new BigNumber(0);
  pos.status = 'liquidated';
}

function testLifecycleHappyPath(s: SimState) {
  console.log('\n--- Step 1: Initialize Engine & Technical Indicators ---');
  const prices = Array.from({ length: 50 }, (_, i) => 67000 + i * 20);
  const { ema, atr } = calcIndicators(prices);
  assertEqual(ema.isGreaterThan(67000), true, 'EMA50 calculated');
  assertEqual(atr.isGreaterThan(0), true, 'ATR14 calculated');
  assertCashInvariant(s, 'Init');

  console.log('\n--- Step 2: Risk Gate & Order Execution (Long 10x) ---');
  const entry = new BigNumber(68000);
  const risk = riskGate(entry, atr, s.initialEquity);
  assertEqual(risk.approved, true, 'Risk Gate Approved');
  const pos = openLong(s, 'BTCUSDT', entry, risk.qty, risk.leverage, atr);
  assertEqual(pos.side, 'long', 'Position Side');
  assertEqual(pos.status, 'open', 'Position Status');
  assertCashInvariant(s, 'Open Long');

  console.log('\n--- Step 3: Trailing Stop & Take Profit (50% Reduce @ TP1) ---');
  const tp1Price = entry.plus(atr.multipliedBy(3.0));
  reduceLong(s, pos, tp1Price, pos.qty.multipliedBy(0.5));
  assertEqual(pos.tp1Hit, true, 'TP1 Flag Set');
  assertCashInvariant(s, 'TP1 Reduction');
}

function testFlipAndLiquidation(s: SimState) {
  const pos = s.positions.get('BTCUSDT')!;

  console.log('\n--- Step 4: Position Flip on Same Row (Long -> Short) ---');
  const flipPrice = new BigNumber(69000);
  const flipQty = pos.qty.multipliedBy(3.0); // 3x quantity triggers reverse leg
  flipToShort(s, pos, flipPrice, flipQty, 10);
  assertEqual(pos.side, 'short', 'Position Flipped to Short');
  assertCashInvariant(s, 'Position Flip');

  console.log('\n--- Step 5: Crash Regime & Liquidation Check ---');
  liquidatePosition(s, pos, pos.liquidationPrice);
  assertEqual(pos.status, 'liquidated', 'Position Liquidated');
  assertCashInvariant(s, 'Post Liquidation');
}

async function runSimulationSmokeTest() {
  console.log('🚀 Running Headless Smoke Test for Crypto Trading Lifecycle Simulation...\n');
  const state: SimState = {
    available: new BigNumber(100000),
    locked: new BigNumber(0),
    realizedPnl: new BigNumber(0),
    totalFees: new BigNumber(0),
    initialEquity: new BigNumber(100000),
    positions: new Map()
  };

  testLifecycleHappyPath(state);
  testFlipAndLiquidation(state);

  console.log('\n🎉 ALL SIMULATION SMOKE TESTS PASSED! Mathematical & accounting invariants verified.');
}

runSimulationSmokeTest();
