//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

#include   "Money Protector.mqh"
#include   "TrendConfirmation.mqh"

//+------------------------------------------------------------------+
//| Standalone Compilation Support for LogicOne                       |
//| Declare Logic-specific variables when compiled standalone          |
//| NOTE: ATR variables provided by TrendConfirmation.mqh             |
//+------------------------------------------------------------------+
#ifndef PARENT_DECLARED
   // Logic-specific trading parameters
   int SL_Points = 20;
   double TRAILING_SL = 50.0;
   double STEPS = 10.0;
   double BREAKEVEN = 30.0;

   // Next trade timing variables
   int NextOpenTradeAfterMinutes = 15;
   int NextOpenTradeAfterTOD_Hour = 0;
   int NextOpenTradeAfterTOD_Min = 15;

   // ATR variables are provided by TrendConfirmation.mqh (included above)
#endif
















//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LogicOne()
  {

// Update and check the signal
   TrendConfirmation();

   ulong ticket = 0;
   double price;
   double TradeSize;
   double SL;
   datetime currentTime = TimeCurrent(); // Get the current time

   TrailingStopTrail(ORDER_TYPE_BUY, TRAILING_SL * myPoint, STEPS * myPoint, true, BREAKEVEN * myPoint); //Trailing Stop = trail
   TrailingStopTrail(ORDER_TYPE_SELL, TRAILING_SL * myPoint, STEPS * myPoint, true, BREAKEVEN * myPoint); //Trailing Stop = trail


   if(g_lastSignalState.bullish)

      //Open Buy Order



     {

      MqlTick last_tick;
      SymbolInfoTick(Symbol(), last_tick);
      price = last_tick.ask;
      SL = SL_Points * myPoint; //Stop Loss = value in points (relative to price)
      TradeSize = MM_Size(SL);
      if(TradesCount(ORDER_TYPE_BUY) + TradesCount(ORDER_TYPE_SELL) > 0 || TimeCurrent() - LastCloseTime() < NextOpenTradeAfterMinutes * 60)
         return; //next open trade after time after previous trade's close
      if(TimeCurrent() <= NextTradeTime)
         return; //next open trade after time of the day
      if(!inTimeInterval(TimeCurrent(), TOD_From_Hour, TOD_From_Min, TOD_To_Hour, TOD_To_Min))
         return; //open trades only at specific times of the day
      if(!TradeDayOfWeek())
         return; //open trades only on specific days of the week
      if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED))
        {
         ticket = myOrderSend(ORDER_TYPE_BUY, price, TradeSize, "");
         if(ticket == 0)
            return;
        }
      else //not autotrading => only send alert
         myAlert("order", "");
      // Convert hour and minute to a datetime value for today
      string timeStr = IntegerToString(NextOpenTradeAfterTOD_Hour, 2) + ":" + IntegerToString(NextOpenTradeAfterTOD_Min, 2);
      NextTradeTime = StringToTime(timeStr);
      // Use 'datetime' or 'long' for calculations involving datetime values
      datetime differenceInSeconds = TimeCurrent() - NextTradeTime + NextOpenTradeAfterMinutes;

      // Ensure NextOpenTradeAfterMinutes is not zero to avoid division by zero error
      if(NextOpenTradeAfterMinutes > 0)
        {
         datetime periodsToAdd = differenceInSeconds / (NextOpenTradeAfterMinutes * 60) + 1;
         NextTradeTime += periodsToAdd * NextOpenTradeAfterMinutes * 60; // Adjust NextTradeTime to the future
        }
      else
        {
         // Handle the case when NextOpenTradeAfterMinutes is zero or invalid
         Print("NextOpenTradeAfterMinutes is zero or not set. Cannot adjust NextTradeTime.");
         // Consider setting NextTradeTime to a default or calculated value to avoid stalling the strategy
        }



      myOrderModifyRel(ORDER_TYPE_BUY, ticket, SL, 0);
     }



//Open Sell Order

   if(g_lastSignalState.bearish)







     {
      MqlTick last_tick;
      SymbolInfoTick(Symbol(), last_tick);
      price = last_tick.bid;
      SL = SL_Points * myPoint; //Stop Loss = value in points (relative to price)
      TradeSize = MM_Size(SL);
      if(TradesCount(ORDER_TYPE_BUY) + TradesCount(ORDER_TYPE_SELL) > 0 || TimeCurrent() - LastCloseTime() < NextOpenTradeAfterMinutes * 60)
         return; //next open trade after time after previous trade's close
      if(TimeCurrent() <= NextTradeTime)
         return; //next open trade after time of the day
      if(!inTimeInterval(TimeCurrent(), TOD_From_Hour, TOD_From_Min, TOD_To_Hour, TOD_To_Min))
         return; //open trades only at specific times of the day
      if(!TradeDayOfWeek())
         return; //open trades only on specific days of the week
      if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED))
        {
         ticket = myOrderSend(ORDER_TYPE_SELL, price, TradeSize, "");
         if(ticket == 0)
            return;
        }
      else //not autotrading => only send alert
         myAlert("order", "");

      // Convert hour and minute to a datetime value for today
      string timeStr = IntegerToString(NextOpenTradeAfterTOD_Hour, 2) + ":" + IntegerToString(NextOpenTradeAfterTOD_Min, 2);
      NextTradeTime = StringToTime(timeStr);
      // Use 'datetime' or 'long' for calculations involving datetime values
      datetime differenceInSeconds = TimeCurrent() - NextTradeTime + NextOpenTradeAfterMinutes;

      // Ensure NextOpenTradeAfterMinutes is not zero to avoid division by zero error
      if(NextOpenTradeAfterMinutes > 0)
        {
         datetime periodsToAdd = differenceInSeconds / (NextOpenTradeAfterMinutes * 60) + 1;
         NextTradeTime += periodsToAdd * NextOpenTradeAfterMinutes * 60; // Adjust NextTradeTime to the future
        }
      else
        {
         // Handle the case when NextOpenTradeAfterMinutes is zero or invalid
         Print("NextOpenTradeAfterMinutes is zero or not set. Cannot adjust NextTradeTime.");
         // Consider setting NextTradeTime to a default or calculated value to avoid stalling the strategy
        }


      // Now NextTradeTime is guaranteed to be in the future relative to TimeCurrent()


      myOrderModifyRel(ORDER_TYPE_SELL, ticket, SL, 0);
     }






  }
  
  
