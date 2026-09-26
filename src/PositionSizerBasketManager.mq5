#include <Trade/Trade.mqh>

#property copyright "Tinashe Chimanikire"
#property version   "2.02"
#property strict

CTrade trade;


// ============================================================
// RESPONSIVE PANEL
// ============================================================

#define BASE_PANEL_X       12
#define BASE_PANEL_Y       16
#define BASE_PANEL_WIDTH   304
#define BASE_PANEL_HEIGHT  742

#define BASE_LABEL_X       11
#define BASE_VALUE_X       160
#define BASE_UNIT_X        256

#define BASE_FONT_TITLE    6
#define BASE_FONT_SECTION  6
#define BASE_FONT_NORMAL   5
#define BASE_FONT_SMALL    5


double panel_scale = 1.0;


// ============================================================
// ENUMS
// ============================================================

enum RiskMode
{
   RISK_MONEY,
   RISK_PERCENTAGE
};

enum DailyTargetMode
{
   DAILY_MONEY,
   DAILY_PERCENTAGE
};


// ============================================================
// SHARED GLOBAL VARIABLES
// ============================================================

string GV_ACTIVE;
string GV_START_BALANCE;
string GV_CLOSE_LOCK;

string GV_DAILY_MODE;
string GV_DAILY_TARGET;


// ============================================================
// LOCAL POSITION SIZER VARIABLES
// ============================================================

RiskMode risk_mode = RISK_PERCENTAGE;

double risk_value = 1.0;

bool sl_line_enabled = true;


// ============================================================
// RESPONSIVE SIZE HELPERS
// ============================================================

int S(double value)
{
   int result =
      (int)MathRound(
         value * panel_scale
      );

   if(result < 1)
      result = 1;

   return result;
}


int PanelX()
{
   return S(BASE_PANEL_X);
}


int PanelY()
{
   return S(BASE_PANEL_Y);
}


int PanelWidth()
{
   return S(BASE_PANEL_WIDTH);
}


int PanelHeight()
{
   return S(BASE_PANEL_HEIGHT);
}


int LabelX()
{
   return
      PanelX() +
      S(BASE_LABEL_X);
}


int ValueX()
{
   return
      PanelX() +
      S(BASE_VALUE_X);
}


int UnitX()
{
   return
      PanelX() +
      S(BASE_UNIT_X);
}


int FontSize(int base_size)
{
   int size =
      (int)MathRound(
         base_size * panel_scale
      );

   if(size < 5)
      size = 5;

   return size;
}


// ============================================================
// CALCULATE RESPONSIVE SCALE
// ============================================================

void CalculatePanelScale()
{
   long chart_width =
      ChartGetInteger(
         0,
         CHART_WIDTH_IN_PIXELS
      );


   long chart_height =
      ChartGetInteger(
         0,
         CHART_HEIGHT_IN_PIXELS
      );


   if(
      chart_width <= 0 ||
      chart_height <= 0
   )
   {
      panel_scale = 1.0;
      return;
   }


   double available_width =
      (double)chart_width - 20.0;


   double available_height =
      (double)chart_height - 20.0;


   double width_scale =
      available_width /
      (double)(
         BASE_PANEL_X +
         BASE_PANEL_WIDTH
      );


   double height_scale =
      available_height /
      (double)(
         BASE_PANEL_Y +
         BASE_PANEL_HEIGHT
      );


   panel_scale =
      MathMin(
         width_scale,
         height_scale
      );


   if(panel_scale > 1.0)
      panel_scale = 1.0;


   if(panel_scale < 0.50)
      panel_scale = 0.50;
}


// ============================================================
// GLOBAL VARIABLE NAMES
// ============================================================

void CreateGlobalVariableNames()
{
   string account =
      IntegerToString(
         (int)AccountInfoInteger(
            ACCOUNT_LOGIN
         )
      );


   string prefix =
      "PSBM_" + account + "_";


   GV_ACTIVE =
      prefix + "ACTIVE";


   GV_START_BALANCE =
      prefix + "START_BALANCE";


   GV_CLOSE_LOCK =
      prefix + "CLOSE_LOCK";


   GV_DAILY_MODE =
      prefix + "DAILY_MODE";


   GV_DAILY_TARGET =
      prefix + "DAILY_TARGET";
}


// ============================================================
// INITIALIZE SHARED VARIABLES
// ============================================================

void InitializeSharedVariables()
{
   if(!GlobalVariableCheck(GV_ACTIVE))
      GlobalVariableSet(
         GV_ACTIVE,
         0.0
      );


   if(!GlobalVariableCheck(GV_START_BALANCE))
      GlobalVariableSet(
         GV_START_BALANCE,
         0.0
      );


   if(!GlobalVariableCheck(GV_CLOSE_LOCK))
      GlobalVariableSet(
         GV_CLOSE_LOCK,
         0.0
      );


   if(!GlobalVariableCheck(GV_DAILY_MODE))
      GlobalVariableSet(
         GV_DAILY_MODE,
         (double)DAILY_PERCENTAGE
      );


   if(!GlobalVariableCheck(GV_DAILY_TARGET))
      GlobalVariableSet(
         GV_DAILY_TARGET,
         5.0
      );
}


// ============================================================
// BASKET STATE
// ============================================================

bool IsBasketActive()
{
   return
      GlobalVariableGet(
         GV_ACTIVE
      ) == 1.0;
}


double GetBasketStartBalance()
{
   return
      GlobalVariableGet(
         GV_START_BALANCE
      );
}


// ============================================================
// DAILY TARGET SETTINGS
// ============================================================

DailyTargetMode GetDailyTargetMode()
{
   return
      (DailyTargetMode)
      (int)GlobalVariableGet(
         GV_DAILY_MODE
      );
}


double GetDailyTargetValue()
{
   return
      GlobalVariableGet(
         GV_DAILY_TARGET
      );
}


// ============================================================
// DAILY SESSION
//
// 23:30:00 -> next day 23:29:59
// ============================================================

datetime GetDailySessionStart()
{
   datetime now =
      TimeCurrent();


   MqlDateTime session_struct;


   TimeToStruct(
      now,
      session_struct
   );


   session_struct.hour = 23;
   session_struct.min  = 30;
   session_struct.sec  = 0;


   datetime today_2330 =
      StructToTime(
         session_struct
      );


   if(now >= today_2330)
      return today_2330;


   return
      today_2330 - 86400;
}


// ============================================================
// CLOSED TRADING P/L
// ============================================================

