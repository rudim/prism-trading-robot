# Plan: Risk Management Documentation Breakdown

## Context

Two existing documents contain overlapping, interleaved risk management research:
- `docs/spec_prism_risk_management.md` — hard controls (stops, caps, circuit breakers, emergency close, volatility sizing)
- `docs/analysis_leverage_and_trading_pocket.md` — structural controls (trading pocket, leverage normalisation, effective leverage monitoring, dynamic MaxTrades, profit lock-in)

The goal is to extract every distinct feature into its own focused file so each topic can be researched, discussed, and eventually implemented independently. The source docs are **kept as-is** (historical reference) — we are only creating new files.

---

## Naming Convention

```
docs/rm_NNN_topic_name.md
```

- `rm_` prefix = Risk Management
- `NNN` = zero-padded three-digit number (allows sorting and future insertions)
- Numbers roughly reflect implementation priority (Phase 1 → Phase 2 → Phase 3)

---

## Files to Create (11 files)

| # | Filename | Feature | Phase |
|---|----------|---------|-------|
| 1 | `rm_001_hard_stop_loss.md` | ATR-based hard stop loss per trade | 1 |
| 2 | `rm_002_max_lot_size_cap.md` | Absolute + dynamic lot size ceiling | 1 |
| 3 | `rm_003_leverage_normalisation.md` | Detect and compensate for account leverage | 1 |
| 4 | `rm_004_emergency_close.md` | Last-resort position close + trading halt | 1 |
| 5 | `rm_005_drawdown_circuit_breaker.md` | Pause trading after peak-to-trough threshold breach | 2 |
| 6 | `rm_006_consecutive_loss_limiter.md` | Pause after N consecutive losing trades | 2 |
| 7 | `rm_007_trading_pocket.md` | Segregate balance into Safe Capital / Trading Capital | 2 |
| 8 | `rm_008_effective_leverage_monitor.md` | Track account leverage × open positions | 2 |
| 9 | `rm_009_volatility_adjusted_sizing.md` | Scale lot size by current ATR vs historical ATR | 3 |
| 10 | `rm_010_dynamic_max_trades.md` | Reduce MaxTrades as account balance grows | 3 |
| 11 | `rm_011_profit_lock_in.md` | Transfer profits to Safe Capital at balance milestones | 3 |

---

## Standard Template for Each File

Every file follows this structure:

```markdown
# RM-NNN: [Feature Name]

**Status:** Draft
**Phase:** [1 / 2 / 3]
**Depends on:** [list any rm_NNN files this relies on, or "None"]

---

## 1. Problem

[What goes wrong without this feature. Concrete dollar + percentage examples.]

## 2. Root Cause

[Why the current code produces this problem.]

## 3. Proposed Solution

[Plain-English description of the mechanism.]

### Parameters
[Input parameters with types, defaults, and acceptable ranges.]

### Behaviour
[Step-by-step description of what the feature does on each tick / trade event.]

## 4. Examples

[Worked numerical examples showing before/after. At minimum two scenarios.]

## 5. Code Impact

### New include file (if applicable)
[File name and rough structure.]

### Functions to add
[Function signatures + one-sentence description.]

### Changes to existing files
[Which existing files need modification and why.]

### Integration point
[Where in OnTick / CalculateLotSize / etc. the feature is called.]

## 6. Modular Design

[How to enable/disable this feature with a single flag. No impact when disabled.]

## 7. Open Questions

[Any unresolved design decisions before implementation.]
```

---

## Content Outline — Key Points Per File

### rm_001 — Hard Stop Loss
- **Problem:** No hard stop on individual positions. A 100-pip adverse move at MarginUsage=0.5 can remove 25–85% of balance depending on leverage.
- **Solution:** ATR × multiplier sets stop distance. Lot size is back-calculated so that loss at stop = MaxRiskPercent × balance.
- **Code impact:** New `CalculateATRStop()` + modified `OpenPosition()` to pass SL price. Lot size formula changes from margin-based to risk-based.
- **Modular:** `EnableHardStop` flag. When false, SL=0 (current behaviour).

