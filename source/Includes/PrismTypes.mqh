//+------------------------------------------------------------------+
//|                                                 PrismTypes.mqh  |
//|                                    Common types and structures   |
//+------------------------------------------------------------------+
#property copyright "Rudi & Claude"

//+------------------------------------------------------------------+
//| Structure to hold calendar event data                            |
//+------------------------------------------------------------------+
struct CalendarEvent
{
   datetime eventTime;       // Event time
   string currency;          // Currency code (USD, EUR, etc.)
   string eventName;         // Event description
   ENUM_CALENDAR_EVENT_IMPORTANCE importance;  // Event impact level
   bool isPast;             // True if event already occurred

   void Clear()
   {
      eventTime = 0;
      currency = "";
      eventName = "";
      importance = CALENDAR_IMPORTANCE_NONE;
      isPast = false;
   }
};

//+------------------------------------------------------------------+
//| Market condition flags structure                                 |
//+------------------------------------------------------------------+
struct MarketConditions
{
   bool nearLongPosition;    // Position close to current price (long)
   bool nearShortPosition;   // Position close to current price (short)
   bool rangingMarket;       // Market in range (ADX below threshold)
   bool bullish;             // Bullish signal active
   bool bearish;             // Bearish signal active
   string signalComment;     // Signal that triggered the condition

   void Reset()
   {
      nearLongPosition = false;
      nearShortPosition = false;
      rangingMarket = false;
      bullish = false;
      bearish = false;
      signalComment = "";
   }
};

//+------------------------------------------------------------------+
//| Position statistics structure                                    |
//+------------------------------------------------------------------+
struct PositionStats
{
   int totalTrades;          // Total open positions
   int totalBackupTrades;    // Backup positions count
   double totalProfit;       // Total floating profit
   double totalLoss;         // Total floating loss
   double buyLots;           // Total buy lots
   double sellLots;          // Total sell lots
   int openType;             // Last opened position type (-1=none, 0=buy, 1=sell)

   void Reset()
   {
      totalTrades = 0;
      totalBackupTrades = 0;
      totalProfit = 0;
      totalLoss = 0;
      buyLots = 0;
      sellLots = 0;
      openType = -1;
   }
};

//+------------------------------------------------------------------+
//| Indicator values structure                                        |
//+------------------------------------------------------------------+
struct IndicatorValues
{
   double ATR;               // Average True Range
   double ADXMain;           // ADX main line
   double ADXPlusDI;         // ADX +DI line
   double ADXMinusDI;        // ADX -DI line
   double ADXMainPrev;       // Previous ADX main
   double ADXPlusDIPrev;     // Previous ADX +DI
   double ADXMinusDIPrev;    // Previous ADX -DI
   double MA1Current;        // Fast MA current value
   double MA1Previous;       // Fast MA previous value
   double MA2Current;        // Slow MA current value
   double MA2Previous;       // Slow MA previous value
   double trendStrength;     // Calculated trend strength

   void Reset()
   {
      ATR = 0;
      ADXMain = 0;
      ADXPlusDI = 0;
      ADXMinusDI = 0;
      ADXMainPrev = 0;
      ADXPlusDIPrev = 0;
      ADXMinusDIPrev = 0;
      MA1Current = 0;
      MA1Previous = 0;
      MA2Current = 0;
      MA2Previous = 0;
      trendStrength = 0;
   }
};

//+------------------------------------------------------------------+
//| Calendar data structure                                           |
//+------------------------------------------------------------------+
struct CalendarData
{
   double eventTime1;        // Time to/since event 1 (minutes)
   double eventTime2;        // Time to/since event 2 (minutes)
   string currency1;         // Currency for event 1
   string currency2;         // Currency for event 2
   string text1;             // Event 1 description
   string text2;             // Event 2 description
   int type1;                // Event 1 type (0=since, 1=until, -1=none)
   int type2;                // Event 2 type
   int impact1;              // Event 1 impact level
   int impact2;              // Event 2 impact level
   double hours1;            // Hours component for event 1
   double hours2;            // Hours component for event 2
   double minutes1;          // Minutes component for event 1
   double minutes2;          // Minutes component for event 2

   void Reset()
   {
      eventTime1 = 99999;
      eventTime2 = 99999;
      currency1 = "";
      currency2 = "";
      text1 = "";
      text2 = "";
      type1 = -1;
      type2 = -1;
      impact1 = -1;
      impact2 = -1;
      hours1 = -1;
      hours2 = -1;
      minutes1 = -1;
      minutes2 = -1;
   }
};
