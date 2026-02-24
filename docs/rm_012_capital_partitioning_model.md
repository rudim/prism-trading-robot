# RM-012: Capital Partitioning Model

**Status:** Draft
**Phase:** 2
**Supersedes:** rm_004 (Emergency Close), rm_007 (Trading Pocket), rm_011 (Profit Lock-In)
**Depends on:** None

---

## 1. Problem

The EA sizes every position relative to the full account balance. This creates three compounding problems that no single prior specification fully solved:

1. **Uncapped position growth.** As the account grows, the same `MarginUsage` percentage drives larger and larger lot sizes. Gains fund progressively bigger bets, and any single adverse event can erase months of careful profit.

2. **No protected capital floor.** All profits remain fully at risk. A flash crash or overnight gap can wipe every dollar ever earned with no mechanism to preserve anything.

3. **No capital-aware emergency shutdown.** The emergency close in rm_004 triggers on generic drawdown or equity thresholds. It has no knowledge of whether the account has accumulated locked profit that should never be touched.

The root cause is the same across all three: a flat, single-pool account model where every dollar — earned or original — is permanently exposed to the next position.

---

## 2. The Three-Bucket Capital Model

This specification replaces the flat account model with three conceptual capital buckets:

```
┌───────────────────────────────────────────────────────────┐
│                     TOTAL BALANCE                         │
├───────────────┬──────────────────────┬────────────────────┤
│ TRADING       │ MARGIN               │ PROFIT             │
│ CAPITAL       │ CAPITAL              │ CAPITAL            │
│               │                      │                    │
│ Drives lot    │ Absorbs floating     │ Locked. Never      │
│ sizing.       │ losses. Maximum      │ used for sizing.   │
│ Bounded by    │ drawdown before      │ Emergency close    │
│ % + min/max.  │ profit is at risk.   │ fires if equity    │
│               │                      │ threatens this.    │
└───────────────┴──────────────────────┴────────────────────┘
```

**Definitions:**

- **Profit Capital** — Cumulative locked profit. Accumulated at configurable balance milestones. Never used for sizing. Emergency close fires if floating losses threaten to breach this floor.
- **Trading Capital** — The bounded amount that drives lot size calculations. Calculated as a percentage of available balance (total minus profit capital), clamped between a minimum and maximum.
- **Margin Capital** — The implicit buffer. Everything that is neither trading capital nor profit capital. Represents the maximum floating loss the account can sustain before a profit-floor emergency close triggers.

**Balance identity:**

```
Total Balance = Profit Capital + Trading Capital + Margin Capital
Available Balance = Total Balance − Profit Capital
Trading Capital = Clamp(Available Balance × TradingPocketPct, MinTradingCapital, MaxTradingCapital)
Margin Capital = Available Balance − Trading Capital  [informational, not a configurable input]
```

---

## 3. Progressive Risk Configuration

The model is tiered. Each tier can be enabled independently. A trader can start permissive and tighten controls progressively.

| Tier | Settings enabled | What changes |
|------|-----------------|--------------|
| **0 — Baseline** | `EnableEmergencyClose = true` only | Generic drawdown / equity / margin-level shutdown. No capital split. Full balance drives sizing. |
| **1 — Pocket** | + `EnableTradingPocket = true` | Position sizing capped. Lot sizes stop growing as balance grows. |
| **2 — Lock-In** | + `EnableProfitLockIn = true` | Profits accumulate in a protected bucket at balance milestones. Pocket operates on unlocked balance only. |
| **3 — Floor** | + `EnableProfitFloor = true` | Emergency close becomes capital-aware: fires if floating losses threaten the locked profit floor. |

Each tier adds protection without breaking the tier below. Disabling a tier restores identical behaviour to the tier beneath it.

---

## 4. Parameters

