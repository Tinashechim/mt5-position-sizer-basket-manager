#property copyright "Tinashe Chimanikire"
#property version   "1.00"
#property strict

// Runs once when the EA is attached to a chart
int OnInit()
{
   Print("Position Sizer & Basket Manager started.");

   return(INIT_SUCCEEDED);
}


// Runs when the EA is removed from the chart
void OnDeinit(const int reason)
{
   Print("Position Sizer & Basket Manager stopped.");
}


// Runs whenever the chart receives a new price tick
void OnTick()
{

}