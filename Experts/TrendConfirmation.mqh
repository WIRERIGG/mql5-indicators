//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef TREND_CONFIRMATION_MQH
#define TREND_CONFIRMATION_MQH
#include "drawRange.mqh"

//+------------------------------------------------------------------+
//| Standalone Compilation Support                                   |
//| Declare ATR variables when parent doesn't provide them           |
//+------------------------------------------------------------------+
#ifndef PARENT_DECLARED
   // ATR variables for Supertrend indicator
   double ATRMultiplier1 = 3.0;
   int ATRPeriod1 = 10;
   int ATRMaxBars = 1000;
#endif

// Define a structure to hold signal states
struct SignalState
  {
   bool              bullish;
   bool              bearish;
  };

// Global variable to hold the last signal states
SignalState g_lastSignalState = {false, false};

input ENUM_APPLIED_PRICE appliedPrice = PRICE_OPEN; // Price type for RSI and EMA
input int lookBackPeriod = 1; // Number of bars to look back for local highs/lows
input int emaPeriod = 8; // EMA calculation period
input int arrowSize = 4; // Size of the arrow
input double arrowOffsetAbove = 100; // Distance above the high of the candle for bearish signal
input double arrowOffsetBelow = 100; // Distance below the low of the candle for bullish signal
input int cciPeriod = 14; // CCI calculation period

// RSI Indicator parameters:
input int rsiPeriod = 14; // RSI period


// ATR parameters (ATRMultiplier1, ATRPeriod1, ATRMaxBars) are input variables defined in main EA file

// Stochastic Indicator parameters:
input int stochasticKPeriod = 14; // Stochastic %K period
input int stochasticDPeriod = 3; // Stochastic %D period
input int stochasticSlowing = 1; // Stochastic slowing







