//+------------------------------------------------------------------+
//|                                                 RIGGWIRE 1.0.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#define PARENT_DECLARED  // Signal to all .mqh files that parent declares variables

#include <Trade/Trade.mqh>
CTrade obj_Trade;
#include <ChartObjects\ChartObjectsLines.mqh>

#include  "drawRange.mqh"
#include  "isNewsEvent.mqh"
#include  "DisplayTrendAnalysis.mqh"
#include  "IsConsolidating.mqh"
#include  "DrawSupplyDemandZones.mqh"
#include   "TrendConfirmation.mqh"
#include   "Money Protector.mqh"

#include "LogicOne.mqh"

#include "LogicTwo.mqh"
#include "LogicThree.mqh"

input bool ShowArrows = true; // Whether to show arrows

// Trailing stop and trading parameters
input double TRAILING_SL = 50; // Trailing stop distance in points
input double STEPS = 10; // Step size for trailing stop
input double BREAKEVEN = 30; // Break-even trigger distance in points
input double MaxSlippage_ = 3; // Maximum slippage in points

// Supertrend indicator parameters
input double ATRMultiplier1 = 3.0; // ATR multiplier for Supertrend
input int ATRPeriod1 = 10; // ATR period for Supertrend
input int ATRMaxBars = 1000; // Maximum bars for Supertrend calculation

// Money management and trading parameters
input double MM_Percent = 2;
input int SL_Points = 20; // Stop Loss in points
input int MagicNumber = 1974400;
input int NextOpenTradeAfterMinutes = 15;
input int NextOpenTradeAfterTOD_Hour = 00;
input int NextOpenTradeAfterTOD_Min = 15;
input int TOD_From_Hour = 08;
input int TOD_From_Min = 0;
input int TOD_To_Hour = 20;
input int TOD_To_Min = 0;
input double MaxSpread = 10;
input bool TradeMonday = true;
input bool TradeTuesday = true;
input bool TradeWednesday = true;
input bool TradeThursday = true;
input bool TradeFriday = true;
input bool TradeSaturday = false;
input bool TradeSunday = false;
input bool Audible_Alerts = true;
input bool Push_Notifications = true;
input int MaxOpenTrades = 5;
input int MaxLongTrades = 5;
input int MaxShortTrades = 5;
input bool Hedging = true;

// Global variables
double myPoint; // Point value for current symbol
double MaxSlippage_Adjusted; // Adjusted slippage value (calculated from MaxSlippage_)
int ema5_H1_handle, ema8_H1_handle, ema13_H1_handle; // EMA handles for H1 timeframe
int ema5_handle, ema8_handle, ema13_handle; // EMA handles for M15 timeframe

int MT5SUPERTREND1_handle;
double MT5SUPERTREND1[];



//+------------------------------
//Performance Tracking
//+------------------------------
int totalTrades = 0;
int totalWins = 0;
int totalLosses = 0;
double winRate = 0.0;
double dailyProfit = 0.0; // DailyProfit as a global variable

datetime dayTime = 0;
double dayBalance = 0;
bool isTradeAllowed = true;
double InitialBalance = 0;
double highestBalance = 0;



int BB_MACD_handle;
double BB_MACD[];



int  MAtrend_handle;
double MAtrend[];


datetime lastTradeDisabledTime = 0;


int totalBars = 0;
double initialBalance = 0;



double SignalBuffer[];



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Acc_B() {return AccountInfoDouble(ACCOUNT_BALANCE);}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Acc_E() {return AccountInfoDouble(ACCOUNT_EQUITY);}
string Acc_S() {return AccountInfoString(ACCOUNT_CURRENCY);}


input double MaxDailyDrawdownPercent = -1.00; // Maximum daily drawdown percentage
input double SpecificDrawdownLimit = -5.00; // Specific drawdown limit for additional control



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Initialize global variables
   myPoint = _Point;
   MaxSlippage_Adjusted = MaxSlippage_;
   if (_Digits == 5 || _Digits == 3) {
      myPoint *= 10;
      MaxSlippage_Adjusted *= 10;
   }

   InitialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   highestBalance = InitialBalance;

