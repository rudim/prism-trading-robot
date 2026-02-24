# RM-013: Prolonged Drawdown Exit

**Status:** Draft
**Phase:** 2
**Depends on:** None (complements rm_012 Capital Partitioning Model)
**Supersedes exploratory draft:** [rm_013_prolonged_drawdown_exit.md](rm_013_prolonged_drawdown_exit.md)

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

---

## 2. Observed Failure Signature

The catastrophic drawdown pattern has four identifiable stages:

| Stage | Duration | Observable state |
|-------|----------|-----------------|
| **Entry** | Hour 0 | Basket opens in direction X on valid signal |
| **Drift** | Hours 1–8 | Position moves against direction. Normal drawdown. Backup activates. |
| **Stall** | Hours 8–24 | Price does not recover. Backup trade also in loss. |
| **Cascade** | Hours 24–72+ | Market trending strongly against basket. Multiple backup trades piling in. Account bleeds to zero. |

The ideal exit is at the **Stall** stage — before the cascade. The two controls in this specification are designed to fire during the stall.

---

## 3. Proposed Solution

Two independent controls address the two distinct scenarios in which positions run too long:

### Control 1 — Backup Drawdown Timer (`ActivateDrawdownTimer`)

**Scenario:** The backup system has activated, meaning the basket is in drawdown. The backup trade is also losing. Time elapses. No recovery.

**Rule:** Once the backup system has engaged, track the open time of the oldest backup trade. If it has been open longer than `DrawdownTimerMinutes` **and the basket is in net loss**, close all open positions.

The net loss requirement means the timer acts as a controlled stop on failing positions — not an automatic exit when the market has recovered and the basket is profitable. If the backup opened, the market dipped, but by the timeout point the basket is back in profit, the recovery is working and the timer does not interfere.

This is the primary defence against the cascade pattern. It directly targets the signature of market-change failure: a backup trade that fails to do its job.

### Control 2 — Maximum Basket Age (`EnableMaxTradeTime`)

**Scenario:** The market drifts slowly against the basket — never aggressively enough to trigger the backup system's equity threshold (`TriggerBackSystem`), but persistently enough that no recovery occurs. The basket occupies trade slots indefinitely, blocking new signal-based entries.

**Rule:** Measure the age of the basket from the time the oldest position was opened (not the backup). If the basket has been open longer than `MaxTradeTimeMinutes`, close all positions — regardless of profit or loss.

This is the no-questions-asked backstop. It ensures no basket runs indefinitely whether or not the backup system was ever engaged. The timer measures from the oldest position in the basket, which may be a backup trade if the EA restarted mid-session.

---

## 4. Parameters

```mql5
input group "════════ RISK: DRAWDOWN TIMERS ════════";

// ── Control 1: Backup Drawdown Timer ─────────────────────────────────────────
input bool   ActivateDrawdownTimer   = true;
// Activate the backup drawdown timer once the backup system has engaged.
// The backup system engages when equity drops below TriggerBackSystem × balance.
// Timer fires only when the basket is also in net loss at the time of expiry.

input int    DrawdownTimerMinutes    = 1440;
// Minutes the oldest backup trade may be open (while basket is in net loss)
// before all positions are closed.
// Default 1440 = 24 hours.
// The timer measures from the open time of the oldest currently-open backup trade.
// If that backup closes and a newer one is open, the clock resets to the newer trade.

// ── Control 2: Maximum Basket Age ────────────────────────────────────────────
input bool   EnableMaxTradeTime      = false;
// Close all positions when the basket has been open longer than MaxTradeTimeMinutes,
// regardless of whether the backup system was engaged and regardless of profit or loss.
// Designed for positions that slowly drift without triggering the backup threshold.

input int    MaxTradeTimeMinutes     = 4320;
// Minutes from basket open (oldest position) before forced close.
// Default 4320 = 72 hours. The timer measures from the oldest open position,
// whether that position is a main trade or a backup trade.
```

---

## 5. Behaviour

### 5.1 Backup Drawdown Timer

Called on every tick as part of the risk check sequence.

