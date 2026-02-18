# Prism MT5 - Installation & Testing Checklist

## Pre-Installation

- [ ] Read `CALENDAR_QUICK_START.md` (6 minutes)
- [ ] Review `CALENDAR_INTEGRATION_README.md` (15 minutes)
- [ ] Understand calendar impact levels and settings
- [ ] Decide on initial configuration (Conservative/Moderate/Aggressive)

## File Verification

- [ ] Confirm all files are present:
  - `prism.mq5` (70 KB) - Main EA file
  - `CALENDAR_INTEGRATION_README.md` (11 KB) - Complete documentation
  - `CALENDAR_QUICK_START.md` (7 KB) - Quick reference guide
  - `CALENDAR_FLOW_DIAGRAM.txt` (44 KB) - Visual flow diagram
  - `IMPLEMENTATION_SUMMARY.md` (14 KB) - Implementation details
  - `INSTALLATION_CHECKLIST.md` - This file

## Compilation

- [ ] Open MetaEditor (F4 from MT5)
- [ ] Open `prism.mq5`
- [ ] Compile (F7 or press Compile button)
- [ ] Verify zero errors
- [ ] Verify zero warnings
- [ ] Check Expert tab for successful compilation message

**Expected Output:**
```
0 error(s), 0 warning(s)
prism.ex5 successfully compiled
```

## Demo Account Setup

### Step 1: Initial Configuration

- [ ] Open MT5 demo account
- [ ] Select a major currency pair (EURUSD, GBPUSD, USDJPY)
- [ ] Attach EA to 1-hour (H1) chart
- [ ] Configure initial settings:

**Recommended Demo Settings:**
```
========== CALENDAR ==========
EnableCalendar = true
IncludeHigh = true
IncludeMedium = false
IncludeLow = false
IncludeSpeaks = true
LeadCalendarMinutes = 240
TrailCalendarMinutes = 480

========== TRADES ==========
MaxTrades = 3  (reduced for demo testing)

========== MARGIN ==========
MinLots = 0.01  (minimum for safety)
```

- [ ] Enable AutoTrading button in MT5
- [ ] Verify EA smiley face is smiling (not sad)

### Step 2: Initialization Verification

- [ ] Check Expert tab for initialization messages
- [ ] Look for: "Calendar Integration Active - MT5 Native API"
- [ ] Verify indicator handles created successfully
- [ ] Check for any error messages (should be none)

**Expected Expert Tab Output:**
```
╔════════════════════════════════════════════════════════════╗
║ Calendar Integration Active - MT5 Native API              ║
╠════════════════════════════════════════════════════════════╣
║ Using MT5 economic calendar for event filtering           ║
║ Settings:                                                  ║
║   - High Impact: YES                                       ║
║   - Medium Impact: NO                                      ║
║   - Low Impact: NO                                         ║
║   - Speeches: YES                                          ║
║   - Lead time: 240 minutes                                 ║
║   - Trail time: 480 minutes                                ║
╚════════════════════════════════════════════════════════════╝
Prism MT5 initialized successfully on EURUSD
```

### Step 3: HUD Display Check

- [ ] Verify two text labels appear on chart:
  - Main HUD (Growth, Targets, Trend, Spread)
  - Calendar HUD (Event status and details)

**Example Calendar HUD Display:**
```
Calendar: 5h 30m until USD [High] Non-Farm Payrolls
```
or
```
Calendar: No relevant news events
```

### Step 4: MT5 Economic Calendar Verification

- [ ] Open MT5 Economic Calendar: `Tools → Economic Calendar`
- [ ] Verify calendar data is loading
- [ ] Check for upcoming high-impact events
- [ ] Compare with EA's calendar display
- [ ] Ensure currencies match your symbol (EUR/USD for EURUSD)

## Function Testing

### Test 1: Calendar Event Detection

**Objective**: Verify EA detects upcoming news events

- [ ] Check MT5 calendar for next high-impact USD or EUR event
- [ ] Note event time and description
- [ ] Check EA's calendar HUD display
- [ ] Verify event details match (currency, impact, time)

