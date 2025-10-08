//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#ifndef MONEY_PROTECTOR_MQH
#define MONEY_PROTECTOR_MQH

#include <Trade\Trade.mqh>
CTrade  trade;

//+------------------------------------------------------------------+
//| Standalone Compilation Support                                     |
//| When compiled standalone, declare variables with default values    |
//| When included in parent EA, parent provides these variables        |
//+------------------------------------------------------------------+
#ifndef PARENT_DECLARED
   // Input parameters (default values for standalone compilation)
   double MM_Percent = 2.0;
   int MagicNumber = 1974400;
   bool TradeSunday = true;
   bool TradeMonday = true;
   bool TradeTuesday = true;
   bool TradeWednesday = true;
   bool TradeThursday = true;
   bool TradeFriday = true;
   bool TradeSaturday = false;
   bool Audible_Alerts = false;
   bool Push_Notifications = false;
   double MaxSlippage_ = 3.0;
   int MaxOpenTrades = 1;
   int MaxLongTrades = 1;
   int MaxShortTrades = 1;
   bool Hedging = false;
   double MaxSpread = 3.0;
   int TOD_From_Hour = 0;
   int TOD_From_Min = 0;
   int TOD_To_Hour = 23;
   int TOD_To_Min = 59;

   // Global variables
   double myPoint = 0.00001;

   // Stub function for standalone compilation (only if not already defined elsewhere)
   #ifndef TREND_DETECTION_DEFINED
   #define TREND_DETECTION_DEFINED
   int TrendDetection() {
      return 0; // Neutral trend in standalone mode
   }
   #endif
#endif

int LotDigits; //initialized in OnInit
datetime LastTradeCloseTime = 0; // Placeholder for the last trade close time
datetime NextTradeTime; // Global variable for next trade time
int OrderRetry = 5; //# of retries if sending order returns error
int OrderWait = 5; //# of seconds to wait if sending order returns error
int MaxPendingOrders = 1000;
int MaxLongPendingOrders = 1000;
int MaxShortPendingOrders = 1000;







//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool inTimeInterval(datetime t, int From_Hour, int From_Min, int To_Hour, int To_Min)
  {
   string TOD = TimeToString(t, TIME_MINUTES);
   string TOD_From = StringFormat("%02d", From_Hour)+":"+StringFormat("%02d", From_Min);
   string TOD_To = StringFormat("%02d", To_Hour)+":"+StringFormat("%02d", To_Min);
   return((StringCompare(TOD, TOD_From) >= 0 && StringCompare(TOD, TOD_To) <= 0)
          || (StringCompare(TOD_From, TOD_To) > 0
              && ((StringCompare(TOD, TOD_From) >= 0 && StringCompare(TOD, "23:59") <= 0)
                  || (StringCompare(TOD, "00:00") >= 0 && StringCompare(TOD, TOD_To) <= 0))));
  }





//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double MM_Size(double SL) // SL = Stop Loss in points
  {
   // Validate SL to prevent invalid input
   if(SL <= 0)
      return 0.0; // Safety check: Stop Loss must be positive

   // Retrieve risk percentage from input (assumes MM_Percent is already defined globally)
   double RiskPercent = MM_Percent / 100.0; // Convert MM_Percent to a fraction

   // Get the account balance
   double AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Retrieve symbol-specific trading properties
   double MaxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);      // Maximum allowable lot size
   double MinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);      // Minimum allowable lot size
   double LotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);    // Increment step for lot size
   double TickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE); // Value of one tick in account currency
   double TickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);   // Size of one tick in points

   // Calculate the maximum risk in monetary terms
   double RiskInMoney = AccountBalance * RiskPercent;

   // Calculate the lot size based on the risk and stop loss
   double LotSize = RiskInMoney / (SL * TickValue / TickSize);

   // Round the lot size to the nearest allowable step
   LotSize = MathRound(LotSize / LotStep) * LotStep;

   // Ensure the calculated lot size is within the broker's allowable range
   LotSize = MathMax(MathMin(LotSize, MaxLot), MinLot);

   return LotSize;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool TradeDayOfWeek()
  {
   // Get the current server time
   MqlDateTime tm;
   TimeCurrent(tm);

   // Map day_of_week to the corresponding trading day input
   switch (tm.day_of_week)
     {
      case 0: return TradeSunday;     // Sunday
      case 1: return TradeMonday;     // Monday
      case 2: return TradeTuesday;    // Tuesday
      case 3: return TradeWednesday;  // Wednesday
      case 4: return TradeThursday;   // Thursday
      case 5: return TradeFriday;     // Friday
      case 6: return TradeSaturday;   // Saturday
      default: return false;          // Invalid day
     }
  }