```
CheckBackupDrawdownTimer():

  if NOT ActivateDrawdownTimer: return false
  if totalBackupTrades == 0: return false    // backup not yet engaged

  oldestBackupTime = GetOldestBackupOpenTime()
  if oldestBackupTime == 0: return false

  elapsedMinutes = (TimeCurrent() - oldestBackupTime) / 60

  if elapsedMinutes >= DrawdownTimerMinutes:
    if netBasketPnL >= 0: return false       // basket recovering — do not interrupt
    deadline = oldestBackupTime + DrawdownTimerMinutes * 60
    Log("BACKUP_TIMEOUT: Backup open since " + TimeToString(oldestBackupTime) +
        ". Deadline was " + TimeToString(deadline) +
        ". Elapsed: " + elapsedMinutes + " min. Net PnL: " + netBasketPnL + ". Closing all.")
    return true    // caller closes positions

  return false
```

**Oldest backup trade, not first-ever backup:** `GetOldestBackupOpenTime()` returns the open time of the oldest *currently open* backup trade. If the first backup trade closes (hit a stop or closed manually) and a second backup opens, the clock resets to the second trade's open time. The timer is anchored to whatever backup positions the EA is currently managing — not to historical state that may no longer be relevant.

**Net loss required:** The timer only closes when `netBasketPnL < 0` at the time of expiry. If the backup has been running for 24 hours but the basket is currently in profit, the market has recovered and no forced exit occurs. On the next tick where elapsed is still ≥ threshold but the basket has moved to loss, the close fires immediately — there is no secondary timer, the condition is re-evaluated on every tick.

**MT5-restart safety:** `GetOldestBackupOpenTime()` scans live positions using `POSITION_TIME` on each tick. It does not rely on a static variable that would reset on EA restart. A basket opened before an MT5 restart is correctly timed from its actual position open times on the next tick.

### 5.2 Maximum Basket Age Timer

```
CheckMaxTradeTime():

  if NOT EnableMaxTradeTime: return false
  if totalTrades == 0: return false

  oldestPositionTime = GetOldestPositionOpenTime()
  if oldestPositionTime == 0: return false

  elapsedMinutes = (TimeCurrent() - oldestPositionTime) / 60

  if elapsedMinutes >= MaxTradeTimeMinutes:
    deadline = oldestPositionTime + MaxTradeTimeMinutes * 60
    Log("MAX_TRADE_TIME: Oldest position open since " + TimeToString(oldestPositionTime) +
        ". Deadline was " + TimeToString(deadline) +
        ". Elapsed: " + elapsedMinutes + " min. Closing all.")
    return true

  return false
```

**No profit/loss check.** The maximum basket age fires regardless of basket P&L. A position that has occupied a trade slot for 72 hours is closed whether it is profitable or not. The purpose is to free the EA to trade current market conditions, not to specifically cut losses.

**The oldest position includes backup trades.** `GetOldestPositionOpenTime()` returns the minimum `POSITION_TIME` across all EA positions on the current symbol, backup or otherwise.

### 5.3 Logging

Both timers log only on trigger. The log entry includes:
- The open time of the oldest relevant position
- The computed deadline (open time + threshold)
- The elapsed minutes at trigger
- For the backup timer: the basket net P&L at time of close

A countdown is shown on the HUD at all times when positions are open (see §7), so the trader can see the ETA without the Experts log being written to on every tick.

### 5.4 Execution order

Both checks run at the top of `OnTick()` after `prepare()`, before any trade-opening logic. The backup timer is checked first — it is the more targeted signal and has a shorter threshold. The basket age timer is the final backstop.

```
OnTick():
  prepare()

  if ActivateDrawdownTimer AND CheckBackupDrawdownTimer(): closeAll(); return
  if EnableMaxTradeTime   AND CheckMaxTradeTime():         closeAll(); return

  if CloseAll: closeAll(); return

  // ... normal trade logic
```

No additional direction cooldown is imposed after a timer-triggered close. The `SleepSeconds` parameter already enforces a minimum gap between trades, and the time elapsed during the drawdown (typically 24–72 hours) itself acts as a natural separation from the failed basket's conditions.

---

## 6. Examples

### Example A — Backup timeout prevents cascade (primary scenario)

