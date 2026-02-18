# RM-011: Profit Lock-In

**Status:** Draft
**Phase:** 3
**Depends on:** rm_007 (Trading Pocket — integrates naturally when both are enabled)

---

## 1. Problem

All profits remain in the active trading balance indefinitely. As the account grows, previous gains become part of the base for future position sizing — meaning they are fully re-risked on subsequent trades. A single bad week can erase months of careful gains.

This is the "ratchet effect" in reverse: profit does not lock in, but losses reduce the base for future profits.

**Example — months of gains erased:**

```
Jan: $2,000 → $2,800  (+$800 profit, 40% growth)
Feb: $2,800 → $3,900  (+$1,100 profit, 39% growth)
Mar: $3,900 → $5,200  (+$1,300 profit, 33% growth)
Apr: Flash crash → $5,200 → $520 (90% loss — all 15 months of gains gone)

Without lock-in: $520 remaining (26% of starting balance)
```

If profits had been progressively locked in, some portion would be protected from the April crash.

---

## 2. Root Cause

There is no mechanism to track cumulative profit separately from the active trading base. The `dailyGrowth` variable tracks intra-day profit resets but does not permanently segregate any amount from future position sizing.

The EA also has no persistent milestone tracking — if MT5 restarts, all intra-session growth tracking resets.

---

## 3. Proposed Solution

At configurable balance milestones, transfer a defined percentage of the cumulative profit into a `g_locked_profit` variable. This locked amount is subtracted from the active trading base when computing lot sizes.

When combined with rm_007 (Trading Pocket), the locked profit reduces the available base for the pocket calculation — keeping the effective trading capital bounded even as total balance grows.

### Parameters

```mql5
input group "════════ RISK: PROFIT LOCK-IN ════════";
input bool   EnableProfitLockIn     = true;    // Lock in a portion of profits at balance milestones
input double LockInStartBalance     = 3000;    // First milestone — begin locking profits at this balance
input double LockInBalanceStep      = 2000;    // Lock in profits at every $2,000 increase above start
input double LockInPercent          = 0.30;    // % of cumulative profit to lock in at each milestone (30%)
input double InitialBalance         = 2000;    // Balance at the time the EA was first started
                                               // (used to calculate cumulative profit)
```

### Behaviour

**`CheckProfitMilestones()`** — called after every position close:

1. Read `currentBalance = accountInfo.Balance()`.
2. Determine current milestone tier: `tier = floor((currentBalance - LockInStartBalance) / LockInBalanceStep)`.
3. If `tier > g_last_processed_milestone_tier`:
   - Calculate cumulative profit: `profit = currentBalance - InitialBalance - g_locked_profit`.
   - If profit > 0: lock in `amountToLock = profit × LockInPercent`.
   - `g_locked_profit += amountToLock`.
   - `g_last_processed_milestone_tier = tier`.
   - Log: "Profit lock-in: $X locked at balance $Y. Total locked: $Z."

**Interaction with `CalculateLotSize()`** (standalone, without rm_007):

```mql5
double activeTradingBase = accountInfo.Balance() - g_locked_profit;
lotSize = (activeTradingBase * MarginUsage / marginRequirement) * BaseLotSize;
```

**Interaction with rm_007 (Trading Pocket) when both enabled:**

```mql5
double unlockedBalance = accountInfo.Balance() - g_locked_profit;
double tradingCapital  = Clamp(unlockedBalance * TradingPocketPct,
                               MinTradingCapital, MaxTradingCapital);
```

---

## 4. Examples

### Example A — First milestone

```
InitialBalance = $2,000, LockInStartBalance = $3,000, LockInBalanceStep = $2,000
LockInPercent = 0.30

Balance reaches $3,000 (first milestone):
  Cumulative profit = $3,000 - $2,000 - $0 (nothing locked yet) = $1,000
  Lock: $1,000 × 0.30 = $300
  g_locked_profit = $300
  Active trading base = $3,000 - $300 = $2,700

If a crash followed immediately:
  Worst case loss = from $2,700 base
  g_locked_profit ($300) is never at risk
```

### Example B — Multiple milestones

```
Milestones trigger at: $3,000, $5,000, $7,000, $9,000...

At $5,000 balance (second milestone):
  Profit since start = $5,000 - $2,000 - $300 (already locked) = $2,700
  Lock: $2,700 × 0.30 = $810
  g_locked_profit = $300 + $810 = $1,110
  Active base = $5,000 - $1,110 = $3,890

At $7,000 balance (third milestone):
  Profit since start = $7,000 - $2,000 - $1,110 = $3,890
  Lock: $3,890 × 0.30 = $1,167
  g_locked_profit = $1,110 + $1,167 = $2,277
  Active base = $7,000 - $2,277 = $4,723
```

