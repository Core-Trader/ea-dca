//+------------------------------------------------------------------+
//|                                                   QMP Filter.mq5 |
//|                                     contactchristinali@gmail.com |
//|                               http//www.wix.com/wiseea/wise-ea#! | 
//+------------------------------------------------------------------+
#property copyright     "Programmed by Christina Li, Wise-EA MetaTrader Programming"
#property link          "www.wix.com/wiseea/wise-ea#! "
#property version       "1.4"
#property description   "Copyright Jim Brown"
#property description   "Updated on 09/14/2018"
//+------------------------------------------------------------------+
//| Setup & Include                                                  |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   4
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLimeGreen
#property indicator_width1  1
#property indicator_label1  "Up"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  1
#property indicator_label2  "Dn"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrRoyalBlue
#property indicator_width3  2
#property indicator_label3  "Hitf_Up"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrOrangeRed
#property indicator_width4  2
#property indicator_label4  "Hitf_Dn"
//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input ENUM_TIMEFRAMES  HigherTimeFrame = 0;
input int    Fast               = 12;   
input int    Slow               = 26;
input int    Smooth             = 9;
input bool   ZeroLag            = true;
input int    SF                 = 1;         
input int    RSI_Period         = 8; 
input int    WP                 = 3; 
input bool   PopUp_Alert        = false;
input bool   PushNotifications  = false;    
//+------------------------------------------------------------------+
//| Global variabels                                                 |
//+------------------------------------------------------------------+
double up[], dn[], uph[], dnh[], pnt;
long   dig;
double trend[], trendh[];
static datetime dt[2];
//----
int MACD_Handle, QQE_Handle;
int MACDH_Handle, QQEH_Handle;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//---- 
   SetIndexBuffer(0,up,INDICATOR_DATA);
   PlotIndexSetInteger(0,PLOT_ARROW,108);
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   SetIndexBuffer(1,dn,INDICATOR_DATA);
   PlotIndexSetInteger(1,PLOT_ARROW,108);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);
//---- 
   SetIndexBuffer(2,uph,INDICATOR_DATA);
   PlotIndexSetInteger(2,PLOT_ARROW,233);
   SetIndexBuffer(3,dnh,INDICATOR_DATA);
   PlotIndexSetInteger(3,PLOT_ARROW,234);
   SetIndexBuffer(4, trend, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, trendh, INDICATOR_CALCULATIONS);
//----
   ArraySetAsSeries(up, true);
   ArraySetAsSeries(dn, true);
   ArraySetAsSeries(uph, true);
   ArraySetAsSeries(dnh, true);
   ArraySetAsSeries(trend, true);
   ArraySetAsSeries(trendh, true);
//----   
   IndicatorSetInteger(INDICATOR_DIGITS,5);
   dt[0]=0;
   dt[1]=0;

   MACD_Handle = iCustom(NULL, 0, "MACD_Platinum", Fast, Slow, Smooth, ZeroLag, true, false, false);
   QQE_Handle = iCustom(NULL, 0, "QQE Adv", SF, RSI_Period, WP);
   if (HigherTimeFrame > Period())
   {
      MACDH_Handle = iCustom(NULL, HigherTimeFrame, "MACD_Platinum", Fast, Slow, Smooth, ZeroLag, true, false, false);
      QQEH_Handle = iCustom(NULL, HigherTimeFrame, "QQE Adv", SF, RSI_Period, WP);
   }
   else
   {
      MACDH_Handle = INVALID_HANDLE;
      QQEH_Handle = INVALID_HANDLE;
   }

   dig = SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
   pnt = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   if (dig == 3 || dig == 5)
      pnt*=10;
}

void OnDeinit(const int reason)
{
   if (MACD_Handle != INVALID_HANDLE)
      IndicatorRelease(MACD_Handle);
   if (QQE_Handle != INVALID_HANDLE)
      IndicatorRelease(QQE_Handle);
   if (MACDH_Handle != INVALID_HANDLE)
      IndicatorRelease(MACDH_Handle);
   if (QQEH_Handle != INVALID_HANDLE)
      IndicatorRelease(QQEH_Handle);
}

