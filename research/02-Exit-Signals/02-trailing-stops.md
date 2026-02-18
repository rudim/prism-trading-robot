# Trailing Stops

## Overview

Trailing stops are dynamic exit mechanisms that follow profitable trades, locking in gains while allowing winners to run. Unlike fixed stops that remain static, trailing stops move in the trader's favor as price moves favorably, protecting accumulated profits. They solve the classic dilemma: "How do I capture large moves without giving back profits?" Trailing stops are essential for trend-following strategies where the best trades can run 100-500+ pips.

**Why this matters**: The difference between good and great traders is often exit quality. Fixed targets cap profits at predetermined levels. Trailing stops capture the full extent of strong trends. A 100-pip winner becomes a 300-pip winner when properly trailed. Over time, these extended wins dramatically increase account growth and expectancy.

**When to use it**: Use trailing stops in trending markets, swing trading, and position trading where moves can extend far beyond initial targets. Most effective when ADX > 25 (strong trend), during momentum surges, and on higher timeframes (H4, D1) where trends are more sustainable. Avoid in choppy, ranging markets where price oscillations trigger premature exits.

## What Are Trailing Stops?

A trailing stop is a stop loss that automatically moves (trails) behind price as a trade becomes profitable, but never moves against you (never widens). Key characteristics:

**How It Works:**
- **Long Trade**: Stop moves up as price rises, stays put when price falls
- **Short Trade**: Stop moves down as price falls, stays put when price rises
- **Never Reverses**: Stop only moves in profitable direction, never backward
- **Distance Maintained**: Keeps fixed distance (pips, %, ATR) from current price or peak

**Example:**
- Long EUR/USD at 1.1000
- Initial stop: 1.0950 (50 pips below)
- Price rises to 1.1050
- Trailing stop (50 pips): Moves to 1.1000 (breakeven)
- Price rises to 1.1100
- Trailing stop: Moves to 1.1050 (+50 pips locked in)
- Price rises to 1.1150, then reverses to 1.1050
- **Stopped out at 1.1050 for +50 pip profit**

Without trailing stop, might have exited at fixed target of 1.1100 (+100 pips) and missed the extra 50 pips, OR held for larger target (1.1200) and given back all gains when stopped at 1.1000.

## Key Trailing Stop Methods

### 1. Fixed Pip Trailing Stop

Simplest method: Stop trails at fixed pip distance from current price or highest high since entry.

**MT5 Built-In Trailing Stop:**
- Right-click position → "Trailing Stop"
- Select distance: 15, 20, 30, 40, 50 pips, or custom
- Stop automatically trails at that distance
- **Limitation**: Only works while MT5 is running (not server-side)

**Settings by Timeframe:**
| Timeframe | Trailing Distance | Usage |
|-----------|-------------------|-------|
| **M15** | 15-25 pips | Scalping |
| **H1** | 30-50 pips | Day trading |
| **H4** | 50-80 pips | Swing trading |
| **D1** | 80-150 pips | Position trading |

**Example - GBP/USD H1 Day Trade:**
- **Entry**: Long at 1.2650
- **Initial Stop**: 1.2610 (40 pips)
- **Trailing Distance**: 40 pips (same as initial)
- **Price Movement**:
  - Reaches 1.2700: Stop moves to 1.2660 (+10 pips profit locked)
  - Reaches 1.2750: Stop moves to 1.2710 (+60 pips locked)
  - Reaches 1.2780: Stop moves to 1.2740 (+90 pips locked)
  - Reverses to 1.2740: **Stopped out at 1.2740 (+90 pips)**

**Advantages:**
- Simple to implement
- Consistent across all trades
- Built into MT5 platform
- No calculation required

**Disadvantages:**
- Fixed distance doesn't adapt to volatility
- Tight trails get stopped out on minor pullbacks
- Wide trails give back too much profit
- Requires MT5 to be running continuously

### 2. ATR Trailing Stop

Uses Average True Range (ATR) to adapt trailing distance to current market volatility.

**Formula:**
```
Long Trade: Trailing Stop = Highest High since entry - (ATR × Multiplier)
Short Trade: Trailing Stop = Lowest Low since entry + (ATR × Multiplier)
```