double GetTodayClosedProfit()
{
   datetime start_time =
      GetDailySessionStart();


   datetime end_time =
      TimeCurrent();


   if(!HistorySelect(
      start_time,
      end_time
   ))
   {
      return 0.0;
   }


   double result = 0.0;


   int total =
      HistoryDealsTotal();


   for(int i = 0; i < total; i++)
   {
      ulong ticket =
         HistoryDealGetTicket(i);


      if(ticket == 0)
         continue;


      ENUM_DEAL_TYPE deal_type =
         (ENUM_DEAL_TYPE)
         HistoryDealGetInteger(
            ticket,
            DEAL_TYPE
         );


      if(
         deal_type != DEAL_TYPE_BUY &&
         deal_type != DEAL_TYPE_SELL
      )
      {
         continue;
      }


      ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)
         HistoryDealGetInteger(
            ticket,
            DEAL_ENTRY
         );


      if(
         entry != DEAL_ENTRY_OUT &&
         entry != DEAL_ENTRY_OUT_BY &&
         entry != DEAL_ENTRY_INOUT
      )
      {
         continue;
      }


      double profit =
         HistoryDealGetDouble(
            ticket,
            DEAL_PROFIT
         );


      double commission =
         HistoryDealGetDouble(
            ticket,
            DEAL_COMMISSION
         );


      double swap =
         HistoryDealGetDouble(
            ticket,
            DEAL_SWAP
         );


      double fee =
         HistoryDealGetDouble(
            ticket,
            DEAL_FEE
         );


      result +=
         profit +
         commission +
         swap +
         fee;
   }


   return result;
}


// ============================================================
// CLOSED TRADES EXIST?
// ============================================================

bool HasClosedTradesToday()
{
   datetime start_time =
      GetDailySessionStart();


   if(!HistorySelect(
      start_time,
      TimeCurrent()
   ))
   {
      return false;
   }


   int total =
      HistoryDealsTotal();


   for(int i = 0; i < total; i++)
   {
      ulong ticket =
         HistoryDealGetTicket(i);


      if(ticket == 0)
         continue;


      ENUM_DEAL_TYPE deal_type =
         (ENUM_DEAL_TYPE)
         HistoryDealGetInteger(
            ticket,
            DEAL_TYPE
         );


      if(
         deal_type != DEAL_TYPE_BUY &&
         deal_type != DEAL_TYPE_SELL
      )
      {
         continue;
      }


      ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)
         HistoryDealGetInteger(
            ticket,
            DEAL_ENTRY
         );


      if(
         entry == DEAL_ENTRY_OUT ||
         entry == DEAL_ENTRY_OUT_BY ||
         entry == DEAL_ENTRY_INOUT
      )
      {
         return true;
      }
   }


   return false;
}


// ============================================================
// DAILY START BALANCE
// ============================================================

double GetDailyStartBalance()
{
   double current_balance =
      AccountInfoDouble(
         ACCOUNT_BALANCE
      );


   double closed_profit =
      GetTodayClosedProfit();


   double start_balance =
      current_balance -
      closed_profit;


   if(start_balance <= 0)
      return current_balance;


   return start_balance;
}


// ============================================================
// CLOSED P/L PERCENTAGE
// ============================================================

double GetTodayClosedProfitPercent()
{
   double start_balance =
      GetDailyStartBalance();


   if(start_balance <= 0)
      return 0.0;


   return
      (
         GetTodayClosedProfit() /
         start_balance
      ) * 100.0;
}


// ============================================================
// DAILY TARGET IN MONEY
// ============================================================

double GetDailyTargetMoney()
{
   double target =
      GetDailyTargetValue();


   if(GetDailyTargetMode() == DAILY_MONEY)
      return target;


   double start_balance =
      GetDailyStartBalance();


   return
      start_balance *
      (target / 100.0);
}


// ============================================================
// REMAINING DAILY TARGET IN MONEY
// ============================================================

double GetRemainingDailyTargetMoney()
{
   double remaining =
      GetDailyTargetMoney() -
      GetTodayClosedProfit();


   if(remaining < 0)
      remaining = 0;


   return remaining;
}


// ============================================================
// REMAINING DAILY TARGET IN PERCENTAGE
// ============================================================

double GetRemainingDailyTargetPercent()
{
   double start_balance =
      GetDailyStartBalance();


   if(start_balance <= 0)
      return 0.0;


   return
      (
         GetRemainingDailyTargetMoney() /
         start_balance
      ) * 100.0;
}


// ============================================================
// DAILY TARGET REACHED
// ============================================================

bool IsDailyTargetReached()
{
   double target_money =
      GetDailyTargetMoney();


   if(target_money <= 0)
      return false;


   return
      GetTodayClosedProfit() >=
      target_money;
}


// ============================================================
// READ DAILY TARGET
// ============================================================

bool ReadDailyTarget()
{
   string text =
      ObjectGetString(
         0,
         "PSBM_DAILY_TARGET_EDIT",
         OBJPROP_TEXT
      );


   double value =
      StringToDouble(text);


   if(value <= 0)
   {
      ObjectSetString(
         0,
         "PSBM_DAILY_TARGET_EDIT",
         OBJPROP_TEXT,
         DoubleToString(
            GetDailyTargetValue(),
            2
         )
      );


      return false;
   }


   GlobalVariableSet(
      GV_DAILY_TARGET,
      value
   );


   return true;
}


// ============================================================
// BASKET PROFIT
// ============================================================

double GetBasketProfit()
{
   double profit = 0.0;


   int total =
      PositionsTotal();


   for(int i = 0; i < total; i++)
   {
      ulong ticket =
         PositionGetTicket(i);


      if(ticket > 0)
      {
         profit +=
            PositionGetDouble(
               POSITION_PROFIT
            );
      }
   }


   return profit;
}


// ============================================================
// EFFECTIVE BASKET TARGET
// ============================================================

double GetBasketTarget()
{
   if(!IsBasketActive())
      return 0.0;


   return
      GetRemainingDailyTargetMoney();
}


// ============================================================
// START BASKET
// ============================================================

void StartBasket()
{
   if(IsBasketActive())
      return;


   double balance =
      AccountInfoDouble(
         ACCOUNT_BALANCE
      );


   GlobalVariableSet(
      GV_START_BALANCE,
      balance
   );


   GlobalVariableSet(
      GV_ACTIVE,
      1.0
   );


   GlobalVariableSet(
      GV_CLOSE_LOCK,
      0.0
   );
}


// ============================================================
// RESET BASKET
// ============================================================

void ResetBasket()
{
   GlobalVariableSet(
      GV_ACTIVE,
      0.0
   );


   GlobalVariableSet(
      GV_START_BALANCE,
      0.0
   );


   GlobalVariableSet(
      GV_CLOSE_LOCK,
      0.0
   );
}


// ============================================================
// UPDATE BASKET STATE
// ============================================================

void UpdateBasketState()
{
   int positions =
      PositionsTotal();


   if(
      positions > 0 &&
      !IsBasketActive()
   )
   {
      StartBasket();

      return;
   }


   if(
      positions == 0 &&
      IsBasketActive()
   )
   {
      ResetBasket();
   }
}


