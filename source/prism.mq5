//+------------------------------------------------------------------+
//|                                              prism.mq5  |
//|                                  Ported from MT4 version by AI    |
//|                         http://codebase.mql4.com/9050            |
//+------------------------------------------------------------------+
#property copyright "Rudi & Claude"
#property version   "0.1"
#property description "Prism Trading Bot"

//+------------------------------------------------------------------+
//| MT5 CONVERSION: Include necessary libraries for trading          |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include "Includes/PrismTypes.mqh"
#include "Includes/PrismCalendar.mqh"
#include "Includes/PrismIndicators.mqh"
#include "Includes/PrismSignals.mqh"
#include "Includes/PrismPositions.mqh"

//+------------------------------------------------------------------+
//| MT5 CONVERSION: Declare CTrade objects for position management   |
//+------------------------------------------------------------------+
CTrade _trade;
CPositionInfo _positionInfo;
COrderInfo _orderInfo;
CSymbolInfo _symbolInfo;
CAccountInfo _accountInfo;

//--- EA Version and Magic Number
string _version = "Prism 0.1";
int _MAGIC = 20260220;

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
input bool EnableCalendar = true;        // Enable economic calendar trading restrictions
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
input double MarginUsage = 0.3;           // Percentage of balance allocated to regular trades (10% = conservative)
input double BackupMargin = 0.1;         // Percentage of balance allocated to backup trades (1% = very conservative)
input double MinMarginLevel = 300;        // Minimum margin level required to open new positions (300% = safe)
input double MinLots = 0.03;              // Minimum lot size for any _trade
input bool EnableStop = true;            // Enable long-term stop loss based on historical profits
input double RelativeStop = 0.3;          // Stop loss as percentage of historical profit (30% drawdown limit)
input double StopGrowth = 0.05;          // Historical profit threshold to activate stop loss (0.5% of balance)

//═══════════════════════════════════════════════════════════════════
//  TRADE MANAGEMENT
//═══════════════════════════════════════════════════════════════════
input group "════════ TRADE MANAGEMENT ════════";
input int MaxTrades = 8;                  // Maximum number of positions per basket (includes regular + backup)
input double TradeSpace = 7.5;            // Minimum distance between trades in ATR units (prevents clustering)
input int SleepSeconds = 18000;           // Minimum seconds between any trades (14400 = 4 hours)
input bool TradeFriday = true;           // Allow trading on Fridays (typically avoided due to weekend risk)
input bool SafeSpread = true;             // Only _trade when _spread is below MaxSpread threshold
input double MaxSpread = 2;               // Maximum _spread in pips allowed for _trade execution

//═══════════════════════════════════════════════════════════════════
//  PROFIT TARGETS
//═══════════════════════════════════════════════════════════════════
input group "════════ PROFIT TARGETS ════════";
input double BasketProfit = 1.1;          // Profit multiplier for basket closure (1.1 = 110% of historical loss)
input double OpenProfit = 0.005;          // Close all positions when total profit exceeds this % of balance
input double MinProfit = 0.007;           // Minimum profit per position for individual exits (0.7% of balance)
input double SafeProfit = 0.005;          // Profit threshold for safe exits on trend reversal (0.5% of balance)
input double DailyGrowth = 0.06;         // Daily profit target (1.5% of balance = aggressive growth)
input bool SafeGrowth = true;             // Stop trading when daily growth target is reached
input bool SafeExits = true;              // Exit positions when trend reverses against open positions
input int RefreshHours = 24;              // Hours between daily profit resets and statistics refresh

//═══════════════════════════════════════════════════════════════════
//  BACKUP SYSTEM (Drawdown Recovery)
//═══════════════════════════════════════════════════════════════════
input group "════════ BACKUP SYSTEM ════════";
input double TriggerBackSystem = 0.95;   // Equity ratio trigger for backup trades (0.999 = 0.1% drawdown)
input double CandleSpike = 5;             // Spike multiplier for backup entry (current candle vs previous)
input bool Aggressive = true;            // Use aggressive backup mode (trend-following vs spike detection)
input bool AllowHedge = true;            // Allow backup trades in opposite direction of main positions

//═══════════════════════════════════════════════════════════════════
//  SIGNAL A: Trend Following with MA Crossover
//═══════════════════════════════════════════════════════════════════
input group "════════ SIGNAL A: TREND FOLLOWING ════════";
input bool SignalA = false;                // Enable Signal A (MA crossover with trend strength filter)
input int SignalAStartHour = 0;           // Trading start hour for Signal A (24-hour format)
input int SignalAEndHour = 23;            // Trading end hour for Signal A (23 = _trade until 11 PM)
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
input bool SignalC = false;                // Enable Signal C (counter-trend entries on extreme moves)
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
input int QueryHistory = 2;              // Number of historical trades to analyze for basket calculations

//--- Global Variables
double _slippage, _marginRequirement, _lotSize, _backupLotSize, _totalHistoryProfit;
int _symbolHistory;
bool _incrementLimits = false;
int _maxStartTrades = 1;
datetime _lastTradeTime = 0;         // MT5: Changed from int to datetime
int _totalHistory = 100;
int _basketNumber = 0;
int _basketNumberType = -1;
int _basketCount = -1;
double _pipPoints = 0.00010;
double _dynamicSlippage = 1;
double _baseLotSize = 0.01;
double _marginLevel = 0;
double _spread = 0;
double _longHistortProfit = 0;
double _dailyGrowth = 0;
double _maxEquity = 0;
double _maxBasketDrawDown = 0;
string _display = "\n";
CalendarData _calendar;
PositionStats _stats;

