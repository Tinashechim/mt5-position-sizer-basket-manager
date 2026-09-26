#include <Trade/Trade.mqh>

#property copyright "Tinashe Chimanikire"
#property version   "1.85"
#property strict

CTrade trade;


// ============================================================
// PANEL SETTINGS
// ============================================================

#define PANEL_X       15
#define PANEL_Y       20
#define PANEL_WIDTH   360
#define PANEL_HEIGHT  710

#define LABEL_X       (PANEL_X + 14)
#define VALUE_X       (PANEL_X + 190)
#define UNIT_X        (PANEL_X + 305)


// ============================================================
// ENUMS
// ============================================================

enum BasketTPMode
{
   TP_MONEY,
   TP_PERCENTAGE
};

enum RiskMode
{
   RISK_MONEY,
   RISK_PERCENTAGE
};


// ============================================================
// SHARED BASKET GLOBAL VARIABLES
// ============================================================

string GV_ACTIVE;
string GV_START_BALANCE;
string GV_TP_MODE;
string GV_TP_VALUE;
string GV_CLOSE_LOCK;


// ============================================================
// POSITION SIZER VARIABLES
// ============================================================

RiskMode risk_mode = RISK_PERCENTAGE;
double risk_value = 1.0;

// SL line is local to each chart.
bool sl_line_enabled = true;


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

   GV_TP_MODE =
      prefix + "TP_MODE";

   GV_TP_VALUE =
      prefix + "TP_VALUE";

   GV_CLOSE_LOCK =
      prefix + "CLOSE_LOCK";
}


// ============================================================
// INITIALIZE SHARED VARIABLES
// ============================================================

