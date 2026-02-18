# RM-005: Drawdown Circuit Breaker

**Status:** Draft
**Phase:** 2
**Depends on:** rm_004 (shares `g_peak_balance` tracking)

---

## 1. Problem

The EA has no mechanism to detect and respond to a sustained drawdown period. It continues opening new positions regardless of how badly the current basket is performing. This means a strategy that is losing systematically — due to a regime change, a broken signal, or a volatile market — will keep adding positions until the account is destroyed.

The difference from rm_004 (Emergency Close) is severity and reversibility:
- **Emergency Close (rm_004):** One-way halt, fires at extreme thresholds (35% DD), requires manual EA restart.
- **Circuit Breaker (rm_005):** Temporary pause, fires earlier (20–25% DD), resumes automatically after a recovery period.

**Example — cascading loss without a circuit breaker:**

```
Day 1: Open 2 positions → lose $400 (8% DD from $5,000 peak)
Day 2: Open 3 more → lose $600 more (20% DD total — should pause here)
Day 3: Still trading → open 2 more → lose $700 more (34% DD)
Day 4: Emergency close fires at 35% — but $1,700 is already gone
```

A circuit breaker at 20% would have stopped new trades at Day 2, preserving $1,700 in subsequent losses.

---

## 2. Root Cause

There is no drawdown tracking against a peak balance in the current code. The existing `EnableStop` / `RelativeStop` checks a fixed ratio of historical profit — not a peak-to-trough equity drawdown. It is also only checked in `CheckLongStop()` (on profit conditions) and does not pause trading; it only closes positions.

---

## 3. Proposed Solution

Track peak equity continuously. When current equity falls by more than `CircuitBreakerPct` from the peak, pause all new trade opening for `CircuitBreakerRecoveryHours`. Resume automatically when the drawdown has recovered to half the threshold.

Use graduated alert levels to warn before the hard stop:

| Equity drawdown from peak | Action |
|--------------------------|--------|
| > `CircuitBreakerWarnPct` (default 15%) | Log warning, no trade restriction |
| > `CircuitBreakerReducePct` (default 20%) | Reduce lot size to 50% |
| > `CircuitBreakerPct` (default 25%) | Halt all new trades for `CircuitBreakerRecoveryHours` |

### Parameters

```mql5
input group "════════ RISK: DRAWDOWN CIRCUIT BREAKER ════════";
input bool   EnableCircuitBreaker          = true;   // Enable drawdown-based trading pause
input double CircuitBreakerWarnPct         = 0.15;   // Log warning at this drawdown from peak
input double CircuitBreakerReducePct       = 0.20;   // Reduce lot size by 50% at this drawdown
input double CircuitBreakerPct             = 0.25;   // Halt new trades at this drawdown
input int    CircuitBreakerRecoveryHours   = 24;     // Hours to pause trading after circuit breaker fires
```

### Behaviour

**Every tick in `CheckRiskConditions()`:**

1. Update `g_peak_balance = max(g_peak_balance, equity)`.
2. If `g_circuit_breaker_pause_until > TimeCurrent()`: return — still in pause period.
3. Calculate `drawdown = (g_peak_balance - equity) / g_peak_balance`.
4. If `drawdown > CircuitBreakerPct`:
   - Log: "CIRCUIT BREAKER: DD=X%, pausing trading for Y hours"
   - Set `g_circuit_breaker_pause_until = TimeCurrent() + CircuitBreakerRecoveryHours × 3600`
5. Else if `drawdown > CircuitBreakerReducePct`: set `g_lot_reduction_factor = 0.50`
6. Else if `drawdown > CircuitBreakerWarnPct`: log warning only
7. Else: `g_lot_reduction_factor = 1.0` (normal sizing)

**In `CanOpenTrade()`:**
Return false if `g_circuit_breaker_pause_until > TimeCurrent()`.

**In `GetSafeLotSize()`:**
Multiply by `g_lot_reduction_factor` (1.0 normally, 0.50 when in reduced mode).

**Resume condition:**
Once the pause expires (`TimeCurrent() > g_circuit_breaker_pause_until`), trading resumes. An optional stricter resume: only resume if `drawdown < CircuitBreakerReducePct / 2` (the balance has meaningfully recovered).

---

