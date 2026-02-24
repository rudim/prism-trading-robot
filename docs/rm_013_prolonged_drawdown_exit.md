# RM-013: Prolonged Drawdown Exit — Exploratory Draft

> **⚠ SUPERSEDED — the strategy has been decided and fully documented in [rm_013_prolonged_drawdown_exit_notes.md](rm_013_prolonged_drawdown_exit_notes.md)**
> This document explored multiple detection approaches. The final implementation uses the two-timer approach (Backup Drawdown Timer + Maximum Basket Age) described in the notes document. The exploratory strategies in §3 (MA Trend Flip, ADX Reversal, Higher Timeframe Divergence, Direction Cooldown, Drawdown Score) are deferred to a future phase. Do not implement from this document.

**Status:** Superseded
**Phase:** 2
**Depends on:** None (complements rm_012 Capital Partitioning Model)

---

## 1. The Problem

Backtesting reveals a consistent pattern behind every catastrophic account loss:

```
Day 1:  EA opens BUY basket. Market moves against it.
Day 1:  Backup system activates. Backup BUY trades open.
Day 2:  Both main and backup positions still losing.
Day 3:  More backup trades added. Drawdown deepens.
Day 4:  Account wiped.
```

The market has not temporarily pulled back — it has **changed direction**. The EA is not experiencing drawdown; it is fighting a new trend with trades pointed at the old one. The backup system, designed to recover from temporary pullbacks, is compounding the loss instead of curing it.

The critical characteristic that separates catastrophic losses from recoverable ones is **time**. Normal adverse moves resolve within hours. A position that is still losing after 24–48 hours — especially one where the backup trade has also failed to recover — is almost certainly the signature of genuine trend change, not a temporary retracement.

**The core insight from backtesting:**

> Every dollar lost in the catastrophic scenario could have been saved by closing all positions at the point when the backup trade had clearly failed. A single rule — "close everything if the backup has been open and losing for 24 hours" — would have prevented most account wipeouts, at the cost of a moderate single-session loss.

This specification formalises that rule and then extends it with more sophisticated market-change detection that can act earlier and with greater confidence.

---

## 2. Observed Failure Signature

The catastrophic drawdown pattern has four identifiable stages:

| Stage | Duration | Observable state |
|-------|----------|-----------------|
| **Entry** | Hour 0 | Basket opens in direction X on valid signal |
| **Drift** | Hours 1–8 | Position moves against direction. Normal drawdown. Backup activates. |
| **Stall** | Hours 8–24 | Price does not recover. Backup trade also in loss. MA/ADX beginning to shift. |
| **Cascade** | Hours 24–72+ | Market trending strongly against basket. Multiple backup trades piling in. Account bleeds to zero. |

The ideal exit is at the **Stall** stage — before the cascade. Any detection strategy that fires during the stall (or earlier) achieves the goal.

What distinguishes the stall from normal drawdown:
1. The backup trade, designed to recover the position, is itself losing.
2. The directional indicators (MAs, ADX) have shifted against the basket direction.
3. Duration: no recovery in the time window that characterises normal pullbacks.

---

## 3. Detection Strategies

Strategies are organised from simplest to most sophisticated. They are not mutually exclusive — multiple strategies can be active simultaneously.

### Strategy 1 — Backup Trade Timeout (Simple, High Confidence)

**Principle:** If the backup system has been active and the basket is still in net loss after `N` hours, the expected recovery has not materialised. Close everything.

**Logic:**
```
When first backup trade opens: record g_backup_open_time = TimeCurrent()
On every tick, if backup trades exist and g_backup_open_time is set:
  backupAge = (TimeCurrent() - g_backup_open_time) / 3600
  if backupAge > BackupTimeoutHours AND netBasketPnL < 0:
    CloseAll("BACKUP_TIMEOUT")
```

**Why this works:** The backup system is specifically designed for short-duration recoveries. A backup that remains in loss after 24 hours is statistically unlikely to recover on its own — the condition it was designed to address (a temporary spike or pullback) has resolved in the wrong direction.

**Risk:** A market that consolidates sideways for 24+ hours might trigger a false close. Mitigate by requiring the basket to also be in net loss (not just the backup).

---