void InitializeSharedVariables()
{
   if(!GlobalVariableCheck(GV_ACTIVE))
      GlobalVariableSet(GV_ACTIVE, 0.0);

   if(!GlobalVariableCheck(GV_START_BALANCE))
      GlobalVariableSet(GV_START_BALANCE, 0.0);

   if(!GlobalVariableCheck(GV_TP_MODE))
      GlobalVariableSet(
         GV_TP_MODE,
         (double)TP_PERCENTAGE
      );

   if(!GlobalVariableCheck(GV_TP_VALUE))
      GlobalVariableSet(
         GV_TP_VALUE,
         2.0
      );

   if(!GlobalVariableCheck(GV_CLOSE_LOCK))
      GlobalVariableSet(
         GV_CLOSE_LOCK,
         0.0
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


BasketTPMode GetSharedTPMode()
{
   return
      (BasketTPMode)
      (int)GlobalVariableGet(
         GV_TP_MODE
      );
}


double GetSharedTPValue()
{
   return
      GlobalVariableGet(
         GV_TP_VALUE
      );
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
// BASKET TARGET
// ============================================================

double GetBasketTarget()
{
   if(!IsBasketActive())
      return 0.0;

   double value =
      GetSharedTPValue();

   if(GetSharedTPMode() == TP_MONEY)
      return value;

   return
      GetBasketStartBalance() *
      (value / 100.0);
}


// ============================================================
// READ BASKET TARGET
// ============================================================

bool ReadBasketTarget()
{
   string text =
      ObjectGetString(
         0,
         "PSBM_TARGET_EDIT",
         OBJPROP_TEXT
      );

   double value =
      StringToDouble(text);

   if(value <= 0)
   {
      ObjectSetString(
         0,
         "PSBM_TARGET_EDIT",
         OBJPROP_TEXT,
         DoubleToString(
            GetSharedTPValue(),
            2
         )
      );

      return false;
   }

   GlobalVariableSet(
      GV_TP_VALUE,
      value
   );

   return true;
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

   double profit =
      GetBasketProfit();

   double target =
      GetBasketTarget();

   if(target <= 0)
      return;

   if(profit < target)
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
//
// Rounds to broker volume step but does NOT cap
// the displayed calculation at the broker maximum.
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

   volume =
      MathFloor(
         volume / step
      ) * step;

   return volume;
}


// ============================================================
// GET STOP LOSS INPUT PRICE
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
// CREATE RED STOP LOSS LINE
//
// VISUAL/CALCULATION ONLY.
// IT NEVER SETS OR MODIFIES A BROKER STOP LOSS.
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


   // If there is no valid typed SL yet,
   // start 100 points below current Ask.
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


   // IMPORTANT:
   // Draw the line in the background.
   // This prevents it from visually cutting through
   // the manager panel.
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


   // Synchronize the number with the line.
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
// DELETE ONLY THE STOP LOSS LINE
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
// UPDATE SL LINE BUTTON
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

   ChartRedraw();
}


// ============================================================
// TOGGLE STOP LOSS LINE
// ============================================================

void ToggleStopLossLine()
{
   sl_line_enabled =
      !sl_line_enabled;

   if(sl_line_enabled)
   {
      CreateStopLossLine();
   }
   else
   {
      DeleteStopLossLine();
   }

   UpdateStopLossLineButton();
}


// ============================================================
// RED LINE -> STOP LOSS INPUT
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
// STOP LOSS INPUT -> RED LINE
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


   // If the line is switched OFF, keep the typed
   // SL value but do not create/move a line.
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
   string entry_text =
      ObjectGetString(
         0,
         "PSBM_ENTRY_EDIT",
         OBJPROP_TEXT
      );


   string stop_text =
      ObjectGetString(
         0,
         "PSBM_SL_EDIT",
         OBJPROP_TEXT
      );


   string risk_text =
      ObjectGetString(
         0,
         "PSBM_RISK_EDIT",
         OBJPROP_TEXT
      );


   double entry =
      StringToDouble(
         entry_text
      );


   double stop =
      StringToDouble(
         stop_text
      );


   double entered_risk =
      StringToDouble(
         risk_text
      );


   if(entered_risk <= 0)
      return;


   risk_value =
      entered_risk;


   if(
      entry <= 0 ||
      stop <= 0
   )
   {
      return;
   }


   if(entry == stop)
      return;


   double risk_amount =
      GetRiskAmount();


   ENUM_ORDER_TYPE order_type;


   if(stop < entry)
      order_type = ORDER_TYPE_BUY;
   else
      order_type = ORDER_TYPE_SELL;


   double one_lot_result =
      0.0;


   ResetLastError();


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


   string currency =
      AccountInfoString(
         ACCOUNT_CURRENCY
      );


   // ---------------------------------------------------------
   // RISK AMOUNT
   // ---------------------------------------------------------

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
      "PSBM_RISK_AMOUNT_UNIT",
      OBJPROP_TEXT,
      currency
   );


   // ---------------------------------------------------------
   // BROKER MAX
   // ---------------------------------------------------------

   ObjectSetString(
      0,
      "PSBM_BROKER_MAX_VALUE",
      OBJPROP_TEXT,
      DoubleToString(
         maximum,
         2
      )
   );


   // ---------------------------------------------------------
   // CALCULATED SIZE
   // ---------------------------------------------------------

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


   // Orange warns that the mathematically required
   // size exceeds the broker's maximum order size.
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
// CREATE RECTANGLE
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
   ObjectDelete(
      0,
      name
   );


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


// ============================================================
// CREATE LABEL
// ============================================================

void CreateLabel(
   string name,
   string text,
   int x,
   int y,
   int size,
   color text_color
)
{
   ObjectDelete(
      0,
      name
   );


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


// ============================================================
// CREATE VALUE
// ============================================================

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
      VALUE_X,
      y,
      8,
      text_color
   );
}


// ============================================================
// CREATE BUTTON
// ============================================================

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
   ObjectDelete(
      0,
      name
   );


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
      8
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
// CREATE EDIT BOX
// ============================================================

