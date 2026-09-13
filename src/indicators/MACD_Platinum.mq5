//+------------------------------------------------------------------+
//|                                                MACD_Platinum.mq4 |
//|                                     contactchristinali@gmail.com |
//|                               http//www.wix.com/wiseea/wise-ea#! | 
//+------------------------------------------------------------------+
#property description   "Version 1.2"
#property description   "Updated on 09/14/2018"
//+------------------------------------------------------------------+
//| Setup & Include                                                  |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 10
#property indicator_plots   4
#property indicator_level1  0.0
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRoyalBlue
#property indicator_width1  1
#property indicator_style1  STYLE_DOT
#property indicator_label1  "Macd"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrIndianRed
#property indicator_width2  2
#property indicator_label2  "Avg"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrTurquoise
#property indicator_width3  1
#property indicator_label3  "UpCross"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrOrangeRed
#property indicator_width4  1
#property indicator_label4  "DnCross"
//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input int  Fast               = 12;
input int  Slow               = 26;
input int  Smooth             = 9;
input bool ZeroLag            = true;
input bool ShowMarkersOnCross = true;
input bool PopUp_Alert        = true;
input bool PushNotifications  = false;
//+------------------------------------------------------------------+
//| Global variabels                                                 |
//+------------------------------------------------------------------+
double Macd[];             // = 0
double Avg[];              // = 1
double MarkersUp[];        // = 2
double MarkersDown[];      // = 3
//----
double fastEma[];    // = 4
double slowEma[];    // = 5
double avgEma[];     // = 6
double fastEmaEma[]; // = 7
double slowEmaEma[]; // = 8
double avgEmaEma[];  // = 9
//----
int    Multiplier = 10;   // forex multiplier from Ninja version
static datetime dt;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//----
   SetIndexBuffer(0,Macd,INDICATOR_DATA);
   SetIndexBuffer(1,Avg,INDICATOR_DATA);
   SetIndexBuffer(2,MarkersUp,INDICATOR_DATA);
   PlotIndexSetInteger(2,PLOT_ARROW,108);
   SetIndexBuffer(3,MarkersDown,INDICATOR_DATA);
   PlotIndexSetInteger(3,PLOT_ARROW,108);
   SetIndexBuffer(4,fastEma,INDICATOR_CALCULATIONS);
   SetIndexBuffer(5,slowEma,INDICATOR_CALCULATIONS);
   SetIndexBuffer(6,avgEma,INDICATOR_CALCULATIONS);
   SetIndexBuffer(7,fastEmaEma,INDICATOR_CALCULATIONS);
   SetIndexBuffer(8,slowEmaEma,INDICATOR_CALCULATIONS);
   SetIndexBuffer(9,avgEmaEma,INDICATOR_CALCULATIONS);
//----
   string short_name="MACD_Platinum(" + string(Fast) + ", " + string(Slow) + ", " + string(Smooth) +")"; 
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
   IndicatorSetInteger(INDICATOR_DIGITS,4);
   dt=0;
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
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
//----
   int limit;
   if (prev_calculated > 0)
      limit = prev_calculated - 1;
   else
   {
      ArrayInitialize(Macd, EMPTY_VALUE);
      ArrayInitialize(Avg, EMPTY_VALUE);
      ArrayInitialize(MarkersUp, EMPTY_VALUE);
      ArrayInitialize(MarkersDown, EMPTY_VALUE);
      ArrayInitialize(fastEma, 0);
      ArrayInitialize(slowEma, 0);
      ArrayInitialize(avgEma, 0);
      ArrayInitialize(fastEmaEma, 0);
      ArrayInitialize(slowEmaEma, 0);
      ArrayInitialize(avgEmaEma, 0);
      limit = 1;
   }
   double fastCoeff = 2.0 / (1 + Fast);
   double slowCoeff = 2.0 / (1 + Slow);
   double smoothCoeff = 2.0 / (1 + Smooth);
//----    
   for (int i = limit; i<rates_total; i++) 
   {
      if (!ZeroLag)
      {
         fastEma[i] = fastCoeff * Multiplier * close[i] + (1 - fastCoeff) * fastEma[i - 1];
         slowEma[i] = slowCoeff * Multiplier * close[i] + (1 - slowCoeff) * slowEma[i - 1];
         Macd[i]    = fastEma[i] - slowEma[i];
         Avg[i]     = smoothCoeff * Macd[i] + (limit == 1 ? 0 : (1 - smoothCoeff) * Avg[i - 1]);
      }
      else
      {	
         fastEma[i]    = fastCoeff * Multiplier * close[i] + (1 - fastCoeff) * fastEma[i - 1];
         slowEma[i]    = slowCoeff * Multiplier * close[i] + (1 - slowCoeff) * slowEma[i - 1];
         fastEmaEma[i] = fastCoeff * fastEma[i] + (1 - fastCoeff) * fastEmaEma[i - 1];
         slowEmaEma[i] = slowCoeff * slowEma[i] + (1 - slowCoeff) * slowEmaEma[i - 1];
         Macd[i]       = (fastEma[i] + fastEma[i] - fastEmaEma[i]) - (slowEma[i] + slowEma[i] - slowEmaEma[i]);
         avgEma[i]     = smoothCoeff * Macd[i]   + (1 - smoothCoeff) * avgEma[i - 1];
         avgEmaEma[i]  = smoothCoeff * avgEma[i] + (1 - smoothCoeff) * avgEmaEma[i - 1];
         Avg[i]  = avgEma[i] + avgEma[i] - avgEmaEma[i];
      }
      //---- markers
      MarkersUp[i]  = EMPTY_VALUE;
      MarkersDown[i] = EMPTY_VALUE;
      if (i<rates_total-1 && ShowMarkersOnCross)
      {
         if (Macd[i] > Avg[i] && Macd[i-1] <= Avg[i-1]) 
         {
            MarkersUp[i] = Avg[i];
            if (i==rates_total-2 && dt<time[rates_total-1]) alert_sig("Up Cross!",time[rates_total-1]);
         }   
         else if (Macd[i] < Avg[i] && Macd[i-1] >= Avg[i-1]) 
         {
            MarkersDown[i] = Avg[i];
            if (i==rates_total-2 && dt<time[rates_total-1]) alert_sig("Dn Cross!",time[rates_total-1]);
         } 
      }
   }
//----
   return(rates_total);
}
//******************************************************************************************************
//******************************************************************************************************
//+------------------------------------------------------------------+
//| FUNCTIONS: Send alerts                                           |
//+------------------------------------------------------------------+
void alert_sig(string comstr, datetime time) 
{
//----
   string body=TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES)+" | MACD_Platinum | "+comstr;
   if (PopUp_Alert) Alert(body);
   if (PushNotifications) SendNotification(body);
   dt=time;
}