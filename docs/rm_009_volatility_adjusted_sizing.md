# RM-009: Volatility-Adjusted Position Sizing

**Status:** Draft
**Phase:** 3
**Depends on:** None (uses existing ATR from `PrismIndicators.mqh`)

---

## 1. Problem

The current lot-size formula uses the account balance and margin requirements — neither of which reflects current market volatility. A position opened during a calm, low-volatility period carries the same dollar risk as one opened during a high-volatility news event, even though the actual price range per unit of time is radically different.

**Example — same lot size, very different risk:**

| Condition | ATR (pips) | Lot Size | Expected move in 1 hour | Expected P&L swing |
|-----------|-----------|----------|------------------------|---------------------|
| Quiet session | 3 | 0.49 lots | 3–10 pips | $15–$49 |
| Active London | 12 | 0.49 lots | 15–30 pips | $73–$147 |
| NFP release | 80 | 0.49 lots | 50–150 pips | $245–$735 |
| Flash crash | 250 | 0.49 lots | 200–400 pips | $980–$1,960 |

The same lot size during an NFP release can produce 15–40× the volatility of a quiet session. The EA should recognise this and size down during high-volatility periods.

---

## 2. Root Cause

The `CalculateLotSize()` function reads `indicators.ATR` but uses it only for `slippage` calculation:

```mql5
slippage = NormalizeDouble((indicators.ATR / pipPoints) * DynamicSlippage, 1);
```

The ATR is not used to adjust position size. There is no mechanism to compare current ATR against a historical baseline or to scale lots based on the current volatility regime.

---

## 3. Proposed Solution

Compare the current ATR to its own rolling average over a lookback period. The ratio (`currentATR / averageATR`) defines the volatility regime:

- Regime above `VolatilityHighThreshold` → high volatility → reduce position size
- Regime below `VolatilityLowThreshold` → low volatility → optionally increase position size
- Normal regime → no adjustment

The adjustment is a simple multiplier applied to the computed lot size.

### Parameters

```mql5
input group "════════ RISK: VOLATILITY-ADJUSTED SIZING ════════";
input bool   EnableVolatilityAdjustment    = true;   // Scale lot size with current volatility regime
input int    VolatilityLookback            = 20;     // Bars to average ATR over for baseline
input double VolatilityHighThreshold       = 1.5;    // ATR > baseline × this = high volatility
input double VolatilityLowThreshold        = 0.7;    // ATR < baseline × this = low volatility
input double HighVolatilityMultiplier      = 0.50;   // Lot size multiplier in high volatility (0.5 = halved)
input double LowVolatilityMultiplier       = 1.00;   // Lot size multiplier in low volatility (1.0 = no increase)
```

*Note: `LowVolatilityMultiplier` defaults to 1.0 (no increase in calm markets) to keep the feature purely protective. Increasing lot size during calm periods is an optional growth enhancement — see Open Questions.*

### Behaviour

**`GetVolatilityMultiplier()`** — called in `CalculateLotSize()`:

1. Copy `VolatilityLookback + 1` bars of ATR from the existing ATR handle.
2. Calculate the average ATR over bars 1 to `VolatilityLookback` (excludes current bar 0).
3. Calculate the volatility ratio: `ratio = currentATR / averageATR`.
4. Return:
   - `HighVolatilityMultiplier` if `ratio > VolatilityHighThreshold`
   - `LowVolatilityMultiplier` if `ratio < VolatilityLowThreshold`
   - `1.0` (no adjustment) otherwise

**In `CalculateLotSize()`:**

```mql5
if(EnableVolatilityAdjustment)
{
   double volMultiplier = GetVolatilityMultiplier();
   lotSize       = NormalizeDouble(lotSize * volMultiplier, 2);
   backupLotSize = NormalizeDouble(backupLotSize * volMultiplier, 2);
}
```

---

## 4. Examples

### Example A — Normal conditions, no adjustment

```
Current ATR:  0.0008 (8 pips)
20-bar avg ATR: 0.0009 (9 pips)
Ratio = 8/9 = 0.89

0.70 < 0.89 < 1.50 → Normal regime → multiplier = 1.0
lotSize unchanged
```

### Example B — NFP release, high volatility

```
Current ATR: 0.0045 (45 pips) — spike during news
20-bar avg ATR: 0.0010 (10 pips)
Ratio = 45/10 = 4.5 > VolatilityHighThreshold (1.5) → HIGH

multiplier = HighVolatilityMultiplier = 0.50
Normal lotSize would be: 0.49 lots
Adjusted lotSize: 0.49 × 0.50 = 0.25 lots

Risk at 50 pips: 0.25 × 50 × $10 = $125 (vs $245 at normal size)
The EA still trades but with half the normal exposure during the news event.
```

