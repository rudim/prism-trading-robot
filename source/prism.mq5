//+------------------------------------------------------------------+
//|                                                       prism.mq5  |
//|                                              Prism Trading EA    |
//|                         Modular architecture with include files  |
//+------------------------------------------------------------------+
#property copyright "Rudi & Claude"
#property link      ""
#property description "Prism Trading EA"
#property description "Modular architecture with include files"

//+------------------------------------------------------------------+
//| Include MT5 trading libraries                                    |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| Include Prism modules                                            |
//+------------------------------------------------------------------+
#include "Includes\\PrismTypes.mqh"
#include "Includes\\PrismCalendar.mqh"
#include "Includes\\PrismSignals.mqh"
#include "Includes\\PrismIndicators.mqh"
#include "Includes\\PrismPositions.mqh"

//+------------------------------------------------------------------+
//| Trading objects                                                  |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo positionInfo;
COrderInfo orderInfo;
CSymbolInfo symbolInfo;
CAccountInfo accountInfo;

//+------------------------------------------------------------------+
//| EA identification                                                |
//+------------------------------------------------------------------+
string version = "Prism";
int MAGIC = 20131130;

//+------------------------------------------------------------------+
//|                    INPUT PARAMETERS                              |
//+------------------------------------------------------------------+

//═══════════════════════════════════════════════════════════════════
//  GENERAL CONTROLS
//═══════════════════════════════════════════════════════════════════
input group "════════ GENERAL CONTROLS ════════";
input bool CloseAll = false;              // Close all positions immediately on next tick
input bool ContinueTrading = true;        // Allow opening new positions after initial trades

//═══════════════════════════════════════════════════════════════════
//  NEWS & ECONOMIC CALENDAR
//═══════════════════════════════════════════════════════════════════
input group "════════ NEWS & CALENDAR ════════";
input bool EnableCalendar = false;        // Enable economic calendar trading restrictions
input bool IncludeHigh = true;            // Monitor high-impact news events (NFP, CPI, FOMC)
input bool IncludeMedium = false;         // Monitor medium-impact news events
input bool IncludeLow = false;            // Monitor low-impact news events
input bool IncludeSpeaks = true;          // Monitor central bank speeches and testimonies
input int LeadCalendarMinutes = 240;      // Stop trading X minutes before scheduled news event
input int TrailCalendarMinutes = 480;     // Resume trading X minutes after news event completion

//═══════════════════════════════════════════════════════════════════
//  RISK MANAGEMENT
//═══════════════════════════════════════════════════════════════════
input group "════════ RISK MANAGEMENT ════════";
input double MarginUsage = 0.1;           // Percentage of balance allocated to regular trades (10% = conservative)
input double BackupMargin = 0.01;         // Percentage of balance allocated to backup trades (1% = very conservative)
input double MinMarginLevel = 300;        // Minimum margin level required to open new positions (300% = safe)
input double MinLots = 0.03;              // Minimum lot size for any trade
input bool EnableStop = false;            // Enable long-term stop loss based on historical profits
input double RelativeStop = 0.3;          // Stop loss as percentage of historical profit (30% drawdown limit)
input double StopGrowth = 0.005;          // Historical profit threshold to activate stop loss (0.5% of balance)

//═══════════════════════════════════════════════════════════════════
//  TRADE MANAGEMENT
//═══════════════════════════════════════════════════════════════════
input group "════════ TRADE MANAGEMENT ════════";
input int MaxTrades = 7;                  // Maximum number of positions per basket (includes regular + backup)
input double TradeSpace = 7.5;            // Minimum distance between trades in ATR units (prevents clustering)
input int SleepSeconds = 14400;           // Minimum seconds between any trades (14400 = 4 hours)
input bool TradeFriday = false;           // Allow trading on Fridays (typically avoided due to weekend risk)
input bool SafeSpread = true;             // Only trade when spread is below MaxSpread threshold
input double MaxSpread = 2;               // Maximum spread in pips allowed for trade execution

