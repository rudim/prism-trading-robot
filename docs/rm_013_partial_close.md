# RM-013: Partial Position Close (Money Management)

**Status:** Draft (stub)
**Phase:** 3 (Enhancement — implement after core risk features)
**Depends on:** RM-001 (soft stop), RM-002 (lot size cap)
**Classification:** Money management (profit optimisation), not risk management (loss limiting)

---

## 1. Distinction from Risk Management

Risk management (RM-001 through RM-012) is concerned with *limiting losses*. This feature is different: it is concerned with *locking in gains* from a winning position while allowing the remainder to continue running.

The distinction matters architecturally. The soft stop (RM-001) is a loss-limit mechanism that closes the *entire* position when a downside threshold is breached. Partial close is a profit-capture mechanism that closes a *fraction* of the position when an upside threshold is reached.

The two can be combined: partially close at +X to lock in profit, then tighten the soft stop on the remainder to breakeven (entry price), so the locked-in profit cannot be fully reversed.

---

## 2. Problem

Prism's current exit logic is basket-oriented: `closeAll()`, `OpenProfit`, `BasketProfit`, and `SafeExits` all act on the entire basket. An individual position that has moved significantly in favour continues running until the basket as a whole triggers an exit condition. In a ranging market this means unrealised gains can be given back before the basket exit fires.

A partial close lets the EA crystallise a fraction of the gain on a winning position without disrupting the basket or waiting for a basket-level condition.

---

## 3. How Partial Close Works in MQL5

```mql5
// Close half of a position:
_trade.PositionClosePartial(ticket, lotsToClose);
```

`lotsToClose` must be a valid lot increment (respecting `SYMBOL_VOLUME_STEP`). After a partial close:
- The original position ticket remains open with the reduced lot size
- `AnalyzePositions()` automatically picks up the new (smaller) lot size on the next tick — no extra tracking required
- The closed portion appears in trade history as a separate deal

---

## 4. Proposed Mechanism (outline — to be detailed)

### Trigger
When a position's floating profit exceeds `LockInThreshold × accountBalance`, close `LockInPercent` of the position.

### Parameters (indicative)
```mql5
input group "════════ MONEY MANAGEMENT: PARTIAL CLOSE ════════";
input bool   EnablePartialClose   = false;  // Partially close winning positions to lock in profit
input double LockInThreshold      = 0.01;   // Trigger: position profit > this % of balance (1%)
input double LockInPercent        = 0.50;   // Fraction of position to close (0.50 = 50%)
input bool   MoveStopToBreakeven  = true;   // After partial close, tighten soft stop to entry price
```

### Interaction with RM-001 (soft stop)
If `MoveStopToBreakeven = true`:
- After the partial close, update the chart object created by RM-001 (`PrismSL_<ticket>`) to `OBJPROP_PRICE = entryPrice`
- The remaining position now has a breakeven soft stop — worst case it closes at zero profit on the remainder, while the partial close profit is already realised

### Interaction with basket accounting
`_stats.buyLots` / `_stats.sellLots` are recalculated from `AnalyzePositions()` on every tick. A partial close is automatically reflected in these totals — the basket cap (RM-002) will also reflect the reduced exposure immediately. No additional tracking is required in `prism.mq5`.

---

## 5. Open Questions

1. **Basket vs individual:** Prism's design philosophy is basket-oriented. Does per-position partial close conflict with the basket P&L logic, or complement it? A single position being partially closed changes `_stats.totalProfit` and could prematurely or erroneously trigger a basket-level exit condition.

2. **Lot rounding:** `lotsToClose = position.Volume() × LockInPercent` must be rounded to the nearest `SYMBOL_VOLUME_STEP`. The remainder must also be above `SYMBOL_VOLUME_MIN`. On small accounts with minimum lot sizes, partial close may not be feasible.

3. **Multiple partial closes:** Should a position be partially closed once, or can the threshold be hit multiple times (e.g. close 50% at +1%, then 50% of the remainder at +2%)? The latter requires tracking how many partial closes have already occurred.

4. **Backup positions:** Should backup trades be eligible for partial close? They are intentionally held through drawdown — a partial close at a brief profit spike might reduce the insurance coverage just when it is most needed.

5. **Interaction with `SleepSeconds`:** Does a partial close reset `_lastTradeTime`? If so, it could delay the next regular trade open.