string labels[] = {
    "*** PROGRESS DASHBOARD ***", "__________________________",
    "DrawDown Limiter is Active.", "Counters will be Reset on Next Day Start.",
    "From: ", "Time Here", "To: ", "Time Here",
    "Current: ", "Time Here",
    "ACCOUNT DRAWDOWN ============", "Account Initial Balance: ", 
    "Torelated DrawDown: ", DoubleToString(SpecificDrawdownLimit, 2),
    "Current Account Equity: ", DoubleToString(Acc_E(), 2), // Removed Acc_S()
    "Current Balance Variation: ", Acc_B() != 0 ? DoubleToString((Acc_E() - Acc_B()) / Acc_B() * 100, 2) + " %" : "N/A",
    "DAILY DRAWDOWN ================", "Starting Balance: ",
    DoubleToString(Acc_B(), 2), // Removed Acc_S()
    "DrawDown Maximum Threshold: ", DoubleToString(MaxDailyDrawdownPercent, 2), // Removed Acc_S()
    "DrawDown Maximum Amount: ", "-" + DoubleToString(Acc_B() * 5 / 100, 2), // Removed Acc_S()
    "Current Closed Daily Profit: ", "0.00", // Removed Acc_S()
    "Current DrawDown Percent: ", "0.00 %",
    ">>> Initializing The Program, Get Ready To Trade."
};

   int yOffset = 30;
   for (int i = 0; i < ArraySize(labels); i++) {
      createText(IntegerToString(i), labels[i], 8, yOffset, clrWhite, 10);
      yOffset += 15;
   }

   // Create initial rectangle
   ObjectDelete(0, "REC");
   if (!ObjectCreate(0, "REC", OBJ_RECTANGLE, 0, D'2023/09/05 06:00', 0.64000, D'2023.09.11 02:00', 0.63650)) {
      Print("Error creating REC object: ", GetLastError());
   }
   ObjectSetInteger(0, "REC", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, "REC", OBJPROP_FILL, false);
   ObjectSetInteger(0, "REC", OBJPROP_WIDTH, 7);

   // Check for news events
   if (isNewsEvent()) {
      Print("_______ ALERT: WE HAVE NEWS EVENT _________");
   }

   // Initialize custom indicator
   MT5SUPERTREND1_handle = iCustom(_Symbol, PERIOD_CURRENT, "MT5 SUPERTREND1",
      "MT5 SUPERTREND",  // IndicatorName
      ATRMultiplier1,     // ATRMultiplier
      ATRPeriod1,         // ATRPeriod
      ATRMaxBars,         // ATRMaxBars
      0,                  // Shift
      false,              // EnableNotifications
      true);              // EnableSignalDots
   if (MT5SUPERTREND1_handle < 0) {
      Print("MT5SUPERTREND1 initialization failed. Handle: ", MT5SUPERTREND1_handle, " Error: ", GetLastError());
      return INIT_FAILED;
   }

   // Initialize EMA indicators
   ema5_H1_handle = iMA(_Symbol, PERIOD_M5, 5, 0, MODE_EMA, PRICE_CLOSE);
   ema8_H1_handle = iMA(_Symbol, PERIOD_M5, 8, 0, MODE_EMA, PRICE_CLOSE);
   ema13_H1_handle = iMA(_Symbol, PERIOD_M5, 13, 0, MODE_EMA, PRICE_CLOSE);

   ema5_handle = iMA(_Symbol, PERIOD_M15, 5, 0, MODE_EMA, PRICE_CLOSE);
   ema8_handle = iMA(_Symbol, PERIOD_M15, 8, 0, MODE_EMA, PRICE_CLOSE);
   ema13_handle = iMA(_Symbol, PERIOD_M15, 13, 0, MODE_EMA, PRICE_CLOSE);

   // Validate EMA handles
   if (ema5_H1_handle < 0 || ema8_H1_handle < 0 || ema13_H1_handle < 0 || ema5_handle < 0 || ema8_handle < 0 || ema13_handle < 0) {
      Print("EMA initialization failed. Error: ", GetLastError());
      return INIT_FAILED;
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Your cleanup code here
   Print("EA is being removed from the chart...");
   EventKillTimer(); // Stop the timer when the EA or indicator is removed
// Example: Delete all graphical objects created by the EA
   ObjectsDeleteAll(0, 0); // This deletes all objects from the current chart


  }
  
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   // Update the countdown display
   UpdateCountdown();

   // Execute trading logic
   LogicOne();

   // Check trade conditions (e.g., drawdown, thresholds)
   CheckTradeConditions();

   // Check daily profit and other conditions
   checkDailyProfit();

   // Exit early if trading is not allowed
   if (!isTradeAllowed) return;

   // Update market information
   double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);

   // Prevent duplicate processing for the same bar
   int bars = iBars(_Symbol, _Period);
   if (totalBars == bars) return;
   totalBars = bars;

   // Limit positions to one active trade
   if (PositionsTotal() > 1) return;

   // Apply trailing stops for buy and sell positions
   TrailingStopTrail(ORDER_TYPE_BUY, TRAILING_SL * myPoint, STEPS * myPoint, true, BREAKEVEN * myPoint);
   TrailingStopTrail(ORDER_TYPE_SELL, TRAILING_SL * myPoint, STEPS * myPoint, true, BREAKEVEN * myPoint);

   // Draw supply and demand zones
   DrawSupplyDemandZones(PERIOD_H1);
   DrawSupplyDemandZones(PERIOD_H4);

   // Draw trading range with trend detection
   FindRange(_Symbol, PERIOD_H1, 0, 20);  // Find H1 range over last 20 bars
   drawRange(rangeStartTime, rangeHigh, rangeEndTime, rangeLow);

   // Check trade entry conditions for H1 timeframe
   CheckTradeEntryConditions(PERIOD_H1);

   // Display trading hours status
   DisplayTradingHoursStatus();
   

   // Perform trend analysis and alignment check
   DisplayTrendAnalysis();
   int trendAlignment = AreAllTrendsAligned();

   // Execute trend confirmation logic
   TrendConfirmation();

   // Determine consolidation status for the last H1 candle
   datetime time1 = iTime(_Symbol, PERIOD_H1, 1);  // Time of the second-last H1 candle
   datetime time2 = iTime(_Symbol, PERIOD_H1, 0);  // Time of the last H1 candle
   double price1 = iHigh(_Symbol, PERIOD_H1, 1);   // High of the second-last H1 candle
   double price2 = iLow(_Symbol, PERIOD_H1, 1);    // Low of the second-last H1 candle

   int consolidationSignal = IsConsolidating(time1, price1, time2, price2);
   UpdateTradingPauseMessage(consolidationSignal);

   // Calculate percentage change over the last hour
   double currentClose = iClose(_Symbol, PERIOD_H1, 0); // Current closing price
   double previousClose = iClose(_Symbol, PERIOD_H1, 1); // Previous closing price
   double percentageChange = ((currentClose - previousClose) / previousClose) * 100.0;

   // Analyze percentage change and take action if needed
   int signal = CheckPercentageSignal(percentageChange);
   if (signal == 1) {
      // Bullish signal detected
      Print("Bullish signal detected for ", _Symbol, " with a percentage change of ", DoubleToString(percentageChange, 2), "%.");
   } else if (signal == -1) {
      // Bearish signal detected
      Print("Bearish signal detected for ", _Symbol, " with a percentage change of ", DoubleToString(percentageChange, 2), "%.");
   } else {
      // No significant movement
      Print("No significant movement for ", _Symbol, ".");
   }
}