int _dailyTargets = 0;
int _totalDays = 0;
int _turn = 0;

IndicatorHandles _handles;
IndicatorValues _indicators;
MarketConditions _market;

//+------------------------------------------------------------------+
//| MT5 CONVERSION: Price arrays for bar data access                 |
//+------------------------------------------------------------------+
double _closeArray[];
double _openArray[];
double _highArray[];
double _lowArray[];

//+------------------------------------------------------------------+
//| Expert initialization function (MT5: changed from init())        |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set symbol information
   _symbolInfo.Name(_Symbol);
   _symbolInfo.RefreshRates();

   // MT5 CONVERSION: Set _trade parameters using CTrade class
   _trade.SetExpertMagicNumber(_MAGIC);
   _trade.SetDeviationInPoints((int)_slippage);
   _trade.SetTypeFilling(ORDER_FILLING_FOK);  // Fill or Kill order type
   _trade.SetAsyncMode(false);                // Synchronous execution

   // Initialize indicator handles
   if(!InitializeIndicators(_handles, ATRPeriod, ADXPeriod, MA1Period, MA2Period, 0))
      return(INIT_FAILED);

   // CALENDAR INTEGRATION - MT5 Native Implementation
   // =================================================
   // The MT4 _version used a custom indicator (milestone_calendar) that parsed ForexFactory feeds.
   // MT5 _version uses native economic calendar API:
   //    - CalendarValueHistory() to get scheduled news events
   //    - CalendarEventById() to get event details
   //    - CalendarCountryById() to filter by country/currency
   if(EnableCalendar)
   {
      Print("╔════════════════════════════════════════════════════════════╗");
      Print("║ Calendar Integration Active - MT5 Native API              ║");
      Print("╠════════════════════════════════════════════════════════════╣");
      Print("║ Using MT5 economic calendar for event filtering           ║");
      Print("║ Settings:                                                  ║");
      Print("║   - High Impact: ", IncludeHigh ? "YES" : "NO", "                                      ║");
      Print("║   - Medium Impact: ", IncludeMedium ? "YES" : "NO", "                                  ║");
      Print("║   - Low Impact: ", IncludeLow ? "YES" : "NO", "                                     ║");
      Print("║   - Speeches: ", IncludeSpeaks ? "YES" : "NO", "                                      ║");
      Print("║   - Lead time: ", LeadCalendarMinutes, " minutes                           ║");
      Print("║   - Trail time: ", TrailCalendarMinutes, " minutes                          ║");
      Print("╚════════════════════════════════════════════════════════════╝");
   }

   // MT5 CONVERSION: Set price arrays as series (index 0 = most recent)
   ArraySetAsSeries(_closeArray, true);
   ArraySetAsSeries(_openArray, true);
   ArraySetAsSeries(_highArray, true);
   ArraySetAsSeries(_lowArray, true);

   // Initial preparation
   prepare();

   Print("Milestone 20.5 MT5 initialized successfully on ", _Symbol);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   _handles.Release();

   // Clean up chart objects
   ObjectDelete(0, "hud");
   ObjectDelete(0, "hudCalendar");

   // Clear comment
   Comment("");

   string reasonText = "";
   switch(reason)
   {
      case REASON_PROGRAM: reasonText = "EA stopped by user"; break;
      case REASON_REMOVE: reasonText = "EA removed from chart"; break;
      case REASON_RECOMPILE: reasonText = "EA recompiled"; break;
      case REASON_CHARTCHANGE: reasonText = "Chart symbol/period changed"; break;
      case REASON_CHARTCLOSE: reasonText = "Chart closed"; break;
      case REASON_PARAMETERS: reasonText = "Input parameters changed"; break;
      case REASON_ACCOUNT: reasonText = "Account changed"; break;
      default: reasonText = "Unknown reason"; break;
   }

   Print("Milestone 20.5 MT5 deinitialized: ", reasonText);
}

//+------------------------------------------------------------------+
//| MT5 CONVERSION: Calculate margin requirement                     |
//| Replaces MarketInfo(Symbol(), MODE_MARGINREQUIRED)              |
//+------------------------------------------------------------------+
double marginCalculate(string symbol, double volume)
{
   double marginInit = 0;

   // MT5: Use OrderCalcMargin to calculate required margin
   if(!OrderCalcMargin(ORDER_TYPE_BUY, symbol, volume,
                       SymbolInfoDouble(symbol, SYMBOL_ASK), marginInit))
   {
      int error = GetLastError();
      Print("Error calculating margin for ", symbol, " volume ", volume, ": ", error);
      return 0;
   }

   return marginInit;
}