// ============================================================
// CLOSE LOCK
// ============================================================

bool AcquireCloseLock()
{
   return
      GlobalVariableSetOnCondition(
         GV_CLOSE_LOCK,
         1.0,
         0.0
      );
}


void ReleaseCloseLock()
{
   GlobalVariableSet(
      GV_CLOSE_LOCK,
      0.0
   );
}


// ============================================================
// CLOSE ALL POSITIONS
// ============================================================

bool CloseAllPositions()
{
   bool success = true;


   for(
      int i = PositionsTotal() - 1;
      i >= 0;
      i--
   )
   {
      ulong ticket =
         PositionGetTicket(i);


      if(ticket <= 0)
         continue;


      if(!trade.PositionClose(ticket))
         success = false;
   }


   return success;
}


// ============================================================
// CHECK BASKET TAKE PROFIT
// ============================================================

void CheckBasketTakeProfit()
{
   if(!IsBasketActive())
      return;


   if(PositionsTotal() == 0)
      return;


   if(IsDailyTargetReached())
      return;


   double basket_profit =
      GetBasketProfit();


   double target =
      GetBasketTarget();


   if(target <= 0)
      return;


   if(basket_profit < target)
      return;


   if(!AcquireCloseLock())
      return;


   CloseAllPositions();


   ReleaseCloseLock();
}


// ============================================================
// CURRENT SPREAD
// ============================================================

double GetCurrentSpreadPoints()
{
   MqlTick tick;


   if(!SymbolInfoTick(
      _Symbol,
      tick
   ))
   {
      return 0.0;
   }


   double point =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_POINT
      );


   if(point <= 0)
      return 0.0;


   return
      (tick.ask - tick.bid) /
      point;
}


// ============================================================
// CURRENT PRICE
// ============================================================

double GetCurrentPrice()
{
   MqlTick tick;


   if(!SymbolInfoTick(
      _Symbol,
      tick
   ))
   {
      return 0.0;
   }


   return tick.ask;
}


// ============================================================
// RISK AMOUNT
// ============================================================

double GetRiskAmount()
{
   if(risk_mode == RISK_MONEY)
      return risk_value;


   double balance =
      AccountInfoDouble(
         ACCOUNT_BALANCE
      );


   return
      balance *
      (risk_value / 100.0);
}


// ============================================================
// NORMALIZE CALCULATED VOLUME
// ============================================================

double NormalizeCalculatedVolume(
   double volume
)
{
   double step =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_VOLUME_STEP
      );


   if(step <= 0)
      return 0.0;


   return
      MathFloor(
         volume / step
      ) * step;
}


// ============================================================
// STOP LOSS INPUT
// ============================================================

double GetStopLossInputPrice()
{
   string text =
      ObjectGetString(
         0,
         "PSBM_SL_EDIT",
         OBJPROP_TEXT
      );


   return
      StringToDouble(text);
}


// ============================================================
// CREATE STOP LOSS LINE
//
// VISUAL / CALCULATION ONLY.
// NEVER MODIFIES BROKER STOP LOSS.
// ============================================================

void CreateStopLossLine()
{
   if(!sl_line_enabled)
      return;


   string name =
      "PSBM_SL_LINE";


   ObjectDelete(
      0,
      name
   );


   double sl_price =
      GetStopLossInputPrice();


   if(sl_price <= 0)
   {
      double current_price =
         GetCurrentPrice();


      double point =
         SymbolInfoDouble(
            _Symbol,
            SYMBOL_POINT
         );


      if(
         current_price <= 0 ||
         point <= 0
      )
      {
         return;
      }


      sl_price =
         current_price -
         (100 * point);
   }


   int digits =
      (int)SymbolInfoInteger(
         _Symbol,
         SYMBOL_DIGITS
      );


   sl_price =
      NormalizeDouble(
         sl_price,
         digits
      );


   if(!ObjectCreate(
      0,
      name,
      OBJ_HLINE,
      0,
      0,
      sl_price
   ))
   {
      return;
   }


   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      clrRed
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_WIDTH,
      2
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_STYLE,
      STYLE_SOLID
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      true
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTED,
      true
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_BACK,
      true
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      false
   );


   ObjectSetString(
      0,
      name,
      OBJPROP_TOOLTIP,
      "Calculation Stop Loss"
   );


   ObjectSetString(
      0,
      "PSBM_SL_EDIT",
      OBJPROP_TEXT,
      DoubleToString(
         sl_price,
         digits
      )
   );


   ChartRedraw();
}


// ============================================================
// DELETE STOP LOSS LINE
// ============================================================

void DeleteStopLossLine()
{
   ObjectDelete(
      0,
      "PSBM_SL_LINE"
   );


   ChartRedraw();
}


// ============================================================
// UPDATE STOP LOSS BUTTON
// ============================================================

void UpdateStopLossLineButton()
{
   if(sl_line_enabled)
   {
      ObjectSetString(
         0,
         "PSBM_SL_LINE_BUTTON",
         OBJPROP_TEXT,
         "ON"
      );


      ObjectSetInteger(
         0,
         "PSBM_SL_LINE_BUTTON",
         OBJPROP_BGCOLOR,
         C'45,105,75'
      );
   }
   else
   {
      ObjectSetString(
         0,
         "PSBM_SL_LINE_BUTTON",
         OBJPROP_TEXT,
         "OFF"
      );


      ObjectSetInteger(
         0,
         "PSBM_SL_LINE_BUTTON",
         OBJPROP_BGCOLOR,
         C'90,55,55'
      );
   }
}


// ============================================================
// TOGGLE STOP LOSS LINE
// ============================================================

void ToggleStopLossLine()
{
   sl_line_enabled =
      !sl_line_enabled;


   if(sl_line_enabled)
      CreateStopLossLine();
   else
      DeleteStopLossLine();


   UpdateStopLossLineButton();


   ChartRedraw();
}


// ============================================================
// STOP LOSS LINE -> INPUT
// ============================================================

void UpdateStopLossFromLine()
{
   if(!sl_line_enabled)
      return;


   if(
      ObjectFind(
         0,
         "PSBM_SL_LINE"
      ) < 0
   )
   {
      return;
   }


   double price =
      ObjectGetDouble(
         0,
         "PSBM_SL_LINE",
         OBJPROP_PRICE
      );


   int digits =
      (int)SymbolInfoInteger(
         _Symbol,
         SYMBOL_DIGITS
      );


   price =
      NormalizeDouble(
         price,
         digits
      );


   ObjectSetString(
      0,
      "PSBM_SL_EDIT",
      OBJPROP_TEXT,
      DoubleToString(
         price,
         digits
      )
   );


   ChartRedraw();
}


// ============================================================
// STOP LOSS INPUT -> LINE
// ============================================================

