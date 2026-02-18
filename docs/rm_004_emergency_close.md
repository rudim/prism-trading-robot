# RM-004: Emergency Close

**Status:** Draft
**Phase:** 1 (Critical — implement first)
**Depends on:** None

---

## 1. Problem

There is no automated last-resort shutdown. When a market event moves strongly against all open positions, the account bleeds until the broker issues a margin call. By the time a margin call fires, the loss is already catastrophic — typically 70–90% of balance — and the broker selects which positions to close at the worst possible moment.

The existing `CloseAll` input parameter closes positions on the next tick but requires the trader to be actively monitoring and manually toggling the setting in MT5. In a fast-moving market this is too slow.

**Example — without emergency close:**

```
$5,000 balance, 8 positions open, 1:100 leverage
Market gaps 200 pips against all positions during off-hours news

Loss per position: 200 × $10 × 0.49 = $980
Total loss (8 positions): $7,840
Account equity: $5,000 - $7,840 = -$2,840 (NEGATIVE EQUITY)
Broker closes positions at market during gap — execution is poor
Result: Account balance potentially wiped below zero, subject to broker policy
```

---

## 2. Root Cause

There are three gaps in the current protection:

1. **No automated trigger:** Protection only fires if the trader manually sets `CloseAll = true`.
2. **No equity floor:** Nothing monitors the equity-to-balance ratio or the margin level.
3. **No trading halt:** Even after a catastrophic loss, if the EA remains running it will attempt to open new positions on the next tick.

---

## 3. Proposed Solution

Implement an `EmergencyCloseAll()` function that:
- Closes all open positions for the current symbol
- Sets a persistent halt flag that blocks any new trade opening
- Logs the reason and alerts the trader

Triggers fire automatically when any of these conditions are detected:

| Trigger | Default Threshold | Reasoning |
|---------|------------------|-----------|
| Drawdown from peak | 35% | Last resort before circuit breaker fails |
| Equity / Balance ratio | < 60% | Positions are bleeding faster than normal losses |
| Margin level | < 150% | Approaching broker margin call zone |

The manual `CloseAll` input remains but is supplemented — not replaced.

### Parameters

```mql5
input group "════════ RISK: EMERGENCY CLOSE ════════";
input bool   EnableEmergencyClose    = true;   // Enable automated emergency position close
input double EmergencyDrawdownPct    = 0.35;   // Trigger if peak-to-current DD exceeds this (0.35 = 35%)
input double EmergencyEquityRatio    = 0.60;   // Trigger if equity / balance falls below this
input double EmergencyMarginLevel    = 150;    // Trigger if margin level falls below this %
```

### Behaviour

**`CheckEmergencyConditions()`** — called at the start of every `OnTick()`:

1. If `g_emergency_halt` is already true: return immediately (halt is persistent until EA is restarted).
2. Calculate current drawdown: `dd = (g_peak_balance - equity) / g_peak_balance`.
3. Calculate equity ratio: `equityRatio = equity / balance`.
4. Read margin level: `marginLevel = accountInfo.MarginLevel()` (0 if no open positions).
5. If any threshold is breached: call `EmergencyCloseAll(reason)`.

**`EmergencyCloseAll(reason)`**:

1. Set `g_emergency_halt = true`.
2. For each open position matching symbol and magic: call `trade.PositionClose(ticket)`.
3. Print the reason and balance to the Experts log.
4. Send MT5 push notification (if enabled by broker).
5. Update peak balance tracking to prevent false re-triggers after halt is cleared.

**`CanOpenTrade()`** — checked in `OpenPosition()` and `SendBackup()`:

```mql5
if(g_emergency_halt) return false;
```

---

## 4. Examples

### Example A — Drawdown trigger

```
Starting balance: $5,000
Peak balance reached: $6,200
Current equity (open losses): $3,900
Drawdown: ($6,200 - $3,900) / $6,200 = 37.1% > EmergencyDrawdownPct (35%)

→ EmergencyCloseAll("DRAWDOWN") fires
→ All positions closed at market
→ g_emergency_halt = true
→ EA stops trading
→ Remaining balance: approximately $3,900 (63% of peak — painful but survivable)
```

