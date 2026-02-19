//+------------------------------------------------------------------+
//|                                           PrismRiskManager.mqh  |
//|                                   Lot size and basket cap logic  |
//+------------------------------------------------------------------+
#property copyright "Rudi & Claude"

#include "PrismTypes.mqh"

//+------------------------------------------------------------------+
//| Apply per-position lot cap (regular or backup).                  |
//| Returns the capped value, never below minLots.                   |
//+------------------------------------------------------------------+
double ApplyLotCap(double rawLots,
                   double accountBalance,
                   double absoluteCap,
                   double perThousand,
                   double minLots)
{
   double dynamicCap = (accountBalance / 1000.0) * perThousand;
   double capped     = MathMin(rawLots, MathMin(absoluteCap, dynamicCap));
   return MathMax(capped, minLots);
}

//+------------------------------------------------------------------+
//| Returns true if opening lotsToOpen would keep the basket total   |
//| within the configured ceiling.                                   |
//+------------------------------------------------------------------+
bool BasketCapAllows(double currentBasketLots,
                     double lotsToOpen,
                     double accountBalance,
                     double absoluteBasketCap,
                     double basketPerThousand)
{
   double dynamicCap     = (accountBalance / 1000.0) * basketPerThousand;
   double basketCeiling  = MathMin(absoluteBasketCap, dynamicCap);
   return (currentBasketLots + lotsToOpen) <= basketCeiling;
}

//+------------------------------------------------------------------+
//| Create a chart object to track the soft stop price for a         |
//| newly opened position.  Call immediately after PositionOpen().   |
//+------------------------------------------------------------------+
void CreateSoftStopObject(ulong ticket,
                          ENUM_ORDER_TYPE orderType,
                          double entryPrice,
                          double atr,
                          bool   isBackup,
                          double atrMultiplier,
                          double backupAtrMultiplier)
{
   double mult      = isBackup ? backupAtrMultiplier : atrMultiplier;
   double stopPrice = (orderType == ORDER_TYPE_BUY)
                    ? entryPrice - atr * mult
                    : entryPrice + atr * mult;
   string objName   = "PrismSL_" + IntegerToString(ticket);

   if(ObjectCreate(0, objName, OBJ_HLINE, 0, 0, stopPrice))
   {
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrCrimson);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      ObjectSetString(0,  objName, OBJPROP_TEXT,
                      StringFormat("ATR=%.5f|%s", atr, isBackup ? "B" : "R"));
   }
}

//+------------------------------------------------------------------+
//| Returns true if the soft stop for this position has been         |
//| breached and the position should be closed.                      |
//+------------------------------------------------------------------+
bool SoftStopBreached(ulong ticket,
                      ENUM_POSITION_TYPE posType,
                      double bid,
                      double ask,
                      double profit,
                      double accountBalance,
                      bool   useATRStop,
                      double maxRiskPercent,
                      double backupMaxRiskPercent,
                      bool   isBackup)
{
   if(useATRStop)
   {
      string objName = "PrismSL_" + IntegerToString(ticket);
      if(ObjectFind(0, objName) < 0) return false;
      double stopPrice = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
      return (posType == POSITION_TYPE_BUY  && bid <= stopPrice) ||
             (posType == POSITION_TYPE_SELL && ask >= stopPrice);
   }
   else
   {
      double threshold = -(isBackup ? backupMaxRiskPercent : maxRiskPercent) * accountBalance;
      return profit < threshold;
   }
}

//+------------------------------------------------------------------+
//| Delete the soft stop chart object for a closed position.         |
//+------------------------------------------------------------------+
void DeleteSoftStopObject(ulong ticket)
{
   ObjectDelete(0, "PrismSL_" + IntegerToString(ticket));
}