//═══════════════════════════════════════════════════════════════════
//  PROFIT TARGETS
//═══════════════════════════════════════════════════════════════════
input group "════════ PROFIT TARGETS ════════";
input double BasketProfit = 1.1;          // Profit multiplier for basket closure (1.1 = 110% of historical loss)
input double OpenProfit = 0.005;          // Close all positions when total profit exceeds this % of balance
input double MinProfit = 0.007;           // Minimum profit per position for individual exits (0.7% of balance)
input double SafeProfit = 0.005;          // Profit threshold for safe exits on trend reversal (0.5% of balance)
input double DailyGrowth = 0.015;         // Daily profit target (1.5% of balance = aggressive growth)
input bool SafeGrowth = true;             // Stop trading when daily growth target is reached
input bool SafeExits = true;              // Exit positions when trend reverses against open positions
input int RefreshHours = 24;              // Hours between daily profit resets and statistics refresh

//═══════════════════════════════════════════════════════════════════
//  BACKUP SYSTEM (Drawdown Recovery)
//═══════════════════════════════════════════════════════════════════
input group "════════ BACKUP SYSTEM ════════";
input double TriggerBackSystem = 0.999;   // Equity ratio trigger for backup trades (0.999 = 0.1% drawdown)
input double CandleSpike = 5;             // Spike multiplier for backup entry (current candle vs previous)
input bool Aggressive = false;            // Use aggressive backup mode (trend-following vs spike detection)
input bool AllowHedge = false;            // Allow backup trades in opposite direction of main positions

//═══════════════════════════════════════════════════════════════════
//  SIGNAL A: Trend Following with MA Crossover
//═══════════════════════════════════════════════════════════════════
input group "════════ SIGNAL A: TREND FOLLOWING ════════";
input bool SignalA = true;                // Enable Signal A (MA crossover with trend strength filter)
input int SignalAStartHour = 0;           // Trading start hour for Signal A (24-hour format)
input int SignalAEndHour = 23;            // Trading end hour for Signal A (23 = trade until 11 PM)
input double TrendSpace = 15;             // Minimum distance from MA to confirm trend (in pips)
input double MinTrend = 1;                // Minimum trend strength in pips (filters weak trends)
input double MaxTrend = 5;                // Maximum trend strength in pips (filters over-extended moves)

//═══════════════════════════════════════════════════════════════════
//  SIGNAL B: ADX Crossover
//═══════════════════════════════════════════════════════════════════
input group "════════ SIGNAL B: ADX CROSSOVER ════════";
input bool SignalB = true;                // Enable Signal B (ADX directional indicator crossover)
input int SignalBStartHour = 0;           // Trading start hour for Signal B
input int SignalBEndHour = 23;            // Trading end hour for Signal B

//═══════════════════════════════════════════════════════════════════
//  SIGNAL C: Counter-Trend on Strong Moves
//═══════════════════════════════════════════════════════════════════
input group "════════ SIGNAL C: COUNTER-TREND ════════";
input bool SignalC = true;                // Enable Signal C (counter-trend entries on extreme moves)
input int SignalCStartHour = 0;           // Trading start hour for Signal C
input int SignalCEndHour = 23;            // Trading end hour for Signal C

//═══════════════════════════════════════════════════════════════════
//  SIGNAL D: MA Momentum + ADX with Calendar Filter
//═══════════════════════════════════════════════════════════════════
input group "════════ SIGNAL D: MOMENTUM ════════";
input bool SignalD = true;                // Enable Signal D (combined MA momentum and ADX with news filter)
input int SignalDStartHour = 0;           // Trading start hour for Signal D
input int SignalDEndHour = 23;            // Trading end hour for Signal D

//═══════════════════════════════════════════════════════════════════
//  INDICATOR SETTINGS: ATR (Volatility)
//═══════════════════════════════════════════════════════════════════
input group "════════ INDICATOR: ATR ════════";
input int ATRPeriod = 14;                 // ATR calculation period (14 = standard setting)

