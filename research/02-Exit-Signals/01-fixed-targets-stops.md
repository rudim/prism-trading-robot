# Fixed Targets & Stops

## Overview

Fixed targets and stops are the simplest and most straightforward exit strategy. They involve setting predetermined profit targets and stop losses at specific price levels or pip distances before entering a trade. Once set, these levels remain unchanged regardless of how the trade progresses. This approach removes emotion from exits, enforces discipline, and ensures consistent risk-reward ratios.

**Why this matters**: More traders fail from poor exits than poor entries. Fixed targets and stops provide structure, prevent emotional decision-making ("should I hold or exit?"), and guarantee every trade has defined risk and reward. They're the foundation of mechanical trading systems and essential for backtesting and automation.

**When to use it**: Fixed targets work best for scalping, day trading, and strategies with clear technical levels (support/resistance, round numbers). Use when you want consistency, simplicity, and the ability to "set and forget" trades. Ideal for beginners developing discipline and for automated trading systems.

## What Are Fixed Targets & Stops?

Fixed targets and stops are predetermined exit points defined BEFORE entering a trade:

**Fixed Stop Loss:**
- Specific price level or pip distance where trade will be closed at a loss
- Protects capital by limiting maximum loss
- Never moves further away (can only move closer or stay same)

**Fixed Take Profit:**
- Specific price level or pip distance where trade will be closed at profit
- Locks in gains at predetermined target
- Based on technical levels, R:R ratio, or fixed pip amounts

**Key Principle**: Set once at entry, never adjusted (except moving stop to breakeven or closer). No emotional decisions during trade.

## Key Fixed Target & Stop Methods

### 1. Fixed Pip Targets & Stops

Simplest method: Use same pip distance for every trade regardless of market conditions.

**Common Fixed Pip Settings:**

**Scalping (M5-M15):**
- Stop: 10-20 pips
- Target: 10-30 pips
- R:R: 1:1 to 1:1.5

**Day Trading (H1):**
- Stop: 30-50 pips
- Target: 60-100 pips
- R:R: 1:2

**Swing Trading (H4):**
- Stop: 50-80 pips
- Target: 100-200 pips
- R:R: 1:2 to 1:3

**Example - EUR/USD Scalp:**
- **Entry**: 1.1050 (long)
- **Fixed Stop**: 15 pips = 1.1035
- **Fixed Target**: 20 pips = 1.1070
- **R:R**: 1:1.33
- **Result**: Price reaches 1.1070, exits at profit automatically

**Pros:**
- Extremely simple to implement
- Consistent across all trades
- Easy to backtest
- No decisions during trade
- Perfect for automated EAs

**Cons:**
- Ignores market structure (might stop above support)
- Ignores volatility (same stop in calm and volatile markets)
- Same distance for all pairs (EUR/USD and GBP/JPY have different volatility)

### 2. Technical Level Targets & Stops

Set exits at key technical levels: support, resistance, swing highs/lows, round numbers.

**Stop Loss Placement:**
- **Long**: Below recent swing low or support
- **Short**: Above recent swing high or resistance
- Add 5-20 pip buffer beyond level (depends on timeframe)

**Target Placement:**
- **Long**: At next resistance, previous swing high, or round number
- **Short**: At next support, previous swing low, or round number
- Can use multiple targets (scale out at multiple levels)

**Example - GBP/USD H1 Long:**
- **Entry**: 1.2650 (breakout above 1.2645 resistance)
- **Stop Loss**: 1.2610 (below recent swing low at 1.2620, minus 10 pip buffer) = 40 pips
- **Target 1**: 1.2720 (next resistance level) = 70 pips (1.75:1 R:R)
- **Target 2**: 1.2780 (major resistance) = 130 pips (3.25:1 R:R)
- **Execution**: Close 50% at Target 1, hold 50% for Target 2

