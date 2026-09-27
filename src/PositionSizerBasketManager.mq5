#include <Trade/Trade.mqh>

#property copyright "Tinashe Chimanikire"
#property version   "2.13"
#property strict

CTrade trade;


// ============================================================
// RESPONSIVE PANEL
// ============================================================

#define BASE_PANEL_X       12
#define BASE_PANEL_Y       16
#define BASE_PANEL_WIDTH   304
#define BASE_PANEL_HEIGHT  722

#define BASE_LABEL_X       11
#define BASE_VALUE_X       160
#define BASE_UNIT_X        256

#define BASE_FONT_TITLE    6
#define BASE_FONT_SECTION  6
#define BASE_FONT_NORMAL   5
#define BASE_FONT_SMALL    5


double panel_scale = 1.0;
double auto_panel_scale = 1.0;
double manual_panel_scale = 1.0;


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

string GV_CLOSE_LOCK;

string GV_DAILY_MODE;
string GV_DAILY_TARGET;
string GV_PANEL_SCALE;


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
   // Text is 20% larger than the previous baseline and
   // continues to grow/shrink with the whole panel.
   int size =
      (int)MathRound(
         base_size * 1.20 * panel_scale
      );

   if(size < 4)
      size = 4;

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
      auto_panel_scale = 1.0;
      panel_scale = manual_panel_scale;
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


   auto_panel_scale =
      MathMin(
         width_scale,
         height_scale
      );


   if(auto_panel_scale > 1.0)
      auto_panel_scale = 1.0;


   if(auto_panel_scale < 0.50)
      auto_panel_scale = 0.50;


   // Manual scale adjusts the automatically fitted size.
   panel_scale =
      auto_panel_scale *
      manual_panel_scale;


   if(panel_scale < 0.25)
      panel_scale = 0.25;


   if(panel_scale > 1.50)
      panel_scale = 1.50;
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


   GV_CLOSE_LOCK =
      prefix + "CLOSE_LOCK";


   GV_DAILY_MODE =
      prefix + "DAILY_MODE";


   GV_DAILY_TARGET =
      prefix + "DAILY_TARGET";


   GV_PANEL_SCALE =
      prefix + "PANEL_SCALE";
}


// ============================================================
// INITIALIZE SHARED VARIABLES
// ============================================================

void InitializeSharedVariables()
{
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


   if(!GlobalVariableCheck(GV_PANEL_SCALE))
      GlobalVariableSet(
         GV_PANEL_SCALE,
         1.0
      );


   manual_panel_scale =
      GlobalVariableGet(
         GV_PANEL_SCALE
      );


   if(manual_panel_scale < 0.50)
      manual_panel_scale = 0.50;


   if(manual_panel_scale > 1.50)
      manual_panel_scale = 1.50;
}


// ============================================================
// SESSION BASKET STATE
//
// Each position permanently belongs to the 23:30 session in
// which it was opened.  Session settings are stored separately
// so carried positions keep their original target.
// ============================================================

string SessionKey(datetime session_start, string suffix)
{
   string account =
      IntegerToString(
         (int)AccountInfoInteger(ACCOUNT_LOGIN)
      );

   return
      "PSBM_" + account + "_S_" +
      IntegerToString((int)session_start) +
      "_" + suffix;
}


datetime GetSessionStartForTime(datetime value)
{
   MqlDateTime session_struct;
   TimeToStruct(value, session_struct);

   session_struct.hour = 23;
   session_struct.min  = 30;
   session_struct.sec  = 0;

   datetime boundary =
      StructToTime(session_struct);

   if(value >= boundary)
      return boundary;

   return boundary - 86400;
}


datetime GetPositionSessionStartByIndex(int index)
{
   ulong ticket = PositionGetTicket(index);

   if(ticket == 0)
      return 0;

   datetime opened =
      (datetime)PositionGetInteger(POSITION_TIME);

   return GetSessionStartForTime(opened);
}


