//+------------------------------------------------------------------+
//|                                               PrismSignals.mqh  |
//|                                    Trading signal generation     |
//+------------------------------------------------------------------+
#property copyright "Rudi & Claude"

#include "PrismTypes.mqh"
#include "PrismCalendar.mqh"

//+------------------------------------------------------------------+
//| Check if current hour is within trading hours for signal         |
//+------------------------------------------------------------------+
bool IsWithinTradingHours(int currentHour, int startHour, int endHour)
{
   if(startHour < endHour)
      return (currentHour >= startHour && currentHour < endHour);
   else if(startHour > endHour)
      return ((currentHour <= endHour && currentHour >= 0) ||
              (currentHour <= 23 && currentHour >= startHour));
   return true;
}

//+------------------------------------------------------------------+
//| Signal A: Trend-based using MA crossovers and trend strength     |
//| within specific pip ranges                                       |
//+------------------------------------------------------------------+
void AnalyzeSignalA(MarketConditions &conditions,
                    const IndicatorValues &indicators,
                    bool signalEnabled,
                    int startHour,
                    int endHour,
                    double minTrend,
                    double maxTrend,
                    double trendSpace,
                    double pipPoints)
{
   if(!signalEnabled)
      return;

   MqlDateTime tm;
   TimeCurrent(tm);
   int currentHour = tm.hour;

   if(!IsWithinTradingHours(currentHour, startHour, endHour))
      return;

   double closePrice[];
   ArraySetAsSeries(closePrice, true);
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 1, closePrice) < 1)
      return;

   // Check trend strength within acceptable range
   if(MathAbs(indicators.trendStrength) > minTrend * pipPoints &&
      MathAbs(indicators.trendStrength) < maxTrend * pipPoints &&
      MathAbs(closePrice[0] - indicators.MA1Current) > trendSpace * pipPoints)
   {
      // Bullish signal
      if(indicators.MA1Current < indicators.MA2Current &&
         indicators.MA2Current > indicators.MA2Previous &&
         closePrice[0] < indicators.MA2Current)
      {
         conditions.bullish = true;
         conditions.bearish = false;
         conditions.signalComment = "SignalA";
      }
      // Bearish signal
      else if(indicators.MA1Current > indicators.MA2Current &&
              indicators.MA2Current < indicators.MA2Previous &&
              closePrice[0] > indicators.MA2Current)
      {
         conditions.bearish = true;
         conditions.bullish = false;
         conditions.signalComment = "SignalA";
      }
   }
}

//+------------------------------------------------------------------+
//| Signal B: ADX directional indicator crossover signals            |
//+------------------------------------------------------------------+
void AnalyzeSignalB(MarketConditions &conditions,
                    const IndicatorValues &indicators,
                    bool signalEnabled,
                    int startHour,
                    int endHour,
                    double adxThreshold,
                    double pipPoints)
{
   if(!signalEnabled)
      return;

   MqlDateTime tm;
   TimeCurrent(tm);
   int currentHour = tm.hour;

   if(!IsWithinTradingHours(currentHour, startHour, endHour))
      return;

   double closePrice[];
   ArraySetAsSeries(closePrice, true);
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 1, closePrice) < 1)
      return;

   // Bullish ADX crossover
   if(indicators.MA1Current < indicators.MA2Current &&
      indicators.ADXPlusDI > adxThreshold &&
      indicators.ADXPlusDIPrev < indicators.ADXMinusDI &&
      closePrice[0] < indicators.MA2Current)
   {
      conditions.bullish = true;
      conditions.bearish = false;
      conditions.signalComment = "SignalB";
   }
   // Bearish ADX crossover
   else if(indicators.MA1Current > indicators.MA2Current &&
           indicators.ADXMinusDI > adxThreshold &&
           indicators.ADXMinusDIPrev < indicators.ADXMinusDI &&
           closePrice[0] > indicators.MA2Current)
   {
      conditions.bearish = true;
      conditions.bullish = false;
      conditions.signalComment = "SignalB";
   }
}

//+------------------------------------------------------------------+
//| Signal C: Strong trend detection for counter-trend positions     |
//+------------------------------------------------------------------+
void AnalyzeSignalC(MarketConditions &conditions,
                    const IndicatorValues &indicators,
                    bool signalEnabled,
                    int startHour,
                    int endHour,
                    double maxTrend,
                    double pipPoints)
{
   if(!signalEnabled)
      return;

   MqlDateTime tm;
   TimeCurrent(tm);
   int currentHour = tm.hour;

   if(!IsWithinTradingHours(currentHour, startHour, endHour))
      return;

   // Strong trend counter-signal
   if(MathAbs(indicators.trendStrength) > maxTrend * pipPoints)
   {
      // Counter bearish on strong uptrend
      if(indicators.MA1Current < indicators.MA2Current &&
         indicators.MA2Current > indicators.MA2Previous)
      {
         conditions.bearish = true;
         conditions.bullish = false;
         conditions.signalComment = "SignalC";
      }
      // Counter bullish on strong downtrend
      else if(indicators.MA1Current > indicators.MA2Current &&
              indicators.MA2Current < indicators.MA2Previous)
      {
         conditions.bullish = true;
         conditions.bearish = false;
         conditions.signalComment = "SignalC";
      }
   }
}