**MT5 Implementation:**
1. Identify swing low (for longs) using indicator or visual inspection
2. Draw horizontal line at support level
3. Place stop 10-20 pips below line
4. Identify next resistance
5. Place take profit at resistance level

### 3. ATR-Based Fixed Stops & Targets

Use Average True Range (ATR) to set stops and targets that adapt to volatility.

**Formula:**
```
Stop Loss Distance = ATR(14) × Multiplier
Take Profit Distance = Stop Loss × R:R Ratio
```

**Standard ATR Multipliers:**
- **Scalping**: 1.5x to 2x ATR
- **Day Trading**: 2x to 2.5x ATR
- **Swing Trading**: 2.5x to 3x ATR

**Example - USD/JPY H1:**
- **Entry**: 145.50 (long)
- **ATR(14, H1)**: 52 pips
- **Multiplier**: 2.0 (day trading standard)
- **Stop Loss**: 145.50 - (52 × 2) = 145.50 - 104 = 144.46 (104 pips)
- **R:R Ratio**: 1:2
- **Take Profit**: 145.50 + (104 × 2) = 145.50 + 208 = 147.58 (208 pips)

**Advantages:**
- Adapts to current volatility
- Wider stops in volatile markets (prevents premature stop-outs)
- Tighter stops in calm markets (better capital efficiency)
- Objective and rules-based

**MT5 ATR Setup:**
```
Insert → Indicators → Trend → Average True Range
Period: 14 (standard)
Read ATR value, multiply by chosen multiplier
Calculate stop and target distances
```

### 4. Risk-Reward Ratio Targets

Set target based on desired R:R ratio and stop distance.

**Process:**
1. Determine stop loss based on technical level or ATR
2. Calculate stop distance in pips
3. Multiply stop distance by desired R:R ratio
4. Set target at that distance

**Example - EUR/USD H4:**
- **Entry**: 1.1050 (long)
- **Stop**: 1.1000 (below support) = 50 pip stop
- **Desired R:R**: 1:3
- **Target Calculation**: 50 pips × 3 = 150 pips
- **Take Profit**: 1.1050 + 0.0150 = 1.1200

**R:R Requirements by Strategy:**
- **Scalping**: 1:1 to 1:1.5 (high win rate compensates)
- **Day Trading**: 1:2 minimum
- **Swing Trading**: 1:2 to 1:3 minimum
- **Trend Following**: 1:3 to 1:5 (low win rate needs large winners)

**Breakeven Win Rate by R:R:**
| Risk-Reward | Breakeven Win Rate |
|-------------|-------------------|
| 1:1 | 50% |
| 1:1.5 | 40% |
| 1:2 | 33% |
| 1:3 | 25% |

### 5. Percentage-Based Stops & Targets

Set exits based on percentage of entry price or account equity.

**Entry Price Percentage:**
- **Stop**: Entry price ± X%
- **Target**: Entry price ± Y%

**Example - XAU/USD (Gold):**
- **Entry**: $1,950 (long)
- **Stop %**: 1.5% = $1,950 × 0.985 = $1,920.75 (approximately $1,921)
- **Target %**: 3.0% = $1,950 × 1.03 = $2,008.50 (approximately $2,009)
- **R:R**: 1:2

**Account Equity Percentage:**
- Risk X% of account per trade
- Target Y% of account per trade

**Example:**
- **Account**: $10,000
- **Risk**: 1% = $100
- **Target**: 2% = $200 (2:1 R:R)
- Calculate position size so stop distance = $100 risk
- Calculate target distance so profit = $200

## Specific Parameters & Settings

### Recommended Fixed Parameters by Trading Style

| Style | Stop (pips) | Target (pips) | R:R | Typical Timeframe |
|-------|-------------|---------------|-----|-------------------|
| **Scalping** | 10-20 | 15-30 | 1:1.5 | M5-M15 |
| **Day Trading** | 30-50 | 60-150 | 1:2-1:3 | H1 |
| **Swing Trading** | 50-100 | 100-300 | 1:2-1:4 | H4-D1 |
| **Position Trading** | 100-200 | 300-800 | 1:3-1:5 | D1-W1 |

