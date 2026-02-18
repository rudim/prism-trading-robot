# RM-002: Maximum Lot Size Cap

**Status:** Draft
**Phase:** 1 (Critical — implement first)
**Depends on:** None (complements rm_001, rm_003)

---

## 1. Problem

The current lot-size formula scales linearly with account balance. As the account grows, each position becomes proportionally larger. When combined with high broker leverage, a successful trading period creates a setup where the next large adverse move can wipe out all accumulated gains in a single trade.

**Example — balance growth increases absolute risk:**

| Balance | Lot Size (1:100) | Lot Size (1:500) | Risk per 50-pip move |
|---------|-----------------|-----------------|----------------------|
| $2,000 | 0.10 | 0.49 | $50 / $245 |
| $5,000 | 0.24 | 1.21 | $120 / $605 |
| $10,000 | 0.49 | 2.43 | $245 / $1,215 |
| $20,000 | 0.97 | 4.85 | $485 / $2,425 |
| $50,000 | 2.43 | 12.14 | $1,215 / $6,070 |

There is currently no ceiling. A $50K account at 1:500 leverage using 8 simultaneous positions has **97 lots of total exposure** — a 10-pip move wipes the account.

---

## 2. Root Cause

`CalculateLotSize()` in `prism.mq5` computes:

```mql5
lotSize = NormalizeDouble((accountBalance * MarginUsage / marginRequirement) * BaseLotSize, 2);
```

`accountBalance` grows with profits, `marginRequirement` decreases as leverage increases. Both effects compound — the formula has no upper bound.

---

## 3. Proposed Solution

Apply a two-level cap after the existing lot-size calculation:

1. **Absolute cap** (`MaxLotSize`): No single position may exceed this lot count regardless of balance.
2. **Dynamic cap** (`MaxLotsPerBalance`): Lot size may not exceed a fixed ratio of balance (expressed as lots per $1,000 of balance). This keeps relative risk bounded even if the absolute cap is generous.

The lower of the two caps is used.

### Parameters

```mql5
input group "════════ RISK: LOT SIZE CAP ════════";
input bool   EnableLotCap        = true;   // Apply maximum lot size limits
input double MaxLotSize          = 0.50;   // Hard ceiling: no single position larger than this
input double MaxLotsPerThousand  = 0.05;   // Dynamic ceiling: max lots per $1,000 of balance
                                           // e.g. 0.05 → $10K balance → 0.50 lots max
```

### Behaviour

1. After `CalculateLotSize()` computes `lotSize` and `backupLotSize` using the existing margin-based formula:
2. Calculate the dynamic cap: `dynamicCap = (accountBalance / 1000.0) × MaxLotsPerThousand`.
3. Apply: `cappedLots = MathMin(lotSize, MathMin(MaxLotSize, dynamicCap))`.
4. Repeat for `backupLotSize`.
5. Ensure the result still respects `MinLots`.

---

## 4. Examples

### Example A — Small account, cap is non-binding

```
Balance = $2,000, MarginUsage = 0.50, 1:100 leverage
Calculated lots = 0.10
MaxLotSize = 0.50 → not binding
Dynamic cap = (2000 / 1000) × 0.05 = 0.10 → not binding
Final lots = 0.10 (unchanged)
```

### Example B — Large account, absolute cap kicks in

```
Balance = $20,000, MarginUsage = 0.50, 1:100 leverage
Calculated lots = 0.97
MaxLotSize = 0.50 → caps to 0.50
Dynamic cap = (20000 / 1000) × 0.05 = 1.00 → not binding
Final lots = 0.50
```

### Example C — High leverage, dynamic cap is tighter

```
Balance = $10,000, MarginUsage = 0.50, 1:500 leverage
Calculated lots = 12.14
MaxLotSize = 0.50 → caps to 0.50
Dynamic cap = (10000 / 1000) × 0.05 = 0.50 → both caps agree
Final lots = 0.50
Max risk (50 pips): 0.50 × 50 × $10 = $250 (2.5% of balance) ✓
```

Compare to uncapped: `12.14 × 50 × $10 = $6,070` (121% of balance — account wipeout).

### Example D — Tuning `MaxLotsPerThousand` for growth

If you want slightly more aggression you can increase `MaxLotsPerThousand`:

| Setting | $5K balance | $10K balance | $20K balance | 50-pip risk at $10K |
|---------|-------------|--------------|--------------|---------------------|
| 0.03 | 0.15 lots | 0.30 lots | 0.50 lots* | $150 (1.5%) |
| 0.05 | 0.25 lots | 0.50 lots | 1.00 lots | $250 (2.5%) |
| 0.10 | 0.50 lots | 1.00 lots | 2.00 lots | $500 (5.0%) |

*capped by MaxLotSize=0.50

---

## 5. Code Impact

### New function (in `PrismRiskManager.mqh`)

```mql5
// Applies the lot size cap. Returns the capped value.
// Pass in the raw calculated lots; returns MathMin of raw, absolute cap, and dynamic cap.
double ApplyLotCap(double rawLots, double accountBalance);
```

### Changes to `prism.mq5`

At the end of `CalculateLotSize()`, after the existing min-lot enforcement:

```mql5
// Before (existing)
if(lotSize < MinLots) lotSize = MinLots;
if(backupLotSize < MinLots) backupLotSize = MinLots;

// After (add these lines)
if(EnableLotCap)
{
   lotSize       = MathMax(ApplyLotCap(lotSize, accountInfo.Balance()), MinLots);
   backupLotSize = MathMax(ApplyLotCap(backupLotSize, accountInfo.Balance()), MinLots);
}
```

### Integration point

End of `CalculateLotSize()` in `prism.mq5`. No changes to signal logic, position opening, or management.

---

## 6. Modular Design

Controlled by a single `EnableLotCap` flag.

- **`false`** (disabled): `ApplyLotCap()` returns the input unchanged. Identical to current behaviour.
- **`true`** (enabled): Both caps applied. The absolute cap (`MaxLotSize`) provides a hard ceiling; the dynamic cap (`MaxLotsPerThousand`) scales proportionally with balance.

Works independently — does not require rm_001 or rm_003 to be enabled, though all three complement each other when combined.

---

## 7. Open Questions

1. **Separate caps for backup lots?** The backup system is designed to trade smaller positions. Should `backupLotSize` use a tighter cap (e.g. `BackupMaxLotSize`) separate from the regular cap?

2. **Cap for basket total?** This cap applies per-position. Should there also be a cap on the *total* lots across all open positions? (This is partly addressed by rm_008 Effective Leverage Monitor.)

3. **Default values:** `MaxLotSize = 0.50` and `MaxLotsPerThousand = 0.05` are reasonable starting points but should be validated against backtest results. Are these conservative enough for the target leverage range?
