# RM-001: Hard Stop Loss

**Status:** Draft
**Phase:** 1 (Critical — implement first)
**Depends on:** None

---

## 1. Problem

Prism currently opens positions with no stop loss (`SL = 0`). If the market moves sharply against an open position, losses are unbounded until the position is eventually closed by the management logic in `ManagePositions()` — which only exits on profit, not on loss.

**Example — current behaviour:**

| Scenario | Balance | Lot Size (1:100) | Adverse Move | Loss | Remaining |
|----------|---------|-----------------|--------------|------|-----------|
| Normal day | $5,000 | 0.24 lots | 50 pips | $120 | $4,880 |
| Flash crash | $5,000 | 0.24 lots | 300 pips | $720 | $4,280 |
| Black swan | $5,000 | 0.24 lots | 800 pips | $1,920 | $3,080 |
| Black swan (1:500) | $5,000 | 12.1 lots | 100 pips | $12,100 | **MARGIN CALL** |

Without a hard stop, the account's survival depends entirely on the market reversing before the broker's margin call is triggered. At high leverage that window is measured in pips, not hours.

---

## 2. Root Cause

`OpenPosition()` in `prism.mq5` always passes `0` as the stop-loss price:

```mql5
trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lotSize, ask, 0, 0, comment);
//                                                          ^ SL = 0
```

The existing `EnableStop` / `RelativeStop` mechanism in `CheckLongStop()` is basket-level and profit-relative — it only fires once the *entire basket* has a combined loss exceeding a fraction of historical profit. It does not protect individual positions and does not fire at all when `totalHistoryProfit` is near zero.

---

## 3. Proposed Solution

Calculate a stop-loss distance based on the Average True Range (ATR). Set position size so that the monetary loss at the stop equals `MaxRiskPercent × account balance`. This makes per-trade risk consistent regardless of market volatility.

### Parameters

```mql5
input group "════════ RISK: HARD STOP LOSS ════════";
input bool   EnableHardStop    = true;   // Attach stop loss to every opened position
input double ATRStopMultiplier = 2.5;    // Stop distance = ATR × this multiplier
input int    MinStopPips       = 15;     // Minimum stop distance in pips (prevents too-tight stops)
input int    MaxStopPips       = 80;     // Maximum stop distance in pips (caps exposure on low-volatility entries)
input double MaxRiskPercent    = 0.10;   // Maximum loss per position as % of balance (0.10 = 10%)
```

### Behaviour

**On each new position open:**

1. Read current ATR value from `indicators.ATR`.
2. Calculate raw stop distance: `stopDistance = ATR × ATRStopMultiplier`.
3. Clamp: `stopDistance = Clamp(stopDistance, MinStopPips × pipPoints, MaxStopPips × pipPoints)`.
4. Calculate the maximum monetary loss allowed: `maxLoss = accountBalance × MaxRiskPercent`.
5. Back-calculate the safe lot size: `safeLots = maxLoss / (stopDistance / pipPoints × 10)` (assumes standard lot = $10/pip for pairs priced in USD, adjust for cross-pairs).
6. Use `min(calculatedLots, safeLots)` as the final lot size.
7. Derive stop price from entry:
   - BUY: `sl = ask - stopDistance`
   - SELL: `sl = bid + stopDistance`
8. Pass `sl` to `trade.PositionOpen(...)`.

---

## 4. Examples

### Example A — Normal conditions

| Input | Value |
|-------|-------|
| Balance | $5,000 |
| ATR | 0.0012 (12 pips) |
| ATRStopMultiplier | 2.5 |
| MaxRiskPercent | 0.10 |

```
stopDistance = 0.0012 × 2.5 = 0.0030 (30 pips) — within [15, 80] range
maxLoss = $5,000 × 0.10 = $500
safeLots = $500 / (30 × $10) = 1.67 lots
```

If the margin-based formula produced 2.43 lots, the hard stop caps it to 1.67 lots.

### Example B — High volatility (news day)

| Input | Value |
|-------|-------|
| Balance | $5,000 |
| ATR | 0.0045 (45 pips) |
| ATRStopMultiplier | 2.5 |
| MaxRiskPercent | 0.10 |

```
stopDistance = 0.0045 × 2.5 = 0.01125 → clamped to MaxStopPips = 80 pips
maxLoss = $5,000 × 0.10 = $500
safeLots = $500 / (80 × $10) = 0.625 lots
```

High volatility automatically reduces position size — the larger ATR-based stop absorbs more pips so fewer lots are needed to keep dollar risk constant.

### Example C — What happens at the stop

```
BUY at 1.0850, stop at 1.0820 (30 pips), 1.67 lots
If market falls to 1.0820:
  Loss = 30 × $10 × 1.67 = $501 ≈ 10% of $5,000 balance
  Position closes automatically. Account survives.
```

Without the stop, if the market continued to 1.0550 (300 pips):
```
  Loss = 300 × $10 × 2.43 = $7,290 → MARGIN CALL
```

---

## 5. Code Impact

### New functions (in `PrismRiskManager.mqh`)

```mql5
// Returns the stop loss price for a new position
double CalculateHardStop(ENUM_ORDER_TYPE orderType, double entryPrice,
                         double atr, double pipPoints);

// Returns the maximum safe lot size given a stop distance
double GetRiskBasedLotSize(double stopDistancePips, double accountBalance,
                           double pipPoints);
```

### Changes to `prism.mq5`

`OpenPosition()` — replace the two `trade.PositionOpen(...)` calls:

```mql5
// Before
trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lotSize, ask, 0, 0, comment);

// After
double sl = EnableHardStop ? CalculateHardStop(ORDER_TYPE_BUY, ask, indicators.ATR, pipPoints) : 0;
double safeLots = EnableHardStop ? GetRiskBasedLotSize(MathAbs(ask - sl) / pipPoints, accountInfo.Balance(), pipPoints) : lotSize;
double finalLots = MathMin(lotSize, safeLots);
trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, finalLots, ask, sl, 0, comment);
```

Same pattern applies to the SELL branch and to `SendBackup()`.

### Integration point

`OpenPosition()` and `SendBackup()` in `prism.mq5`, immediately before calling `trade.PositionOpen()`.

---

## 6. Modular Design

Controlled by a single `EnableHardStop` input flag.

- **`false`** (disabled): `CalculateHardStop()` returns `0`. `GetRiskBasedLotSize()` returns the unchanged input lots. Behaviour is identical to current code.
- **`true`** (enabled): Stop prices are calculated and attached; lot size may be reduced.

No changes to signal logic, position management, or any other module. The feature is entirely contained within the two new helper functions and the two modified `PositionOpen` call sites.

---

## 7. Open Questions

1. **Cross-pair pip value:** The `$10/pip` assumption holds for USD-quoted pairs (EURUSD, GBPUSD). For JPY pairs or crosses the pip value differs. Should `GetRiskBasedLotSize()` use `SymbolInfoDouble(SYMBOL_TRADE_TICK_VALUE)` to get the accurate pip value per lot?

2. **Backup positions:** Should backup positions also have hard stops, or should they behave differently given they are counter-trend/spike entries by design?

3. **Moving stops:** Should this feature include trailing stop logic, or is that a separate concern (potential RM-012)?

4. **Interaction with `RelativeStop`:** Once hard stops are in place, the existing `EnableStop` / `RelativeStop` basket-level mechanism becomes a secondary safety layer. Should it be kept, deprecated, or documented as complementary?
