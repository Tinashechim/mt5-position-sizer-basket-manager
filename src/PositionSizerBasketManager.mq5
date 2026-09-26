#property copyright "Tinashe Chimanikire"
#property version   "1.00"
#property strict


// Calculates the combined floating profit/loss
// of all currently open positions
double GetBasketProfit()
{
   double basket_profit = 0.0;

   int total_positions = PositionsTotal();

   for(int i = 0; i < total_positions; i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket > 0)
      {
         double position_profit = PositionGetDouble(POSITION_PROFIT);

         basket_profit += position_profit;
      }
   }

   return basket_profit;
}


// Displays basket information on the chart
void UpdateDisplay()
{
   double basket_profit = GetBasketProfit();

   Comment(
      "MT5 Position Sizer & Basket Manager\n",
      "Open Positions: ", PositionsTotal(), "\n",
      "Basket P/L: ", DoubleToString(basket_profit, 2)
   );
}


// Runs once when the EA is attached
int OnInit()
{
   Print("Position Sizer & Basket Manager started.");

   UpdateDisplay();

   return(INIT_SUCCEEDED);
}


// Runs when the EA is removed
void OnDeinit(const int reason)
{
   Comment("");

   Print("Position Sizer & Basket Manager stopped.");
}


// Runs whenever a new price tick arrives
void OnTick()
{
   UpdateDisplay();
}