### Example C — Black swan after multiple milestones

```
Balance reaches $10,000, g_locked_profit = $2,800
Active base = $10,000 - $2,800 = $7,200

Crash: active base fully wiped
Remaining balance = g_locked_profit = $2,800 (still > initial $2,000 ✓)
Account survives. Can restart trading from $2,800 base.
```

### Example D — Combined with Trading Pocket (rm_007)

```
Balance = $10,000, g_locked_profit = $2,800
unlockedBalance = $10,000 - $2,800 = $7,200
tradingCapital = $7,200 × 0.30 = $2,160 (within [$1,000, $5,000] bounds)

Lot size based on $2,160 (not $10,000)
Max potential trading loss: $2,160 (21.6% of total balance)
Locked profit ($2,800) is always safe.
```

---

## 5. Code Impact

### New state (in `PrismRiskManager.mqh`)

```mql5
static double g_locked_profit              = 0.0;
static int    g_last_processed_milestone_tier = -1;
```

### New functions (in `PrismRiskManager.mqh`)

```mql5
// Checks if balance has crossed a new milestone and locks in profit if so.
// Call after any position close.
void CheckProfitMilestones(double currentBalance);

// Returns the portion of balance that is locked and should not be used for sizing.
double GetLockedProfit();

// Returns the active trading base (balance minus locked profit).
// Used by CalculateLotSize() when rm_007 is not enabled.
double GetActiveTradingBase(double accountBalance);
```

### Changes to `prism.mq5`

In `CloseAllPositions()`, after successful position close:

```mql5
if(EnableProfitLockIn)
   CheckProfitMilestones(accountInfo.Balance());
```

In `CalculateLotSize()`:

```mql5
double tradingBase;

if(EnableTradingPocket)
{
   double unlockedBalance = accountInfo.Balance() - GetLockedProfit();
   tradingBase = CalculateTradingCapital(unlockedBalance);
}
else if(EnableProfitLockIn)
{
   tradingBase = GetActiveTradingBase(accountInfo.Balance());
}
else
{
   tradingBase = accountInfo.Balance();
}

lotSize = NormalizeDouble((tradingBase * MarginUsage / marginRequirement) * BaseLotSize, 2);
```

In `UpdateDisplay()`:

```mql5
if(EnableProfitLockIn)
   display += " Locked: $" + DoubleToString(GetLockedProfit(), 0);
```

### Integration point

`CloseAllPositions()` (trigger) and `CalculateLotSize()` (effect) in `prism.mq5`.

---

## 6. Modular Design

Controlled by `EnableProfitLockIn` flag.

- **`false`** (disabled): `GetLockedProfit()` returns 0. `GetActiveTradingBase()` returns full balance. Identical to current behaviour.
- **`true`** (enabled): Milestone tracking is active. Locked profit accumulates over time and is never returned to the active trading base.

When used together with rm_007 (Trading Pocket), the locked profit is subtracted before the pocket percentage is applied — ensuring that the pocket operates only on truly available capital, not on funds already committed to protection.

The feature is directionally additive: locked profit can only increase, never decrease during a trading session. If MT5 restarts, `g_locked_profit` resets to zero — see Open Questions for persistence.

---

## 7. Open Questions

1. **`InitialBalance` as an input:** The user must manually set `InitialBalance` to the balance at the time they first ran the EA. If they forget, profit calculations will be incorrect. Can this be solved by reading the balance on `OnInit()` and storing it — only using the input as an override?

2. **Persistence across restarts:** `g_locked_profit` is a static variable that resets when MT5 restarts or the EA is removed. Critical for long-term operation. Should this value be written to a file (using `FileOpen` / `FileWrite`) and reloaded on `OnInit()`?

3. **Milestone frequency:** The step-based approach (lock in at every $2,000 increase) means milestones become less frequent in dollar terms as the account grows (the same $2,000 step is a smaller percentage of a $20,000 account). Should the step be percentage-based instead (e.g. lock in at every 20% balance increase)?

4. **What if the account falls back below a milestone?** If the balance drops from $7,000 back to $4,500, the Tier 2 milestone at $5,000 has already been processed. Should it re-trigger when the balance crosses $5,000 again on the way back up?

5. **Interaction with `DailyGrowth` resets:** The `dailyGrowth` variable in `prism.mq5` resets every `RefreshHours`. Should `CheckProfitMilestones()` be called during daily resets as well, or only on individual position closes?
