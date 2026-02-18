# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Prism Trading Robot** is a MetaTrader 5 (MT5) Expert Advisor (EA) written in **MQL5** — not JavaScript, TypeScript, or Python. All source files use `.mq5` (entry point) and `.mqh` (include/header) extensions.

## Build & Compilation

There is no automated build system. MQL5 code is compiled inside **MetaEditor** (bundled with MetaTrader 5):

- Open `source/prism.mq5` in MetaEditor
- Press **F7** or **Ctrl+Shift+F5** to compile
- Output: `prism.ex5` (binary executable loaded by MT5)
- Compilation errors appear in MetaEditor's "Errors" tab

**Testing**: Use the MT5 Strategy Tester (built-in backtester). No unit test framework exists.

**Deployment**: Copy the entire `source/` folder into MT5's `MQL5/Experts/` directory, then compile.

## Architecture

The EA was refactored from a monolithic single file (~1,744 lines in v20.5) to a modular architecture in v22.0. The entry point coordinates five include files:

```
source/
├── prism.mq5                     # Main EA: OnInit, OnTick, OnDeinit + all input parameters
└── Includes/
    ├── MilestoneTypes.mqh        # Shared data structures (CalendarEvent, MarketConditions, PositionStats, IndicatorValues)
    ├── MilestoneIndicators.mqh   # ATR, ADX, MA indicator handles + ReadIndicatorValues()
    ├── MilestoneCalendar.mqh     # Economic calendar integration via MT5 native API
    ├── MilestoneSignals.mqh      # Four trading signal generators (A/B/C/D)
    └── MilestonePositions.mqh    # Open position analysis + historical profit calculation
```

**Data flow**: `prism.mq5` calls `ReadIndicatorValues()` → `AnalyzePositions()` → `PrepareCalendar()` → `AnalyzeTrendSignals()` on each tick, then executes trades based on returned structs.

## Trading Signals

Four independent signals, each configurable with enable/disable and trading hours:

- **Signal A** – Trend following: fast MA (90-period) vs slow MA (30-period) crossover with pip-range trend strength filter
- **Signal B** – ADX directional crossover: +DI/-DI lines crossing above ADX threshold
- **Signal C** – Counter-trend: detects candle spikes and wick rejections on extended moves
- **Signal D** – Momentum composite: MA + ADX + economic calendar filter combined

## Input Parameters

Parameters are grouped into 14 logical sections in `prism.mq5` (lines ~1–200). Key groups:
- **GENERAL CONTROLS**: `CloseAll` (emergency exit), `ContinueTrading`
- **NEWS & CALENDAR**: Controls news blackout windows (`LeadCalendarMinutes`, `TrailCalendarMinutes`)
- **RISK MANAGEMENT**: Percentage-based sizing (`MarginUsage`, `BackupMargin`), margin floor, stop logic
- **BACKUP SYSTEM**: Drawdown-triggered insurance trades (`TriggerBackSystem`, `CandleSpike`, `AllowHedge`)
- **PROFIT TARGETS**: Basket closure, daily growth targets, safe-exit conditions

## Key Conventions

- **Pip calculation**: `GetPipPoint()` in `MilestonePositions.mqh` auto-detects 4 vs 5-digit pricing (e.g., EURUSD vs USDJPY)
- **ATR-based spacing**: `TradeSpace` (minimum distance between trades) is measured in ATR units, not pips
- **Magic number**: Identifies EA's own orders — never hardcoded; passed from main file to all include functions
- **Struct-based API**: Functions accept/return `IndicatorValues`, `PositionStats`, `CalendarData` structs rather than raw primitives

## Documentation

- `source/README.md` — Feature overview for v22.0
- `source/CHANGELOG.md` — Version history
- `docs/back_trade_system.md` — Deep dive on backup/insurance trade logic
- `docs/CALENDAR_INTEGRATION_README.md` — Economic calendar setup
- `research/` — 52 trading strategy reference documents (research only, not implementation specs)
