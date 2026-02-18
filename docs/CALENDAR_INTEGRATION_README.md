# Prism MT5 - Calendar Integration Documentation

## Overview

The Prism now includes full integration with MT5's native economic calendar API. This replaces the MT4 version's dependency on the custom `prism_calendar` indicator that parsed ForexFactory feeds.

## Implementation Details

### Core Components

#### 1. Calendar Data Structure
```mql5
struct CalendarEvent
{
   datetime eventTime;       // Event time
   string currency;          // Currency code (USD, EUR, etc.)
   string eventName;         // Event description
   ENUM_CALENDAR_EVENT_IMPORTANCE importance;  // Event impact level
   bool isPast;             // True if event already occurred
};
```

#### 2. Main Function: `prepareCalendar()`

This function is called on every tick to fetch and process economic calendar events.

**Process Flow:**
1. **Time Range Setup**: Searches 24 hours back and 48 hours forward from current time
2. **Event Fetching**: Uses `CalendarValueHistory()` to get all scheduled events
3. **Currency Filtering**: Extracts base and quote currencies from symbol (e.g., EURUSD → EUR, USD)
4. **Impact Filtering**: Applies user-defined filters (High, Medium, Low, Speaks)
5. **Event Categorization**: Separates events into past and upcoming
6. **Event Selection**: Identifies most recent past event and next upcoming event
7. **Data Population**: Fills calendar struct for trading logic

### Key Variables Populated

#### Primary Event Data (Event 1)
- `ffCalenadarEventTime1` - Minutes until/since the primary event
- `calendar.currency1` - Currency code (USD, EUR, GBP, etc.)
- `calendar.text1` - Event description
- `calendar.type1` - 0 = "since", 1 = "until"
- `calendar.impact1` - 0=High, 1=Medium, 2=Low, 3=Speaks
- `calendar.hours1` / `calendar.minutes1` - Time breakdown

#### Secondary Event Data (Event 2)
- `ffCalenadarEventTime2` - Minutes until/since the secondary event
- Similar structure to Event 1 variables

### MT5 Calendar API Functions Used

1. **CalendarValueHistory(values[], startTime, endTime)**
   - Fetches all calendar events in the specified time range
   - Returns array of `MqlCalendarValue` structures

2. **CalendarEventById(eventId, event)**
   - Gets detailed event information including name and importance
   - Returns `MqlCalendarEvent` structure

3. **CalendarCountryById(countryId, country)**
   - Gets country details including currency code
   - Returns `MqlCalendarCountry` structure

## Configuration Parameters

### Input Settings

```mql5
input bool EnableCalendar = false;       // Enable calendar-based trading restrictions
input bool IncludeHigh = true;          // Include high-impact news events
input bool IncludeMedium = false;       // Include medium-impact news events
input bool IncludeLow = false;          // Include low-impact news events
input bool IncludeSpeaks = true;        // Include central bank speeches
input int LeadCalendarMinutes = 240;    // Stop trading 4 hours before news
input int TrailCalendarMinutes = 480;   // Resume 8 hours after news
```

### Impact Level Definitions

- **High Impact** (0): Major economic indicators, central bank rate decisions, NFP, GDP
- **Medium Impact** (1): Secondary indicators, retail sales, housing data
- **Low Impact** (2): Minor indicators, less market-moving data
- **Speaks** (3): Central bank official speeches, testimony, press conferences

### Speech Detection

The system identifies speaking events by searching for keywords in event names:
- "speech"
- "speak"
- "testimony"
- "statement"
- "conference"
- "press"

## Trading Logic Integration

### Signal Generation

Calendar integration affects Signal D in `prepareTrend()`:

```mql5
bool calendarCondition = (!EnableCalendar) ||
   (EnableCalendar && ffCalenadarEventTime1 > TrailCalendarMinutes &&
    getCalendarType1() == "since ");
```

Signal D only activates when:
- Calendar is disabled, OR
- Enough time (480 minutes default) has passed since the last news event

### Position Opening

The `openPosition()` function checks calendar conditions before opening trades:

```mql5
if(EnableCalendar)
{
   string calType = getCalendarType1();

   if(ffCalenadarEventTime1 > TrailCalendarMinutes && calType == "since ")
      sendOpen();  // Enough time passed since news
   else if(ffCalenadarEventTime1 > LeadCalendarMinutes && calType == "until ")
      sendOpen();  // Enough time before upcoming news
   else if(ffCalenadarEventTime1 >= 99999)
      sendOpen();  // No news scheduled
}
```

### Backup System

The `backSystem()` applies the same calendar restrictions to backup trades.

### Position Management

Calendar-based exit in `managePositions()`:

```mql5
else if(EnableCalendar && totalTrades > 0 && totalProfit + totalLoss > 0 &&
        ffCalenadarEventTime1 < LeadCalendarMinutes &&
        getCalendarType1() == "until " && ffCalenadarEventTime1 > 0)
{
   Print("Calendar exit triggered: Upcoming news event");
   closeAll();
}
```

Closes profitable positions when:
- News event is approaching (less than 240 minutes away)
- Overall positions are in profit

## HUD Display

The on-chart display shows real-time calendar status:

### Display States

1. **No Events**
   ```
   Calendar: No relevant news events
   ```

2. **Upcoming Event (Safe)**
   ```
   Calendar: 5h 30m until USD [High] Non-Farm Payrolls
   ```

