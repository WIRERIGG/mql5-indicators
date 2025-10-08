#ifndef DRAWRANGE_MQH
#define DRAWRANGE_MQH

#include <ChartObjects\ChartObjectsLines.mqh>
#include "TrendConfirmation.mqh"

// Constants for object names
const string RANGE_RECTANGLE = "RangeRectangle";
const string MIDPOINT_LINE = "MidpointLine";

// Global variables for range data
double rangeHigh, rangeLow;
datetime rangeStartTime, rangeEndTime;

// EMA Handles for M15 and H1
// These are expected to be declared in the parent EA file
extern int ema5_handle;
extern int ema8_handle;
extern int ema13_handle;
extern int ema5_H1_handle;
extern int ema8_H1_handle;
extern int ema13_H1_handle;

// Function to draw trading range
int drawRange(datetime time1, double price1, datetime time2, double price2) {
   // Delete existing objects
   ObjectDelete(0, RANGE_RECTANGLE);
   ObjectDelete(0, MIDPOINT_LINE);

   // Create rectangle
   if (!ObjectCreate(0, RANGE_RECTANGLE, OBJ_RECTANGLE, 0, time1, price1, time2, price2)) {
      Print("Error creating range rectangle: ", GetLastError());
      return 0;
   }

   // Determine trend signal
   int trendSignal = TrendDetection();

   // Set rectangle color based on trend
   color rectangleColor = clrYellow;
   if (trendSignal == 1) {
      rectangleColor = clrLime; // Bullish trend
   } else if (trendSignal == -1) {
      rectangleColor = clrRed; // Bearish trend
   }

   ObjectSetInteger(0, RANGE_RECTANGLE, OBJPROP_COLOR, rectangleColor);
   ObjectSetInteger(0, RANGE_RECTANGLE, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, RANGE_RECTANGLE, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, RANGE_RECTANGLE, OBJPROP_BACK, true);
   ObjectSetInteger(0, RANGE_RECTANGLE, OBJPROP_FILL, false);

   // Calculate and draw midpoint line
   double midpoint = (price1 + price2) / 2;
   if (!ObjectCreate(0, MIDPOINT_LINE, OBJ_TREND, 0, time1, midpoint, time2, midpoint)) {
      Print("Error creating midpoint line: ", GetLastError());
      return 0;
   }

   // Set line properties
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
   color lineColor = currentPrice > midpoint ? clrLime : clrRed;
   ObjectSetInteger(0, MIDPOINT_LINE, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, MIDPOINT_LINE, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, MIDPOINT_LINE, OBJPROP_RAY_RIGHT, false);

   // Determine final trading signal
   if (lineColor == clrLime && trendSignal == 1) return 1;  // Bullish
   if (lineColor == clrRed && trendSignal == -1) return -1; // Bearish
   return 0; // No clear signal
}

// EMA-based trend detection
#ifndef TREND_DETECTION_DEFINED
#define TREND_DETECTION_DEFINED
int TrendDetection() {
   double ema5_M15[1], ema8_M15[1], ema13_M15[1];
   double ema5_H1[1], ema8_H1[1], ema13_H1[1];

   // Copy EMA data for M15
   if (CopyBuffer(ema5_handle, 0, 0, 1, ema5_M15) <= 0 ||
       CopyBuffer(ema8_handle, 0, 0, 1, ema8_M15) <= 0 ||
       CopyBuffer(ema13_handle, 0, 0, 1, ema13_M15) <= 0) {
      Print("Error copying EMA data for M15: ", GetLastError());
      return 0;
   }

   // Copy EMA data for H1
   if (CopyBuffer(ema5_H1_handle, 0, 0, 1, ema5_H1) <= 0 ||
       CopyBuffer(ema8_H1_handle, 0, 0, 1, ema8_H1) <= 0 ||
       CopyBuffer(ema13_H1_handle, 0, 0, 1, ema13_H1) <= 0) {
      Print("Error copying EMA data for H1: ", GetLastError());
      return 0;
   }

   // Determine trend signal for M15
   int trendSignal_M15 = NormalizeSignal(Sign(ema5_M15[0] - ema8_M15[0]) +
                                         Sign(ema5_M15[0] - ema13_M15[0]));

   // Determine trend signal for H1
   int trendSignal_H1 = NormalizeSignal(Sign(ema5_H1[0] - ema8_H1[0]) +
                                        Sign(ema5_H1[0] - ema13_H1[0]));

   // Combine signals
   return (trendSignal_M15 == trendSignal_H1) ? trendSignal_M15 : 0;
}
#endif // TREND_DETECTION_DEFINED

// Find range data
void FindRange(string symbol, ENUM_TIMEFRAMES timeframe, int startPeriod, int endPeriod) {
   rangeHigh = 0;
   rangeLow = DBL_MAX;

   for (int i = startPeriod; i <= endPeriod; i++) {
      double high = iHigh(symbol, timeframe, i);
      double low = iLow(symbol, timeframe, i);
      if (high > rangeHigh) rangeHigh = high;
      if (low < rangeLow) rangeLow = low;
   }

   rangeStartTime = iTime(symbol, timeframe, endPeriod);
   rangeEndTime = iTime(symbol, timeframe, startPeriod);
}

// Normalize signal to -1, 0, or 1
int NormalizeSignal(int sum) {
   return (sum > 0) - (sum < 0);
}

// Utility to return sign of a value
int Sign(double value) {
   return (value > 0) - (value < 0);
}

#endif // DRAWRANGE_MQH
