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

`calculateLotSize()` in `prism.mq5` computes:

```mql5
_lotSize       = NormalizeDouble((accountBalance * MarginUsage  / _marginRequirement) * _baseLotSize, 2);
_backupLotSize = NormalizeDouble((accountBalance * BackupMargin / _marginRequirement) * _baseLotSize, 2);
```

`accountBalance` grows with profits, `_marginRequirement` decreases as leverage increases. Both effects compound in the same direction — neither formula has an upper bound.

---

## 3. Three Distinct Caps

This feature addresses three separate exposure concerns that must not be conflated:

| Cap | Scope | What it limits |
|-----|-------|----------------|
| **Per-position cap — regular** | Single trade | `_lotSize` used when opening a normal signal trade |
| **Per-position cap — backup** | Single trade | `_backupLotSize` used when opening a backup/insurance trade |
| **Basket total cap** | All open trades combined | `_stats.buyLots + _stats.sellLots` at the time a new trade would open |

### Why separate caps are needed

**Regular vs backup trades are fundamentally different in intent.**
Backup trades are emergency insurance trades triggered by drawdown. They are intentionally sized smaller than regular trades (controlled by `BackupMargin` which defaults to 10× smaller than `MarginUsage`). Applying the same absolute ceiling to both would either under-protect regular trades or over-restrict backup trades. Each needs its own ceiling that reflects its role.

**Per-position vs basket are different failure modes.**
A per-position cap prevents any single trade from being catastrophically large. A basket cap prevents the accumulation of many individually-acceptable trades from producing catastrophic total exposure. Both must be enforced independently — a per-position cap alone does not protect against a 8-trade basket at maximum individual lot size.

**Concrete example of the gap:**
With `MaxLotSize = 0.50` and `MaxTrades = 8`, the per-position cap is satisfied but the basket total can still reach 4.0 lots. On EURUSD at 1:100, a 50-pip move against a 4.0-lot basket costs $2,000 — potentially the entire balance of a small account.

---

## 4. Proposed Solution

Apply caps at two points in the trade lifecycle:

1. **At lot-size calculation** (`calculateLotSize()`): cap `_lotSize` and `_backupLotSize` independently before they are stored as globals.
2. **At trade open** (`sendOpen()` / `backSystem()`): check the current basket total against the basket cap before firing the order.

### Parameters

```mql5
input group "════════ RISK: LOT SIZE CAP ════════";
input bool   EnableLotCap             = true;   // Apply all lot size caps
// --- Per-position: regular trades ---
input double MaxLotSize               = 0.50;   // Hard ceiling per regular position (lots)
input double MaxLotsPerThousand       = 0.05;   // Dynamic ceiling: max lots per $1,000 balance
                                                // e.g. 0.05 → $10K balance → 0.50 lots max
// --- Per-position: backup trades ---
input double BackupMaxLotSize         = 0.10;   // Hard ceiling per backup position (lots)
input double BackupMaxLotsPerThousand = 0.01;   // Dynamic ceiling for backup: max lots per $1,000
                                                // e.g. 0.01 → $10K balance → 0.10 lots max
// --- Basket total ---
input double MaxBasketLots            = 2.00;   // Hard ceiling on total open lots (all positions combined)
input double MaxBasketLotsPerThousand = 0.20;   // Dynamic basket ceiling: max total lots per $1,000
                                                // e.g. 0.20 → $10K balance → 2.00 lots max basket
```

### Behaviour

#### Per-position caps (applied inside `calculateLotSize()`)

1. After the existing margin-based formula produces `_lotSize` and `_backupLotSize`:
2. For regular trades — calculate dynamic cap: `dynamicCap = (accountBalance / 1000.0) × MaxLotsPerThousand`
3. Apply: `_lotSize = MathMax(MathMin(_lotSize, MathMin(MaxLotSize, dynamicCap)), MinLots)`
4. For backup trades — calculate backup dynamic cap: `backupDynamicCap = (accountBalance / 1000.0) × BackupMaxLotsPerThousand`
5. Apply: `_backupLotSize = MathMax(MathMin(_backupLotSize, MathMin(BackupMaxLotSize, backupDynamicCap)), MinLots)`

#### Basket total cap (applied at trade open, before order is sent)

1. At the point a new position would be opened, compute current basket exposure:
   `currentBasketLots = _stats.buyLots + _stats.sellLots`
2. Calculate dynamic basket cap: `basketDynamicCap = (accountBalance / 1000.0) × MaxBasketLotsPerThousand`
3. Effective basket ceiling: `basketCeiling = MathMin(MaxBasketLots, basketDynamicCap)`
4. If `currentBasketLots + lotsAboutToOpen > basketCeiling` → do not open the trade.
5. This check applies to both regular and backup trade opens.

---

## 5. Examples

### Example A — Small account, no cap binding

```
Balance = $2,000, MarginUsage = 0.50, 1:100 leverage
Calculated _lotSize = 0.10

Per-position regular cap:
  MaxLotSize = 0.50 → not binding
  Dynamic cap = (2000 / 1000) × 0.05 = 0.10 → not binding
  Final _lotSize = 0.10 (unchanged)

Basket cap (4 trades open at 0.10 = 0.40 lots total):
  MaxBasketLots = 2.00 → not binding
  Dynamic basket = (2000 / 1000) × 0.20 = 0.40 → exactly at limit
  5th trade would be blocked: 0.40 + 0.10 = 0.50 > 0.40 ✓
```

### Example B — Large account, absolute per-position cap binding

