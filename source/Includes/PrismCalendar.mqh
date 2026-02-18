//+------------------------------------------------------------------+
//|                                              PrismCalendar.mqh  |
//|                              Economic calendar integration       |
//+------------------------------------------------------------------+
#property copyright "Rudi & Claude"

#include "PrismTypes.mqh"

//+------------------------------------------------------------------+
//| Get currency codes relevant to current symbol                    |
//+------------------------------------------------------------------+
void GetSymbolCurrencies(string& baseCurrency, string& quoteCurrency)
{
   string symbolName = _Symbol;
   int len = StringLen(symbolName);

   if(len >= 6)
   {
      baseCurrency = StringSubstr(symbolName, 0, 3);
      quoteCurrency = StringSubstr(symbolName, 3, 3);
   }
   else
   {
      baseCurrency = "";
      quoteCurrency = "";
   }
}

//+------------------------------------------------------------------+
//| Check if event importance matches filter settings                |
//+------------------------------------------------------------------+
bool IsEventImportanceIncluded(ENUM_CALENDAR_EVENT_IMPORTANCE importance,
                               bool includeHigh, bool includeMedium, bool includeLow)
{
   switch(importance)
   {
      case CALENDAR_IMPORTANCE_HIGH:
         return includeHigh;
      case CALENDAR_IMPORTANCE_MODERATE:
         return includeMedium;
      case CALENDAR_IMPORTANCE_LOW:
         return includeLow;
      default:
         return false;
   }
}