**ATR Multipliers by Style:**
- **Aggressive**: 1.5x - 2x ATR (tighter, more sensitive)
- **Moderate**: 2x - 2.5x ATR (balanced)
- **Conservative**: 3x - 4x ATR (wider, trend-holding)

**Example - EUR/USD H4:**
- **Entry**: Long at 1.1000
- **ATR(14, H4)**: 50 pips
- **Multiplier**: 2.5x (swing trading)
- **Initial Stop**: 1.0875 (125 pips = 50 × 2.5)

**Price Progress:**
- **Day 1**: High 1.1080, ATR trailing stop = 1.1080 - 125 = 1.0955 (moves up 80 pips)
- **Day 2**: High 1.1150, stop = 1.1150 - 125 = 1.1025 (now +25 pips profit locked)
- **Day 3**: High 1.1240, stop = 1.1240 - 125 = 1.1115 (+115 pips locked)
- **Day 4**: Price reverses to 1.1115, **stopped out at 1.1115 (+115 pips)**

**MT5 Implementation:**
Requires custom indicator or EA. Search MQL5 market for "ATR Trailing Stop" indicators.

**Code Concept:**
```cpp
// Calculate ATR-based trailing stop
double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
double multiplier = 2.5;
double highestHigh = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 20, 0));
double trailingStop = highestHigh - (atr * multiplier);
```

**Advantages:**
- Adapts to volatility automatically
- Wider stops in volatile periods (prevents stop-outs)
- Tighter stops in calm periods (protects more profit)
- Objective and systematic

**Disadvantages:**
- More complex than fixed pips
- Requires custom indicator or EA
- ATR is lagging (based on past data)
- Can be too wide in trending moves (gives back significant profits)

### 3. Chandelier Exit Trailing Stop

Advanced ATR-based method that uses highest high or lowest low as anchor point.

**Formula:**
```
Long: Stop = Highest High(22) - (ATR(22) × 3)
Short: Stop = Lowest Low(22) + (ATR(22) × 3)
```

**Standard Parameters:**
- **Lookback Period**: 22 periods (roughly one month of trading days)
- **ATR Period**: 22 (matches lookback)
- **ATR Multiplier**: 3.0 (standard), can tighten to 2.5 once deep in profit

**Example - USD/JPY D1 Position Trade:**
- **Entry**: Long at 145.00
- **ATR(22, D1)**: 1.20 (120 pips)
- **Multiplier**: 3.0
- **Initial Highest High**: 145.50 (since entry)
- **Chandelier Stop**: 145.50 - (1.20 × 3) = 145.50 - 3.60 = 141.90

**Price Progress:**
- **Week 1**: New high 147.00, ATR = 1.25
  - Stop = 147.00 - (1.25 × 3) = 143.25 (moves up 135 pips)
- **Week 2**: New high 149.50, ATR = 1.30
  - Stop = 149.50 - (1.30 × 3) = 145.60 (+60 pips profit locked)
- **Week 3**: New high 151.00, ATR = 1.35
  - Stop = 151.00 - (1.35 × 3) = 146.95 (+195 pips locked)
- **Week 4**: Price reverses, stopped at 146.95 (+195 pips final)

**Why Chandelier Works:**
- Trails from highest high (not just current price)
- 3× ATR gives plenty of room for normal pullbacks
- Tightens automatically as trend progresses (ATR often decreases in mature trends)
- Used by professional trend followers

**MT5 Implementation:**
Search MQL5 market for "Chandelier Exit" indicator. Not built-in, requires custom indicator.

**Best Timeframes:** D1, W1 for position trading; H4 for swing trading

### 4. Moving Average Trailing Stop

Uses moving average as dynamic support/resistance for trailing stop placement.

**Common MA Trailing Stops:**
- **20 EMA**: Aggressive, quick exits
- **50 EMA**: Moderate, balances holding vs. exiting
- **200 EMA**: Very conservative, long-term trends only

**Entry Rules:**
1. Enter trade in trend direction
2. Place initial stop below/above moving average
3. As trade progresses, trail stop below/above MA
4. Exit when price closes on wrong side of MA
5. Can add buffer (5-10 pips beyond MA)

**Example - XAU/USD H4 with 50 EMA:**
- **Entry**: Long gold at $1,950 (uptrend, above 50 EMA)
- **50 EMA**: $1,930
- **Initial Stop**: $1,925 (5 below 50 EMA)