//+------------------------------------------------------------------+
//| Signal D: Combined MA momentum and ADX with calendar check       |
//+------------------------------------------------------------------+
void AnalyzeSignalD(MarketConditions &conditions,
                    const IndicatorValues &indicators,
                    const CalendarData &calData,
                    bool signalEnabled,
                    int startHour,
                    int endHour,
                    double minTrend,
                    double maxTrend,
                    double pipPoints,
                    bool enableCalendar,
                    int trailCalendarMinutes)
{
   if(!signalEnabled)
      return;

   MqlDateTime tm;
   TimeCurrent(tm);
   int currentHour = tm.hour;

   if(!IsWithinTradingHours(currentHour, startHour, endHour))
      return;

   // Calendar check: Only trade if enough time passed since news
   bool calendarCondition = (!enableCalendar) ||
      (enableCalendar && calData.eventTime1 > trailCalendarMinutes &&
       GetCalendarTypeString(calData.type1) == "since ");

   if(!calendarCondition)
      return;

   double closePrice[];
   ArraySetAsSeries(closePrice, true);
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 1, closePrice) < 1)
      return;

   // Check trend strength within range
   if(MathAbs(indicators.trendStrength) > minTrend * pipPoints &&
      MathAbs(indicators.trendStrength) < maxTrend * pipPoints)
   {
      // Bullish momentum signal
      if(indicators.MA1Current > indicators.MA1Previous &&
         indicators.MA2Current > indicators.MA1Current &&
         indicators.ADXPlusDI > indicators.ADXMinusDI &&
         closePrice[0] > indicators.MA1Current)
      {
         conditions.bullish = true;
         conditions.bearish = false;
         conditions.signalComment = "SignalD";
      }
      // Bearish momentum signal
      else if(indicators.MA1Current > indicators.MA1Previous &&
              indicators.MA2Current > indicators.MA1Current &&
              indicators.ADXMinusDI > indicators.ADXPlusDI &&
              closePrice[0] < indicators.MA1Current)
      {
         conditions.bullish = false;
         conditions.bearish = true;
         conditions.signalComment = "SignalD";
      }
   }
}

//+------------------------------------------------------------------+
//| Master signal analysis - evaluates all enabled signals           |
//+------------------------------------------------------------------+
void AnalyzeTrendSignals(MarketConditions &conditions,
                         const IndicatorValues &indicators,
                         const CalendarData &calData,
                         // Signal A parameters
                         bool signalAEnabled,
                         int signalAStart,
                         int signalAEnd,
                         double minTrend,
                         double maxTrend,
                         double trendSpace,
                         // Signal B parameters
                         bool signalBEnabled,
                         int signalBStart,
                         int signalBEnd,
                         double adxThreshold,
                         // Signal C parameters
                         bool signalCEnabled,
                         int signalCStart,
                         int signalCEnd,
                         // Signal D parameters
                         bool signalDEnabled,
                         int signalDStart,
                         int signalDEnd,
                         // General parameters
                         double pipPoints,
                         bool enableCalendar,
                         int trailCalendarMinutes)
{
   // Reset conditions
   conditions.bullish = false;
   conditions.bearish = false;
   conditions.rangingMarket = false;

   // Check for ranging market
   if(indicators.ADXMain < adxThreshold)
   {
      conditions.rangingMarket = true;
      return;
   }

   // Evaluate each signal in sequence
   // Note: Last signal to trigger will override previous signals

   AnalyzeSignalA(conditions, indicators, signalAEnabled, signalAStart, signalAEnd,
                  minTrend, maxTrend, trendSpace, pipPoints);

   AnalyzeSignalB(conditions, indicators, signalBEnabled, signalBStart, signalBEnd,
                  adxThreshold, pipPoints);

   AnalyzeSignalC(conditions, indicators, signalCEnabled, signalCStart, signalCEnd,
                  maxTrend, pipPoints);

   AnalyzeSignalD(conditions, indicators, calData, signalDEnabled, signalDStart, signalDEnd,
                  minTrend, maxTrend, pipPoints, enableCalendar, trailCalendarMinutes);
}