**Pass Criteria**: EA shows correct event with accurate time remaining

### Test 2: Pre-News Trading Restriction

**Objective**: Verify EA stops trading before high-impact news

**Setup**:
- [ ] Wait until 4-6 hours before a high-impact news event
- [ ] Check calendar HUD shows "X hours until [Currency] [High]..."
- [ ] Monitor Expert tab for trading activity

**3-4 hours before news**:
- [ ] EA should stop opening new positions
- [ ] Expert tab should show reduced trading activity
- [ ] Existing positions remain open (unless profitable)

**Less than 240 minutes (4 hours) before news**:
- [ ] Calendar HUD shows: "⚠ NEWS IN Xh Xm - [Currency] [High] [Event] - WAITING/EXIT"
- [ ] EA stops all new position entries
- [ ] If positions exist and overall profit > 0: EA closes all positions
- [ ] Expert tab shows: "Calendar exit triggered: Upcoming news event"

**Pass Criteria**: No new positions opened within LeadCalendarMinutes of news

### Test 3: Post-News Trading Resumption

**Objective**: Verify EA resumes trading after news impact period

**Setup**:
- [ ] Monitor EA after high-impact news event releases
- [ ] Check calendar HUD transitions from "until" to "since"

**0-4 hours after news**:
- [ ] Calendar HUD shows: "⏳ Xh Xm since [Currency] [High] [Event] - CAUTION"
- [ ] EA continues blocking new positions
- [ ] calendar.type1 = 0 (since)

**4-8 hours after news**:
- [ ] Calendar HUD still shows caution state
- [ ] Still no new positions (TrailCalendarMinutes = 480)

**8+ hours after news**:
- [ ] Calendar HUD shows: "Calendar: Xh Xm since [Currency] [Medium] - Trading normal"
- [ ] EA resumes normal trading operations
- [ ] New positions can be opened (if other conditions met)

**Pass Criteria**: Trading resumes exactly TrailCalendarMinutes after news

### Test 4: Calendar Disabled Mode

**Objective**: Verify EA trades normally with calendar disabled

- [ ] Set `EnableCalendar = false`
- [ ] Restart EA
- [ ] Check initialization message
- [ ] Verify no calendar restrictions applied

**Expected**:
- [ ] Calendar HUD shows: "Calendar: Disabled"
- [ ] EA trades through news events
- [ ] No time-based restrictions from calendar
- [ ] ffCalenadarEventTime1 = 99999

**Pass Criteria**: Calendar has no effect on trading decisions

### Test 5: Multiple Currency Pairs

**Objective**: Verify currency filtering works correctly

- [ ] Test EA on EURUSD (tracks EUR and USD events)
- [ ] Test EA on GBPJPY (tracks GBP and JPY events)
- [ ] Test EA on XAUUSD (tracks XAU and USD events)

**For each symbol**:
- [ ] Calendar shows only relevant currency events
- [ ] No GBP events shown on EURUSD
- [ ] No EUR events shown on GBPJPY
- [ ] Correct base and quote currency extraction

**Pass Criteria**: Only events for symbol's currencies are tracked

### Test 6: Impact Level Filtering

**Objective**: Verify impact level filters work correctly

**Test A - High Only**:
```
IncludeHigh = true
IncludeMedium = false
IncludeLow = false
IncludeSpeaks = false
```
- [ ] Calendar shows only high-impact economic indicators
- [ ] No speeches shown
- [ ] No medium/low impact events

**Test B - High + Speeches**:
```
IncludeHigh = true
IncludeMedium = false
IncludeLow = false
IncludeSpeaks = true
```
- [ ] Calendar shows high-impact indicators
- [ ] Calendar shows central bank speeches
- [ ] Impact shows [High] or [Speaks]

**Test C - All Levels**:
```
IncludeHigh = true
IncludeMedium = true
IncludeLow = true
IncludeSpeaks = true
```
- [ ] Calendar shows all economic events
- [ ] Multiple events may be tracked
- [ ] Impact levels vary [High], [Medium], [Low], [Speaks]

**Pass Criteria**: Only selected impact levels appear in calendar

