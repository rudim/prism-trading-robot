# RM-007: Trading Pocket

**Status:** Draft
**Phase:** 2
**Depends on:** None (complements rm_011 Profit Lock-In)

---

## 1. Problem

Every position is sized relative to the full account balance. As the account grows through successful trading, the same `MarginUsage` percentage produces larger and larger positions. A profitable week that doubles the balance also doubles the risk on the next trade.

This creates a structural problem:

**Every dollar earned increases the potential loss on the next trade by `MarginUsage` dollars of exposure.**

At `MarginUsage = 0.50` and `1:100 leverage`, doubling the account from $5K to $10K also doubles individual position size from 0.24 to 0.49 lots — so a single adverse move that would have cost $240 now costs $490.

**The win–risk spiral:**

```
$2,000 balance → 0.10 lots → $50 risk per 50 pips
Win $1,800 → $3,800 balance → 0.18 lots → $90 risk per 50 pips
Win $3,230 → $7,030 balance → 0.34 lots → $170 risk per 50 pips
Lose $7,030 → $0 balance (85% drawdown in one trade at this size)
```

The winning period funded the losing trade — and the losing trade was far larger than any winning trade.

---

## 2. Root Cause

`CalculateLotSize()` uses `accountInfo.Balance()` directly:

```mql5
double accountBalance = accountInfo.Balance();
lotSize = NormalizeDouble((accountBalance * MarginUsage / marginRequirement) * BaseLotSize, 2);
```

As balance grows, `accountBalance` grows, and so does `lotSize`. There is no mechanism to isolate a portion of the balance from position sizing.

---

## 3. Proposed Solution

Divide the account balance into two conceptual buckets:

- **Trading Capital:** The amount actively used for position sizing. Capped at `MaxTradingCapital`. This is the only amount that drives lot size calculations.
- **Safe Capital:** Everything above `MaxTradingCapital`. This amount grows as the account grows but is never used for position sizing.

As the account grows, safe capital accumulates while trading capital stays bounded. Maximum potential loss is always limited to the trading capital amount.

### Parameters

```mql5
input group "════════ RISK: TRADING POCKET ════════";
input bool   EnableTradingPocket    = true;     // Segregate balance into trading and safe capital
input double TradingPocketPct       = 0.30;     // Trading capital as % of total balance
input double MinTradingCapital      = 1000;     // Trading capital is never less than this ($)
input double MaxTradingCapital      = 5000;     // Trading capital never exceeds this ($)
```

### Behaviour

**`CalculateTradingCapital()`** — called at the start of `CalculateLotSize()`:

1. Get `totalBalance = accountInfo.Balance()`.
2. Calculate `tradingCapital = totalBalance × TradingPocketPct`.
3. Clamp: `tradingCapital = Clamp(tradingCapital, MinTradingCapital, MaxTradingCapital)`.
4. `safeCapital = totalBalance - tradingCapital`.

**In `CalculateLotSize()`:**

Replace `accountBalance` with `tradingCapital`:

```mql5
// Before
lotSize = (accountBalance * MarginUsage / marginRequirement) * BaseLotSize;

// After
double tradingCapital = CalculateTradingCapital();
lotSize = (tradingCapital * MarginUsage / marginRequirement) * BaseLotSize;
```

**Display:**

Show `tradingCapital` and `safeCapital` on the HUD so the trader always knows the split.

---

## 4. Examples

### Example A — Small account, cap is not yet binding

```
Balance = $2,000, TradingPocketPct = 0.30
tradingCapital = $2,000 × 0.30 = $600 → below MinTradingCapital ($1,000)
→ clamp up: tradingCapital = $1,000
safeCapital = $2,000 - $1,000 = $1,000

Max potential loss if trading capital wiped: $1,000 (50% of balance)
```

### Example B — Growing account

```
Balance = $5,000, TradingPocketPct = 0.30
tradingCapital = $5,000 × 0.30 = $1,500 → within [1000, 5000]
safeCapital = $3,500

Without pocket: lots based on $5,000 → 0.24 lots
With pocket:    lots based on $1,500 → 0.07 lots
Max potential loss: $1,500 (30% of balance, not 100%)
```

### Example C — Large account, MaxTradingCapital is binding

```
Balance = $20,000, TradingPocketPct = 0.30
tradingCapital = $20,000 × 0.30 = $6,000 → above MaxTradingCapital ($5,000)
→ clamp down: tradingCapital = $5,000
safeCapital = $15,000

Max potential loss if trading capital wiped: $5,000 (25% of $20,000)
```