### Strategy 2 — Basket Age with Net Loss (Time-Based Escalation)

**Principle:** Any position that has been open and losing for longer than a configurable threshold is presumed to be fighting the market.

**Logic:**
```
When basket opens: record g_basket_open_time = time of oldest position
On every tick:
  basketAge = (TimeCurrent() - g_basket_open_time) / 3600
  if basketAge > MaxBasketAgeHours AND netBasketPnL < 0:
    CloseAll("BASKET_TIMEOUT")
```

**Parameter interaction:** `MaxBasketAgeHours` should be set generously (48–72 hours) to give normal positions time to recover. The backup timeout is the primary early trigger; basket age is the final backstop.

---

### Strategy 3 — MA Trend Flip Against Open Direction

**Principle:** The same MA relationship that generated the basket's entry signal has since reversed. The market's medium-term trend has demonstrably changed.

The EA's signals use the relationship between MA1 (90-period) and MA2 (30-period):

| Entry signal | Bullish condition | Bearish condition |
|-------------|------------------|------------------|
| BUY basket opened when | MA1 < MA2 (short-term average above long-term) | — |
| SELL basket opened when | — | MA1 > MA2 (short-term average below long-term) |

A trend flip is confirmed when the MA relationship has **reversed** from the state at entry and **held** for `MATrendFlipBars` bars:

```
If holding BUY basket:
  flipDetected = (MA1Current > MA2Current)    // short-term fell below long-term
  If flipDetected for MATrendFlipBars consecutive bars AND netBasketPnL < 0:
    CloseAll("MA_TREND_FLIP")

If holding SELL basket:
  flipDetected = (MA1Current < MA2Current)    // short-term rose above long-term
  If flipDetected for MATrendFlipBars consecutive bars AND netBasketPnL < 0:
    CloseAll("MA_TREND_FLIP")
```

**Why require N bars:** A single bar crossing is noise. A sustained flip held for 3–5 bars on the trading timeframe represents a real medium-term shift.

**Strength of this signal:** The entry signal itself is now pointing in the opposite direction. The EA would not open a new position in the original direction. Holding an open position against the current signal state is internally contradictory.

---

### Strategy 4 — ADX Directional Reversal

**Principle:** The ADX +DI/-DI lines have crossed against the basket direction and sustained the cross for multiple bars.

```
If holding BUY basket:
  bearishDI = (ADXMinusDI > ADXPlusDI)    // selling pressure dominant
  If bearishDI for ADXFlipBars consecutive bars AND ADXMain > ADXThreshold:
    // Strong directional move against position
    CloseAll("ADX_REVERSAL")

If holding SELL basket:
  bullishDI = (ADXPlusDI > ADXMinusDI)    // buying pressure dominant
  If bullishDI for ADXFlipBars consecutive bars AND ADXMain > ADXThreshold:
    CloseAll("ADX_REVERSAL")
```

The `ADXMain > ADXThreshold` guard ensures the signal is fired only when the market is actually trending, not during low-ADX ranging periods where DI lines cross frequently.

**Relationship to Strategy 3:** MA flip (Strategy 3) detects medium-term trend change via price averages. ADX reversal (Strategy 4) detects directional force. Both can be required simultaneously (AND logic) for a more conservative trigger, or either can trigger independently (OR logic) for a more aggressive exit.

---

### Strategy 5 — Higher Timeframe Trend Divergence

**Principle:** If the position direction conflicts with the trend on a higher timeframe, the trade is swimming against the tide. This can be detected at position open (as a filter) or continuously (as an exit trigger).

**Method:** Read the MA relationship on H1 or H4 at position open. If the higher timeframe MAs are already aligned against the intended direction, the position is entering a medium-term headwind.

```
// At position open:
double htMA1[], htMA2[];
CopyBuffer(htMA1Handle, 0, 0, 1, htMA1);
CopyBuffer(htMA2Handle, 0, 0, 1, htMA2);

bool htBullish = (htMA1[0] < htMA2[0]);    // same logic as entry signals
bool htBearish = (htMA1[0] > htMA2[0]);

if(openingBuy && htBearish && EnableHTFFilter)
  // Higher timeframe is bearish — flag elevated risk or block entry

// As continuous exit monitor:
if(holdingBuy && htBearish for HTFFlipBars bars AND netBasketPnL < 0)
  CloseAll("HTF_DIVERGENCE")
```