### Test 7: Signal D Calendar Integration

**Objective**: Verify Signal D respects calendar conditions

**Setup**:
- [ ] Enable only Signal D:
  ```
  SignalA = false
  SignalB = false
  SignalC = false
  SignalD = true
  ```
- [ ] Set EnableCalendar = true

**Less than 480 minutes after news**:
- [ ] Signal D should not generate entry signals
- [ ] No new positions opened even if market conditions favor entry

**More than 480 minutes after news**:
- [ ] Signal D resumes normal operation
- [ ] Positions can be opened if market conditions met

**Pass Criteria**: Signal D blocked for TrailCalendarMinutes after news

## Performance Testing

### Test 8: One Week Demo Trading

- [ ] Run EA on demo for minimum 7 days
- [ ] Monitor daily with checklist below

**Daily Monitoring Checklist**:
- [ ] EA running (smiley face smiling)
- [ ] Calendar HUD showing current status
- [ ] Check Expert tab for errors (should be none)
- [ ] Verify calendar events match MT5 calendar
- [ ] Confirm trading stops before scheduled news
- [ ] Confirm trading resumes after trail period
- [ ] Check position management logic
- [ ] Review any unusual behavior

**Weekly Summary**:
- [ ] Total trades opened: _______
- [ ] Calendar events detected: _______
- [ ] Times trading was blocked: _______
- [ ] Times positions were closed before news: _______
- [ ] Any errors or warnings: _______
- [ ] Calendar accuracy: _______% (matches MT5 calendar)

### Test 9: Stress Testing

**High-Impact News Week**: Test during week with multiple major events
- [ ] Monday: _______________ (event name)
- [ ] Tuesday: _______________
- [ ] Wednesday: _______________
- [ ] Thursday: _______________
- [ ] Friday: _______________

**Verification**:
- [ ] EA handled all events correctly
- [ ] No positions opened within restricted windows
- [ ] Positions closed before news when profitable
- [ ] Trading resumed after each event's trail period
- [ ] Calendar display updated accurately throughout

## Documentation Review

- [ ] Read through `CALENDAR_INTEGRATION_README.md` completely
- [ ] Understand all configuration parameters
- [ ] Review example scenarios in `CALENDAR_FLOW_DIAGRAM.txt`
- [ ] Understand troubleshooting section
- [ ] Know how to interpret HUD messages

## Live Deployment Prerequisites

**ONLY proceed to live account if ALL of these are checked:**

- [ ] ✅ Successfully compiled with zero errors/warnings
- [ ] ✅ Ran on demo account for minimum 7 days
- [ ] ✅ Calendar events detected correctly
- [ ] ✅ Trading restricted before news events
- [ ] ✅ Trading resumed after news events
- [ ] ✅ HUD display accurate and informative
- [ ] ✅ No errors in Expert tab during testing
- [ ] ✅ Understand all configuration parameters
- [ ] ✅ Tested with different impact level settings
- [ ] ✅ Verified currency filtering works
- [ ] ✅ Signal D calendar integration confirmed
- [ ] ✅ Backup system respects calendar
- [ ] ✅ Position exits before news confirmed
- [ ] ✅ Comfortable with risk management settings
- [ ] ✅ Read all documentation thoroughly

## Live Account Setup

### Configuration Selection

Choose configuration based on your risk tolerance:

**Conservative (Recommended for most traders)**:
```
EnableCalendar = true
IncludeHigh = true
IncludeMedium = true
IncludeLow = false
IncludeSpeaks = true
LeadCalendarMinutes = 360    // 6 hours before
TrailCalendarMinutes = 720   // 12 hours after
MaxTrades = 7
```

**Moderate (Balanced approach)**:
```
EnableCalendar = true
IncludeHigh = true
IncludeMedium = false
IncludeLow = false
IncludeSpeaks = false
LeadCalendarMinutes = 240    // 4 hours before
TrailCalendarMinutes = 480   // 8 hours after
MaxTrades = 7
```