#define UP_TREND 1
#define DOWN_TREND -1 
  
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
{
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   int limit;
   if (prev_calculated <= 0 || prev_calculated > rates_total)
   {
      limit = rates_total - 2;
      ArrayInitialize(trend, 0);
      ArrayInitialize(trendh, 0);
      ArrayInitialize(up, EMPTY_VALUE);
      ArrayInitialize(dn, EMPTY_VALUE);
      ArrayInitialize(uph, EMPTY_VALUE);
      ArrayInitialize(dnh, EMPTY_VALUE);
   }
   else
      limit = rates_total - prev_calculated + 1;

   double blue[1], orange[1], qqe1[1], qqe2[1];   
   for(int i=limit; i > 0; i--)
   {
      up[i] = EMPTY_VALUE;
      dn[i] = EMPTY_VALUE;
      uph[i] = EMPTY_VALUE;
      dnh[i] = EMPTY_VALUE;
      trend[i] = trend[i + 1];
      trendh[i] = trendh[i + 1];
      if (CopyBuffer(MACD_Handle, 0, i, 1, blue) <= 0
         || CopyBuffer(MACD_Handle, 1, i, 1, orange) <= 0
         || CopyBuffer(QQE_Handle, 0, i, 1, qqe1) <= 0
         || CopyBuffer(QQE_Handle, 1, i, 1, qqe2) <= 0)
      {
         return(0);
      }
      if (trend[i] != UP_TREND && blue[0] >= orange[0] && qqe1[0] >= qqe2[0])    
      {
         trend[i] = UP_TREND;
         up[i] = low[i] - 2 * pnt;
         if (i == 1 && dt[0] < time[0])
            alert_sig("Trend change to Up!", 0, time[0]);
      }
      else if (trend[i] != DOWN_TREND && blue[0] < orange[0] && qqe1[0] < qqe2[0]) 
      {
         trend[i] = DOWN_TREND;
         dn[i] = high[i] + 2 * pnt;
         if (i==1 && dt[0] < time[0])
            alert_sig("Trend change to Dn!", 0, time[0]);
      }
      if (HigherTimeFrame > 0 && HigherTimeFrame > Period())
      {
         int shift = iBarShift(HigherTimeFrame, time[i]);
         int nextshift = iBarShift(HigherTimeFrame, time[i - 1]);
         if (shift != -1) // last current chart bar for the higher time frame bar
         {
            double blueh[1], orangeh[1], qqe1h[1], qqe2h[1];
            if (CopyBuffer(MACDH_Handle, 0, shift, 1, blueh) <= 0
               || CopyBuffer(MACDH_Handle, 1, shift, 1, orangeh) <= 0
               || CopyBuffer(QQEH_Handle, 0, shift, 1, qqe1h) <= 0
               || CopyBuffer(QQEH_Handle, 1, shift, 1, qqe2h) <= 0)
            {
               return(0);
            }
            if (trendh[i] != UP_TREND && blueh[0] >= orangeh[0] && qqe1h[0] >= qqe2h[0])    
            {
               trendh[i] = UP_TREND;
               uph[i] = low[i] - 4 * pnt;
               if (i == 1 && dt[1] < time[0] && shift != nextshift)
                  alert_sig("Higher TimeFrame Trend change to Up!", 1, time[0]);
            }
            else if (trendh[i] != DOWN_TREND && blueh[0] < orangeh[0] && qqe1h[0] < qqe2h[0])
            {
               trendh[i] = DOWN_TREND;
               dnh[i] = high[i] + 4 * pnt;
               if (i == 1 && dt[1] < time[0] && shift != nextshift)
                  alert_sig("Higher TimeFrame Trend change to Dn!", 1, time[0]);
            }
         }
      }
   }
//----
   return (rates_total);
}
//******************************************************************************************************
//+------------------------------------------------------------------+
//| FUNCTIONS: Send alerts                                           |
//+------------------------------------------------------------------+
void alert_sig(string comstr, int index, datetime time) 
{
//----
   string body=TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES)+" | QMP Filter | "+comstr;
   if (PopUp_Alert)
      Alert(body);
   if (PushNotifications)
      SendNotification(body);
   dt[index] = time;
}
//+------------------------------------------------------------------+
//| FUNCTIONS: iBarShift                                             |
//+------------------------------------------------------------------+
int iBarShift(ENUM_TIMEFRAMES tf, datetime checktime)
{
   datetime Arr[];
   if (CopyTime(NULL, tf, 0, 1, Arr) < 1) // count only the current time    
      return -1;
   
   datetime curtime = Arr[0];
   if (checktime >= curtime)
      return (0);
   int num = CopyTime(NULL, tf, checktime, curtime, Arr);
   if (checktime < Arr[0])
      return(num);
   else
      return(num-1); 
}