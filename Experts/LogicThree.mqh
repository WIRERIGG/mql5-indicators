//+------------------------------------------------------------------+
//|                                                   LogicThree.mqh |
//|                  RIGGWIRE Trading System - Conservative Swing    |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
//| Strategy: Conservative Swing Trading with Strong Trend Following|
//| - Wider stops for swing positions                               |
//| - Slower trailing stops for bigger profit targets               |
//| - Strong trend confirmation (no contrarian entries)             |
//| - Higher timeframe alignment required                           |
//+------------------------------------------------------------------+

#include "Money Protector.mqh"
#include "TrendConfirmation.mqh"

//+------------------------------------------------------------------+
//| Standalone Compilation Support for LogicThree                   |
//| SWING PARAMETERS: Conservative, trend-following                 |
//+------------------------------------------------------------------+
#ifndef PARENT_DECLARED
   // Logic-specific trading parameters - SWING TRADING CONFIGURATION
   int SL_Points = 40;              // Wide stop loss for swing trades
   double TRAILING_SL = 100.0;      // Slow trailing stop for bigger moves
   double STEPS = 20.0;             // Larger step size
   double BREAKEVEN = 60.0;         // Later breakeven activation

   // Next trade timing variables
   int NextOpenTradeAfterTOD_Hour = 0;
   int NextOpenTradeAfterTOD_Min = 30;  // Slower re-entry (30 min)

   // ATR variables are provided by TrendConfirmation.mqh (included above)
#endif

//+------------------------------------------------------------------+
//| CheckStrongTrend - Multi-Timeframe Trend Confirmation           |
//| Only trade when trend is confirmed across multiple timeframes   |
//+------------------------------------------------------------------+
bool CheckStrongTrend(bool isBullish)
{
   // Get EMA values on higher timeframe (H1) for stronger confirmation
   double ema5_H1[], ema13_H1[];
   ArraySetAsSeries(ema5_H1, true);
   ArraySetAsSeries(ema13_H1, true);

   int ema5Handle = iMA(_Symbol, PERIOD_H1, 5, 0, MODE_EMA, PRICE_CLOSE);
   int ema13Handle = iMA(_Symbol, PERIOD_H1, 13, 0, MODE_EMA, PRICE_CLOSE);

   if(ema5Handle == INVALID_HANDLE || ema13Handle == INVALID_HANDLE)
      return false;

   if(CopyBuffer(ema5Handle, 0, 0, 2, ema5_H1) <= 0 ||
      CopyBuffer(ema13Handle, 0, 0, 2, ema13_H1) <= 0)
   {
      IndicatorRelease(ema5Handle);
      IndicatorRelease(ema13Handle);
      return false;
   }

   IndicatorRelease(ema5Handle);
   IndicatorRelease(ema13Handle);

   // For BULLISH: EMA5 must be above EMA13 AND rising
   if(isBullish)
   {
      bool emaAligned = (ema5_H1[0] > ema13_H1[0]);
      bool emaRising = (ema5_H1[0] > ema5_H1[1]);
      return (emaAligned && emaRising);
   }
   // For BEARISH: EMA5 must be below EMA13 AND falling
   else
   {
      bool emaAligned = (ema5_H1[0] < ema13_H1[0]);
      bool emaFalling = (ema5_H1[0] < ema5_H1[1]);
      return (emaAligned && emaFalling);
   }
}

//+------------------------------------------------------------------+
//| CheckSupertrendAlignment - Confirm Supertrend Direction         |
//| Only trade WITH the Supertrend direction (no contrarian)        |
//+------------------------------------------------------------------+
bool CheckSupertrendAlignment(bool isBullish)
{
   double supertrendArray[];
   ArraySetAsSeries(supertrendArray, true);

   int supertrendHandle = iCustom(_Symbol, PERIOD_M5, "MT5 SUPERTREND1",
                                   ATRPeriod1, ATRMultiplier1, ATRMaxBars);

   if(supertrendHandle == INVALID_HANDLE)
      return false;

   if(CopyBuffer(supertrendHandle, 0, 0, 1, supertrendArray) <= 0)
   {
      IndicatorRelease(supertrendHandle);
      return false;
   }

   double currentSupertrend = supertrendArray[0];
   IndicatorRelease(supertrendHandle);

   MqlTick last_tick;
   SymbolInfoTick(_Symbol, last_tick);

   // For BULLISH: Price must be ABOVE Supertrend (trend-following)
   if(isBullish)
      return (last_tick.ask > currentSupertrend);
   // For BEARISH: Price must be BELOW Supertrend (trend-following)
   else
      return (last_tick.bid < currentSupertrend);
}

//+------------------------------------------------------------------+
//| LogicThree - Conservative Swing Trading Strategy                |
//| Trend-following with strong confirmation and wider risk targets |
//+------------------------------------------------------------------+
void LogicThree()
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
   // STEP 4: Apply Trailing Stop Management (Conservative)
   // ===================================================================
   TrailingStopTrail(ORDER_TYPE_BUY, TRAILING_SL * myPoint, STEPS * myPoint, true, BREAKEVEN * myPoint);
   TrailingStopTrail(ORDER_TYPE_SELL, TRAILING_SL * myPoint, STEPS * myPoint, true, BREAKEVEN * myPoint);

   // ===================================================================
   // STEP 5: Process BULLISH Signal (SWING BUY)
   // ===================================================================
   if(g_lastSignalState.bullish)
   {
      // --- Strong Trend Confirmation (H1 timeframe) ---
      if(!CheckStrongTrend(true))
         return;  // Skip if H1 trend not confirmed

      // --- Supertrend Alignment (Trend-Following Only) ---
      if(!CheckSupertrendAlignment(true))
         return;  // Skip if price not above Supertrend

      MqlTick last_tick;
      SymbolInfoTick(Symbol(), last_tick);
      price = last_tick.ask;
      SL = SL_Points * myPoint;  // Wide 40-point stop
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

      // --- Update Next Trade Time (30-minute intervals for swing) ---
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

      // --- Apply Wide Stop Loss ---
      myOrderModifyRel(ORDER_TYPE_BUY, ticket, SL, 0);
   }

   // ===================================================================
   // STEP 6: Process BEARISH Signal (SWING SELL)
   // ===================================================================
   if(g_lastSignalState.bearish)
   {
      // --- Strong Trend Confirmation (H1 timeframe) ---
      if(!CheckStrongTrend(false))
         return;  // Skip if H1 trend not confirmed

      // --- Supertrend Alignment (Trend-Following Only) ---
      if(!CheckSupertrendAlignment(false))
         return;  // Skip if price not below Supertrend

      MqlTick last_tick;
      SymbolInfoTick(Symbol(), last_tick);
      price = last_tick.bid;
      SL = SL_Points * myPoint;  // Wide 40-point stop
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

      // --- Update Next Trade Time (30-minute intervals for swing) ---
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

      // --- Apply Wide Stop Loss ---
      myOrderModifyRel(ORDER_TYPE_SELL, ticket, SL, 0);
   }
}
//+------------------------------------------------------------------+