**Price Progress:**
- **Day 2**: Price $1,985, 50 EMA at $1,945
  - Stop = $1,940 (5 below EMA)
- **Day 5**: Price $2,020, 50 EMA at $1,970
  - Stop = $1,965 (+15 profit locked)
- **Day 8**: Price $2,050, 50 EMA at $2,000
  - Stop = $1,995 (+45 locked)
- **Day 10**: Price closes at $1,990, below 50 EMA at $2,005
  - **Exit at $1,995 (stop hit) for +$45 profit**

**Advantages:**
- Follows trend structure
- MA acts as natural support/resistance
- Gives trade room to breathe during pullbacks
- Popular with swing traders

**Disadvantages:**
- Can give back substantial profit (50 EMA lags significantly)
- Whipsaws possible if price oscillates around MA
- Requires manual monitoring and stop adjustment
- Less precise than ATR methods

### 5. Parabolic SAR Trailing Stop

Parabolic SAR (Stop and Reverse) is specifically designed as a trailing stop indicator.

**How It Works:**
- Dots appear above price (downtrend) or below price (uptrend)
- Dots continuously move closer to price (accelerating)
- When price crosses SAR, position reverses (or exits)
- Built into MT5

**Settings:**
- **Step**: 0.02 (standard, how fast SAR accelerates)
- **Maximum**: 0.2 (maximum acceleration limit)

**Example - EUR/USD H1:**
- **Entry**: Long at 1.1000
- **SAR Dot**: Below price at 1.0980
- **Price rises to 1.1050**: SAR moves to 1.1005
- **Price rises to 1.1100**: SAR moves to 1.1040
- **Price rises to 1.1150**: SAR moves to 1.1085
- **Price reverses to 1.1085**: **SAR hit, exit at 1.1085 (+85 pips)**

**MT5 Implementation:**
```
Insert → Indicators → Trend → Parabolic SAR
Step: 0.02, Maximum: 0.2 (default settings work well)
Exit when price crosses SAR dots
```

**Advantages:**
- Built into MT5 (no custom code needed)
- Visual (dots on chart)
- Accelerates as trend progresses (tightens automatically)
- Good for strong trends

**Disadvantages:**
- Whipsaws in ranging markets
- Can exit too early in choppy trends
- Dots jump significantly when price crosses (slippage risk)
- Not adaptable (fixed acceleration formula)

### 6. Manual Trailing Based on Market Structure

Professional approach: Manually trail stop based on swing lows/highs and market structure.

**Process:**
1. Enter trade in trend direction
2. Identify most recent swing low (uptrend) or swing high (downtrend)
3. Place stop below swing low + buffer
4. As new swing lows form at higher levels, move stop up
5. Never move stop down (only up in long, only down in short)

**Example - GBP/USD H4 Uptrend:**
- **Entry**: Long at 1.2650
- **Initial Stop**: Below swing low at 1.2600 (50 pips)

**Structure Evolution:**
- **Swing 1**: Low at 1.2620 → Stop at 1.2610 (higher swing low, move stop up)
- **Swing 2**: Low at 1.2680 → Stop at 1.2670 (+20 pips profit now locked)
- **Swing 3**: Low at 1.2740 → Stop at 1.2730 (+80 pips locked)
- **Breakdown**: Price breaks below swing low at 1.2740
- **Exit**: Stopped at 1.2730 (+80 pips)

**Advantages:**
- Respects market structure
- Gives trades maximum room
- Captures full trend extent
- Professional approach

**Disadvantages:**
- Requires active monitoring
- Subjective (what defines a "swing low"?)
- Time-consuming
- Needs experience to execute well

## Specific Parameters & Settings

### Trailing Stop Decision Matrix

| Market Condition | Best Trailing Method | Typical Distance |
|------------------|----------------------|------------------|
| **Strong Trend (ADX > 30)** | Chandelier Exit or 50 EMA | Wide (3-4x ATR) |
| **Moderate Trend (ADX 25-30)** | ATR Trailing (2.5x) | Moderate |
| **Weak Trend (ADX 20-25)** | Parabolic SAR or Fixed Pip | Tighter |
| **Highly Volatile** | ATR (3x multiplier) | Very wide |
| **Low Volatility** | Fixed Pip or ATR (2x) | Tighter |
| **Swing Trading** | Manual Structure | Wide |
| **Day Trading** | ATR or Fixed Pip | Moderate |
| **Scalping** | Fixed Pip (tight) | Very tight |