### Example B — Equity floor trigger

```
Balance: $5,000 (no recent closed trades, so peak = balance)
Open floating loss: $2,200
Equity: $5,000 - $2,200 = $2,800
Equity ratio: $2,800 / $5,000 = 0.56 < EmergencyEquityRatio (0.60)

→ EmergencyCloseAll("EQUITY_FLOOR") fires
→ Locks in approximately $2,800 before it can worsen
```

### Example C — Margin level trigger

```
Balance: $5,000
Margin used (8 positions): $2,000
Equity: $2,800
Margin level: $2,800 / $2,000 × 100 = 140% < EmergencyMarginLevel (150%)

→ EmergencyCloseAll("MARGIN_LEVEL") fires before broker margin call
→ EA selects which positions to close (hopefully at better prices than broker auto-close)
```

### Example D — False trigger prevention

```
g_peak_balance starts at 0 (no trades yet)
Balance: $5,000, Equity: $4,800 (one open position)
Drawdown: ($5,000 - $4,800) / $5,000 = 4% → no trigger
```

Peak balance is updated each tick when `equity > g_peak_balance`.

---

## 5. Code Impact

### New state (in `PrismRiskManager.mqh`)

```mql5
static bool   g_emergency_halt  = false;
static double g_peak_balance    = 0;
```

### New functions (in `PrismRiskManager.mqh`)

```mql5
// Evaluates all emergency conditions. Calls EmergencyCloseAll() if any threshold is breached.
void CheckEmergencyConditions();

// Closes all positions for current symbol + magic. Sets g_emergency_halt.
void EmergencyCloseAll(string reason);

// Returns false if emergency halt is active or if CloseAll input is set.
bool CanOpenTrade();
```

### Changes to `prism.mq5`

In `OnTick()`, before any other logic:

```mql5
void OnTick()
{
   PrepareAll();

   if(CloseAll || !CanOpenTrade())
   {
      if(CloseAll) CloseAllPositions();
      return;
   }
   // ... rest of OnTick
}
```

In `PrepareAll()` or at the top of `OnTick()`:

```mql5
if(EnableEmergencyClose) CheckEmergencyConditions();
```

Update `g_peak_balance` in `CalculateLotSize()` or `PrepareAll()`:

```mql5
double equity = accountInfo.Equity();
if(equity > g_peak_balance) g_peak_balance = equity;
```

In `OpenPosition()` and `SendBackup()`:

```mql5
if(!CanOpenTrade()) return;
```

### Integration point

`OnTick()` — very first call after `PrepareAll()`. The halt check in `CanOpenTrade()` is a guard used in both `OpenPosition()` and `SendBackup()`.

---

## 6. Modular Design

Controlled by `EnableEmergencyClose` flag.

- **`false`** (disabled): `CheckEmergencyConditions()` is not called. `CanOpenTrade()` always returns `true` (ignoring the halt flag). Behaviour is identical to current code.
- **`true`** (enabled): Thresholds are monitored every tick. Halt is sticky until EA restart.

The `g_peak_balance` tracking is required even when disabled (it is used by rm_005 Drawdown Circuit Breaker). The peak tracking can be separated into a shared utility function.

---

## 7. Open Questions

1. **Restart behaviour:** Once `g_emergency_halt = true`, it persists until the EA is removed and re-attached. Is this the right behaviour, or should it reset after a cooling-off period (similar to rm_005's `DrawdownRecoveryHours`)?

2. **Notification channel:** Should `EmergencyCloseAll()` use `SendMail()`, `SendNotification()`, or both? Push notifications require broker/MT5 configuration that not all traders have set up.

3. **Partial close option:** Rather than closing all positions, could the emergency trigger close only losing positions while keeping profitable ones open? This is more complex but may preserve some upside during recoveries.

4. **Interaction with backup system:** The backup system is specifically designed to trade during drawdowns. Should the emergency close be coordinated with — or take precedence over — `BackupWithCalendarCheck()`?