//+------------------------------------------------------------------+
//| CloseOldTrades - Centralized Trade Duration Management          |
//| Automatically closes positions exceeding 24-hour duration        |
//| Works for all strategies using MagicNumber identification        |
//+------------------------------------------------------------------+
void CloseOldTrades()
  {
   const int MAX_TRADE_DURATION_SECONDS = 86400;  // 24 hours in seconds

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;

      // Check if position belongs to current symbol and magic number
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      // Check trade duration
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      datetime currentTime = TimeCurrent();
      int tradeDuration = (int)(currentTime - openTime);

      // Close if exceeds 24 hours
      if(tradeDuration >= MAX_TRADE_DURATION_SECONDS)
        {
         if(trade.PositionClose(ticket))
           {
            Print("Position #", ticket, " closed by Money Protector - Max duration exceeded (24 hours)");
           }
         else
           {
            Print("Failed to close position #", ticket, " - Error: ", GetLastError());
           }
        }
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void myAlert(string type, string message)
  {
   int handle;
   if(type == "print")
      Print(message);
   else
      if(type == "error")
        {
         Print(type+" | testlll @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
         if(Audible_Alerts)
            Alert(type+" | testlll @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
         handle = FileOpen("testlll.txt", FILE_TXT|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE, ';');
         if(handle != INVALID_HANDLE)
           {
            FileSeek(handle, 0, SEEK_END);
            FileWrite(handle, type+" | testlll @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
            FileClose(handle);
           }
         if(Push_Notifications)
            SendNotification(type+" | testlll @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
        }
      else
         if(type == "order")
           {
            Print(type+" | testlll @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
            if(Audible_Alerts)
               Alert(type+" | testlll @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
            handle = FileOpen("testlll.txt", FILE_TXT|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE, ';');
            if(handle != INVALID_HANDLE)
              {
               FileSeek(handle, 0, SEEK_END);
               FileWrite(handle, type+" | testlll @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
               FileClose(handle);
              }
            if(Push_Notifications)
               SendNotification(type+" | testlll @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
           }
         else
            if(type == "modify")
              {
               Print(type+" | testlll @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
               if(Audible_Alerts)
                  Alert(type+" | testlll @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
               handle = FileOpen("testlll.txt", FILE_TXT|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE, ';');
               if(handle != INVALID_HANDLE)
                 {
                  FileSeek(handle, 0, SEEK_END);
                  FileWrite(handle, type+" | testlll @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
                  FileClose(handle);
                 }
               if(Push_Notifications)
                  SendNotification(type+" | testlll @ "+Symbol()+","+IntegerToString(Period())+" | "+message);
              }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TradesCount(ENUM_ORDER_TYPE type) //returns # of open trades for order type, current symbol and magic number
  {
   if(type <= 1)
     {
      int result = 0;
      int total = PositionsTotal();
      for(int i = 0; i < total; i++)
        {
         if(PositionGetTicket(i) <= 0)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber || PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_TYPE) != type)
            continue;
         result++;
        }
      return(result);
     }
   else
     {
      int result = 0;
      int total = OrdersTotal();
      for(int i = 0; i < total; i++)
        {
         if(OrderGetTicket(i) <= 0)
            continue;
         if(OrderGetInteger(ORDER_MAGIC) != MagicNumber || OrderGetString(ORDER_SYMBOL) != Symbol() || OrderGetInteger(ORDER_TYPE) != type)
            continue;
         result++;
        }
      return(result);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong LastHistoryTradeTicket(int deal_io)
  {
   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();
   ulong ticket = 0;
   for(int i = total-1; i >= 0; i--)
     {
      if((ticket = HistoryDealGetTicket(i)) <= 0)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) == Symbol()
         && HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber
         && HistoryDealGetInteger(ticket, DEAL_TYPE) <= 1 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == deal_io)
         return(ticket);
     }
   return(0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime LastCloseTime()
  {
   ulong ticket = 0;
   if((ticket = LastHistoryTradeTicket(DEAL_ENTRY_OUT)) > 0)
      return((datetime)HistoryDealGetInteger(ticket, DEAL_TIME));
   return(0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int myOrderModify(ENUM_ORDER_TYPE type, ulong ticket, double SL, double TP) //modify SL and TP (absolute price), zero targets do not modify
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
      return(-1);
   bool netting = AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   int retries = 0;
   int err = 0;
   SL = NormalizeDouble(SL, Digits());
   TP = NormalizeDouble(TP, Digits());
   if(SL < 0)
      SL = 0;
   if(TP < 0)
      TP = 0;
//prepare to select order
   Sleep(10);
   if((type <= 1 && ((netting && !PositionSelect(Symbol())) || (!netting && !PositionSelectByTicket(ticket)))) || (type > 1 && !OrderSelect(ticket)))
     {
      err = GetLastError();
      myAlert("error", "PositionSelect / OrderSelect failed; error #"+IntegerToString(err));
      return(-1);
     }
//ignore open positions other than "type"
   if(type <= 1 && PositionGetInteger(POSITION_TYPE) != type)
      return(0);
//prepare to modify order
   double currentSL = (type <= 1) ? PositionGetDouble(POSITION_SL) : OrderGetDouble(ORDER_SL);
   double currentTP = (type <= 1) ? PositionGetDouble(POSITION_TP) : OrderGetDouble(ORDER_TP);
   if(NormalizeDouble(SL, Digits()) == 0)
      SL = currentSL; //not to modify
   if(NormalizeDouble(TP, Digits()) == 0)
      TP = currentTP; //not to modify
   if(NormalizeDouble(SL - currentSL, Digits()) == 0
      && NormalizeDouble(TP - currentTP, Digits()) == 0)
      return(0); //nothing to do
   MqlTradeRequest request;
   ZeroMemory(request);
   request.action = (type <= 1) ? TRADE_ACTION_SLTP : TRADE_ACTION_MODIFY;
   if(type > 1)
      request.order = ticket;
   else
      request.position = PositionGetInteger(POSITION_TICKET);
   request.symbol = Symbol();
   request.price = (type <= 1) ? PositionGetDouble(POSITION_PRICE_OPEN) : OrderGetDouble(ORDER_PRICE_OPEN);
   request.sl = NormalizeDouble(SL, Digits());
   request.tp = NormalizeDouble(TP, Digits());
   request.deviation = (ulong)MaxSlippage_;  // Cast to ulong to match MqlTradeRequest structure
   MqlTradeResult result;
   ZeroMemory(result);
   while(!OrderSuccess(result.retcode) && retries < OrderRetry+1)
     {
      if(!OrderSend(request, result) || !OrderSuccess(result.retcode))
        {
         err = GetLastError();
         myAlert("print", "OrderModify error #"+IntegerToString(err));
         Sleep(OrderWait*1000);
        }
      retries++;
     }
   if(!OrderSuccess(result.retcode))
     {
      myAlert("error", "OrderModify failed "+IntegerToString(OrderRetry+1)+" times; error #"+IntegerToString(err));
      return(-1);
     }
   string alertstr = "Order modify: ticket="+IntegerToString(ticket);
   if(NormalizeDouble(SL, Digits()) != 0)
      alertstr = alertstr+" SL="+DoubleToString(SL);
   if(NormalizeDouble(TP, Digits()) != 0)
      alertstr = alertstr+" TP="+DoubleToString(TP);
   myAlert("modify", alertstr);
   return(0);
  }

//+------------------------------------------------------------------+
//| Trailing stop adjustment function                                |
//+------------------------------------------------------------------+
void TrailingStopTrail(ENUM_ORDER_TYPE type, double baseTS, double step, bool aboveBE, double aboveBEval) {
   long spreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double spread = spreadPoints * SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double TS = NormalizeDouble(baseTS, Digits());
   step = NormalizeDouble(step, Digits());
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double maxAllowedLoss = accountBalance * 0.5; // 50% of account balance as max allowed loss

   int total = PositionsTotal();
   for (int i = total - 1; i >= 0; i--) {
      if (PositionGetTicket(i) <= 0 || !PositionSelectByTicket(PositionGetInteger(POSITION_TICKET)))
         continue;

      ulong ticket = PositionGetInteger(POSITION_TICKET);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentProfit = PositionGetDouble(POSITION_PROFIT);
      double profitPercent = (currentProfit / accountBalance) * 100;
      double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double SL = PositionGetDouble(POSITION_SL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double pipValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double pipsAtRisk = maxAllowedLoss / (volume * pipValue);

      // Lock profits at even percentage intervals
      double lockedProfitThreshold = MathFloor(profitPercent / 2) * 2; // Round down to nearest even number
      bool isProfitLocked = profitPercent >= lockedProfitThreshold && currentProfit > 0;

      // Ensure potential loss is within allowed limits
      double potentialLoss = (SL - openPrice) * volume * pipValue;
      bool isLossWithinLimit = MathAbs(potentialLoss) <= maxAllowedLoss;

      MqlTick lastTick;
      SymbolInfoTick(Symbol(), lastTick);

      // Adjust SL for BUY or SELL based on conditions
      if (type == ORDER_TYPE_BUY && (!aboveBE || lastTick.bid > openPrice + TS + aboveBEval) && 
          (NormalizeDouble(SL, Digits()) <= 0 || lastTick.bid > SL + TS + step)) {
         myOrderModify(ORDER_TYPE_BUY, ticket, lastTick.bid - TS, 0);
      } else if (type == ORDER_TYPE_SELL && (!aboveBE || lastTick.ask < openPrice - TS - aboveBEval) && 
                 (NormalizeDouble(SL, Digits()) <= 0 || lastTick.ask < SL - TS - step)) {
         myOrderModify(ORDER_TYPE_SELL, ticket, lastTick.ask + TS, 0);
      }

      // Adjust SL if profit is locked
      if (isProfitLocked) {
         double adjustedSL = (type == ORDER_TYPE_BUY)
                                ? MathMax(SL, openPrice + (lockedProfitThreshold / 100) * openPrice)
                                : MathMin(SL, openPrice - (lockedProfitThreshold / 100) * openPrice);
         if (isLossWithinLimit) {
            myOrderModify(type, ticket, adjustedSL, 0);
         }
      }

      // Close positions if profit > 3% and a trend reversal is detected
      int trendSignal = TrendDetection();
      if (profitPercent > 3 && ((type == ORDER_TYPE_BUY && trendSignal == -1) || (type == ORDER_TYPE_SELL && trendSignal == 1))) {
         if (trade.PositionClose(ticket)) {
            Print("Position closed due to trend reversal. Ticket: ", ticket);
         } else {
            Print("Error closing position. Ticket: ", ticket, " Error code: ", GetLastError());
         }
      }

      // Adjust SL if profit > 1%
      if (profitPercent >= 1) {
         double newSL = (type == ORDER_TYPE_BUY)
                           ? openPrice + spread + 30 * _Point
                           : openPrice - spread - 30 * _Point;

         if ((type == ORDER_TYPE_BUY && newSL > SL) || (type == ORDER_TYPE_SELL && newSL < SL)) {
            myOrderModify(type, ticket, newSL, 0);
            Print("SL adjusted for ticket: ", ticket);
         }
      }
   }
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool OrderSuccess(uint retcode)
  {
   return(retcode == TRADE_RETCODE_PLACED || retcode == TRADE_RETCODE_DONE
          || retcode == TRADE_RETCODE_DONE_PARTIAL || retcode == TRADE_RETCODE_NO_CHANGES);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong myOrderSend(ENUM_ORDER_TYPE type, double price, double volume, string ordername) //send order, return ticket ("price" is irrelevant for market orders)
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
      return(0);
   int retries = 0;
   int long_trades = TradesCount(ORDER_TYPE_BUY);
   int short_trades = TradesCount(ORDER_TYPE_SELL);
   int long_pending = TradesCount(ORDER_TYPE_BUY_LIMIT) + TradesCount(ORDER_TYPE_BUY_STOP) + TradesCount(ORDER_TYPE_BUY_STOP_LIMIT);
   int short_pending = TradesCount(ORDER_TYPE_SELL_LIMIT) + TradesCount(ORDER_TYPE_SELL_STOP) + TradesCount(ORDER_TYPE_SELL_STOP_LIMIT);
   string ordername_ = ordername;
   if(ordername != "")
      ordername_ = "("+ordername+")";
//test Hedging
   if(!Hedging && ((type % 2 == 0 && short_trades + short_pending > 0) || (type % 2 == 1 && long_trades + long_pending > 0)))
     {
      myAlert("print", "Order"+ordername_+" not sent, hedging not allowed");
      return(0);
     }
//test maximum trades
   if((type % 2 == 0 && long_trades >= MaxLongTrades)
      || (type % 2 == 1 && short_trades >= MaxShortTrades)
      || (long_trades + short_trades >= MaxOpenTrades)
      || (type > 1 && type % 2 == 0 && long_pending >= MaxLongPendingOrders)
      || (type > 1 && type % 2 == 1 && short_pending >= MaxShortPendingOrders)
      || (type > 1 && long_pending + short_pending >= MaxPendingOrders)
     )
     {
      myAlert("print", "Order"+ordername_+" not sent, maximum reached");
      return(0);
     }
//prepare to send order
   MqlTradeRequest request;
   ZeroMemory(request);
   request.action = (type <= 1) ? TRADE_ACTION_DEAL : TRADE_ACTION_PENDING;

//set allowed filling type
   int filling = (int)SymbolInfoInteger(Symbol(),SYMBOL_FILLING_MODE);
   if(request.action == TRADE_ACTION_DEAL && (filling & 1) != 1)
      request.type_filling = ORDER_FILLING_IOC;

   request.magic = MagicNumber;
   request.symbol = Symbol();
   request.volume = NormalizeDouble(volume, LotDigits);
   request.sl = 0;
   request.tp = 0;
   request.deviation = (ulong)MaxSlippage_;  // Cast to ulong to match MqlTradeRequest structure
   request.type = type;
   request.comment = ordername;

   int expiration=(int)SymbolInfoInteger(Symbol(), SYMBOL_EXPIRATION_MODE);
   if((expiration & SYMBOL_EXPIRATION_GTC) != SYMBOL_EXPIRATION_GTC)
     {
      request.type_time = ORDER_TIME_DAY;
      request.type_filling = ORDER_FILLING_RETURN;
     }

   MqlTradeResult result;
   MqlTick last_tick;
   SymbolInfoTick(Symbol(), last_tick);
   if(MaxSpread > 0 && last_tick.ask - last_tick.bid > MaxSpread * myPoint)
     {
      myAlert("order", "Order"+ordername_+" not sent, maximum spread "+DoubleToString(MaxSpread * myPoint, Digits())+" exceeded");
      return(0);
     }
   ZeroMemory(result);
   while(!OrderSuccess(result.retcode) && retries < OrderRetry+1)
     {
      //refresh price before sending order

      SymbolInfoTick(Symbol(), last_tick);
      if(type == ORDER_TYPE_BUY)
         price = last_tick.ask;
      else
         if(type == ORDER_TYPE_SELL)
            price = last_tick.bid;
         else
            if(price < 0) //invalid price for pending order
              {
               myAlert("order", "Order"+ordername_+" not sent, invalid price for pending order");
               return(0);
              }
      request.price = NormalizeDouble(price, Digits());
      if(!OrderSend(request, result) || !OrderSuccess(result.retcode))
        {
         myAlert("print", "OrderSend"+ordername_+" error: "+result.comment);
         Sleep(OrderWait*1000);
        }
      retries++;
     }
   if(!OrderSuccess(result.retcode))
     {
      myAlert("error", "OrderSend"+ordername_+" failed "+IntegerToString(OrderRetry+1)+" times; error: "+result.comment);
      return(0);
     }
   string typestr[8] = {"Buy", "Sell", "Buy Limit", "Sell Limit", "Buy Stop", "Sell Stop", "Buy Stop Limit", "Sell Stop Limit"};
   myAlert("order", "Order sent"+ordername_+": "+typestr[type]+" "+Symbol()+" Magic #"+IntegerToString(MagicNumber));
   return(result.order);
  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int myOrderModifyRel(ENUM_ORDER_TYPE type, ulong ticket, double SL, double TP) //works for positions and orders, modify SL and TP (relative to open price), zero targets do not modify, ticket is irrelevant for open positions
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
      return(-1);
   bool netting = AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
   int retries = 0;
   int err = 0;
   SL = NormalizeDouble(SL, Digits());
   TP = NormalizeDouble(TP, Digits());
   if(SL < 0)
      SL = 0;
   if(TP < 0)
      TP = 0;
//prepare to select order
   Sleep(10);
   if((type <= 1 && ((netting && !PositionSelect(Symbol())) || (!netting && !PositionSelectByTicket(ticket)))) || (type > 1 && !OrderSelect(ticket)))
     {
      err = GetLastError();
      myAlert("error", "PositionSelect / OrderSelect failed; error #"+IntegerToString(err));
      return(-1);
     }
//ignore open positions other than "type"
   if(type <= 1 && PositionGetInteger(POSITION_TYPE) != type)
      return(0);
//prepare to modify order, convert relative to absolute
   double openprice = (type <= 1) ? PositionGetDouble(POSITION_PRICE_OPEN) : OrderGetDouble(ORDER_PRICE_OPEN);
   if(((type <= 1) ? PositionGetInteger(POSITION_TYPE) : OrderGetInteger(ORDER_TYPE)) % 2 == 0) //buy
     {
      if(NormalizeDouble(SL, Digits()) != 0)
         SL = openprice - SL;
      if(NormalizeDouble(TP, Digits()) != 0)
         TP = openprice + TP;
     }
   else //sell
     {
      if(NormalizeDouble(SL, Digits()) != 0)
         SL = openprice + SL;
      if(NormalizeDouble(TP, Digits()) != 0)
         TP = openprice - TP;
     }
   double currentSL = (type <= 1) ? PositionGetDouble(POSITION_SL) : OrderGetDouble(ORDER_SL);
   double currentTP = (type <= 1) ? PositionGetDouble(POSITION_TP) : OrderGetDouble(ORDER_TP);
   if(NormalizeDouble(SL, Digits()) == 0)
      SL = currentSL; //not to modify
   if(NormalizeDouble(TP, Digits()) == 0)
      TP = currentTP; //not to modify
   if(NormalizeDouble(SL - currentSL, Digits()) == 0
      && NormalizeDouble(TP - currentTP, Digits()) == 0)
      return(0); //nothing to do
   MqlTradeRequest request;
   ZeroMemory(request);
   request.action = (type <= 1) ? TRADE_ACTION_SLTP : TRADE_ACTION_MODIFY;
   if(type > 1)
      request.order = ticket;
   else
      request.position = PositionGetInteger(POSITION_TICKET);
   request.symbol = Symbol();
   request.price = (type <= 1) ? PositionGetDouble(POSITION_PRICE_OPEN) : OrderGetDouble(ORDER_PRICE_OPEN);
   request.sl = NormalizeDouble(SL, Digits());
   request.tp = NormalizeDouble(TP, Digits());
   request.deviation = (ulong)MaxSlippage_;  // Cast to ulong to match MqlTradeRequest structure
   MqlTradeResult result;
   ZeroMemory(result);
   while(!OrderSuccess(result.retcode) && retries < OrderRetry+1)
     {
      if(!OrderSend(request, result) || !OrderSuccess(result.retcode))
        {
         err = GetLastError();
         myAlert("print", "OrderModify error #"+IntegerToString(err));
         Sleep(OrderWait*1000);
        }
      retries++;
     }
   if(!OrderSuccess(result.retcode))
     {
      myAlert("error", "OrderModify failed "+IntegerToString(OrderRetry+1)+" times; error #"+IntegerToString(err));
      return(-1);
     }
   string alertstr = "Order modify: ticket="+IntegerToString(ticket);
   if(NormalizeDouble(SL, Digits()) != 0)
      alertstr = alertstr+" SL="+DoubleToString(SL);
   if(NormalizeDouble(TP, Digits()) != 0)
      alertstr = alertstr+" TP="+DoubleToString(TP);
   myAlert("modify", alertstr);
   return(0);
  }


//+------------------------------------------------------------------+
//| Function to check if the current server time is within trading hours |
//+------------------------------------------------------------------+
bool IsWithinTradingHours() {
   datetime currentTime = TimeCurrent(); // Get current server time
   MqlDateTime currentDateTime;
   TimeToStruct(currentTime, currentDateTime); // Break down into components

   // Convert current time to minutes since midnight
   int currentTimeMinutes = currentDateTime.hour * 60 + currentDateTime.min;

   // Convert trading hours to minutes since midnight
   int startTradingTimeMinutes = TOD_From_Hour * 60 + TOD_From_Min;
   int endTradingTimeMinutes = TOD_To_Hour * 60 + TOD_To_Min;

   // Handle overnight trading hours (end time is past midnight)
   if (endTradingTimeMinutes < startTradingTimeMinutes) {
      // If current time is before end time (early morning next day)
      if (currentTimeMinutes < endTradingTimeMinutes) {
         return true;
      }
      // If current time is after start time (current day before midnight)
      if (currentTimeMinutes >= startTradingTimeMinutes) {
         return true;
      }
      return false; // Otherwise, it's outside trading hours
   }

   // Handle standard trading hours (same day)
   return currentTimeMinutes >= startTradingTimeMinutes && currentTimeMinutes <= endTradingTimeMinutes;
}

#endif // MONEY_PROTECTOR_MQH
