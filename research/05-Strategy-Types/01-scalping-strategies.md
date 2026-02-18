# Scalping Strategies

## Overview

Scalping captures small, frequent profits from minimal price movements. Scalpers make dozens to hundreds of trades per day, targeting 5-20 pip profits with tight 10-20 pip stops. Success requires speed, discipline, low spreads, and stable execution. While demanding, scalping provides consistent cash flow and works in most market conditions.

**Why this matters**: Scalping offers multiple daily opportunities independent of major trends. Small consistent wins compound rapidly. A scalper making 10 trades/day at +10 pips average = 100 pips daily = 2,000+ pips monthly. High win rate (60-75%) provides psychological advantage of frequent wins.

**When to use it**: Scalp during high liquidity periods (London/NY sessions), with low-spread pairs (EUR/USD, USD/JPY), on M5-M15 timeframes. Requires fast execution broker, tight spreads (<1 pip), and stable platform. Not for part-time traders or slow connections.

## Core Scalping Principles

**1. Speed & Execution:**
- Trades last minutes to hours (rarely longer)
- Entry/exit must be instant
- Slippage = profit killer

**2. Tight Spread Requirement:**
- EUR/USD: 0.5-1 pip max
- GBP/USD: 1-1.5 pips max
- USD/JPY: 0.5-1 pip max
- Gold: $0.20-0.30 max

**3. High Win Rate:**
- Need 60-75% winners
- Small R:R (1:1 to 1:1.5) compensated by frequency

**4. Risk Management:**
- Risk 0.5-1% max per trade (many trades daily)
- Daily loss limit: 2-3% (circuit breaker)
- Stop trading after 3-5 consecutive losses

## Scalping Strategy #1: M5 EMA Crossover

**Timeframe:** M5
**Pairs:** EUR/USD, GBP/USD, USD/JPY

**Setup:**
- 10 EMA, 20 EMA, 50 EMA on M5 chart
- Trade during London (8am-12pm GMT) or NY (1pm-5pm GMT)

**Long Entry:**
- 10 EMA crosses above 20 EMA
- Both above 50 EMA (trend filter)
- Enter immediately on cross

**Short Entry:**
- 10 EMA crosses below 20 EMA
- Both below 50 EMA
- Enter on cross

**Stop Loss:** 15 pips
**Take Profit:** 15-20 pips (1:1 to 1:1.3)

**Example:**
- EUR/USD M5
- 10 EMA crosses above 20 EMA at 1.1050
- Entry: 1.1051
- Stop: 1.1036 (15 pips)
- Target: 1.1066 (15 pips)
- Duration: 25 minutes
- Result: +15 pips

**Daily Expectancy:** 10-15 trades, 65% win rate, +80-120 pips

## Scalping Strategy #2: Range Scalping

**Timeframe:** M15
**Pairs:** EUR/GBP, EUR/CHF (tight rangers)

**Setup:**
- Identify 30-50 pip range
- Place buy orders at support, sell orders at resistance
- Use Bollinger Bands (15 period, 2 std dev) for confirmation

**Entry Rules:**
- Price touches lower BB near support → Buy
- Price touches upper BB near resistance → Sell
- RSI confirms (< 35 for buy, > 65 for sell)

**Stop Loss:** 20 pips beyond range boundary
**Take Profit:** Middle of range (15-25 pips)

**Example:**
- EUR/GBP M15 range: 0.8550-0.8595
- Price at 0.8552 (lower BB touch)
- RSI = 32
- Entry: Long at 0.8553
- Stop: 0.8533 (20 pips)
- Target: 0.8573 (middle, 20 pips)
- Result: +20 pips in 45 minutes

**Expectancy:** 5-10 trades/day, 70-75% win rate

## Scalping Strategy #3: Breakout Scalp

**Timeframe:** M5-M15
**Session:** London open (8am GMT), NY open (1pm GMT)

**Setup:**
- Identify consolidation in Asian session (typically 20-40 pips)
- Wait for London/NY volume surge
- Trade breakout direction

**Entry:**
- Price breaks 5 pips above/below consolidation
- Volume increase (if available)
- Enter with 2-5 pip buffer

**Stop Loss:** Back inside range + 5 pips
**Take Profit:** 1× to 1.5× range size

**Example:**
- EUR/USD consolidates 1.1000-1.1035 (35 pips) during Asian
- London opens, breaks above 1.1040
- Entry: 1.1042
- Stop: 1.1025 (back in range, 17 pips)
- Target: 1.1077 (35 pips = range size, 2:1 R:R)
- Result: Hits target in 15 minutes

**Expectancy:** 2-4 breakouts daily, 50-60% win rate, larger R:R compensates

## Scalping Strategy #4: News Spike Scalp

**Timeframe:** M1-M5
**Events:** NFP, FOMC, CPI, retail sales

**Setup:**
- Major news event in 1 minute
- Wait for initial spike (do NOT trade spike)
- Enter on retracement

**Entry Rules:**
- Spike occurs (price jumps 30-50+ pips)
- Wait for 50% retracement of spike
- Enter in direction of spike continuation
- Example: Spike up 50 pips, retraces 25 pips, enter long

**Stop Loss:** 20-30 pips
**Take Profit:** 30-50 pips (second wave)

**Example:**
- NFP better than expected
- EUR/USD spikes from 1.1000 to 1.1055 (+55 pips in 30 seconds)
- Retraces to 1.1030 (25 pips back)
- Entry: Long at 1.1032
- Stop: 1.1005 (27 pips)
- Target: 1.1065 (33 pips, 1.2:1)
- Result: Second wave to 1.1070 (+38 pips)