## 4. Examples

### Example A — Warning level, no restriction

```
Peak balance: $5,500 (after profitable period)
Current equity: $4,620
Drawdown: ($5,500 - $4,620) / $5,500 = 16% > CircuitBreakerWarnPct (15%)

Action: Log "WARNING: Drawdown 16% from peak $5,500"
No trade restriction — EA continues normally.
```

### Example B — Reduce level

```
Drawdown reaches 21%
Current equity: $4,345

Action: g_lot_reduction_factor = 0.50
New trades: lotSize × 0.50 (half the normal size)
Reduced exposure limits further losses while strategy continues.
```

### Example C — Circuit breaker fires

```
Drawdown reaches 26%
Current equity: $4,070

Action: g_circuit_breaker_pause_until = now + 24 hours
No new positions for 24 hours.
Log: "CIRCUIT BREAKER TRIGGERED: DD=26%, pausing until [timestamp]"
Existing open positions continue to be managed (ManagePositions still runs).
```

### Example D — Auto-resume

```
24 hours later: g_circuit_breaker_pause_until < TimeCurrent()
Current drawdown: 12% (market has partially recovered)
12% < CircuitBreakerReducePct / 2 (10%) ... still above — use strict resume

Alternative with lenient resume: 12% < 25% → resume trading at full size
```

Resume behaviour (strict vs lenient) is an implementation choice — see Open Questions.

---

## 5. Code Impact

### New state (in `PrismRiskManager.mqh`)

```mql5
static datetime g_circuit_breaker_pause_until = 0;
static double   g_lot_reduction_factor        = 1.0;
// g_peak_balance shared with rm_004
```

### New functions (in `PrismRiskManager.mqh`)

```mql5
// Called every tick. Updates peak balance, checks drawdown thresholds.
void CheckDrawdownCircuitBreaker();

// Returns current lot reduction factor (1.0 = normal, 0.5 = halved)
double GetCircuitBreakerLotFactor();

// Returns true if circuit breaker pause is currently active
bool IsCircuitBreakerActive();
```

### Changes to `prism.mq5`

`PrepareAll()` or `OnTick()` — add:

```mql5
if(EnableCircuitBreaker) CheckDrawdownCircuitBreaker();
```

`CalculateLotSize()` — after lot computation:

```mql5
if(EnableCircuitBreaker)
{
   lotSize       *= GetCircuitBreakerLotFactor();
   backupLotSize *= GetCircuitBreakerLotFactor();
}
```

`CanOpenTrade()` — add check:

```mql5
if(EnableCircuitBreaker && IsCircuitBreakerActive()) return false;
```

### Integration point

`CheckDrawdownCircuitBreaker()` is called early in `OnTick()`, after `PrepareAll()`, before position opening. `ManagePositions()` and `CheckLongStop()` are **not** gated — existing positions continue to be managed during a pause.

---

## 6. Modular Design

Controlled by `EnableCircuitBreaker` flag.

- **`false`** (disabled): None of the circuit breaker functions are called. No state is modified. Identical to current behaviour.
- **`true`** (enabled): Three graduated levels of response. Pause is temporary and automatic.

The shared `g_peak_balance` variable is also used by rm_004. If both modules are enabled, the same tracked peak is used by both — no duplication. If only rm_005 is enabled without rm_004, the peak tracking still works correctly.

---

## 7. Open Questions

1. **Strict vs lenient resume:** Should trading resume simply when the time period expires, or should it also require the drawdown to have recovered below a secondary threshold? The lenient approach resumes faster but may re-enter a still-troubled market.

2. **Interaction with existing `ManagePositions()`:** During a circuit breaker pause, existing positions should still be managed for exit (profit targets, safe exits). Does the pause correctly only affect `OpenPosition()` and `SendBackup()` but not `ManagePositions()`?

3. **Reset of peak balance after circuit breaker fires:** When the breaker fires and trading pauses, should `g_peak_balance` be reset to the current (lower) equity when trading resumes? This would prevent the circuit breaker from immediately re-firing when the balance hasn't fully recovered to the old peak.

4. **Multiple concurrent activations:** If the circuit breaker fires, is paused, and during the pause the drawdown worsens further — should the pause timer extend, or should rm_004 Emergency Close take over?