### rm_002 — Max Lot Size Cap
- **Problem:** At a $20K balance with 1:500 leverage, the margin-based formula produces 97+ lots per position. Even 1 pip adverse = 97% balance loss.
- **Solution:** Absolute cap `MaxLotSize` + dynamic cap `MaxLotsPerBalance × balance`. Applies after all other sizing.
- **Code impact:** One helper function `ApplyLotCap(double lots)` called at the end of `CalculateLotSize()`.
- **Modular:** `EnableLotCap` flag. When false, no ceiling applied.

### rm_003 — Leverage Normalisation
- **Problem:** The lot-size formula `lotSize = balance × MarginUsage / marginRequirement × BaseLotSize` inherently scales with broker leverage. At 1:2000 vs 1:100 the same balance produces 20× larger lots.
- **Solution:** Detect `AccountInfoInteger(ACCOUNT_LEVERAGE)`. Apply scale-down ratio when leverage exceeds `MaxAllowedLeverage`. Show warning if leverage exceeds `WarnAboveLeverage`.
- **Code impact:** `NormaliseLotForLeverage(double lots)` helper. Called inside `CalculateLotSize()`.
- **Modular:** `EnableLeverageNormalisation` flag.

### rm_004 — Emergency Close
- **Problem:** No automated last-resort shutdown. When equity falls below margin requirement the broker closes positions at worst possible moment.
- **Solution:** `EmergencyCloseAll()` closes all positions and sets a flag that disables all trade opening. Triggered automatically when drawdown > 35%, equity < 60% of balance, or margin level < 150.
- **Code impact:** New function, called at start of `OnTick()` before any other logic. Global `g_emergency_halt` flag checked in `OpenPosition()` and `SendBackup()`.
- **Modular:** `EnableEmergencyClose` flag.

### rm_005 — Drawdown Circuit Breaker
- **Problem:** A losing streak can cascade: each loss reduces balance, which eventually triggers backup system, which can compound losses further.
- **Solution:** Track `g_peak_balance`. When `(peak - equity) / peak > MaxDrawdownPercent` pause all new trades for `DrawdownRecoveryHours`. Graduated warnings at 15% and 20% before the 25% hard stop.
- **Code impact:** `CheckDrawdownCircuitBreaker()` called in `OnTick()`. Writes `g_circuit_breaker_pause_until`. `OpenPosition()` checks this timestamp.
- **Modular:** `EnableDrawdownCircuitBreaker` flag. Depends on rm_004 pattern for the pause mechanism.

### rm_006 — Consecutive Loss Limiter
- **Problem:** Systematic strategy failure (or market regime change) can produce 5–10 consecutive losses before any manual review. The EA keeps trading throughout.
- **Solution:** Count closed losing trades. After `MaxConsecutiveLosses` consecutive losses, pause for `ConsecutiveLossPauseHours`. Reset counter on any win.
- **Code impact:** `OnTradeTransaction()` or history polling in `PrepareAll()` to detect closed trades. Counter stored in global `g_consecutive_losses`.
- **Modular:** `EnableConsecutiveLossLimit` flag.

### rm_007 — Trading Pocket
- **Problem:** Position sizing uses total balance, so every profitable period increases subsequent trade risk. A win that grows balance from $2K to $4K also doubles the next loss exposure.
- **Solution:** Split balance into TradingCapital (capped at MaxTradingCapital) and SafeCapital (remainder). Lot-size formula uses TradingCapital only.
- **Code impact:** `CalculateTradingCapital()` returns the active amount. `CalculateLotSize()` uses this instead of `accountInfo.Balance()`.
- **Modular:** `EnableTradingPocket` flag. When disabled, TradingCapital = full balance (current behaviour).

### rm_008 — Effective Leverage Monitor
- **Problem:** Account leverage × number of open positions = effective leverage. 1:100 × 8 positions = 1:800 effective. A 12-pip move wipes the account.
- **Solution:** Calculate effective leverage each tick. Warn when > `WarnEffectiveLeverage`. Block new trades when > `MaxEffectiveLeverage`.
- **Code impact:** `GetEffectiveLeverage()` utility function. Check result in `OpenPosition()` before placing order.
- **Modular:** `EnableEffectiveLeverageCheck` flag. Depends on rm_003 for leverage reading pattern.