### When to Activate Trailing Stop

**Option A: Immediate**
- Activate trailing stop from entry
- Pro: Guarantees trail starts immediately
- Con: Can get stopped out early on initial pullback

**Option B: After Breakeven**
- Wait until price reaches 1:1 R:R, then activate trail
- Pro: Guarantees no loss once trail activates
- Con: Miss opportunity to lock profits earlier

**Option C: After First Target**
- Close partial position at first target, activate trail on remainder
- Pro: Locked in some profit, trail the "free" position
- Con: More complex management

**Most Popular (Recommended): Option B**
- Activate trail when price reaches initial stop distance in profit (1:1)
- Example: 50-pip stop, activate 50-pip trail when +50 pips in profit
- Ensures trail can't create loss, only locks in profits

### Combining Trailing with Partial Exits

**Three-Stage Exit Strategy:**
1. **33% at Fixed Target**: Close one-third at 1:2 R:R (bank guaranteed profit)
2. **33% at Breakeven Trail**: Close when trail hits breakeven (some additional profit)
3. **33% on Wide Trail**: Let run with 3-4x ATR trail (capture extended moves)

**Example:**
- Position: 0.90 lots
- Close 0.30 lots at +60 pips (2:1 R:R) = guaranteed profit
- Close 0.30 lots when 2× ATR trail hits = additional profit
- Trail 0.30 lots with 4× ATR = potential large winner

This approach balances certainty (first exit), reasonable profit (second exit), and home-run potential (third exit).

## Practical Examples

### Example 1: ATR Trailing Stop Success - EUR/USD H4

**Setup:**
- **Entry**: Long at 1.1000 after pullback in uptrend
- **Initial Stop**: 1.0950 (50 pips, technical level)
- **ATR(14, H4)**: 45 pips
- **ATR Multiplier**: 2.5× (112 pips)
- **Position**: 0.20 lots ($10,000 account, 1% risk)

**Price Evolution:**
- **Day 1 Close**: 1.1040 (now +40 pips)
  - Activate ATR trail: Stop = 1.1040 - 112 = 1.0928 (still below entry)
- **Day 2 Close**: 1.1110 (+110 pips)
  - ATR trail: Stop = 1.1110 - 112 = 1.0998 (now breakeven -2 pips)
- **Day 3 Close**: 1.1185 (+185 pips)
  - ATR trail: Stop = 1.1185 - 112 = 1.1073 (+73 pips locked in)
- **Day 4 Close**: 1.1250 (+250 pips)
  - ATR trail: Stop = 1.1250 - 112 = 1.1138 (+138 pips locked)
- **Day 5**: Price reverses to 1.1135
  - **Stopped out at 1.1138 (+138 pips, $276 profit, 2.76% gain)**

**Why It Worked:**
- 112-pip trail (2.5x ATR) gave plenty of room for daily fluctuations
- Captured 55% of total move (250 pip high, exited at 138)
- Fixed target at 100 pips would have left 38 pips on table
- ATR adapted to H4 volatility perfectly

### Example 2: Chandelier Exit on Position Trade - USD/JPY Weekly

**Setup:**
- **Entry**: Long at 140.00 (major trend beginning)
- **Timeframe**: W1 (position trade)
- **ATR(22, W1)**: 2.50 (250 pips)
- **Chandelier Multiplier**: 3×
- **Position**: 0.10 lots ($50,000 account, 0.5% risk)

**Multi-Week Evolution:**
- **Week 4**: High 143.50, Chandelier = 143.50 - (2.50 × 3) = 135.50
  - Stop at 135.50 (still protecting against major reversal, -450 pips)
- **Week 8**: High 148.00, ATR = 2.30, Chandelier = 148.00 - 6.90 = 141.10
  - Stop at 141.10 (+110 pips profit now protected)
- **Week 12**: High 152.50, ATR = 2.10, Chandelier = 152.50 - 6.30 = 146.20
  - Stop at 146.20 (+620 pips locked in)
- **Week 16**: High 156.00, ATR = 2.00, Chandelier = 156.00 - 6.00 = 150.00
  - Stop at 150.00 (+1,000 pips locked)
