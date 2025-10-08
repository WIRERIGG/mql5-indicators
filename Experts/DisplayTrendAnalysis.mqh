#ifndef DISPLAY_TREND_ANALYSIS_MQH
#define DISPLAY_TREND_ANALYSIS_MQH

// Function to display trend analysis on the chart
void DisplayTrendAnalysis() {
   // Analyze trends on specified timeframes
   ENUM_TIMEFRAMES timeframes[] = {PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4};
   string timeframeNames[] = {"M15", "M30", "H1", "H4"};
   int xOffset = 10, yOffset = 10;

   // Display trend results on the chart
   for (int i = 0; i < ArraySize(timeframes); i++) {
      int trend = TrendAnalysis(timeframes[i], true); // `true` confirms trends with H4
      string trendText = timeframeNames[i] + ": " + TrendToString(trend);

      // Create text for each timeframe trend
      string objName = "Trend_" + timeframeNames[i];
      createText(objName, trendText, xOffset, yOffset + (i * 20), TrendColor(trend), 12);
   }

   // Display overall alignment status
   int alignedTrend = AreAllTrendsAligned();
   string alignmentText = "Overall Trend: " + TrendToString(alignedTrend);
   createText("OverallTrend", alignmentText, xOffset, yOffset + (ArraySize(timeframes) * 20), TrendColor(alignedTrend), 14);
}

// Analyze trend for a given timeframe and optionally confirm with H4
int TrendAnalysis(ENUM_TIMEFRAMES timeframe, bool confirmWithH4 = false) {
   // Fetch the latest candle data
   MqlRates rates[];
   if (CopyRates(_Symbol, timeframe, 0, 1, rates) <= 0) {
      Print("Error fetching rates for ", _Symbol, " on timeframe ", timeframe);
      return 0; // Neutral if data cannot be fetched
   }

   // Determine basic trend direction
   int trendDirection = 0; // 0 for Neutral, 1 for Bullish, -1 for Bearish
   if (rates[0].close > rates[0].open) {
      trendDirection = 1; // Bullish
   } else if (rates[0].close < rates[0].open) {
      trendDirection = -1; // Bearish
   }

   // Confirm trend with H4 if required
   if (confirmWithH4 && timeframe != PERIOD_H4) {
      MqlRates ratesH4[];
      if (CopyRates(_Symbol, PERIOD_H4, 0, 1, ratesH4) <= 0) {
         Print("Error fetching H4 rates for ", _Symbol);
         return 0; // Neutral if data cannot be fetched
      }

      // Confirm only if it aligns with the H4 trend
      if (!((ratesH4[0].close > ratesH4[0].open && trendDirection == 1) ||
            (ratesH4[0].close < ratesH4[0].open && trendDirection == -1))) {
         return 0; // Neutral if misaligned
      }
   }

   return trendDirection;
}


int AreAllTrendsAligned() {
    ENUM_TIMEFRAMES timeframes[4] = {PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4};
    int firstTrend = TrendAnalysis(timeframes[0]); // Adjust TrendAnalysis to perform what you need for trend confirmation

    if(firstTrend == 0) {
        return 0; // Neutral or no clear trend
    }

    for(int i = 1; i < ArraySize(timeframes); i++) {
        int trend = TrendAnalysis(timeframes[i]); // Again, ensure TrendAnalysis is adapted per your strategy

        if(trend == 0 || trend != firstTrend) {
            return 0; // Trends not aligned or one or more are neutral
        }
    }

    // All trends are aligned and not neutral
    return firstTrend; // 1 for bullish, -1 for bearish
}



// Convert trend value to a descriptive string
string TrendToString(int trend) {
   if (trend == 1) return "Bullish";
   if (trend == -1) return "Bearish";
   return "Neutral";
}

// Get color based on trend value
color TrendColor(int trend) {
   if (trend == 1) return clrLime;
   if (trend == -1) return clrRed;
   return clrYellow;
}
bool createText(string objName, string text, int x, int y, color clrTxt, int fontSize = 10, ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER) {
   static struct TextProperties {
      string previousText;
      int previousX;
      int previousY;
      color previousColor;
      int previousFontSize;
      ENUM_BASE_CORNER previousCorner;
   } textStates[];

   int index = -1;

   // Find the index of objName in the array, or add it if not found
   for (int i = 0; i < ArraySize(textStates); i++) {
      if (textStates[i].previousText == objName) {
         index = i;
         break;
      }
   }
   if (index == -1) {
      // Add a new entry for the object
      index = ArraySize(textStates);
      ArrayResize(textStates, index + 1);
      textStates[index].previousText = ""; // Initialize previousText to an empty string
   }

   // Check if the object exists
   if (ObjectFind(0, objName) >= 0) {
      // Update only if properties have changed
      if (textStates[index].previousText != text ||
          textStates[index].previousX != x ||
          textStates[index].previousY != y ||
          textStates[index].previousColor != clrTxt ||
          textStates[index].previousFontSize != fontSize ||
          textStates[index].previousCorner != corner) {
         ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
         ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);
         ObjectSetString(0, objName, OBJPROP_TEXT, text);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrTxt);
         ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);

         // Update the stored state
         textStates[index].previousText = text;
         textStates[index].previousX = x;
         textStates[index].previousY = y;
         textStates[index].previousColor = clrTxt;
         textStates[index].previousFontSize = fontSize;
         textStates[index].previousCorner = corner;
      }
   } else {
      // Create the object if it doesn't exist
      if (!ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0)) {
         Print(__FUNCTION__, ": failed to create label! Error Code = ", GetLastError());
         return false;
      }

      // Set properties for the newly created object
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, corner);
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrTxt);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);

      // Initialize the stored state
      textStates[index].previousText = text;
      textStates[index].previousX = x;
      textStates[index].previousY = y;
      textStates[index].previousColor = clrTxt;
      textStates[index].previousFontSize = fontSize;
      textStates[index].previousCorner = corner;
   }

   return true;
}

#endif // DISPLAY_TREND_ANALYSIS_MQH