```
Balance: $5,000
DrawdownTimerMinutes: 1440 (24 hours)

Mon 09:00  BUY basket opens on Signal B.
Mon 14:00  Market pulls back. Equity drops below TriggerBackSystem threshold.
           First backup BUY trade opens. Oldest backup open time = Mon 14:00.
           Timer deadline = Tue 14:00.
Mon 17:00  Both positions still in loss. Market continuing lower.
Tue 00:00  Overnight. Market trends further against basket.
Tue 14:00  Elapsed since backup open: 1440 minutes (24 hours).
           netBasketPnL < 0 → condition met.
           Log: "BACKUP_TIMEOUT: Backup open since Mon 14:00.
                 Deadline was Tue 14:00. Elapsed: 1440 min. Net PnL: -$310. Closing all."
           closeAll() → all positions closed.

State at close:
  Loss crystallised at ~Tue 14:00 price level.
  Account survives. EA restarts signal scanning from next tick.

Without timer:
  Wed 09:00  More backup trades added. Drawdown deepens.
  Thu 12:00  Account wiped.
```

### Example B — Basket timeout catches slow drift (no backup engaged)

```
Balance: $5,000
EnableMaxTradeTime: true
MaxTradeTimeMinutes: 4320 (72 hours)
TriggerBackSystem: 0.95

Mon 09:00  BUY basket opens. Oldest position time = Mon 09:00.
           Max trade time deadline = Thu 09:00.
Mon–Wed    Market drifts sideways then slowly lower.
           Equity oscillates between 96%–99% of balance.
           TriggerBackSystem threshold (95%) never crossed.
           No backup trades open.
           ActivateDrawdownTimer has nothing to monitor.

Thu 09:00  Elapsed since oldest position: 4320 minutes (72 hours).
           Log: "MAX_TRADE_TIME: Oldest position open since Mon 09:00.
                 Deadline was Thu 09:00. Elapsed: 4320 min. Closing all."
           closeAll() → all positions closed.

State at close:
  Position occupied trade slots for 3 days.
  Small loss (or possibly small profit) crystallised.
  EA can now act on current market signals.

Without MaxTradeTime:
  Trade continues drifting indefinitely. New signal entries blocked.
  If the position eventually reaches TriggerBackSystem after 3+ days,
  the backup starts from a weakened capital position.
```

### Example C — Backup fires before max trade time (normal interaction)

```
MaxTradeTimeMinutes:  4320 (72 hours)
DrawdownTimerMinutes: 1440 (24 hours)

Mon 09:00  BUY basket opens. Oldest position = Mon 09:00.
           MaxTradeTime deadline = Wed 09:00 (Thu is wrong: Mon + 72h = Thu 09:00).
Mon 16:00  Backup engages. Oldest backup = Mon 16:00.
           BackupTimer deadline = Tue 16:00.

Tue 16:00  Backup timer threshold reached. netBasketPnL < 0.
           CloseAll("BACKUP_TIMEOUT").
           Basket was 31h old; backup was 24h old.
           MaxTradeTime (Wed 09:00) never reached.
```

### Example D — Basket recovers before backup timer fires

```
DrawdownTimerMinutes: 1440 (24 hours)

Mon 10:00  BUY basket opens.
Mon 12:00  Backup engages. Oldest backup = Mon 12:00.
           Timer deadline = Tue 12:00.
Tue 05:00  Market reverses. Basket moves into profit (+$120).
Tue 12:00  Backup has been open 1440 minutes.
           netBasketPnL = +$120 → condition NOT met. Timer does not fire.
           EA continues holding the profitable basket.
Tue 14:00  Basket reaches OpenProfit target → closeAll() via normal profit logic.

The net loss requirement correctly preserved a recovering basket.
```

### Example E — Basket recovers then falls back into loss after deadline

```
DrawdownTimerMinutes: 1440 (24 hours)

Mon 12:00  Backup opens. Deadline = Tue 12:00.
Tue 12:00  Elapsed = 1440 min. netBasketPnL = +$80. Timer does not fire.
Tue 13:30  Market reverses again. netBasketPnL = -$45.
           On next tick: elapsed = 1470 min >= 1440 AND netBasketPnL < 0.
           Timer fires immediately → CloseAll("BACKUP_TIMEOUT").

Once the deadline is passed the check fires on the first tick the basket
moves to net loss. There is no secondary countdown.
```

