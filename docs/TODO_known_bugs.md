# Prism vs Original — Logic Diff & Known Bugs

Analysis of behavioural differences found between `source/original.mq5` (reference) and
`source/prism.mq5` (refactored port). When running both on identical data with the same
settings, results diverge due to the issues below.

---

## CRITICAL — Default Parameter Values

The two files shipped with completely different default input values. Any backtest comparison
must use identical values manually, as the defaults are not equivalent.

| Parameter | `original.mq5` | `prism.mq5` | Notes |
|---|---|---|---|
| `MarginUsage` | `0.1` | `0.3` | 3× lot size |
| `BackupMargin` | `0.01` | `0.1` | 10× backup lots |
| `TriggerBackSystem` | `0.999` | `0.95` | Backup fires at 5% drawdown vs 0.1% |
| `DailyGrowth` | `0.015` | `0.06` | 4× higher daily target |
| `StopGrowth` | `0.005` | `0.05` | 10× higher stop threshold |
| `SleepSeconds` | `14400` | `18000` | 1 hr longer minimum sleep |
| `TradeFriday` | `false` | `true` | Friday trading on by default |
| `Aggressive` | `false` | `true` | Aggressive backup mode on by default |
| `AllowHedge` | `false` | `true` | Hedging on by default |
| `MaxTrades` | `7` | `8` | One extra trade allowed |
| `SignalA` | `true` | `false` | Signal A disabled |
| `SignalC` | `true` | `false` | Signal C disabled |
| `EnableCalendar` | `false` | `true` | Calendar filter on by default |
| `EnableStop` | `false` | `true` | Long-term stop on by default |
| `QueryHistory` | `14` | `2` | Far fewer history trades analysed |

**Fix:** Use identical input values in both tests before comparing results.

---

## HIGH — `basketNumberType` Never Assigned in Original

### Root cause

In `original.mq5`, `basketNumberType` is declared as `int basketNumberType = -1` and is
**never assigned again anywhere in the file**. In `sendOpen()` only `openType` is updated;
`basketNumberType` stays `-1` forever.

In `prism.mq5`, `_basketNumberType` is correctly updated inside `OpenPosition()` after every
successful trade:

```mql5
// prism.mq5 — OpenPosition()
_basketNumberType = (int)POSITION_TYPE_BUY;   // or SELL
```

### Cascade effect 1 — SafeExits is dead code in the original

`managePositions()` safe-exit condition in `original.mq5`:

```mql5
((bullish && basketNumberType == (int)POSITION_TYPE_SELL) ||   // -1 == 1 → always FALSE
 (bearish && basketNumberType == (int)POSITION_TYPE_BUY))      // -1 == 0 → always FALSE
```

Because `basketNumberType` is permanently `-1`, this entire branch is unreachable.
`SafeExits = true` has **zero effect** in the original. The EA will never close a basket
on trend reversal.

In Prism, because `_basketNumberType` is set correctly, `SafeExits` works as intended.

### Cascade effect 2 — `basketCount` always resets to 0 before every trade

The condition `if(basketNumberType != POSITION_TYPE_BUY) basketCount = 0` is always true
(`-1 != 0`) so `basketCount` is reset to 0 before **every single BUY attempt**, meaning
`MaxTrades` is effectively never enforced — the gate `basketCount < MaxTrades` always passes
because `basketCount` was just zeroed. Prism correctly only resets `_basketCount` when the
trade direction changes.

### Fix options

- **Keep Prism behaviour** (recommended): `_basketNumberType` is correctly maintained. Prism
  is the fixed version here.
- **Reproduce original bug**: Remove the `_basketNumberType = (int)POSITION_TYPE_BUY/SELL`
  lines from `OpenPosition()`. Not recommended.

---

## MEDIUM — `bullish`/`bearish` State Persists Across Ticks in Original

### Root cause

**`original.mq5` `prepareTrend()`:**

```mql5
if(eADXMain < ADXMain)
{
   rangingMarket = true;
   bullish = false;   // ← ONLY reset here, when market is ranging
   bearish = false;
}
else
{
   rangingMarket = false;
   // If no signal fires this tick, bullish/bearish keep last tick's values
}
```

**`prism.mq5` `AnalyzeTrendSignals()`:**

```mql5
// Reset unconditionally at the top, EVERY tick
conditions.bullish = false;
conditions.bearish = false;
conditions.rangingMarket = false;

if(indicators.ADXMain < adxThreshold)
{
   conditions.rangingMarket = true;
   return;
}
// signal evaluation follows
```

### Behavioural impact

In the original, once a signal fires (`bullish = true`), that state persists on every
subsequent tick as long as the market stays trending — even if no signal condition is
currently satisfied. Prism requires signals to re-qualify every single tick.

Scenario where they diverge:
1. Signal fires on tick N → `bullish = true`
2. Ticks N+1 … N+k: market still trending but signal conditions not met
3. Original: still `bullish = true` → can still open trades (subject to SleepSeconds)
4. Prism: `bullish = false` → no new trades

### Fix in Prism (to match original behaviour)

Move the `bullish`/`bearish` reset inside the ranging branch only:

```mql5
// AnalyzeTrendSignals() in PrismSignals.mqh
// Replace the current top-of-function reset block with:

conditions.rangingMarket = false;

if(indicators.ADXMain < adxThreshold)
{
   conditions.rangingMarket = true;
   conditions.bullish = false;   // only clear when ranging
   conditions.bearish = false;
   return;
}

// signal evaluation follows — prior state preserved if nothing fires
```

---

## NONE — Confirmed Equivalent (no fix needed)

These differences look suspicious but are logically identical:

| # | Description | Verdict |
|---|---|---|
| Friday condition | `(dayOfWeek!=5 && !TF) \|\| TF` vs `dayOfWeek!=5 \|\| TF` | Boolean equivalents |
| `SendBackup` guard | Different structure | Functionally equivalent with `MaxStartTrades=1` |
| Backup trigger threshold | `>= MaxStartTrades` vs `>= 1` | `MaxStartTrades` is always 1 |
| Open position guard | `< MaxStartTrades \|\| MaxStartTrades==0` vs `< 1` | Equivalent |
| Individual exit guard | `<= MaxStartTrades` vs `<= 1` | Equivalent |
| `SafeGrowth` structure | Two nested `if` vs one `if(A && B)` | Identical |
| `symbolHistory` type | `double` in original vs `int` in Prism | No impact for integer values |
| `signalComment` stale | Not cleared on no-signal ticks in Prism | Never reaches order comment |

---

## Recommended Fix Order

1. **Align all input parameters** for both test runs first — this alone will produce much
   closer results.
2. **Fix `bullish`/`bearish` reset timing** in `AnalyzeTrendSignals()` — move the reset
   inside the ranging branch only (see code snippet above).
3. **Decide on `_basketNumberType`** — Prism's implementation is intentionally correct.
   If the goal is to reproduce the original's exact results, the fix in step 2 plus matching
   parameters should be sufficient; removing `_basketNumberType` updates would also be needed
   to exactly replicate the original's broken `SafeExits` / basket-count behaviour, but this
   is not recommended.
