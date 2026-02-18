# Trend Following Systems

## Overview

Trend following systems are complete trading frameworks designed to capture sustained directional moves. Rather than isolated entry signals, these are full strategies with defined entry rules, exit management, risk controls, and position sizing - everything needed for consistent execution. Trend following is the most profitable approach long-term, generating the largest winners that offset inevitable losers.

**Why this matters**: While individual indicators identify signals, complete systems integrate multiple components into cohesive strategies. Trend following systems have made fortunes for legendary traders (Turtles, CTAs, hedge funds) because trends persist and large moves pay for everything. A properly built trend system needs only 35-45% win rate to be highly profitable.

**When to use it**: Use trend following systems when markets show directional bias (ADX > 25), after consolidation breakouts, and on H4-D1 timeframes where trends are sustainable. Best during trending market phases (30-40% of the time), not in ranges.

## Complete Trend Following Framework

**Essential Components:**
1. **Trend Identification**: Determine if trend exists and direction
2. **Entry Rules**: Precise conditions for opening positions
3. **Position Sizing**: Risk management per trade
4. **Stop Loss**: Initial and trailing stop strategy
5. **Profit Targets**: Exit strategy and profit taking
6. **Trade Management**: Adjustment rules during trade
7. **Market Filters**: When NOT to trade

## System #1: Classic MA Crossover System

**Overview:** 20/50 EMA crossover with ADX filter and ATR-based stops.

**Components:**

**1. Trend Filter:**
- ADX(14) > 25 (strong trend present)
- Skip trades when ADX < 25

**2. Entry Rules (Long):**
- 20 EMA crosses above 50 EMA
- Price closes above both EMAs
- ADX > 25
- Enter on next candle open

**3. Entry Rules (Short):**
- 20 EMA crosses below 50 EMA
- Price closes below both EMAs
- ADX > 25
- Enter on next candle open

**4. Stop Loss:**
- Long: Entry - (2 × ATR)
- Short: Entry + (2 × ATR)

**5. Profit Targets:**
- Target 1: 2× initial risk (close 50%)
- Target 2: 4× initial risk (close remaining 50%)
- Or trail with 50 EMA

**6. Position Sizing:**
- Risk 1% per trade
- Size based on ATR stop distance

**7. Exit Rules:**
- Stop loss hit
- Trailing 50 EMA crossed
- 20 EMA crosses back through 50 EMA (signal reversal)

**Example - EUR/USD H4:**
- 20 EMA crosses above 50 EMA at 1.1000
- ADX = 28 (qualified)
- ATR = 45 pips
- Entry: 1.1005 (long)
- Stop: 1.0915 (90 pips = 2 × ATR)
- Target 1: 1.1185 (180 pips, close 50%)
- Trail remaining with 50 EMA
- Final exit: 1.1250 when 20 crosses below 50
- **Result:** 50% at +180 pips, 50% at +245 pips = average +212 pips

**Expectancy:** 40-45% win rate, 1:3+ average R:R

## System #2: Pullback to MA System

**Overview:** Enter on pullbacks to moving average in established trend.

**Components:**

**1. Trend Identification:**
- Price above 50 EMA and 200 EMA (uptrend)
- Price below 50 EMA and 200 EMA (downtrend)
- ADX > 25

**2. Entry Rules (Long):**
- Established uptrend (price > 50 & 200 EMA)
- Price pulls back to 20 or 50 EMA
- Bullish reversal candle at EMA (engulfing, pin bar)
- Enter above reversal candle high
- ADX still > 20

**3. Stop Loss:**
- Below reversal candle low + 10-pip buffer
- Or below 50 EMA, whichever is closer

**4. Targets:**
- Previous swing high (resistance)
- Or 2-3× risk distance

**5. Position Sizing:**
- Risk 1-1.5% per trade

**6. Trade Management:**
- Move stop to breakeven at +1R
- Trail with 20 EMA after +2R profit
- Exit if price closes below 50 EMA

**Example - GBP/USD H1:**
- Strong uptrend, price at 1.2750
- Pulls back to 50 EMA at 1.2680
- Bullish pin bar forms
- Entry: 1.2690 (above pin bar)
- Stop: 1.2655 (below pin bar, 35 pips)
- Target: 1.2760 (previous high, 70 pips, 2:1)
- **Result:** Target hit, +70 pips

**Expectancy:** 50-55% win rate, 1:2 to 1:3 R:R

## System #3: ADX Momentum Breakout System

**Overview:** Trade breakouts with strong ADX confirmation.

**Components:**

**1. Setup Identification:**
- Range/consolidation for minimum 20-30 candles
- Clear support and resistance
- ADX declining or below 20 (weak trend)

**2. Entry Rules (Long):**
- Price breaks above resistance
- ADX rising (momentum building)
- +DI crosses above -DI
- Enter on retest of broken resistance as support
- Or enter on breakout with 5-10 pip buffer

**3. Stop Loss:**
- Below broken resistance (now support)
- Or 2× ATR from entry

**4. Targets:**
- Measured move: Range height added to breakout point
- Example: 100-pip range, breakout at 1.1100 → Target 1.1200

**5. Position Sizing:**
- Risk 1% on initial breakout
- Add 0.5% position on successful retest

**6. Exit Management:**
- Take 33% profit at 1:2
- Trail 50% with ATR trailing stop
- Hold 17% for extended run with wide trail

**Example - EUR/USD D1:**
- Range: 1.0950-1.1050 (100 pips) for 25 days
- Breakout above 1.1050
- ADX rises from 18 to 26
- Entry: 1.1055 (breakout) or 1.1052 (retest)
- Stop: 1.1010 (below range, 42-45 pips)
- Target: 1.1150 (measured move, 95-100 pips, 2:1+)
- **Result:** Hits 1.1165, ATR trail exits at 1.1140 (+85-88 pips average)