```mql5
input group "════════ RISK: CAPITAL PARTITIONING MODEL ════════";

// ── Tier 0: Emergency Close ──────────────────────────────────────────────────
input bool   EnableEmergencyClose    = true;
// Close all positions and halt trading if any of these thresholds are breached:
input double EmergencyDrawdownPct    = 0.35;  // Peak-to-current equity drawdown (0.35 = 35%)
input double EmergencyEquityRatio    = 0.60;  // Equity / Balance ratio (0.60 = 60%)
input double EmergencyMarginLevel    = 150;   // MT5 margin level % (150 = 150%)

// ── Tier 1: Trading Pocket ────────────────────────────────────────────────────
input bool   EnableTradingPocket     = false;
// What fraction of available balance is used for position sizing:
input double TradingPocketPct        = 0.30;  // 30% of available balance is trading capital
// Hard limits on trading capital regardless of balance or percentage:
input double MinTradingCapital       = 1000;  // Trading capital is never less than this ($)
input double MaxTradingCapital       = 5000;  // Trading capital never exceeds this ($)

// ── Tier 2: Profit Lock-In ────────────────────────────────────────────────────
input bool   EnableProfitLockIn      = false;
input double InitialBalance          = 2000;  // Balance when EA was first started ($)
                                              // Used to calculate cumulative profit.
                                              // Tip: set to current balance on first attach.
input double LockInStartBalance      = 3000;  // First milestone — begin locking profit at this balance ($)
input double LockInBalanceStep       = 2000;  // Lock in profit at every $N increase above start ($)
input double LockInPercent           = 0.30;  // % of unlocked cumulative profit to lock at each milestone

// ── Tier 3: Profit Floor Emergency Close ─────────────────────────────────────
input bool   EnableProfitFloor       = false;
// Floor definition — choose fixed amount or percentage of locked profit:
input bool   ProfitFloorIsFixed      = false;    // false = % of locked profit | true = fixed $ amount
input double ProfitFloorPct          = 1.00;     // (when false) 1.00 = protect 100% of locked profit
                                                  // 0.80 = allow up to 20% of locked profit to be risked
input double ProfitFloorAmount       = 500;      // (when true)  minimum locked $ that must remain safe ($)
```

---

## 5. Behaviour

### 5.1 Capital Calculation — `CalculateCapitalBuckets()`

Called at the start of `CalculateLotSize()` and `UpdateDisplay()`.

```
totalBalance     = accountInfo.Balance()
profitCapital    = GetProfitCapital()         // see §5.2
availableBalance = totalBalance − profitCapital

if EnableTradingPocket:
    tradingCapital = Clamp(availableBalance × TradingPocketPct,
                           MinTradingCapital, MaxTradingCapital)
else:
    tradingCapital = availableBalance          // entire available balance drives sizing

marginCapital = availableBalance − tradingCapital   // informational
```

### 5.2 Profit Capital — `GetProfitCapital()` and `CheckProfitMilestones()`

`GetProfitCapital()` returns `g_locked_profit`. This is zero when `EnableProfitLockIn = false`.

`CheckProfitMilestones(currentBalance)` — called after every position close:

1. `tier = floor((currentBalance − LockInStartBalance) / LockInBalanceStep)`.
2. If `tier > g_last_milestone_tier` and `currentBalance > LockInStartBalance`:
   - `unlockedProfit = currentBalance − InitialBalance − g_locked_profit`.
   - If `unlockedProfit > 0`: `g_locked_profit += unlockedProfit × LockInPercent`.
   - `g_last_milestone_tier = tier`.
   - Log: `"Profit lock-in: $X locked at balance $Y. Total locked: $Z."`.

### 5.3 Lot Sizing — `CalculateLotSize()`

The full decision tree, covering all combinations:

```mql5
double totalBalance     = accountInfo.Balance();
double profitCapital    = GetProfitCapital();         // 0 when Tier 2 disabled
double availableBalance = totalBalance - profitCapital;

double tradingBase;
if(EnableTradingPocket)
    tradingBase = Clamp(availableBalance * TradingPocketPct,
                        MinTradingCapital, MaxTradingCapital);
else
    tradingBase = availableBalance;

lotSize       = NormalizeDouble((tradingBase * MarginUsage  / marginRequirement) * BaseLotSize, 2);
backupLotSize = NormalizeDouble((tradingBase * BackupMargin / marginRequirement) * BaseLotSize, 2);
```

