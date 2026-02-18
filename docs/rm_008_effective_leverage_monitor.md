# RM-008: Effective Leverage Monitor

**Status:** Draft
**Phase:** 2
**Depends on:** rm_003 (shares leverage reading pattern)

---

## 1. Problem

Account leverage (e.g. 1:100) is only one dimension of exposure. The number of simultaneously open positions is a multiplier on top of that leverage. The EA's `MaxTrades` setting allows up to 7 simultaneous positions — so the actual exposure can be far larger than account leverage alone suggests.

**Effective leverage = account leverage × total lots open / base lot**

| Account Leverage | Open Positions | Lots Each | Effective Leverage | Wipeout move |
|-----------------|----------------|-----------|-------------------|--------------|
| 1:100 | 1 | 0.49 | 1:4,900 | 204 pips |
| 1:100 | 4 | 0.49 | 1:19,600 | 51 pips |
| 1:100 | 7 | 0.49 | 1:34,300 | 29 pips |
| 1:500 | 7 | 2.43 | 1:170,100 | 6 pips |
| 1:500 | 7 | 12.14 | 1:850,000 | 1.2 pips |

At 1:500 leverage with 7 large positions open, a normal spread widening event can trigger a margin call. The EA has no awareness of this total exposure.

*Note: The "effective leverage" formula above is a simplified risk metric — account leverage in the traditional sense describes margin efficiency, but colloquially here it refers to total notional exposure divided by equity.*

---

## 2. Root Cause

The EA evaluates each position decision in isolation. `OpenPosition()` checks `MaxTrades` and `marginLevel`, but does not compute the total notional exposure across all open positions relative to equity. The risk compounds silently as positions accumulate.

---

## 3. Proposed Solution

Calculate total open exposure in lots each tick. Express this as a ratio of account equity (effective leverage). Warn when it exceeds a soft limit; block new positions when it exceeds a hard limit.

### Parameters

```mql5
input group "════════ RISK: EFFECTIVE LEVERAGE MONITOR ════════";
input bool EnableEffectiveLeverageCheck  = true;   // Monitor total position exposure
input int  WarnEffectiveLeverage         = 500;    // Log warning above this effective leverage
input int  MaxEffectiveLeverage          = 1000;   // Block new trades above this effective leverage
```

### Behaviour

**`GetEffectiveLeverage()`** — called in `CanOpenTrade()` before allowing a new position:

1. Get total open lots for this symbol and magic: `totalLots = positions.buyLots + positions.sellLots`.
2. Get account leverage: `int accountLeverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE)`.
3. Get current equity: `double equity = accountInfo.Equity()`.
4. Notional value of all open positions: `notional = totalLots × contractSize × currentPrice`.
5. Effective leverage: `effectiveLeverage = notional / equity`.
   - Simplified shortcut: `effectiveLeverage = (totalLots / BaseLotSize) × accountLeverage × (marginRequirement / equity)`.
6. If `effectiveLeverage > WarnEffectiveLeverage`: log warning.
7. If `effectiveLeverage > MaxEffectiveLeverage`: return false from `CanOpenTrade()`.

**Every tick** — log the current effective leverage to the HUD so the trader can see it.

---

## 4. Examples

### Example A — Single position, low effective leverage

```
Balance/Equity = $5,000
Account leverage = 1:100
1 BUY position, 0.49 lots
Contract size = 100,000 units, price = 1.0850

Notional = 0.49 × 100,000 × 1.0850 = $53,165
Effective leverage = $53,165 / $5,000 = 10.6:1

→ Well below any warning threshold — no action
```

### Example B — Multiple positions approach soft limit

```
Equity = $5,000
Account leverage = 1:100
6 BUY positions, 0.49 lots each = 2.94 lots total

Notional = 2.94 × 100,000 × 1.0850 = $318,990
Effective leverage = $318,990 / $5,000 = 63.8:1 → below WarnEffectiveLeverage (500)

Still safe — effective leverage is high in absolute terms but within tolerance.
```

### Example C — High-leverage account triggers warning

