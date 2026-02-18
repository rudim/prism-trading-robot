# RM-010: Dynamic MaxTrades

**Status:** Draft
**Phase:** 3
**Depends on:** None (complements rm_007 Trading Pocket, rm_008 Effective Leverage Monitor)

---

## 1. Problem

`MaxTrades` is a fixed input parameter. The EA will always attempt to open up to that many simultaneous positions, regardless of account size or current leverage. At higher balance levels, each of those positions is proportionally larger — so the same `MaxTrades = 7` that was acceptable at a $2,000 balance becomes a concentration of enormous risk at a $20,000 balance.

**Total exposure comparison — MaxTrades = 7, 1:100 leverage:**

| Balance | Lot Size (each) | 7 Positions Total | 50-pip adverse move |
|---------|-----------------|------------------|---------------------|
| $2,000 | 0.10 | 0.70 lots | $350 (17.5%) |
| $5,000 | 0.24 | 1.70 lots | $850 (17.0%) |
| $10,000 | 0.49 | 3.43 lots | $1,715 (17.2%) |
| $20,000 | 0.97 | 6.79 lots | $3,395 (17.0%) |

At lower leverage, the percentage risk stays roughly constant (because lot size scales with balance). However, the absolute dollar amounts compound — a $3,395 loss at $20,000 is harder psychologically and practically than $350 at $2,000.

At high leverage the situation is far worse:

**Total exposure — MaxTrades = 7, 1:500 leverage:**

| Balance | Lot Size (each) | 7 Positions Total | 50-pip adverse move |
|---------|-----------------|------------------|---------------------|
| $2,000 | 0.49 | 3.43 lots | $1,715 (85.8%) |
| $5,000 | 1.21 | 8.47 lots | $4,235 (84.7%) |
| $10,000 | 2.43 | 17.01 lots | $8,505 (85.1%) |

With high leverage and MaxTrades = 7, exposure is catastrophic at all balance levels. Reducing MaxTrades as the account grows is a direct way to reduce total portfolio leverage.

---

## 2. Root Cause

`MaxTrades` is declared as a fixed input:

```mql5
input int MaxTrades = 7;
```

It is used as a direct ceiling in `OpenPosition()`:

```mql5
if(basketCount < MaxTrades)
{
   // open position
}
```

There is no balance-aware logic that adjusts this ceiling.

---

## 3. Proposed Solution

Compute an effective MaxTrades limit at runtime based on current account balance (and optionally leverage). When `EnableDynamicMaxTrades` is on, the input `MaxTrades` serves as the upper ceiling for small accounts; for larger accounts, the dynamic calculation returns a lower value.

### Parameters

```mql5
input group "════════ RISK: DYNAMIC MAX TRADES ════════";
input bool   EnableDynamicMaxTrades  = true;   // Reduce max simultaneous positions as balance grows
input double MaxTradesTier1Balance   = 3000;   // Below this: use MaxTrades input unchanged
input double MaxTradesTier2Balance   = 10000;  // Below this: use Tier2 limit
input double MaxTradesTier3Balance   = 20000;  // Below this: use Tier3 limit
                                               // Above Tier3: use Tier4 limit
input int    MaxTradesTier2          = 5;      // Max trades for Tier 2
input int    MaxTradesTier3          = 4;      // Max trades for Tier 3
input int    MaxTradesTier4          = 3;      // Max trades for Tier 4 (large accounts)
```

### Behaviour

**`GetDynamicMaxTrades()`** — returns the effective trade limit:

```
if balance < MaxTradesTier1Balance → return MaxTrades (input unchanged)
if balance < MaxTradesTier2Balance → return min(MaxTrades, MaxTradesTier2)
if balance < MaxTradesTier3Balance → return min(MaxTrades, MaxTradesTier3)
else                               → return min(MaxTrades, MaxTradesTier4)
```

The `min()` ensures the dynamic limit never exceeds what the input parameter allows. If a trader manually sets `MaxTrades = 2`, the dynamic limit will not increase it.

**In `OpenPosition()` and `SendBackup()`:**

Replace `MaxTrades` with `GetDynamicMaxTrades()`.

---

## 4. Examples

### Example A — Small account, no restriction