void EnsureSessionState(datetime session_start)
{
   if(session_start <= 0)
      return;

   string balance_key =
      SessionKey(session_start, "START_BALANCE");

   string mode_key =
      SessionKey(session_start, "MODE");

   string target_key =
      SessionKey(session_start, "TARGET");

   if(!GlobalVariableCheck(balance_key))
      GlobalVariableSet(
         balance_key,
         AccountInfoDouble(ACCOUNT_BALANCE)
      );

   if(!GlobalVariableCheck(mode_key))
      GlobalVariableSet(
         mode_key,
         (double)GetDailyTargetMode()
      );

   if(!GlobalVariableCheck(target_key))
      GlobalVariableSet(
         target_key,
         GetDailyTargetValue()
      );
}


double GetSessionStartBalance(datetime session_start)
{
   EnsureSessionState(session_start);

   return GlobalVariableGet(
      SessionKey(session_start, "START_BALANCE")
   );
}


DailyTargetMode GetSessionTargetMode(datetime session_start)
{
   EnsureSessionState(session_start);

   return
      (DailyTargetMode)(int)GlobalVariableGet(
         SessionKey(session_start, "MODE")
      );
}


double GetSessionTargetValue(datetime session_start)
{
   EnsureSessionState(session_start);

   return GlobalVariableGet(
      SessionKey(session_start, "TARGET")
   );
}


int GetSessionOpenPositionCount(datetime session_start)
{
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(GetPositionSessionStartByIndex(i) == session_start)
         count++;
   }

   return count;
}


double GetSessionFloatingProfit(datetime session_start)
{
   double profit = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);

      if(GetSessionStartForTime(opened) != session_start)
         continue;

      profit += PositionGetDouble(POSITION_PROFIT);
   }

   return profit;
}


// ============================================================
// CARRY-OVER SUMMARY
// ============================================================

int GetCarryOverPositionCount(datetime current_session)
{
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      datetime position_session =
         GetPositionSessionStartByIndex(i);

      if(position_session > 0 && position_session < current_session)
         count++;
   }

   return count;
}


double GetCarryOverFloatingProfit(datetime current_session)
{
   double profit = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);

      datetime position_session =
         GetSessionStartForTime(opened);

      if(position_session > 0 && position_session < current_session)
         profit += PositionGetDouble(POSITION_PROFIT);
   }

   return profit;
}


int GetCarryOverBasketCount(datetime current_session)
{
   datetime sessions[];
   int session_count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      datetime position_session =
         GetPositionSessionStartByIndex(i);

      if(position_session <= 0 || position_session >= current_session)
         continue;

      bool already_counted = false;

      for(int j = 0; j < session_count; j++)
      {
         if(sessions[j] == position_session)
         {
            already_counted = true;
            break;
         }
      }

      if(already_counted)
         continue;

      ArrayResize(sessions, session_count + 1);
      sessions[session_count] = position_session;
      session_count++;
   }

   return session_count;
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
   return GetSessionStartForTime(TimeCurrent());
}


// ============================================================
// POSITION IDENTIFIER -> ORIGINAL SESSION
// ============================================================

datetime GetPositionIdentifierSession(long position_id)
{
   if(position_id <= 0)
      return 0;

   int total = HistoryDealsTotal();
   datetime earliest = 0;

   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);

      if(ticket == 0)
         continue;

      if(HistoryDealGetInteger(ticket, DEAL_POSITION_ID) != position_id)
         continue;

      ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);

      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;

      datetime deal_time =
         (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

      if(earliest == 0 || deal_time < earliest)
         earliest = deal_time;
   }

   if(earliest == 0)
      return 0;

   return GetSessionStartForTime(earliest);
}


// ============================================================
// CLOSED P/L BELONGING TO ONE ORIGINAL SESSION
// ============================================================

double GetSessionClosedProfit(datetime session_start)
{
   if(!HistorySelect(session_start, TimeCurrent()))
      return 0.0;

   double result = 0.0;
   int total = HistoryDealsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);

      if(ticket == 0)
         continue;

      ENUM_DEAL_TYPE deal_type =
         (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);

      if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
         continue;

      ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);

      if(
         entry != DEAL_ENTRY_OUT &&
         entry != DEAL_ENTRY_OUT_BY &&
         entry != DEAL_ENTRY_INOUT
      )
      {
         continue;
      }

      long position_id =
         HistoryDealGetInteger(ticket, DEAL_POSITION_ID);

      if(GetPositionIdentifierSession(position_id) != session_start)
         continue;

      result +=
         HistoryDealGetDouble(ticket, DEAL_PROFIT) +
         HistoryDealGetDouble(ticket, DEAL_COMMISSION) +
         HistoryDealGetDouble(ticket, DEAL_SWAP) +
         HistoryDealGetDouble(ticket, DEAL_FEE);
   }

   return result;
}


