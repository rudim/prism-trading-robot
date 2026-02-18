# Backup Trade System Analysis - Prism

## Overview

The backup trade system in Prism is **NOT a traditional martingale strategy**. Instead of doubling position sizes after losses, it uses a **conservative grid/averaging approach** with spike detection to add smaller "insurance" positions during minor drawdowns.

## Key Characteristics

### Lot Sizing Strategy
- **Regular trades**: Use 10% of balance for margin calculation (`MarginUsage = 0.1`)
- **Backup trades**: Use only 1% of balance for margin calculation (`BackupMargin = 0.01`)
- **Result**: Backup trades are approximately **1/10th the size** of regular trades
- This is the **opposite of martingale** - backup trades are SMALLER, not larger

### Trigger Conditions

The backup system activates when **ALL** of the following conditions are met:

```mql5
// From OnTick() lines 1593-1598
if(totalTrades >= MaxStartTrades &&
   (accountInfo.Balance() + (totalProfit + totalLoss)) / accountInfo.Balance() < TriggerBackSystem)
{
   backSystem();
}
```

#### 1. Trade Count Threshold
- `totalTrades >= MaxStartTrades` (default: 1)
- Must have at least the minimum number of open positions

#### 2. Equity Drawdown Threshold
- `(Balance + CurrentProfit) / Balance < TriggerBackSystem`
- Default: `TriggerBackSystem = 0.999` (0.999 = 99.9%)
- Triggers when equity drops to **99.9% of balance** (0.1% drawdown)
- Very conservative trigger - activates on minimal drawdown

#### 3. Maximum Trade Limit
- `totalBackupTrades < MaxTrades - MaxStartTrades`
- Default: Can open up to 6 backup trades (7 max - 1 start = 6)
- Prevents unlimited position stacking

## Operating Modes

### Mode 1: Aggressive (Default: OFF)

```mql5
input bool Aggressive = false;
```

When enabled, the system follows current trend signals:
- **Bullish signal** → Opens BUY backup positions
- **Bearish signal** → Opens SELL backup positions
- No spike detection required
- Trades align with existing trend direction

**Code location**: lines 1259-1278

### Mode 2: Spike Detection (Default: ON)

The default mode uses sophisticated spike detection to identify rejection candles:

#### BUY Backup Trigger (Bullish Spike)
```mql5
// Lines 1282-1303
if(MathAbs(highArray[0] - lowArray[0]) > CandleSpike * MathAbs(highArray[1] - lowArray[1]) &&
   openArray[0] < closeArray[0] &&
   closeArray[0] < (highArray[0] + lowArray[0]) / 2)
```

Conditions:
1. **Spike size**: Current candle range > 5x previous candle range
2. **Bullish candle**: Close > Open (green/white candle)
3. **Rejection pattern**: Close below candle midpoint (upper wick rejection)
4. **Hedging check**: Only if `AllowHedge=true` OR existing positions are BUY

**Logic**: Large spike up that fails to hold = potential reversal down → BUY opportunity

#### SELL Backup Trigger (Bearish Spike)
```mql5
// Lines 1306-1327
if(MathAbs(highArray[0] - lowArray[0]) > CandleSpike * MathAbs(highArray[1] - lowArray[1]) &&
   openArray[0] > closeArray[0] &&
   closeArray[0] > (highArray[0] + lowArray[0]) / 2)
```

Conditions:
1. **Spike size**: Current candle range > 5x previous candle range
2. **Bearish candle**: Close < Open (red/black candle)
3. **Rejection pattern**: Close above candle midpoint (lower wick rejection)
4. **Hedging check**: Only if `AllowHedge=true` OR existing positions are SELL

**Logic**: Large spike down that fails to hold = potential reversal up → SELL opportunity

## Key Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `TriggerBackSystem` | 0.999 | Equity/Balance ratio trigger (99.9%) |
| `BackupMargin` | 0.01 | 1% of balance for backup lot sizing |
| `MarginUsage` | 0.1 | 10% of balance for regular lot sizing |
| `CandleSpike` | 5 | Spike multiplier (current range vs previous) |
| `MaxTrades` | 7 | Maximum total trades per basket |
| `MaxStartTrades` | 1 | Minimum trades before backup activates |
| `Aggressive` | false | Use trend-following vs spike detection |
| `AllowHedge` | false | Allow opposite direction backup trades |

