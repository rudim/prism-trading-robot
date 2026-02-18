# Milestone 21.x - Risk Management Enhancement Specification

**Version:** 21.x
**Date:** 2026-02-16
**Author:** Claude Code
**Status:** Draft for Review

---

## Executive Summary

Analysis of the Milestone 20.x strategy revealed catastrophic account wipeouts caused by black swan events. The current implementation lacks adequate risk controls to prevent cascading losses. This specification outlines a comprehensive risk management framework that maintains the strategy's profit potential while implementing multiple layers of protection.

**Key Finding:** Lower MarginUsage (0.1) causes early account depletion due to insufficient profit buffer, while higher MarginUsage (0.5) allows survival but creates vulnerability to single catastrophic trades.

**Solution:** Maintain aggressive position sizing for growth, but add multiple safety mechanisms to prevent black swan events from causing total account loss.

---

## Table of Contents

1. [Problem Analysis](#1-problem-analysis)
2. [Design Philosophy](#2-design-philosophy)
3. [Proposed Safety Mechanisms](#3-proposed-safety-mechanisms)
4. [Implementation Priority](#4-implementation-priority)
5. [Parameter Specifications](#5-parameter-specifications)
6. [Testing Strategy](#6-testing-strategy)
7. [Rollback Plan](#7-rollback-plan)

---

## 1. Problem Analysis

### 1.1 Current Failure Modes

#### Failure Mode 1: Catastrophic Single Trade Loss
- **Scenario:** Large position enters during volatile period
- **Example:** $3,800 balance → $570 in one trade (-85%)
- **Root Cause:** No hard stop loss; RelativeStop triggers too late
- **Frequency:** Low (black swan events)
- **Impact:** CRITICAL - Total account loss

#### Failure Mode 2: Insufficient Growth Buffer
- **Scenario:** Small positions cannot build profit buffer fast enough
- **Example:** MarginUsage=0.1 leads to slow growth, early wipeout
- **Root Cause:** Risk/reward imbalance for account size
- **Frequency:** High with conservative settings
- **Impact:** HIGH - Slow death by thousand cuts

#### Failure Mode 3: Cascading Failures
- **Scenario:** Loss → Reduced capital → Larger relative risk → Bigger loss
- **Example:** Trade sequence: +$1,800 → -$3,230 → +$660 → -$2,460 (margin call)
- **Root Cause:** No circuit breakers to stop trading after major loss
- **Frequency:** Medium after initial large loss
- **Impact:** CRITICAL - Accelerates account death

### 1.2 Why Existing Safeguards Failed

| Safeguard | Intended Purpose | Why It Failed |
|-----------|------------------|---------------|
| **RelativeStop** | Protect accumulated profits | Triggers after loss, not during; 5-minute trades move too fast |
| **DailyGrowth** | Limit daily profit taking | Doesn't prevent losses; only limits wins |
| **SafeGrowth** | Close all at daily target | Doesn't help during losing trades |
| **MinProfit** | Individual position exits | Only for profitable positions |
| **SleepSeconds** | Spacing between trades | Doesn't prevent bad trade entry |

**Conclusion:** All existing safeguards are profit-focused, not loss-prevention focused.

---

## 2. Design Philosophy

### 2.1 Core Principles

1. **Asymmetric Risk Management**
   - Allow unlimited upside (keep aggressive growth)
   - Strictly limit downside (cap maximum loss per trade)

2. **Multiple Layers of Defense** (Swiss Cheese Model)
   - Each layer has gaps
   - Multiple layers prevent total failure
   - No single point of failure

3. **Market-Adaptive Sizing**
   - Position size based on current volatility (ATR)
   - Larger positions in calm markets
   - Smaller positions in volatile markets

4. **Circuit Breakers**
   - Automatic trading pause after major loss
   - Prevents emotional/algorithmic revenge trading
   - Time for market conditions to normalize

5. **Graceful Degradation**
   - System should fail safely, not catastrophically
   - Protect capital over maximizing profit
   - Preserve ability to recover

### 2.2 Key Metrics to Optimize

- **Maximum Single Trade Loss:** <15% of balance
- **Maximum Daily Drawdown:** <25% of balance
- **Maximum Consecutive Losses:** 3 trades
- **Recovery Time:** <7 days after major loss
- **Win Rate:** Maintain ≥45%
- **Profit Factor:** Maintain ≥1.5

---

## 3. Proposed Safety Mechanisms

### 3.1 Hard Stop Loss (ATR-Based) ⭐ PRIORITY 1

#### Purpose
Prevent any single trade from losing more than a fixed percentage of balance.

#### Specification

```mql5
//--- Input parameters
input bool     EnableHardStop = true;        // Enable hard stop loss
input double   ATRMultiplier = 2.5;          // Stop loss = ATR × multiplier
input double   MinStopLossPips = 15;         // Minimum stop loss in pips
input double   MaxStopLossPips = 50;         // Maximum stop loss in pips
input double   MaxRiskPercent = 0.15;        // Maximum risk per trade (15%)

//--- Implementation
double CalculateStopLoss(string symbol, ENUM_TIMEFRAMES timeframe,
                         ENUM_ORDER_TYPE type, double entry_price)
{
   // Get ATR
   double atr = iATR(symbol, timeframe, ATRPeriod, 0);

   // Calculate stop distance
   double stop_pips = (atr / _Point) * ATRMultiplier;

   // Apply limits
   stop_pips = MathMax(stop_pips, MinStopLossPips);
   stop_pips = MathMin(stop_pips, MaxStopLossPips);

   // Convert to price
   double sl_price;
   if (type == ORDER_TYPE_BUY)
      sl_price = entry_price - stop_pips * _Point;
   else
      sl_price = entry_price + stop_pips * _Point;

   return sl_price;
}

//--- Position sizing based on stop loss
double CalculateLotSize(double stop_loss_pips)
{
   double risk_amount = AccountBalance() * MaxRiskPercent;
   double pip_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   double lot_size = risk_amount / (stop_loss_pips * pip_value * 10);

   // Apply minimum and maximum
   lot_size = MathMax(lot_size, MinLots);
   lot_size = MathMin(lot_size, MaxLotSize);

   // Round to valid lot step
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot_size = MathFloor(lot_size / lot_step) * lot_step;

   return lot_size;
}
```

#### Benefits
- ✅ Prevents catastrophic single trade losses
- ✅ Adapts to market volatility
- ✅ Compatible with existing position sizing
- ✅ Industry standard risk management

#### Risks
- ⚠️ May reduce profit potential in trending markets
- ⚠️ Stop loss hunting by brokers
- ⚠️ Whipsaw in volatile markets

#### Mitigation
- Use 2.5× ATR to avoid tight stops
- Implement MinStopLossPips = 15 to prevent hunting
- MaxStopLossPips = 50 to cap worst case

---

### 3.2 Maximum Lot Size Cap ⭐ PRIORITY 1

#### Purpose
Prevent position size from growing unbounded as account balance increases.

#### Specification

```mql5
//--- Input parameters
input double   MaxLotSize = 0.20;            // Maximum lot size (absolute cap)
input double   MaxLotsPerBalance = 0.10;     // Max lots per $1,000 balance
input bool     EnableDynamicCap = true;      // Use dynamic cap based on balance

//--- Implementation
double ApplyLotSizeCap(double calculated_lot_size)
{
   double final_lot_size = calculated_lot_size;

   // Apply absolute cap
   final_lot_size = MathMin(final_lot_size, MaxLotSize);

   // Apply dynamic cap based on balance
   if (EnableDynamicCap)
   {
      double balance_factor = AccountBalance() / 1000.0;
      double dynamic_cap = MaxLotsPerBalance * balance_factor;
      final_lot_size = MathMin(final_lot_size, dynamic_cap);
   }

   // Ensure within broker limits
   double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   final_lot_size = MathMin(final_lot_size, max_volume);

   return final_lot_size;
}
```

#### Benefits
- ✅ Prevents "win big, lose bigger" cycle
- ✅ Limits exposure regardless of balance growth
- ✅ Simple to implement and test
- ✅ No complex calculations

#### Configuration Examples

| Account Balance | MaxLotSize | MaxLotsPerBalance | Effective Cap |
|-----------------|------------|-------------------|---------------|
| $2,000 | 0.20 | 0.10 | 0.20 (absolute) |
| $5,000 | 0.20 | 0.10 | 0.20 (absolute) |
| $10,000 | 0.50 | 0.10 | 0.50 (1.0 lots would be capped to 0.5) |

---

### 3.3 Maximum Drawdown Circuit Breaker ⭐ PRIORITY 2

#### Purpose
Automatically halt trading when drawdown exceeds threshold, preventing cascading losses.

#### Specification

```mql5
//--- Input parameters
input bool     EnableDrawdownStop = true;    // Enable drawdown circuit breaker
input double   MaxDrawdownPercent = 0.25;    // Stop trading at 25% drawdown
input int      DrawdownRecoveryHours = 24;   // Hours to wait before resuming
input bool     CloseOnDrawdown = true;       // Close all positions when triggered

//--- Global variables
datetime g_drawdown_pause_until = 0;
double g_peak_balance = 0;

//--- Implementation
bool CheckDrawdownCircuitBreaker()
{
   // Update peak balance
   if (AccountBalance() > g_peak_balance)
      g_peak_balance = AccountBalance();

   // Calculate current drawdown
   double current_drawdown = 0;
   if (g_peak_balance > 0)
      current_drawdown = (g_peak_balance - AccountBalance()) / g_peak_balance;

   // Check if circuit breaker triggered
   if (current_drawdown >= MaxDrawdownPercent)
   {
      if (g_drawdown_pause_until == 0)  // First time triggering
      {
         Print("⚠️ CIRCUIT BREAKER TRIGGERED! Drawdown: ",
               DoubleToString(current_drawdown * 100, 2), "%");

         // Close all positions if enabled
         if (CloseOnDrawdown)
         {
            CloseAllPositions("Circuit breaker - max drawdown");
         }

         // Set pause period
         g_drawdown_pause_until = TimeCurrent() + DrawdownRecoveryHours * 3600;

         // Send alert
         Alert("Circuit Breaker Activated - Trading paused for ",
               DrawdownRecoveryHours, " hours");

         return true;  // Trading paused
      }
   }

   // Check if still in pause period
   if (TimeCurrent() < g_drawdown_pause_until)
   {
      return true;  // Still paused
   }

   // Check if recovered enough to resume
   if (current_drawdown < MaxDrawdownPercent * 0.5)  // 50% recovery
   {
      if (g_drawdown_pause_until > 0)
      {
         Print("✅ Circuit breaker released - Trading resumed");
         g_drawdown_pause_until = 0;
      }
   }

   return false;  // Trading allowed
}

//--- Integration in OnTick()
void OnTick()
{
   // Check circuit breaker first
   if (CheckDrawdownCircuitBreaker())
      return;  // Trading paused

   // ... rest of trading logic
}
```

#### Benefits
- ✅ Prevents cascading losses after major drawdown
- ✅ Automatic recovery without manual intervention
- ✅ Psychological benefit (removes emotion)
- ✅ Allows market conditions to normalize

#### Alert Levels

| Drawdown | Action | Alert |
|----------|--------|-------|
| 15% | Warning | "⚠️ Approaching max drawdown" |
| 20% | Reduce position size by 50% | "⚠️ High drawdown - reducing risk" |
| 25% | **CIRCUIT BREAKER** | "🛑 TRADING PAUSED - Max drawdown reached" |

---

### 3.4 Consecutive Loss Limiter ⭐ PRIORITY 2

#### Purpose
Pause trading after consecutive losses to prevent systematic issues from compounding.

#### Specification

```mql5
//--- Input parameters
input int      MaxConsecutiveLosses = 3;     // Stop after N consecutive losses
input int      ConsecutiveLossPauseHours = 6; // Hours to pause
input double   MinLossToCount = 0.01;        // Minimum loss % to count (1%)

//--- Global variables
int g_consecutive_losses = 0;
datetime g_consecutive_loss_pause_until = 0;

//--- Track trade result
void OnTradeClose(double profit)
{
   double balance = AccountBalance();
   double loss_percent = -profit / balance;

   if (profit < 0 && loss_percent >= MinLossToCount)
   {
      g_consecutive_losses++;

      Print("Consecutive losses: ", g_consecutive_losses, "/", MaxConsecutiveLosses);

      // Check if limit reached
      if (g_consecutive_losses >= MaxConsecutiveLosses)
      {
         g_consecutive_loss_pause_until = TimeCurrent() + ConsecutiveLossPauseHours * 3600;

         Alert("⚠️ ", MaxConsecutiveLosses, " consecutive losses - ",
               "Trading paused for ", ConsecutiveLossPauseHours, " hours");

         Print("Consecutive loss details:");
         // Log last N trades for analysis
      }
   }
   else if (profit > 0)
   {
      // Reset counter on win
      if (g_consecutive_losses > 0)
         Print("✅ Consecutive loss streak broken after ", g_consecutive_losses, " losses");
      g_consecutive_losses = 0;
   }
}

//--- Check before opening new trade
bool CanOpenNewTrade()
{
   // Check if in pause period
   if (TimeCurrent() < g_consecutive_loss_pause_until)
   {
      return false;
   }

   // Release pause if time expired
   if (g_consecutive_loss_pause_until > 0 && TimeCurrent() >= g_consecutive_loss_pause_until)
   {
      Print("✅ Consecutive loss pause expired - Trading resumed");
      g_consecutive_losses = 0;
      g_consecutive_loss_pause_until = 0;
   }

   return true;
}
```

#### Benefits
- ✅ Detects systematic problems (bad market conditions, broken logic)
- ✅ Prevents revenge trading mentality
- ✅ Forces analysis of what's going wrong
- ✅ Preserves capital during unfavorable conditions

---

### 3.5 Volatility-Adjusted Position Sizing ⭐ PRIORITY 3

#### Purpose
Reduce position size during high volatility periods to limit risk.

#### Specification

```mql5
//--- Input parameters
input bool     EnableVolatilityAdjustment = true;
input int      VolatilityLookback = 20;      // Bars to calculate average ATR
input double   VolatilityThresholdHigh = 1.5; // High volatility = ATR > 1.5× average
input double   VolatilityThresholdLow = 0.7;  // Low volatility = ATR < 0.7× average
input double   HighVolatilityMultiplier = 0.5; // Reduce position size by 50%
input double   LowVolatilityMultiplier = 1.2;  // Increase position size by 20%

//--- Calculate volatility regime
double GetVolatilityAdjustment()
{
   if (!EnableVolatilityAdjustment)
      return 1.0;

   // Get current ATR
   double current_atr = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod, 0);

   // Calculate average ATR over lookback period
   double sum_atr = 0;
   for (int i = 0; i < VolatilityLookback; i++)
   {
      sum_atr += iATR(_Symbol, PERIOD_CURRENT, ATRPeriod, i);
   }
   double avg_atr = sum_atr / VolatilityLookback;

   // Calculate volatility ratio
   double volatility_ratio = current_atr / avg_atr;

   // Determine adjustment
   double adjustment = 1.0;

   if (volatility_ratio > VolatilityThresholdHigh)
   {
      adjustment = HighVolatilityMultiplier;
      if (g_last_volatility_regime != "HIGH")
      {
         Print("⚠️ HIGH VOLATILITY DETECTED - Reducing position size to ",
               DoubleToString(adjustment * 100, 0), "%");
         g_last_volatility_regime = "HIGH";
      }
   }
   else if (volatility_ratio < VolatilityThresholdLow)
   {
      adjustment = LowVolatilityMultiplier;
      if (g_last_volatility_regime != "LOW")
      {
         Print("✅ LOW VOLATILITY - Increasing position size to ",
               DoubleToString(adjustment * 100, 0), "%");
         g_last_volatility_regime = "LOW";
      }
   }
   else
   {
      if (g_last_volatility_regime != "NORMAL")
      {
         Print("📊 NORMAL VOLATILITY - Standard position sizing");
         g_last_volatility_regime = "NORMAL";
      }
   }

   return adjustment;
}

//--- Apply to lot size calculation
double CalculateLotSizeWithVolatility()
{
   // Base lot size from existing logic
   double base_lot = CalculateBaseLotSize();

   // Apply volatility adjustment
   double volatility_adjustment = GetVolatilityAdjustment();
   double adjusted_lot = base_lot * volatility_adjustment;

   // Apply all caps
   adjusted_lot = ApplyLotSizeCap(adjusted_lot);

   return adjusted_lot;
}
```

#### Benefits
- ✅ Automatically reduces risk during black swan events
- ✅ Increases profit during favorable conditions
- ✅ Market-adaptive without manual intervention
- ✅ Complements other safety mechanisms

---

### 3.6 Emergency Close Function ⭐ PRIORITY 3

#### Purpose
Provide manual and automatic emergency shutdown capability.

#### Specification

```mql5
//--- Input parameters
input bool     EnableEmergencyClose = true;
input double   EmergencyDrawdownPercent = 0.35;  // Emergency at 35% drawdown
input string   EmergencyHotkey = "Ctrl+E";       // Keyboard shortcut

//--- Emergency close reasons
enum ENUM_EMERGENCY_REASON
{
   EMERGENCY_MANUAL,           // Manual trigger
   EMERGENCY_DRAWDOWN,         // Exceeded drawdown limit
   EMERGENCY_EQUITY,           // Equity too low
   EMERGENCY_MARGIN_CALL,      // Near margin call
   EMERGENCY_UNKNOWN_ERROR     // System error
};

//--- Emergency close function
void EmergencyCloseAll(ENUM_EMERGENCY_REASON reason)
{
   string reason_text;
   switch(reason)
   {
      case EMERGENCY_MANUAL:        reason_text = "MANUAL EMERGENCY CLOSE"; break;
      case EMERGENCY_DRAWDOWN:      reason_text = "EMERGENCY - Drawdown Limit"; break;
      case EMERGENCY_EQUITY:        reason_text = "EMERGENCY - Low Equity"; break;
      case EMERGENCY_MARGIN_CALL:   reason_text = "EMERGENCY - Margin Call Risk"; break;
      default:                      reason_text = "EMERGENCY - Unknown"; break;
   }

   Print("🚨🚨🚨 ", reason_text, " 🚨🚨🚨");
   Print("Closing all ", PositionsTotal(), " positions immediately");

   // Disable all trading
   g_trading_enabled = false;

   // Close all positions
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0)
      {
         PositionClose(ticket);
      }
   }

   // Cancel all pending orders
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if (ticket > 0)
      {
         OrderDelete(ticket);
      }
   }

   // Send alerts
   Alert("🚨 EMERGENCY CLOSE TRIGGERED: ", reason_text);
   SendNotification("Milestone EA - Emergency Close: " + reason_text);

   // Log state for analysis
   LogEmergencyState();

   Print("Emergency close completed. Trading disabled.");
}

//--- Check emergency conditions in OnTick()
void CheckEmergencyConditions()
{
   if (!EnableEmergencyClose)
      return;

   // Check drawdown
   if (g_peak_balance > 0)
   {
      double drawdown = (g_peak_balance - AccountBalance()) / g_peak_balance;
      if (drawdown >= EmergencyDrawdownPercent)
      {
         EmergencyCloseAll(EMERGENCY_DRAWDOWN);
         return;
      }
   }

   // Check equity vs balance
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if (equity < balance * 0.6)  // Equity < 60% of balance
   {
      EmergencyCloseAll(EMERGENCY_EQUITY);
      return;
   }

   // Check margin level
   double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if (margin_level < 150 && margin_level > 0)  // Near margin call
   {
      EmergencyCloseAll(EMERGENCY_MARGIN_CALL);
      return;
   }
}

//--- Handle keyboard shortcut
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if (id == CHARTEVENT_KEYDOWN)
   {
      // Check for Ctrl+E
      if (lparam == 69 && (TerminalInfoInteger(TERMINAL_KEYSTATE_CONTROL) < 0))
      {
         EmergencyCloseAll(EMERGENCY_MANUAL);
      }
   }
}
```

#### Benefits
- ✅ Last line of defense against total wipeout
- ✅ Manual control for user intervention
- ✅ Automatic triggers for catastrophic scenarios
- ✅ Clean shutdown with logging for post-mortem

---

## 4. Implementation Priority

### Phase 1: Critical Safeguards (Immediate) 🔴

**Target:** Prevent account wipeout
**Timeline:** Version 21.0

1. **Hard Stop Loss (ATR-Based)** - Priority 1
   - Implement: 2-3 hours
   - Test: 1 day
   - Impact: HIGH - Prevents catastrophic single trade loss

2. **Maximum Lot Size Cap** - Priority 1
   - Implement: 1 hour
   - Test: 1 day
   - Impact: MEDIUM - Limits exposure growth

3. **Emergency Close Function** - Priority 1
   - Implement: 2 hours
   - Test: 1 hour
   - Impact: CRITICAL - Last resort protection

### Phase 2: Operational Safeguards (High Priority) 🟡

**Target:** Improve daily risk management
**Timeline:** Version 21.1

4. **Maximum Drawdown Circuit Breaker** - Priority 2
   - Implement: 2 hours
   - Test: 2 days
   - Impact: HIGH - Prevents cascading losses

5. **Consecutive Loss Limiter** - Priority 2
   - Implement: 1-2 hours
   - Test: 2 days
   - Impact: MEDIUM - Detects systematic problems

### Phase 3: Optimization (Nice to Have) 🟢

**Target:** Enhance profitability
**Timeline:** Version 21.2

6. **Volatility-Adjusted Position Sizing** - Priority 3
   - Implement: 3-4 hours
   - Test: 1 week
   - Impact: MEDIUM - Improves risk-adjusted returns

---

## 5. Parameter Specifications

### 5.1 Recommended Default Values

```ini
[Phase 1 - Critical]
EnableHardStop=true
ATRMultiplier=2.5
MinStopLossPips=15
MaxStopLossPips=50
MaxRiskPercent=0.15

MaxLotSize=0.20
MaxLotsPerBalance=0.10
EnableDynamicCap=true

EnableEmergencyClose=true
EmergencyDrawdownPercent=0.35

[Phase 2 - Operational]
EnableDrawdownStop=true
MaxDrawdownPercent=0.25
DrawdownRecoveryHours=24
CloseOnDrawdown=true

MaxConsecutiveLosses=3
ConsecutiveLossPauseHours=6
MinLossToCount=0.01

[Phase 3 - Optimization]
EnableVolatilityAdjustment=true
VolatilityLookback=20
VolatilityThresholdHigh=1.5
VolatilityThresholdLow=0.7
HighVolatilityMultiplier=0.5
LowVolatilityMultiplier=1.2

[Existing Parameters - Keep Current Values]
MarginUsage=0.50          # KEEP at 0.50 for growth
DailyGrowth=0.06          # KEEP current
MaxTrades=8               # KEEP current
SafeGrowth=true           # KEEP current
RelativeStop=0.30         # KEEP current
```

### 5.2 Parameter Interaction Matrix

| Parameter | Affects | Synergy | Conflict |
|-----------|---------|---------|----------|
| **ATRMultiplier** | Stop distance | ✅ With volatility adjustment | ⚠️ May conflict with RelativeStop |
| **MaxLotSize** | Position size | ✅ With all risk limits | ⚠️ May limit growth with high MarginUsage |
| **MaxDrawdownPercent** | Circuit breaker | ✅ With consecutive loss limiter | ⚠️ May trigger too early if set too low |
| **MaxRiskPercent** | Position sizing | ✅ With hard stop loss | ⚠️ Conflicts with MarginUsage logic |
| **MarginUsage** | Growth rate | ✅ Capped by MaxLotSize | ⚠️ Can bypass risk limits if not capped |

### 5.3 Conservative vs Aggressive Profiles

#### Conservative Profile (Capital Preservation)
```ini
ATRMultiplier=2.0
MaxRiskPercent=0.10
MaxLotSize=0.15
MaxDrawdownPercent=0.20
MaxConsecutiveLosses=2
MarginUsage=0.30
```
- **Expected:** Lower drawdown, slower growth
- **Use Case:** Small accounts, risk-averse traders

#### Balanced Profile (Recommended)
```ini
ATRMultiplier=2.5
MaxRiskPercent=0.15
MaxLotSize=0.20
MaxDrawdownPercent=0.25
MaxConsecutiveLosses=3
MarginUsage=0.50
```
- **Expected:** Moderate drawdown, steady growth
- **Use Case:** Standard trading, tested parameters

#### Aggressive Profile (Maximum Growth)
```ini
ATRMultiplier=3.0
MaxRiskPercent=0.20
MaxLotSize=0.30
MaxDrawdownPercent=0.30
MaxConsecutiveLosses=4
MarginUsage=0.50
```
- **Expected:** Higher drawdown, faster growth
- **Use Case:** Larger accounts, experienced traders

---

## 6. Testing Strategy

### 6.1 Backtest Requirements

#### Test 1: Black Swan Survivability
- **Dataset:** January 2025 (known wipeout event)
- **Expected:** Account survives with <25% drawdown
- **Pass Criteria:** Final balance > $1,500 (75% of initial)

#### Test 2: Long-Term Stability
- **Dataset:** Full year 2025
- **Expected:** Positive returns with controlled drawdown
- **Pass Criteria:**
  - Final balance > $2,500 (25% annual return)
  - Max drawdown < 30%
  - Recovery factor > 2.0

#### Test 3: High Volatility Period
- **Dataset:** Known volatile periods (news events)
- **Expected:** Reduced position sizing, no major losses
- **Pass Criteria:** No single trade loss > 15%

#### Test 4: Parameter Sensitivity
- **Method:** Monte Carlo simulation (1,000 runs)
- **Variables:** ATRMultiplier (2.0-3.5), MaxRiskPercent (0.10-0.20)
- **Expected:** Consistent performance across ranges
- **Pass Criteria:** 80% of runs profitable, max DD < 35%

### 6.2 Forward Testing Plan

#### Week 1: Demo Account (Phase 1)
- Deploy hard stop loss + max lot size
- Monitor: Stop loss triggers, position sizes
- Alert on: Any position approaching MaxLotSize

#### Week 2: Demo Account (Phase 1+2)
- Add circuit breakers
- Monitor: Drawdown levels, pause triggers
- Alert on: Any circuit breaker activation

#### Week 3: Demo Account (Full Implementation)
- Add volatility adjustment
- Monitor: Position size adjustments, volatility regime changes
- Compare: Performance vs Phase 1 only

#### Week 4: Live Account (Micro Lot)
- Deploy to live with 0.01 lot minimum
- Monitor: All safety mechanisms
- Alert on: Any unexpected behavior

### 6.3 Success Metrics

| Metric | Current (20.x) | Target (21.x) | Measurement |
|--------|----------------|---------------|-------------|
| **Max Single Trade Loss** | -85% | **<15%** | Per trade P&L |
| **Account Wipeout Rate** | 100% | **<5%** | 1000 backtest runs |
| **Recovery Time** | N/A (wipeout) | **<7 days** | Days to new equity high |
| **Max Drawdown** | >100% | **<30%** | Peak to trough |
| **Win Rate** | 50% | **>45%** | Wins / total trades |
| **Profit Factor** | N/A | **>1.5** | Gross profit / gross loss |

---

## 7. Rollback Plan

### 7.1 Trigger Conditions

Roll back to 20.x if ANY of the following occur:

1. **Performance Degradation**
   - Profit factor drops below 1.2 for 30 days
   - Win rate drops below 40%
   - Account growth <2% monthly for 3 consecutive months

2. **System Instability**
   - Circuit breakers trigger >10 times per month
   - Emergency close triggered incorrectly
   - Position sizing errors (0 lots or excessive lots)

3. **User Feedback**
   - Multiple reports of missed opportunities due to pauses
   - Backtests show worse performance than 20.x
   - Optimization reports show parameter conflicts

### 7.2 Rollback Procedure

```bash
# Step 1: Disable new safety features
EnableHardStop=false
EnableDrawdownStop=false
EnableEmergencyClose=false
EnableVolatilityAdjustment=false

# Step 2: Restore 20.x parameters
MaxLotSize=999.0  # Effectively unlimited
MarginUsage=0.50  # Original value

# Step 3: Close all positions cleanly
# Manual intervention required

# Step 4: Restart EA with 20.x binary
# Recompile from milestone-20.5.mq5
```

### 7.3 Post-Rollback Analysis

1. Export all logs from 21.x period
2. Analyze which safety mechanism caused issues
3. Adjust parameters or remove problematic feature
4. Re-test in demo before re-deployment

---

## 8. Implementation Checklist

### Phase 1 (Version 21.0) - Week 1

- [ ] **Code Implementation**
  - [ ] Add ATR-based hard stop loss function
  - [ ] Modify position sizing to calculate based on stop distance
  - [ ] Add MaxLotSize cap to lot calculation
  - [ ] Implement emergency close function
  - [ ] Add keyboard shortcut handler (Ctrl+E)

- [ ] **Testing**
  - [ ] Backtest on January 2025 data
  - [ ] Verify stop losses execute correctly
  - [ ] Test MaxLotSize cap with growing balance
  - [ ] Test emergency close triggers

- [ ] **Documentation**
  - [ ] Update user manual with new parameters
  - [ ] Document emergency procedures
  - [ ] Create parameter guide for different account sizes

### Phase 2 (Version 21.1) - Week 2-3

- [ ] **Code Implementation**
  - [ ] Add drawdown tracking and circuit breaker
  - [ ] Implement consecutive loss counter
  - [ ] Add pause/resume logic
  - [ ] Create alert system for all triggers

- [ ] **Testing**
  - [ ] Backtest on multiple volatile periods
  - [ ] Test circuit breaker pause and resume
  - [ ] Verify consecutive loss detection
  - [ ] Test interaction with Phase 1 features

- [ ] **Documentation**
  - [ ] Document circuit breaker behavior
  - [ ] Create troubleshooting guide
  - [ ] Update optimization guide

### Phase 3 (Version 21.2) - Week 4+

- [ ] **Code Implementation**
  - [ ] Add volatility regime detection
  - [ ] Implement dynamic position sizing
  - [ ] Add volatility alerts and logging

- [ ] **Testing**
  - [ ] Backtest on full year of data
  - [ ] Compare performance across volatility regimes
  - [ ] Optimize volatility thresholds

- [ ] **Documentation**
  - [ ] Document volatility adjustment logic
  - [ ] Create optimization report comparing 20.x vs 21.x
  - [ ] Publish performance metrics

### Final Validation

- [ ] **Full System Test**
  - [ ] Run 1,000 Monte Carlo backtests
  - [ ] Test all safety mechanisms together
  - [ ] Verify no conflicts between features
  - [ ] Load test with 8 simultaneous positions

- [ ] **Demo Account Testing**
  - [ ] Deploy to demo for 1 week minimum
  - [ ] Monitor all triggers and alerts
  - [ ] Verify correct position sizing
  - [ ] Test manual emergency close

- [ ] **Production Readiness**
  - [ ] Code review by second developer
  - [ ] User acceptance testing
  - [ ] Create rollback plan documentation
  - [ ] Final approval before live deployment

---

## 9. Open Questions for Review

1. **Hard Stop Loss Placement**
   - Should stop loss be fixed at entry or trailing?
   - How to handle gap risk (weekend gaps)?
   - Should we use guaranteed stops (if available)?

2. **Circuit Breaker Recovery**
   - 24-hour pause too long/short?
   - Should recovery require manual intervention?
   - What conditions allow auto-resume?

3. **Interaction with Existing Logic**
   - Does hard stop loss replace RelativeStop or complement it?
   - Should DailyGrowth pause during circuit breaker?
   - How does emergency close interact with SafeGrowth?

4. **Parameter Optimization**
   - Should we re-run optimization with new safety features?
   - Which parameters are most critical to optimize?
   - How to balance growth vs safety in optimization criteria?

5. **User Experience**
   - Too many alerts?
   - Need dashboard or visual indicators?
   - Mobile notifications for circuit breakers?

---

## 10. Conclusion

This specification provides a comprehensive framework for enhancing the Milestone strategy's risk management while preserving its profit potential. The multi-layered approach ensures that no single failure can cause total account loss.

**Key Takeaways:**
- ✅ MarginUsage stays at 0.50 for growth
- ✅ Multiple safety mechanisms prevent catastrophic loss
- ✅ Phased implementation reduces deployment risk
- ✅ Clear testing and rollback procedures
- ✅ Market-adaptive sizing improves risk-adjusted returns

**Next Steps:**
1. Review and approve this specification
2. Begin Phase 1 implementation
3. Backtest on January 2025 wipeout event
4. Iterate based on results

---

**Document Status:** ✏️ Draft - Awaiting Review
**Approval Required:** Yes
**Estimated Implementation:** 2-3 weeks (all phases)