**Application modes:**
- **Entry filter** (preventative): block entries when higher timeframe trend is opposite.
- **Exit monitor** (curative): close existing positions when higher timeframe flips against them.

The entry filter is the more powerful application — preventing the problem rather than curing it. The exit monitor catches cases where the higher timeframe flips after the position is already open.

---

### Strategy 6 — Consecutive Direction Loss Counter

**Principle:** If the last `N` completed baskets in direction X all resulted in net losses, that direction is demonstrably not working in the current market. Apply a cooldown before allowing new entries in that direction.

**State:**
```
g_direction_losses[2]       // consecutive losing basket count per direction (0=buy, 1=sell)
g_direction_cooldown[2]     // timestamp: don't trade this direction until this time
```

**Logic at basket close:**
```
On basket close with net loss:
  g_direction_losses[direction]++
  if g_direction_losses[direction] >= MaxDirectionLosses:
    g_direction_cooldown[direction] = TimeCurrent() + DirectionCooldownHours * 3600
    g_direction_losses[direction] = 0
    Log("Direction cooldown active for " + direction + " until " + TimeToString(cooldown))

On basket close with net profit:
  g_direction_losses[direction] = 0    // reset on any win
```

**In `sendOpen()` / `openPosition()`:**
```
if(TimeCurrent() < g_direction_cooldown[intendedDirection])
  return;    // cooldown active, skip this direction
```

**Effect:** After repeated failure in one direction, the EA stops fighting the market and waits for conditions to change. This does not require any indicator — it is purely based on trading outcomes.

---

### Strategy 7 — Drawdown Duration Score (Composite)

**Principle:** Combine depth and duration into a single score. Neither alone is sufficient — a deep short-duration drawdown is survivable; a shallow but multi-day drawdown is the stall pattern. The product of depth × duration provides a better signal than either alone.

```
drawdownDepth    = (balance - equity) / balance          // 0.0 to 1.0
drawdownDuration = hours since equity first dropped below threshold

drawdownScore = drawdownDepth * drawdownDuration

if drawdownScore > DrawdownScoreThreshold:
  CloseAll("DRAWDOWN_SCORE")
```

**Calibration examples:**

| Depth | Duration | Score | Action |
|-------|---------|-------|--------|
| 5% for 2 hours | 0.05 × 2 = 0.10 | Low | Wait |
| 5% for 24 hours | 0.05 × 24 = 1.20 | Medium | Alert |
| 10% for 12 hours | 0.10 × 12 = 1.20 | Medium | Alert |
| 10% for 48 hours | 0.10 × 48 = 4.80 | High | Close |
| 20% for 6 hours | 0.20 × 6 = 1.20 | Medium | Alert |
| 20% for 24 hours | 0.20 × 24 = 4.80 | High | Close |

A `DrawdownScoreThreshold` of 3.0–5.0 catches the catastrophic scenario while ignoring normal short-duration drawdowns.

**State:**
```
g_drawdown_start_time    // when equity first dropped below DrawdownAlertPct * balance
                         // reset to 0 when equity recovers above threshold
```

---

## 4. Parameters