- **Week 18**: Major reversal begins, stopped at 150.00
  - **Final Profit**: +1,000 pips = $10,000 (20% account gain)

**Key Success Factors:**
- Chandelier's wide trail (3× ATR = 600-750 pips) allowed trend to breathe
- Never exited on minor weekly pullbacks
- Captured 4-month trend from 140 to 156 (exited at 150)
- Position trade patience + proper trailing = massive winner

**What Would Have Happened:**
- **Fixed 200-pip target**: +200 pips, missed 800 pips
- **Fixed 500-pip target**: +500 pips, missed 500 pips
- **50 EMA trail**: Likely exited at ~145.00 (+500 pips), missed remaining 500

### Example 3: Failed Trailing (Too Tight) - GBP/USD H1

**Setup:**
- **Entry**: Long at 1.2650
- **Initial Stop**: 1.2610 (40 pips)
- **Mistake**: Activated 30-pip fixed trailing immediately
- **Price Movement**:
  - Rises to 1.2690 (+40 pips)
  - Trail moves to 1.2660 (+10 pips locked)
  - Price pulls back to 1.2665 (normal H1 volatility)
  - **Stopped out at 1.2660 for +10 pips**
  - Price then resumes to 1.2780 (+130 pips from entry)

**Lesson Learned:**
- 30-pip trail too tight for GBP/USD H1 volatility (ATR was 55 pips)
- Should have used ATR trail (2× = 110 pips) or waited for larger profit before activating
- Exited winner too early, missed 120 additional pips
- **Fix**: Use ATR-based trail or wait until +100 pips before activating 40-50 pip trail

## Pros & Cons

### Trailing Stops - Pros
- Captures extended trends (100-500+ pip winners)
- Locks in profits automatically
- Removes guesswork ("when should I exit?")
- Maximizes expectancy (large winners improve R-multiples)
- Adapts to price action (moves with market)
- Protects profits while staying in trend
- Essential for trend-following strategies

### Trailing Stops - Cons
- Can exit too early on pullbacks (whipsawed out)
- Gives back some profit before exit
- Requires monitoring (manual trails) or EA (automated)
- Doesn't work well in ranging markets
- More complex than fixed targets
- Can be frustrating (watching profits shrink before exit)
- MT5 built-in trail requires platform running

## Best Market Conditions

**Best Markets for Trailing:**
- **Strong Trends**: ADX > 30, clear HH/HL or LH/LL
- **High Volatility**: Large daily/weekly ranges
- **News-Driven Moves**: Major breakouts or policy shifts
- **Higher Timeframes**: H4, D1, W1 (sustainable trends)
- **Momentum**: After consolidation breakouts

**Worst Markets for Trailing:**
- **Ranging/Choppy**: Price oscillates, constant stop-outs
- **Low Volatility**: Asian session, summer months
- **News Events**: Whipsaw action around releases
- **Lower Timeframes**: M5, M15 (too much noise)

**Best Pairs for Trailing:**
- **EUR/USD**: Clean trends, respects trailing stops
- **USD/JPY**: Smooth trends, perfect for position trades
- **GBP/USD**: Volatile but trending (wider trails needed)
- **XAU/USD**: Strong trends once established

## Current Best Practices (2025-2026)

### Professional Standards

1. **ATR-Based Trailing Preferred**: The Average True Range (ATR) is now considered best practice for trailing stops as it's a volatility-based indicator that tightens during low volatility phases while expanding during high volatility phases, providing dynamic risk management.

2. **Chandelier Exit for Position Trades**: The ATR Chandelier Exit builds upon ATR Trailing Stop by factoring in price extremes (highest highs/lowest lows), providing more dynamic risk management in volatile markets. It's particularly effective in forex and cryptocurrency markets where volatility changes rapidly.

3. **3x ATR Standard with 2.5x Tightening**: Professional traders use 3× ATR multiplier for initial trailing, providing balanced movement. Once trades move deep into profit (2:1 R:R or more), tighten multiplier to 2.5× to protect more gains.

4. **Weekly/Daily Timeframe Optimization**: The Chandelier strategy works best as swing or position trading exit strategy on daily and weekly timeframes because trends persist longer and the trailing method is less prone to false signals on these preferred timeframes.