void CreateEdit(
   string name,
   string text,
   int x,
   int y,
   int width
)
{
   ObjectDelete(
      0,
      name
   );


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
      22
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
      8
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
// CREATE PANEL
// ============================================================

void CreatePanel()
{
   string currency =
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


   // ---------------------------------------------------------
   // MAIN BACKGROUND
   // ---------------------------------------------------------

   CreateRectangle(
      "PSBM_PANEL",
      PANEL_X,
      PANEL_Y,
      PANEL_WIDTH,
      PANEL_HEIGHT,
      C'25,28,35',
      C'70,75,85'
   );


   CreateRectangle(
      "PSBM_HEADER",
      PANEL_X,
      PANEL_Y,
      PANEL_WIDTH,
      48,
      C'35,39,48',
      C'35,39,48'
   );


   CreateLabel(
      "PSBM_TITLE",
      "POSITION SIZER & BASKET MANAGER",
      LABEL_X,
      PANEL_Y + 8,
      9,
      clrWhite
   );


   CreateLabel(
      "PSBM_SUBTITLE",
      "Account-wide manual management",
      LABEL_X,
      PANEL_Y + 27,
      7,
      C'160,165,175'
   );


   // ========================================================
   // BASKET TAKE PROFIT
   // ========================================================

   CreateLabel(
      "PSBM_BASKET_TITLE",
      "BASKET TAKE PROFIT",
      LABEL_X,
      PANEL_Y + 62,
      9,
      C'90,180,255'
   );


   CreateLabel(
      "PSBM_POSITIONS_LABEL",
      "Open Positions",
      LABEL_X,
      PANEL_Y + 88,
      8,
      C'190,195,205'
   );


   CreateValue(
      "PSBM_POSITIONS_VALUE",
      "0",
      PANEL_Y + 88,
      clrWhite
   );


   CreateLabel(
      "PSBM_PROFIT_LABEL",
      "Basket P/L",
      LABEL_X,
      PANEL_Y + 113,
      8,
      C'190,195,205'
   );


   CreateValue(
      "PSBM_PROFIT_VALUE",
      "0.00",
      PANEL_Y + 113,
      clrWhite
   );


   CreateLabel(
      "PSBM_TP_MODE_LABEL",
      "TP Mode",
      LABEL_X,
      PANEL_Y + 143,
      8,
      C'190,195,205'
   );


   string tp_mode_text =
      "Percentage";


   if(GetSharedTPMode() == TP_MONEY)
      tp_mode_text = "Money";


   CreateButton(
      "PSBM_MODE_BUTTON",
      tp_mode_text,
      VALUE_X,
      PANEL_Y + 136,
      105,
      22,
      C'55,60,70'
   );


   CreateLabel(
      "PSBM_TP_VALUE_LABEL",
      "Target",
      LABEL_X,
      PANEL_Y + 173,
      8,
      C'190,195,205'
   );


   CreateEdit(
      "PSBM_TARGET_EDIT",
      DoubleToString(
         GetSharedTPValue(),
         2
      ),
      VALUE_X,
      PANEL_Y + 166,
      85
   );


   CreateLabel(
      "PSBM_TARGET_UNIT",
      "%",
      UNIT_X,
      PANEL_Y + 173,
      8,
      clrWhite
   );


   CreateLabel(
      "PSBM_BALANCE_LABEL",
      "Starting Balance",
      LABEL_X,
      PANEL_Y + 203,
      8,
      C'190,195,205'
   );


   CreateValue(
      "PSBM_BALANCE_VALUE",
      "0.00",
      PANEL_Y + 203,
      clrWhite
   );


   CreateLabel(
      "PSBM_TARGET_LABEL",
      "Profit Target",
      LABEL_X,
      PANEL_Y + 228,
      8,
      C'190,195,205'
   );


   CreateValue(
      "PSBM_TARGET_VALUE",
      "0.00",
      PANEL_Y + 228,
      C'90,220,140'
   );


   CreateButton(
      "PSBM_CLOSE_BUTTON",
      "CLOSE ALL TRADES",
      LABEL_X,
      PANEL_Y + 258,
      PANEL_WIDTH - 28,
      26,
      C'145,55,55'
   );


   CreateLabel(
      "PSBM_STATUS_LABEL",
      "STATUS",
      LABEL_X,
      PANEL_Y + 297,
      7,
      C'160,165,175'
   );


   CreateValue(
      "PSBM_STATUS_VALUE",
      "WAITING",
      PANEL_Y + 297,
      C'255,190,80'
   );


   CreateRectangle(
      "PSBM_DIVIDER",
      LABEL_X,
      PANEL_Y + 326,
      PANEL_WIDTH - 28,
      1,
      C'65,70,80',
      C'65,70,80'
   );


   // ========================================================
   // POSITION SIZER
   // ========================================================

   CreateLabel(
      "PSBM_SIZER_TITLE",
      "POSITION SIZER",
      LABEL_X,
      PANEL_Y + 342,
      9,
      C'90,180,255'
   );


   CreateLabel(
      "PSBM_SYMBOL_LABEL",
      "Symbol",
      LABEL_X,
      PANEL_Y + 368,
      8,
      C'190,195,205'
   );


   CreateValue(
      "PSBM_SYMBOL_VALUE",
      _Symbol,
      PANEL_Y + 368,
      clrWhite
   );


   CreateLabel(
      "PSBM_SPREAD_LABEL",
      "Current Spread",
      LABEL_X,
      PANEL_Y + 393,
      8,
      C'190,195,205'
   );


   CreateValue(
      "PSBM_SPREAD_VALUE",
      "0.0",
      PANEL_Y + 393,
      clrWhite
   );


   CreateLabel(
      "PSBM_SPREAD_UNIT",
      "points",
      UNIT_X,
      PANEL_Y + 393,
      7,
      C'160,165,175'
   );


   CreateLabel(
      "PSBM_RISK_MODE_LABEL",
      "Risk Mode",
      LABEL_X,
      PANEL_Y + 423,
      8,
      C'190,195,205'
   );


   CreateButton(
      "PSBM_RISK_MODE_BUTTON",
      "Percentage",
      VALUE_X,
      PANEL_Y + 416,
      105,
      22,
      C'55,60,70'
   );


   CreateLabel(
      "PSBM_RISK_LABEL",
      "Risk",
      LABEL_X,
      PANEL_Y + 453,
      8,
      C'190,195,205'
   );


   CreateEdit(
      "PSBM_RISK_EDIT",
      "1.00",
      VALUE_X,
      PANEL_Y + 446,
      85
   );


   CreateLabel(
      "PSBM_RISK_UNIT",
      "%",
      UNIT_X,
      PANEL_Y + 453,
      8,
      clrWhite
   );


   CreateLabel(
      "PSBM_ENTRY_LABEL",
      "Entry Price",
      LABEL_X,
      PANEL_Y + 483,
      8,
      C'190,195,205'
   );


   CreateEdit(
      "PSBM_ENTRY_EDIT",
      DoubleToString(
         current_price,
         digits
      ),
      VALUE_X,
      PANEL_Y + 476,
      105
   );


   CreateLabel(
      "PSBM_SL_LABEL",
      "Stop Loss",
      LABEL_X,
      PANEL_Y + 513,
      8,
      C'190,195,205'
   );


   CreateEdit(
      "PSBM_SL_EDIT",
      "",
      VALUE_X,
      PANEL_Y + 506,
      105
   );


   // ---------------------------------------------------------
   // SL LINE ON/OFF
   // ---------------------------------------------------------

   CreateLabel(
      "PSBM_SL_LINE_LABEL",
      "SL Line",
      LABEL_X,
      PANEL_Y + 543,
      8,
      C'190,195,205'
   );


   CreateButton(
      "PSBM_SL_LINE_BUTTON",
      "ON",
      VALUE_X,
      PANEL_Y + 536,
      70,
      22,
      C'45,105,75'
   );


   // ---------------------------------------------------------
   // RISK AMOUNT
   // ---------------------------------------------------------

   CreateLabel(
      "PSBM_RISK_AMOUNT_LABEL",
      "Risk Amount",
      LABEL_X,
      PANEL_Y + 573,
      8,
      C'190,195,205'
   );


   CreateValue(
      "PSBM_RISK_AMOUNT_VALUE",
      "0.00",
      PANEL_Y + 573,
      clrWhite
   );


   CreateLabel(
      "PSBM_RISK_AMOUNT_UNIT",
      currency,
      UNIT_X,
      PANEL_Y + 573,
      7,
      C'160,165,175'
   );


   // ---------------------------------------------------------
   // CALCULATED SIZE
   // ---------------------------------------------------------

   CreateLabel(
      "PSBM_SIZE_LABEL",
      "Calculated Size",
      LABEL_X,
      PANEL_Y + 598,
      8,
      C'190,195,205'
   );


   CreateValue(
      "PSBM_SIZE_VALUE",
      "0.00",
      PANEL_Y + 598,
      C'90,220,140'
   );


   CreateLabel(
      "PSBM_SIZE_UNIT",
      "lots",
      UNIT_X,
      PANEL_Y + 598,
      7,
      C'160,165,175'
   );


   // ---------------------------------------------------------
   // BROKER MAXIMUM
   // ---------------------------------------------------------

   CreateLabel(
      "PSBM_BROKER_MAX_LABEL",
      "Broker Max",
      LABEL_X,
      PANEL_Y + 623,
      8,
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
      PANEL_Y + 623,
      clrWhite
   );


   CreateLabel(
      "PSBM_BROKER_MAX_UNIT",
      "lots",
      UNIT_X,
      PANEL_Y + 623,
      7,
      C'160,165,175'
   );


   // ---------------------------------------------------------
   // CALCULATE
   // ---------------------------------------------------------

   CreateButton(
      "PSBM_CALCULATE_BUTTON",
      "CALCULATE",
      LABEL_X,
      PANEL_Y + 650,
      PANEL_WIDTH - 28,
      24,
      C'45,105,155'
   );


   // ---------------------------------------------------------
   // SIGNATURE
   // ---------------------------------------------------------

   CreateLabel(
      "PSBM_SIGNATURE",
      "By Tinashe Chimanikire",
      LABEL_X,
      PANEL_Y + 681,
      7,
      C'130,135,145'
   );


   // Create the calculation-only red SL line.
   CreateStopLossLine();

   UpdateStopLossLineButton();

   ChartRedraw();
}


// ============================================================
// UPDATE PANEL
// ============================================================

void UpdatePanel()
{
   string currency =
      AccountInfoString(
         ACCOUNT_CURRENCY
      );


   // ---------------------------------------------------------
   // TP MODE
   // ---------------------------------------------------------

   string mode_text;


   if(GetSharedTPMode() == TP_PERCENTAGE)
      mode_text = "Percentage";
   else
      mode_text = "Money";


   ObjectSetString(
      0,
      "PSBM_MODE_BUTTON",
      OBJPROP_TEXT,
      mode_text
   );


   if(GetSharedTPMode() == TP_PERCENTAGE)
   {
      ObjectSetString(
         0,
         "PSBM_TARGET_UNIT",
         OBJPROP_TEXT,
         "%"
      );
   }
   else
   {
      ObjectSetString(
         0,
         "PSBM_TARGET_UNIT",
         OBJPROP_TEXT,
         currency
      );
   }


   // ---------------------------------------------------------
   // OPEN POSITIONS
   // ---------------------------------------------------------

   ObjectSetString(
      0,
      "PSBM_POSITIONS_VALUE",
      OBJPROP_TEXT,
      IntegerToString(
         PositionsTotal()
      )
   );


   // ---------------------------------------------------------
   // BASKET PROFIT
   // ---------------------------------------------------------

   double profit =
      GetBasketProfit();


   ObjectSetString(
      0,
      "PSBM_PROFIT_VALUE",
      OBJPROP_TEXT,
      DoubleToString(
         profit,
         2
      )
   );


   if(profit > 0)
   {
      ObjectSetInteger(
         0,
         "PSBM_PROFIT_VALUE",
         OBJPROP_COLOR,
         C'90,220,140'
      );
   }
   else if(profit < 0)
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


   // ---------------------------------------------------------
   // ACTIVE BASKET
   // ---------------------------------------------------------

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
         "PSBM_TARGET_VALUE",
         OBJPROP_TEXT,
         DoubleToString(
            GetBasketTarget(),
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


      ObjectSetInteger(
         0,
         "PSBM_MODE_BUTTON",
         OBJPROP_BGCOLOR,
         C'65,65,65'
      );


      ObjectSetInteger(
         0,
         "PSBM_TARGET_EDIT",
         OBJPROP_BGCOLOR,
         C'65,65,65'
      );
   }
   else
   {
      // ------------------------------------------------------
      // WAITING
      // ------------------------------------------------------

      ObjectSetString(
         0,
         "PSBM_BALANCE_VALUE",
         OBJPROP_TEXT,
         "0.00"
      );


      ObjectSetString(
         0,
         "PSBM_TARGET_VALUE",
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


      ObjectSetInteger(
         0,
         "PSBM_MODE_BUTTON",
         OBJPROP_BGCOLOR,
         C'55,60,70'
      );


      ObjectSetInteger(
         0,
         "PSBM_TARGET_EDIT",
         OBJPROP_BGCOLOR,
         C'45,49,58'
      );
   }


   // ---------------------------------------------------------
   // SYMBOL
   // ---------------------------------------------------------

   ObjectSetString(
      0,
      "PSBM_SYMBOL_VALUE",
      OBJPROP_TEXT,
      _Symbol
   );


   // ---------------------------------------------------------
   // SPREAD
   // ---------------------------------------------------------

   ObjectSetString(
      0,
      "PSBM_SPREAD_VALUE",
      OBJPROP_TEXT,
      DoubleToString(
         GetCurrentSpreadPoints(),
         1
      )
   );


   // ---------------------------------------------------------
   // BROKER MAX
   // ---------------------------------------------------------

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
   // ---------------------------------------------------------
   // RED SL LINE DRAGGED
   // ---------------------------------------------------------

   if(
      id == CHARTEVENT_OBJECT_DRAG &&
      sparam == "PSBM_SL_LINE"
   )
   {
      UpdateStopLossFromLine();

      return;
   }


   // ---------------------------------------------------------
   // BUTTON CLICKS
   // ---------------------------------------------------------

   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // ------------------------------------------------------
      // BASKET TP MODE
      // ------------------------------------------------------

      if(sparam == "PSBM_MODE_BUTTON")
      {
         ObjectSetInteger(
            0,
            "PSBM_MODE_BUTTON",
            OBJPROP_STATE,
            false
         );


         if(IsBasketActive())
            return;


         if(GetSharedTPMode() == TP_PERCENTAGE)
         {
            GlobalVariableSet(
               GV_TP_MODE,
               (double)TP_MONEY
            );
         }
         else
         {
            GlobalVariableSet(
               GV_TP_MODE,
               (double)TP_PERCENTAGE
            );
         }


         UpdatePanel();

         return;
      }


      // ------------------------------------------------------
      // RISK MODE
      // ------------------------------------------------------

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


      // ------------------------------------------------------
      // SL LINE ON/OFF
      // ------------------------------------------------------

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


      // ------------------------------------------------------
      // CALCULATE
      // ------------------------------------------------------

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


      // ------------------------------------------------------
      // CLOSE ALL
      // ------------------------------------------------------

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


   // ---------------------------------------------------------
   // EDIT BOXES
   // ---------------------------------------------------------

   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      // ------------------------------------------------------
      // BASKET TARGET
      // ------------------------------------------------------

      if(sparam == "PSBM_TARGET_EDIT")
      {
         if(IsBasketActive())
         {
            ObjectSetString(
               0,
               "PSBM_TARGET_EDIT",
               OBJPROP_TEXT,
               DoubleToString(
                  GetSharedTPValue(),
                  2
               )
            );

            return;
         }


         ReadBasketTarget();


         ObjectSetString(
            0,
            "PSBM_TARGET_EDIT",
            OBJPROP_TEXT,
            DoubleToString(
               GetSharedTPValue(),
               2
            )
         );


         UpdatePanel();

         return;
      }


      // ------------------------------------------------------
      // TYPED SL
      // ------------------------------------------------------

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


   CreatePanel();


   // Account-wide basket monitoring does not depend
   // only on ticks from this chart.
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