//═══════════════════════════════════════════════════════════════════
//  INDICATOR SETTINGS: ADX (Trend Strength)
//═══════════════════════════════════════════════════════════════════
input group "════════ INDICATOR: ADX ════════";
input double ADXMain = 16;                // ADX threshold for trending market (below = ranging, above = trending)
input int ADXPeriod = 14;                 // ADX calculation period (14 = standard setting)
input int ADXShiftCheck = 1;              // Number of bars to check for ADX crossover confirmation

//═══════════════════════════════════════════════════════════════════
//  INDICATOR SETTINGS: Moving Averages
//═══════════════════════════════════════════════════════════════════
input group "════════ INDICATOR: MOVING AVERAGES ════════";
input int MA1Period = 90;                 // Fast MA period (shorter = more responsive to price changes)
input int MA2Period = 30;                 // Slow MA period (longer = smoother, less noise)
input int MAShiftCheck = 10;              // Number of bars to check for MA trend confirmation

//═══════════════════════════════════════════════════════════════════
//  HISTORY & STATISTICS
//═══════════════════════════════════════════════════════════════════
input group "════════ HISTORY & STATISTICS ════════";
input int QueryHistory = 14;              // Number of historical trades to analyze for basket calculations

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
// Core structures
IndicatorHandles indicatorHandles;
IndicatorValues indicators;
MarketConditions market;
PositionStats positions;
CalendarData calendar;

// Trading state
datetime lastTradeTime = 0;
int basketNumber = 0;
int basketNumberType = -1;
int basketCount = -1;

// Daily tracking
double dailyGrowth = 0;
double maxEquity = 0;
int dailyTargets = 0;
int totalDays = 0;
int turn = 0;

// Calculated values
double slippage = 0;
double marginRequirement = 0;
double lotSize = 0;
double backupLotSize = 0;
double totalHistoryProfit = 0;
double marginLevel = 0;
double spread = 0;
double pipPoints = 0.00010;
int symbolHistory = 0;

// Constants
const double DynamicSlippage = 1;
const double BaseLotSize = 0.01;
const int ATRShift = 0;
const int ADXShift = 0;
const int MAShift = 0;
const int MMAShift = 0;

// Display
string display = "\n";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize symbol information
   symbolInfo.Name(_Symbol);
   symbolInfo.RefreshRates();

   // Set trade parameters
   trade.SetExpertMagicNumber(MAGIC);
   trade.SetDeviationInPoints((int)slippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);

   // Initialize indicators
   if(!InitializeIndicators(indicatorHandles, ATRPeriod, ADXPeriod, MA1Period, MA2Period, MMAShift))
   {
      return INIT_FAILED;
   }

   // Print calendar status
   if(EnableCalendar)
   {
      Print("╔════════════════════════════════════════════════════════════╗");
      Print("║ Economic Calendar Active - MT5 Native API                ║");
      Print("╠════════════════════════════════════════════════════════════╣");
      Print("║ High Impact: ", IncludeHigh ? "YES" : "NO", " | Medium: ", IncludeMedium ? "YES" : "NO", " | Low: ", IncludeLow ? "YES" : "NO", "       ║");
      Print("║ Speeches: ", IncludeSpeaks ? "YES" : "NO", " | Lead: ", LeadCalendarMinutes, "m | Trail: ", TrailCalendarMinutes, "m    ║");
      Print("╚════════════════════════════════════════════════════════════╝");
   }

   // Initial preparation
   pipPoints = GetPipPoint();
   PrepareAll();

   Print("Prism initialized successfully on ", _Symbol);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   indicatorHandles.Release();

   // Clean up chart objects
   ObjectDelete(0, "hud");
   ObjectDelete(0, "hudCalendar");
   Comment("");

   Print("Prism deinitialized");
}

