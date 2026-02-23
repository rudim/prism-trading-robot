//+------------------------------------------------------------------+
//|                                           PrismRiskManager.mqh  |
//|                                   Lot size and basket cap logic  |
//+------------------------------------------------------------------+
#property copyright "Rudi & Claude"

#include "PrismTypes.mqh"

//--- Leverage normalisation state (set once in InitLeverageNormalisation)
int g_accountLeverage = 0;

//+------------------------------------------------------------------+
//| Initialise leverage normalisation. Call once from OnInit().      |
//| Reads and stores the account leverage. Prints a warning when the |
//| account leverage exceeds warnAbove — regardless of enable flag.  |
//+------------------------------------------------------------------+
void InitLeverageNormalisation(bool enabled, int warnAbove)
{
   g_accountLeverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);

   if(g_accountLeverage > warnAbove)
      Print("WARNING: Account leverage 1:", g_accountLeverage,
            " exceeds warning threshold 1:", warnAbove,
            ". Lots will", enabled ? "" : " NOT",
            " be normalised (EnableLeverageNormalisation=",
            enabled ? "true" : "false", ").");
}

//+------------------------------------------------------------------+
//| Returns the leverage normalisation factor (0 < factor <= 1.0).  |
//| Factor = 1.0 when account leverage <= referenceLeverage (no     |
//| scaling needed). Normalisation only scales DOWN, never UP.       |
//| When disabled, always returns 1.0.                               |
//+------------------------------------------------------------------+
double GetLeverageNormalisationFactor(bool enabled, int referenceLeverage)
{
   if(!enabled || g_accountLeverage <= 0 || g_accountLeverage <= referenceLeverage)
      return 1.0;

   return MathMin(1.0, (double)referenceLeverage / (double)g_accountLeverage);
}

//+------------------------------------------------------------------+
//| Returns the current effective leverage across all open positions.|
//| Formula: (totalLots / baseLotSize) x accountLeverage            |
//|          x (marginRequirement / equity)                         |
//| Returns 0.0 when no positions are open or inputs are invalid.   |
//+------------------------------------------------------------------+
double GetEffectiveLeverage(const PositionStats &positions,
                            double marginRequirement,
                            double accountEquity,
                            double baseLotSize)
{
   if(accountEquity <= 0 || marginRequirement <= 0 || baseLotSize <= 0 || g_accountLeverage <= 0)
      return 0.0;

   double totalLots = positions.buyLots + positions.sellLots;
   if(totalLots <= 0)
      return 0.0;

   return (totalLots / baseLotSize) * g_accountLeverage * (marginRequirement / accountEquity);
}

//+------------------------------------------------------------------+
//| Returns true if opening another position is allowed.             |
//| Blocks when effective leverage >= maxEffectiveLeverage.          |
//| When disabled, always returns true.                              |
//+------------------------------------------------------------------+
bool IsEffectiveLeverageSafe(const PositionStats &positions,
                             double marginRequirement,
                             double accountEquity,
                             double baseLotSize,
                             bool enabled,
                             int maxEffectiveLeverage)
{
   if(!enabled)
      return true;

   double effLev = GetEffectiveLeverage(positions, marginRequirement, accountEquity, baseLotSize);
   if(effLev >= (double)maxEffectiveLeverage)
   {
      Print("Skipping trade: effective leverage ", DoubleToString(effLev, 0),
            ":1 has reached limit of 1:", maxEffectiveLeverage);
      return false;
   }

   return true;
}

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
