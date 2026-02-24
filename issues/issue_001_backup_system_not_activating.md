# Issue 001: Backup System Fails to Activate — Drawdown Timer Never Fires

**Status:** Open
**Severity:** Critical
**Backtest:** `reports/ReportTester-298469420.html`
**Test period:** 2023-07-01 – 2025-12-31 (EURUSD_custom, M5)
**Outcome:** Account blown — final balance **-$0.78** from a $1,000 start

---

## Summary

During the backtest, several distinct drawdown periods occurred where the backup system should have activated but did not. The immediate consequence of backup not activating is that the **drawdown timer (`CheckBackupDrawdownTimer`) never starts**, because it can only run when at least one backup position is open. Without a backup position, the timer returns immediately and the forced-close safety net is never applied.

The most severe failure occurred between approximately **2023-08-30 and 2023-09-25**, when a BUY position on EURUSD held for ~26 days while price fell ~330 pips, accumulating a **-$617.40 loss** (plus -$27.80 swap = **-$645.20 total**) that wiped the account from ~$644 balance to **-$0.78**.

---

## Observed Evidence

### Backup trades that did fire (correctly)

| Deal # | Date | Type | Lots | Held | Outcome |
|--------|------|------|------|------|---------|
| 41 | 2023-07-12 | SELL | 0.10 | 24 h (timer fired) | -$117.20 (forced close) |
| 77 | 2023-07-20 | SELL | 0.06 | 6.5 h | +$9.12 |
| 89 | 2023-07-24 | SELL | 0.06 | ~20 min | +$16.38 |
| 101 | 2023-07-26 | SELL | 0.07 | 24 h (timer fired) | -$42.56 |
| 107 | 2023-07-31 | BUY | 0.05 | ~5 h | +$7.15 |
| 123 | 2023-08-03 | BUY | 0.05 | ~16 h | +$17.40 |
| 131 | 2023-08-07 | BUY | 0.05 | ~2.6 h | +$10.70 |
| 147 | 2023-08-11 | SELL | 0.05 | ~8 h | +$7.65 |
| 171 | 2023-08-17 | SELL | 0.06 | ~4 h | +$13.86 |

**Last backup: 2023-08-17.** After that, no backup ever opened again.

### Catastrophic failure period (backup never fired)

- A BUY position was opened around **2023-08-30** (between deals 193 and 195).
- At the time of opening, EURUSD was approximately **1.093**.
- The position ran for **~26 days** with no backup hedge and no forced close.
- On **2023-09-25**, it was closed at **1.05866** (a 335-pip adverse move).
- At peak drawdown, the $644 balance was carrying ~$600 in unrealized loss — an equity ratio of roughly **2%**, far below the `TriggerBackSystem = 0.95` (5%) threshold.
- Yet backup never activated.

---

## Root Cause Analysis

Four bugs interact to prevent backup from activating. Bug 1 is the primary cause; Bugs 2–4 are contributing factors.

---

### Bug 1 (Primary): Aggressive mode ignores `AllowHedge` — hedge SELL blocked by open BUY lots

**File:** `source/prism.mq5`
**Function:** `sendBack()` — lines ~663–682

```mql5
// Aggressive mode backup logic
if(!_market.nearLongPosition && type == (int)POSITION_TYPE_BUY && _stats.sellLots == 0)
{
    // Open BUY backup  ← only fires if NO sell positions open
}
else if(!_market.nearShortPosition && type == (int)POSITION_TYPE_SELL && _stats.buyLots == 0)
{
    // Open SELL backup  ← only fires if NO buy positions open  ← THIS IS THE BLOCKER
}
```

When the main position is a **BUY** and price starts dropping:
- The market signal turns **bearish** → `type = POSITION_TYPE_SELL`
- Aggressive backup attempts to open a **SELL** (hedge) position
- **Blocked** because `_stats.buyLots != 0` (there are open BUY positions)

The result is a complete deadlock: backup is needed most when the market is moving against the open position, but that is precisely when aggressive mode cannot open a hedge.

**Contrast with spike-detection mode**, which correctly wires `AllowHedge`:
```mql5
// Spike detection mode — AllowHedge IS respected
((!AllowHedge && _stats.openType == (int)POSITION_TYPE_SELL) || AllowHedge)
```

In spike-detection mode, setting `AllowHedge = true` lets backup open in the opposite direction. In aggressive mode, `AllowHedge` is read from inputs but **never referenced in the code path**. The condition `_stats.buyLots == 0` (or `_stats.sellLots == 0`) always blocks the hedge regardless of `AllowHedge`.

**Why this mattered in the test:**
After 2023-08-17, the EA held BUY positions during a prolonged bearish move. Aggressive mode tried to open a SELL hedge but was blocked every tick. Backup never opened → drawdown timer never started → no forced close after 24 hours.

---

### Bug 2 (Contributing): `MinMarginLevel` blocks backup precisely when drawdown is worst

**File:** `source/prism.mq5`
**Function:** `OnTick()` — the outer trading gate

```mql5
if(_dailyGrowth / _accountInfo.Balance() < DailyGrowth &&
   currentTime - _lastTradeTime > SleepSeconds &&
   (_marginLevel == 0 || _marginLevel > MinMarginLevel))   // ← gate
{
    if(_stats.totalTrades >= _maxStartTrades && equityRatio < TriggerBackSystem)
    {
        backSystem();   // backup trigger is inside this gate
    }
}
```

`MinMarginLevel = 300` requires **margin level ≥ 300%** before any new position (including backup) can open. During severe drawdown:

