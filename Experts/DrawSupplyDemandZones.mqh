// Global Variables to store latest zones
double h4SupplyTop, h4SupplyBottom, h4DemandTop, h4DemandBottom;
double d1SupplyTop, d1SupplyBottom, d1DemandTop, d1DemandBottom;

// Function to draw supply and demand zones
void DrawSupplyDemandZones(ENUM_TIMEFRAMES timeframe) {
   int barsBack = 10; // Number of bars to analyze
   datetime startTime = TimeCurrent() - PeriodSeconds(timeframe) * barsBack;
   datetime endTime = TimeCurrent();

   double highestHigh = iHigh(_Symbol, timeframe, iHighest(_Symbol, timeframe, MODE_HIGH, barsBack, 0));
   double lowestLow = iLow(_Symbol, timeframe, iLowest(_Symbol, timeframe, MODE_LOW, barsBack, 0));

   // Zone boundaries
   double supplyTop = highestHigh;
   double supplyBottom = highestHigh - (highestHigh - lowestLow) * 0.1;
   double demandTop = lowestLow + (highestHigh - lowestLow) * 0.1;
   double demandBottom = lowestLow;

   // Set global variables based on the timeframe
   if (timeframe == PERIOD_H4) {
      h4SupplyTop = supplyTop;
      h4SupplyBottom = supplyBottom;
      h4DemandTop = demandTop;
      h4DemandBottom = demandBottom;
   } else if (timeframe == PERIOD_D1) {
      d1SupplyTop = supplyTop;
      d1SupplyBottom = supplyBottom;
      d1DemandTop = demandTop;
      d1DemandBottom = demandBottom;
   }

   // Choose colors based on timeframe
   color supplyColor = (timeframe == PERIOD_H4) ? clrRed : clrDarkRed;
   color demandColor = (timeframe == PERIOD_H4) ? clrGreen : clrDarkGreen;

   string prefix = EnumToString(timeframe);
   DrawZone(prefix + "_SupplyZone", supplyTop, supplyBottom, supplyColor, startTime, endTime);
   DrawZone(prefix + "_DemandZone", demandTop, demandBottom, demandColor, startTime, endTime);
}

// Function to draw a rectangular zone and a center line
void DrawZone(string name, double top, double bottom, color zoneColor, datetime startTime, datetime endTime) {
   string objectName = name + "_Rectangle";
   string centerLineName = name + "_CenterLine";
   double center = (top + bottom) / 2;

   // Delete existing objects
   ObjectDelete(0, objectName);
   ObjectDelete(0, centerLineName);

   // Create and configure rectangle
   if (ObjectCreate(0, objectName, OBJ_RECTANGLE, 0, startTime, top, endTime, bottom)) {
      ObjectSetInteger(0, objectName, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, objectName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, objectName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objectName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objectName, OBJPROP_SELECTABLE, false);
   }

   // Create and configure center line
   if (ObjectCreate(0, centerLineName, OBJ_TREND, 0, startTime, center, endTime, center)) {
      ObjectSetInteger(0, centerLineName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, centerLineName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, centerLineName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, centerLineName, OBJPROP_SELECTABLE, false);
   }

   ChartRedraw();
}