```mql5
input group "════════ RISK: PROLONGED DRAWDOWN EXIT ════════";

// ── Master switch ──────────────────────────────────────────────────────────────
input bool   EnableProlongedDrawdownExit = true;
// When disabled: no time-based or trend-flip exits fire. Behaviour identical to
// current EA (exits only on profit targets or SafeExits with profit threshold).

// ── Strategy 1: Backup Trade Timeout ──────────────────────────────────────────
input bool   EnableBackupTimeout        = true;
input int    BackupTimeoutHours         = 24;   // Close all if backup in net loss for this long (hours)

// ── Strategy 2: Basket Age Backstop ───────────────────────────────────────────
input bool   EnableBasketTimeout        = true;
input int    MaxBasketAgeHours          = 72;   // Close all if basket open and losing for this long (hours)

// ── Strategy 3: MA Trend Flip ─────────────────────────────────────────────────
input bool   EnableMATrendFlip          = true;
input int    MATrendFlipBars            = 3;    // Bars MA must stay flipped before triggering (reduces noise)

// ── Strategy 4: ADX Directional Reversal ──────────────────────────────────────
input bool   EnableADXReversal          = true;
input int    ADXFlipBars                = 3;    // Bars DI must stay flipped before triggering
input double ADXReversalThreshold       = 20;   // ADX main must exceed this for the reversal to count
                                                 // (avoids false triggers in ranging markets)

// ── Strategy 5: Higher Timeframe Divergence ───────────────────────────────────
input bool   EnableHTFDivergence        = false;
input ENUM_TIMEFRAMES HTFTimeframe      = PERIOD_H4;   // Higher timeframe to check (H1, H4, D1)
input int    HTFDivergenceBars          = 3;    // Bars HTF MAs must be divergent before triggering
input bool   HTFAsEntryFilter           = false; // Also block new entries when HTF is divergent

// ── Strategy 6: Direction Cooldown ────────────────────────────────────────────
input bool   EnableDirectionCooldown    = true;
input int    MaxDirectionLosses         = 3;    // Consecutive losing baskets before cooldown activates
input int    DirectionCooldownHours     = 12;   // Hours to block a direction after MaxDirectionLosses

// ── Strategy 7: Drawdown Score ────────────────────────────────────────────────
input bool   EnableDrawdownScore        = false;
input double DrawdownAlertPct           = 0.05; // Equity drop threshold to begin duration tracking (5%)
input double DrawdownScoreThreshold     = 4.0;  // Score (depth × hours) that triggers close
```

---

## 5. Exit Decision Framework

The strategies are not all equal. They operate at different confidence levels and respond to different time horizons. Recommended trigger logic:

```
CheckProlongedDrawdownExit():

  // Only act when positions are open and in net loss
  if totalTrades == 0 OR netBasketPnL >= 0:
    return

  // Strategy 1: Backup timeout (most direct signal)
  if EnableBackupTimeout AND totalBackupTrades > 0:
    backupAge = (Now - g_backup_open_time) / 3600
    if backupAge > BackupTimeoutHours:
      CloseAll("BACKUP_TIMEOUT")
      return

  // Strategy 2: Basket age backstop
  if EnableBasketTimeout:
    basketAge = (Now - g_basket_open_time) / 3600
    if basketAge > MaxBasketAgeHours:
      CloseAll("BASKET_TIMEOUT")
      return

  // Strategy 3: MA trend flip (requires sustained confirmation)
  if EnableMATrendFlip:
    if MATrendFlippedAgainstBasket for MATrendFlipBars:
      CloseAll("MA_TREND_FLIP")
      return

  // Strategy 4: ADX directional reversal
  if EnableADXReversal:
    if ADXDirectionAgainstBasket for ADXFlipBars AND ADXMain > ADXReversalThreshold:
      CloseAll("ADX_REVERSAL")
      return

  // Strategy 5: HTF divergence (continuous monitor)
  if EnableHTFDivergence:
    if HTFTrendAgainstBasket for HTFDivergenceBars:
      CloseAll("HTF_DIVERGENCE")
      return

  // Strategy 7: Composite drawdown score
  if EnableDrawdownScore:
    updateDrawdownDurationTracker()
    score = drawdownDepth * drawdownDurationHours
    if score > DrawdownScoreThreshold:
      CloseAll("DRAWDOWN_SCORE")
      return
```

### Priority rationale

Strategy 1 (backup timeout) is checked first because it is the most direct evidence of the failure pattern described in §1. The backup's entire purpose is short-duration recovery. If it hasn't recovered in 24 hours, the premise is invalidated.

Strategy 2 (basket age) is the no-questions-asked backstop. No indicator can remain reliable forever; time alone is a valid reason to cut a position.

Strategies 3 and 4 (MA and ADX flip) are signal-based and act faster than time-based strategies when the market changes sharply. They should be checked after the time-based checks since a fast market move may trigger them within hours, making them redundant if the time-based checks also fired.

### After closing: "try again" policy

When `CloseAll` is triggered by this module:

1. `g_direction_losses[direction]++` — contributes toward the direction cooldown counter (Strategy 6).
2. A configurable `PostExitCooldownMinutes` prevents immediate re-entry in any direction.
3. The EA resumes normal signal-based trading once the cooldown expires.

