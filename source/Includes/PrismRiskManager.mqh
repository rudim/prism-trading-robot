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