//+------------------------------------------------------------------+
//| Check if event name indicates a speech/speaking event            |
//+------------------------------------------------------------------+
bool IsSpeakingEvent(string eventName)
{
   string lowerName = eventName;
   StringToLower(lowerName);

   if(StringFind(lowerName, "speech") >= 0 ||
      StringFind(lowerName, "speak") >= 0 ||
      StringFind(lowerName, "testimony") >= 0 ||
      StringFind(lowerName, "statement") >= 0 ||
      StringFind(lowerName, "conference") >= 0 ||
      StringFind(lowerName, "press") >= 0)
   {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Get impact level as integer (0=High, 1=Medium, 2=Low, 3=Speaks)  |
//+------------------------------------------------------------------+
int GetImpactLevel(ENUM_CALENDAR_EVENT_IMPORTANCE importance, bool isSpeech, bool includeSpeaks)
{
   if(isSpeech && includeSpeaks)
      return 3;

   switch(importance)
   {
      case CALENDAR_IMPORTANCE_HIGH:
         return 0;
      case CALENDAR_IMPORTANCE_MODERATE:
         return 1;
      case CALENDAR_IMPORTANCE_LOW:
         return 2;
      default:
         return -1;
   }
}

//+------------------------------------------------------------------+
//| Get calendar type string for display                             |
//+------------------------------------------------------------------+
string GetCalendarTypeString(int eventType)
{
   if(eventType == 0)
      return "since ";
   else if(eventType == 1)
      return "until ";
   return "";
}

//+------------------------------------------------------------------+
//| Prepare calendar data using MT5 native API                       |
//+------------------------------------------------------------------+
void PrepareCalendar(CalendarData &calData,
                     bool enableCalendar,
                     bool includeHigh,
                     bool includeMedium,
                     bool includeLow,
                     bool includeSpeaks)
{
   // If calendar disabled, set safe defaults
   if(!enableCalendar)
   {
      calData.Reset();
      return;
   }

   // Get currencies for current symbol
   string baseCurrency, quoteCurrency;
   GetSymbolCurrencies(baseCurrency, quoteCurrency);

   // Time range: 24 hours back and 48 hours forward
   datetime currentTime = TimeCurrent();
   datetime startTime = currentTime - (24 * 3600);
   datetime endTime = currentTime + (48 * 3600);

   // Get calendar events
   MqlCalendarValue values[];
   int valueCount = CalendarValueHistory(values, startTime, endTime);

   if(valueCount <= 0)
   {
      calData.Reset();
      return;
   }

   // Arrays to store relevant events
   CalendarEvent upcomingEvents[];
   CalendarEvent pastEvents[];
   ArrayResize(upcomingEvents, 0);
   ArrayResize(pastEvents, 0);

   // Process each calendar value
   for(int i = 0; i < valueCount; i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event))
         continue;

      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country))
         continue;

      string eventCurrency = country.currency;

      // Check if event currency matches our symbol
      if(eventCurrency != baseCurrency && eventCurrency != quoteCurrency)
         continue;

      // Check if event is a speech
      bool isSpeech = IsSpeakingEvent(event.name);

      // Check if we should include this event
      bool includeEvent = false;
      if(isSpeech && includeSpeaks)
         includeEvent = true;
      else if(IsEventImportanceIncluded(event.importance, includeHigh, includeMedium, includeLow))
         includeEvent = true;

      if(!includeEvent)
         continue;

      // Create calendar event entry
      CalendarEvent calEvent;
      calEvent.eventTime = values[i].time;
      calEvent.currency = eventCurrency;
      calEvent.eventName = event.name;
      calEvent.importance = event.importance;
      calEvent.isPast = (values[i].time < currentTime);

      // Add to appropriate array
      if(calEvent.isPast)
      {
         int size = ArraySize(pastEvents);
         ArrayResize(pastEvents, size + 1);
         pastEvents[size] = calEvent;
      }
      else
      {
         int size = ArraySize(upcomingEvents);
         ArrayResize(upcomingEvents, size + 1);
         upcomingEvents[size] = calEvent;
      }
   }

   // Find most recent past event
   CalendarEvent mostRecentPast;
   mostRecentPast.Clear();
   datetime closestPastTime = 0;

   for(int i = 0; i < ArraySize(pastEvents); i++)
   {
      if(pastEvents[i].eventTime > closestPastTime)
      {
         closestPastTime = pastEvents[i].eventTime;
         mostRecentPast = pastEvents[i];
      }
   }

   // Find next upcoming event
   CalendarEvent nextUpcoming;
   nextUpcoming.Clear();
   datetime closestFutureTime = D'2099.12.31 23:59:59';

   for(int i = 0; i < ArraySize(upcomingEvents); i++)
   {
      if(upcomingEvents[i].eventTime < closestFutureTime)
      {
         closestFutureTime = upcomingEvents[i].eventTime;
         nextUpcoming = upcomingEvents[i];
      }
   }

   // Populate data for Event 1 (most recent past event)
   if(mostRecentPast.eventTime > 0)
   {
      calData.currency1 = mostRecentPast.currency;
      calData.text1 = mostRecentPast.eventName;
      calData.type1 = 0;  // "since"

      bool isSpeech1 = IsSpeakingEvent(mostRecentPast.eventName);
      calData.impact1 = GetImpactLevel(mostRecentPast.importance, isSpeech1, includeSpeaks);

      long secondsSince = currentTime - mostRecentPast.eventTime;
      long minutesSince = secondsSince / 60;
      calData.hours1 = (double)(minutesSince / 60);
      calData.minutes1 = (double)(minutesSince % 60);
      calData.eventTime1 = (double)minutesSince;
   }
   else
   {
      calData.currency1 = "";
      calData.text1 = "";
      calData.type1 = -1;
      calData.impact1 = -1;
      calData.hours1 = -1;
      calData.minutes1 = -1;
      calData.eventTime1 = 99999;
   }

   // Populate data for Event 2 (next upcoming event)
   if(nextUpcoming.eventTime > 0 && nextUpcoming.eventTime < closestFutureTime)
   {
      calData.currency2 = nextUpcoming.currency;
      calData.text2 = nextUpcoming.eventName;
      calData.type2 = 1;  // "until"

      bool isSpeech2 = IsSpeakingEvent(nextUpcoming.eventName);
      calData.impact2 = GetImpactLevel(nextUpcoming.importance, isSpeech2, includeSpeaks);

      long secondsUntil = nextUpcoming.eventTime - currentTime;
      long minutesUntil = secondsUntil / 60;
      calData.hours2 = (double)(minutesUntil / 60);
      calData.minutes2 = (double)(minutesUntil % 60);
      calData.eventTime2 = (double)minutesUntil;

      // Override Event 1 to use upcoming event for trading decisions
      calData.eventTime1 = (double)minutesUntil;
      calData.type1 = 1;  // "until"
   }
   else
   {
      calData.currency2 = "";
      calData.text2 = "";
      calData.type2 = -1;
      calData.impact2 = -1;
      calData.hours2 = -1;
      calData.minutes2 = -1;
      calData.eventTime2 = 99999;
   }
}
