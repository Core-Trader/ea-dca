//+------------------------------------------------------------------+
//|                                                      QQE Adv.mq5 |
//|                                     contactchristinali@gmail.com |
//|                               http//www.wix.com/wiseea/wise-ea#! | 
//+------------------------------------------------------------------+
#property description   "Version 1.00"
#property description   "Updated on 08/29/2018"
//+------------------------------------------------------------------+
//| Setup & Include                                                  |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 6
#property indicator_plots   2
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrOrange
#property indicator_width1  2
#property indicator_label1  "RsiMa"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  1
#property indicator_style2  STYLE_DOT
#property indicator_label2  "Slow"
#include <MovingAverages.mqh>
//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input int SF = 1; 
input int RSI_Period = 8;
input int WP = 3; 
//+------------------------------------------------------------------+
//| Global variabels                                                 |
//+------------------------------------------------------------------+
double RsiMa[];
double TrLevelSlow[];
//----
double AtrRsi[];
double MaAtrRsi[];
double Rsi[];
double MaMaAtrRsi[];
//----
int Wilders_Period;
int StartBar;
int RSI_Handle;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
void OnInit()
  {
//----  
   Wilders_Period = RSI_Period * 2 - 1;
   if (Wilders_Period < SF) StartBar = SF;
   else StartBar = Wilders_Period;
//----
   SetIndexBuffer(0,RsiMa,INDICATOR_DATA);
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,StartBar);
   SetIndexBuffer(1,TrLevelSlow,INDICATOR_DATA);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,StartBar);
   SetIndexBuffer(2,AtrRsi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(3,MaAtrRsi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(4,Rsi,INDICATOR_CALCULATIONS);
   SetIndexBuffer(5,MaMaAtrRsi,INDICATOR_CALCULATIONS);
//---- set arrays as series, most recent entry at index [0]
   ArraySetAsSeries(RsiMa,true);
   ArraySetAsSeries(TrLevelSlow,true);
   ArraySetAsSeries(AtrRsi,true);
   ArraySetAsSeries(MaAtrRsi,true);
   ArraySetAsSeries(Rsi,true);
   ArraySetAsSeries(MaMaAtrRsi,true);
//----
   string short_name="QQE("+string(SF)+")"; 
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
   IndicatorSetInteger(INDICATOR_DIGITS,4);
//----
   RSI_Handle = iRSI(NULL, 0, RSI_Period, PRICE_CLOSE);   
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
   if(prev_calculated==0 || prev_calculated<0 || prev_calculated>rates_total)
   {
      ArrayInitialize(RsiMa, EMPTY_VALUE);
      ArrayInitialize(TrLevelSlow, EMPTY_VALUE);
      ArrayInitialize(AtrRsi, EMPTY_VALUE);
      ArrayInitialize(MaAtrRsi, EMPTY_VALUE);
      ArrayInitialize(Rsi, EMPTY_VALUE);
      ArrayInitialize(MaMaAtrRsi, EMPTY_VALUE);
      limit = rates_total - 2;
   }
   else
      limit = rates_total-prev_calculated;
//----
   if(CopyBuffer(RSI_Handle,0,0,rates_total,Rsi)<=0)    
     {
      Print("Getting RAI is failed! Error",GetLastError());
      return(0);
     }
//----
   if (SF > 1)
      ExponentialMAOnBuffer(rates_total,prev_calculated,RSI_Period,SF,Rsi,RsiMa);
//---- 
   for(int i=limit; i>=0; i--)
   {
      if (SF == 1)
         RsiMa[i] = Rsi[i];
      AtrRsi[i] = MathAbs(RsiMa[i+1] - RsiMa[i]);
   }
//----       
   ExponentialMAOnBuffer(rates_total, prev_calculated, RSI_Period + SF + 1, Wilders_Period, AtrRsi, MaAtrRsi); 
//----
   ExponentialMAOnBuffer(rates_total, prev_calculated, RSI_Period + SF + 1 + Wilders_Period, Wilders_Period, MaAtrRsi, MaMaAtrRsi);
//---- get TrLevelSlow values
   double tr = TrLevelSlow[limit + 1];
   for(int i = limit; i >= 0; i--)
   {
      double dar = MaMaAtrRsi[i] * WP;
      if (RsiMa[i] < tr && !(RsiMa[i + 1] < tr && RsiMa[i] + dar > tr))
      {
         tr = RsiMa[i] + dar;
      }
      else if (RsiMa[i] > tr && !(RsiMa[i + 1] > tr && RsiMa[i] - dar < tr))
      {
         tr = RsiMa[i] - dar;
      }
      TrLevelSlow[i] = tr;
   }

   return rates_total;
}