**Aggressive (Minimal restrictions)**:
```
EnableCalendar = true
IncludeHigh = true
IncludeMedium = false
IncludeLow = false
IncludeSpeaks = false
LeadCalendarMinutes = 120    // 2 hours before
TrailCalendarMinutes = 240   // 4 hours after
MaxTrades = 7
```

### Live Deployment Steps

- [ ] Start with smallest account or minimum lot sizes
- [ ] Use Conservative settings initially
- [ ] Monitor closely for first week
- [ ] Keep detailed log of calendar events and EA responses
- [ ] Check Expert tab multiple times daily
- [ ] Verify HUD display matches reality
- [ ] Gradually increase position sizes if performing well
- [ ] Adjust settings based on observed performance

### First Week Live Monitoring

**Daily Checks** (minimum 2x per day):
- [ ] EA running and active
- [ ] Calendar HUD showing accurate information
- [ ] No errors in Expert tab
- [ ] Positions managed correctly
- [ ] Trading stops/starts align with calendar events
- [ ] Account balance trending positively

**Weekly Review**:
- [ ] Total P/L: _____________
- [ ] Calendar events during week: _____________
- [ ] Times blocked from trading: _____________
- [ ] Early exits before news: _____________
- [ ] Performance vs demo: _____________
- [ ] Any issues or concerns: _____________
- [ ] Settings adjustments needed: _____________

## Troubleshooting Quick Reference

### Issue: Calendar shows "No relevant news events" always

**Solutions**:
1. [ ] Check MT5 Economic Calendar has data (Tools → Economic Calendar)
2. [ ] Verify symbol currencies (EURUSD tracks EUR and USD only)
3. [ ] Enable more impact levels (try IncludeHigh = true)
4. [ ] Wait - there may genuinely be no scheduled events

### Issue: EA trading during high-impact news

**Solutions**:
1. [ ] Verify EnableCalendar = true
2. [ ] Check IncludeHigh = true
3. [ ] Verify event currency matches symbol
4. [ ] Check LeadCalendarMinutes setting (should be 240+)
5. [ ] Review Expert tab for calendar initialization

### Issue: EA not resuming trading after news

**Solutions**:
1. [ ] Check calendar HUD for time since event
2. [ ] Verify TrailCalendarMinutes setting
3. [ ] Ensure other trading conditions are met (spread, signals, etc.)
4. [ ] Check if another upcoming event is blocking trades

### Issue: Compilation errors

**Solutions**:
1. [ ] Verify MT5 build is 3802 or higher
2. [ ] Check Trade library is available (#include <Trade\Trade.mqh>)
3. [ ] Ensure file saved with UTF-8 encoding
4. [ ] Review error messages for specific line numbers

## Support Resources

- **Calendar Integration Details**: `CALENDAR_INTEGRATION_README.md`
- **Quick Settings Guide**: `CALENDAR_QUICK_START.md`
- **Flow Diagrams**: `CALENDAR_FLOW_DIAGRAM.txt`
- **Implementation Notes**: `IMPLEMENTATION_SUMMARY.md`
- **Source Code**: `prism.mq5` (fully commented)

## Final Pre-Live Checklist

Before going live with real money, confirm:

- [ ] ✅ I have read all documentation
- [ ] ✅ I understand how calendar integration works
- [ ] ✅ I have tested on demo for minimum 7 days
- [ ] ✅ I have verified calendar event detection
- [ ] ✅ I have observed correct pre-news behavior
- [ ] ✅ I have observed correct post-news behavior
- [ ] ✅ I understand the HUD display
- [ ] ✅ I know which settings to use
- [ ] ✅ I have verified position management
- [ ] ✅ I accept the risks of automated trading
- [ ] ✅ I will monitor the EA daily
- [ ] ✅ I have emergency stop procedures in place

**Date Demo Testing Started**: ________________
**Date Demo Testing Completed**: ________________
**Date Live Deployment**: ________________

**Signature/Acknowledgment**: ____________________________

---

**Remember**: The calendar integration helps avoid volatile news periods, but it does not guarantee profits or eliminate all risks. Always trade responsibly with funds you can afford to lose.

**Good luck with your trading! 🎯**