```
Equity = $5,000
Account leverage = 1:500
3 BUY positions, 2.43 lots each = 7.29 lots total

Notional = 7.29 × 100,000 × 1.0850 = $790,965
Effective leverage = $790,965 / $5,000 = 158:1

→ 158 > WarnEffectiveLeverage (500)? No — still OK.

6 positions at 2.43 lots: 14.58 lots total
Notional = $1,581,930
Effective leverage = $1,581,930 / $5,000 = 316:1 → warning at 316

7 positions: effective leverage = 369:1 → still below 500 warn threshold
```

### Example D — MaxEffectiveLeverage blocks a new trade

```
Equity = $3,200 (in drawdown)
Account leverage = 1:500
6 positions, 2.43 lots each = 14.58 lots

Notional = 14.58 × 100,000 × 1.0850 = $1,581,930
Effective leverage = $1,581,930 / $3,200 = 494:1

→ Below MaxEffectiveLeverage (1000) — 7th trade would be:
→ 7 positions = 17.01 lots → $1,845,585 / $3,200 = 576:1 → below 1000 — still allowed

The monitor is most useful when equity is reduced (in drawdown) — effective leverage spikes even with the same lot sizes.
```

**Note:** The threshold defaults (WarnEffectiveLeverage=500, MaxEffectiveLeverage=1000) are conservative starting points that need calibration against the specific leverage and balance range in use. See Open Questions.

---

## 5. Code Impact

### New function (in `PrismRiskManager.mqh`)

```mql5
// Returns the current effective leverage across all open positions for this EA.
// Returns 0 if no positions are open (nothing to measure).
double GetEffectiveLeverage(const PositionStats &positions,
                            double marginRequirement,
                            double accountEquity);

// Returns true if effective leverage is below the hard limit.
// Logs a warning if above the soft limit.
bool IsEffectiveLeverageSafe(const PositionStats &positions,
                             double marginRequirement,
                             double accountEquity);
```

### Changes to `prism.mq5`

In `OpenPosition()` and `SendBackup()`, before placing the trade:

```mql5
if(EnableEffectiveLeverageCheck &&
   !IsEffectiveLeverageSafe(positions, marginRequirement, accountInfo.Equity()))
{
   Print("Skipping trade: effective leverage limit reached");
   return;
}
```

In `UpdateDisplay()` — add to HUD:

```mql5
double effLev = GetEffectiveLeverage(positions, marginRequirement, accountInfo.Equity());
display += " EffLev: " + DoubleToString(effLev, 0) + ":1";
```

### Integration point

`OpenPosition()` and `SendBackup()` in `prism.mq5` — checked immediately before calling `trade.PositionOpen()`. The check uses `positions` (already populated by `AnalyzePositions()` in `PrepareAll()`) and `marginRequirement` (already calculated in `CalculateLotSize()`).

---

## 6. Modular Design

Controlled by `EnableEffectiveLeverageCheck` flag.

- **`false`** (disabled): `IsEffectiveLeverageSafe()` returns true. No checks, no HUD display. Identical to current behaviour.
- **`true`** (enabled): Both the warning and hard block are active.

Re-uses data already computed each tick (`positions`, `marginRequirement`, `accountInfo.Equity()`) — no additional data fetching required.

Naturally combines with rm_003 (Leverage Normalisation): rm_003 reduces individual position sizes; rm_008 limits the total stack of positions. Together they bound both the per-trade and total-portfolio exposure.

---

## 7. Open Questions

1. **Threshold calibration:** The default `MaxEffectiveLeverage = 1000` is a starting point. What is the right value given the strategy's typical position count and leverage range? This needs backtesting against the wipeout scenarios described in `analysis_leverage_and_trading_pocket.md`.

2. **Effective leverage formula:** The simplified calculation using `marginRequirement` as a proxy for notional value may not be accurate for all symbol types (indices, metals, energies). Should the full notional calculation (`totalLots × contractSize × price`) be used instead?

3. **Directional netting:** If there are 3 BUY and 3 SELL positions simultaneously (hedged), should the effective leverage use gross lots (6) or net lots (0)? The gross approach is more conservative and correct for margin purposes.

4. **Per-trade or aggregate check:** Should the check fire when the *current aggregate* exceeds the limit, or when *adding one more position* would push it over? The current design uses the aggregate — it checks before adding, so it fires when the next trade would breach the limit.
