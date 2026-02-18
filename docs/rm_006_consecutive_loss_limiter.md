# RM-006: Consecutive Loss Limiter

**Status:** Draft
**Phase:** 2
**Depends on:** None (complements rm_005)

---

## 1. Problem

When the strategy's signals stop working — due to a changed market regime, a broken indicator, or parameter drift — the EA continues trading without any recognition of the pattern. A run of 5–10 consecutive losing trades is a strong signal that something is wrong, but the EA responds by opening more positions.

Consecutive losses are distinct from the drawdown circuit breaker (rm_005):
- **Drawdown circuit breaker** triggers on cumulative equity loss from a peak.
- **Consecutive loss limiter** triggers on a *streak* of losing trades regardless of size.

A trader making ten 0.5% losses in a row (5% total) would not trigger a 25% drawdown circuit breaker. But ten consecutive losses strongly suggests the strategy is misfiring — warranting a pause to reassess.

**Example:**

```
Trade 1: -$50  (loss 1)
Trade 2: -$45  (loss 2)
Trade 3: -$55  (loss 3) → MaxConsecutiveLosses = 3 → PAUSE
Trades 4–8: Would have occurred but don't → saves ~$225 in continued losses
Market regime shifts → resume after 6 hours → strategy works again
```

---

## 2. Root Cause

The EA has no mechanism to detect or count consecutive closed losses. Closed trade history is read in `CalculateHistoricalProfit()` for basket calculations only — individual trade results are not tracked for pattern detection.

---

## 3. Proposed Solution

Maintain a counter of consecutive losing closed trades. When the counter reaches `MaxConsecutiveLosses`, pause all new trade opening for `ConsecutiveLossPauseHours`. Reset the counter to zero on any winning trade. Resume automatically after the pause expires.

### Parameters

```mql5
input group "════════ RISK: CONSECUTIVE LOSS LIMITER ════════";
input bool   EnableConsecutiveLossLimit    = true;   // Pause trading after N consecutive losses
input int    MaxConsecutiveLosses          = 3;      // Number of losses in a row that triggers a pause
input int    ConsecutiveLossPauseHours     = 6;      // Hours to pause trading after trigger
input double MinLossToCount               = 0.005;  // Minimum loss as % of balance to count as a loss
                                                     // (filters out near-breakeven exits)
```

### Behaviour

**After every closed position** (detected by polling deal history in `PrepareAll()` or via `OnTradeTransaction()`):

1. Retrieve the most recently closed deal for this symbol and magic number.
2. Calculate the loss as a percentage of account balance.
3. If `profit < -(balance × MinLossToCount)`: increment `g_consecutive_losses`.
4. If `profit > 0`: reset `g_consecutive_losses = 0`.
5. If `g_consecutive_losses >= MaxConsecutiveLosses`:
   - Set `g_consecutive_loss_pause_until = TimeCurrent() + ConsecutiveLossPauseHours × 3600`
   - Reset `g_consecutive_losses = 0` (prevent re-triggering on next check)
   - Log: "CONSECUTIVE LOSS LIMIT: 3 consecutive losses. Pausing trading for 6 hours."

**In `CanOpenTrade()`:**
Return false if `g_consecutive_loss_pause_until > TimeCurrent()`.

---

## 4. Examples

### Example A — Three losses trigger pause

```
Balance: $5,000, MinLossToCount = 0.005 → minimum $25 loss to count

Trade 1 closed: -$80  (1.6% loss) → g_consecutive_losses = 1
Trade 2 closed: -$60  (1.2% loss) → g_consecutive_losses = 2
Trade 3 closed: -$95  (1.9% loss) → g_consecutive_losses = 3 → PAUSE

g_consecutive_loss_pause_until = now + 6 hours
Next potential trade is suppressed for 6 hours.
```

### Example B — A win resets the counter

