//+------------------------------------------------------------------+
//|                                           PrismRiskManager.mqh  |
//|                                   Lot size and basket cap logic  |
//+------------------------------------------------------------------+
#property copyright "Rudi & Claude"

#include "PrismTypes.mqh"
#include <Trade\PositionInfo.mqh>

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

//+------------------------------------------------------------------+
//| rm_013: Returns the open time of the oldest backup trade for     |
//| this EA on the current symbol. Backup trades are identified by   |
//| "Backup" in the position comment. Returns 0 when no backup       |
//| trades are currently open. If the first backup closes and a      |
//| newer one is open, the clock resets to the newer trade's time.   |
//+------------------------------------------------------------------+
datetime GetOldestBackupOpenTime(int magic)
{
   datetime oldest = 0;
   CPositionInfo pos;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != magic) continue;
      if(StringFind(pos.Comment(), "Backup", 0) < 0) continue;

      datetime openTime = (datetime)pos.Time();
      if(oldest == 0 || openTime < oldest)
         oldest = openTime;
   }
   return oldest;
}

//+------------------------------------------------------------------+
//| rm_013: Returns the open time of the oldest position of any      |
//| type for this EA on the current symbol. Returns 0 when no        |
//| positions are open.                                              |
//+------------------------------------------------------------------+
datetime GetOldestPositionOpenTime(int magic)
{
   datetime oldest = 0;
   CPositionInfo pos;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol() != _Symbol || pos.Magic() != magic) continue;

      datetime openTime = (datetime)pos.Time();
      if(oldest == 0 || openTime < oldest)
         oldest = openTime;
   }
   return oldest;
}

//+------------------------------------------------------------------+
//| rm_013: Backup drawdown timer check.                             |
//| Returns true when the oldest backup trade has been open for at   |
//| least thresholdMinutes AND the basket is in net loss.            |
//| Only logs and returns true once the threshold is breached.       |
//| Caller is responsible for closing positions.                     |
//+------------------------------------------------------------------+
bool CheckBackupDrawdownTimer(int magic, double netBasketPnL,
                              bool activate, int thresholdMinutes)
{
   if(!activate) return false;

   datetime oldestBackup = GetOldestBackupOpenTime(magic);
   if(oldestBackup == 0) return false;

   long elapsedMinutes = (TimeCurrent() - oldestBackup) / 60;
   if(elapsedMinutes < thresholdMinutes) return false;

   if(netBasketPnL >= 0) return false;   // basket recovering — do not interrupt

   datetime deadline = oldestBackup + (datetime)(thresholdMinutes * 60);
   Print("BACKUP_TIMEOUT: Backup open since ", TimeToString(oldestBackup),
         ". Deadline was ", TimeToString(deadline),
         ". Elapsed: ", elapsedMinutes, " min",
         ". Net PnL: ", DoubleToString(netBasketPnL, 2),
         ". Closing all positions.");
   return true;
}

//+------------------------------------------------------------------+
//| rm_013: Max trade time check.                                    |
//| Returns true when the oldest open position has been open for at  |
//| least thresholdMinutes, regardless of basket P&L.               |
//| Caller is responsible for closing positions.                     |
//+------------------------------------------------------------------+
bool CheckMaxTradeTime(int magic, bool enable, int thresholdMinutes)
{
   if(!enable) return false;

   datetime oldestPos = GetOldestPositionOpenTime(magic);
   if(oldestPos == 0) return false;

   long elapsedMinutes = (TimeCurrent() - oldestPos) / 60;
   if(elapsedMinutes < thresholdMinutes) return false;

   datetime deadline = oldestPos + (datetime)(thresholdMinutes * 60);
   Print("MAX_TRADE_TIME: Oldest position open since ", TimeToString(oldestPos),
         ". Deadline was ", TimeToString(deadline),
         ". Elapsed: ", elapsedMinutes, " min",
         ". Closing all positions.");
   return true;
}