### Fixed Stop Buffer Guidelines

Add buffer beyond obvious levels to avoid stop hunts:

| Timeframe | Buffer (pips) | Example |
|-----------|---------------|---------|
| **M5** | 2-5 | Support at 1.1000, stop at 1.0995 |
| **M15** | 5-8 | Support at 1.1000, stop at 1.0992 |
| **M30** | 8-12 | Support at 1.1000, stop at 1.0988 |
| **H1** | 10-15 | Support at 1.1000, stop at 1.0985 |
| **H4** | 15-25 | Support at 1.1000, stop at 1.0975 |
| **D1** | 25-50 | Support at 1.1000, stop at 1.0950 |

### Partial Exit Strategy (Scaling Out)

Instead of single target, use multiple targets to balance certainty and potential:

**Example - Two-Target System:**
- Close 50% at 1:2 R:R (high probability, bank profits)
- Hold 50% for 1:4 R:R (lower probability, larger reward)
- Move stop to breakeven when first target hit

**Example - Three-Target System:**
- Close 33% at 1:1.5 R:R (very high probability)
- Close 33% at 1:3 R:R (moderate probability)
- Hold 33% for 1:5+ R:R (low probability but huge reward)
- Move stop to +1R when first target hit

**Benefits:**
- Guarantees some profit even if price reverses
- Allows participation in larger moves
- Reduces psychological pressure
- Higher overall expectancy

## Practical Examples

### Example 1: Fixed Pip Scalp - EUR/USD M15

**Setup:**
- **Strategy**: London open breakout scalp
- **Entry**: 1.1050 (long on breakout above range)
- **Fixed Stop**: 15 pips = 1.1035
- **Fixed Target**: 25 pips = 1.1075
- **R:R**: 1:1.67
- **Position Size**: $10,000 account, 1% risk ($100), 0.67 lots

**Execution:**
- 08:05 AM: Enter long at 1.1050
- 08:07 AM: Price dips to 1.1043 (scare trade, but not stopped)
- 08:12 AM: Price rallies to 1.1065 (15 pips profit)
- 08:18 AM: Price reaches 1.1075, **take profit hit automatically**

**Result:**
- +25 pips = $167.50 profit (1.67% gain)
- Trade duration: 13 minutes
- Never touched, fully automated