**Expectancy:** 40-45% win rate, 1:3 to 1:5 R:R

## System #4: Multi-Timeframe Trend System

**Overview:** Higher TF confirms trend, lower TF provides entry.

**Components:**

**1. Higher Timeframe Analysis (D1):**
- Identify trend: Price above/below 50 & 200 SMA
- ADX > 25 on D1
- Clear HH/HL pattern (uptrend) or LH/LL (downtrend)
- **Trade direction**: Only trade in direction of D1 trend

**2. Entry Timeframe (H4):**
- Wait for pullback on H4 to 20 or 50 EMA
- Confirm D1 trend still intact
- Entry signal: Price rebounds from H4 EMA

**3. Execution Timeframe (H1):**
- Zoom to H1 for precise entry
- Enter on H1 bullish candle at H4 MA level
- Stop below H1 swing low

**4. Stop Loss:**
- H1 swing low + buffer (tighter entry)
- Typical: 30-50 pips on majors

**5. Targets:**
- H4 previous swing high/low
- D1 next major level
- Often 100-300 pips

**6. Management:**
- Breakeven at +50 pips (H1 timeframe basis)
- Trail with H4 20 EMA after +100 pips
- D1 trend reversal = immediate exit

**Example - USD/JPY:**
- D1: Clear uptrend, price > 50/200 SMA, ADX = 32
- H4: Pullback to 50 EMA at 145.20
- H1: Bullish engulfing at 145.25
- Entry: 145.30 (H1 signal)
- Stop: 145.00 (H1 swing low, 30 pips)
- Target: 146.50 (H4 resistance, 120 pips, 4:1)
- **Result:** +115 pips when H4 EMA crossed

**Expectancy:** 50-55% win rate, 1:3 to 1:4 R:R

## Position Sizing & Risk Management

**Standard Rules Across All Systems:**

1. **Maximum Risk Per Trade:** 1-2% of account
2. **Maximum Portfolio Heat:** 5% (max 5 positions × 1% each)
3. **Correlated Pairs Rule:** Maximum 2 correlated positions (EUR/USD + GBP/USD)
4. **Daily Loss Limit:** 3% of account (stop trading for day)
5. **Consecutive Loss Limit:** After 5 losses, reduce size to 0.5%

**Position Sizing Formula:**
```
Risk Amount = Account × Risk %
Position Size = Risk Amount / (Stop Distance in Pips × Pip Value)
```

## Backtesting Requirements

**Minimum Standards:**
- **Data**: 2+ years, tick quality 99%+
- **Trades**: 100+ trades minimum for statistical significance
- **Conditions**: Test through trending AND ranging periods
- **Validation**: Out-of-sample testing on 30% of data

**Target Metrics:**
- **Win Rate**: 35-55% acceptable
- **Profit Factor**: > 1.5 minimum, > 2.0 excellent
- **Max Drawdown**: < 25%
- **Expectancy**: > 0.5R per trade
- **R-Multiple**: Average win > 2.5× average loss

## Common Mistakes & Solutions

**Mistake 1: Trading Against Trend**
- Solution: Always align with higher timeframe trend

**Mistake 2: No ADX Filter**
- Solution: Skip trades when ADX < 20 (no trend)

**Mistake 3: Fixed Targets in Trends**
- Solution: Use trailing stops to capture extended moves

**Mistake 4: Overtrading in Ranges**
- Solution: Require minimum 20-30 candles of trend structure

**Mistake 5: Holding Through Reversals**
- Solution: Exit when MA crosses signal reversal

## Best Timeframes & Pairs

**Optimal Timeframes:**
- **H4**: Best balance (clear trends, manageable holding)
- **D1**: Highest reliability (smoothest trends)
- **H1**: Active trading (more opportunities)

**Best Pairs for Trend Following:**
- **EUR/USD**: Clean trends, high liquidity
- **USD/JPY**: Sustained directional moves
- **GBP/USD**: Strong trends (higher volatility)
- **XAU/USD**: Powerful trends once established

## Current Best Practices (2025-2026)

1. **ADX Filter Mandatory**: Professional systems require ADX > 25 confirmation
2. **Multi-Timeframe Standard**: Top-down analysis (D1→H4→H1) is industry norm
3. **ATR-Based Everything**: Stops, targets, position sizing all use ATR
4. **Partial Exits Preferred**: 50% at 2R, trail remainder is most common approach
5. **Expectancy Over Win Rate**: Focus on R-multiples, not winning percentage

## Related Topics

- [Trend Following Entries](../01-Entry-Signals/01-trend-following-entries.md)
- [Trailing Stops](../02-Exit-Signals/02-trailing-stops.md)
- [Moving Averages](../06-Technical-Indicators/01-moving-averages.md)
- [Trend Indicators](../06-Technical-Indicators/06-trend-indicators.md)
- [Risk-Reward Optimization](../03-Risk-Management/05-risk-reward-optimization.md)

## References

- "Trend Following" by Michael Covel - Complete guide to trend strategies
- "The Complete TurtleTrader" - Classic trend system
- BabyPips - "Trend Following Strategy" lessons
- TradingView - Trend following strategy scripts
- MQL5 Community - Trend following EA examples

---

**Last Updated**: February 2026
**Complexity Level**: Intermediate to Advanced
**Time to Master**: 4-8 weeks
**Critical Importance**: ⭐⭐⭐⭐⭐ (Most profitable long-term approach)