### 5.4 Emergency Close — `CheckEmergencyConditions()`

Called at the start of every `OnTick()`. Checks conditions in priority order:

**Condition 1 — Profit Floor (Tier 3):**

```
if EnableProfitFloor and g_locked_profit > 0:
    floorEquity = CalculateProfitFloor()
    if equity < floorEquity:
        EmergencyCloseAll("PROFIT_FLOOR")
```

Where `CalculateProfitFloor()` returns:

```
if ProfitFloorIsFixed:
    return ProfitFloorAmount
else:
    return g_locked_profit × ProfitFloorPct
```

**Condition 2 — Drawdown from peak (Tier 0):**

```
dd = (g_peak_balance − equity) / g_peak_balance
if dd > EmergencyDrawdownPct:
    EmergencyCloseAll("DRAWDOWN")
```

**Condition 3 — Equity / Balance ratio (Tier 0):**

```
if equity / balance < EmergencyEquityRatio:
    EmergencyCloseAll("EQUITY_FLOOR")
```

**Condition 4 — Margin level (Tier 0):**

```
if marginLevel > 0 and marginLevel < EmergencyMarginLevel:
    EmergencyCloseAll("MARGIN_LEVEL")
```

`EmergencyCloseAll(reason)`:

1. Set `g_emergency_halt = true`.
2. Close all open positions for current symbol + magic.
3. Log reason, current balance, and locked profit to Experts log.
4. Send MT5 push notification if configured.

`CanOpenTrade()` returns `false` whenever `g_emergency_halt = true`. Checked in `OpenPosition()` and `SendBackup()` before placing any order.

`g_peak_balance` is updated on every tick when `equity > g_peak_balance`.

---

## 6. Examples

### Example A — Tier 1 only (Trading Pocket, no profit lock)

```
Balance = $10,000, TradingPocketPct = 0.30, Max = $5,000
profitCapital = $0 (lock-in disabled)
availableBalance = $10,000
tradingCapital = $10,000 × 0.30 = $3,000 (within [$1,000, $5,000])
marginCapital = $7,000

Lot sizing uses $3,000, not $10,000.
Max floating loss before generic emergency (EmergencyEquityRatio 0.60):
  floor equity = $10,000 × 0.60 = $6,000
  max float loss = $10,000 − $6,000 = $4,000
```

### Example B — Tier 2 (Pocket + Lock-In)

```
InitialBalance = $2,000, now Balance = $7,000
Milestones at $3,000 and $5,000 have triggered.

After $3,000 milestone:
  profit = $3,000 − $2,000 − $0 = $1,000  →  lock $300
After $5,000 milestone:
  profit = $5,000 − $2,000 − $300 = $2,700  →  lock $810
g_locked_profit = $1,110

At $7,000 balance:
  profitCapital = $1,110
  availableBalance = $7,000 − $1,110 = $5,890
  tradingCapital = $5,890 × 0.30 = $1,767 (within [$1,000, $5,000])
  marginCapital = $5,890 − $1,767 = $4,123

Locked profit ($1,110) is entirely removed from the sizing base.
```

### Example C — Tier 3 (Profit Floor emergency close)

```
Balance = $7,000, g_locked_profit = $1,110
ProfitFloorIsFixed = false, ProfitFloorPct = 1.00
floorEquity = $1,110 × 1.00 = $1,110

Open positions move against account.
Equity drops from $7,000 toward $1,110.
At equity = $1,110: EmergencyCloseAll("PROFIT_FLOOR") fires.

Remaining balance ≈ $1,110 (the locked profit is fully preserved).
Account survives and can be restarted.
```

### Example D — Partial profit floor (ProfitFloorPct = 0.80)

```
g_locked_profit = $2,000
floorEquity = $2,000 × 0.80 = $1,600

Emergency close fires at equity = $1,600.
Up to $400 (20% of locked profit) can be lost to floating positions.
Remaining at close ≈ $1,600.
```