**Why It Worked:**
- Simple, mechanical execution
- No emotional decisions
- Stop far enough to avoid noise (didn't hit at 1.1043)
- Target realistic for London volatility

### Example 2: Technical Level Targets - GBP/USD H4

**Setup:**
- **Strategy**: H4 swing low bounce
- **Analysis**: Support at 1.2550 (tested 3 times), resistance at 1.2720
- **Entry**: 1.2560 (long on bullish pin bar at support)
- **Stop Loss**: 1.2520 (below support + buffer) = 40 pips
- **Target 1**: 1.2635 (50% of range) = 75 pips (1.875:1 R:R)
- **Target 2**: 1.2715 (near resistance) = 155 pips (3.875:1 R:R)
- **Position**: $25,000 account, 1% risk ($250), 0.625 lots

**Execution:**
- **Day 1, 4 PM**: Enter at 1.2560
- **Day 2, 8 AM**: Move stop to breakeven (1.2560) when price reaches 1.2620
- **Day 2, 2 PM**: Target 1 hit at 1.2635, close 50% (0.3125 lots), +$234
- **Day 3, 10 AM**: Price reaches 1.2708
- **Day 3, 11 AM**: Price reverses from 1.2712 (5 pips from Target 2)
- **Day 3, 4 PM**: Exit remaining 50% at 1.2695, +$422

**Result:**
- 50% position: +75 pips = $234
- 50% position: +135 pips = $422
- **Total**: +$656 (2.62% gain)
- **Average R:** +2.6R

**Key Decisions:**
- Moving stop to breakeven protected profits
- Taking partial profit at midpoint guaranteed win
- Exiting near Target 2 instead of waiting captured most of move
- Technical levels provided logical exit points

### Example 3: ATR-Based Trade - XAU/USD H1

**Setup:**
- **Instrument**: Gold (XAU/USD)
- **Timeframe**: H1
- **Entry**: $1,965 (long on trend continuation)
- **ATR(14, H1)**: $12
- **Multiplier**: 2x (day trading)
- **Stop**: $1,965 - ($12 × 2) = $1,941 (24 points)
- **R:R**: 1:2.5
- **Target**: $1,965 + ($24 × 2.5) = $2,025 (60 points)
- **Position**: $50,000 account, 1% risk ($500), 0.21 lots

**Execution:**
- **9:00 AM**: Enter long at $1,965
- **11:00 AM**: Price pulls back to $1,952 (-13 points, nervous but ATR stop allows it)
- **1:00 PM**: Price rallies to $1,988 (+23 points)
- **3:00 PM**: US session opens, gold surges
- **5:00 PM**: Price reaches $2,025, **target hit** (+60 points)

**Result:**
- +$60 × 0.21 lots = $1,260 profit (2.52% gain)
- 2.5R trade

**Why ATR Worked:**
- $24 stop accommodated normal H1 volatility on gold
- Without ATR, might have used $15 stop (would have been stopped at $1,952)
- ATR "breathing room" allowed trade to survive pullback
- Large target ($60) appropriate for gold's volatility

### Example 4: Failed Trade Example (Learning)

**Setup:**
- **Pair**: EUR/USD
- **Entry**: 1.1050 (long on assumed support)
- **Stop**: 1.1020 (30 pips, below support)
- **Target**: 1.1110 (60 pips, 2:1 R:R)

**What Went Wrong:**
- **5 minutes after entry**: Strong USD data released (forgot to check calendar)
- **8 minutes after entry**: EUR/USD drops sharply
- **12 minutes after entry**: Stopped out at 1.1020 (-30 pips)
- Price continued to 1.0990

**Lesson:**
- Fixed stops protected from disaster (didn't hold hoping for recovery)
- Lost only 1% of account (30 pips = planned risk)
- If no stop, might have held to 1.0990 (-60 pips, -2%)
- **Key**: Fixed stop limited damage to acceptable level

**What Trader Did Right:**
- Respected stop (didn't move it away)
- Accepted loss (didn't revenge trade)
- Reviewed mistake (calendar check now mandatory)
- Fixed stops prevented emotional "maybe it'll come back" holding

## Pros & Cons

### Fixed Targets & Stops - Pros
- Simple and mechanical (no decisions during trade)
- Removes emotion completely
- Guarantees consistent risk-reward ratios
- Easy to backtest and optimize
- Perfect for automated trading
- Forces discipline
- Prevents "hoping" trades recover
- Can "set and forget" (don't need to watch constantly)

### Fixed Targets & Stops - Cons
- May exit early (price continues beyond target)
- Stop may be too tight or too wide (doesn't adapt)
- Doesn't account for changing market conditions
- Gives back profit in strong trends (vs. trailing stops)
- Can miss large moves (hit target, then price runs 200 more pips)
- Technical stops may be at obvious levels (stop hunts)
- Fixed pips ignore individual trade context

## Best Market Conditions

**Works Best In:**
- Clear ranging markets (support/resistance levels obvious)
- Scalping (quick in/out, no time to manage)
- News trading (pre-defined risk essential)
- High-frequency strategies (many trades, mechanical execution)
- When personal discipline is weak (removes temptation)
- Automated trading (EA requires fixed parameters)

**Works Worst In:**
- Strong trending markets (leaves profit on table)
- Highly volatile markets (fixed stops too tight)
- Low liquidity periods (slippage exceeds fixed distances)
- When targets are far beyond any technical level

**Best Pairs:**
- **EUR/USD**: Liquid, respects technical levels
- **USD/JPY**: Smooth price action, predictable moves
- **EUR/GBP**: Range-bound, clear technical levels
- **XAU/USD**: Clear support/resistance levels

## Current Best Practices (2025-2026)

### Professional Standards

1. **Minimum 1:2 Risk-Reward Ratio**: Professional traders require minimum 1:2 R:R for any fixed target trade. This allows 33% win rate to breakeven, giving statistical edge with 40%+ win rates.

2. **Technical Level Priority**: Modern trading analysis emphasizes placing stops and targets at actual technical levels (support, resistance, swing points) rather than arbitrary pip distances. This increases probability of success.

3. **ATR Integration**: 2025 traders increasingly use ATR for stop placement even with fixed targets, allowing stops to adapt to volatility while maintaining fixed target distance from stop.

4. **Partial Position Exits**: The "scale out" approach (multiple targets) is now considered professional standard, balancing profit certainty with larger reward potential. Typical: 50-60% at first target, 40-50% for extended target.

5. **Breakeven Stop Protocol**: Moving stop to breakeven after reaching 1:1 R:R or first target is standard risk management, guaranteeing zero-loss on partial positions while allowing remaining position to run.

### Common Mistakes (2025-2026)

1. **Moving Stops Away**: Widening stops when being tested. Fixed means FIXED - moving stop away violates entire system and leads to massive losses.

2. **Taking Profit Early**: Manually closing at +30 pips when target is 60 pips because "profit is profit." This destroys strategy expectancy and R:R ratios.

3. **No Breakeven Stop**: Not moving stop to breakeven when reaching first target, allowing winners to turn into losers.

4. **Ignoring Spread**: Setting 10-pip target on 2-pip spread pairs means only 8 pips of actual profit. Always account for spread.

5. **Not Backtesting Fixed Levels**: Using fixed 30-pip stops without testing if that distance is optimal for strategy and pair. Requires backtesting multiple distances.

### Resources from Trading Communities

- **BabyPips**: "Set stop losses before entering trades - never adjust stops further away, only closer or leave them"
- **ForexFactory Consensus**: "Use 1:2 minimum R:R for swing trades, 1:1.5 minimum for scalps"
- **MQL5 Community**: "Fixed stops are essential for automated EAs - allows reliable backtesting and live performance"
- **Professional Trader**: "Fixed stops protect you from yourself. The best trade management is no management - set levels and walk away."

## Related Topics

- [Stop Loss Placement](../03-Risk-Management/02-stop-loss-placement.md) - Detailed stop loss strategies
- [Risk-Reward Optimization](../03-Risk-Management/05-risk-reward-optimization.md) - Expectancy and R:R analysis
- [Trailing Stops](02-trailing-stops.md) - Alternative dynamic exit strategy
- [Indicator-Based Exits](03-indicator-based-exits.md) - Technical indicator exits
- [Position Sizing Methods](../03-Risk-Management/01-position-sizing-methods.md) - Size calculation based on stop distance
- [Support & Resistance Levels](../07-Market-Analysis/03-support-resistance-levels.md) - Technical level identification

## References

**Fixed Exit Strategy Resources:**
- BabyPips School - "Setting Stop Losses and Take Profits" fundamental course
- Investopedia - "Risk-Reward Ratio" calculation and application
- MQL5 Documentation - SetStopLoss and SetTakeProfit functions for MT5 EAs
- ForexFactory Forums - Community consensus on optimal R:R ratios by strategy type
- TradingView - Pine Script tutorials for automated stop/target implementation

---

**Last Updated**: February 2026
**Complexity Level**: Beginner
**Time to Master**: 1 week
**Critical Importance**: ⭐⭐⭐⭐⭐ (Foundation of risk management and discipline - must master first)