void UpdateStopLossLineFromInput()
{
   string text =
      ObjectGetString(
         0,
         "PSBM_SL_EDIT",
         OBJPROP_TEXT
      );


   double price =
      StringToDouble(text);


   if(price <= 0)
      return;


   if(!sl_line_enabled)
      return;


   if(
      ObjectFind(
         0,
         "PSBM_SL_LINE"
      ) < 0
   )
   {
      CreateStopLossLine();
      return;
   }


   int digits =
      (int)SymbolInfoInteger(
         _Symbol,
         SYMBOL_DIGITS
      );


   price =
      NormalizeDouble(
         price,
         digits
      );


   ObjectSetDouble(
      0,
      "PSBM_SL_LINE",
      OBJPROP_PRICE,
      price
   );


   ObjectSetInteger(
      0,
      "PSBM_SL_LINE",
      OBJPROP_SELECTED,
      true
   );


   ChartRedraw();
}


// ============================================================
// CALCULATE POSITION SIZE
// ============================================================

void CalculatePositionSize()
{
   double entry =
      StringToDouble(
         ObjectGetString(
            0,
            "PSBM_ENTRY_EDIT",
            OBJPROP_TEXT
         )
      );


   double stop =
      StringToDouble(
         ObjectGetString(
            0,
            "PSBM_SL_EDIT",
            OBJPROP_TEXT
         )
      );


   double entered_risk =
      StringToDouble(
         ObjectGetString(
            0,
            "PSBM_RISK_EDIT",
            OBJPROP_TEXT
         )
      );


   if(entered_risk <= 0)
      return;


   risk_value =
      entered_risk;


   if(
      entry <= 0 ||
      stop <= 0 ||
      entry == stop
   )
   {
      return;
   }


   double risk_amount =
      GetRiskAmount();


   ENUM_ORDER_TYPE order_type;


   if(stop < entry)
      order_type = ORDER_TYPE_BUY;
   else
      order_type = ORDER_TYPE_SELL;


   double one_lot_result =
      0.0;


   if(!OrderCalcProfit(
      order_type,
      _Symbol,
      1.0,
      entry,
      stop,
      one_lot_result
   ))
   {
      return;
   }


   double one_lot_loss =
      MathAbs(
         one_lot_result
      );


   if(one_lot_loss <= 0)
      return;


   double raw_volume =
      risk_amount /
      one_lot_loss;


   double calculated_volume =
      NormalizeCalculatedVolume(
         raw_volume
      );


   double minimum =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_VOLUME_MIN
      );


   double maximum =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_VOLUME_MAX
      );


   ObjectSetString(
      0,
      "PSBM_RISK_AMOUNT_VALUE",
      OBJPROP_TEXT,
      DoubleToString(
         risk_amount,
         2
      )
   );


   ObjectSetString(
      0,
      "PSBM_BROKER_MAX_VALUE",
      OBJPROP_TEXT,
      DoubleToString(
         maximum,
         2
      )
   );


   if(
      calculated_volume <= 0 ||
      calculated_volume < minimum
   )
   {
      ObjectSetString(
         0,
         "PSBM_SIZE_VALUE",
         OBJPROP_TEXT,
         "Below min"
      );


      ObjectSetInteger(
         0,
         "PSBM_SIZE_VALUE",
         OBJPROP_COLOR,
         C'255,190,80'
      );


      ChartRedraw();
      return;
   }


   ObjectSetString(
      0,
      "PSBM_SIZE_VALUE",
      OBJPROP_TEXT,
      DoubleToString(
         calculated_volume,
         2
      )
   );


   if(calculated_volume > maximum)
   {
      ObjectSetInteger(
         0,
         "PSBM_SIZE_VALUE",
         OBJPROP_COLOR,
         C'255,190,80'
      );
   }
   else
   {
      ObjectSetInteger(
         0,
         "PSBM_SIZE_VALUE",
         OBJPROP_COLOR,
         C'90,220,140'
      );
   }


   ChartRedraw();
}


// ============================================================
// UI HELPERS
// ============================================================

void CreateRectangle(
   string name,
   int x,
   int y,
   int width,
   int height,
   color background,
   color border
)
{
   ObjectDelete(0, name);


   ObjectCreate(
      0,
      name,
      OBJ_RECTANGLE_LABEL,
      0,
      0,
      0
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      x
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      y
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_XSIZE,
      width
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_YSIZE,
      height
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_BGCOLOR,
      background
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_BORDER_COLOR,
      border
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_CORNER,
      CORNER_LEFT_UPPER
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );
}


void CreateLabel(
   string name,
   string text,
   int x,
   int y,
   int size,
   color text_color
)
{
   ObjectDelete(0, name);


   ObjectCreate(
      0,
      name,
      OBJ_LABEL,
      0,
      0,
      0
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      x
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      y
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_CORNER,
      CORNER_LEFT_UPPER
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_ANCHOR,
      ANCHOR_LEFT_UPPER
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_FONTSIZE,
      size
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      text_color
   );


   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Arial"
   );


   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );
}


void CreateValue(
   string name,
   string text,
   int y,
   color text_color
)
{
   CreateLabel(
      name,
      text,
      ValueX(),
      y,
      FontSize(BASE_FONT_NORMAL),
      text_color
   );
}


void CreateButton(
   string name,
   string text,
   int x,
   int y,
   int width,
   int height,
   color background
)
{
   ObjectDelete(0, name);


   ObjectCreate(
      0,
      name,
      OBJ_BUTTON,
      0,
      0,
      0
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      x
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      y
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_XSIZE,
      width
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_YSIZE,
      height
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_BGCOLOR,
      background
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_BORDER_COLOR,
      C'80,85,95'
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      clrWhite
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_FONTSIZE,
      FontSize(BASE_FONT_NORMAL)
   );


   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Arial"
   );


   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
   );
}


void CreateEdit(
   string name,
   string text,
   int x,
   int y,
   int width
)
{
   ObjectDelete(0, name);


   ObjectCreate(
      0,
      name,
      OBJ_EDIT,
      0,
      0,
      0
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      x
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      y
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_XSIZE,
      width
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_YSIZE,
      S(19)
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_BGCOLOR,
      C'45,49,58'
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_BORDER_COLOR,
      C'80,85,95'
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      clrWhite
   );


   ObjectSetInteger(
      0,
      name,
      OBJPROP_FONTSIZE,
      FontSize(BASE_FONT_NORMAL)
   );


   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Arial"
   );


   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
   );
}


// ============================================================
// UPDATE PANEL BACKGROUND
// ============================================================

