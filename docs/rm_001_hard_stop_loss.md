# RM-001: Position Loss Protection (Soft Stop)

**Status:** Draft (reframed)
**Phase:** 1 (Critical — implement first)
**Depends on:** RM-002 (lot size cap already implemented)
**See also:** RM-013 (partial close / money management — separate concern)

---

## 1. Problem

Prism opens every position with `SL = 0`. The existing `longStop()` only fires at the basket level once accumulated losses exceed a fraction of historical profit — it does not protect individual positions and does not fire at all when `_totalHistoryProfit` is near zero (fresh account).

`managePositions()` exits positions on profit only. There is no per-position loss exit.

**Current layered protection (as-built):**

| Layer | Mechanism | Scope | Fires when |
|-------|-----------|-------|------------|
| RM-002 | Lot size cap | Per position + basket | Caps exposure at open time |
| `longStop()` | `EnableStop / RelativeStop` | Entire basket | Loss > fraction of history profit |
| `managePositions()` | `OpenProfit / BasketProfit` | Entire basket | Basket is profitable |
| None | — | Per position, adverse move | ← **gap** |

The gap: a single position can accumulate an unbounded individual loss while the basket logic waits for the *combined* picture to deteriorate far enough.

---

## 2. Why Not a Broker-Side Hard Stop Loss

The original draft proposed attaching a stop loss price to each `PositionOpen()` call. That approach has a significant drawback: **stop hunting**.

Many retail forex brokers can see every client's pending stop order. A cluster of stop orders just below a round number or a swing low is a known liquidity pool. Brokers and institutional players regularly spike price through these levels to trigger stops before reversing. A visible hard stop at `ask - 2.5 × ATR` is a literal instruction to the broker about where to push price to close your position. A deliberate spike only needs to touch the level for one tick.

**Alternative: soft stop.** Instead of attaching a stop price to the broker, the EA monitors each position's floating loss every tick inside `managePositions()` and calls `PositionClose()` when the threshold is breached. The broker never sees a stop order. The logical protection is identical; the execution on a fast market is at the next available tick price rather than an exact level, but this is a worthwhile trade-off at the lot sizes Prism typically trades.

---

## 3. Trade Type Identification

Normal and backup trades need different protection thresholds. Normal trades are signal-based and should be cut if the signal is invalidated. Backup trades are intentionally counter-trend and need room to breathe — a tight per-position stop would defeat their purpose.

**Approach: dual magic numbers.**

A second magic number is assigned to all backup trade opens:

```mql5
int _MAGIC        = 20260220;   // regular trades
int _MAGIC_BACKUP = 20260221;   // backup trades
```

`_trade.SetExpertMagicNumber()` is called with the appropriate value before each `PositionOpen()`. At management time, `_positionInfo.Magic()` is an instant integer comparison with no string parsing overhead.

**Benefits:**
- Integer check in the hot path (every tick in `managePositions()`)
- MT5 history queries filter by magic natively — regular and backup trades have separate history profit reporting
- Visible distinction in broker statements and trading journals
- Removes the existing `StringFind("Backup")` string search from `AnalyzePositions()`

**Refactoring required:** `AnalyzePositions()`, `CalculateHistoricalProfit()`, `closeAll()`, and `managePositions()` all currently filter on `_MAGIC` alone and must be updated to accept both magic numbers. The trade comments (`"Min"` / `"Backup"` label) are kept as-is for human readability in the journal — they are no longer used for programmatic type detection.

---

## 4. Two Threshold Modes

The soft stop can be expressed in either of two ways, controlled by a single toggle:

### Mode 1: Balance-percentage threshold

```
Regular stop: close if position.Profit() < -MaxRiskPercent × accountBalance
Backup stop:  close if position.Profit() < -BackupMaxRiskPercent × accountBalance
```

**Characteristics:**
- No per-trade state required — the threshold is computed fresh each tick
- Consistent dollar risk regardless of when the trade was opened
- Does not account for prevailing market volatility — a quiet-market entry and a news-event entry get the same dollar threshold

**When to use:** Simplest to implement and validate. Good starting point.

### Mode 2: ATR-based price level threshold

```
Regular stop: close if bid < entryPrice - ATR_at_open × ATRStopMultiplier  (BUY)
              close if ask > entryPrice + ATR_at_open × ATRStopMultiplier  (SELL)
Backup stop:  same logic, larger multiplier (BackupATRStopMultiplier)
```

**Characteristics:**
- Stop distance is proportional to volatility at the time of entry — a wide-range day gives more room; a compressed range day is tighter
- Requires the ATR value at open time to be stored and retrievable at management time
- The stop price is fixed for the life of the trade (not recalculated as ATR changes)

**When to use:** More precise protection. Better calibrated to the market regime at entry.

**Storage problem:** The EA's in-memory variables are lost on restart. The ATR at open time cannot be recovered from MT5's position API — it only exposes entry price, lots, type, profit, and comment. Three options for solving this:

1. **Encode in comment** — append ATR to the comment string at open time: `"Prism 0.1 SignalA Min 1|ATR=0.00120"`. Parse it back with `StringSubstr()` / `StringSplit()` at management time. Fragile if comment format changes. Comment truncation risk.

2. **Use current ATR as proxy** — check the stop against `_indicators.ATR` (current value) rather than the ATR at open. Acceptable if the EA's timeframe ATR doesn't swing dramatically between a trade open and the stop check. Not precise but avoids any storage concern.

3. **Chart object as per-trade data store** *(explored below)*

---

## 5. Chart Object as Per-Trade Data Store

This is a novel approach worth detailing. MT5 chart objects have two relevant properties that make them viable as lightweight per-trade storage:

1. **They persist across EA restarts.** Chart objects are stored with the chart profile, not in EA memory. If the EA is stopped and restarted, `ObjectFind()` can immediately re-read all previously created objects and the stop logic resumes without any re-initialisation.

2. **They are named.** An object name up to 63 characters long can encode any identifier. Using the position ticket gives a unique, stable, instantly queryable key: `"PrismSL_" + IntegerToString(ticket)`.

### How it works

**At trade open** — immediately after `_trade.PositionOpen()` succeeds:
```mql5
ulong ticket   = _trade.ResultOrder();
double stopPrice = (orderType == ORDER_TYPE_BUY)
                 ? ask - _indicators.ATR * ATRStopMultiplier
                 : bid + _indicators.ATR * ATRStopMultiplier;
string objName = "PrismSL_" + IntegerToString(ticket);

ObjectCreate(0, objName, OBJ_HLINE, 0, 0, stopPrice);
ObjectSetInteger(0, objName, OBJPROP_COLOR,  clrCrimson);
ObjectSetInteger(0, objName, OBJPROP_STYLE,  STYLE_DASH);
ObjectSetInteger(0, objName, OBJPROP_WIDTH,  1);
ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);  // visible on chart — shows soft stop level
// Store ATR in description for diagnostics
ObjectSetString(0, objName, OBJPROP_TEXT,
                StringFormat("ATR=%.5f|%s", _indicators.ATR, isBackup ? "B" : "R"));
```

**At management time** — inside the per-position loop in `managePositions()`:
```mql5
string objName = "PrismSL_" + IntegerToString(_positionInfo.Ticket());
if(ObjectFind(0, objName) >= 0)
{
   double stopPrice = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
   bool breached = (_positionInfo.PositionType() == POSITION_TYPE_BUY  && bid <= stopPrice) ||
                   (_positionInfo.PositionType() == POSITION_TYPE_SELL && ask >= stopPrice);
   if(EnableSoftStop && breached)
   {
      // close position, delete object
   }
}
```

**At position close** — delete the object:
```mql5
ObjectDelete(0, "PrismSL_" + IntegerToString(ticket));
```

**On EA deinit** — sweep and delete all remaining soft stop objects:
```mql5
for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
{
   if(StringFind(ObjectName(0, i), "PrismSL_", 0) == 0)
      ObjectDelete(0, ObjectName(0, i));
}
```

### Visual benefit

When `OBJPROP_HIDDEN = false`, each open position has a visible dashed red horizontal line on the chart showing exactly where its soft stop is. This is a useful diagnostic during live trading. Setting it to `true` suppresses the lines if visual clutter is a concern.

### Limitations

- **Chart-specific:** Objects live on the chart where the EA runs (chart ID 0 = current). This is fine since the EA only trades that symbol.
- **Strategy Tester:** In non-visual mode, `ObjectCreate()` and `ObjectGetDouble()` still function correctly — chart objects are usable in the tester even without the visual display.
- **Backup thresholds:** The object stores a single price level. For backup trades (which need a wider stop), the price is simply calculated with `BackupATRStopMultiplier` at open time and stored the same way — the management code reads the object price without needing to know which multiplier was used.

### Recommendation

The chart object approach cleanly solves the ATR storage problem and provides a visible chart indicator as a bonus. It is the preferred mechanism if Mode 2 (ATR-based threshold) is adopted. If Mode 1 (balance-percentage) is used, chart objects are not needed and the entire stop check is stateless.

---

## 6. Parameters

```mql5
input group "════════ RISK: POSITION LOSS PROTECTION ════════";
input bool   EnableSoftStop            = true;   // Dynamically close positions exceeding loss threshold
input bool   UseATRStop                = true;   // true = ATR price-level stop, false = balance-% stop
// ATR mode parameters
input double ATRStopMultiplier         = 2.5;    // Regular stop: entry ± ATR × this value
input double BackupATRStopMultiplier   = 4.0;    // Backup stop: wider multiplier for counter-trend trades
// Percentage mode parameters
input double MaxRiskPercent            = 0.02;   // Max loss per regular position as % of balance (2%)
input double BackupMaxRiskPercent      = 0.05;   // Max loss per backup position as % of balance (5%)
```

Only the ATR-mode or percentage-mode parameters are active at any time, depending on `UseATRStop`.

---

## 7. Interaction with Existing Mechanisms

Once the soft stop is in place, the full protection stack becomes:

| Order | Mechanism | Scope | Description |
|-------|-----------|-------|-------------|
| 1 | RM-002 lot cap | Per position + basket | Limits exposure at open time |
| 2 | Soft stop (this feature) | Per position | Closes individual losers before they damage the basket |
| 3 | `longStop()` | Entire basket | Final safety net: wipes basket if cumulative loss vs history is too large |
| 4 | `SafeExits` / `OpenProfit` | Entire basket | Exits basket on profit conditions or trend reversal |

`longStop()` and the soft stop serve different purposes and should both remain active. The soft stop removes individual losers early; `longStop()` handles the case where multiple positions are simultaneously losing (correlated adverse move) faster than tick-by-tick soft stop checks can respond.

**`longStop()` on fresh accounts:** The existing mechanism only activates when `_totalHistoryProfit > StopGrowth × balance`. On a fresh account this never fires. The soft stop fills this gap entirely and makes `longStop()` a secondary rather than primary safety net.

---

## 8. Code Impact

### Changes to `prism.mq5`

#### Dual magic numbers
```mql5
// Alongside existing _MAGIC:
int _MAGIC_BACKUP = 20260221;

// In sendBack() — set backup magic before each PositionOpen(), restore after:
_trade.SetExpertMagicNumber(_MAGIC_BACKUP);
_trade.PositionOpen(...);
_trade.SetExpertMagicNumber(_MAGIC);

// In closeAll(), managePositions(), AnalyzePositions() — update position filter:
// From: positionInfo.Magic() == _MAGIC
// To:   positionInfo.Magic() == _MAGIC || positionInfo.Magic() == _MAGIC_BACKUP
```

#### Chart object cleanup in `OnDeinit()`
```mql5
for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
{
   if(StringFind(ObjectName(0, i), "PrismSL_", 0) == 0)
      ObjectDelete(0, ObjectName(0, i));
}
```

### New / modified functions in `PrismRiskManager.mqh`

```mql5
// Create a soft stop chart object for a newly opened position.
// Call immediately after a successful PositionOpen().
// ticket     — _trade.ResultOrder()
// orderType  — ORDER_TYPE_BUY or ORDER_TYPE_SELL
// entryPrice — ask (BUY) or bid (SELL)
// atr        — _indicators.ATR at open time
// isBackup   — true if opened via sendBack()
void CreateSoftStopObject(ulong ticket, ENUM_ORDER_TYPE orderType, double entryPrice,
                          double atr, bool isBackup,
                          double atrMultiplier, double backupAtrMultiplier);

// Check whether the soft stop for a position has been breached.
// Returns true if the position should be closed.
// For ATR mode: reads the stop price from the chart object.
// For % mode: computes threshold from profit and balance.
bool SoftStopBreached(ulong ticket, ENUM_POSITION_TYPE posType,
                      double bid, double ask,
                      double profit, double accountBalance,
                      bool useATRStop,
                      double maxRiskPercent, double backupMaxRiskPercent,
                      bool isBackup);

// Delete the chart object for a closed position.
void DeleteSoftStopObject(ulong ticket);
```

### Changes to `managePositions()` — inside the per-position loop
```mql5
if(EnableSoftStop)
{
   bool isBackup = (_positionInfo.Magic() == _MAGIC_BACKUP);
   if(SoftStopBreached(_positionInfo.Ticket(), _positionInfo.PositionType(),
                       bid, ask, _positionInfo.Profit(), _accountInfo.Balance(),
                       UseATRStop, MaxRiskPercent, BackupMaxRiskPercent, isBackup))
   {
      Print("Soft stop: closing ", _positionInfo.Ticket(),
            " loss=", _positionInfo.Profit());
      if(_trade.PositionClose(_positionInfo.Ticket()))
      {
         DeleteSoftStopObject(_positionInfo.Ticket());
         _dailyGrowth += _positionInfo.Profit();
         _lastTradeTime = TimeCurrent();
      }
   }
}
```

---

## 9. Open Questions

1. **Mode selection for live trading:** `UseATRStop = true` is the more principled choice but adds chart object overhead. Starting with `UseATRStop = false` (percentage mode) in early backtests will validate the close-on-loss mechanism before adding the chart object layer.

2. **Dual magic numbers refactor scope:** `AnalyzePositions()`, `CalculateHistoricalProfit()`, `closeAll()`, and `managePositions()` all need updating to accept both magic numbers. The refactor is mechanical but should be done carefully to avoid a subtle counting bug similar to the `basketNumberType` issue documented in `toto_bugs.md`.

3. **Backtesting validation of defaults:** `MaxRiskPercent = 0.02` (2%) and `ATRStopMultiplier = 2.5` should both be validated against backtest results. Too tight and the soft stop fires on normal pullbacks; too loose and it adds little protection over the existing basket mechanisms.

4. **Soft stop object and partial close interaction:** If RM-013 (partial close) is later implemented, the chart object approach could be extended to track the reduced lot size after a partial close, so the soft stop continues to apply correctly to the remaining position.