bool HasSessionClosedTrades(datetime session_start)
{
   if(!HistorySelect(session_start, TimeCurrent()))
      return false;

   int total = HistoryDealsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);

      if(ticket == 0)
         continue;

      ENUM_DEAL_TYPE deal_type =
         (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);

      if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL)
         continue;

      ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);

      if(
         entry != DEAL_ENTRY_OUT &&
         entry != DEAL_ENTRY_OUT_BY &&
         entry != DEAL_ENTRY_INOUT
      )
      {
         continue;
      }

      long position_id =
         HistoryDealGetInteger(ticket, DEAL_POSITION_ID);

      if(GetPositionIdentifierSession(position_id) == session_start)
         return true;
   }

   return false;
}


double GetSessionTargetMoney(datetime session_start)
{
   double target = GetSessionTargetValue(session_start);

   if(GetSessionTargetMode(session_start) == DAILY_MONEY)
      return target;

   return
      GetSessionStartBalance(session_start) *
      (target / 100.0);
}


double GetSessionRemainingTargetMoney(datetime session_start)
{
   double remaining =
      GetSessionTargetMoney(session_start) -
      GetSessionClosedProfit(session_start);

   if(remaining < 0)
      remaining = 0;

   return remaining;
}


double GetSessionClosedProfitPercent(datetime session_start)
{
   double start_balance =
      GetSessionStartBalance(session_start);

   if(start_balance <= 0)
      return 0.0;

   return
      (GetSessionClosedProfit(session_start) /
       start_balance) * 100.0;
}


double GetSessionRemainingTargetPercent(datetime session_start)
{
   double start_balance =
      GetSessionStartBalance(session_start);

   if(start_balance <= 0)
      return 0.0;

   return
      (GetSessionRemainingTargetMoney(session_start) /
       start_balance) * 100.0;
}


bool IsSessionTargetReached(datetime session_start)
{
   double target_money =
      GetSessionTargetMoney(session_start);

   if(target_money <= 0)
      return false;

   return
      GetSessionClosedProfit(session_start) >=
      target_money;
}


// Current daily panel always represents the CURRENT session only.

double GetTodayClosedProfit()
{
   return GetSessionClosedProfit(GetDailySessionStart());
}


bool HasClosedTradesToday()
{
   return HasSessionClosedTrades(GetDailySessionStart());
}


double GetDailyStartBalance()
{
   return GetSessionStartBalance(GetDailySessionStart());
}


double GetTodayClosedProfitPercent()
{
   return GetSessionClosedProfitPercent(GetDailySessionStart());
}


double GetDailyTargetMoney()
{
   return GetSessionTargetMoney(GetDailySessionStart());
}


double GetRemainingDailyTargetMoney()
{
   return GetSessionRemainingTargetMoney(GetDailySessionStart());
}


double GetRemainingDailyTargetPercent()
{
   return GetSessionRemainingTargetPercent(GetDailySessionStart());
}


bool IsDailyTargetReached()
{
   return IsSessionTargetReached(GetDailySessionStart());
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

   // The current session may still be edited during the day.
   // Older carried sessions keep their own frozen target.
   datetime current_session =
      GetDailySessionStart();

   EnsureSessionState(current_session);

   GlobalVariableSet(
      SessionKey(current_session, "TARGET"),
      value
   );


   return true;
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
// CLOSE ONLY POSITIONS FROM ONE SESSION
// ============================================================

bool CloseSessionPositions(datetime session_start)
{
   bool success = true;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);

      if(GetSessionStartForTime(opened) != session_start)
         continue;

      if(!trade.PositionClose(ticket))
         success = false;
   }

   return success;
}


// ============================================================
// CHECK ALL OPEN SESSION BASKETS
// ============================================================