### Example E — Fixed floor amount

```
ProfitFloorIsFixed = true, ProfitFloorAmount = $500
g_locked_profit = $2,800
floorEquity = $500

Emergency close fires at equity = $500.
$500 is always preserved regardless of how much was locked.
(Simpler to reason about; appropriate when you want a hard dollar floor.)
```

### Example F — Capital breakdown across balance levels

| Balance | Profit Capital | Available | Trading Capital (30%) | Margin Capital |
|---------|---------------|-----------|----------------------|----------------|
| $2,000 | $0 | $2,000 | $1,000 (min floor) | $1,000 |
| $5,000 | $300 | $4,700 | $1,410 | $3,290 |
| $10,000 | $1,110 | $8,890 | $2,667 | $6,223 |
| $20,000 | $2,277 | $17,723 | $5,000 (max cap) | $12,723 |
| $50,000 | $4,200 | $45,800 | $5,000 (max cap) | $40,800 |

At large balances, the MaxTradingCapital cap keeps lot sizes flat while margin capital becomes very large — providing extensive drawdown tolerance before any profit floor is threatened.

### Example G — Black swan with all tiers enabled

```
Balance = $10,000
g_locked_profit = $1,110 (Tier 2)
tradingCapital = $2,667
marginCapital = $6,223
ProfitFloorPct = 1.00  →  floorEquity = $1,110

Black swan: all positions gap 300 pips against account.
Lot size (from $2,667 base) ≈ 0.13 lots.
300-pip loss on 0.13 lots = $390.

Without model: 300-pip × 0.49 lots (full $10K) = $1,470 (14.7%)
With model:    300-pip × 0.13 lots             = $390  (3.9%)

Even if the worst possible outcome consumed all margin capital ($6,223),
the profit floor fires at equity = $1,110.
Account survives with locked profit intact.
```

---

## 7. Code Impact

### New state (in `PrismRiskManager.mqh`)

```mql5
static double g_locked_profit             = 0.0;
static int    g_last_milestone_tier       = -1;
static bool   g_emergency_halt            = false;
static double g_peak_balance              = 0.0;
```

### New functions (in `PrismRiskManager.mqh`)

```mql5
// Returns locked profit (0 when EnableProfitLockIn = false).
double GetProfitCapital();

// Returns active trading capital based on pocket settings and locked profit.
// When all features disabled, returns accountBalance unchanged.
double CalculateTradingCapital(double totalBalance);

// Returns informational margin capital (not used for sizing).
double CalculateMarginCapital(double totalBalance);

// Checks whether balance has crossed a new milestone and locks profit if so.
// Call after any position close.
void CheckProfitMilestones(double currentBalance);

// Returns the equity floor below which profit-floor emergency triggers.
double CalculateProfitFloor();

// Evaluates all emergency conditions. Calls EmergencyCloseAll() if any threshold is breached.
void CheckEmergencyConditions();

// Closes all positions for current symbol + magic. Sets g_emergency_halt.
void EmergencyCloseAll(string reason);

// Returns false if emergency halt is active.
bool CanOpenTrade();
```

### Changes to `prism.mq5`

**`CalculateLotSize()`** — replace the balance variable:

```mql5
double totalBalance  = accountInfo.Balance();
double profitCapital = GetProfitCapital();
double tradingBase   = CalculateTradingCapital(totalBalance);

lotSize       = NormalizeDouble((tradingBase * MarginUsage  / marginRequirement) * BaseLotSize, 2);
backupLotSize = NormalizeDouble((tradingBase * BackupMargin / marginRequirement) * BaseLotSize, 2);
```

**`CloseAllPositions()`** — after each successful close:

```mql5
if(EnableProfitLockIn)
    CheckProfitMilestones(accountInfo.Balance());
```

**`OnTick()`** — at the top, before any trade logic:

```mql5
void OnTick()
{
    PrepareAll();

    // Update peak balance for drawdown tracking
    double equity = accountInfo.Equity();
    if(equity > g_peak_balance) g_peak_balance = equity;

    // Emergency conditions (includes profit floor if Tier 3 enabled)
    if(EnableEmergencyClose) CheckEmergencyConditions();

    if(CloseAll || !CanOpenTrade())
    {
        if(CloseAll) CloseAllPositions();
        return;
    }
    // ... rest of OnTick
}
```

**`UpdateDisplay()`** — add capital breakdown to HUD:

```mql5
double total   = accountInfo.Balance();
double profit  = GetProfitCapital();
double trading = CalculateTradingCapital(total);
double margin  = CalculateMarginCapital(total);

if(EnableProfitLockIn)
    display += " Locked: $" + DoubleToString(profit, 0);
if(EnableTradingPocket)
    display += " Trading: $" + DoubleToString(trading, 0)
             + " Margin: $"  + DoubleToString(margin, 0);
if(g_emergency_halt)
    display += " *** EMERGENCY HALT ***";
```

### Integration points

| Change | Location |
|--------|----------|
| Lot size base substitution | `CalculateLotSize()` in `prism.mq5` |
| Profit milestone check | `CloseAllPositions()` in `prism.mq5` |
| Emergency conditions check | Top of `OnTick()` in `prism.mq5` |
| Trade gate | `OpenPosition()` and `SendBackup()` via `CanOpenTrade()` |
| HUD display | `UpdateDisplay()` in `prism.mq5` |

---

## 8. Modular Design

Each tier is independently controlled by its own flag. Disabling a tier produces behaviour identical to that tier not existing.

| Flags | Effective behaviour |
|-------|---------------------|
| All disabled | Full balance used for sizing. Generic emergency close only (if `EnableEmergencyClose`). |
| `EnableTradingPocket` only | Lot sizing capped. Profit floor inactive. |
| `EnableProfitLockIn` only | Profit accumulates but pocket not active; trading base = balance − locked profit. |
| `EnableTradingPocket` + `EnableProfitLockIn` | Pocket operates on unlocked balance. Profit is protected from sizing. |
| All enabled | Full model: locked profit floor, capped trading capital, capital-aware emergency close. |

The `g_locked_profit` state is session-persistent only. It resets if MT5 restarts or the EA is removed — see Open Questions §9.2.

---

## 9. Open Questions

1. **`InitialBalance` as an input:** If the user forgets to update this when attaching the EA to a new account, profit calculations will be wrong. Can `OnInit()` read the current balance and use it as the default, with the input as an override only?

2. **Persistence across restarts:** `g_locked_profit` and `g_last_milestone_tier` are static variables that reset on EA restart. For long-term operation, these should be written to a file using `FileOpen` / `FileWrite` and reloaded in `OnInit()`.

3. **Re-trigger on balance recovery:** If balance drops from $7,000 back to $4,500, the Tier 2 milestone at $5,000 has already been processed. Should it re-trigger when the account crosses $5,000 again on the way back up?

4. **Milestone step sizing:** A fixed dollar step (e.g., every $2,000) represents a shrinking percentage as the account grows. Should the step be percentage-based instead (e.g., lock at every 20% balance increase)?

5. **Emergency halt restart policy:** Once `g_emergency_halt = true`, it persists until the EA is removed and re-attached. Is this desirable, or should there be an optional cooling-off period (similar to rm_005's `DrawdownRecoveryHours`) after which the halt clears automatically?

6. **Interaction with `DailyGrowth` targets:** The `dailyGrowth` and `SafeGrowth` checks in `CalculateLotSize()` compare against `accountInfo.Balance()`. Should these thresholds compare against `tradingCapital` instead, to keep targets meaningful relative to the active sizing base?

7. **Partial emergency close:** Rather than closing all positions, could the profit-floor trigger close only the losing positions while keeping profitable ones open? Preserves upside but adds complexity.

8. **Backup system interaction:** The backup system is designed to trade during drawdowns. Should the profit-floor emergency close take precedence over — or be coordinated with — `BackupWithCalendarCheck()`?