The new position will be opened in whichever direction the current signals indicate — which may be the opposite of the closed basket if the MA/ADX have already flipped. This is the "close and try again with the new market" behaviour.

---

## 6. State Tracking

New state variables required in `PrismRiskManager.mqh` or a new `PrismDrawdownGuard.mqh`:

```mql5
// Basket and backup open timestamps
static datetime g_basket_open_time     = 0;    // Time of oldest open position in current basket
static datetime g_backup_open_time     = 0;    // Time first backup trade opened in current basket
                                               // Reset to 0 when all positions closed

// Direction cooldown (Strategy 6)
static int    g_direction_losses[2]    = {0, 0};  // [0]=buy, [1]=sell
static datetime g_direction_cooldown[2] = {0, 0};

// MA flip tracking (Strategy 3)
static int    g_ma_flip_bars           = 0;    // Consecutive bars MA has been flipped against basket

// ADX flip tracking (Strategy 4)
static int    g_adx_flip_bars          = 0;    // Consecutive bars DI has been flipped against basket

// HTF state (Strategy 5)
static int    g_htf_handle_ma1         = INVALID_HANDLE;
static int    g_htf_handle_ma2         = INVALID_HANDLE;
static int    g_htf_flip_bars          = 0;

// Drawdown score tracking (Strategy 7)
static datetime g_drawdown_start_time  = 0;    // When equity first dropped below DrawdownAlertPct
```

---

## 7. Code Impact

### New functions

```mql5
// Core check — call at start of every OnTick() after PrepareAll()
// Returns true if it triggered a close (caller should return from OnTick immediately)
bool CheckProlongedDrawdownExit(const PositionStats &stats,
                                const MarketConditions &market,
                                const IndicatorValues &indicators);

// Update basket/backup open timestamps. Call from sendOpen() and sendBack()
// after any successful position open.
void UpdateBasketTimestamps(bool isBackup);

// Reset all basket tracking state. Call from closeAll() when all positions are closed.
void ResetBasketState();

// Strategy 6: update direction loss counters. Call from closeAll() when basket closes in loss.
void RecordBasketClose(bool wasProfit, int direction);

// Strategy 6: returns true if this direction is currently in cooldown.
bool IsDirectionOnCooldown(int direction);

// Strategy 5: initialise HTF indicator handles. Call from OnInit().
bool InitHTFIndicators();
```

### Changes to `prism.mq5`

**`OnInit()`:**
```mql5
if(EnableHTFDivergence && EnableProlongedDrawdownExit)
    InitHTFIndicators();
```

**`OnTick()` — top of tick, after `prepare()`:**
```mql5
if(EnableProlongedDrawdownExit)
    if(CheckProlongedDrawdownExit(_stats, _market, _indicators))
        return;
```

**`sendOpen()` / `sendBack()`** — after successful `_trade.PositionOpen()`:
```mql5
UpdateBasketTimestamps(isBackup);
```

**`closeAll()`** — before iterating positions:
```mql5
bool wasProfit = (_stats.totalProfit + _stats.totalLoss) > 0;
RecordBasketClose(wasProfit, _stats.openType);
// ... existing close loop ...
ResetBasketState();
```

**`openPosition()` / `sendOpen()`** — before opening:
```mql5
if(EnableDirectionCooldown && IsDirectionOnCooldown(intendedDirection))
{
    Print("Direction cooldown active, skipping ", directionStr);
    return;
}
```

### HUD display additions

```mql5
if(EnableProlongedDrawdownExit && _stats.totalTrades > 0)
{
    if(g_basket_open_time > 0)
    {
        double basketAge = (TimeCurrent() - g_basket_open_time) / 3600.0;
        display += " BasketAge: " + DoubleToString(basketAge, 1) + "h";
    }
    if(g_backup_open_time > 0)
    {
        double backupAge = (TimeCurrent() - g_backup_open_time) / 3600.0;
        display += " BackupAge: " + DoubleToString(backupAge, 1) + "h";
    }
}
```

---

## 8. Configuration Presets

### Conservative (maximum protection, accepts early false exits)

