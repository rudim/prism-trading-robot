//+------------------------------------------------------------------+
//|                                             PrismPositions.mqh  |
//|                              Position analysis and management    |
//+------------------------------------------------------------------+
#property copyright "Rudi & Claude"

#include "PrismTypes.mqh"
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Analyze all open positions and calculate statistics              |
//+------------------------------------------------------------------+
void AnalyzePositions(PositionStats &stats,
                     MarketConditions &conditions,
                     int magic,
                     int magicBackup,
                     double atr,
                     double tradeSpace)
{
   stats.Reset();
   conditions.nearLongPosition = false;
   conditions.nearShortPosition = false;

   CPositionInfo posInfo;
   CSymbolInfo symInfo;
   symInfo.Name(_Symbol);
   symInfo.RefreshRates();

   double ask = symInfo.Ask();
   double bid = symInfo.Bid();

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!posInfo.SelectByIndex(i))
         continue;

      if(posInfo.Symbol() == _Symbol &&
         (posInfo.Magic() == magic || posInfo.Magic() == magicBackup))
      {
         stats.totalTrades++;

         // Backup trades are identified by magic number
         if(posInfo.Magic() == magicBackup)
            stats.totalBackupTrades++;

         if(posInfo.StopLoss() == 0)
         {
            // Check proximity to current price
            if(posInfo.PositionType() == POSITION_TYPE_BUY &&
               MathAbs(posInfo.PriceOpen() - ask) < atr * tradeSpace)
               conditions.nearLongPosition = true;
            else if(posInfo.PositionType() == POSITION_TYPE_SELL &&
                    MathAbs(posInfo.PriceOpen() - bid) < atr * tradeSpace)
               conditions.nearShortPosition = true;

            // Accumulate lot sizes
            if(posInfo.PositionType() == POSITION_TYPE_BUY)
            {
               stats.buyLots += posInfo.Volume();
               stats.openType = (int)POSITION_TYPE_BUY;
            }
            else if(posInfo.PositionType() == POSITION_TYPE_SELL)
            {
               stats.sellLots += posInfo.Volume();
               stats.openType = (int)POSITION_TYPE_SELL;
            }

            // Accumulate profit/loss
            if(posInfo.Profit() > 0)
               stats.totalProfit += posInfo.Profit();
            else
               stats.totalLoss += posInfo.Profit();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate historical profit from closed deals                    |
//+------------------------------------------------------------------+
double CalculateHistoricalProfit(int magic, int magicBackup, int queryHistory, int &symbolHistory)
{
   symbolHistory = 0;
   double totalHistoryProfit = 0;

   if(!HistorySelect(0, TimeCurrent()))
   {
      Print("Error selecting history: ", GetLastError());
      return 0;
   }

   int totalDeals = HistoryDealsTotal();
   int counted = 0;
   int maxHistory = 100;

   for(int i = totalDeals - 1; i >= 0 && counted < maxHistory; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
         (HistoryDealGetInteger(ticket, DEAL_MAGIC) == magic ||
          HistoryDealGetInteger(ticket, DEAL_MAGIC) == magicBackup) &&
         HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         if(symbolHistory >= queryHistory)
            break;

         totalHistoryProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         symbolHistory++;
         counted++;
      }
   }

   return totalHistoryProfit;
}

//+------------------------------------------------------------------+
//| Set pip point value based on symbol digits                       |
//+------------------------------------------------------------------+
double GetPipPoint()
{
   int symbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(symbolDigits == 3 || symbolDigits == 2)
      return 0.010;
   else if(symbolDigits == 5 || symbolDigits == 4)
      return 0.00010;
   else
      return 0.00010;
}