### Example F — Parameter comparison across settings

| `DrawdownTimerMinutes` | `MaxTradeTimeMinutes` | Character |
|------------------------|----------------------|-----------|
| 480 (8h) | 1440 (24h) | Very aggressive. Exits early. Accepts frequent small losses to avoid large ones. |
| 1440 (24h) | 4320 (72h) | Balanced. Allows normal multi-session recovery before cutting. Default. |
| 2880 (48h) | 7200 (5d) | Permissive. Gives positions more room. Risk: deeper loss before exit. |
| `ActivateDrawdownTimer = false` | `EnableMaxTradeTime = true`, 4320 | Time-only backstop. No backup monitoring. Simplest configuration. |
| `ActivateDrawdownTimer = true` | `EnableMaxTradeTime = false` | Backup-only monitoring. No hard limit on positions that never trigger backup. |

---

## 7. Code Impact

### New helper functions (in `PrismRiskManager.mqh`)

```mql5
//--- Returns the open time of the oldest currently-open backup trade for this EA.
//    Backup trades are identified by the presence of "Backup" in the position comment.
//    Returns 0 if no backup trades are open. If a backup trade closes and a newer
//    one is open, returns the newer trade's open time (timer resets naturally).
datetime GetOldestBackupOpenTime(int magic)
{
   datetime oldest = 0;
   CPositionInfo pos;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != magic) continue;
      if(StringFind(pos.Comment(), "Backup", 0) < 0) continue;

      datetime openTime = (datetime)pos.TimeOpen();
      if(oldest == 0 || openTime < oldest)
         oldest = openTime;
   }
   return oldest;
}

//--- Returns the open time of the oldest position (any type) for this EA.
//    Returns 0 if no positions are open.
datetime GetOldestPositionOpenTime(int magic)
{
   datetime oldest = 0;
   CPositionInfo pos;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != magic) continue;

      datetime openTime = (datetime)pos.TimeOpen();
      if(oldest == 0 || openTime < oldest)
         oldest = openTime;
   }
   return oldest;
}

//--- Backup drawdown timer check.
//    Returns true when: backup has been open >= DrawdownTimerMinutes AND basket is in net loss.
//    Logs once on trigger with open time, deadline, elapsed minutes, and net PnL.
bool CheckBackupDrawdownTimer(int magic, double netBasketPnL)
{
   if(!ActivateDrawdownTimer) return false;

   datetime oldestBackup = GetOldestBackupOpenTime(magic);
   if(oldestBackup == 0) return false;

   long elapsedMinutes = (TimeCurrent() - oldestBackup) / 60;
   if(elapsedMinutes < DrawdownTimerMinutes) return false;

   if(netBasketPnL >= 0) return false;    // basket recovering — do not interrupt

   datetime deadline = oldestBackup + (datetime)(DrawdownTimerMinutes * 60);
   Print("BACKUP_TIMEOUT: Backup open since ", TimeToString(oldestBackup),
         ". Deadline was ", TimeToString(deadline),
         ". Elapsed: ", elapsedMinutes, " min",
         ". Net PnL: ", DoubleToString(netBasketPnL, 2),
         ". Closing all positions.");
   return true;
}

//--- Max trade time check.
//    Returns true when the oldest position has been open >= MaxTradeTimeMinutes.
//    Fires regardless of basket P&L. Logs once on trigger.
bool CheckMaxTradeTime(int magic)
{
   if(!EnableMaxTradeTime) return false;

   datetime oldestPos = GetOldestPositionOpenTime(magic);
   if(oldestPos == 0) return false;

   long elapsedMinutes = (TimeCurrent() - oldestPos) / 60;
   if(elapsedMinutes < MaxTradeTimeMinutes) return false;

   datetime deadline = oldestPos + (datetime)(MaxTradeTimeMinutes * 60);
   Print("MAX_TRADE_TIME: Oldest position open since ", TimeToString(oldestPos),
         ". Deadline was ", TimeToString(deadline),
         ". Elapsed: ", elapsedMinutes, " min",
         ". Closing all positions.");
   return true;
}
```

### Changes to `prism.mq5`

**`OnTick()` — insert after `prepare()`, before trade logic:**

