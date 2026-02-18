# Moving Averages

## Overview

Moving averages are the most widely used technical indicators in trading, forming the foundation of countless strategies. They smooth price data to identify trend direction, provide dynamic support/resistance levels, and generate entry/exit signals through crossovers. Simple yet powerful, moving averages work across all markets, timeframes, and trading styles.

**Why this matters**: Every professional trader uses moving averages in some form. They filter market noise, reveal underlying trends, and provide objective reference points for decision-making. Master moving averages and you master trend identification - the core skill of profitable trading.

**When to use it**: Use MAs for trend identification (is price above or below MA?), dynamic support/resistance (will price bounce off MA?), crossover signals (did fast MA cross slow MA?), and trade filtering (only buy when above 200 MA). Effective on all timeframes from M5 scalping to D1 position trading.

## What Are Moving Averages?

A moving average calculates the average price over a specified number of periods, creating a smoothed line that "moves" with new data. As new prices form, the oldest prices drop off, keeping the average current.

**Types of Moving Averages:**

### 1. Simple Moving Average (SMA)
Arithmetic mean of prices over N periods. All periods weighted equally.

**Formula:** SMA = (P1 + P2 + P3 + ... + PN) / N

**Example - 5-period SMA:**
- Prices: 1.1000, 1.1010, 1.1020, 1.1015, 1.1025
- SMA = (1.1000 + 1.1010 + 1.1020 + 1.1015 + 1.1025) / 5 = 1.1014

### 2. Exponential Moving Average (EMA)
Weighted average giving more importance to recent prices. More responsive to new data.

**Formula:** EMA = (Close - Previous EMA) × Multiplier + Previous EMA
- Multiplier = 2 / (Period + 1)

**Example - 10-period EMA:**
- Multiplier = 2 / 11 = 0.1818
- More weight on recent 2-3 periods vs. SMA's equal weight

### 3. Weighted Moving Average (WMA)
Linear weighting with most recent price having highest weight.

**Formula:** WMA = (P1×1 + P2×2 + P3×3 + ... + PN×N) / (1+2+3+...+N)

**Comparison:**
| Type | Responsiveness | Smoothness | Use Case |
|------|----------------|------------|----------|
| **SMA** | Slowest | Most smooth | Long-term trends, 200 MA |
| **EMA** | Fast | Moderate | Short-term trends, crossovers |
| **WMA** | Fastest | Least smooth | Quick signals, scalping |

**Most Popular:** EMA (20, 50) for day trading, SMA (200) for long-term trend.

## Key Moving Average Periods

### Short-Term MAs (Fast)
- **8-10 EMA**: Very responsive, scalping
- **20 EMA**: Most popular short-term, day trading
- **21 EMA**: Fibonacci-based, swing trading

### Medium-Term MAs (Moderate)
- **50 EMA/SMA**: Standard medium-term trend
- **89 EMA**: Fibonacci-based
- **100 SMA**: Psychological level

### Long-Term MAs (Slow)
- **200 EMA/SMA**: Industry standard for major trend
- **365 SMA**: One-year average (D1 charts)

## Key Moving Average Strategies

### 1. MA Crossover Strategy

**Golden Cross / Death Cross:**
- **Golden Cross**: 50 MA crosses above 200 MA (bullish)
- **Death Cross**: 50 MA crosses below 200 MA (bearish)

**Example - EUR/USD D1:**
- 50 MA crosses above 200 MA at 1.1000
- Enter long, hold until crossover reverses
- Target: Ride full trend (weeks to months)

**Faster Crossovers:**
- **10/20 EMA**: Scalping/day trading
- **20/50 EMA**: Day trading/swing trading
- **50/200 SMA**: Position trading

### 2. MA as Dynamic Support/Resistance

**Concept:** Price tends to bounce off MAs like horizontal support/resistance.

**Trading Rules:**
- **Uptrend**: Buy when price pulls back to 20/50 EMA
- **Downtrend**: Sell when price rallies to 20/50 EMA
- **Stop**: Below MA + buffer (10-20 pips)

**Example:**
- EUR/USD uptrend, price at 1.1100
- Pulls back to 50 EMA at 1.1050
- Bullish pin bar forms at 50 EMA
- Enter long at 1.1055, stop at 1.1035

### 3. Price Above/Below MA Filter

**Simple but Effective Rule:**
- **Only buy when price > 200 SMA** (major uptrend)
- **Only sell when price < 200 SMA** (major downtrend)
- **Stay out when price near 200 SMA** (no clear trend)

**Statistics:** Strategies with this filter often improve win rate by 5-10%.