## Calendar Integration

The backup system respects calendar restrictions:

```mql5
// Lines 1337-1351
if(EnableCalendar)
{
   string calType = getCalendarType1();

   if(ffCalenadarEventTime1 > TrailCalendarMinutes && calType == "since ")
      sendBack();  // Safe: enough time since news
   else if(ffCalenadarEventTime1 > LeadCalendarMinutes && calType == "until ")
      sendBack();  // Safe: enough time before news
   else if(ffCalenadarEventTime1 >= 99999)
      sendBack();  // Safe: no news scheduled
}
```

Will NOT open backup trades:
- Within `LeadCalendarMinutes` (240 min) before high-impact news
- Within `TrailCalendarMinutes` (480 min) after high-impact news

## Risk Management Features

### 1. Position Sizing Protection
- Backup trades are 10x SMALLER than regular trades
- Limits exposure during drawdown periods
- Default: `backupLotSize = MinLots` (0.03) minimum

### 2. Margin Checks
```mql5
// Lines 1287-1302
double freeMargin = accountInfo.FreeMargin();
double marginRequired = 0;
if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, backupLotSize, ask, marginRequired))
{
   if(freeMargin >= marginRequired)
   {
      // Open backup trade
   }
}
```
- Validates sufficient margin before each backup trade
- Prevents margin call scenarios

### 3. Trade Count Limits
- Maximum 7 trades per basket (regular + backup combined)
- Prevents unlimited position stacking
- Configurable via `MaxTrades` parameter

### 4. Sleep Timer Respected
```mql5
// Lines 1589-1591
if(currentTime - lastTradeTime > SleepSeconds)
```
- Minimum `SleepSeconds` (14400 = 4 hours) between trades
- Applies to both regular and backup trades
- Prevents rapid-fire position opening

## Strategic Purpose

The backup system serves as a **downside protection mechanism**:

1. **Early Drawdown Response**: Activates at minimal 0.1% drawdown
2. **Counter-Trend Entries**: Spike detection identifies potential reversals
3. **Position Averaging**: Adds to positions at better prices
4. **Risk-Limited**: Uses smaller lot sizes (1% vs 10% margin)
5. **Market Context Aware**: Respects calendar events and spread conditions

## Comparison to Martingale

| Feature | Traditional Martingale | Prism Backup System |
|---------|----------------------|------------------------|
| **Lot sizing** | Doubles after loss (2x, 4x, 8x) | Fixed smaller size (0.1x of regular) |
| **Risk profile** | Exponentially increasing | Linear, controlled |
| **Entry logic** | After every loss | Spike detection + drawdown threshold |
| **Maximum trades** | Often unlimited | Hard cap at 7 trades |
| **Recovery goal** | Recover all losses + initial profit | Exit at break-even or small profit |
| **Margin risk** | Very high (exponential growth) | Low (decreasing position sizes) |

**Conclusion**: This is NOT a martingale strategy. It's a **defensive grid/averaging system** with spike-based entry logic and conservative position sizing.

## Code References

- **Main trigger logic**: `OnTick()` lines 1593-1598
- **Backup system entry**: `backSystem()` lines 1335-1351
- **Trade execution**: `sendBack()` lines 1244-1330
- **Lot size calculation**: `calculateLotSize()` lines 379-381
- **Aggressive mode**: lines 1259-1278
- **Spike detection mode**: lines 1280-1328

## Optimization Considerations

To adjust backup system behavior:

1. **More conservative**: Increase `TriggerBackSystem` to 0.995 (0.5% drawdown)
2. **More aggressive**: Decrease to 0.99 (1% drawdown)
3. **Larger backup trades**: Increase `BackupMargin` from 0.01 to 0.02 (2%)
4. **More sensitive spikes**: Decrease `CandleSpike` from 5 to 3
5. **Less sensitive spikes**: Increase `CandleSpike` to 7 or 10
6. **Disable spike detection**: Set `Aggressive = true`