### Example D — Lot size comparison across balance levels

| Balance | Without Pocket | With Pocket (30%, max $5K) | Pocket lots/no-pocket ratio |
|---------|---------------|---------------------------|------------------------------|
| $2,000 | 0.10 | 0.05 (min $1K) | 0.50× |
| $5,000 | 0.24 | 0.07 | 0.29× |
| $10,000 | 0.49 | 0.24 ($2,500 capital) | 0.49× |
| $20,000 | 0.97 | 0.24 ($5,000 max) | 0.25× |
| $50,000 | 2.43 | 0.24 ($5,000 max) | 0.10× |

At large balances, the trading pocket creates a firm ceiling on risk regardless of how much the account has grown.

### Example E — Black swan event with pocket

```
Balance = $10,000, Trading Capital = $2,500
Lot size = 0.12 lots (based on $2,500)
Black swan: 300-pip adverse move × 0.12 lots = $360 loss

Without pocket: 300-pip × 0.49 lots = $1,470 loss (14.7% of balance)
With pocket:    300-pip × 0.12 lots = $360 loss (3.6% of balance)

Safe capital ($7,500) is completely untouched.
```

---

## 5. Code Impact

### New function (in `PrismRiskManager.mqh`)

```mql5
// Returns the active trading capital based on trading pocket settings.
// When disabled, returns accountBalance unchanged.
double CalculateTradingCapital(double accountBalance);

// Returns the safe capital (informational only, not used in sizing)
double CalculateSafeCapital(double accountBalance);
```

### Changes to `prism.mq5`

In `CalculateLotSize()`:

```mql5
double accountBalance = accountInfo.Balance();
double tradingBase    = EnableTradingPocket
                        ? CalculateTradingCapital(accountBalance)
                        : accountBalance;

lotSize       = NormalizeDouble((tradingBase * MarginUsage / marginRequirement) * BaseLotSize, 2);
backupLotSize = NormalizeDouble((tradingBase * BackupMargin / marginRequirement) * BaseLotSize, 2);
```

In `UpdateDisplay()` — add to HUD:

```mql5
if(EnableTradingPocket)
{
   double tc = CalculateTradingCapital(accountInfo.Balance());
   display += " Trading: $" + DoubleToString(tc, 0) +
              " Safe: $"    + DoubleToString(accountInfo.Balance() - tc, 0);
}
```

### Integration point

`CalculateLotSize()` in `prism.mq5`. One variable substitution — all downstream lot-size logic is unchanged.

---

## 6. Modular Design

Controlled by `EnableTradingPocket` flag.

- **`false`** (disabled): `CalculateTradingCapital()` returns the full `accountBalance`. Identical to current behaviour.
- **`true`** (enabled): Trading capital is derived from the percentage formula with min/max bounds.

Pairs naturally with rm_011 (Profit Lock-In), which can grow the `safeCapital` bucket by explicitly transferring profit milestones there. When both are enabled, `CalculateTradingCapital()` subtracts the locked profit from the available pool:

```mql5
// Combined with rm_011:
tradingCapital = Clamp(
   (accountBalance - g_locked_profit) * TradingPocketPct,
   MinTradingCapital,
   MaxTradingCapital
);
```

---

## 7. Open Questions

1. **`TradingPocketPct` vs fixed amount:** Should trading capital be a fixed dollar amount (e.g. always $2,000) or a percentage of balance? A fixed amount is simpler to reason about. A percentage allows the pocket to grow slowly with the account. The percentage approach with a maximum cap achieves both — it grows up to the cap, then stays fixed.

2. **Impact on minimum trade viability:** At small account sizes (< $3,000 with `MinTradingCapital = $1,000`), the pocket forces trading from a base smaller than the full balance. If `MinLots = 0.03` and the trading capital only supports `0.02 lots`, what happens? The `MinLots` floor takes over — which effectively ignores the pocket for very small accounts. Is this the desired behaviour?

3. **Safe capital accessibility:** Is safe capital literally just the portion not used for sizing, or should there be a mechanism to withdraw it? (Likely out of scope for the EA — this is an external portfolio management concern.)

4. **DailyGrowth tracking:** The `dailyGrowth` and `SafeGrowth` checks in `CalculateLotSize()` compare against `accountInfo.Balance()`. Should these thresholds be compared against `tradingCapital` instead, to ensure daily growth targets are meaningful relative to the active trading amount?