### 4. Multi-MA Ribbon

**Setup:** Plot 8-12 EMAs with periods 5, 8, 13, 21, 34, 55, 89, 144 (Fibonacci sequence)

**Interpretation:**
- **Bullish**: All MAs sloping up, price above ribbon
- **Bearish**: All MAs sloping down, price below ribbon
- **Ranging**: MAs intertwined, price oscillating through ribbon

**Entry**: Enter when price breaks through ribbon in trend direction.

## Specific Parameters & Settings

### Recommended MA Periods by Timeframe

| Timeframe | Fast MA | Slow MA | Long-Term Filter |
|-----------|---------|---------|------------------|
| **M5** | 10 EMA | 20 EMA | 50 EMA |
| **M15** | 10 EMA | 20 EMA | 50 EMA |
| **M30** | 20 EMA | 50 EMA | 100 EMA |
| **H1** | 20 EMA | 50 EMA | 200 SMA |
| **H4** | 20 EMA | 50 EMA | 200 SMA |
| **D1** | 50 SMA | 200 SMA | - |

### MA Type Selection

**Use SMA When:**
- Looking for major trend (200 MA)
- Prefer smoothness over responsiveness
- Using very long periods (100+)

**Use EMA When:**
- Day trading or swing trading
- Want faster signals
- Using shorter periods (10-50)

**MT5 Implementation:**
```
Insert → Indicators → Trend → Moving Average
Period: 20 (or desired)
MA Method: Exponential (or Simple)
Apply to: Close
```

## Practical Examples

### Example 1: 20/50 EMA Crossover - GBP/USD H1

**Setup:**
- 20 EMA crosses above 50 EMA at 1.2650
- Confirming uptrend beginning

**Entry:** Long at 1.2655 (next candle after cross)
**Stop:** Below recent swing low at 1.2620 (35 pips)
**Management:** Hold while 20 EMA > 50 EMA

**Progression:**
- Day 1-3: Price trends to 1.2750 (20 EMA > 50 EMA, hold)
- Day 4: 20 EMA crosses below 50 EMA at 1.2745
- **Exit:** 1.2745 (+90 pips, $900 on 1.0 lot)

### Example 2: 200 SMA Bounce - EUR/USD D1

**Setup:**
- Strong uptrend, price > 200 SMA for 3 months
- Price pulls back to 200 SMA at 1.1050
- Bullish engulfing forms at 200 SMA

**Entry:** Long at 1.1060 (above engulfing)
**Stop:** 1.1020 (below 200 SMA, 40 pips)
**Target:** Previous high at 1.1250 (190 pips, 4.75:1 R:R)

**Result:** Price bounces, reaches 1.1240 after 2 weeks (+180 pips)

## Pros & Cons

**Pros:**
- Simple, objective, visual
- Works across all markets and timeframes
- Foundation of many strategies
- Built into all platforms
- Easy to backtest and automate

**Cons:**
- Lagging (based on past prices)
- Whipsaws in ranging markets
- Late entry signals
- Gives back profit at trend exhaustion

## Best Market Conditions

**Works Best:**
- Trending markets (ADX > 25)
- H1-D1 timeframes
- Major pairs (EUR/USD, GBP/USD)
- Post-breakout momentum

**Works Worst:**
- Choppy, ranging markets
- Very low/very high volatility
- M1-M5 (too much noise)

## Current Best Practices (2025-2026)

1. **20/50 EMA Standard**: Most popular combination for intraday trading
2. **200 SMA Universal**: Institutional level watched globally
3. **EMA Preferred for Speed**: Modern traders favor EMA over SMA for responsiveness
4. **Confluence with Price Action**: Never trade MA signals alone - always confirm with support/resistance
5. **Multiple Timeframe**: Check MA alignment on higher TF before entering

## Related Topics

- [Trend Following Entries](../01-Entry-Signals/01-trend-following-entries.md)
- [Indicator-Based Exits](../02-Exit-Signals/03-indicator-based-exits.md)
- [Trend Indicators](06-trend-indicators.md)
- [Trend Following Systems](../05-Strategy-Types/05-trend-following-systems.md)

## References

- Investopedia - "Moving Average (MA)" complete guide
- BabyPips - "Moving Averages" school lesson
- TradingView - MA indicator scripts
- MQL5 Documentation - iMA() function reference

---

**Last Updated**: February 2026
**Complexity Level**: Beginner
**Time to Master**: 1-2 weeks
**Critical Importance**: ⭐⭐⭐⭐⭐ (Foundation of technical analysis)
