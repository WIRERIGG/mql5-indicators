#ifndef IS_NEWS_EVENT_MQH
#define IS_NEWS_EVENT_MQH

//+------------------------------------------------------------------+
//| Check for news events affecting the current symbol               |
//+------------------------------------------------------------------+
bool isNewsEvent() {
   bool isNews = false;
   int totalNews = 0;

   // Define time range for news lookback and lookahead
   datetime startTime = TimeTradeServer() - PeriodSeconds(PERIOD_D1);
   datetime endTime = TimeTradeServer() + PeriodSeconds(PERIOD_D1);
   datetime timeRange = PeriodSeconds(PERIOD_H1);
   datetime timeBefore = TimeTradeServer() - timeRange;
   datetime timeAfter = TimeTradeServer() + timeRange;

   // Retrieve calendar data
   MqlCalendarValue values[];
   int valuesTotal = CalendarValueHistory(values, startTime, endTime);

   Print("Total Calendar Values: ", valuesTotal, " | Array Size: ", ArraySize(values));
   if (valuesTotal > 0) {
      Print("Server Time: ", TimeTradeServer());
      ArrayPrint(values); // Debugging purpose
   }

   Print("Lookback Time: ", timeBefore, " | Current Time: ", TimeTradeServer());
   Print("Lookahead Time: ", timeAfter, " | Current Time: ", TimeTradeServer());

   // Process calendar data
   for (int i = 0; i < valuesTotal; i++) {
      MqlCalendarEvent event;
      if (!CalendarEventById(values[i].event_id, event)) {
         Print("Error fetching event by ID: ", GetLastError());
         continue;
      }

      MqlCalendarCountry country;
      if (!CalendarCountryById(event.country_id, country)) {
         Print("Error fetching country by ID: ", GetLastError());
         continue;
      }

      // Check if the event's currency matches the current symbol
      if (StringFind(_Symbol, country.currency) >= 0) {
         // Focus only on moderate-importance news
         if (event.importance == CALENDAR_IMPORTANCE_MODERATE) {
            if (values[i].time <= TimeTradeServer() && values[i].time >= timeBefore) {
               Print("News Released: ", event.name, " | Currency: ", country.currency, 
                     " | Importance: ", EnumToString(event.importance),
                     " | Time: ", values[i].time);
               totalNews++;
            } else if (values[i].time >= TimeTradeServer() && values[i].time <= timeAfter) {
               Print("Upcoming News: ", event.name, " | Currency: ", country.currency, 
                     " | Importance: ", EnumToString(event.importance),
                     " | Time: ", values[i].time);
               totalNews++;
            }
         }
      }
   }

   // Determine if any relevant news was found
   if (totalNews > 0) {
      isNews = true;
      Print("News Found: Total = ", totalNews, "/", ArraySize(values));
   } else {
      isNews = false;
      Print("No News Found: Total = ", totalNews, "/", ArraySize(values));
   }

   return isNews;
}

#endif // IS_NEWS_EVENT_MQH