### rm_009 — Volatility-Adjusted Sizing
- **Problem:** Fixed lot size during high-volatility periods (news events, flash crashes) produces disproportionate P&L swings. The EA has no awareness of current volatility regime.
- **Solution:** Compare current ATR to rolling average ATR over `VolatilityLookback` bars. Scale lot size by `HighVolatilityMultiplier` (e.g. 0.5) or `LowVolatilityMultiplier` (e.g. 1.2).
- **Code impact:** `GetVolatilityMultiplier()` reads existing ATR handle from `PrismIndicators.mqh`. Applied as a multiplier at end of `CalculateLotSize()`.
- **Modular:** `EnableVolatilityAdjustment` flag. Reuses existing ATR infrastructure.

### rm_010 — Dynamic MaxTrades
- **Problem:** MaxTrades is a fixed parameter. As balance grows, each position is proportionally larger — allowing the same number of simultaneous positions creates exponentially higher total exposure.
- **Solution:** Tiered table: balance < $3K → 8, $3K–$10K → 6, $10K–$20K → 5, $20K+ → 3. Override the input MaxTrades with this computed value.
- **Code impact:** `GetDynamicMaxTrades()` returns effective limit. `OnTick()` uses this instead of raw `MaxTrades` input. Optionally also reduce based on leverage.
- **Modular:** `EnableDynamicMaxTrades` flag. When disabled, uses input `MaxTrades` unchanged.

### rm_011 — Profit Lock-In
- **Problem:** All profits remain in the active balance, which means they are fully at risk in subsequent trades. A single losing session can erase weeks of gains.
- **Solution:** At configurable balance milestones, transfer a percentage of cumulative profit to a tracked `g_locked_capital` value. Position sizing uses `balance - g_locked_capital` as the base.
- **Code impact:** `CheckProfitMilestones()` called on trade close. `CalculateLotSize()` subtracts locked capital. Pairs naturally with rm_007 (Trading Pocket).
- **Modular:** `EnableProfitLockIn` flag. Milestone table configurable via input array or fixed tiers.

---

## Code Modularity Strategy

All 11 features will be implemented in **one new include file**: `source/Includes/PrismRiskManager.mqh`

This file will:
- Define all risk-management input parameters (each with an `Enable*` boolean)
- Expose a clean API used by `prism.mq5`:
  - `InitRiskManager()` — called from `OnInit()`
  - `GetSafeLotSize(double rawLots)` — applies caps, leverage normalisation, volatility, pocket
  - `CanOpenTrade()` — returns bool (checks circuit breakers, consecutive losses, effective leverage, emergency halt)
  - `OnTradeClose(double profit)` — updates consecutive loss counter, profit lock-in milestones
  - `CheckRiskConditions()` — called each tick to update drawdown tracking, circuit breaker state
- When all `Enable*` flags are false, every function is a pass-through: zero behaviour change to current code.

`prism.mq5` changes are minimal:
1. `#include "Includes\\PrismRiskManager.mqh"`
2. `CalculateLotSize()` pipes through `GetSafeLotSize(rawLots)`
3. `OpenPosition()` / `SendBackup()` check `CanOpenTrade()`
4. `CloseAllPositions()` calls `OnTradeClose(profit)`
5. `PrepareAll()` calls `CheckRiskConditions()`

---

## Files to Create

| File | Action |
|------|--------|
| `docs/rm_001_hard_stop_loss.md` | Create |
| `docs/rm_002_max_lot_size_cap.md` | Create |
| `docs/rm_003_leverage_normalisation.md` | Create |
| `docs/rm_004_emergency_close.md` | Create |
| `docs/rm_005_drawdown_circuit_breaker.md` | Create |
| `docs/rm_006_consecutive_loss_limiter.md` | Create |
| `docs/rm_007_trading_pocket.md` | Create |
| `docs/rm_008_effective_leverage_monitor.md` | Create |
| `docs/rm_009_volatility_adjusted_sizing.md` | Create |
| `docs/rm_010_dynamic_max_trades.md` | Create |
| `docs/rm_011_profit_lock_in.md` | Create |

No existing files are modified. Source docs remain as historical reference.

---

## Verification

After creation:
- Each file follows the standard template (7 sections present)
- All 11 files exist in `docs/`
- `grep -r "rm_0" docs/` confirms naming convention is consistent
- Cross-references between files (e.g. rm_011 references rm_007) are accurate
- No implementation code changes have been made — docs only
