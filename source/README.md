# Prism Trading EA

## Overview

Prism is a MetaTrader 5 Expert Advisor built around a modular architecture. The core trading logic is split across focused include files to improve maintainability and extensibility.

## Architecture

```
source/
├── prism.mq5               # Main EA: OnInit, OnTick, OnDeinit + all input parameters
└── Includes/
    ├── PrismTypes.mqh      # Common data structures
    ├── PrismCalendar.mqh   # Economic calendar integration
    ├── PrismSignals.mqh    # Signal generation (A, B, C, D)
    ├── PrismIndicators.mqh # Indicator management
    └── PrismPositions.mqh  # Position analysis
```

## Parameter Groups

Parameters are organised into 14 logical sections in `prism.mq5`:

- **General Controls** – Basic EA operation (`CloseAll`, `ContinueTrading`)
- **News & Calendar** – Economic event filtering and blackout windows
- **Risk Management** – Margin, stops, and lot sizing
- **Trade Management** – Position limits, spacing, timing, and spread filter
- **Profit Targets** – Exit strategies and daily growth goals
- **Backup System** – Drawdown recovery mechanism
- **Signal A: Trend Following** – MA crossover parameters
- **Signal B: ADX Crossover** – Directional indicator signals
- **Signal C: Counter-Trend** – Extreme move entries
- **Signal D: Momentum** – Combined MA/ADX with news filter
- **Indicator: ATR** – Volatility measurement
- **Indicator: ADX** – Trend strength
- **Indicator: Moving Averages** – Trend direction
- **History & Statistics** – Performance tracking

## Include File Details

### PrismTypes.mqh
Common data structures:
- `CalendarEvent` – Economic event data
- `MarketConditions` – Bullish/bearish/ranging flags
- `PositionStats` – Open position statistics
- `IndicatorValues` – Technical indicator readings
- `CalendarData` – News event timing data

### PrismCalendar.mqh
Economic calendar integration:
- `PrepareCalendar()` – Fetches news events from MT5 API
- `GetSymbolCurrencies()` – Extracts base/quote currencies
- `IsEventImportanceIncluded()` – Filters by impact level
- `IsSpeakingEvent()` – Detects central bank speeches
- `GetCalendarTypeString()` – Formats "since" or "until" text

### PrismSignals.mqh
Signal generation logic:
- `AnalyzeSignalA()` – Trend following with MA crossover
- `AnalyzeSignalB()` – ADX directional indicator crossover
- `AnalyzeSignalC()` – Counter-trend on strong moves
- `AnalyzeSignalD()` – MA momentum + ADX with calendar filter
- `AnalyzeTrendSignals()` – Master function evaluating all signals
- `IsWithinTradingHours()` – Time-of-day filtering

### PrismIndicators.mqh
Technical indicator management:
- `IndicatorHandles` – Structure holding all indicator handles
- `InitializeIndicators()` – Creates ATR, ADX, MA handles
- `ReadIndicatorValues()` – Copies indicator buffers into structure

### PrismPositions.mqh
Position analysis and statistics:
- `AnalyzePositions()` – Scans open positions and calculates stats
- `CalculateHistoricalProfit()` – Analyses closed trade history
- `GetPipPoint()` – Determines pip value based on symbol digits

## Compilation Requirements

- MT5 build 3802 or higher
- Trade library (included with MT5)
- All include files must be in the `Includes/` subdirectory

## Further Documentation

- `back_trade_system.md` – Backup system deep-dive
- `CALENDAR_INTEGRATION_README.md` – Economic calendar setup

## Authors

Rudi & Claude