5. **Breakeven Activation Protocol**: Modern risk management mandates moving stop to breakeven when price reaches 1:1 R:R, THEN activating trailing mechanism. This guarantees zero-loss trades while allowing trails to capture extended moves.

### Common Mistakes (2025-2026)

1. **Trail Too Tight**: Using fixed 20-30 pip trails on pairs with 60-80 pip ATR. Trail must be wider than normal volatility or constant stop-outs occur.

2. **Trailing in Ranges**: Activating trails in ranging markets (ADX < 20). Trails work for trends only - switch to fixed targets when ranging.

3. **Not Using ATR**: Ignoring volatility when setting trail distance. ATR-based trails dramatically outperform fixed-pip trails across all market conditions.

4. **Immediate Activation**: Starting trail from entry instead of waiting for +1R or first target. Initial pullback often stops out profitable trades unnecessarily.

5. **Manual Trail Neglect**: Setting manual trailing stop but forgetting to adjust it. Use automated trails (EA) or indicator-based trails for consistency.

### Resources from Trading Communities

- **LuxAlgo (2025)**: ["5 ATR Stop-Loss Strategies for Risk Control"](https://www.luxalgo.com/blog/5-atr-stop-loss-strategies-for-risk-control/) - Comprehensive ATR trailing approaches
- **Chandelier Exit Trading Strategy**: [Traders Union Guide](https://tradersunion.com/interesting-articles/trading-strategies/chandelier-exit/) - Complete Chandelier implementation
- **NetPicks**: ["Chandelier Exit Indicator: How the Adaptive Trailing Stop Works"](https://www.netpicks.com/chandelier-exit/) - Adaptive trailing mechanics
- **Forex Training Group**: ["Protect Your Open Profits With Trailing Stop Loss Strategies"](https://forextraininggroup.com/protect-your-open-profits-with-trailing-stop-loss-strategies/) - Multiple trailing methods compared
- **Professional Trader**: "The difference between average traders and great traders is exits. Fixed targets cap your upside. Trailing stops let your winners run. That's where account growth comes from."

## Related Topics

- [Fixed Targets & Stops](01-fixed-targets-stops.md) - Alternative static exit strategy
- [Indicator-Based Exits](03-indicator-based-exits.md) - Technical indicator exits
- [Stop Loss Placement](../03-Risk-Management/02-stop-loss-placement.md) - Initial stop placement methods
- [Trend Following Systems](../05-Strategy-Types/05-trend-following-systems.md) - Complete trend strategies using trails
- [Volatility Indicators](../06-Technical-Indicators/04-volatility-indicators.md) - ATR and volatility measurement
- [Risk-Reward Optimization](../03-Risk-Management/05-risk-reward-optimization.md) - How trailing improves expectancy

## References

**Trailing Stop Strategy Research:**
- [5 ATR Stop-Loss Strategies for Risk Control](https://www.luxalgo.com/blog/5-atr-stop-loss-strategies-for-risk-control/) - LuxAlgo comprehensive guide
- [Chandelier Exit Trading Strategy](https://tradersunion.com/interesting-articles/trading-strategies/chandelier-exit/) - Complete Chandelier implementation
- [Chandelier Exit | ChartSchool](https://chartschool.stockcharts.com/table-of-contents/technical-indicators-and-overlays/technical-overlays/chandelier-exit) - StockCharts educational resource

**Implementation Guides:**
- [Chandelier Exit Indicator: How the Adaptive Trailing Stop Works](https://www.netpicks.com/chandelier-exit/) - NetPicks detailed guide
- [Protect Your Open Profits With Trailing Stop Loss Strategies](https://forextraininggroup.com/protect-your-open-profits-with-trailing-stop-loss-strategies/) - Forex Training Group
- [Chandelier Exit Strategy: A Trader's Guide](https://www.quantifiedstrategies.com/chandelier-exit-strategy/) - QuantifiedStrategies complete guide
- MQL5 Community - "ATR Trailing Stop" and "Chandelier Exit" indicator downloads

---

**Last Updated**: February 2026
**Complexity Level**: Intermediate
**Time to Master**: 2-4 weeks
**Critical Importance**: ⭐⭐⭐⭐⭐ (Essential for trend following - differentiates good from great traders)