void CheckBasketTakeProfit()
{
   datetime sessions[];
   int session_count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      datetime session_start =
         GetPositionSessionStartByIndex(i);

      if(session_start <= 0)
         continue;

      EnsureSessionState(session_start);

      bool found = false;

      for(int j = 0; j < session_count; j++)
      {
         if(sessions[j] == session_start)
         {
            found = true;
            break;
         }
      }

      if(!found)
      {
         ArrayResize(sessions, session_count + 1);
         sessions[session_count] = session_start;
         session_count++;
      }
   }

   for(int i = 0; i < session_count; i++)
   {
      datetime session_start = sessions[i];

      if(IsSessionTargetReached(session_start))
         continue;

      double target =
         GetSessionRemainingTargetMoney(session_start);

      if(target <= 0)
         continue;

      double floating =
         GetSessionFloatingProfit(session_start);

      if(floating < target)
         continue;

      if(!AcquireCloseLock())
         return;

      CloseSessionPositions(session_start);
      ReleaseCloseLock();
   }
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


   if(risk_mode == RISK_PERCENTAGE)
   {
      ObjectSetString(0, "PSBM_RISK_MODE_BUTTON", OBJPROP_TEXT, "Percentage");
      ObjectSetString(0, "PSBM_RISK_UNIT", OBJPROP_TEXT, "%");
   }
   else
   {
      ObjectSetString(0, "PSBM_RISK_MODE_BUTTON", OBJPROP_TEXT, "Money");
      ObjectSetString(
         0,
         "PSBM_RISK_UNIT",
         OBJPROP_TEXT,
         AccountInfoString(ACCOUNT_CURRENCY)
      );
   }

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


   double required_margin = 0.0;

   if(calculated_volume > 0)
   {
      double margin_price = entry;

      if(!OrderCalcMargin(
         order_type,
         _Symbol,
         calculated_volume,
         margin_price,
         required_margin
      ))
      {
         required_margin = 0.0;
      }
   }


   ObjectSetString(
      0,
      "PSBM_MARGIN_VALUE",
      OBJPROP_TEXT,
      DoubleToString(required_margin, 2)
   );


   ObjectSetString(
      0,
      "PSBM_MARGIN_UNIT",
      OBJPROP_TEXT,
      AccountInfoString(ACCOUNT_CURRENCY)
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


   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
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


   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
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

   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 2);
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

   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 2);
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

   string account_currency = AccountInfoString(ACCOUNT_CURRENCY);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double current_price = GetCurrentPrice();

   int px = PanelX();
   int py = PanelY();
   int pw = PanelWidth();

   CreateRectangle("PSBM_PANEL", px, py, pw, PanelHeight(), C'25,28,35', C'70,75,85');
   CreateRectangle("PSBM_HEADER", px, py, pw, S(42), C'35,39,48', C'35,39,48');

   CreateLabel("PSBM_TITLE", "POSITION SIZER & BASKET MANAGER",
               LabelX(), py + S(6), FontSize(BASE_FONT_TITLE), clrWhite);
   CreateLabel("PSBM_SUBTITLE", "Account-wide manual trade management",
               LabelX(), py + S(24), FontSize(BASE_FONT_SMALL), C'160,165,175');

   // Manual panel scaling. Automatic monitor/chart fitting remains active,
   // while these controls let the user fine-tune the result.
   CreateButton("PSBM_SCALE_MINUS", "-",
                px + S(216), py + S(22), S(18), S(17), C'55,60,70');

   CreateLabel("PSBM_SCALE_VALUE",
               IntegerToString((int)MathRound(manual_panel_scale * 100.0)) + "%",
               px + S(237), py + S(25), FontSize(BASE_FONT_SMALL), C'200,205,215');

   CreateButton("PSBM_SCALE_PLUS", "+",
                px + S(276), py + S(22), S(18), S(17), C'55,60,70');

   // CURRENT BASKET
   CreateLabel("PSBM_BASKET_TITLE", "CURRENT BASKET",
               LabelX(), py + S(51), FontSize(BASE_FONT_SECTION), C'90,180,255');

   CreateLabel("PSBM_POSITIONS_LABEL", "Positions",
               LabelX(), py + S(72), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_POSITIONS_VALUE", "0", py + S(72), clrWhite);

   CreateLabel("PSBM_PROFIT_LABEL", "Floating P/L",
               LabelX(), py + S(91), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_PROFIT_VALUE", "0.00", py + S(91), clrWhite);

   CreateLabel("PSBM_TP_VALUE_LABEL", "Remaining Target",
               LabelX(), py + S(110), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_TARGET_VALUE", "0.00", py + S(110), C'90,220,140');
   CreateLabel("PSBM_TARGET_UNIT", account_currency,
               UnitX(), py + S(111), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateLabel("PSBM_STATUS_LABEL", "Status",
               LabelX(), py + S(129), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_STATUS_VALUE", "WAITING", py + S(129), C'255,190,80');

   // CARRY-OVER
   CreateRectangle("PSBM_CARRY_DIVIDER", LabelX(), py + S(151), pw - S(22), 1,
                   C'65,70,80', C'65,70,80');
   CreateLabel("PSBM_CARRY_TITLE", "CARRY-OVER",
               LabelX(), py + S(161), FontSize(BASE_FONT_SECTION), C'90,180,255');

   CreateLabel("PSBM_CARRY_BASKETS_LABEL", "Older Baskets",
               LabelX(), py + S(181), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_CARRY_BASKETS_VALUE", "0", py + S(181), clrWhite);

   CreateLabel("PSBM_CARRY_POSITIONS_LABEL", "Positions",
               LabelX(), py + S(200), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_CARRY_POSITIONS_VALUE", "0", py + S(200), clrWhite);

   CreateLabel("PSBM_CARRY_PROFIT_LABEL", "Floating P/L",
               LabelX(), py + S(219), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_CARRY_PROFIT_VALUE", "0.00", py + S(219), clrWhite);
   CreateLabel("PSBM_CARRY_CURRENCY", account_currency,
               UnitX(), py + S(220), FontSize(BASE_FONT_SMALL), C'160,165,175');

   // DAILY PERFORMANCE
   CreateRectangle("PSBM_DAILY_DIVIDER", LabelX(), py + S(241), pw - S(22), 1,
                   C'65,70,80', C'65,70,80');
   CreateLabel("PSBM_DAILY_TITLE", "DAILY PERFORMANCE",
               LabelX(), py + S(251), FontSize(BASE_FONT_SECTION), C'90,180,255');

   CreateLabel("PSBM_DAILY_MODE_LABEL", "Target Mode",
               LabelX(), py + S(273), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateButton("PSBM_DAILY_MODE_BUTTON", "Percentage",
                ValueX(), py + S(267), S(88), S(19), C'55,60,70');

   CreateLabel("PSBM_DAILY_TARGET_LABEL", "Daily Target",
               LabelX(), py + S(297), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateEdit("PSBM_DAILY_TARGET_EDIT", DoubleToString(GetDailyTargetValue(), 2),
              ValueX(), py + S(291), S(72));
   CreateLabel("PSBM_DAILY_TARGET_UNIT", "%",
               UnitX(), py + S(298), FontSize(BASE_FONT_SMALL), clrWhite);

   CreateLabel("PSBM_DAILY_CLOSED_LABEL", "Closed P/L",
               LabelX(), py + S(321), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_DAILY_CLOSED_VALUE", "0.00", py + S(321), clrWhite);
   CreateLabel("PSBM_DAILY_CURRENCY", account_currency,
               UnitX(), py + S(322), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateLabel("PSBM_DAILY_PERCENT_LABEL", "Closed P/L %",
               LabelX(), py + S(340), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_DAILY_PERCENT_VALUE", "0.00", py + S(340), clrWhite);
   CreateLabel("PSBM_DAILY_PERCENT_UNIT", "%",
               UnitX(), py + S(341), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateLabel("PSBM_REMAINING_LABEL", "Remaining Target",
               LabelX(), py + S(359), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_REMAINING_VALUE", "0.00", py + S(359), C'255,190,80');
   CreateLabel("PSBM_REMAINING_UNIT", "%",
               UnitX(), py + S(360), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateLabel("PSBM_DAILY_STATUS_LABEL", "Status",
               LabelX(), py + S(378), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_DAILY_STATUS_VALUE", "IN PROGRESS", py + S(378), C'255,190,80');

   // POSITION SIZER
   CreateRectangle("PSBM_SIZER_DIVIDER", LabelX(), py + S(400), pw - S(22), 1,
                   C'65,70,80', C'65,70,80');
   CreateLabel("PSBM_SIZER_TITLE", "POSITION SIZER",
               LabelX(), py + S(410), FontSize(BASE_FONT_SECTION), C'90,180,255');

   CreateLabel("PSBM_SYMBOL_LABEL", "Symbol",
               LabelX(), py + S(432), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_SYMBOL_VALUE", _Symbol, py + S(432), clrWhite);

   CreateLabel("PSBM_SPREAD_LABEL", "Spread",
               LabelX(), py + S(451), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_SPREAD_VALUE", "0.0", py + S(451), clrWhite);
   CreateLabel("PSBM_SPREAD_UNIT", "points",
               UnitX(), py + S(452), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateLabel("PSBM_RISK_MODE_LABEL", "Risk Mode",
               LabelX(), py + S(475), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateButton("PSBM_RISK_MODE_BUTTON", "Percentage",
                ValueX(), py + S(469), S(88), S(19), C'55,60,70');

   CreateLabel("PSBM_RISK_LABEL", "Risk",
               LabelX(), py + S(499), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateEdit("PSBM_RISK_EDIT", "1.00", ValueX(), py + S(493), S(72));
   CreateLabel("PSBM_RISK_UNIT", "%",
               UnitX(), py + S(500), FontSize(BASE_FONT_SMALL), clrWhite);

   CreateLabel("PSBM_ENTRY_LABEL", "Entry Price",
               LabelX(), py + S(523), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateEdit("PSBM_ENTRY_EDIT", DoubleToString(current_price, digits),
              ValueX(), py + S(517), S(88));

   CreateLabel("PSBM_SL_LABEL", "Stop Loss",
               LabelX(), py + S(547), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateEdit("PSBM_SL_EDIT", "", ValueX(), py + S(541), S(88));

   CreateLabel("PSBM_SL_LINE_LABEL", "SL Line",
               LabelX(), py + S(571), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateButton("PSBM_SL_LINE_BUTTON", "ON",
                ValueX(), py + S(565), S(72), S(19), C'45,105,75');

   CreateLabel("PSBM_RISK_AMOUNT_LABEL", "Risk Amount",
               LabelX(), py + S(595), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_RISK_AMOUNT_VALUE", "0.00", py + S(595), clrWhite);
   CreateLabel("PSBM_RISK_AMOUNT_UNIT", account_currency,
               UnitX(), py + S(596), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateLabel("PSBM_SIZE_LABEL", "Calculated Size",
               LabelX(), py + S(614), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_SIZE_VALUE", "0.00", py + S(614), C'90,220,140');
   CreateLabel("PSBM_SIZE_UNIT", "lots",
               UnitX(), py + S(615), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateLabel("PSBM_BROKER_MAX_LABEL", "Broker Max",
               LabelX(), py + S(633), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_BROKER_MAX_VALUE",
               DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), 2),
               py + S(633), clrWhite);
   CreateLabel("PSBM_BROKER_MAX_UNIT", "lots",
               UnitX(), py + S(634), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateLabel("PSBM_MARGIN_LABEL", "Required Margin",
               LabelX(), py + S(652), FontSize(BASE_FONT_NORMAL), C'190,195,205');
   CreateValue("PSBM_MARGIN_VALUE", "0.00", py + S(652), clrWhite);
   CreateLabel("PSBM_MARGIN_UNIT", account_currency,
               UnitX(), py + S(653), FontSize(BASE_FONT_SMALL), C'160,165,175');

   CreateButton("PSBM_CALCULATE_BUTTON", "CALCULATE",
                LabelX(), py + S(676), pw - S(22), S(21), C'45,105,155');

   CreateLabel("PSBM_SIGNATURE", "By Tinashe Chimanikire",
               LabelX(), py + S(704), FontSize(BASE_FONT_SMALL), C'130,135,145');


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
   // CURRENT SESSION BASKET
   // ========================================================

   datetime current_session =
      GetDailySessionStart();

   EnsureSessionState(current_session);

   int current_positions =
      GetSessionOpenPositionCount(current_session);

   ObjectSetString(
      0,
      "PSBM_POSITIONS_VALUE",
      OBJPROP_TEXT,
      IntegerToString(current_positions)
   );

   double basket_profit =
      GetSessionFloatingProfit(current_session);

   ObjectSetString(
      0,
      "PSBM_PROFIT_VALUE",
      OBJPROP_TEXT,
      DoubleToString(basket_profit, 2)
   );

   if(basket_profit > 0)
      ObjectSetInteger(0, "PSBM_PROFIT_VALUE", OBJPROP_COLOR, C'90,220,140');
   else if(basket_profit < 0)
      ObjectSetInteger(0, "PSBM_PROFIT_VALUE", OBJPROP_COLOR, C'255,100,100');
   else
      ObjectSetInteger(0, "PSBM_PROFIT_VALUE", OBJPROP_COLOR, clrWhite);

   double remaining_money =
      GetSessionRemainingTargetMoney(current_session);

   ObjectSetString(
      0,
      "PSBM_TARGET_VALUE",
      OBJPROP_TEXT,
      DoubleToString(remaining_money, 2)
   );

   ObjectSetString(
      0,
      "PSBM_TARGET_UNIT",
      OBJPROP_TEXT,
      account_currency
   );

   if(current_positions > 0)
   {
      ObjectSetString(0, "PSBM_STATUS_VALUE", OBJPROP_TEXT, "ACTIVE");
      ObjectSetInteger(0, "PSBM_STATUS_VALUE", OBJPROP_COLOR, C'90,220,140');
   }
   else
   {
      ObjectSetString(0, "PSBM_STATUS_VALUE", OBJPROP_TEXT, "WAITING");
      ObjectSetInteger(0, "PSBM_STATUS_VALUE", OBJPROP_COLOR, C'255,190,80');
   }


   // ========================================================
   // CARRY-OVER BASKETS
   // ========================================================

   int carry_baskets =
      GetCarryOverBasketCount(current_session);

   int carry_positions =
      GetCarryOverPositionCount(current_session);

   double carry_profit =
      GetCarryOverFloatingProfit(current_session);

   ObjectSetString(
      0,
      "PSBM_CARRY_BASKETS_VALUE",
      OBJPROP_TEXT,
      IntegerToString(carry_baskets)
   );

   ObjectSetString(
      0,
      "PSBM_CARRY_POSITIONS_VALUE",
      OBJPROP_TEXT,
      IntegerToString(carry_positions)
   );

   ObjectSetString(
      0,
      "PSBM_CARRY_PROFIT_VALUE",
      OBJPROP_TEXT,
      DoubleToString(carry_profit, 2)
   );

   ObjectSetString(
      0,
      "PSBM_CARRY_CURRENCY",
      OBJPROP_TEXT,
      account_currency
   );

   if(carry_profit > 0)
      ObjectSetInteger(0, "PSBM_CARRY_PROFIT_VALUE", OBJPROP_COLOR, C'90,220,140');
   else if(carry_profit < 0)
      ObjectSetInteger(0, "PSBM_CARRY_PROFIT_VALUE", OBJPROP_COLOR, C'255,100,100');
   else
      ObjectSetInteger(0, "PSBM_CARRY_PROFIT_VALUE", OBJPROP_COLOR, clrWhite);


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
      // MANUAL PANEL SCALE
      // -----------------------------------------------------

      if(
         sparam == "PSBM_SCALE_MINUS" ||
         sparam == "PSBM_SCALE_PLUS"
      )
      {
         ObjectSetInteger(
            0,
            sparam,
            OBJPROP_STATE,
            false
         );


         if(sparam == "PSBM_SCALE_MINUS")
            manual_panel_scale -= 0.10;
         else
            manual_panel_scale += 0.10;


         if(manual_panel_scale < 0.50)
            manual_panel_scale = 0.50;


         if(manual_panel_scale > 1.50)
            manual_panel_scale = 1.50;


         GlobalVariableSet(
            GV_PANEL_SCALE,
            manual_panel_scale
         );


         RebuildResponsivePanel();
         return;
      }


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


         datetime current_session =
            GetDailySessionStart();

         EnsureSessionState(current_session);

         GlobalVariableSet(
            SessionKey(current_session, "MODE"),
            (double)GetDailyTargetMode()
         );


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
   // Freeze the current session settings and discover any
   // carried session baskets from their original open times.
   EnsureSessionState(GetDailySessionStart());

   for(int i = 0; i < PositionsTotal(); i++)
      EnsureSessionState(GetPositionSessionStartByIndex(i));

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