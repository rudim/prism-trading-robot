# Calendar Integration - Quick Start Guide

## Basic Setup

### Step 1: Enable Calendar Integration
```
EnableCalendar = true
```

### Step 2: Choose Impact Levels to Track
```
IncludeHigh = true          // Major economic events (NFP, FOMC, GDP)
IncludeMedium = false       // Secondary indicators
IncludeLow = false          // Minor indicators
IncludeSpeaks = true        // Central bank speeches
```

### Step 3: Set Time Windows
```
LeadCalendarMinutes = 240   // Stop trading 4 hours BEFORE news
TrailCalendarMinutes = 480  // Resume trading 8 hours AFTER news
```

## How It Works

### Trading Restrictions

The EA automatically:

1. **STOPS opening new positions** when:
   - High-impact news is less than 4 hours away (LeadCalendarMinutes)
   - Less than 8 hours have passed since last news (TrailCalendarMinutes)

2. **CLOSES profitable positions** when:
   - News is approaching (within LeadCalendarMinutes)
   - Overall positions are in profit

3. **DISPLAYS calendar status** on chart:
   - Shows next upcoming event
   - Shows time until/since event
   - Shows event importance and currency

### On-Chart Display

```
⚠ NEWS IN 2h 15m - USD [High] FOMC Rate Decision - WAITING/EXIT
```
- ⚠ = Warning symbol (news approaching)
- Time = Hours and minutes until event
- Currency = Affected currency (USD, EUR, etc.)
- Impact = [High], [Medium], [Low], or [Speaks]
- Status = Current trading state

## Recommended Settings

### Conservative (Safest)
Avoid all major news events with wide time buffers.
```
EnableCalendar = true
IncludeHigh = true
IncludeMedium = true
IncludeLow = false
IncludeSpeaks = true
LeadCalendarMinutes = 360    // Stop 6 hours before
TrailCalendarMinutes = 720   // Resume 12 hours after
```

### Moderate (Balanced)
Avoid only high-impact news with standard time buffers.
```
EnableCalendar = true
IncludeHigh = true
IncludeMedium = false
IncludeLow = false
IncludeSpeaks = false
LeadCalendarMinutes = 240    // Stop 4 hours before
TrailCalendarMinutes = 480   // Resume 8 hours after
```

### Aggressive (Minimal Restrictions)
Avoid only critical news with short time buffers.
```
EnableCalendar = true
IncludeHigh = true
IncludeMedium = false
IncludeLow = false
IncludeSpeaks = false
LeadCalendarMinutes = 120    // Stop 2 hours before
TrailCalendarMinutes = 240   // Resume 4 hours after
```

### Disabled (Original Behavior)
Trade through all news events.
```
EnableCalendar = false
```

## Understanding Impact Levels

### High Impact
**Major market-moving events that often cause 50-200+ pip moves:**
- Non-Farm Payrolls (NFP)
- Federal Reserve (FOMC) Rate Decisions
- European Central Bank (ECB) Rate Decisions
- Gross Domestic Product (GDP)
- Consumer Price Index (CPI)
- Retail Sales
- Unemployment Rate

**Recommendation**: Always include (IncludeHigh = true)

### Medium Impact
**Secondary indicators that can cause 20-50 pip moves:**
- Manufacturing PMI
- Services PMI
- Consumer Confidence
- Trade Balance
- Housing Starts
- Industrial Production

**Recommendation**: Include for conservative approach, exclude for aggressive

### Low Impact
**Minor indicators with minimal market impact (<20 pips):**
- Building Permits
- Business Inventories
- Factory Orders
- Various regional data

**Recommendation**: Usually safe to exclude (IncludeLow = false)

### Speaks
**Central bank officials speaking or testifying:**
- Fed Chair Powell speeches
- ECB President speeches
- FOMC member testimony
- Central bank press conferences

**Recommendation**: Include major officials (IncludeSpeaks = true)

## Verification Checklist

After enabling calendar integration:

- [ ] Check MT5 Economic Calendar (Tools → Economic Calendar)
- [ ] Verify events are showing in MT5 calendar
- [ ] Confirm EA initialization message shows calendar active
- [ ] Check on-chart display shows calendar status
- [ ] Verify EA stops trading before scheduled high-impact news
- [ ] Confirm EA resumes after TrailCalendarMinutes has passed
- [ ] Test on demo account for at least one week

## Monitoring

### What to Watch

1. **HUD Display**: Check the calendar status line on chart
2. **Expert Log**: Look for calendar-related messages:
   - "Calendar Integration Active - MT5 Native API"
   - "Calendar exit triggered: Upcoming news event"
3. **Trading Activity**: Verify pauses before/after major news
4. **Position Closes**: Confirm profitable exits before news

### Expected Behavior

**5+ hours before news**: Normal trading
**4 hours before news**: Stop opening new positions
**2 hours before news**: Close profitable positions
**At news time**: No trading activity
**4 hours after news**: Still no trading
**8 hours after news**: Resume normal trading

## Troubleshooting

### EA Not Stopping Before News

**Possible causes:**
1. EnableCalendar = false → Set to true
2. Event importance doesn't match filters → Check IncludeHigh/Medium/Low
3. LeadCalendarMinutes too low → Increase to 240+ minutes
4. Wrong currency → Verify symbol currencies match event currency

**Solution:**
```
EnableCalendar = true
IncludeHigh = true
LeadCalendarMinutes = 240
```

### Calendar Shows "No relevant news events"

**Possible causes:**
1. No events scheduled in next 48 hours for symbol currencies
2. All events filtered out by impact settings
3. MT5 calendar database not updated

**Solution:**
1. Check MT5 calendar manually (Tools → Economic Calendar)
2. Try enabling all impact levels temporarily
3. Wait for MT5 calendar to update (automatic)

### EA Trading During News

**Possible causes:**
1. Calendar disabled → EnableCalendar = false
2. Event not matching filter criteria
3. Time window expired (outside Lead/Trail minutes)

**Solution:**
Review settings and check on-chart display for calendar status.

## Key Points to Remember

1. **Calendar integration uses MT5's built-in economic calendar** - no external feeds required

2. **Only tracks currencies in your trading symbol** - EURUSD tracks EUR and USD news only

3. **Automatic time zone handling** - all times are in broker server time

4. **Graceful degradation** - if calendar data unavailable, EA trades normally

5. **Real-time updates** - calendar checked on every tick, data refreshes automatically

6. **Multiple trading signals** - only Signal D uses calendar for entry, but all respect news restrictions

## Support

For detailed information, see:
- `CALENDAR_INTEGRATION_README.md` - Complete documentation
- `milestone-20.5.mq5` - Source code with comments
- MT5 Economic Calendar - Tools → Economic Calendar

---

**Quick Tip**: Start with Moderate settings and adjust based on your risk tolerance and trading style.