//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TrendConfirmation()
  {
   static bool lastSignalBullish = false;
   static bool lastSignalBearish = false;

   int globalSignal = 0; // 1 for bullish, -1 for bearish, 0 for no signal

   SignalState currentSignal = {false, false};
// Get the trend signal from TrendDetection()
   int trendSignal = TrendDetection();

   int emaHandle = iMA(_Symbol, PERIOD_M5, emaPeriod, 0, MODE_EMA, appliedPrice);
   int rsiHandle = iRSI(_Symbol, PERIOD_M5, rsiPeriod, appliedPrice);
   int cciHandle = iCCI(_Symbol, PERIOD_M5, cciPeriod, appliedPrice);
   int stochasticHandle = iStochastic(_Symbol, PERIOD_M5, stochasticKPeriod, stochasticDPeriod, stochasticSlowing, MODE_SMA, STO_LOWHIGH);
   int MT5_SUPERTREND1_handle = iCustom(_Symbol, PERIOD_M5, "MT5 SUPERTREND1",
      "MT5 SUPERTREND",  // IndicatorName
      ATRMultiplier1,     // ATRMultiplier
      ATRPeriod1,         // ATRPeriod
      ATRMaxBars,         // ATRMaxBars
      0,                  // Shift
      false,              // EnableNotifications
      true);              // EnableSignalDots

   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double emaValues[], rsiValues[], cciValues[], stochasticMain[], stochasticSignal[], MT5SUPERTREND1Values[], priceHighs[], priceLows[];
   ArraySetAsSeries(emaValues, true);
   ArraySetAsSeries(rsiValues, true);
   ArraySetAsSeries(cciValues, true);
   ArraySetAsSeries(stochasticMain, true);
   ArraySetAsSeries(stochasticSignal, true);
   ArraySetAsSeries(MT5SUPERTREND1Values, true);
   ArraySetAsSeries(priceHighs, true);
   ArraySetAsSeries(priceLows, true);

   if(CopyBuffer(emaHandle, 0, 0, lookBackPeriod + 1, emaValues) <= 0 ||
      CopyHigh(_Symbol, PERIOD_CURRENT, 0, lookBackPeriod + 1, priceHighs) <= 0 ||
      CopyLow(_Symbol, PERIOD_CURRENT, 0, lookBackPeriod + 1, priceLows) <= 0 ||
      CopyBuffer(emaHandle, 0, 0, lookBackPeriod + 1, emaValues) <= 0 ||
      CopyBuffer(rsiHandle, 0, 0, lookBackPeriod + 1, rsiValues) <= 0 ||
      CopyBuffer(cciHandle, 0, 0, lookBackPeriod + 1, cciValues) <= 0 ||
      CopyBuffer(stochasticHandle, 0, 0, lookBackPeriod + 1, stochasticMain) <= 0 ||
      CopyBuffer(stochasticHandle, 1, 0, lookBackPeriod + 1, stochasticSignal) <= 0 ||
      CopyBuffer(MT5_SUPERTREND1_handle, 0, 0, lookBackPeriod + 1, MT5SUPERTREND1Values) <= 0)
     {

      Print("Failed to copy data.");
      return;
     }

// Check for trend agreement among indicators
   for(int i = 1; i <= lookBackPeriod; i++)
     {


      bool currentAskAboveEMA = currentAsk > emaValues[i]; // For Bullish Signals
      bool currentBidBelowEMA = currentBid < emaValues[i]; // For Bearish Signals

      bool isBullishSupertrend =  currentAsk < MT5SUPERTREND1Values[i];
      bool isBearishSupertrend = currentBid > MT5SUPERTREND1Values[i];


      bool bullishSignal = currentAskAboveEMA && cciValues[i] > 120 && stochasticMain[i] > stochasticSignal[i] && rsiValues[i] > 20 && rsiValues[i] < 70 && isBearishSupertrend;
      bool bearishSignal = currentBidBelowEMA && cciValues[i] < -120 && stochasticMain[i] < stochasticSignal[i] && rsiValues[i] > 20 && rsiValues[i] < 70 && isBullishSupertrend;

      // Enhance signal confirmation with globalSignal
      bullishSignal = bullishSignal && (globalSignal == 1 || trendSignal == 1);
      bearishSignal = bearishSignal && (globalSignal == -1 || trendSignal == -1);

      // Enhanced Print statement with Supertrend checks
      //   Print("Iteration: ", i,
      //           ", CurrentAsk: ", currentAsk,
      //           ", CurrentBid: ", currentBid,
      //           ", CurrentAskAboveEMA: ", currentAskAboveEMA,
      //           ", CurrentBidBelowEMA: ", currentBidBelowEMA,
      //           ", IsBullishSupertrend: ", isBullishSupertrend,
      //           ", IsBearishSupertrend: ", isBearishSupertrend,
      //           ", BullishSignal: ", bullishSignal,
      //           ", BearishSignal: ", bearishSignal,
      //           ", EMAValue: ", emaValues[i],
      //           ", CCIValue: ", cciValues[i],
      //           ", StochasticMain: ", stochasticMain[i],
      //           ", StochasticSignal: ", stochasticSignal[i],
      //           ", RSIValue: ", rsiValues[i],
      //           ", SupertrendValue: ", MT5SUPERTREND1Values[i]);
      // Determine the current signal based on your conditions
      if(bullishSignal)
        {
         currentSignal.bullish = true;
        }
      else
         if(bearishSignal)
           {
            currentSignal.bearish = true;
           }

      if(bullishSignal && !lastSignalBullish)
        {
         lastSignalBullish = true;
         lastSignalBearish = false;
         double arrowPosition = priceLows[i] - arrowOffsetBelow * _Point;
         string arrowName = "BullishArrow_" + IntegerToString(GetTickCount());
         datetime barTime = iTime(_Symbol, PERIOD_CURRENT, i);
         if(ObjectCreate(0, arrowName, OBJ_ARROW_UP, 0, barTime, arrowPosition))
           {
            ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, arrowSize);
           }
        }
      else
         if(bearishSignal && !lastSignalBearish)
           {
            lastSignalBullish = false;
            lastSignalBearish = true;
            double arrowPosition = priceHighs[i] + arrowOffsetAbove * _Point;
            string arrowName = "BearishArrow_" + IntegerToString(GetTickCount());
            datetime barTime = iTime(_Symbol, PERIOD_CURRENT, i);
            if(ObjectCreate(0, arrowName, OBJ_ARROW_DOWN, 0, barTime, arrowPosition))
              {
               ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrRed);
               ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, arrowSize);
              }
           }
     }
     
   g_lastSignalState = currentSignal;
   
// Release handles to the indicators used
   IndicatorRelease(emaHandle);
   IndicatorRelease(rsiHandle);
   IndicatorRelease(cciHandle);
   IndicatorRelease(stochasticHandle);
   IndicatorRelease(MT5_SUPERTREND1_handle);

  }