```mql5
void OnTick()
{
   prepare();

   // ── Drawdown timer checks (rm_013) ───────────────────────────────────────
   double netPnL = _stats.totalProfit + _stats.totalLoss;
   if(CheckBackupDrawdownTimer(_MAGIC, netPnL)) { closeAll(); return; }
   if(CheckMaxTradeTime(_MAGIC))                { closeAll(); return; }

   // ── Existing controls ────────────────────────────────────────────────────
   if(CloseAll) { closeAll(); return; }

   // ... rest of OnTick
}
```

**`UpdateDisplay()` — add countdown timers to HUD:**

The HUD shows the time remaining on active timers so the trader can see the deadline without checking the Experts log.

```mql5
// Backup timer countdown
if(ActivateDrawdownTimer)
{
   datetime oldestBackup = GetOldestBackupOpenTime(_MAGIC);
   if(oldestBackup > 0)
   {
      long elapsedMin  = (TimeCurrent() - oldestBackup) / 60;
      long remainMin   = DrawdownTimerMinutes - elapsedMin;
      datetime deadline = oldestBackup + (datetime)(DrawdownTimerMinutes * 60);

      if(remainMin > 0)
         display += " BkpTimer: " + IntegerToString((int)remainMin) + "m ("
                  + TimeToString(deadline, TIME_MINUTES) + ")";
      else
         display += " BkpTimer: EXPIRED";
   }
}

// Max trade time countdown
if(EnableMaxTradeTime)
{
   datetime oldestPos = GetOldestPositionOpenTime(_MAGIC);
   if(oldestPos > 0)
   {
      long elapsedMin  = (TimeCurrent() - oldestPos) / 60;
      long remainMin   = MaxTradeTimeMinutes - elapsedMin;
      datetime deadline = oldestPos + (datetime)(MaxTradeTimeMinutes * 60);

      if(remainMin > 0)
         display += " MaxAge: " + IntegerToString((int)remainMin) + "m ("
                  + TimeToString(deadline, TIME_MINUTES) + ")";
      else
         display += " MaxAge: EXPIRED";
   }
}
```

The HUD format shows both minutes remaining and the wall-clock deadline, for example:
```
BkpTimer: 847m (Tue 14:00)   MaxAge: 2413m (Thu 09:00)
```

### No new persistent state variables required

Both checks scan live MT5 position data (`POSITION_TIME`) on each tick rather than maintaining static timestamps. This means:

- **MT5-restart safe:** If the EA restarts mid-basket, the timers continue from the actual position open times, not from zero.
- **No persistence needed:** Unlike `g_locked_profit` in rm_012, these values are always computable from live positions.
- **No `OnInit()` changes:** No handles or state to initialise.

---

## 8. Interaction with Existing Systems

| System | Interaction |
|--------|-------------|
| **Backup system (`TriggerBackSystem`)** | The backup system opens trades when equity drops below the threshold. `ActivateDrawdownTimer` starts its clock at that point. The two settings work sequentially: backup system detects the drawdown, timer limits how long the backup is allowed to run in a losing state. |
| **`SafeExits`** | `SafeExits` closes on trend reversal only when the basket is in profit. The backup timer closes when the basket is in **loss** and time has expired. They are complementary: `SafeExits` handles profitable reversals, the backup timer handles prolonged losing positions. |
| **`ContinueTrading`** | After a timer-triggered close, the existing `SleepSeconds` gap and signal conditions govern re-entry. The time elapsed during the drawdown (typically 24+ hours for the backup timer) acts as a natural separation. No additional cooldown is imposed by this module. |
| **`CloseAll` (manual)** | `CloseAll` is checked after the timer checks. Both lead to `closeAll()`. Order is not significant since `CloseAll` is a manual override. |
| **rm_012 Capital Partitioning** | A timer-triggered close crystallises a loss. This reduces the balance used in rm_012's capital calculations on the next basket. Profit lock-in milestones are unaffected (they respond to position close events, which fire normally via `closeAll()`). |
| **rm_005 Drawdown Circuit Breaker** | rm_005 monitors daily drawdown at a session level. The backup timer is basket-level and more targeted. Both can be active simultaneously. In most catastrophic scenarios the backup timer fires well before rm_005's daily drawdown limit is breached — rm_005 remains a deeper backstop. |
