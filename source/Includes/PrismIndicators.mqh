//+------------------------------------------------------------------+
//|                                            PrismIndicators.mqh  |
//|                              Indicator management and reading    |
//+------------------------------------------------------------------+
#property copyright "Rudi & Claude"

#include "PrismTypes.mqh"

//+------------------------------------------------------------------+
//| Indicator handles structure                                      |
//+------------------------------------------------------------------+
struct IndicatorHandles
{
   int ATR;
   int ADX;
   int MA1;
   int MA2;

   void Reset()
   {
      ATR = INVALID_HANDLE;
      ADX = INVALID_HANDLE;
      MA1 = INVALID_HANDLE;
      MA2 = INVALID_HANDLE;
   }

   bool IsValid()
   {
      return (ATR != INVALID_HANDLE &&
              ADX != INVALID_HANDLE &&
              MA1 != INVALID_HANDLE &&
              MA2 != INVALID_HANDLE);
   }

   void Release()
   {
      if(ATR != INVALID_HANDLE) IndicatorRelease(ATR);
      if(ADX != INVALID_HANDLE) IndicatorRelease(ADX);
      if(MA1 != INVALID_HANDLE) IndicatorRelease(MA1);
      if(MA2 != INVALID_HANDLE) IndicatorRelease(MA2);
   }
};

//+------------------------------------------------------------------+
//| Initialize all indicator handles                                 |
//+------------------------------------------------------------------+
bool InitializeIndicators(IndicatorHandles &handles,
                          int atrPeriod,
                          int adxPeriod,
                          int ma1Period,
                          int ma2Period,
                          int maShift)
{
   handles.ATR = iATR(_Symbol, PERIOD_CURRENT, atrPeriod);
   handles.ADX = iADX(_Symbol, PERIOD_CURRENT, adxPeriod);
   handles.MA1 = iMA(_Symbol, PERIOD_M5, ma1Period, maShift, MODE_SMMA, PRICE_MEDIAN);
   handles.MA2 = iMA(_Symbol, PERIOD_M5, ma2Period, maShift, MODE_SMMA, PRICE_MEDIAN);

   if(!handles.IsValid())
   {
      Print("ERROR: Failed to create indicator handles");
      Print("ATR Handle: ", handles.ATR);
      Print("ADX Handle: ", handles.ADX);
      Print("MA1 Handle: ", handles.MA1);
      Print("MA2 Handle: ", handles.MA2);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Read all indicator values into structure                         |
//+------------------------------------------------------------------+
bool ReadIndicatorValues(const IndicatorHandles &handles,
                        IndicatorValues &values,
                        int atrShift,
                        int adxShift,
                        int adxShiftCheck,
                        int maShift,
                        int maShiftCheck)
{
   // Prepare buffers
   double bufferATR[];
   double bufferADXMain[];
   double bufferADXPlusDI[];
   double bufferADXMinusDI[];
   double bufferMA1[];
   double bufferMA2[];

   ArraySetAsSeries(bufferATR, true);
   ArraySetAsSeries(bufferADXMain, true);
   ArraySetAsSeries(bufferADXPlusDI, true);
   ArraySetAsSeries(bufferADXMinusDI, true);
   ArraySetAsSeries(bufferMA1, true);
   ArraySetAsSeries(bufferMA2, true);

   // Copy ATR
   if(CopyBuffer(handles.ATR, 0, atrShift, 1, bufferATR) < 1)
   {
      Print("Error copying ATR buffer: ", GetLastError());
      return false;
   }
   values.ATR = bufferATR[0];

   // Copy ADX buffers
   int adxBarsNeeded = adxShift + adxShiftCheck + 1;
   if(CopyBuffer(handles.ADX, MAIN_LINE, adxShift, adxBarsNeeded, bufferADXMain) < adxBarsNeeded)
   {
      Print("Error copying ADX Main buffer: ", GetLastError());
      return false;
   }
   if(CopyBuffer(handles.ADX, PLUSDI_LINE, adxShift, adxBarsNeeded, bufferADXPlusDI) < adxBarsNeeded)
   {
      Print("Error copying ADX +DI buffer: ", GetLastError());
      return false;
   }
   if(CopyBuffer(handles.ADX, MINUSDI_LINE, adxShift, adxBarsNeeded, bufferADXMinusDI) < adxBarsNeeded)
   {
      Print("Error copying ADX -DI buffer: ", GetLastError());
      return false;
   }

   values.ADXMain = bufferADXMain[0];
   values.ADXPlusDI = bufferADXPlusDI[0];
   values.ADXMinusDI = bufferADXMinusDI[0];
   values.ADXMainPrev = bufferADXMain[adxShiftCheck];
   values.ADXPlusDIPrev = bufferADXPlusDI[adxShiftCheck];
   values.ADXMinusDIPrev = bufferADXMinusDI[adxShiftCheck];

   // Copy MA buffers
   int maBarsNeeded = maShift + maShiftCheck + 1;
   if(CopyBuffer(handles.MA1, 0, maShift, maBarsNeeded, bufferMA1) < maBarsNeeded)
   {
      Print("Error copying MA1 buffer: ", GetLastError());
      return false;
   }
   if(CopyBuffer(handles.MA2, 0, maShift, maBarsNeeded, bufferMA2) < maBarsNeeded)
   {
      Print("Error copying MA2 buffer: ", GetLastError());
      return false;
   }

   values.MA1Current = bufferMA1[0];
   values.MA1Previous = bufferMA1[maShiftCheck];
   values.MA2Current = bufferMA2[0];
   values.MA2Previous = bufferMA2[maShiftCheck];

   // Calculate trend strength
   values.trendStrength = values.MA1Current - values.MA1Previous;

   return true;
}