```
BackupTimeoutHours      = 12
MaxBasketAgeHours       = 36
EnableMATrendFlip       = true,  MATrendFlipBars = 2
EnableADXReversal       = true,  ADXFlipBars = 2
EnableHTFDivergence     = true,  HTFTimeframe = PERIOD_H1
HTFAsEntryFilter        = true
MaxDirectionLosses      = 2,  DirectionCooldownHours = 24
EnableDrawdownScore     = true,  DrawdownScoreThreshold = 2.0
```

### Balanced (recommended starting point)

```
BackupTimeoutHours      = 24
MaxBasketAgeHours       = 72
EnableMATrendFlip       = true,  MATrendFlipBars = 3
EnableADXReversal       = true,  ADXFlipBars = 3,  ADXReversalThreshold = 20
EnableHTFDivergence     = false
HTFAsEntryFilter        = false
MaxDirectionLosses      = 3,  DirectionCooldownHours = 12
EnableDrawdownScore     = false
```

### Permissive (only hard backstops, maximum position survival time)

```
BackupTimeoutHours      = 48
MaxBasketAgeHours       = 120
EnableMATrendFlip       = false
EnableADXReversal       = false
EnableHTFDivergence     = false
EnableDirectionCooldown = true,  MaxDirectionLosses = 5,  DirectionCooldownHours = 6
EnableDrawdownScore     = false
```

---

## 9. Interaction with Existing Systems

| Existing system | Interaction |
|----------------|-------------|
| **SafeExits** | `SafeExits` closes on trend reversal only when basket is in profit. This spec handles the inverse: closes on trend reversal when basket is in **loss**. They are complementary. |
| **Backup system** | Backup timeout directly monitors the backup system's age. When this spec fires, it closes backup trades along with everything else. The backup system should not open new trades after a `CloseAll("BACKUP_TIMEOUT")` until `PostExitCooldownMinutes` elapses. |
| **rm_012 Capital Partitioning** | After this spec closes a losing basket, rm_012's profit floor remains intact (no milestone triggers on a loss close). The direction cooldown prevents re-entry that would only continue eroding capital. |
| **rm_005 Drawdown Circuit Breaker** | rm_005 monitors daily drawdown. This spec monitors basket-level duration and trend state. They can both be active — rm_005 is a blunt instrument (daily reset) while this is basket-specific. |
| **Calendar filter** | Time-based exits (Strategies 1 and 2) ignore the calendar blackout window — a position that has been open and losing for 48 hours should be closed regardless of upcoming news. Signal-based exits (Strategies 3–4) are also independent of calendar state. |

---

## 10. Open Questions

1. **What counts as "net loss" for the trigger condition?** Should the trigger fire if the basket is merely below the `OpenProfit` threshold (i.e., not profitable enough), or only when the basket is in absolute dollar loss? Using absolute loss is safer; using a profit threshold could also exit marginal winners early.

2. **Partial close option:** Instead of closing all positions, could the timeout trigger close only the losing positions while keeping any profitable ones? This would preserve partial gains but complicates the "clear state and start fresh" intent.

3. **Backup timeout reset on backup close:** If some backup trades are manually closed by the user or by another rule, should `g_backup_open_time` reset to track the *current* oldest backup trade, or remain fixed from when the first backup was ever opened in this basket?

4. **MA flip bars — trading timeframe sensitivity:** On M15, 3 bars is 45 minutes. On H1, 3 bars is 3 hours. The `MATrendFlipBars` parameter needs to be calibrated per timeframe. Should it be expressed in hours rather than bars to be timeframe-agnostic?

5. **Direction cooldown interaction with hedge mode:** When `AllowHedge = true`, the backup system can open trades in the opposite direction. A direction cooldown on the original direction would still allow hedging. Is this the desired interaction, or should the cooldown block both directions?

6. **Backtesting validation:** The primary validation needed is: "on each historical catastrophic loss, at what time did the earliest detection strategy fire, and what would the saved capital have been?" This should be run before setting default parameter values.

7. **Strategy 7 (Drawdown Score) calibration:** The depth × duration formula is not dimensionally normalised — a 5% drawdown for 24 hours gives the same score as a 10% drawdown for 12 hours. Is linear scaling between depth and duration appropriate, or should one dimension be weighted more heavily?