//+------------------------------------------------------------------+
//| Calculate margin requirement for given lot size                  |
//+------------------------------------------------------------------+
double CalculateMargin(string symbol, double volume)
{
   double marginInit = 0;

   if(!OrderCalcMargin(ORDER_TYPE_BUY, symbol, volume,
                       SymbolInfoDouble(symbol, SYMBOL_ASK), marginInit))
   {
      Print("Error calculating margin: ", GetLastError());
      return 0;
   }

   return marginInit;
}

//+------------------------------------------------------------------+
//| Calculate lot sizes and manage daily growth tracking            |
//+------------------------------------------------------------------+
void CalculateLotSize()
{
   symbolInfo.RefreshRates();
   double ask = symbolInfo.Ask();
   double bid = symbolInfo.Bid();

   // Calculate spread
   spread = (ask - bid) / pipPoints;

   // Dynamic slippage based on ATR
   slippage = NormalizeDouble((indicators.ATR / pipPoints) * DynamicSlippage, 1);

   // Calculate margin requirement
   marginRequirement = CalculateMargin(_Symbol, BaseLotSize);

   if(marginRequirement <= 0)
   {
      lotSize = MinLots;
      backupLotSize = MinLots;
      return;
   }

   double accountBalance = accountInfo.Balance();

   // Calculate lot sizes based on margin usage
   lotSize = NormalizeDouble((accountBalance * MarginUsage / marginRequirement) * BaseLotSize, 2);
   backupLotSize = NormalizeDouble((accountBalance * BackupMargin / marginRequirement) * BaseLotSize, 2);

   // Ensure minimum lot sizes
   if(lotSize < MinLots) lotSize = MinLots;
   if(backupLotSize < MinLots) backupLotSize = MinLots;

   // Calculate margin level
   double accountMargin = accountInfo.Margin();
   if(accountMargin > 0)
      marginLevel = accountInfo.Equity() / accountMargin * 100;
   if(positions.totalTrades == 0)
      marginLevel = 0;

   // Daily refresh logic
   datetime currentTime = TimeCurrent();
   if(MathMod((long)currentTime, 3600 * RefreshHours) <= 10)
   {
      if(turn == 0)
         totalDays++;
      turn = 1;

      // Check daily growth target
      if(dailyGrowth / accountBalance > DailyGrowth)
      {
         Print("Daily growth target reached: ", DoubleToString(dailyGrowth / accountBalance * 100, 2), "%");
         dailyTargets++;
      }

      dailyGrowth = 0;

      // Close profitable positions at daily reset
      if(positions.totalProfit + positions.totalLoss > 0)
      {
         Print("Daily reset: Closing profitable positions");
         CloseAllPositions();
      }
   }
   else
   {
      turn = 0;
   }

   // Safe growth check
   if(SafeGrowth && dailyGrowth / accountBalance > DailyGrowth)
   {
      Print("SafeGrowth triggered: Daily target reached");
      CloseAllPositions();
   }

   // Track maximum equity
   if(accountBalance > maxEquity)
      maxEquity = accountBalance;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions(string type = "none")
{
   if(positions.totalTrades == 1)
      lastTradeTime = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!positionInfo.SelectByIndex(i))
         continue;

      if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == MAGIC)
      {
         symbolInfo.RefreshRates();

         if((positionInfo.StopLoss() == 0 && positionInfo.Profit() > 0 && type == "profits") || type == "none")
         {
            if(trade.PositionClose(positionInfo.Ticket()))
            {
               dailyGrowth += positionInfo.Profit();
               lastTradeTime = TimeCurrent();
            }
            else
            {
               Print("Error closing position: ", trade.ResultRetcodeDescription());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Master preparation function                                       |
//+------------------------------------------------------------------+
void PrepareAll()
{
   // Read indicators
   ReadIndicatorValues(indicatorHandles, indicators, ATRShift, ADXShift,
                      ADXShiftCheck, MAShift, MAShiftCheck);

   // Prepare calendar
   PrepareCalendar(calendar, EnableCalendar, IncludeHigh, IncludeMedium,
                  IncludeLow, IncludeSpeaks);

   // Analyze signals
   AnalyzeTrendSignals(market, indicators, calendar,
                      SignalA, SignalAStartHour, SignalAEndHour, MinTrend, MaxTrend, TrendSpace,
                      SignalB, SignalBStartHour, SignalBEndHour, ADXMain,
                      SignalC, SignalCStartHour, SignalCEndHour,
                      SignalD, SignalDStartHour, SignalDEndHour,
                      pipPoints, EnableCalendar, TrailCalendarMinutes);

   // Analyze positions
   AnalyzePositions(positions, market, MAGIC, indicators.ATR, TradeSpace);

   // Calculate historical profit
   totalHistoryProfit = CalculateHistoricalProfit(MAGIC, QueryHistory, symbolHistory);

   // Calculate lot sizes
   CalculateLotSize();

   // Update display
   UpdateDisplay();
}

//+------------------------------------------------------------------+
//| Open new position                                                 |
//+------------------------------------------------------------------+
void OpenPosition()
{
   symbolInfo.RefreshRates();
   double ask = symbolInfo.Ask();
   double bid = symbolInfo.Bid();

   double closePrice[], openPrice[];
   ArraySetAsSeries(closePrice, true);
   ArraySetAsSeries(openPrice, true);

   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 1, closePrice) < 1) return;
   if(CopyOpen(_Symbol, PERIOD_CURRENT, 0, 1, openPrice) < 1) return;

   // Check spread condition
   if((!SafeSpread || spread < MaxSpread))
   {
      // Long signal
      if(!market.nearLongPosition && market.bullish && positions.sellLots == 0 &&
         openPrice[0] < closePrice[0])
      {
         if(basketNumberType != (int)POSITION_TYPE_BUY) basketCount = 0;
         if(basketCount < MaxTrades)
         {
            double freeMargin = accountInfo.FreeMargin();
            double marginRequired = 0;

            if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lotSize, ask, marginRequired))
               return;

            if(freeMargin < marginRequired)
               return;

            string comment = version + " " + market.signalComment + " Min " + IntegerToString(basketNumber);

            if(trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lotSize, ask, 0, 0, comment))
            {
               Print("Opened BUY: ", comment);
               lastTradeTime = TimeCurrent();
               basketCount++;
               if(basketNumberType != (int)POSITION_TYPE_BUY) basketNumber++;
               basketNumberType = (int)POSITION_TYPE_BUY;
            }
         }
      }
      // Short signal
      else if(!market.nearShortPosition && market.bearish && positions.buyLots == 0 &&
              openPrice[0] > closePrice[0])
      {
         if(basketNumberType != (int)POSITION_TYPE_SELL) basketCount = 0;
         if(basketCount < MaxTrades)
         {
            double freeMargin = accountInfo.FreeMargin();
            double marginRequired = 0;

            if(!OrderCalcMargin(ORDER_TYPE_SELL, _Symbol, lotSize, bid, marginRequired))
               return;

            if(freeMargin < marginRequired)
               return;

            string comment = version + " " + market.signalComment + " Min " + IntegerToString(basketNumber);

            if(trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, lotSize, bid, 0, 0, comment))
            {
               Print("Opened SELL: ", comment);
               lastTradeTime = TimeCurrent();
               basketCount++;
               if(basketNumberType != (int)POSITION_TYPE_SELL) basketNumber++;
               basketNumberType = (int)POSITION_TYPE_SELL;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Open position with calendar check                                |
//+------------------------------------------------------------------+
void OpenWithCalendarCheck()
{
   if(EnableCalendar)
   {
      string calType = GetCalendarTypeString(calendar.type1);

      if(calendar.eventTime1 > TrailCalendarMinutes && calType == "since ")
         OpenPosition();
      else if(calendar.eventTime1 > LeadCalendarMinutes && calType == "until ")
         OpenPosition();
      else if(calendar.eventTime1 >= 99999)
         OpenPosition();
   }
   else
   {
      OpenPosition();
   }
}

//+------------------------------------------------------------------+
//| Send backup position                                             |
//+------------------------------------------------------------------+
void SendBackup()
{
   if((!ContinueTrading && positions.totalBackupTrades == 0))
      return;

   if(positions.totalBackupTrades >= MaxTrades - 1)
      return;

   symbolInfo.RefreshRates();
   double ask = symbolInfo.Ask();
   double bid = symbolInfo.Bid();

   double closePrice[], openPrice[], highPrice[], lowPrice[];
   ArraySetAsSeries(closePrice, true);
   ArraySetAsSeries(openPrice, true);
   ArraySetAsSeries(highPrice, true);
   ArraySetAsSeries(lowPrice, true);

   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 2, closePrice) < 2) return;
   if(CopyOpen(_Symbol, PERIOD_CURRENT, 0, 2, openPrice) < 2) return;
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 2, highPrice) < 2) return;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, 2, lowPrice) < 2) return;

   if(Aggressive)
   {
      // Aggressive mode: Follow trend
      if(!market.nearLongPosition && market.bullish && positions.sellLots == 0)
      {
         string comment = version + " " + market.signalComment + " Backup " + IntegerToString(basketNumber);
         trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, backupLotSize, ask, 0, 0, comment);
      }
      else if(!market.nearShortPosition && market.bearish && positions.buyLots == 0)
      {
         string comment = version + " " + market.signalComment + " Backup " + IntegerToString(basketNumber);
         trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, backupLotSize, bid, 0, 0, comment);
      }
   }
   else
   {
      // Spike detection mode
      // BUY backup on bullish spike rejection
      if(MathAbs(highPrice[0] - lowPrice[0]) > CandleSpike * MathAbs(highPrice[1] - lowPrice[1]) &&
         openPrice[0] < closePrice[0] &&
         closePrice[0] < (highPrice[0] + lowPrice[0]) / 2 &&
         (AllowHedge || positions.openType == (int)POSITION_TYPE_BUY))
      {
         double freeMargin = accountInfo.FreeMargin();
         double marginRequired = 0;

         if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, backupLotSize, ask, marginRequired))
         {
            if(freeMargin >= marginRequired)
            {
               string comment = version + " Backup " + market.signalComment + " " + IntegerToString(basketNumber);
               if(trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, backupLotSize, ask, 0, 0, comment))
               {
                  Print("Opened BUY backup on spike");
                  lastTradeTime = TimeCurrent();
               }
            }
         }
      }

      // SELL backup on bearish spike rejection
      if(MathAbs(highPrice[0] - lowPrice[0]) > CandleSpike * MathAbs(highPrice[1] - lowPrice[1]) &&
         openPrice[0] > closePrice[0] &&
         closePrice[0] > (highPrice[0] + lowPrice[0]) / 2 &&
         (AllowHedge || positions.openType == (int)POSITION_TYPE_SELL))
      {
         double freeMargin = accountInfo.FreeMargin();
         double marginRequired = 0;

         if(OrderCalcMargin(ORDER_TYPE_SELL, _Symbol, backupLotSize, bid, marginRequired))
         {
            if(freeMargin >= marginRequired)
            {
               string comment = version + " Backup " + market.signalComment + " " + IntegerToString(basketNumber);
               if(trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, backupLotSize, bid, 0, 0, comment))
               {
                  Print("Opened SELL backup on spike");
                  lastTradeTime = TimeCurrent();
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Backup system with calendar check                                |
//+------------------------------------------------------------------+
void BackupWithCalendarCheck()
{
   if(EnableCalendar)
   {
      string calType = GetCalendarTypeString(calendar.type1);

      if(calendar.eventTime1 > TrailCalendarMinutes && calType == "since ")
         SendBackup();
      else if(calendar.eventTime1 > LeadCalendarMinutes && calType == "until ")
         SendBackup();
      else if(calendar.eventTime1 >= 99999)
         SendBackup();
   }
   else
   {
      SendBackup();
   }
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+
void ManagePositions()
{
   symbolInfo.RefreshRates();
   double ask = symbolInfo.Ask();
   double bid = symbolInfo.Bid();

   // Basket profit condition
   if(totalHistoryProfit < 0 && positions.totalProfit > 0 &&
      positions.totalProfit > MathAbs(maxEquity - totalHistoryProfit) * BasketProfit)
   {
      Print("Basket profit target reached");
      CloseAllPositions("profits");
   }
   // Multiple trades with overall profit
   else if(positions.totalTrades > 1 &&
           positions.totalProfit + positions.totalLoss > OpenProfit * accountInfo.Balance())
   {
      Print("Open profit target reached");
      CloseAllPositions();
   }
   // Safe exit on trend reversal
   else if(SafeExits && positions.totalTrades > 0 &&
           positions.totalProfit + positions.totalLoss > SafeProfit * accountInfo.Balance() &&
           ((market.bullish && basketNumberType == (int)POSITION_TYPE_SELL) ||
            (market.bearish && basketNumberType == (int)POSITION_TYPE_BUY)))
   {
      Print("SafeExit: Trend reversal detected");
      CloseAllPositions();
   }
   // Calendar-based exit
   else if(EnableCalendar && positions.totalTrades > 0 &&
           positions.totalProfit + positions.totalLoss > 0 &&
           calendar.eventTime1 < LeadCalendarMinutes &&
           GetCalendarTypeString(calendar.type1) == "until " && calendar.eventTime1 > 0)
   {
      Print("Calendar exit: Upcoming news");
      CloseAllPositions();
   }
   else
   {
      // Individual position management
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!positionInfo.SelectByIndex(i))
            continue;

         if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == MAGIC)
         {
            // Small position count exits
            if(positions.totalTrades <= 1)
            {
               if(positionInfo.PositionType() == POSITION_TYPE_BUY &&
                  bid > positionInfo.PriceOpen() &&
                  positionInfo.Profit() > MinProfit * accountInfo.Balance())
               {
                  if(trade.PositionClose(positionInfo.Ticket()))
                  {
                     dailyGrowth += positionInfo.Profit();
                     lastTradeTime = TimeCurrent();
                  }
               }
               else if(positionInfo.PositionType() == POSITION_TYPE_SELL &&
                       ask < positionInfo.PriceOpen() &&
                       positionInfo.Profit() > MinProfit * accountInfo.Balance())
               {
                  if(trade.PositionClose(positionInfo.Ticket()))
                  {
                     dailyGrowth += positionInfo.Profit();
                     lastTradeTime = TimeCurrent();
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Long-term stop loss protection                                   |
//+------------------------------------------------------------------+
void CheckLongStop()
{
   if(EnableStop &&
      totalHistoryProfit > StopGrowth * accountInfo.Balance() &&
      (positions.totalProfit + positions.totalLoss) < 0 &&
      MathAbs(positions.totalProfit + positions.totalLoss) > RelativeStop * totalHistoryProfit)
   {
      Print("Long-term stop triggered");
      CloseAllPositions();
   }
}

//+------------------------------------------------------------------+
//| Update HUD display                                               |
//+------------------------------------------------------------------+
void UpdateDisplay()
{
   display = "";
   display += "\n Growth: " + DoubleToString(dailyGrowth / accountInfo.Balance() * 100, 1) +
              " / " + DoubleToString(DailyGrowth * 100, 1) + "%" +
              " Targets: " + IntegerToString(dailyTargets) + " / " + IntegerToString(totalDays) +
              " Trend: " + DoubleToString(indicators.trendStrength / pipPoints, 1);
   display += " Spread: " + DoubleToString(spread, 1);

   // Main HUD
   if(ObjectFind(0, "hud") == -1)
   {
      ObjectCreate(0, "hud", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "hud", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "hud", OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }

   ObjectSetInteger(0, "hud", OBJPROP_YDISTANCE, EnableCalendar ? 90 : 20);
   ObjectSetString(0, "hud", OBJPROP_TEXT, display);
   ObjectSetString(0, "hud", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, "hud", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "hud", OBJPROP_COLOR, clrLightGray);
   ObjectSetInteger(0, "hud", OBJPROP_XDISTANCE, 6);

   // Calendar HUD
   if(ObjectFind(0, "hudCalendar") == -1)
   {
      ObjectCreate(0, "hudCalendar", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "hudCalendar", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "hudCalendar", OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }

   ObjectSetInteger(0, "hudCalendar", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "hudCalendar", OBJPROP_YDISTANCE, EnableCalendar ? 110 : 40);
   ObjectSetString(0, "hudCalendar", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, "hudCalendar", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "hudCalendar", OBJPROP_COLOR, clrLightGray);

   // Calendar text
   string calendarText = "";

   if(EnableCalendar)
   {
      string calType = GetCalendarTypeString(calendar.type1);
      string impactText = "";

      if(calendar.impact1 == 0) impactText = "High";
      else if(calendar.impact1 == 1) impactText = "Medium";
      else if(calendar.impact1 == 2) impactText = "Low";
      else if(calendar.impact1 == 3) impactText = "Speaks";
      else impactText = "Unknown";

      if(calendar.eventTime1 >= 99999)
      {
         calendarText = "Calendar: No relevant news events";
      }
      else if(calType == "until ")
      {
         long hours = (long)calendar.hours1;
         long minutes = (long)calendar.minutes1;

         if(calendar.eventTime1 < LeadCalendarMinutes)
            calendarText = StringFormat("⚠ NEWS IN %dh %dm - %s [%s] %s - WAITING/EXIT",
                                       hours, minutes, calendar.currency1, impactText, calendar.text1);
         else
            calendarText = StringFormat("Calendar: %dh %dm until %s [%s] %s",
                                       hours, minutes, calendar.currency1, impactText, calendar.text1);
      }
      else if(calType == "since ")
      {
         long hours = (long)calendar.hours1;
         long minutes = (long)calendar.minutes1;

         if(calendar.eventTime1 < TrailCalendarMinutes)
            calendarText = StringFormat("⏳ %dh %dm since %s [%s] %s - CAUTION",
                                       hours, minutes, calendar.currency1, impactText, calendar.text1);
         else
            calendarText = StringFormat("Calendar: %dh %dm since %s [%s] - Trading normal",
                                       hours, minutes, calendar.currency1, impactText);
      }
      else
      {
         calendarText = "Calendar: Analyzing events...";
      }
   }
   else
   {
      calendarText = "Calendar: Disabled";
   }

   ObjectSetString(0, "hudCalendar", OBJPROP_TEXT, calendarText);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Prepare all data
   PrepareAll();

   // Force close if requested
   if(CloseAll)
   {
      CloseAllPositions();
      return;
   }

   // Get day of week
   MqlDateTime tm;
   TimeCurrent(tm);
   int dayOfWeek = tm.day_of_week;

   datetime currentTime = TimeCurrent();

   // Trading conditions
   if((dayOfWeek != 5 || TradeFriday))
   {
      if(dailyGrowth / accountInfo.Balance() < DailyGrowth &&
         currentTime - lastTradeTime > SleepSeconds &&
         (marginLevel == 0 || marginLevel > MinMarginLevel))
      {
         // Trigger backup system if in drawdown
         if(positions.totalTrades >= 1 &&
            (accountInfo.Balance() + (positions.totalProfit + positions.totalLoss)) / accountInfo.Balance() < TriggerBackSystem)
         {
            BackupWithCalendarCheck();
         }
         // Open new positions
         else if((ContinueTrading || (!ContinueTrading && positions.totalTrades > 0)) &&
                 (positions.totalTrades < 1))
         {
            OpenWithCalendarCheck();
         }
      }
   }

   // Always manage positions
   ManagePositions();
   CheckLongStop();
}

//+------------------------------------------------------------------+
//| END OF FILE                                                      |
//+------------------------------------------------------------------+