input int stochasticUpperLevel = 80; // Overbought level for Stochastic
input int stochasticLowerLevel = 20; // Adjusted Oversold level for Stochastic

//+------------------------------------------------------------------------------------------+
//| Enhanced Function to calculate percentage move with option to choose reference price     |
//+------------------------------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculatePercentageMove(ENUM_TIMEFRAMES timeframe, bool compareWithOpen = false)
  {
   double referencePrice = compareWithOpen ? iOpen(_Symbol, timeframe, 0) : iClose(_Symbol, timeframe, 1);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID); // Assuming bid price as current price for selling scenarios

// Validate reference price
   if(referencePrice == 0 || currentPrice == 0)
     {
      Print("CalculatePercentageMove: Invalid market data.");
      return 0; // Market data is unavailable or invalid
     }

// Calculate and return the percentage move, formatted to 2 decimal places
   double percentageMove = (currentPrice - referencePrice) / referencePrice * 100;
   return NormalizeDouble(percentageMove, 2); // Normalize to 2 decimal places for consistency
  }


//+------------------------------------------------------------------+



// Corrected function to accept arrays by reference
bool DetectBearishDivergence(double &rsiValues[], double &priceHighs[], int lookBack)
  {
   int highestPriceIndex = ArrayMaximum(priceHighs, 0, lookBack);
   int highestRsiIndex = ArrayMaximum(rsiValues, 0, lookBack);

   if(highestPriceIndex < 0 || highestRsiIndex < 0 || highestPriceIndex == highestRsiIndex)
     {
      return false; // Error or no divergence
     }

   double highestPrice = priceHighs[highestPriceIndex];
   double highestRsi = rsiValues[highestRsiIndex];

// Look for lower highs in RSI compared to price
   for(int i = 0; i < lookBack; i++)
     {
      if(i != highestPriceIndex && priceHighs[i] > highestPrice && rsiValues[i] < highestRsi)
        {
         return true; // Bearish divergence found
        }
     }
   return false; // No bearish divergence found
  }

// Corrected function signature to accept arrays by reference
bool DetectBullishDivergence(double &rsiValues[], double &priceLows[], int lookBack)
  {
   int lowestPriceIndex = ArrayMinimum(priceLows, 0, lookBack);
   int lowestRsiIndex = ArrayMinimum(rsiValues, 0, lookBack);

   if(lowestPriceIndex < 0 || lowestRsiIndex < 0 || lowestPriceIndex == lowestRsiIndex)
      return false; // Error or no divergence

   double lowestPrice = priceLows[lowestPriceIndex];
   double lowestRsi = rsiValues[lowestRsiIndex];

// Look for higher lows in RSI compared to price
   for(int i = 0; i < lookBack; i++)
     {
      if(i != lowestPriceIndex && priceLows[i] < lowestPrice && rsiValues[i] > lowestRsi)
        {
         return true;
        }
     }
   return false;
  }


//+------------------------------------------------------------------+
// Calculate the average volume over the last 'periods' bars.
double CalculateAverageVolume(int periods)
  {
   long volumes[]; // Changed from double to long
   ArraySetAsSeries(volumes, true); // Ensure the array is processed as a series
// Use CopyTickVolume to copy tick volumes for the last 'periods' bars
   int copied = CopyTickVolume(_Symbol, _Period, 0, periods, volumes);
   if(copied <= 0)
      return -1; // Return -1 in case of an error

   double sum = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      sum += (double)volumes[i]; // Explicitly cast long to double
     }
   if(copied > 0)
      return sum / (double)copied; // Ensure division is performed in double precision
   return -1;
  }
//+------------------------------------------------------------------+




// Implementation of the ZigzagTrend function
int ZigzagTrend(const string symbol, const ENUM_TIMEFRAMES timeframe, const int inpDepth, const int inpDeviation, const int inpBackstep, const bool showArrows)
  {
   int bufferIndex = 7; // Assuming bufferIndex 7 is used for signals in the ZigZagColor indicator
   double signalValue = iCustom(symbol, timeframe, "ZigZagColor", inpDepth, inpDeviation, inpBackstep, showArrows, bufferIndex, 0);

   if(signalValue == 1)
     {
      // Bullish signal detected
      return 1;
     }
   else
      if(signalValue == -1)
        {
         // Bearish signal detected
         return -1;
        }

// No new signal
   return 0;
  }
//+------------------------------------------------------------------+

#endif // TREND_CONFIRMATION_MQH
