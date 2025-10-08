//+------------------------------------------------------------------+
//|                                                     LogicOne.mqh |
//|                         RIGGWIRE Trading System - Logic Module 1 |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

#include "Money Protector.mqh"
#include "TrendConfirmation.mqh"

//+------------------------------------------------------------------+
//| Standalone Compilation Support for LogicOne                     |
//| Declare Logic-specific variables when compiled standalone        |
//| NOTE: ATR variables provided by TrendConfirmation.mqh           |
//+------------------------------------------------------------------+
#ifndef PARENT_DECLARED
   // Logic-specific trading parameters
   int SL_Points = 20;
   double TRAILING_SL = 50.0;
   double STEPS = 10.0;
   double BREAKEVEN = 30.0;

   // Next trade timing variables
   int NextOpenTradeAfterTOD_Hour = 0;
   int NextOpenTradeAfterTOD_Min = 15;

   // ATR variables are provided by TrendConfirmation.mqh (included above)
#endif

//+------------------------------------------------------------------+
//| CloseOldTrades - Close trades older than 1 day                  |
//| Risk Management: No trade should exceed 24 hours                |
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

      // Close if exceeds 1 day
      if(tradeDuration >= MAX_TRADE_DURATION_SECONDS)
      {
         if(trade.PositionClose(ticket))
         {
            Print("Position #", ticket, " closed - Max duration exceeded (24 hours)");
         }
         else
         {
            Print("Failed to close position #", ticket, " - Error: ", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| LogicOne - Primary Trading Logic Module                         |
//| Executes trades based on TrendConfirmation signals with         |
//| multi-indicator confluence and risk management                  |
//+------------------------------------------------------------------+
void LogicOne()
{
   // ===================================================================
   // STEP 1: Update Technical Analysis Signals
   // ===================================================================
   TrendConfirmation();

   // ===================================================================
   // STEP 2: Close Trades Exceeding 1 Day Duration
   // ===================================================================
   CloseOldTrades();

   // ===================================================================
   // STEP 3: Initialize Trade Variables
   // ===================================================================
   ulong ticket = 0;
   double price;
   double TradeSize;
   double SL;
   datetime currentTime = TimeCurrent();

   // ===================================================================
   // STEP 4: Apply Trailing Stop Management
   // ===================================================================
   TrailingStopTrail(ORDER_TYPE_BUY, TRAILING_SL * myPoint, STEPS * myPoint, true, BREAKEVEN * myPoint);
   TrailingStopTrail(ORDER_TYPE_SELL, TRAILING_SL * myPoint, STEPS * myPoint, true, BREAKEVEN * myPoint);

   // ===================================================================
   // STEP 5: Process BULLISH Signal (BUY Trade)
   // ===================================================================
   if(g_lastSignalState.bullish)
   {
      MqlTick last_tick;
      SymbolInfoTick(Symbol(), last_tick);
      price = last_tick.ask;
      SL = SL_Points * myPoint;
      TradeSize = MM_Size(SL);

      // --- Safety Filters ---
      // No existing positions allowed
      if(TradesCount(ORDER_TYPE_BUY) + TradesCount(ORDER_TYPE_SELL) > 0)
         return;

      // Next trade time of day filter
      if(TimeCurrent() <= NextTradeTime)
         return;

      // Trading hours filter
      if(!inTimeInterval(TimeCurrent(), TOD_From_Hour, TOD_From_Min, TOD_To_Hour, TOD_To_Min))
         return;

      // Trading day of week filter
      if(!TradeDayOfWeek())
         return;

      // --- Execute Trade ---
      if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED))
      {
         ticket = myOrderSend(ORDER_TYPE_BUY, price, TradeSize, "");
         if(ticket == 0)
            return;
      }
      else
      {
         myAlert("order", ""); // Auto-trading disabled, send alert only
      }

      // --- Update Next Trade Time ---
      string timeStr = IntegerToString(NextOpenTradeAfterTOD_Hour, 2) + ":" +
                       IntegerToString(NextOpenTradeAfterTOD_Min, 2);
      NextTradeTime = StringToTime(timeStr);

      // Advance to next trading period
      datetime differenceInSeconds = TimeCurrent() - NextTradeTime;
      if(differenceInSeconds > 0)
      {
         datetime periodsToAdd = (differenceInSeconds / (NextOpenTradeAfterTOD_Min * 60)) + 1;
         NextTradeTime += periodsToAdd * NextOpenTradeAfterTOD_Min * 60;
      }

      // --- Apply Stop Loss ---
      myOrderModifyRel(ORDER_TYPE_BUY, ticket, SL, 0);
   }

   // ===================================================================
   // STEP 6: Process BEARISH Signal (SELL Trade)
   // ===================================================================
   if(g_lastSignalState.bearish)
   {
      MqlTick last_tick;
      SymbolInfoTick(Symbol(), last_tick);
      price = last_tick.bid;
      SL = SL_Points * myPoint;
      TradeSize = MM_Size(SL);

      // --- Safety Filters ---
      // No existing positions allowed
      if(TradesCount(ORDER_TYPE_BUY) + TradesCount(ORDER_TYPE_SELL) > 0)
         return;

      // Next trade time of day filter
      if(TimeCurrent() <= NextTradeTime)
         return;

      // Trading hours filter
      if(!inTimeInterval(TimeCurrent(), TOD_From_Hour, TOD_From_Min, TOD_To_Hour, TOD_To_Min))
         return;

      // Trading day of week filter
      if(!TradeDayOfWeek())
         return;

      // --- Execute Trade ---
      if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED))
      {
         ticket = myOrderSend(ORDER_TYPE_SELL, price, TradeSize, "");
         if(ticket == 0)
            return;
      }
      else
      {
         myAlert("order", ""); // Auto-trading disabled, send alert only
      }

      // --- Update Next Trade Time ---
      string timeStr = IntegerToString(NextOpenTradeAfterTOD_Hour, 2) + ":" +
                       IntegerToString(NextOpenTradeAfterTOD_Min, 2);
      NextTradeTime = StringToTime(timeStr);

      // Advance to next trading period
      datetime differenceInSeconds = TimeCurrent() - NextTradeTime;
      if(differenceInSeconds > 0)
      {
         datetime periodsToAdd = (differenceInSeconds / (NextOpenTradeAfterTOD_Min * 60)) + 1;
         NextTradeTime += periodsToAdd * NextOpenTradeAfterTOD_Min * 60;
      }

      // --- Apply Stop Loss ---
      myOrderModifyRel(ORDER_TYPE_SELL, ticket, SL, 0);
   }
}
//+------------------------------------------------------------------+