//+------------------------------------------------------------------+
//| Calculate lot sizes and manage daily growth tracking            |
//+------------------------------------------------------------------+
void calculateLotSize()
{
   // MT5 CONVERSION: Get current Ask and Bid using SymbolInfoDouble
   _symbolInfo.RefreshRates();
   double ask = _symbolInfo.Ask();
   double bid = _symbolInfo.Bid();

   // Calculate _spread in pips
   _spread = (ask - bid) / _pipPoints;

   // Dynamic _slippage based on ATR
   _slippage = NormalizeDouble((_indicators.ATR / _pipPoints) * _dynamicSlippage, 1);

   // Calculate margin requirement for base lot size
   _marginRequirement = marginCalculate(_Symbol, _baseLotSize);

   if(_marginRequirement <= 0)
   {
      Print("Warning: Invalid margin requirement, using minimum lot size");
      _lotSize = MinLots;
      _backupLotSize = MinLots;
      return;
   }

   // MT5 CONVERSION: Use AccountInfo class methods instead of Account*() functions
   double accountBalance = _accountInfo.Balance();

   // Calculate lot sizes based on margin usage percentage
   _lotSize = NormalizeDouble((accountBalance * MarginUsage / _marginRequirement) * _baseLotSize, 2);
   _backupLotSize = NormalizeDouble((accountBalance * BackupMargin / _marginRequirement) * _baseLotSize, 2);

   // Ensure minimum lot sizes
   if(_lotSize < MinLots) _lotSize = MinLots;
   if(_backupLotSize < MinLots) _backupLotSize = MinLots;

   // Calculate margin level
   double accountMargin = _accountInfo.Margin();
   if(accountMargin > 0)
      _marginLevel = _accountInfo.Equity() / accountMargin * 100;
   if(_stats.totalTrades == 0) _marginLevel = 0;

   // Daily refresh logic
   datetime currentTime = TimeCurrent();
   if(MathMod((long)currentTime, 3600 * RefreshHours) <= 10)
   {
      if(_turn == 0) _totalDays = _totalDays + 1;
      _turn = 1;

      // Check if daily growth target reached
      if(_dailyGrowth / accountBalance > DailyGrowth)
      {
         Print("Daily growth target reached: ", DoubleToString(_dailyGrowth / accountBalance * 100, 2), "%");
         _dailyTargets = _dailyTargets + 1;
         _turn = 1;
      }

      _dailyGrowth = 0;

      // Close all positions at daily reset if in profit
      if(_stats.totalProfit + _stats.totalLoss > 0)
      {
         Print("Daily reset: Closing all profitable positions");
         closeAll();
      }
   }
   else
   {
      _turn = 0;
   }

   // Safe growth check - close all if daily target reached
   if(SafeGrowth)
      if(_dailyGrowth / accountBalance > DailyGrowth)
      {
         Print("SafeGrowth triggered: Daily target reached");
         closeAll();
      }

   // Track maximum equity
   if(accountBalance > _maxEquity)
      _maxEquity = accountBalance;
}

//+------------------------------------------------------------------+
//| Close all positions (MT5: Complete rewrite for position model)   |
//+------------------------------------------------------------------+
void closeAll(string type = "none")
{
   if(_stats.totalTrades == 1)
      _lastTradeTime = TimeCurrent();

   // MT5 CONVERSION: Iterate through positions using position-based model
   // In MT4: OrdersTotal() returns pending and open orders
   // In MT5: PositionsTotal() returns only open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!_positionInfo.SelectByIndex(i)) continue;

      // Check if position belongs to this EA and symbol
      if(_positionInfo.Symbol() == _Symbol && _positionInfo.Magic() == _MAGIC)
      {
         _symbolInfo.RefreshRates();

         // Check close conditions based on type parameter
         // MT5 CONVERSION: OrderStopLoss() becomes _positionInfo.StopLoss()
         // MT5 CONVERSION: OrderProfit() becomes _positionInfo.Profit()
         if((_positionInfo.StopLoss() == 0 && _positionInfo.Profit() > 0 && type == "profits") || type == "none")
         {
            // MT5 CONVERSION: OrderClose() replaced with _trade.PositionClose()
            // MT4: OrderClose(OrderTicket(), OrderLots(), Bid/Ask, _slippage)
            // MT5: _trade.PositionClose(_positionInfo.Ticket())
            if(_trade.PositionClose(_positionInfo.Ticket()))
            {
               _dailyGrowth = _dailyGrowth + _positionInfo.Profit();
               _lastTradeTime = TimeCurrent();
            }
            else
            {
               Print("Error closing position ", _positionInfo.Ticket(), ": ", _trade.ResultRetcodeDescription());
            }
         }
      }
   }
}


//+------------------------------------------------------------------+
//| Main preparation function - calls all prep functions in sequence |
//+------------------------------------------------------------------+
void prepare()
{
   ReadIndicatorValues(_handles, _indicators, 0, 0, ADXShiftCheck, 0, MAShiftCheck);  // Get indicator values
   PrepareCalendar(_calendar, EnableCalendar, IncludeHigh, IncludeMedium, IncludeLow, IncludeSpeaks);  // Fetch economic calendar events using MT5 API
   AnalyzeTrendSignals(_market, _indicators, _calendar,
                       SignalA, SignalAStartHour, SignalAEndHour, MinTrend, MaxTrend, TrendSpace,
                       SignalB, SignalBStartHour, SignalBEndHour, ADXMain,
                       SignalC, SignalCStartHour, SignalCEndHour,
                       SignalD, SignalDStartHour, SignalDEndHour,
                       _pipPoints, EnableCalendar, TrailCalendarMinutes);  // Analyze trend and generate signals
   _pipPoints = GetPipPoint();
   _totalHistoryProfit = CalculateHistoricalProfit(_MAGIC, QueryHistory, _symbolHistory);
   AnalyzePositions(_stats, _market, _MAGIC, _indicators.ATR, TradeSpace);
   calculateLotSize();   // Calculate lot sizes and check daily growth
   update();             // Update _display on chart
}