3. **Upcoming Event (Warning)**
   ```
   ⚠ NEWS IN 2h 15m - USD [High] FOMC Rate Decision - WAITING/EXIT
   ```

4. **Past Event (Caution)**
   ```
   ⏳ 1h 30m since USD [High] CPI - CAUTION
   ```

5. **Past Event (Safe)**
   ```
   Calendar: 9h 45m since EUR [Medium] - Trading normal
   ```

6. **Calendar Disabled**
   ```
   Calendar: Disabled
   ```

## Usage Examples

### Conservative Setup (Avoid Major News)
```mql5
EnableCalendar = true;
IncludeHigh = true;
IncludeMedium = true;
IncludeLow = false;
IncludeSpeaks = true;
LeadCalendarMinutes = 360;    // Stop 6 hours before
TrailCalendarMinutes = 720;   // Resume 12 hours after
```

### Moderate Setup (High Impact Only)
```mql5
EnableCalendar = true;
IncludeHigh = true;
IncludeMedium = false;
IncludeLow = false;
IncludeSpeaks = false;
LeadCalendarMinutes = 240;    // Stop 4 hours before
TrailCalendarMinutes = 480;   // Resume 8 hours after
```

### Aggressive Setup (Trade Through Most News)
```mql5
EnableCalendar = true;
IncludeHigh = true;
IncludeMedium = false;
IncludeLow = false;
IncludeSpeaks = false;
LeadCalendarMinutes = 120;    // Stop 2 hours before
TrailCalendarMinutes = 240;   // Resume 4 hours after
```

### Disabled (Original EA Behavior)
```mql5
EnableCalendar = false;
```

## Technical Notes

### Currency Extraction

The system automatically extracts currency pairs from the symbol name:
- EURUSD → Base: EUR, Quote: USD
- GBPJPY → Base: GBP, Quote: JPY
- XAUUSD → Base: XAU, Quote: USD

Only events for these currencies are tracked.

### Time Zones

All times are in broker server time (MT5 TimeCurrent()). The calendar API automatically handles time zone conversions.

### Performance

Calendar data is fetched on every tick via `prepareCalendar()`. The query is efficient:
- 72-hour window (24 hours back, 48 hours forward)
- Filtered by currency and impact level
- Results cached within the tick execution

For high-frequency strategies, consider implementing a caching mechanism to refresh calendar data only once per minute.

### Error Handling

The implementation gracefully handles:
- No calendar data available
- No events matching filter criteria
- Invalid currency codes
- MT5 calendar database not initialized

In all error cases, it defaults to safe behavior (allows trading as if calendar is disabled for that tick).

## Comparison with MT4 Version

### MT4 Implementation
- Custom indicator `prism_calendar`
- Parsed ForexFactory XML feed
- Created chart objects with event data
- EA read data from chart objects

### MT5 Implementation
- Native MT5 Calendar API
- Direct database queries
- No external dependencies
- No custom indicator required
- More reliable and faster

### Advantages of MT5 Approach
1. **Official Data**: Uses MT5's built-in economic calendar
2. **No Web Scraping**: No dependency on external feeds
3. **Better Performance**: Direct API calls, no indicator overhead
4. **More Reliable**: No parsing errors or feed availability issues
5. **Automatic Updates**: Calendar data updated by MetaQuotes

## Troubleshooting

### Calendar Not Working

1. **Check MT5 Economic Calendar**: Open Tools → Economic Calendar in MT5
2. **Verify Data**: Ensure events are showing in the MT5 calendar
3. **Enable in Settings**: Confirm EnableCalendar = true
4. **Check Filters**: Verify at least one impact level is enabled
5. **Review Logs**: Check Expert tab for calendar initialization messages

### No Events Detected

- Symbol currencies may not have upcoming events in 48-hour window
- Filter settings may be too restrictive
- Try enabling more impact levels temporarily

### Trading Not Stopping Before News

- Check LeadCalendarMinutes setting (default 240 minutes = 4 hours)
- Verify the event importance matches your filter settings
- Confirm the currency matches your symbol (EUR in EURUSD, etc.)

## Testing Recommendations

1. **Demo Account**: Always test calendar integration on demo first
2. **Verify Events**: Compare EA's detected events with MT5 calendar
3. **Test Before News**: Monitor behavior 5-6 hours before high-impact news
4. **Test After News**: Verify resumption of trading after TrailCalendarMinutes
5. **Check HUD**: Confirm event details display correctly
6. **Multiple Symbols**: Test on different currency pairs
7. **Impact Levels**: Test with different filter combinations

## Future Enhancements

Potential improvements for future versions:

1. **Event Caching**: Refresh calendar data only once per minute instead of every tick
2. **Multiple Events**: Track more than two events simultaneously
3. **Event Actual vs Forecast**: Use actual vs forecast deviation to gauge market impact
4. **Symbol-Specific Settings**: Different calendar settings per currency pair
5. **Event History**: Log calendar events and their market impact for analysis
6. **Custom Event Filtering**: Allow filtering by specific event names or types

## Support

For issues or questions about calendar integration:
1. Review this documentation
2. Check the Expert tab logs for error messages
3. Verify MT5 economic calendar is functioning
4. Test with EnableCalendar = false to isolate issues

---

**Version**: 20.5
**Last Updated**: 2026-02-14
**MT5 Build**: Compatible with MT5 build 3802+