void CheckTradeConditions() {
   static string lastDisplayedText = "";    // Last displayed message
   static color lastDisplayedColor = clrWhite;  // Last color of the message
   static bool lastTradeAllowedState = true;    // Last state of trade allowance
   static datetime lastCheckedTime = 0;         // Last time conditions were checked

   // Avoid frequent updates within a short timeframe (e.g., once every second)
   datetime currentTime = TimeCurrent();
   if (currentTime == lastCheckedTime) return;  // Skip redundant checks
   lastCheckedTime = currentTime;

   double dailyProfitOrDrawdown = 0.0;

   // Calculate daily profit or drawdown as a percentage
   if (initialBalance != 0) {
      dailyProfitOrDrawdown = (Acc_E() - initialBalance) / initialBalance * 100;
   } else {
      dailyProfitOrDrawdown = 0; // No change if initial balance is zero
   }

   // Determine current message and color
   string currentText;
   color currentColor;

   if (dailyProfitOrDrawdown <= MaxDailyDrawdownPercent || dailyProfitOrDrawdown >= SpecificDrawdownLimit) {
      currentText = ">>> Maximum Threshold Hit, Trading Disabled.";
      currentColor = clrRed;
      isTradeAllowed = false;
      lastTradeDisabledTime = currentTime; // Record suspension time
   } else {
      currentText = "Trading conditions are normal.";
      currentColor = clrGreen;
      isTradeAllowed = true;
   }

   // Automatically re-enable trading after 24 hours
   if (!isTradeAllowed && lastTradeDisabledTime != 0 && (currentTime - lastTradeDisabledTime > 86400)) {
      isTradeAllowed = true;  // Re-enable trading
      lastTradeDisabledTime = 0;  // Reset the timer
      currentText = "Trading conditions are normal.";
      currentColor = clrGreen;
   }

   // Update label only if the text or color has changed
   if (currentText != lastDisplayedText || currentColor != lastDisplayedColor) {
      // Update or create the label
      if (ObjectFind(0, "TradeStatusLabel") >= 0) {
         // Update existing label properties
         ObjectSetString(0, "TradeStatusLabel", OBJPROP_TEXT, currentText);
         ObjectSetInteger(0, "TradeStatusLabel", OBJPROP_COLOR, currentColor);
      } else {
         // Create the label if it doesn't exist
         ObjectCreate(0, "TradeStatusLabel", OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, "TradeStatusLabel", OBJPROP_XDISTANCE, 8);
         ObjectSetInteger(0, "TradeStatusLabel", OBJPROP_YDISTANCE, 300);
         ObjectSetInteger(0, "TradeStatusLabel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, "TradeStatusLabel", OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, "TradeStatusLabel", OBJPROP_TEXT, currentText);
         ObjectSetInteger(0, "TradeStatusLabel", OBJPROP_COLOR, currentColor);
      }

      // Store the current state as the last displayed state
      lastDisplayedText = currentText;
      lastDisplayedColor = currentColor;
   }
}




//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------------------------+
void checkDailyProfit() {
   // Display trading hours status
   DisplayTradingHoursStatus();

   // Time zone adjustment (server time difference)
   int timeZoneDifference = 7; // Adjust hours if needed
   datetime localCurrentTime = TimeCurrent() - timeZoneDifference * 3600;

   // Calculate start and end of the trading day
   string sdate = TimeToString(localCurrentTime, TIME_DATE); // Get date part
   datetime start = StringToTime(sdate);
   datetime to = start + 86400; // End of the day (24 hours later)

   if (dayTime < to) {
      dayTime = to;
      dayBalance = Acc_B();
   }

   // Calculate total daily profit
   double total_day_Profit = 0;
   HistorySelect(start, TimeCurrent());
   int totalDeals = HistoryDealsTotal();
   for (int i = 0; i < totalDeals; i++) {
      ulong ticket = HistoryDealGetTicket(i);
      if (HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
         double dealProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                             HistoryDealGetDouble(ticket, DEAL_COMMISSION) +
                             HistoryDealGetDouble(ticket, DEAL_SWAP);
         total_day_Profit += dealProfit;
      }
   }

   // Calculate drawdown/profit percentage
   double startingBalance = AccountInfoDouble(ACCOUNT_BALANCE) - total_day_Profit;
   double dailyProfitOrDrawdown = startingBalance != 0 ? NormalizeDouble(total_day_Profit * 100 / startingBalance, 2) : 0.0;
   string dailyProfitText = DoubleToString(dailyProfitOrDrawdown, 2) + " %";

   // Display daily profit and time ranges
   createText("4", TimeToString(start), 100, 80, clrYellow, 10);
   createText("6", TimeToString(to), 100, 95, clrYellow, 10);
   createText("8", TimeToString(TimeCurrent()), 100, 110, clrWhite, 10);

   // Display equity and balance variations
   double equityVariation = initialBalance != 0 ? (Acc_E() - initialBalance) / initialBalance * 100 : 0;
   color equityColor = Acc_E() > initialBalance ? clrLime : (Acc_E() < initialBalance ? clrRed : clrWhite);
   createText("15", DoubleToString(Acc_E(), 2) + " " + Acc_S(), 250, 175, equityColor, 10);
   createText("17", DoubleToString(equityVariation, 2) + " %", 250, 190, equityColor, 10);

   // Display daily profit
   createText("20", DoubleToString(dayBalance, 2) + " " + Acc_S(), 270, 225, clrWhite, 10);
   createText("24", "-" + DoubleToString(dayBalance * 5 / 100, 2) + " " + Acc_S(), 270, 255, clrYellow, 10);

   color profitColor = Acc_B() > dayBalance ? clrLime : (Acc_B() < dayBalance ? clrRed : clrWhite);
   createText("26", DoubleToString(total_day_Profit, 2) + " " + Acc_S(), 270, 270, profitColor, 10);
   createText("28", dailyProfitText, 270, 285, profitColor, 10);

   // Call CheckTradeConditions for threshold evaluation
   CheckTradeConditions();

   // Calculate trading range and spread
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   CopyHigh(_Symbol, _Period, 0, 100, high);
   CopyLow(_Symbol, _Period, 0, 100, low);

   int highestCandle = ArrayMaximum(high, 0, 40);
   int lowestCandle = ArrayMinimum(low, 0, 40);
   double tradingRange = NormalizeDouble(high[highestCandle] - low[lowestCandle], 5);
   string tradeComment = tradingRange > 0.003 ? "Good to trade" : "No trade";

   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;

   // Update trading range and spread
   createText("31", "Trading Range: " + DoubleToString(tradingRange, 5) + " | " + tradeComment, 8, 315, clrYellow, 10);
   createText("32", "Spread: " + DoubleToString(spread, 1) + " points", 8, 330, clrYellow, 10);

   // Display trend analysis
   string trends[] = {"15m", "30m", "1h", "4h"};
   ENUM_TIMEFRAMES timeframes[] = {PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4};
   int startYPos = 345;
   for (int i = 0; i < ArraySize(timeframes); i++) {
      int trend = TrendAnalysis(timeframes[i]);
      string trendText = trends[i] + " Trend: " + (trend == 1 ? "Bullish" : (trend == -1 ? "Bearish" : "Neutral"));
      double percentageMove = CalculatePercentageMove(timeframes[i]);
      trendText += " (" + DoubleToString(percentageMove, 2) + "%)";
      createText("Trend_" + IntegerToString(i), trendText, 8, startYPos + (i * 15), clrYellow, 10);
   }
}


//+------------------------------------------------------------------+
//| Function to check the percentage move and return signal          |
//+------------------------------------------------------------------+
int CheckPercentageSignal(double percentage) {
   // Initialize signal: 0 for no significant movement
   int signal = 0;

   // Set signal based on percentage thresholds
   if (percentage > 3.0) {
      signal = 1; // Bullish signal for percentage above 3%
   } else if (percentage < -3.0) {
      signal = -1; // Bearish signal for percentage below -3%
   }

   // Print the signal for debugging or tracking
   Print("Percentage Move: ", DoubleToString(percentage, 2), "%, Signal: ", signal);

   return signal;
}



// Periodically call CheckDrawdownAndAdjust, e.g., before opening new trades or on a timer

//+------------------------------------------------------------------+
//| Function to check trade entry conditions                         |
//+------------------------------------------------------------------+
void CheckTradeEntryConditions(ENUM_TIMEFRAMES timeframe) {
   // Check if trading is within allowed hours
   if (!IsWithinTradingHours()) {
      Print("Not within trading hours.");
      return;
   }

   // Perform trend analysis
   MarketTrend trend = (MarketTrend)TrendAnalysis(timeframe);
   switch (trend) {
      case TREND_NEUTRAL:
         Print("Market is neutral. No trade considered.");
         return;

      case TREND_BULLISH:
         Print("Bullish trend detected. Considering a BUY trade.");
         // Add BUY trade entry logic here
         break;

      case TREND_BEARISH:
         Print("Bearish trend detected. Considering a SELL trade.");
         // Add SELL trade entry logic here
         break;
   }

   // Fetch bar data for trading range checks
   datetime time1 = iTime(_Symbol, timeframe, 1); // Time of the second last bar
   datetime time2 = iTime(_Symbol, timeframe, 0); // Time of the last bar
   double price1 = iHigh(_Symbol, timeframe, 1);  // High of the second last bar
   double price2 = iLow(_Symbol, timeframe, 1);   // Low of the second last bar

   // Check for market consolidation
   int tradeSignal = IsConsolidating(time1, price1, time2, price2);
   if (tradeSignal == -1) {
      Print("Market is consolidating. Trading paused.");
      return;
   }

   Print("Market not consolidating. Proceeding with trade execution.");
   // Insert additional trade execution logic here
}





//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Display Trading Hours Status with Local Time Adjustment          |
//+------------------------------------------------------------------+
void DisplayTradingHoursStatus() {
   string tradingHoursStatusText;
   color statusColor;
   string countdownText;

   // Time zone adjustment (assuming server time is 7 hours ahead of local time)
   int timeZoneDifference = 7; // Adjust dynamically if needed
   datetime localCurrentTime = TimeCurrent() - timeZoneDifference * 3600; // Adjust server time to local time

   // Convert local time to a structure for easier manipulation
   MqlDateTime currentDateTime;
   TimeToStruct(localCurrentTime, currentDateTime);

   // Convert time to total minutes
   int currentTimeMinutes = currentDateTime.hour * 60 + currentDateTime.min;
   int startTradingTimeMinutes = TOD_From_Hour * 60 + TOD_From_Min; // Trading starts
   int endTradingTimeMinutes = TOD_To_Hour * 60 + TOD_To_Min;       // Trading ends
   int timeDifferenceMinutes;

   // Check if currently within trading hours
   bool isWithinTradingHours = (currentTimeMinutes >= startTradingTimeMinutes && currentTimeMinutes < endTradingTimeMinutes);

   if (isWithinTradingHours) {
      tradingHoursStatusText = "Status: Within Trading Hours";
      statusColor = clrLime;
      timeDifferenceMinutes = endTradingTimeMinutes - currentTimeMinutes;

      countdownText = "Time left today: " +
                      IntegerToString(timeDifferenceMinutes / 60) + "h " +
                      IntegerToString(timeDifferenceMinutes % 60) + "m";
   } else {
      tradingHoursStatusText = "Status: Outside Trading Hours";
      statusColor = clrRed;

      if (currentTimeMinutes > endTradingTimeMinutes) {
         // Time until trading starts the next day
         timeDifferenceMinutes = 1440 - currentTimeMinutes + startTradingTimeMinutes;
      } else {
         // Time until trading starts today
         timeDifferenceMinutes = startTradingTimeMinutes - currentTimeMinutes;
      }

      countdownText = "Time until start: " +
                      IntegerToString(timeDifferenceMinutes / 60) + "h " +
                      IntegerToString(timeDifferenceMinutes % 60) + "m";
   }

   // Display the trading hours status
   int startYPos = 417;
   createText("TradingHoursStatus", tradingHoursStatusText, 8, startYPos, statusColor, 10);

   // Display the countdown text below the status
   int countdownYPos = startYPos + 15;
   createText("Countdown", countdownText, 8, countdownYPos, statusColor, 10);
}


//+------------------------------------------------------------------+
//| Update Countdown Display                                         |
//+------------------------------------------------------------------+
void UpdateCountdown() {
   string countdownText;           // Text for displaying countdown or trade status
   datetime currentTime = TimeCurrent(); // Current server time
   long differenceInSeconds = NextTradeTime - currentTime; // Time difference in seconds

   color countdownColor = clrRed;  // Default color for waiting state

   // Check if it's time to trade or a trade just closed
   if (differenceInSeconds <= 0 || tradeStatus == 1) {
      countdownColor = clrLime;   // Green color indicates trading is allowed
      countdownText = "Time to trade!";

      // Reset trade status if applicable
      tradeStatus = 0; // Ensure fresh countdown for the next cycle
   } else {
      // Calculate hours, minutes, and seconds remaining for the next trade
      long hours = differenceInSeconds / 3600;
      long minutes = (differenceInSeconds % 3600) / 60;
      long seconds = differenceInSeconds % 60;

      // Format the countdown text
      countdownText = "Next trade in: " + IntegerToString(hours) + "h " +
                      IntegerToString(minutes) + "m " +
                      IntegerToString(seconds) + "s";
   }

   // Display the countdown with the appropriate color
   createText("NextTradeCountdown", countdownText, 8, 447, countdownColor, 10);
}



// Assuming all external variables and necessary functions (like LastCloseTime, TimeCurrent, etc.) are defined elsewhere in your EA or script.
// Global variable declaration
int tradeStatus = 0; // 0 indicates no recent trade close, 1 indicates a trade just closed

// The rest of your code follows...
//+------------------------------------------------------------------+
//| Update the Next Trade Time and Trade Status                      |
//+------------------------------------------------------------------+
int UpdateNextTradeTime() {
   datetime lastTradeCloseTime = LastCloseTime(); // Get the time of the last trade close
   datetime currentTime = TimeCurrent();         // Current server time
   datetime calculatedNextTradeTime = 0;         // Initialize calculated trade time
   tradeStatus = 0;                              // Reset tradeStatus initially

   // Determine NextTradeTime based on provided configuration
   if ((NextOpenTradeAfterTOD_Hour > 0 || NextOpenTradeAfterTOD_Min > 0) && lastTradeCloseTime > 0) {
      MqlDateTime structCurrentTime, structNextTradeTime;
      TimeToStruct(currentTime, structCurrentTime);  // Convert current time to MqlDateTime
      structNextTradeTime = structCurrentTime;       // Copy current date
      structNextTradeTime.hour = NextOpenTradeAfterTOD_Hour;
      structNextTradeTime.min = NextOpenTradeAfterTOD_Min;
      calculatedNextTradeTime = StructToTime(structNextTradeTime); // Convert back to datetime
   } 
   else if (NextOpenTradeAfterMinutes > 0 && lastTradeCloseTime > 0) {
      calculatedNextTradeTime = lastTradeCloseTime + NextOpenTradeAfterMinutes * 60; // Add delay in seconds
   } 
   else {
      Print("Configuration error: Check ToD parameters and NextOpenTradeAfterMinutes.");
      return -1; // Return -1 to indicate an error
   }

   // Adjust for past calculated trade times (e.g., missed NextTradeTime)
   if (calculatedNextTradeTime <= currentTime) {
      calculatedNextTradeTime += 86400; // Add one day (86400 seconds)
   }

   // Update the global NextTradeTime
   NextTradeTime = calculatedNextTradeTime;

   // Determine the tradeStatus based on whether it's time to trade
   tradeStatus = currentTime >= NextTradeTime ? 1 : 0;

   // Update the countdown display
   UpdateCountdown();

   // Return the trade status (1 if ready to trade, 0 otherwise)
   return tradeStatus;
}