//+------------------------------------------------------------------+
//| Send open position order                                          |
//+------------------------------------------------------------------+
void sendOpen()
{
   _symbolInfo.RefreshRates();
   double ask = _symbolInfo.Ask();
   double bid = _symbolInfo.Bid();

   // Get current bar open/close for direction check
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 1, _closeArray) < 1) return;
   if(CopyOpen(_Symbol, PERIOD_CURRENT, 0, 1, _openArray) < 1) return;

   // Check _spread condition
   if((SafeSpread && _spread < MaxSpread) || !SafeSpread)
   {
      // Long position signal
      if(!_market.nearLongPosition && _market.bullish && _stats.sellLots == 0 && _openArray[0] < _closeArray[0])
      {
         if(_basketNumberType != (int)POSITION_TYPE_BUY) _basketCount = 0;
         if(_basketCount < MaxTrades)
         {
            // MT5 CONVERSION: Check free margin
            // MT4: AccountFreeMarginCheck(Symbol(), OP_BUY, _lotSize)
            // MT5: OrderCalcMargin() then compare with FreeMargin
            double freeMargin = _accountInfo.FreeMargin();
            double marginRequired = 0;
            if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, _lotSize, ask, marginRequired))
            {
               Print("Error calculating margin for BUY: ", GetLastError());
               return;
            }

            if(freeMargin < marginRequired)
            {
               Print("Insufficient free margin for BUY. Required: ", marginRequired, " Available: ", freeMargin);
               return;
            }

            string comment = _version + " " + _market.signalComment + " Min " + IntegerToString(_basketNumber);

            // MT5 CONVERSION: Open position using CTrade
            // MT4: OrderSend(Symbol(), OP_BUY, _lotSize, Ask, _slippage, 0, 0, comment, _MAGIC)
            // MT5: _trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, _lotSize, ask, 0, 0, comment)
            if(_trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, _lotSize, ask, 0, 0, comment))
            {
               Print("Opened BUY position: ", comment);
               _lastTradeTime = TimeCurrent();
               _basketCount++;
               if(_basketNumberType != (int)POSITION_TYPE_BUY) _basketNumber++;
               _stats.openType = (int)POSITION_TYPE_BUY;
            }
            else
            {
               Print("Error opening BUY position: ", _trade.ResultRetcodeDescription());
            }
         }
      }
      // Short position signal
      else if(!_market.nearShortPosition && _market.bearish && _stats.buyLots == 0 && _openArray[0] > _closeArray[0])
      {
         if(_basketNumberType != (int)POSITION_TYPE_SELL) _basketCount = 0;
         if(_basketCount < MaxTrades)
         {
            double freeMargin = _accountInfo.FreeMargin();
            double marginRequired = 0;
            if(!OrderCalcMargin(ORDER_TYPE_SELL, _Symbol, _lotSize, bid, marginRequired))
            {
               Print("Error calculating margin for SELL: ", GetLastError());
               return;
            }

            if(freeMargin < marginRequired)
            {
               Print("Insufficient free margin for SELL. Required: ", marginRequired, " Available: ", freeMargin);
               return;
            }

            string comment = _version + " " + _market.signalComment + " Min " + IntegerToString(_basketNumber);

            if(_trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, _lotSize, bid, 0, 0, comment))
            {
               Print("Opened SELL position: ", comment);
               _lastTradeTime = TimeCurrent();
               _basketCount++;
               if(_basketNumberType != (int)POSITION_TYPE_SELL) _basketNumber++;
               _stats.openType = (int)POSITION_TYPE_SELL;
            }
            else
            {
               Print("Error opening SELL position: ", _trade.ResultRetcodeDescription());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Open position with calendar check                                |
//+------------------------------------------------------------------+
void openPosition()
{
   if(EnableCalendar)
   {
      // Calendar check - only _trade at appropriate times relative to news
      string calType = GetCalendarTypeString(_calendar.type1);

      if(_calendar.eventTime1 > TrailCalendarMinutes && calType == "since ")
         sendOpen();  // Enough time passed since news
      else if(_calendar.eventTime1 > LeadCalendarMinutes && calType == "until ")
         sendOpen();  // Enough time before upcoming news
      else if(_calendar.eventTime1 >= 99999)
         sendOpen();  // No news scheduled
   }
   else
      sendOpen();  // Calendar disabled, always open
}

//+------------------------------------------------------------------+
//| Send backup position order (spike detection system)              |
//+------------------------------------------------------------------+
void sendBack()
{
   if((ContinueTrading || (!ContinueTrading && _stats.totalBackupTrades > 0)) &&
      (_stats.totalBackupTrades < MaxTrades - _maxStartTrades))
   {
      _symbolInfo.RefreshRates();
      double ask = _symbolInfo.Ask();
      double bid = _symbolInfo.Bid();

      // Get bar data for spike detection
      if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 2, _closeArray) < 2) return;
      if(CopyOpen(_Symbol, PERIOD_CURRENT, 0, 2, _openArray) < 2) return;
      if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 2, _highArray) < 2) return;
      if(CopyLow(_Symbol, PERIOD_CURRENT, 0, 2, _lowArray) < 2) return;

      if(Aggressive)
      {
         // Aggressive mode: Follow current trend
         int type = -1;
         if(_market.bullish) type = (int)POSITION_TYPE_BUY;
         else if(_market.bearish) type = (int)POSITION_TYPE_SELL;

         if(!_market.nearLongPosition && type == (int)POSITION_TYPE_BUY && _stats.sellLots == 0)
         {
            string comment = _version + " " + _market.signalComment + " Backup " + IntegerToString(_basketNumber);
            if(!_trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, _backupLotSize, ask, 0, 0, comment))
               Print("Error opening aggressive BUY backup: ", _trade.ResultRetcodeDescription());
         }
         else if(!_market.nearShortPosition && type == (int)POSITION_TYPE_SELL && _stats.buyLots == 0)
         {
            string comment = _version + " " + _market.signalComment + " Backup " + IntegerToString(_basketNumber);
            if(!_trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, _backupLotSize, bid, 0, 0, comment))
               Print("Error opening aggressive SELL backup: ", _trade.ResultRetcodeDescription());
         }
      }
      else
      {
         // Spike detection for BUY backup (bullish spike)
         if(MathAbs(_highArray[0] - _lowArray[0]) > CandleSpike * MathAbs(_highArray[1] - _lowArray[1]) &&
            _openArray[0] < _closeArray[0] &&
            _closeArray[0] < (_highArray[0] + _lowArray[0]) / 2 &&
            ((!AllowHedge && _stats.openType == (int)POSITION_TYPE_BUY) || AllowHedge))
         {
            double freeMargin = _accountInfo.FreeMargin();
            double marginRequired = 0;
            if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, _backupLotSize, ask, marginRequired))
            {
               if(freeMargin >= marginRequired)
               {
                  string comment = _version + " Backup " + _market.signalComment + " " + IntegerToString(_basketNumber);
                  if(_trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, _backupLotSize, ask, 0, 0, comment))
                  {
                     Print("Opened BUY backup on spike: ", comment);
                     _lastTradeTime = TimeCurrent();
                  }
                  else
                     Print("Error opening BUY backup: ", _trade.ResultRetcodeDescription());
               }
            }
         }

         // Spike detection for SELL backup (bearish spike)
         if(MathAbs(_highArray[0] - _lowArray[0]) > CandleSpike * MathAbs(_highArray[1] - _lowArray[1]) &&
            _openArray[0] > _closeArray[0] &&
            _closeArray[0] > (_highArray[0] + _lowArray[0]) / 2 &&
            ((!AllowHedge && _stats.openType == (int)POSITION_TYPE_SELL) || AllowHedge))
         {
            double freeMargin = _accountInfo.FreeMargin();
            double marginRequired = 0;
            if(OrderCalcMargin(ORDER_TYPE_SELL, _Symbol, _backupLotSize, bid, marginRequired))
            {
               if(freeMargin >= marginRequired)
               {
                  string comment = _version + " Backup " + _market.signalComment + " " + IntegerToString(_basketNumber);
                  if(_trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, _backupLotSize, bid, 0, 0, comment))
                  {
                     Print("Opened SELL backup on spike: ", comment);
                     _lastTradeTime = TimeCurrent();
                  }
                  else
                     Print("Error opening SELL backup: ", _trade.ResultRetcodeDescription());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Backup system with calendar check                                |
//+------------------------------------------------------------------+
void backSystem()
{
   if(EnableCalendar)
   {
      // Calendar check for backup system
      string calType = GetCalendarTypeString(_calendar.type1);

      if(_calendar.eventTime1 > TrailCalendarMinutes && calType == "since ")
         sendBack();
      else if(_calendar.eventTime1 > LeadCalendarMinutes && calType == "until ")
         sendBack();
      else if(_calendar.eventTime1 >= 99999)
         sendBack();
   }
   else
      sendBack();
}

//+------------------------------------------------------------------+
//| Manage existing positions and execute exit logic                 |
//+------------------------------------------------------------------+
void managePositions()
{
   _symbolInfo.RefreshRates();
   double ask = _symbolInfo.Ask();
   double bid = _symbolInfo.Bid();

   // Basket profit condition: Close profitable positions if history is negative
   if(_totalHistoryProfit < 0 && _stats.totalProfit > 0 &&
      _stats.totalProfit > MathAbs(_maxEquity - _totalHistoryProfit) * BasketProfit)
   {
      Print("Basket profit target reached, closing profitable positions");
      closeAll("profits");
   }
   // Multiple trades with overall profit
   else if(_stats.totalTrades > 1 && _stats.totalProfit + _stats.totalLoss > OpenProfit * _accountInfo.Balance())
   {
      Print("Open profit target reached, closing all positions");
      closeAll();
   }
   // Safe exit: Close on trend reversal
   else if(SafeExits && _stats.totalTrades > 0 &&
           _stats.totalProfit + _stats.totalLoss > SafeProfit * _accountInfo.Balance() &&
           ((_market.bullish && _basketNumberType == (int)POSITION_TYPE_SELL) ||
            (_market.bearish && _basketNumberType == (int)POSITION_TYPE_BUY)))
   {
      Print("SafeExit triggered: Trend reversal detected");
      closeAll();
   }
   // Calendar-based exit: Close positions with profit if news approaching
   else if(EnableCalendar && _stats.totalTrades > 0 && _stats.totalProfit + _stats.totalLoss > 0 &&
           _calendar.eventTime1 < LeadCalendarMinutes &&
           GetCalendarTypeString(_calendar.type1) == "until " && _calendar.eventTime1 > 0)
   {
      Print("Calendar exit triggered: Upcoming news event");
      closeAll();
   }
   else
   {
      // Individual position management
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!_positionInfo.SelectByIndex(i)) continue;

         if(_positionInfo.Symbol() == _Symbol && _positionInfo.Magic() == _MAGIC)
         {
            // For small number of trades, exit when price moves in favor
            if(_stats.totalTrades <= _maxStartTrades)
            {
               if(_positionInfo.PositionType() == POSITION_TYPE_BUY &&
                  bid > _positionInfo.PriceOpen() &&
                  _positionInfo.Profit() > MinProfit * _accountInfo.Balance())
               {
                  if(_trade.PositionClose(_positionInfo.Ticket()))
                  {
                     Print("Closed BUY position with profit: ", _positionInfo.Profit());
                     _dailyGrowth += _positionInfo.Profit();
                     _lastTradeTime = TimeCurrent();
                  }
               }
               else if(_positionInfo.PositionType() == POSITION_TYPE_SELL &&
                       ask < _positionInfo.PriceOpen() &&
                       _positionInfo.Profit() > MinProfit * _accountInfo.Balance())
               {
                  if(_trade.PositionClose(_positionInfo.Ticket()))
                  {
                     Print("Closed SELL position with profit: ", _positionInfo.Profit());
                     _dailyGrowth += _positionInfo.Profit();
                     _lastTradeTime = TimeCurrent();
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Long-term stop loss protection based on historical profit        |
//+------------------------------------------------------------------+
void longStop()
{
   if(EnableStop &&
      _totalHistoryProfit > StopGrowth * _accountInfo.Balance() &&
      (_stats.totalProfit + _stats.totalLoss) < 0 &&
      MathAbs(_stats.totalProfit + _stats.totalLoss) > RelativeStop * _totalHistoryProfit)
   {
      Print("Long-term stop triggered. Historical profit: ", _totalHistoryProfit,
            " Current drawdown: ", (_stats.totalProfit + _stats.totalLoss));
      closeAll();
   }
}

//+------------------------------------------------------------------+
//| Update HUD _display on chart                                       |
//+------------------------------------------------------------------+
void update()
{
   _display = "";
   _display = _display + "\n Growth: " + DoubleToString(_dailyGrowth / _accountInfo.Balance() * 100, 1) +
             " / " + DoubleToString(DailyGrowth * 100, 1) + "%" +
             " Milestones: " + IntegerToString(_dailyTargets) + " / " + IntegerToString(_totalDays) +
             " Trend: " + DoubleToString(_indicators.trendStrength / _pipPoints, 1);
   _display = _display + " Spread: " + DoubleToString(_spread, 1);

   // MT5 CONVERSION: Create or update chart label
   // MT4: ObjectCreate("hud", OBJ_LABEL, 0, 0, 0)
   // MT5: ObjectCreate(0, "hud", OBJ_LABEL, 0, 0, 0) - requires chart ID
   if(ObjectFind(0, "hud") == -1)
   {
      ObjectCreate(0, "hud", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "hud", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "hud", OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }

   if(EnableCalendar)
      ObjectSetInteger(0, "hud", OBJPROP_YDISTANCE, 90);
   else
      ObjectSetInteger(0, "hud", OBJPROP_YDISTANCE, 20);

   // MT5 CONVERSION: ObjectSetText() replaced with ObjectSetString()
   // MT4: ObjectSetText("hud", _display, 10, "Arial Bold", LightGray)
   // MT5: ObjectSetString(0, "hud", OBJPROP_TEXT, _display)
   ObjectSetString(0, "hud", OBJPROP_TEXT, _display);
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

   if(EnableCalendar)
      ObjectSetInteger(0, "hudCalendar", OBJPROP_YDISTANCE, 110);
   else
      ObjectSetInteger(0, "hudCalendar", OBJPROP_YDISTANCE, 40);

   ObjectSetString(0, "hudCalendar", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, "hudCalendar", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "hudCalendar", OBJPROP_COLOR, clrLightGray);

   // Calendar status messages with event details
   string calendarText = "";

   if(EnableCalendar)
   {
      string calType = GetCalendarTypeString(_calendar.type1);
      string impactText = "";

      // Get impact level text
      if(_calendar.impact1 == 0) impactText = "High";
      else if(_calendar.impact1 == 1) impactText = "Medium";
      else if(_calendar.impact1 == 2) impactText = "Low";
      else if(_calendar.impact1 == 3) impactText = "Speaks";
      else impactText = "Unknown";

      // Build calendar _display text
      if(_calendar.eventTime1 >= 99999)
      {
         calendarText = "Calendar: No relevant news events";
      }
      else if(calType == "until ")
      {
         // Upcoming event
         long hours = (long)_calendar.hours1;
         long minutes = (long)_calendar.minutes1;

         if(_calendar.eventTime1 < LeadCalendarMinutes)
            calendarText = StringFormat("⚠ NEWS IN %dh %dm - %s [%s] %s - WAITING/EXIT",
                                       hours, minutes, _calendar.currency1, impactText, _calendar.text1);
         else
            calendarText = StringFormat("Calendar: %dh %dm until %s [%s] %s",
                                       hours, minutes, _calendar.currency1, impactText, _calendar.text1);
      }
      else if(calType == "since ")
      {
         // Past event
         long hours = (long)_calendar.hours1;
         long minutes = (long)_calendar.minutes1;

         if(_calendar.eventTime1 < TrailCalendarMinutes)
            calendarText = StringFormat("⏳ %dh %dm since %s [%s] %s - CAUTION",
                                       hours, minutes, _calendar.currency1, impactText, _calendar.text1);
         else
            calendarText = StringFormat("Calendar: %dh %dm since %s [%s] - Trading normal",
                                       hours, minutes, _calendar.currency1, impactText);
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
//| Expert tick function (MT5: changed from start())                 |
//+------------------------------------------------------------------+
void OnTick()
{
   // Prepare all data
   prepare();

   // Force close all if requested
   if(CloseAll)
   {
      closeAll();
      return;
   }

   // MT5 CONVERSION: Get day of week
   // MT4: DayOfWeek() returns day directly
   // MT5: Must use MqlDateTime structure
   MqlDateTime tm;
   TimeCurrent(tm);
   int dayOfWeek = tm.day_of_week;

   datetime currentTime = TimeCurrent();

   // Trading conditions check
   if((dayOfWeek != 5 && !TradeFriday) || TradeFriday)
   {
      if(_dailyGrowth / _accountInfo.Balance() < DailyGrowth &&
         currentTime - _lastTradeTime > SleepSeconds &&
         (_marginLevel == 0 || _marginLevel > MinMarginLevel))
      {
         // Trigger backup system if in drawdown
         if(_stats.totalTrades >= _maxStartTrades &&
            (_accountInfo.Balance() + (_stats.totalProfit + _stats.totalLoss)) / _accountInfo.Balance() < TriggerBackSystem)
         {
            backSystem();
         }
         // Open new positions if conditions met
         else if((ContinueTrading || (!ContinueTrading && _stats.totalTrades > 0)) &&
                 (_stats.totalTrades < _maxStartTrades || _maxStartTrades == 0))
         {
            openPosition();
         }
      }
   }

   // Always manage positions and check stops
   managePositions();
   longStop();
}

//+------------------------------------------------------------------+
//| END OF FILE                                                       |
//+------------------------------------------------------------------+

/*
╔══════════════════════════════════════════════════════════════════╗
║                   MT4 TO MT5 CONVERSION SUMMARY                  ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║ 1. INITIALIZATION FUNCTIONS                                      ║
║    ✓ init() → OnInit()                                          ║
║    ✓ start() → OnTick()                                         ║
║    ✓ Added OnDeinit() for cleanup                               ║
║                                                                  ║
║ 2. INPUT PARAMETERS                                              ║
║    ✓ extern → input                                             ║
║    ✓ Added input groups for better organization                 ║
║                                                                  ║
║ 3. TRADING CLASSES                                               ║
║    ✓ Added CTrade, CPositionInfo, CSymbolInfo, CAccountInfo    ║
║    ✓ Set expert magic number via _trade.SetExpertMagicNumber()  ║
║                                                                  ║
║ 4. ORDER/POSITION MODEL                                          ║
║    ✓ OrderSend() → _trade.PositionOpen()                        ║
║    ✓ OrderClose() → _trade.PositionClose()                      ║
║    ✓ OrdersTotal() → PositionsTotal()                          ║
║    ✓ OrderSelect() → _positionInfo.SelectByIndex()              ║
║    ✓ OrderType() → _positionInfo.PositionType()                 ║
║    ✓ OP_BUY/OP_SELL → POSITION_TYPE_BUY/POSITION_TYPE_SELL    ║
║    ✓ OrderProfit() → _positionInfo.Profit()                     ║
║    ✓ OrderLots() → _positionInfo.Volume()                       ║
║    ✓ OrderOpenPrice() → _positionInfo.PriceOpen()               ║
║    ✓ OrderStopLoss() → _positionInfo.StopLoss()                 ║
║    ✓ OrderComment() → _positionInfo.Comment()                   ║
║                                                                  ║
║ 5. MARKET INFORMATION                                            ║
║    ✓ MarketInfo() → SymbolInfoDouble(), SymbolInfoInteger()   ║
║    ✓ Ask/Bid → _symbolInfo.Ask(), _symbolInfo.Bid()             ║
║    ✓ MODE_DIGITS → SYMBOL_DIGITS                               ║
║    ✓ MODE_MARGINREQUIRED → OrderCalcMargin()                   ║
║                                                                  ║
║ 6. ACCOUNT INFORMATION                                           ║
║    ✓ AccountBalance() → _accountInfo.Balance()                  ║
║    ✓ AccountEquity() → _accountInfo.Equity()                    ║
║    ✓ AccountMargin() → _accountInfo.Margin()                    ║
║    ✓ AccountFreeMargin() → _accountInfo.FreeMargin()            ║
║    ✓ AccountFreeMarginCheck() → OrderCalcMargin()              ║
║                                                                  ║
║ 7. INDICATORS                                                    ║
║    ✓ iATR() → Create handle with iATR(), read with CopyBuffer()║
║    ✓ iADX() → Create handle with iADX(), read with CopyBuffer()║
║    ✓ iMA() → Create handle with iMA(), read with CopyBuffer() ║
║    ✓ Indicators use handles and buffer arrays instead of direct║
║      function calls returning values                            ║
║    ✓ All arrays set as series with ArraySetAsSeries()          ║
║                                                                  ║
║ 8. HISTORY ACCESS                                                ║
║    ✓ OrdersHistoryTotal() → HistoryDealsTotal()                ║
║    ✓ OrderSelect(MODE_HISTORY) → HistoryDealGetTicket()        ║
║    ✓ OrderProfit() → HistoryDealGetDouble(DEAL_PROFIT)         ║
║    ✓ OrderSymbol() → HistoryDealGetString(DEAL_SYMBOL)         ║
║    ✓ Must call HistorySelect() before accessing history        ║
║                                                                  ║
║ 9. PRICE DATA                                                    ║
║    ✓ Close[0] → Copy to _closeArray[] with CopyClose()          ║
║    ✓ Open[0] → Copy to _openArray[] with CopyOpen()             ║
║    ✓ High[0] → Copy to _highArray[] with CopyHigh()             ║
║    ✓ Low[0] → Copy to _lowArray[] with CopyLow()                ║
║    ✓ MqlRates structure for complete bar data                   ║
║                                                                  ║
║ 10. TIME FUNCTIONS                                               ║
║    ✓ DayOfWeek() → MqlDateTime structure                       ║
║    ✓ Hour() → MqlDateTime structure                            ║
║    ✓ _lastTradeTime: int → datetime                             ║
║                                                                  ║
║ 11. CHART OBJECTS                                                ║
║    ✓ ObjectCreate() → ObjectCreate(0, ...)  [chart ID required]║
║    ✓ ObjectDescription() → ObjectGetString(OBJPROP_TEXT)       ║
║    ✓ ObjectSetText() → ObjectSetString(OBJPROP_TEXT)           ║
║    ✓ ObjectSet() → ObjectSetInteger(), ObjectSetDouble()       ║
║    ✓ ObjectFind() → ObjectFind(0, ...)  [chart ID required]    ║
║                                                                  ║
║ 12. ERROR HANDLING                                               ║
║    ✓ Added error checking for all CopyBuffer() calls           ║
║    ✓ Added _trade result checking with _trade.ResultRetcodeDescription()║
║    ✓ Enhanced error messages with context                       ║
║                                                                  ║
║ 13. CALENDAR INTEGRATION (COMPLETED)                             ║
║    ✓ prepareCalendar() - Fully implemented using MT5 native API║
║    ✓ getCalendarType1() - Returns "since " or "until "         ║
║    ✓ CalendarValueHistory() - Fetches events in 72-hour window ║
║    ✓ CalendarEventById() - Gets event details and importance   ║
║    ✓ CalendarCountryById() - Filters by symbol currencies      ║
║    ✓ Tracks next upcoming event and most recent past event     ║
║    ✓ Calculates time until/since events in minutes             ║
║    ✓ Filters by impact level (High/Medium/Low/Speaks)          ║
║    ✓ Speech detection using keyword matching                    ║
║    ✓ Populates all milestone variables for trading logic       ║
║                                                                  ║
║    Implementation details:                                       ║
║    • Uses CalendarEvent struct to organize event data           ║
║    • Extracts base/quote currencies from symbol name            ║
║    • 24-hour lookback and 48-hour lookahead window              ║
║    • Priority to upcoming events over past events               ║
║    • Handles cases where no events are scheduled                ║
║                                                                  ║
║ 14. CODE QUALITY IMPROVEMENTS                                    ║
║    ✓ Comprehensive inline comments explaining conversions       ║
║    ✓ Clear TODO markers for calendar integration                ║
║    ✓ Enhanced logging with descriptive messages                 ║
║    ✓ Proper error handling throughout                           ║
║    ✓ Organized code structure with function headers             ║
║                                                                  ║
║ COMPILATION NOTES:                                               ║
║ • Ensure Trade library is available in MT5 Include directory    ║
║ • All indicator handles must be valid before use                ║
║ • Array operations require proper sizing with CopyBuffer()      ║
║ • Calendar features disabled until indicator is ported          ║
║                                                                  ║
║ TESTING RECOMMENDATIONS:                                         ║
║ • Test on demo account first                                     ║
║ • Verify lot size calculations match MT4 _version                ║
║ • Check position opening/closing logic                          ║
║ • Confirm indicator values match MT4 _version                    ║
║ • Test calendar integration with EnableCalendar=true            ║
║ • Verify calendar events _display correctly in HUD               ║
║ • Check trading restrictions near high-impact news              ║
║ • Test with different impact level combinations                 ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
*/
