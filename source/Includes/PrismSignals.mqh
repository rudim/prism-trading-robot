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
   return false;
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
                    double pip)
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

   conditions.signalComment = "SignalA";

   // Check trend strength within acceptable range
   if(MathAbs(indicators.trendStrength) > minTrend * pip &&
      MathAbs(indicators.trendStrength) < maxTrend * pip &&
      MathAbs(closePrice[0] - indicators.MA1Current) > trendSpace * pip)
   {
      // Bullish signal
      if(indicators.MA1Current < indicators.MA2Current &&
         indicators.MA2Current > indicators.MA2Previous &&
         closePrice[0] < indicators.MA2Current)
      {
         conditions.bullish = true;
         conditions.bearish = false;
      }
      // Bearish signal
      else if(indicators.MA1Current > indicators.MA2Current &&
              indicators.MA2Current < indicators.MA2Previous &&
              closePrice[0] > indicators.MA2Current)
      {
         conditions.bearish = true;
         conditions.bullish = false;
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
                    double pip)
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

   conditions.signalComment = "SignalB";

   // Bullish ADX crossover
   if(indicators.MA1Current < indicators.MA2Current &&
      indicators.ADXPlusDI > adxThreshold &&
      indicators.ADXPlusDIPrev < indicators.ADXMinusDI &&
      closePrice[0] < indicators.MA2Current)
   {
      conditions.bullish = true;
      conditions.bearish = false;
   }
   // Bearish ADX crossover
   else if(indicators.MA1Current > indicators.MA2Current &&
           indicators.ADXMinusDI > adxThreshold &&
           indicators.ADXMinusDIPrev < indicators.ADXMinusDI &&
           closePrice[0] > indicators.MA2Current)
   {
      conditions.bearish = true;
      conditions.bullish = false;
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
                    double pip)
{
   if(!signalEnabled)
      return;

   MqlDateTime tm;
   TimeCurrent(tm);
   int currentHour = tm.hour;

   if(!IsWithinTradingHours(currentHour, startHour, endHour))
      return;

   conditions.signalComment = "SignalC";

   // Strong trend counter-signal
   if(MathAbs(indicators.trendStrength) > maxTrend * pip)
   {
      // Counter bearish on strong uptrend
      if(indicators.MA1Current < indicators.MA2Current &&
         indicators.MA2Current > indicators.MA2Previous)
      {
         conditions.bearish = true;
         conditions.bullish = false;
      }
      // Counter bullish on strong downtrend
      else if(indicators.MA1Current > indicators.MA2Current &&
              indicators.MA2Current < indicators.MA2Previous)
      {
         conditions.bullish = true;
         conditions.bearish = false;
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
                    double pip,
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

   conditions.signalComment = "SignalD";

   double closePrice[];
   ArraySetAsSeries(closePrice, true);
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 1, closePrice) < 1)
      return;

   // Check trend strength within range
   if(MathAbs(indicators.trendStrength) > minTrend * pip &&
      MathAbs(indicators.trendStrength) < maxTrend * pip)
   {
      // Bullish momentum signal
      if(indicators.MA1Current > indicators.MA1Previous &&
         indicators.MA2Current > indicators.MA1Current &&
         indicators.ADXPlusDI > indicators.ADXMinusDI &&
         closePrice[0] > indicators.MA1Current)
      {
         conditions.bullish = true;
         conditions.bearish = false;
      }
      // Bearish momentum signal
      else if(indicators.MA1Current > indicators.MA1Previous &&
              indicators.MA2Current > indicators.MA1Current &&
              indicators.ADXMinusDI > indicators.ADXPlusDI &&
              closePrice[0] < indicators.MA1Current)
      {
         conditions.bullish = false;
         conditions.bearish = true;
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
                         double pip,
                         bool enableCalendar,
                         int trailCalendarMinutes)
{
   // Reset ranging flag only
   conditions.rangingMarket = false;

   // Check for ranging market
   if(indicators.ADXMain < adxThreshold)
   {
      conditions.rangingMarket = true;
      conditions.bullish = false;
      conditions.bearish = false;
      return;
   }

   // Evaluate each signal in sequence
   // Note: Last signal to trigger will override previous signals

   AnalyzeSignalA(conditions, indicators, signalAEnabled, signalAStart, signalAEnd,
                  minTrend, maxTrend, trendSpace, pip);

   AnalyzeSignalB(conditions, indicators, signalBEnabled, signalBStart, signalBEnd,
                  adxThreshold, pip);

   AnalyzeSignalC(conditions, indicators, signalCEnabled, signalCStart, signalCEnd,
                  maxTrend, pip);

   AnalyzeSignalD(conditions, indicators, calData, signalDEnabled, signalDStart, signalDEnd,
                  minTrend, maxTrend, pip, enableCalendar, trailCalendarMinutes);
}
