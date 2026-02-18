# Prism Trading EA - Changelog

## Modular Refactoring

### Architecture Changes

- Extracted signal logic into `Includes/PrismSignals.mqh`
  - All 4 signals (A, B, C, D) in a dedicated module
  - Easy to maintain and extend with new signals

- Extracted calendar logic into `Includes/PrismCalendar.mqh`
  - Economic calendar integration isolated
  - MT5 native API implementation

- Extracted indicator management into `Includes/PrismIndicators.mqh`
  - ATR, ADX, MA handle management
  - Buffer reading and validation

- Extracted position analysis into `Includes/PrismPositions.mqh`
  - Position statistics calculation
  - Historical profit analysis
  - Proximity detection logic

- Created common types in `Includes/PrismTypes.mqh`
  - `CalendarEvent`, `MarketConditions`, `PositionStats`, `IndicatorValues`, `CalendarData` structures

### Parameter Reorganization

Parameters regrouped into 14 logical categories with descriptive comments:

1. General Controls
2. News & Calendar
3. Risk Management
4. Trade Management
5. Profit Targets
6. Backup System
7. Signal A: Trend Following
8. Signal B: ADX Crossover
9. Signal C: Counter-Trend
10. Signal D: Momentum
11. Indicator: ATR
12. Indicator: ADX
13. Indicator: Moving Averages
14. History & Statistics

### Rebrand

- Renamed from Milestone EA to Prism Trading EA
- Updated copyright to Rudi & Claude
- Removed explicit version properties (version tracked in git)

### No Trading Logic Changes

The actual trading behaviour is unchanged:
- Same signal calculations
- Same entry/exit logic
- Same risk management
- Same calendar integration
- Same backup system
- Same position management