void UpdatePanelBackground()
{
   color panel_color =
      C'25,28,35';


   color header_color =
      C'35,39,48';


   if(IsDailyTargetReached())
   {
      panel_color =
         C'25,75,50';


      header_color =
         C'30,95,60';
   }
   else if(
      HasClosedTradesToday() &&
      GetTodayClosedProfit() < 0
   )
   {
      panel_color =
         C'75,30,35';


      header_color =
         C'95,35,40';
   }


   ObjectSetInteger(
      0,
      "PSBM_PANEL",
      OBJPROP_BGCOLOR,
      panel_color
   );


   ObjectSetInteger(
      0,
      "PSBM_HEADER",
      OBJPROP_BGCOLOR,
      header_color
   );
}


// ============================================================
// CREATE PANEL
// ============================================================

void CreatePanel()
{
   CalculatePanelScale();


   string account_currency =
      AccountInfoString(
         ACCOUNT_CURRENCY
      );


   int digits =
      (int)SymbolInfoInteger(
         _Symbol,
         SYMBOL_DIGITS
      );


   double current_price =
      GetCurrentPrice();


   int px = PanelX();
   int py = PanelY();
   int pw = PanelWidth();


   // ========================================================
   // MAIN PANEL
   // ========================================================

   CreateRectangle(
      "PSBM_PANEL",
      px,
      py,
      pw,
      PanelHeight(),
      C'25,28,35',
      C'70,75,85'
   );


   CreateRectangle(
      "PSBM_HEADER",
      px,
      py,
      pw,
      S(42),
      C'35,39,48',
      C'35,39,48'
   );


   CreateLabel(
      "PSBM_TITLE",
      "POSITION SIZER & BASKET MANAGER",
      LabelX(),
      py + S(6),
      FontSize(BASE_FONT_TITLE),
      clrWhite
   );


   CreateLabel(
      "PSBM_SUBTITLE",
      "Account-wide manual trade management",
      LabelX(),
      py + S(24),
      FontSize(BASE_FONT_SMALL),
      C'160,165,175'
   );


   // ========================================================
   // BASKET TAKE PROFIT
   // ========================================================

   CreateLabel(
      "PSBM_BASKET_TITLE",
      "BASKET TAKE PROFIT",
      LabelX(),
      py + S(51),
      FontSize(BASE_FONT_SECTION),
      C'90,180,255'
   );


   CreateLabel(
      "PSBM_POSITIONS_LABEL",
      "Open Positions",
      LabelX(),
      py + S(74),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_POSITIONS_VALUE",
      "0",
      py + S(74),
      clrWhite
   );


   CreateLabel(
      "PSBM_PROFIT_LABEL",
      "Basket P/L",
      LabelX(),
      py + S(94),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_PROFIT_VALUE",
      "0.00",
      py + S(94),
      clrWhite
   );


   CreateLabel(
      "PSBM_TP_MODE_LABEL",
      "TP Source",
      LabelX(),
      py + S(117),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_MODE_VALUE",
      "Daily Target",
      py + S(117),
      clrWhite
   );


   CreateLabel(
      "PSBM_TP_VALUE_LABEL",
      "Remaining Target",
      LabelX(),
      py + S(139),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_TARGET_VALUE",
      "0.00",
      py + S(139),
      C'90,220,140'
   );


   CreateLabel(
      "PSBM_TARGET_UNIT",
      account_currency,
      UnitX(),
      py + S(140),
      FontSize(BASE_FONT_SMALL),
      C'160,165,175'
   );


   CreateLabel(
      "PSBM_BALANCE_LABEL",
      "Basket Start Balance",
      LabelX(),
      py + S(162),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_BALANCE_VALUE",
      "0.00",
      py + S(162),
      clrWhite
   );


   CreateLabel(
      "PSBM_EFFECTIVE_LABEL",
      "Effective TP",
      LabelX(),
      py + S(183),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_EFFECTIVE_VALUE",
      "0.00",
      py + S(183),
      C'90,220,140'
   );


   CreateButton(
      "PSBM_CLOSE_BUTTON",
      "CLOSE ALL TRADES",
      LabelX(),
      py + S(206),
      pw - S(22),
      S(22),
      C'145,55,55'
   );


   CreateLabel(
      "PSBM_STATUS_LABEL",
      "STATUS",
      LabelX(),
      py + S(238),
      FontSize(BASE_FONT_SMALL),
      C'160,165,175'
   );


   CreateValue(
      "PSBM_STATUS_VALUE",
      "WAITING",
      py + S(238),
      C'255,190,80'
   );


   // ========================================================
   // DAILY PERFORMANCE
   // ========================================================

   CreateRectangle(
      "PSBM_DAILY_DIVIDER",
      LabelX(),
      py + S(262),
      pw - S(22),
      1,
      C'65,70,80',
      C'65,70,80'
   );


   CreateLabel(
      "PSBM_DAILY_TITLE",
      "DAILY PERFORMANCE",
      LabelX(),
      py + S(275),
      FontSize(BASE_FONT_SECTION),
      C'90,180,255'
   );


   CreateLabel(
      "PSBM_DAILY_MODE_LABEL",
      "Target Mode",
      LabelX(),
      py + S(299),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateButton(
      "PSBM_DAILY_MODE_BUTTON",
      "Percentage",
      ValueX(),
      py + S(293),
      S(88),
      S(19),
      C'55,60,70'
   );


   CreateLabel(
      "PSBM_DAILY_TARGET_LABEL",
      "Daily Target",
      LabelX(),
      py + S(323),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateEdit(
      "PSBM_DAILY_TARGET_EDIT",
      DoubleToString(
         GetDailyTargetValue(),
         2
      ),
      ValueX(),
      py + S(317),
      S(72)
   );


   CreateLabel(
      "PSBM_DAILY_TARGET_UNIT",
      "%",
      UnitX(),
      py + S(324),
      FontSize(BASE_FONT_SMALL),
      clrWhite
   );


   CreateLabel(
      "PSBM_DAILY_CLOSED_LABEL",
      "Closed P/L",
      LabelX(),
      py + S(347),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_DAILY_CLOSED_VALUE",
      "0.00",
      py + S(347),
      clrWhite
   );


   CreateLabel(
      "PSBM_DAILY_CURRENCY",
      account_currency,
      UnitX(),
      py + S(348),
      FontSize(BASE_FONT_SMALL),
      C'160,165,175'
   );


   CreateLabel(
      "PSBM_DAILY_PERCENT_LABEL",
      "Closed P/L %",
      LabelX(),
      py + S(368),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_DAILY_PERCENT_VALUE",
      "0.00",
      py + S(368),
      clrWhite
   );


   CreateLabel(
      "PSBM_DAILY_PERCENT_UNIT",
      "%",
      UnitX(),
      py + S(369),
      FontSize(BASE_FONT_SMALL),
      C'160,165,175'
   );


   CreateLabel(
      "PSBM_REMAINING_LABEL",
      "Remaining Target",
      LabelX(),
      py + S(389),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_REMAINING_VALUE",
      "0.00",
      py + S(389),
      C'255,190,80'
   );


   CreateLabel(
      "PSBM_REMAINING_UNIT",
      "%",
      UnitX(),
      py + S(390),
      FontSize(BASE_FONT_SMALL),
      C'160,165,175'
   );


   CreateLabel(
      "PSBM_DAILY_STATUS_LABEL",
      "Daily Status",
      LabelX(),
      py + S(410),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_DAILY_STATUS_VALUE",
      "IN PROGRESS",
      py + S(410),
      C'255,190,80'
   );


   // ========================================================
   // POSITION SIZER
   // ========================================================

   CreateRectangle(
      "PSBM_SIZER_DIVIDER",
      LabelX(),
      py + S(434),
      pw - S(22),
      1,
      C'65,70,80',
      C'65,70,80'
   );


   CreateLabel(
      "PSBM_SIZER_TITLE",
      "POSITION SIZER",
      LabelX(),
      py + S(447),
      FontSize(BASE_FONT_SECTION),
      C'90,180,255'
   );


   CreateLabel(
      "PSBM_SYMBOL_LABEL",
      "Symbol",
      LabelX(),
      py + S(471),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_SYMBOL_VALUE",
      _Symbol,
      py + S(471),
      clrWhite
   );


   CreateLabel(
      "PSBM_SPREAD_LABEL",
      "Current Spread",
      LabelX(),
      py + S(492),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_SPREAD_VALUE",
      "0.0",
      py + S(492),
      clrWhite
   );


   CreateLabel(
      "PSBM_SPREAD_UNIT",
      "points",
      UnitX(),
      py + S(493),
      FontSize(BASE_FONT_SMALL),
      C'160,165,175'
   );


   CreateLabel(
      "PSBM_RISK_MODE_LABEL",
      "Risk Mode",
      LabelX(),
      py + S(515),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateButton(
      "PSBM_RISK_MODE_BUTTON",
      "Percentage",
      ValueX(),
      py + S(509),
      S(88),
      S(19),
      C'55,60,70'
   );


   CreateLabel(
      "PSBM_RISK_LABEL",
      "Risk",
      LabelX(),
      py + S(539),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateEdit(
      "PSBM_RISK_EDIT",
      "1.00",
      ValueX(),
      py + S(533),
      S(72)
   );


   CreateLabel(
      "PSBM_RISK_UNIT",
      "%",
      UnitX(),
      py + S(540),
      FontSize(BASE_FONT_SMALL),
      clrWhite
   );


   CreateLabel(
      "PSBM_ENTRY_LABEL",
      "Entry Price",
      LabelX(),
      py + S(563),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateEdit(
      "PSBM_ENTRY_EDIT",
      DoubleToString(
         current_price,
         digits
      ),
      ValueX(),
      py + S(557),
      S(88)
   );


   CreateLabel(
      "PSBM_SL_LABEL",
      "Stop Loss",
      LabelX(),
      py + S(587),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateEdit(
      "PSBM_SL_EDIT",
      "",
      ValueX(),
      py + S(581),
      S(88)
   );


   CreateLabel(
      "PSBM_SL_LINE_LABEL",
      "SL Line",
      LabelX(),
      py + S(611),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateButton(
      "PSBM_SL_LINE_BUTTON",
      "ON",
      ValueX(),
      py + S(605),
      S(60),
      S(19),
      C'45,105,75'
   );


   CreateLabel(
      "PSBM_RISK_AMOUNT_LABEL",
      "Risk Amount",
      LabelX(),
      py + S(635),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_RISK_AMOUNT_VALUE",
      "0.00",
      py + S(635),
      clrWhite
   );


   CreateLabel(
      "PSBM_RISK_AMOUNT_UNIT",
      account_currency,
      UnitX(),
      py + S(636),
      FontSize(BASE_FONT_SMALL),
      C'160,165,175'
   );


   CreateLabel(
      "PSBM_SIZE_LABEL",
      "Calculated Size",
      LabelX(),
      py + S(656),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_SIZE_VALUE",
      "0.00",
      py + S(656),
      C'90,220,140'
   );


   CreateLabel(
      "PSBM_SIZE_UNIT",
      "lots",
      UnitX(),
      py + S(657),
      FontSize(BASE_FONT_SMALL),
      C'160,165,175'
   );


   CreateLabel(
      "PSBM_BROKER_MAX_LABEL",
      "Broker Max",
      LabelX(),
      py + S(677),
      FontSize(BASE_FONT_NORMAL),
      C'190,195,205'
   );


   CreateValue(
      "PSBM_BROKER_MAX_VALUE",
      DoubleToString(
         SymbolInfoDouble(
            _Symbol,
            SYMBOL_VOLUME_MAX
         ),
         2
      ),
      py + S(677),
      clrWhite
   );


   CreateLabel(
      "PSBM_BROKER_MAX_UNIT",
      "lots",
      UnitX(),
      py + S(678),
      FontSize(BASE_FONT_SMALL),
      C'160,165,175'
   );


   // --------------------------------------------------------
   // CALCULATE BUTTON
   // --------------------------------------------------------

   CreateButton(
      "PSBM_CALCULATE_BUTTON",
      "CALCULATE",
      LabelX(),
      py + S(699),
      pw - S(22),
      S(21),
      C'45,105,155'
   );


   // --------------------------------------------------------
   // AUTHOR
   //
   // Moved upward to provide proper bottom padding.
   // --------------------------------------------------------

   CreateLabel(
      "PSBM_SIGNATURE",
      "By Tinashe Chimanikire",
      LabelX(),
      py + S(724),
      FontSize(BASE_FONT_SMALL),
      C'130,135,145'
   );


   CreateStopLossLine();


   UpdateStopLossLineButton();


   ChartRedraw();
}


// ============================================================
// REBUILD RESPONSIVE PANEL
// ============================================================

void RebuildResponsivePanel()
{
   string daily_target =
      ObjectGetString(
         0,
         "PSBM_DAILY_TARGET_EDIT",
         OBJPROP_TEXT
      );


   string risk =
      ObjectGetString(
         0,
         "PSBM_RISK_EDIT",
         OBJPROP_TEXT
      );


   string entry =
      ObjectGetString(
         0,
         "PSBM_ENTRY_EDIT",
         OBJPROP_TEXT
      );


   string stop =
      ObjectGetString(
         0,
         "PSBM_SL_EDIT",
         OBJPROP_TEXT
      );


   if(StringToDouble(daily_target) > 0)
   {
      GlobalVariableSet(
         GV_DAILY_TARGET,
         StringToDouble(
            daily_target
         )
      );
   }


   double old_stop =
      StringToDouble(stop);


   ObjectsDeleteAll(
      0,
      "PSBM_"
   );


   CalculatePanelScale();


   CreatePanel();


   if(StringToDouble(risk) > 0)
   {
      ObjectSetString(
         0,
         "PSBM_RISK_EDIT",
         OBJPROP_TEXT,
         risk
      );
   }


   if(StringToDouble(entry) > 0)
   {
      ObjectSetString(
         0,
         "PSBM_ENTRY_EDIT",
         OBJPROP_TEXT,
         entry
      );
   }


   if(old_stop > 0)
   {
      ObjectSetString(
         0,
         "PSBM_SL_EDIT",
         OBJPROP_TEXT,
         stop
      );


      if(sl_line_enabled)
         UpdateStopLossLineFromInput();
   }


   UpdatePanel();


   ChartRedraw();
}


// ============================================================
// UPDATE PANEL
// ============================================================

void UpdatePanel()
{
   string account_currency =
      AccountInfoString(
         ACCOUNT_CURRENCY
      );


   UpdatePanelBackground();


   // ========================================================
   // BASKET
   // ========================================================

   ObjectSetString(
      0,
      "PSBM_POSITIONS_VALUE",
      OBJPROP_TEXT,
      IntegerToString(
         PositionsTotal()
      )
   );


   double basket_profit =
      GetBasketProfit();


   ObjectSetString(
      0,
      "PSBM_PROFIT_VALUE",
      OBJPROP_TEXT,
      DoubleToString(
         basket_profit,
         2
      )
   );


   if(basket_profit > 0)
   {
      ObjectSetInteger(
         0,
         "PSBM_PROFIT_VALUE",
         OBJPROP_COLOR,
         C'90,220,140'
      );
   }
   else if(basket_profit < 0)
   {
      ObjectSetInteger(
         0,
         "PSBM_PROFIT_VALUE",
         OBJPROP_COLOR,
         C'255,100,100'
      );
   }
   else
   {
      ObjectSetInteger(
         0,
         "PSBM_PROFIT_VALUE",
         OBJPROP_COLOR,
         clrWhite
      );
   }


   double remaining_money =
      GetRemainingDailyTargetMoney();


   ObjectSetString(
      0,
      "PSBM_TARGET_VALUE",
      OBJPROP_TEXT,
      DoubleToString(
         remaining_money,
         2
      )
   );


   ObjectSetString(
      0,
      "PSBM_EFFECTIVE_VALUE",
      OBJPROP_TEXT,
      DoubleToString(
         remaining_money,
         2
      )
   );


   ObjectSetString(
      0,
      "PSBM_TARGET_UNIT",
      OBJPROP_TEXT,
      account_currency
   );


   if(IsBasketActive())
   {
      ObjectSetString(
         0,
         "PSBM_BALANCE_VALUE",
         OBJPROP_TEXT,
         DoubleToString(
            GetBasketStartBalance(),
            2
         )
      );


      ObjectSetString(
         0,
         "PSBM_STATUS_VALUE",
         OBJPROP_TEXT,
         "ACTIVE"
      );


      ObjectSetInteger(
         0,
         "PSBM_STATUS_VALUE",
         OBJPROP_COLOR,
         C'90,220,140'
      );
   }
   else
   {
      ObjectSetString(
         0,
         "PSBM_BALANCE_VALUE",
         OBJPROP_TEXT,
         "0.00"
      );


      ObjectSetString(
         0,
         "PSBM_STATUS_VALUE",
         OBJPROP_TEXT,
         "WAITING"
      );


      ObjectSetInteger(
         0,
         "PSBM_STATUS_VALUE",
         OBJPROP_COLOR,
         C'255,190,80'
      );
   }


   // ========================================================
   // DAILY PERFORMANCE
   // ========================================================

   if(
      GetDailyTargetMode() ==
      DAILY_PERCENTAGE
   )
   {
      ObjectSetString(
         0,
         "PSBM_DAILY_MODE_BUTTON",
         OBJPROP_TEXT,
         "Percentage"
      );


      ObjectSetString(
         0,
         "PSBM_DAILY_TARGET_UNIT",
         OBJPROP_TEXT,
         "%"
      );


      ObjectSetString(
         0,
         "PSBM_REMAINING_UNIT",
         OBJPROP_TEXT,
         "%"
      );


      ObjectSetString(
         0,
         "PSBM_REMAINING_VALUE",
         OBJPROP_TEXT,
         DoubleToString(
            GetRemainingDailyTargetPercent(),
            2
         )
      );
   }
   else
   {
      ObjectSetString(
         0,
         "PSBM_DAILY_MODE_BUTTON",
         OBJPROP_TEXT,
         "Money"
      );


      ObjectSetString(
         0,
         "PSBM_DAILY_TARGET_UNIT",
         OBJPROP_TEXT,
         account_currency
      );


      ObjectSetString(
         0,
         "PSBM_REMAINING_UNIT",
         OBJPROP_TEXT,
         account_currency
      );


      ObjectSetString(
         0,
         "PSBM_REMAINING_VALUE",
         OBJPROP_TEXT,
         DoubleToString(
            GetRemainingDailyTargetMoney(),
            2
         )
      );
   }


   double daily_profit =
      GetTodayClosedProfit();


   double daily_percent =
      GetTodayClosedProfitPercent();


   ObjectSetString(
      0,
      "PSBM_DAILY_CLOSED_VALUE",
      OBJPROP_TEXT,
      DoubleToString(
         daily_profit,
         2
      )
   );


   ObjectSetString(
      0,
      "PSBM_DAILY_PERCENT_VALUE",
      OBJPROP_TEXT,
      DoubleToString(
         daily_percent,
         2
      )
   );


   color daily_color =
      clrWhite;


   if(daily_profit > 0)
   {
      daily_color =
         C'90,220,140';
   }
   else if(daily_profit < 0)
   {
      daily_color =
         C'255,100,100';
   }


   ObjectSetInteger(
      0,
      "PSBM_DAILY_CLOSED_VALUE",
      OBJPROP_COLOR,
      daily_color
   );


   ObjectSetInteger(
      0,
      "PSBM_DAILY_PERCENT_VALUE",
      OBJPROP_COLOR,
      daily_color
   );


   if(IsDailyTargetReached())
   {
      ObjectSetString(
         0,
         "PSBM_DAILY_STATUS_VALUE",
         OBJPROP_TEXT,
         "TARGET REACHED"
      );


      ObjectSetInteger(
         0,
         "PSBM_DAILY_STATUS_VALUE",
         OBJPROP_COLOR,
         C'90,220,140'
      );


      ObjectSetInteger(
         0,
         "PSBM_REMAINING_VALUE",
         OBJPROP_COLOR,
         C'90,220,140'
      );
   }
   else
   {
      ObjectSetString(
         0,
         "PSBM_DAILY_STATUS_VALUE",
         OBJPROP_TEXT,
         "IN PROGRESS"
      );


      ObjectSetInteger(
         0,
         "PSBM_DAILY_STATUS_VALUE",
         OBJPROP_COLOR,
         C'255,190,80'
      );


      ObjectSetInteger(
         0,
         "PSBM_REMAINING_VALUE",
         OBJPROP_COLOR,
         C'255,190,80'
      );
   }


   // ========================================================
   // POSITION SIZER
   // ========================================================

   ObjectSetString(
      0,
      "PSBM_SYMBOL_VALUE",
      OBJPROP_TEXT,
      _Symbol
   );


   ObjectSetString(
      0,
      "PSBM_SPREAD_VALUE",
      OBJPROP_TEXT,
      DoubleToString(
         GetCurrentSpreadPoints(),
         1
      )
   );


   ObjectSetString(
      0,
      "PSBM_BROKER_MAX_VALUE",
      OBJPROP_TEXT,
      DoubleToString(
         SymbolInfoDouble(
            _Symbol,
            SYMBOL_VOLUME_MAX
         ),
         2
      )
   );


   UpdateStopLossLineButton();


   ChartRedraw();
}


// ============================================================
// CHART EVENTS
// ============================================================

void OnChartEvent(
   const int id,
   const long &lparam,
   const double &dparam,
   const string &sparam
)
{
   // --------------------------------------------------------
   // CHART RESIZE
   // --------------------------------------------------------

   if(id == CHARTEVENT_CHART_CHANGE)
   {
      RebuildResponsivePanel();
      return;
   }


   // --------------------------------------------------------
   // STOP LOSS LINE DRAG
   // --------------------------------------------------------

   if(
      id == CHARTEVENT_OBJECT_DRAG &&
      sparam == "PSBM_SL_LINE"
   )
   {
      UpdateStopLossFromLine();
      return;
   }


   // --------------------------------------------------------
   // BUTTONS
   // --------------------------------------------------------

   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // -----------------------------------------------------
      // DAILY TARGET MODE
      // -----------------------------------------------------

      if(sparam == "PSBM_DAILY_MODE_BUTTON")
      {
         ObjectSetInteger(
            0,
            "PSBM_DAILY_MODE_BUTTON",
            OBJPROP_STATE,
            false
         );


         if(
            GetDailyTargetMode() ==
            DAILY_PERCENTAGE
         )
         {
            GlobalVariableSet(
               GV_DAILY_MODE,
               (double)DAILY_MONEY
            );
         }
         else
         {
            GlobalVariableSet(
               GV_DAILY_MODE,
               (double)DAILY_PERCENTAGE
            );
         }


         UpdatePanel();
         return;
      }


      // -----------------------------------------------------
      // RISK MODE
      // -----------------------------------------------------

      if(sparam == "PSBM_RISK_MODE_BUTTON")
      {
         ObjectSetInteger(
            0,
            "PSBM_RISK_MODE_BUTTON",
            OBJPROP_STATE,
            false
         );


         if(risk_mode == RISK_PERCENTAGE)
         {
            risk_mode =
               RISK_MONEY;


            ObjectSetString(
               0,
               "PSBM_RISK_MODE_BUTTON",
               OBJPROP_TEXT,
               "Money"
            );


            ObjectSetString(
               0,
               "PSBM_RISK_UNIT",
               OBJPROP_TEXT,
               AccountInfoString(
                  ACCOUNT_CURRENCY
               )
            );
         }
         else
         {
            risk_mode =
               RISK_PERCENTAGE;


            ObjectSetString(
               0,
               "PSBM_RISK_MODE_BUTTON",
               OBJPROP_TEXT,
               "Percentage"
            );


            ObjectSetString(
               0,
               "PSBM_RISK_UNIT",
               OBJPROP_TEXT,
               "%"
            );
         }


         ChartRedraw();
         return;
      }


      // -----------------------------------------------------
      // SL LINE
      // -----------------------------------------------------

      if(sparam == "PSBM_SL_LINE_BUTTON")
      {
         ObjectSetInteger(
            0,
            "PSBM_SL_LINE_BUTTON",
            OBJPROP_STATE,
            false
         );


         ToggleStopLossLine();
         return;
      }


      // -----------------------------------------------------
      // CALCULATE
      // -----------------------------------------------------

      if(sparam == "PSBM_CALCULATE_BUTTON")
      {
         ObjectSetInteger(
            0,
            "PSBM_CALCULATE_BUTTON",
            OBJPROP_STATE,
            false
         );


         CalculatePositionSize();
         return;
      }


      // -----------------------------------------------------
      // CLOSE ALL
      // -----------------------------------------------------

      if(sparam == "PSBM_CLOSE_BUTTON")
      {
         ObjectSetInteger(
            0,
            "PSBM_CLOSE_BUTTON",
            OBJPROP_STATE,
            false
         );


         if(PositionsTotal() == 0)
            return;


         if(!AcquireCloseLock())
            return;


         CloseAllPositions();


         ReleaseCloseLock();


         return;
      }
   }


   // --------------------------------------------------------
   // EDIT BOXES
   // --------------------------------------------------------

   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(sparam == "PSBM_DAILY_TARGET_EDIT")
      {
         ReadDailyTarget();


         ObjectSetString(
            0,
            "PSBM_DAILY_TARGET_EDIT",
            OBJPROP_TEXT,
            DoubleToString(
               GetDailyTargetValue(),
               2
            )
         );


         UpdatePanel();
         return;
      }


      if(sparam == "PSBM_SL_EDIT")
      {
         UpdateStopLossLineFromInput();
         return;
      }
   }
}


// ============================================================
// DELETE PANEL
// ============================================================

void DeletePanel()
{
   ObjectsDeleteAll(
      0,
      "PSBM_"
   );


   ChartRedraw();
}


// ============================================================
// INITIALIZATION
// ============================================================

int OnInit()
{
   CreateGlobalVariableNames();


   InitializeSharedVariables();


   if(
      PositionsTotal() > 0 &&
      !IsBasketActive()
   )
   {
      StartBasket();
   }


   CalculatePanelScale();


   CreatePanel();


   EventSetTimer(1);


   UpdatePanel();


   return INIT_SUCCEEDED;
}


// ============================================================
// SHUTDOWN
// ============================================================

void OnDeinit(
   const int reason
)
{
   EventKillTimer();


   DeletePanel();
}


// ============================================================
// MAIN PROCESS
// ============================================================

void ProcessEA()
{
   UpdateBasketState();


   UpdatePanel();


   CheckBasketTakeProfit();
}


// ============================================================
// TICK
// ============================================================

void OnTick()
{
   ProcessEA();
}


// ============================================================
// TIMER
// ============================================================

void OnTimer()
{
   ProcessEA();
}