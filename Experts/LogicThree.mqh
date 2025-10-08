
#include   "Money Protector.mqh"
#include   "TrendConfirmation.mqh"

//+------------------------------------------------------------------+
//| Standalone Compilation Support for LogicThree                     |
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












bool CheckConditionForLogicThree() { /* Implement logic */ return false; }


void LogicThree()
{


   ulong ticket = 0;
   double price;
   double TradeSize;
   double SL;
   datetime currentTime = TimeCurrent(); // Get the current time


   TrailingStopTrail(ORDER_TYPE_BUY, TRAILING_SL * myPoint, STEPS * myPoint, true, BREAKEVEN * myPoint); //Trailing Stop = trail
   TrailingStopTrail(ORDER_TYPE_SELL, TRAILING_SL * myPoint, STEPS * myPoint, true, BREAKEVEN * myPoint); //Trailing Stop = trail





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

      // Check if the calculated NextTradeTime is in the past, and if so, adjust it
      if(NextTradeTime <= TimeCurrent())
        {
         // Use 'datetime' or 'long' for calculations involving datetime values
         datetime differenceInSeconds = TimeCurrent() - NextTradeTime + NextOpenTradeAfterMinutes;
         datetime periodsToAdd = differenceInSeconds / (NextOpenTradeAfterMinutes * 60) + 1;
         NextTradeTime += periodsToAdd * NextOpenTradeAfterMinutes * 60; // Adjust NextTradeTime to the future
        }


      myOrderModifyRel(ORDER_TYPE_BUY, ticket, SL, 0);
     }
 
 
 
 //Open Sell Order
 
 
 
 
 
 
 
 
 
 
 
     
     


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
      // Convert hour and minute to a datetime value for today
      string timeStr = IntegerToString(NextOpenTradeAfterTOD_Hour, 2) + ":" + IntegerToString(NextOpenTradeAfterTOD_Min, 2);
      NextTradeTime = StringToTime(timeStr);

      // Check if the calculated NextTradeTime is in the past, and if so, adjust it
      if(NextTradeTime <= TimeCurrent())
        {
         // Use 'datetime' or 'long' for calculations involving datetime values
         datetime differenceInSeconds = TimeCurrent() - NextTradeTime + NextOpenTradeAfterMinutes;
         datetime periodsToAdd = differenceInSeconds / (NextOpenTradeAfterMinutes * 60) + 1;
         NextTradeTime += periodsToAdd * NextOpenTradeAfterMinutes * 60; // Adjust NextTradeTime to the future
        }


      // Now NextTradeTime is guaranteed to be in the future relative to TimeCurrent()


      myOrderModifyRel(ORDER_TYPE_SELL, ticket, SL, 0);
     }






}