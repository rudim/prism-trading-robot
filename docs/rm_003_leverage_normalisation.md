# RM-003: Leverage Normalisation

**Status:** Draft
**Phase:** 1 (Critical — implement first)
**Depends on:** None (complements rm_002)

---

## 1. Problem

The lot-size formula uses `marginRequirement` — the margin needed for one base lot — as a divisor. This value is calculated by MT5 using the broker's account leverage. Because `marginRequirement ∝ 1 / leverage`, a higher leverage setting produces proportionally larger lots from the same balance.

The EA does not know or adjust for the broker's leverage setting. A trader who switches brokers, changes account type, or uses a different demo account can inadvertently multiply their position sizes by 10–40× with no code change.

**Lot size comparison — $5,000 balance, MarginUsage = 0.50:**

| Broker Leverage | marginRequirement (0.01 lots) | Calculated Lot Size | 50-pip risk |
|-----------------|------------------------------|---------------------|-------------|
| 1:50 | $10.30 | 0.24 lots | $120 (2.4%) |
| 1:100 | $5.15 | 0.49 lots | $245 (4.9%) |
| 1:200 | $2.58 | 0.97 lots | $485 (9.7%) |
| 1:500 | $1.03 | 2.43 lots | $1,215 (24.3%) |
| 1:1000 | $0.52 | 4.85 lots | $2,425 (48.5%) |
| 1:2000 | $0.26 | 9.71 lots | $4,855 (97.1%) |

At 1:2000 leverage the EA is effectively 40× more aggressive than at 1:50 — with the same parameters. One bad day at 1:2000 wipes an account that would have survived easily at 1:100.

---

## 2. Root Cause

The formula:

```mql5
lotSize = (accountBalance * MarginUsage / marginRequirement) * BaseLotSize;
```

`marginRequirement` is the margin needed for `BaseLotSize = 0.01` lots, which MT5 calculates as:

```
marginRequirement = (contractSize × price × BaseLotSize) / accountLeverage
```

As `accountLeverage` increases, `marginRequirement` falls, and `lotSize` rises — without any cap or awareness in the EA.

---

## 3. Proposed Solution

Define a **reference leverage** (`ReferenceLeverage`) that represents the intended leverage the strategy was designed for. If the account's actual leverage is higher than this reference, scale down the lot size proportionally.

### Parameters

```mql5
input group "════════ RISK: LEVERAGE NORMALISATION ════════";
input bool EnableLeverageNormalisation = true;   // Scale lot sizes to reference leverage
input int  ReferenceLeverage           = 100;    // Leverage the strategy is calibrated for
input int  WarnAboveLeverage           = 200;    // Print warning if account leverage exceeds this
```

### Behaviour

1. On `OnInit()`, read account leverage: `int accountLeverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE)`.
2. If `accountLeverage > WarnAboveLeverage`, print a warning in the Experts log.
3. In `CalculateLotSize()`, after the raw lot is computed, apply the normalisation:

```
adjustmentFactor = min(1.0, ReferenceLeverage / accountLeverage)
normalisedLots = rawLots × adjustmentFactor
```

If `accountLeverage ≤ ReferenceLeverage` the factor is 1.0 — no change. If leverage is higher, lots are scaled down.

---

## 4. Examples

### Example A — Trader on a 1:100 account (reference leverage)

```
accountLeverage = 100, ReferenceLeverage = 100
adjustmentFactor = min(1.0, 100/100) = 1.0
normalisedLots = rawLots × 1.0 → unchanged
```

### Example B — Trader switches to 1:500 account

```
accountLeverage = 500, ReferenceLeverage = 100
adjustmentFactor = min(1.0, 100/500) = 0.20
rawLots (at 1:500) = 12.14
normalisedLots = 12.14 × 0.20 = 2.43 lots

→ Same lot size as if the account were 1:100. Risk is equivalent.
```

### Example C — Low leverage account (1:30 — UK retail broker)