**Warning:** High risk, wide spreads during news. Only for experienced scalpers.

## Risk Management for Scalping

**Position Sizing:**
- Risk 0.5% per scalp (multiple trades daily)
- $10,000 account: $50 risk per trade
- 15-pip stop on EUR/USD: 0.33 lots

**Daily Limits:**
- **Maximum Daily Risk:** 3%
- **Maximum Trades:** 20 (prevents overtrading)
- **Loss Streak Rule:** Stop after 5 losses
- **Daily Profit Target:** 50-100 pips (can stop after hitting)

**Position Management:**
- No holding overnight
- Close all positions by session end
- Move to breakeven at +5-7 pips
- No averaging down (recipe for disaster)

## Technical Requirements

**Broker:**
- ECN/STP execution (no dealing desk)
- Spreads: EUR/USD < 1 pip
- Commission: < $7 round-turn per lot
- Execution speed: < 50ms
- No requotes

**Platform:**
- MT5 or fast execution platform
- One-click trading essential
- Good VPS if trading from home

**Internet:**
- Stable connection (fiber optic ideal)
- VPS recommended (near broker server)
- Backup connection critical

## Best Pairs for Scalping

| Pair | Typical Spread | Volatility | Best Session |
|------|----------------|------------|--------------|
| **EUR/USD** | 0.5-1.0 pips | Moderate | London/NY |
| **USD/JPY** | 0.5-1.0 pips | Low-Mod | Tokyo/London |
| **GBP/USD** | 1.0-1.5 pips | High | London |
| **EUR/GBP** | 1.0-1.5 pips | Low | London |
| **AUD/USD** | 0.8-1.2 pips | Moderate | Sydney/London |

**Avoid:**
- Exotic pairs (wide spreads)
- Illiquid times (Asian afternoon)
- Pre/post major news (spread widens)

## Scalping Session Schedule

**Asian Session (12am-8am GMT):**
- Low volume, ranging
- Use range scalping strategy
- EUR/JPY, AUD/JPY

**London Session (8am-12pm GMT):**
- BEST for scalping
- High volume, clear moves
- EUR/USD, GBP/USD, EUR/GBP

**NY Session (1pm-5pm GMT):**
- Good volume
- USD pairs active
- EUR/USD, GBP/USD, USD/JPY

**London/NY Overlap (1pm-4pm GMT):**
- PEAK liquidity
- Fastest moves
- All major pairs

## Common Scalping Mistakes

1. **Over-Leveraging:** Using 10:1+ leverage, one bad trade = account damage
2. **Spread Ignorance:** Forgetting 1-pip spread = 10% of 10-pip target
3. **No Daily Limit:** Keep trading when losing, blow account
4. **Averaging Down:** Adding to losers, turning scalps into hold-and-hope
5. **Slow Execution:** Manual entries, missed fills, slippage kills profits

## Scalping vs. Other Styles

| Factor | Scalping | Day Trading | Swing Trading |
|--------|----------|-------------|---------------|
| **Timeframe** | M1-M15 | H1 | H4-D1 |
| **Hold Time** | Minutes-hours | Hours-day | Days-weeks |
| **Target** | 5-20 pips | 30-100 pips | 100-400 pips |
| **Win Rate** | 65-75% | 50-60% | 40-50% |
| **Trades/Day** | 10-50 | 2-10 | 0.5-2 |
| **Stress** | Very High | High | Moderate |
| **Time Required** | Full-time | Part-time+ | Part-time |

## Pros & Cons

**Pros:**
- Many opportunities daily
- High win rate (psychological advantage)
- Quick profits (no overnight holds)
- Works in most conditions
- Compounding effect of frequent wins

**Cons:**
- Extremely time-intensive
- High stress/focus required
- Spread/commission significant % of profit
- Requires fast execution
- Exhausting over time
- Not suitable for employment

## Best Market Conditions

**Works Best:**
- High liquidity (London/NY)
- Moderate volatility
- Clear short-term trends/ranges
- Tight spreads
- Fast execution environment

**Works Worst:**
- Low liquidity (Asian afternoon)
- Extreme volatility (news spikes)
- Wide spreads (exotics, pre-news)
- Slow execution/high slippage

## Current Best Practices (2025-2026)

1. **Algo Competition:** Many scalpers now semi-automated (EAs for entries)
2. **Spread Crucial:** 0.5-pip spread standard, 1+ pip makes scalping difficult
3. **Breakeven Fast:** Move stop to breakeven at +5-7 pips immediately
4. **Session-Specific:** London session remains most reliable for manual scalping
5. **Risk Caps:** 3% daily loss limit now industry standard

## Related Topics

- [Fixed Targets & Stops](../02-Exit-Signals/01-fixed-targets-stops.md)
- [Mean Reversion Entries](../01-Entry-Signals/02-mean-reversion-entries.md)
- [Position Sizing Methods](../03-Risk-Management/01-position-sizing-methods.md)
- [Drawdown Limits](../03-Risk-Management/04-drawdown-limits.md)
- [Market Sessions & Timing](../07-Market-Analysis/01-market-sessions-timing.md)

## References

- BabyPips - "Scalping" strategy guide
- Investopedia - "Scalping Trading" definition
- ForexFactory - Scalping strategy threads
- MQL5 Community - Scalping EA development
- TradingView - M5 scalping scripts

---

**Last Updated**: February 2026
**Complexity Level**: Advanced
**Time to Master**: 3-6 months
**Critical Importance**: ⭐⭐⭐ (High-frequency, demanding, but profitable for dedicated traders)