- Equity drops as the losing position expands
- `marginLevel = Equity / Margin × 100%`
- Example with 0.18 lots on EURUSD, ~$39 margin (at Exness high leverage) and $14 remaining equity:
  `marginLevel ≈ 14 / 39 × 100% ≈ 36%` — far below 300%

**Paradox:** The backup system is the drawdown recovery mechanism, but `MinMarginLevel = 300%` prevents it from activating when the drawdown is severe enough to lower margin level below 300%. The protection is disabled exactly when it is needed most.

---

### Bug 3 (Contributing): Aggressive backup does not update `_lastTradeTime`

**File:** `source/prism.mq5`
**Function:** `sendBack()` — aggressive mode branch

```mql5
// Aggressive BUY backup — missing _lastTradeTime update
if(!_trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, _backupLotSize, ask, 0, 0, comment))
    Print("Error opening aggressive BUY backup: ", _trade.ResultRetcodeDescription());
// NO _lastTradeTime = TimeCurrent(); here
```

Spike-detection mode **does** update `_lastTradeTime`:
```mql5
if(_trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, _backupLotSize, ask, 0, 0, comment))
{
    Print("Opened BUY backup on spike: ", comment);
    _lastTradeTime = TimeCurrent();  // ← present here
}
```

Without resetting `_lastTradeTime`, the `SleepSeconds` gate never re-arms after an aggressive backup opens, so consecutive ticks will immediately attempt additional backups until the `MaxTrades - _maxStartTrades` cap is hit. This causes backup position spam in aggressive mode (a separate reliability concern) but is secondary to Bug 1 in this failure scenario.

---

### Bug 4 (Consequence): Drawdown timer cannot activate without a backup position

**File:** `source/Includes/PrismRiskManager.mqh`
**Function:** `CheckBackupDrawdownTimer()` — line 180

```mql5
bool CheckBackupDrawdownTimer(int magic, double netBasketPnL,
                              bool activate, int thresholdMinutes)
{
    if(!activate) return false;

    datetime oldestBackup = GetOldestBackupOpenTime(magic);
    if(oldestBackup == 0) return false;   // ← returns false if no backup is open
    ...
}
```

The drawdown timer requires a backup position to be open. If backup never activates (due to Bugs 1 or 2), `GetOldestBackupOpenTime` returns `0` and the timer exits immediately. The forced-close safety net is therefore **never applied**, no matter how long a losing position is held.

**Observed impact:** The BUY position that blew the account was held for 26 days. With `DrawdownTimerMinutes = 1440` (24 hours), a forced close should have triggered on day 2 at the latest — but only if a backup had been opened first.

---

## Summary of Bugs

| # | Location | Description | Severity |
|---|----------|-------------|----------|
| 1 | `sendBack()` aggressive branch | `AllowHedge` not respected — `buyLots == 0` / `sellLots == 0` blocks hedge | **Critical** |
| 2 | `OnTick()` outer gate | `MinMarginLevel = 300%` blocks backup when drawdown lowers margin level | **High** |
| 3 | `sendBack()` aggressive branch | `_lastTradeTime` not updated after aggressive backup opens | **Medium** |
| 4 | `CheckBackupDrawdownTimer()` | Timer never starts if no backup is open (consequence of Bug 1) | **High** (consequence) |

---

## Relevant Code Locations

| Symbol | File | Line(s) | Description |
|--------|------|---------|-------------|
| `sendBack()` | `source/prism.mq5` | ~636–739 | Full backup send logic |
| Aggressive BUY block | `source/prism.mq5` | ~663–671 | Missing `AllowHedge` check, missing `_lastTradeTime` |
| Aggressive SELL block | `source/prism.mq5` | ~673–682 | Missing `AllowHedge` check, missing `_lastTradeTime` |
| Spike BUY block | `source/prism.mq5` | ~686–710 | Correct: uses `AllowHedge`, updates `_lastTradeTime` |
| Spike SELL block | `source/prism.mq5` | ~712–736 | Correct: uses `AllowHedge`, updates `_lastTradeTime` |
| Outer trading gate | `source/prism.mq5` | ~886–906 | `MinMarginLevel` gate wraps backup trigger |
| Backup trigger | `source/prism.mq5` | ~893–898 | Calls `backSystem()` |
| `CheckBackupDrawdownTimer()` | `source/Includes/PrismRiskManager.mqh` | 175–195 | Returns false if no backup open |
| `GetOldestBackupOpenTime()` | `source/Includes/PrismRiskManager.mqh` | 128–144 | Returns 0 when no backup exists |
| `AnalyzePositions()` | `source/Includes/PrismPositions.mqh` | 14–75 | Counts `buyLots`/`sellLots` (SL==0 filter) |

---

## Test Configuration (from report)

Key settings that contributed to this failure:

| Parameter | Value | Relevance |
|-----------|-------|-----------|
| `Aggressive` | `true` | Selects the broken code path |
| `AllowHedge` | `true` | Intended to allow hedging — not wired in aggressive mode |
| `TriggerBackSystem` | `0.95` | 5% drawdown triggers backup |
| `MinMarginLevel` | `300.0` | Blocks backup when margin level < 300% |
| `SleepSeconds` | `18000` | 5-hour minimum between trades (also gates backup) |
| `DrawdownTimerMinutes` | `1440` | 24-hour timer — never started because no backup opened |
| `EnableLotCap` | `false` | Lot caps disabled (not a factor here) |
