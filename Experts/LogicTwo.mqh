//+------------------------------------------------------------------+
//|                                                     LogicTwo.mqh |
//|                  RIGGWIRE Trading System - Aggressive Scalping   |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
//| Strategy: High-Frequency Scalping with Tight Risk Management    |
//| - Tighter stops for quick exits                                 |
//| - Faster trailing stops to lock profits quickly                 |
//| - High volatility filter (ATR-based)                            |
//| - Simplified entry logic for speed                              |
//+------------------------------------------------------------------+

#include "Money Protector.mqh"
#include "TrendConfirmation.mqh"

//+------------------------------------------------------------------+
//| Standalone Compilation Support for LogicTwo                     |
//| SCALPING PARAMETERS: Aggressive, tight risk management          |
//+------------------------------------------------------------------+
#ifndef PARENT_DECLARED
   // Logic-specific trading parameters - SCALPING CONFIGURATION
   int SL_Points = 10;              // Tight stop loss for scalping
   double TRAILING_SL = 30.0;       // Fast trailing stop
   double STEPS = 5.0;              // Smaller step size
   double BREAKEVEN = 15.0;         // Quick breakeven activation

   // Next trade timing variables
   int NextOpenTradeAfterTOD_Hour = 0;
   int NextOpenTradeAfterTOD_Min = 5;  // Faster re-entry (5 min instead of 15)

   // ATR variables are provided by TrendConfirmation.mqh (included above)
#endif

//+------------------------------------------------------------------+
//| CheckHighVolatility - ATR-Based Volatility Filter               |
//| Only trade when market volatility is sufficient for scalping    |
//+------------------------------------------------------------------+
bool CheckHighVolatility()
{
   // Get ATR value to measure volatility
   double atrArray[];
   ArraySetAsSeries(atrArray, true);

   int atrHandle = iATR(_Symbol, PERIOD_M5, ATRPeriod1);
   if(atrHandle == INVALID_HANDLE)
      return false;

   if(CopyBuffer(atrHandle, 0, 0, 1, atrArray) <= 0)
   {
      IndicatorRelease(atrHandle);
      return false;
   }

   double currentATR = atrArray[0];
   IndicatorRelease(atrHandle);

   // Require ATR above average (volatility filter)
   // Higher volatility = better for scalping
   return (currentATR > ATRMultiplier1 * myPoint);
}

//+------------------------------------------------------------------+
//| LogicTwo - Aggressive Scalping Strategy                         |
//| Fast entries with tight risk management and quick profit taking |
//+------------------------------------------------------------------+
void LogicTwo()
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
   // STEP 4: Apply Trailing Stop Management (Aggressive)
   // ===================================================================
   TrailingStopTrail(ORDER_TYPE_BUY, TRAILING_SL * myPoint, STEPS * myPoint, true, BREAKEVEN * myPoint);
   TrailingStopTrail(ORDER_TYPE_SELL, TRAILING_SL * myPoint, STEPS * myPoint, true, BREAKEVEN * myPoint);

   // ===================================================================
   // STEP 5: Process BULLISH Signal (SCALPING BUY)
   // ===================================================================
   if(g_lastSignalState.bullish)
   {
      // --- Volatility Filter for Scalping ---
      if(!CheckHighVolatility())
         return;  // Skip trade if volatility too low

      MqlTick last_tick;
      SymbolInfoTick(Symbol(), last_tick);
      price = last_tick.ask;
      SL = SL_Points * myPoint;  // Tight 10-point stop
      TradeSize = MM_Size(SL);

      // --- Safety Filters (Simplified for Speed) ---
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

      // --- Update Next Trade Time (5-minute intervals for scalping) ---
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

      // --- Apply Tight Stop Loss ---
      myOrderModifyRel(ORDER_TYPE_BUY, ticket, SL, 0);
   }

   // ===================================================================
   // STEP 6: Process BEARISH Signal (SCALPING SELL)
   // ===================================================================
   if(g_lastSignalState.bearish)
   {
      // --- Volatility Filter for Scalping ---
      if(!CheckHighVolatility())
         return;  // Skip trade if volatility too low

      MqlTick last_tick;
      SymbolInfoTick(Symbol(), last_tick);
      price = last_tick.bid;
      SL = SL_Points * myPoint;  // Tight 10-point stop
      TradeSize = MM_Size(SL);

      // --- Safety Filters (Simplified for Speed) ---
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

      // --- Update Next Trade Time (5-minute intervals for scalping) ---
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

      // --- Apply Tight Stop Loss ---
      myOrderModifyRel(ORDER_TYPE_SELL, ticket, SL, 0);
   }
}
//+------------------------------------------------------------------+