```
Balance = $2,000 (< Tier1 $3,000)
MaxTrades input = 7
GetDynamicMaxTrades() = 7 (unchanged)
```

### Example B — Growing account, reduced to 5

```
Balance = $6,000 (between Tier1 $3,000 and Tier2 $10,000)
MaxTrades input = 7
GetDynamicMaxTrades() = min(7, MaxTradesTier2=5) = 5

EA will open at most 5 simultaneous positions.
```

### Example C — Large account, maximum restriction

```
Balance = $25,000 (above Tier3 $20,000)
MaxTrades input = 7
GetDynamicMaxTrades() = min(7, MaxTradesTier4=3) = 3

Only 3 simultaneous positions allowed.
```

### Example D — Trader with conservative MaxTrades input

```
Balance = $25,000, MaxTrades = 2
GetDynamicMaxTrades() = min(2, 3) = 2

Dynamic limit (3) does not override the user's conservative input (2).
```

### Example E — Combined with lot size caps (rm_002)

```
Balance = $20,000, MaxTrades = 7, 1:100 leverage
Without dynamic limit: 7 positions × 0.97 lots = 6.79 lots total
With dynamic limit: 3 positions × 0.50 lots (capped by rm_002) = 1.50 lots total

50-pip risk: 1.50 × 50 × $10 = $750 (3.75% of $20,000)
vs original: 6.79 × 50 × $10 = $3,395 (17% of $20,000)
```

---

## 5. Code Impact

### New function (in `PrismRiskManager.mqh`)

```mql5
// Returns the effective maximum trades limit based on current account balance.
// Respects the MaxTrades input as an upper ceiling — never returns more than MaxTrades.
int GetDynamicMaxTrades(double accountBalance, int maxTradesInput);
```

### Changes to `prism.mq5`

In `OpenPosition()`:

```mql5
// Before
if(basketCount < MaxTrades)

// After
int effectiveMaxTrades = EnableDynamicMaxTrades
                         ? GetDynamicMaxTrades(accountInfo.Balance(), MaxTrades)
                         : MaxTrades;
if(basketCount < effectiveMaxTrades)
```

Same change in `SendBackup()`:

```mql5
if(positions.totalBackupTrades >= effectiveMaxTrades - 1)
   return;
```

### Integration point

`OpenPosition()` and `SendBackup()` in `prism.mq5`. Two small substitutions — no structural changes.

---

## 6. Modular Design

Controlled by `EnableDynamicMaxTrades` flag.

- **`false`** (disabled): `GetDynamicMaxTrades()` is not called; the `MaxTrades` input is used directly. Identical to current behaviour.
- **`true`** (enabled): Effective trade limit is computed dynamically based on balance tiers.

The tier boundaries and limits are all configurable inputs. A trader who wants no restriction at any balance can disable the feature or set all tier limits equal to `MaxTrades`.

Complements rm_007 (Trading Pocket) — together they bound both per-trade size (rm_007: sizing from a bounded capital base) and total number of positions (rm_010). When combined:

```
Total exposure = GetDynamicMaxTrades() × GetRiskBasedLotSize()
             = bounded count × bounded size
```

---

## 7. Open Questions

1. **Leverage-aware tiers:** Should the tier thresholds also factor in account leverage? At 1:100, MaxTradesTier2=5 might be fine. At 1:500, even Tier1 (small accounts, MaxTrades=7) might be too many. Should there be an optional `if leverage > X: reduce by 1` modifier?

2. **Gradual reduction vs step function:** The current design uses discrete tiers (7 → 5 → 4 → 3). Should this be a smooth formula instead? For example: `effectiveMaxTrades = max(MinTrades, MaxTrades - floor(balance / TierStep))`. The step approach is easier to configure; the smooth approach is more proportional.

3. **Interaction with the existing `basketCount`:** `basketCount` tracks how many positions have been opened in the current basket and resets when direction changes. Does `GetDynamicMaxTrades()` need to interact with `basketCount` or does the simple substitution work correctly?

4. **Should the display show the dynamic limit?** The HUD currently shows various parameters. Adding "MaxTrades: 5/7" (effective/input) would help the trader see that the dynamic limit is active.