```
accountLeverage = 30, ReferenceLeverage = 100
adjustmentFactor = min(1.0, 100/30) = clamped to 1.0 (no increase)
normalisedLots = rawLots × 1.0 → unchanged

Note: At 1:30, the margin-based formula already produces smaller lots.
      Normalisation only scales DOWN, never UP.
```

### Example D — Scaling comparison, $5,000 balance

| Account Leverage | Raw Lots | Adjustment | Final Lots | 50-pip Risk |
|-----------------|----------|------------|-----------|-------------|
| 1:50 | 0.24 | 1.00 | 0.24 | $120 (2.4%) |
| 1:100 | 0.49 | 1.00 | 0.49 | $245 (4.9%) |
| 1:200 | 0.97 | 0.50 | 0.49 | $245 (4.9%) — normalised |
| 1:500 | 2.43 | 0.20 | 0.49 | $245 (4.9%) — normalised |
| 1:2000 | 9.71 | 0.05 | 0.49 | $245 (4.9%) — normalised |

After normalisation, any account at or above 1:100 produces the same effective position size as a 1:100 account. Risk is consistent regardless of broker.

---

## 5. Code Impact

### New function (in `PrismRiskManager.mqh`)

```mql5
// Returns the lot normalisation factor (0 < factor ≤ 1.0)
// Factor = 1.0 when account leverage ≤ ReferenceLeverage (no adjustment needed)
double GetLeverageNormalisationFactor();
```

### New state (in `PrismRiskManager.mqh`)

```mql5
static int g_accountLeverage = 0;  // Set once in InitRiskManager()
```

### Changes to `prism.mq5`

In `CalculateLotSize()`, after computing raw `lotSize` and `backupLotSize`:

```mql5
if(EnableLeverageNormalisation)
{
   double factor = GetLeverageNormalisationFactor();
   lotSize       = NormalizeDouble(lotSize * factor, 2);
   backupLotSize = NormalizeDouble(backupLotSize * factor, 2);
}
```

In `OnInit()` or `InitRiskManager()`:

```mql5
g_accountLeverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);
if(EnableLeverageNormalisation && g_accountLeverage > WarnAboveLeverage)
   Print("WARNING: Account leverage ", g_accountLeverage,
         ":1 exceeds warning threshold ", WarnAboveLeverage, ":1. Lots will be normalised.");
```

### Integration point

`CalculateLotSize()` in `prism.mq5`, applied after the existing margin-based formula and before rm_002's lot cap. Ordering: raw lots → leverage normalisation (rm_003) → lot cap (rm_002) → min lots.

---

## 6. Modular Design

Controlled by `EnableLeverageNormalisation` flag.

- **`false`** (disabled): `GetLeverageNormalisationFactor()` returns 1.0. No effect on lot sizes.
- **`true`** (enabled): Lots are scaled down proportionally when account leverage exceeds `ReferenceLeverage`.

The warning (`WarnAboveLeverage`) prints regardless of whether normalisation is enabled, so traders are always informed of a high-leverage account. Only the actual scaling is gated by the flag.

Naturally complements rm_002 (lot cap) — together they ensure no position is too large whether the excess comes from a large balance or high leverage.

---

## 7. Open Questions

1. **Should normalisation ever scale UP?** If `accountLeverage < ReferenceLeverage`, the formula already produces smaller lots. Should there be an optional upward scaling for low-leverage accounts so results are always equivalent to 1:100? Probably not — lower leverage is inherently safer.

2. **Per-symbol leverage:** Some brokers apply different leverage to different instruments (e.g. 1:200 for FX, 1:10 for indices). Should the leverage be read per-symbol using `SymbolInfoInteger(SYMBOL_TRADE_EXEMODE)` or similar, rather than the account-wide setting?

3. **ReferenceLeverage default:** Is 100 the right reference? The original strategy may have been designed at a different leverage level. This should be confirmed by reviewing the original backtest conditions.
