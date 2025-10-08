#ifndef IS_CONSOLIDATING_MQH
#define IS_CONSOLIDATING_MQH

#include  "DisplayTrendAnalysis.mqh"

// Enumeration for market trend
enum MarketTrend
  {
   TREND_BULLISH = 1,
   TREND_BEARISH = -1,
   TREND_NEUTRAL = 0
  };





// Function to determine if the market is consolidating
int IsConsolidating(datetime time1, double price1, datetime time2, double price2)
{
    // Calculate the trading range
    double tradingRange = NormalizeDouble(fabs(price1 - price2), 5);

    // Determine trade signal based on trading range
    return (tradingRange > 0.003) ? 1 : -1;
}


int UpdateTradingPauseMessage(int consolidationSignal) {
    static int lastConsolidationSignal = 0; // Static variable to track the last consolidation signal
    string objName = "TradingPausedMessage";

    // Determine the consolidation status for the last H1 candle
    datetime time1 = iTime(_Symbol, PERIOD_H1, 1);  // Time of the second last H1 candle
    datetime time2 = iTime(_Symbol, PERIOD_H1, 0);  // Time of the last H1 candle
    double price1 = iHigh(_Symbol, PERIOD_H1, 1);  // High of the second last H1 candle
    double price2 = iLow(_Symbol, PERIOD_H1, 1);   // Low of the second last H1 candle

    // Check if the object exists. If it does not exist, create it.
    if (ObjectFind(0, objName) == -1) {
        if (!ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0)) {
            Print("Error creating label: ", objName, ", Error code: ", GetLastError());
            return 0; // Exit if unable to create the object
        }
        // Set object properties if created for the first time
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 8);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 403); // Positioning as per the original function
    }

    // Determine the message based on the consolidation signal
    string message;
    color msgColor;

    // If the market is consolidating (signal == -1), show the "Trading Paused" message.
    // If not consolidating (signal == 1), we still want to show the "Trading Active" message for clarity.
    if (consolidationSignal == -1) {
        message = "Trading Paused due to Consolidation";
        msgColor = clrRed; // Use red color to indicate trading is paused
    } else {
        message = "Trading Active - No Consolidation Detected";
        msgColor = clrLime; // Use lime color to indicate trading is active
    }

    // Update the label with the determined message and color
    ObjectSetString(0, objName, OBJPROP_TEXT, message);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, msgColor);

    // Determine the return signal based on consolidation status change
    int returnSignal = 0; // Default return value indicating no change

    // Check if the consolidation status has changed since the last check
    if (consolidationSignal != lastConsolidationSignal) {
        // Update the lastConsolidationSignal for the next call
        lastConsolidationSignal = consolidationSignal;

        // Determine the return signal based on the current consolidation signal
        if (consolidationSignal == -1) {
            returnSignal = -1; // Indicate consolidation (trading paused)
        } else if (consolidationSignal == 1) {
            returnSignal = 1; // Indicate no consolidation (trading active)
        }
    }

    // Return the signal
    return returnSignal;
}


//+------------------------------------------------------------------------------------------+
//+------------------------------------------------------------------------------------------+
//+------------------------------------------------------------------------------------------+
//+------------------------------------------------------------------------------------------+
//+------------------------------------------------------------------------------------------+
//+------------------------------------------------------------------------------------------+
//+------------------------------------------------------------------------------------------+
//+------------------------------------------------------------------------------------------+

#endif // IS_CONSOLIDATING_MQH