```
Balance = $20,000, MarginUsage = 0.50, 1:100 leverage
Calculated _lotSize = 0.97

Per-position regular cap:
  MaxLotSize = 0.50 → caps to 0.50
  Dynamic cap = (20000 / 1000) × 0.05 = 1.00 → not binding
  Final _lotSize = 0.50

Backup cap:
  Calculated _backupLotSize ≈ 0.10 (BackupMargin is 10× smaller)
  BackupMaxLotSize = 0.10 → at limit
  Backup dynamic cap = (20000 / 1000) × 0.01 = 0.20 → not binding
  Final _backupLotSize = 0.10
```

### Example C — High leverage, dynamic cap tighter than absolute

```
Balance = $10,000, MarginUsage = 0.50, 1:500 leverage
Calculated _lotSize = 12.14

Per-position regular cap:
  MaxLotSize = 0.50 → caps to 0.50
  Dynamic cap = (10000 / 1000) × 0.05 = 0.50 → both caps agree
  Final _lotSize = 0.50
  Max risk (50 pips): 0.50 × 50 × $10 = $250 (2.5% of balance) ✓
Compare to uncapped: 12.14 × 50 × $10 = $6,070 (121% of balance — account wipeout)

Basket cap (8 positions at 0.50 = 4.0 lots):
  MaxBasketLots = 2.00 → blocks trade #5 onward
  Dynamic basket = (10000 / 1000) × 0.20 = 2.00 → agrees
  Maximum basket exposure: 2.00 lots
  Max basket risk (50 pips): 2.00 × 50 × $10 = $1,000 (10% of balance) ✓
```

### Example D — Tuning `MaxLotsPerThousand` for growth

If you want slightly more aggression you can increase `MaxLotsPerThousand`:

| Setting | $5K balance | $10K balance | $20K balance | 50-pip risk at $10K |
|---------|-------------|--------------|--------------|---------------------|
| 0.03 | 0.15 lots | 0.30 lots | 0.50 lots* | $150 (1.5%) |
| 0.05 | 0.25 lots | 0.50 lots | 1.00 lots | $250 (2.5%) |
| 0.10 | 0.50 lots | 1.00 lots | 2.00 lots | $500 (5.0%) |

*capped by MaxLotSize=0.50

---

## 6. Code Impact

### New function (in `PrismRiskManager.mqh`)

```mql5
// Applies the per-position lot cap. Returns the capped value, never below MinLots.
// rawLots       — output of the margin-based formula
// accountBalance — current account balance
// absoluteCap   — hard ceiling (MaxLotSize or BackupMaxLotSize)
// perThousand   — dynamic ceiling coefficient (MaxLotsPerThousand or BackupMaxLotsPerThousand)
// minLots       — floor (MinLots input)
double ApplyLotCap(double rawLots, double accountBalance,
                   double absoluteCap, double perThousand, double minLots);

// Returns true if opening lotsToBuy/lotsToSell would keep basket total within cap.
// Call this at trade-open time before sending the order.
// currentBasketLots — _stats.buyLots + _stats.sellLots at this tick
// lotsToOpen        — _lotSize or _backupLotSize about to be traded
// accountBalance    — current account balance
bool BasketCapAllows(double currentBasketLots, double lotsToOpen,
                     double accountBalance,
                     double absoluteBasketCap, double basketPerThousand);
```

### Changes to `prism.mq5` — `calculateLotSize()`

```mql5
// Existing min-lot enforcement (keep as-is):
if(_lotSize < MinLots) _lotSize = MinLots;
if(_backupLotSize < MinLots) _backupLotSize = MinLots;

// Add after:
if(EnableLotCap)
{
   _lotSize       = ApplyLotCap(_lotSize,       accountBalance, MaxLotSize,       MaxLotsPerThousand,       MinLots);
   _backupLotSize = ApplyLotCap(_backupLotSize, accountBalance, BackupMaxLotSize, BackupMaxLotsPerThousand, MinLots);
}
```

### Changes to `prism.mq5` — `sendOpen()` and `backSystem()`

```mql5
// Add before each PositionOpen() call:
if(EnableLotCap)
{
   double currentBasket = _stats.buyLots + _stats.sellLots;
   if(!BasketCapAllows(currentBasket, _lotSize, accountBalance,
                       MaxBasketLots, MaxBasketLotsPerThousand))
      return;   // basket full — skip this trade
}
```

---

## 7. Modular Design

Controlled by a single `EnableLotCap` flag.

- **`false`** (disabled): `ApplyLotCap()` returns the input unchanged; basket check always passes. Identical to current behaviour.
- **`true`** (enabled): All three caps active. Each cap is independently tunable and can be made non-binding by setting its value very high.

Works independently — does not require rm_001 or rm_003 to be enabled, though all three complement each other when combined.

---

## 8. Default Values Rationale

| Parameter | Default | Rationale |
|-----------|---------|-----------|
| `MaxLotSize` | 0.50 | Hard ceiling at half a standard lot. Safe for accounts up to $10K at 1:100. |
| `MaxLotsPerThousand` | 0.05 | 2.5% balance risk per 50-pip move per position. Conservative starting point. |
| `BackupMaxLotSize` | 0.10 | Backup trades are insurance — they should be materially smaller than regular trades. |
| `BackupMaxLotsPerThousand` | 0.01 | 5× tighter than regular on a relative basis, matching the intent of `BackupMargin`. |
| `MaxBasketLots` | 2.00 | 4× the default `MaxLotSize` — allows up to 4 concurrent positions at full size. |
| `MaxBasketLotsPerThousand` | 0.20 | Dynamic counterpart: $10K → 2.0 lot max basket, consistent with `MaxBasketLots`. |

All defaults should be validated against backtest results before live deployment.
