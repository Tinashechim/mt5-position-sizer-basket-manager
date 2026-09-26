#include <Trade/Trade.mqh>

#property copyright "Tinashe Chimanikire"
#property version   "1.20"
#property strict


// Trade object used for closing positions
CTrade trade;


// Basket take-profit modes
enum BasketTPMode
{
   TP_MONEY,
   TP_PERCENTAGE
};


// User settings
input BasketTPMode BasketTPType = TP_PERCENTAGE;
input double BasketTPValue = 2.0;


// Balance recorded when the EA starts
double basket_start_balance = 0.0;


// Prevents repeated closing attempts once the target is reached
bool basket_closing = false;


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


// Calculates the basket take-profit amount
// in the account currency
double GetBasketTarget()
{
   // Money mode
   if(BasketTPType == TP_MONEY)
   {
      return BasketTPValue;
   }

   // Percentage mode
   return basket_start_balance * (BasketTPValue / 100.0);
}


// Closes every currently open position
// regardless of symbol
bool CloseAllPositions()
{
   bool all_closed = true;

   // Work backwards because the number of positions
   // changes as positions are closed
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket > 0)
      {
         string symbol = PositionGetString(POSITION_SYMBOL);

         Print(
            "Attempting to close position ",
            ticket,
            " on ",
            symbol
         );

         if(!trade.PositionClose(ticket))
         {
            Print(
               "Failed to close position ",
               ticket,
               ". Retcode: ",
               trade.ResultRetcode(),
               " - ",
               trade.ResultRetcodeDescription()
            );

            all_closed = false;
         }
      }
   }

   return all_closed;
}


// Checks whether the basket target has been reached
void CheckBasketTakeProfit()
{
   // Nothing to manage if there are no positions
   if(PositionsTotal() == 0)
   {
      basket_closing = false;
      return;
   }

   double basket_profit = GetBasketProfit();
   double basket_target = GetBasketTarget();

   // Do nothing until the target is reached
   if(basket_profit < basket_target)
   {
      return;
   }

   // Prevent duplicate closing attempts on the same tick
   if(basket_closing)
   {
      return;
   }

   basket_closing = true;

   Print(
      "Basket TP reached. Profit: ",
      basket_profit,
      " Target: ",
      basket_target
   );

   bool all_closed = CloseAllPositions();

   if(all_closed)
   {
      Print("Basket successfully closed.");
   }
   else
   {
      Print("Some positions could not be closed.");
   }

   basket_closing = false;
}


// Displays basket information on the chart
void UpdateDisplay()
{
   double basket_profit = GetBasketProfit();
   double basket_target = GetBasketTarget();

   string mode_text;

   if(BasketTPType == TP_MONEY)
   {
      mode_text = "Money";
   }
   else
   {
      mode_text = "Percentage";
   }

   Comment(
      "MT5 Position Sizer & Basket Manager\n",
      "\n",
      "Open Positions: ", PositionsTotal(), "\n",
      "Basket P/L: ", DoubleToString(basket_profit, 2), "\n",
      "\n",
      "Basket TP Mode: ", mode_text, "\n",
      "Basket TP Value: ", DoubleToString(BasketTPValue, 2), "\n",
      "Basket Start Balance: ",
      DoubleToString(basket_start_balance, 2), "\n",
      "Basket Profit Target: ",
      DoubleToString(basket_target, 2)
   );
}


// Runs once when the EA is attached
int OnInit()
{
   // Validate the user's target
   if(BasketTPValue <= 0)
   {
      Print("ERROR: Basket TP value must be greater than zero.");

      return(INIT_PARAMETERS_INCORRECT);
   }

   // Capture balance used for percentage calculations
   basket_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);

   Print("Position Sizer & Basket Manager started.");
   Print("Basket starting balance: ", basket_start_balance);
   Print("Basket profit target: ", GetBasketTarget());

   UpdateDisplay();

   return(INIT_SUCCEEDED);
}


// Runs when the EA is removed
void OnDeinit(const int reason)
{
   Comment("");

   Print("Position Sizer & Basket Manager stopped.");
}


// Runs whenever a new tick arrives
void OnTick()
{
   UpdateDisplay();

   CheckBasketTakeProfit();
}