```
Trade 1 closed: -$80 → counter = 1
Trade 2 closed: -$60 → counter = 2
Trade 3 closed: +$120 → counter RESET to 0

No pause. Strategy continues normally.
```

### Example C — Near-breakeven exits don't count

```
MinLossToCount = 0.005 → minimum $25 loss on $5,000 balance

Trade closed: -$12 (0.24% loss — below threshold)
→ g_consecutive_losses unchanged (not counted as a meaningful loss)

This prevents a series of very small exits from triggering a pause.
```

### Example D — Auto-resume

```
6 hours after pause: TimeCurrent() > g_consecutive_loss_pause_until
Market conditions have changed (e.g., volatility normalised after news)
EA resumes trading normally.
```

---

## 5. Code Impact

### New state (in `PrismRiskManager.mqh`)

```mql5
static int      g_consecutive_losses            = 0;
static datetime g_consecutive_loss_pause_until  = 0;
static ulong    g_last_processed_deal_ticket    = 0;  // Prevents double-counting
```

### New functions (in `PrismRiskManager.mqh`)

```mql5
// Scans recent deal history to detect newly closed trades.
// Updates g_consecutive_losses and may set g_consecutive_loss_pause_until.
void CheckConsecutiveLosses(double accountBalance);

// Returns true if the consecutive loss pause is currently active.
bool IsConsecutiveLossPauseActive();
```

### Changes to `prism.mq5`

In `PrepareAll()`:

```mql5
if(EnableConsecutiveLossLimit)
   CheckConsecutiveLosses(accountInfo.Balance());
```

In `CanOpenTrade()`:

```mql5
if(EnableConsecutiveLossLimit && IsConsecutiveLossPauseActive()) return false;
```

### Deal history detection approach

MQL5 does not have a simple `OnPositionClose()` callback. Two approaches:

**Option A — Poll deal history (simpler, slight delay):**
Each tick, call `HistorySelect()` and check if the most recent `DEAL_ENTRY_OUT` deal for this symbol/magic has a different ticket than `g_last_processed_deal_ticket`. Process it and update the ticket.

**Option B — `OnTradeTransaction()` (real-time):**
Override `OnTradeTransaction()` in `prism.mq5` and call `CheckConsecutiveLosses()` when `trans.type == TRADE_TRANSACTION_DEAL_ADD` and `trans.deal_type == DEAL_TYPE_SELL/BUY` exit. This fires immediately when a position closes.

Option B is more responsive but adds a new callback function to `prism.mq5`. Option A is simpler and sufficient given the EA's tick-based execution model.

### Integration point

`PrepareAll()` in `prism.mq5` (once per tick). The pause check in `CanOpenTrade()` gates `OpenPosition()` and `SendBackup()`.

---

## 6. Modular Design

Controlled by `EnableConsecutiveLossLimit` flag.

- **`false`** (disabled): `CheckConsecutiveLosses()` is not called. `IsConsecutiveLossPauseActive()` always returns false. Identical to current behaviour.
- **`true`** (enabled): Counter is maintained and pause logic is active.

No interaction with other RM features except through the shared `CanOpenTrade()` gate. The counter and pause operate independently of drawdown calculations.

---

## 7. Open Questions

1. **Detection method:** Option A (polling) vs Option B (`OnTradeTransaction()`)? Polling has a maximum one-tick delay, which is acceptable. `OnTradeTransaction()` requires adding a new function to `prism.mq5` that was not previously there.

2. **What counts as "the same streak"?** If positions A and B are both open simultaneously and both close as losses, are they two losses or one? The current design counts each closed deal separately — should basket closures (multiple positions closed together) count as one loss event?

3. **Backup positions:** Should losses from backup positions count toward the consecutive loss counter? Backup trades are expected to occasionally lose — including them may trigger pauses more frequently than intended.

4. **Counter persistence:** If MT5 is restarted, `g_consecutive_losses` resets to zero. Should the counter be persisted in a file so it survives restarts?