### Example C — Very quiet overnight session, low volatility

```
Current ATR: 0.0003 (3 pips)
20-bar avg ATR: 0.0008 (8 pips)
Ratio = 3/8 = 0.375 < VolatilityLowThreshold (0.70) → LOW

multiplier = LowVolatilityMultiplier = 1.00 (default — no change)
lotSize unchanged

If LowVolatilityMultiplier were set to 1.20:
→ lotSize × 1.20 (20% increase during calm periods)
→ This is an optional enhancement, disabled by default.
```

### Example D — Volatility ratio transitions

```
Hour 1 (pre-news): ATR ratio = 1.1 → Normal → 0.49 lots
Hour 2 (news hits): ATR ratio = 3.2 → High → 0.25 lots (halved)
Hour 3 (post-news): ATR ratio = 1.8 → Still high → 0.25 lots
Hour 4 (settled): ATR ratio = 1.2 → Normal → 0.49 lots (restored)
```

The adjustment is entirely tick-driven — it responds automatically as the ATR ratio changes.

---

## 5. Code Impact

### New function (in `PrismRiskManager.mqh`)

```mql5
// Returns the volatility multiplier (0 < multiplier ≤ MaxVolMultiplier).
// Reads from the existing ATR indicator handle.
double GetVolatilityMultiplier(int atrHandle, int lookback, double pipPoints);
```

### Data dependency

The function needs the ATR indicator handle (`indicatorHandles.ATR` from `PrismIndicators.mqh`) and needs to copy `VolatilityLookback + 1` bars of ATR data. This is a read-only operation on an already-initialised handle — no new indicators are created.

### Changes to `prism.mq5`

In `CalculateLotSize()`, after computing raw `lotSize` / `backupLotSize` and before applying the lot cap:

```mql5
if(EnableVolatilityAdjustment)
{
   double vm = GetVolatilityMultiplier(indicatorHandles.ATR, VolatilityLookback, pipPoints);
   lotSize       = NormalizeDouble(lotSize * vm, 2);
   backupLotSize = NormalizeDouble(backupLotSize * vm, 2);
}
```

`indicatorHandles` is a global variable in `prism.mq5` and is accessible here. The function signature receives it as a parameter to keep `PrismRiskManager.mqh` decoupled from the indicator module.

### Integration point

`CalculateLotSize()` in `prism.mq5`. Applies before the lot cap (rm_002) so that the cap is applied after volatility adjustment — preserving the cap's role as an absolute ceiling.

Recommended order of lot-size adjustments:
1. Raw calculation (margin-based)
2. Leverage normalisation (rm_003)
3. Trading pocket base (rm_007)
4. **Volatility adjustment (rm_009)**
5. Lot cap — absolute and dynamic (rm_002)
6. Min lots floor

---

## 6. Modular Design

Controlled by `EnableVolatilityAdjustment` flag.

- **`false`** (disabled): `GetVolatilityMultiplier()` is not called; lots are unchanged. Identical to current behaviour.
- **`true`** (enabled): Multiplier is computed on every tick and applied to both regular and backup lot sizes.

Reuses the existing ATR handle — no new indicators, no new indicator periods. The only addition is a call to `CopyBuffer()` for `VolatilityLookback + 1` bars, which is a lightweight operation.

---

## 7. Open Questions

1. **Should `LowVolatilityMultiplier` default to > 1.0?** Increasing position size during calm periods could improve returns but adds a growth-risk trade-off. The conservative default of 1.0 is purely protective. Should this be configurable for more advanced users?

2. **ATR timeframe:** The existing ATR handle uses `PERIOD_CURRENT` (the chart timeframe). Should the volatility lookback use the same timeframe or a higher timeframe (e.g. H1) to smooth out intra-bar spikes?

3. **Which ATR shift to average?** The current implementation uses bars 1 to `VolatilityLookback`. Bar 0 (the current forming bar) is excluded to avoid partial-bar ATR distortion. Is this the correct approach?

4. **Interaction with the Calendar module:** The calendar already pauses trading during news. Should the volatility adjustment be the mechanism for reducing position size *near* news events instead of an additional layer, or are they truly complementary (calendar provides binary on/off, volatility adjustment provides continuous scaling)?

5. **Hysteresis:** Should there be a delay before reverting from a high-volatility regime back to normal? (e.g. stay in "high" for at least N bars after the ratio drops below `VolatilityHighThreshold`). This would prevent rapid oscillation between regimes.
