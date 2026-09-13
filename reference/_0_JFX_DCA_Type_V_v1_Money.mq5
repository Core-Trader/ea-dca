//+----------------------------------------------------------------------------------------------+
//|  Copyright 2025, EA Builder Pro                                                              |
//|                                                                                              |
//|  https://www.eabuilderpro.com                                                                |
//|                                                                                              |
//|  Thank you for your purchase!                                                                |
//|                                                                                              |
//|  Please trade responsibly. Using this EA may cause you to lose real money.                   |
//|  Test throughly with a demo account and never leave an EA without                            |
//|  monitoring and supervision on a Live account.                                               |
//|                                                                                              |
//|  EA Builder Pro can not be held responsible for any losses, whatever the reason.             |
//|  Do not use this EA if you do not agree with our terms: https://eabuilderpro.com/terms.html  |
//|                                                                                              |
//|  Thanks to all whom contributed by sharing feedback!                                         |
//|                                                                                              |
//|  Copyright 2025, EA Builder Pro                                                              |
//+----------------------------------------------------------------------------------------------+

//
//  Includes
//
#include <Trade\SymbolInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\Trade.mqh>

//
//  Properties
//
#property copyright "Copyright 2025, EA Builder Pro"
#property link "https://www.eabuilderpro.com"
#property version "3.00"
//#property description "Publisher: John Doe" // If you're publishing this EA, please uncomment this field.
//#property description "Description of your EA." // If you're publishing this EA, please uncomment this field.
#property strict

//
//  Inputs
//
input group "General settings";
input int MagicNumber = 327556; // Magic number (unique number per EA, per instance)
input double PipPointOverride = 0; // Manual pip point (0 = auto detection)
input string OrderSymbolOverride; // Order symbol (empty = current)
input int MaxDeviationSlippage = 10; // Maximum deviation/ slippage
input bool ValidateOrderMargin = true; // Validate available order margin
bool UseValidateOrderMargin = true;
input string OrderComment = "#0 JFX DCA Type V v1 Money (327556)"; // Order comment
input bool OneQuotePerBar = false; // First quote/tick per bar processed only
input group "SL & TP";
input bool SendSlTpToBroker = false; // TP/ SL managed by the broker (false = by EA)
input double TrailUpdateStepPip = 1; // Broker: Minimal SL/ TP update frequency (Pips)
input int TrailUpdateStepSeconds = 30; // Broker: Minimal SL/ TP update frequency (Seconds)
input bool AllowManualTPSLChanges = false; // EA: Allow manually moving TP and SL lines
input group "Display & Notifications";
input bool AlertOnError = true; // Metatrader alert on error
input bool NotificationOnError = true; // Send notification on error
input bool EmailOnError = false; // Send e-mail on error
input bool DisplayOnChartError = true; // Display errors on chart
input bool DisplayOnChartWarning = true; // Display warnings on chart
input bool DisplayOrderInfo = false; // Display order counts on chart

//
//  Globals
//
ENUM_TIMEFRAMES DisplayOrderDuringTimeframe = PERIOD_W1; // Display orders on the chart during timeframe
double PipPoint = 0.0001;
string OrderSymbolTarget;
uint OrderFillingType = -1;
uint AccountMarginMode = -1;
bool StopEA = false;
double UnitsOneLot = 100000;
int IsDemoLiveOrVisualMode = false;
string Error;
string ErrorPreviousQuote;
string Warning;
datetime ErrorPreviousQuoteDateTime;
string OrderInfoComment;
datetime OrdersModifiedLast = 0;
bool UsesBrokerOrderTrailing = false;

//
//  MQL5 Init
//
// --- declaration of constants
#define OBJPROP_TIME1 300
#define OBJPROP_PRICE1 301
#define OBJPROP_TIME2 302
#define OBJPROP_PRICE2 303
#define OBJPROP_TIME3 304
#define OBJPROP_PRICE3 305
//---
#define OBJPROP_RAY 310
#define OBJPROP_FIBOLEVELS 200
//---
 
#define OBJPROP_FIRSTLEVEL1 211 
#define OBJPROP_FIRSTLEVEL2 212
#define OBJPROP_FIRSTLEVEL3 213
#define OBJPROP_FIRSTLEVEL4 214
#define OBJPROP_FIRSTLEVEL5 215
#define OBJPROP_FIRSTLEVEL6 216
#define OBJPROP_FIRSTLEVEL7 217
#define OBJPROP_FIRSTLEVEL8 218
#define OBJPROP_FIRSTLEVEL9 219
#define OBJPROP_FIRSTLEVEL10 220
#define OBJPROP_FIRSTLEVEL11 221
#define OBJPROP_FIRSTLEVEL12 222
#define OBJPROP_FIRSTLEVEL13 223
#define OBJPROP_FIRSTLEVEL14 224
#define OBJPROP_FIRSTLEVEL15 225
#define OBJPROP_FIRSTLEVEL16 226
#define OBJPROP_FIRSTLEVEL17 227
#define OBJPROP_FIRSTLEVEL18 228
#define OBJPROP_FIRSTLEVEL19 229
#define OBJPROP_FIRSTLEVEL20 230
#define OBJPROP_FIRSTLEVEL21 231
#define OBJPROP_FIRSTLEVEL22 232
#define OBJPROP_FIRSTLEVEL23 233
#define OBJPROP_FIRSTLEVEL24 234
#define OBJPROP_FIRSTLEVEL25 235
#define OBJPROP_FIRSTLEVEL26 236
#define OBJPROP_FIRSTLEVEL27 237
#define OBJPROP_FIRSTLEVEL28 238
#define OBJPROP_FIRSTLEVEL29 239
#define OBJPROP_FIRSTLEVEL30 240
#define OBJPROP_FIRSTLEVEL31 241
//---
#define MODE_OPEN 0
#define MODE_CLOSE 3
#define MODE_VOLUME 4 
#define MODE_REAL_VOLUME 5
#define MODE_TRADES 0
#define MODE_HISTORY 1
#define SELECT_BY_POS 0
#define SELECT_BY_TICKET 1
//---
#define DOUBLE_VALUE 0
#define FLOAT_VALUE 1
#define LONG_VALUE INT_VALUE
//---
#define CHART_BAR 0
#define CHART_CANDLE 1
//---
#define MODE_ASCEND 0
#define MODE_DESCEND 1
//---
#define MODE_LOW 1
#define MODE_HIGH 2
#define MODE_TIME 5
#define MODE_BID 9
#define MODE_ASK 10
#define MODE_POINT 11
#define MODE_DIGITS 12
#define MODE_SPREAD 13
#define MODE_STOPLEVEL 14
#define MODE_LOTSIZE 15
#define MODE_TICKVALUE 16
#define MODE_TICKSIZE 17
#define MODE_SWAPLONG 18
#define MODE_SWAPSHORT 19
#define MODE_STARTING 20
#define MODE_EXPIRATION 21
#define MODE_TRADEALLOWED 22
#define MODE_MINLOT 23
#define MODE_LOTSTEP 24
#define MODE_MAXLOT 25
#define MODE_SWAPTYPE 26
#define MODE_PROFITCALCMODE 27
#define MODE_MARGINCALCMODE 28
#define MODE_MARGININIT 29
#define MODE_MARGINMAINTENANCE 30
#define MODE_MARGINHEDGED 31
#define MODE_MARGINREQUIRED 32
#define MODE_FREEZELEVEL 33
//---
#define EMPTY -1
//---
#define CharToStr CharToString
#define DoubleToStr DoubleToString
#define StrToDouble StringToDouble
#define StrToInteger (int)StringToInteger
#define StrToTime StringToTime
#define TimeToStr TimeToString 
#define StringGetChar StringGetCharacter
#define StringSetChar StringSetCharacter

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES TimeframeConvert(int tf)
  {
   switch(tf)
     {
      case 0: return(PERIOD_CURRENT);
      case 1: return(PERIOD_M1);
      case 5: return(PERIOD_M5);
      case 15: return(PERIOD_M15);
      case 30: return(PERIOD_M30);
      case 60: return(PERIOD_H1);
      case 240: return(PERIOD_H4);
      case 1440: return(PERIOD_D1);
      case 10080: return(PERIOD_W1);
      case 43200: return(PERIOD_MN1);
      
      case 2: return(PERIOD_M2);
      case 3: return(PERIOD_M3);
      case 4: return(PERIOD_M4);      
      case 6: return(PERIOD_M6);
      case 10: return(PERIOD_M10);
      case 12: return(PERIOD_M12);
      case 16385: return(PERIOD_H1);
      case 16386: return(PERIOD_H2);
      case 16387: return(PERIOD_H3);
      case 16388: return(PERIOD_H4);
      case 16390: return(PERIOD_H6);
      case 16392: return(PERIOD_H8);
      case 16396: return(PERIOD_H12);
      case 16408: return(PERIOD_D1);
      case 32769: return(PERIOD_W1);
      case 49153: return(PERIOD_MN1);      
      default: return(PERIOD_CURRENT);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_MA_METHOD MethodConvert(int method)
  {
   switch(method)
     {
      case 0: return(MODE_SMA);
      case 1: return(MODE_EMA);
      case 2: return(MODE_SMMA);
      case 3: return(MODE_LWMA);
      default: return(MODE_SMA);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_APPLIED_PRICE PriceConvert(int price)
  {
   switch(price)
     {
      case 1: return(PRICE_CLOSE);
      case 2: return(PRICE_OPEN);
      case 3: return(PRICE_HIGH);
      case 4: return(PRICE_LOW);
      case 5: return(PRICE_MEDIAN);
      case 6: return(PRICE_TYPICAL);
      case 7: return(PRICE_WEIGHTED);
      default: return(PRICE_CLOSE);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_STO_PRICE StoFieldConvert(int field)
  {
   switch(field)
     {
      case 0: return(STO_LOWHIGH);
      case 1: return(STO_CLOSECLOSE);
      default: return(STO_LOWHIGH);
     }
  }

//+------------------------------------------------------------------+
enum ALLIGATOR_MODE  { agMODE_GATORJAW=1, agMODE_GATORTEETH, agMODE_GATORLIPS };
enum ADX_MODE        { adxMODE_MAIN, adxMODE_PLUSDI, adxMODE_MINUSDI };
enum UP_LOW_MODE     { ulMODE_BASE, ulMODE_UPPER, ulMODE_LOWER };
enum ICHIMOKU_MODE   { imMODE_TENKANSEN=1, imMODE_KIJUNSEN, imMODE_SENKOUSPANA, imMODE_SENKOUSPANB, imMODE_CHINKOUSPAN };
enum MAIN_SIGNAL_MODE{ msMODE_MAIN, msMODE_SIGNAL };
enum ORDER_GROUP_TYPE { Single=1, SymbolOrderType=2, Basket=3, SymbolCode=4 };
enum ORDER_PROFIT_CALCULATION_TYPE { Pips=1, Money=2, EquityPercentage=3 };
enum ORDER_RISK_CALCULATION_TYPE { RiskTypeMoney=1, RiskTypeBalancePercentage=2 };
enum CRUD { NoAction = 0, Created = 1, Updated = 2, Deleted = 3 };
enum SL_TP_DIRECTION { Auto = 0, Favorable = 1, Unfavorable = 2 };
enum CLOSE_INFO_STATUS { New = 0, Executing = 1, Old = 2 };

//
//  TradingModuleModuleDemand
//
enum TradingModuleDemand
{
	NoneDemand = 0,
	NoBuyDemand = 1,
	NoSellDemand = 2,
	NoOpenDemand = 4,
	OpenBuySellDemand = 8,
	OpenBuyDemand = 16,
	OpenSellDemand = 32,
	CloseBuyDemand = 64,
	CloseSellDemand = 128,
	CloseBuySellDemand = 256
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CopyBufferOneValue(int handle, int index, int shift)
{
   double buf[];

   if(CopyBuffer(handle, index, shift, 1, buf) > 0)
      return(buf[0]);

   return EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| For zone indicators                                              |
//+------------------------------------------------------------------+
double CopyClosestBufferOneValue(int handle, string symbol, int mode, int startShift)
{
    for(int iShift = startShift; iShift < 1000; iShift++)
    {
      double result = CopyBufferOneValue(handle, mode, iShift);
      if (result != EMPTY_VALUE && result != 0)
      {
         return result;
      }
    }
    
    return EMPTY_VALUE;
}
//
//  MQL5 Library Functions
//
double Ask_LibFunc()
{
   MqlTick last_tick;
   SymbolInfoTick(_Symbol,last_tick);
   return last_tick.ask;
}

double Bid_LibFunc()
{
   MqlTick last_tick;
   SymbolInfoTick(_Symbol,last_tick);
   return last_tick.bid;
}

void Open_LibFunc(double& open[], int count)
{
   ArraySetAsSeries(open,true);
   CopyOpen(_Symbol,_Period,0,count,open);
}

void Close_LibFunc(double& close[], int count)
{
   ArraySetAsSeries(close,true);
   CopyClose(_Symbol,_Period,0,count,close);
}

void Low_LibFunc(double& low[], int count)
{
   ArraySetAsSeries(low,true);
   CopyLow(_Symbol,_Period,0,count,low);
}

void High_LibFunc(double& high[], int count)
{
   ArraySetAsSeries(high,true);
   CopyHigh(_Symbol,_Period,0,count,high);
}

double Hour_LibFunc()
{
   MqlDateTime mql_datetime;
   TimeCurrent(mql_datetime);
   return mql_datetime.hour;
}

double Minutes_LibFunc()
{
   MqlDateTime mql_datetime;
   TimeCurrent(mql_datetime);
   return mql_datetime.min;
}

double Seconds_LibFunc()
{
   MqlDateTime mql_datetime;
   TimeCurrent(mql_datetime);
   return mql_datetime.sec;
}

double DayOfWeek_LibFunc()
{
   MqlDateTime mql_datetime;
   TimeCurrent(mql_datetime);
   return mql_datetime.day_of_week;
}

double DayOfMonth_LibFunc()
{
   MqlDateTime mql_datetime;
   TimeCurrent(mql_datetime);
   return mql_datetime.day;
}

double DayOfYear_LibFunc()
{
   MqlDateTime mql_datetime;
   TimeCurrent(mql_datetime);
   return mql_datetime.day_of_year;
}

double MonthOfYear_LibFunc()
{
   MqlDateTime mql_datetime;
   TimeCurrent(mql_datetime);
   return mql_datetime.mon;
}

double Year_LibFunc()
{
   MqlDateTime mql_datetime;
   TimeCurrent(mql_datetime);
   return mql_datetime.year;
}

int TimeSeconds_LibFunc(const datetime dateTime)
{
   MqlDateTime dt;
   TimeToStruct(dateTime, dt);
   return dt.sec;
}

double AccountBalance_LibFunc()
{
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

double AccountCredit_LibFunc()
{
   return AccountInfoDouble(ACCOUNT_CREDIT);
}

double AccountEquity_LibFunc()
{
   return AccountInfoDouble(ACCOUNT_EQUITY);
}

double AccountFreeMargin_LibFunc()
{
   return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
}

double AccountMargin_LibFunc()
{
   return AccountInfoDouble(ACCOUNT_MARGIN);
}

double AccountProfit_LibFunc()
{
   return AccountInfoDouble(ACCOUNT_PROFIT);
}

string AccountCompany_LibFunc()
{
   return AccountInfoString(ACCOUNT_COMPANY);
}

string AccountCurrency_LibFunc()
{
   return AccountInfoString(ACCOUNT_CURRENCY);
}

string AccountName_LibFunc()
{
   return AccountInfoString(ACCOUNT_NAME);
}

string AccountServer_LibFunc()
{
   return AccountInfoString(ACCOUNT_SERVER);
}

long AccountLeverage_LibFunc()
{
   return AccountInfoInteger(ACCOUNT_LEVERAGE);
}

long AccountNumber_LibFunc()
{
   return AccountInfoInteger(ACCOUNT_LOGIN);
}

double MarketInfo_LibFunc(string symbol, int type)
{
   switch(type)
     {
      case MODE_LOW:
         return(SymbolInfoDouble(symbol,SYMBOL_LASTLOW));
      case MODE_HIGH:
         return(SymbolInfoDouble(symbol,SYMBOL_LASTHIGH));
      case MODE_TIME:
         return((double)SymbolInfoInteger(symbol,SYMBOL_TIME));
      case MODE_BID:
         return(Bid_LibFunc());
      case MODE_ASK:
         return(Ask_LibFunc());
      case MODE_POINT:
         return(SymbolInfoDouble(symbol,SYMBOL_POINT));
      case MODE_DIGITS:
         return((double)SymbolInfoInteger(symbol,SYMBOL_DIGITS));
      case MODE_SPREAD:
         return((double)SymbolInfoInteger(symbol,SYMBOL_SPREAD));
      case MODE_STOPLEVEL:
         return((double)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL));
      case MODE_LOTSIZE:
         return(SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE));
      case MODE_TICKVALUE:
         return(SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE));
      case MODE_TICKSIZE:
         return(SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE));
      case MODE_SWAPLONG:
         return(SymbolInfoDouble(symbol,SYMBOL_SWAP_LONG));
      case MODE_SWAPSHORT:
         return(SymbolInfoDouble(symbol,SYMBOL_SWAP_SHORT));
      case MODE_STARTING:
         return(0);
      case MODE_EXPIRATION:
         return(0);
      case MODE_TRADEALLOWED:
         return(0);
      case MODE_MINLOT:
         return(SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN));
      case MODE_LOTSTEP:
         return(SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP));
      case MODE_MAXLOT:
         return(SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX));
      case MODE_SWAPTYPE:
         return((double)SymbolInfoInteger(symbol,SYMBOL_SWAP_MODE));
      case MODE_PROFITCALCMODE:
         return((double)SymbolInfoInteger(symbol,SYMBOL_TRADE_CALC_MODE));
      case MODE_MARGINCALCMODE:
         return(0);
      case MODE_MARGININIT:
         return(0);
      case MODE_MARGINMAINTENANCE:
         return(0);
      case MODE_MARGINHEDGED:
         return(0);
      case MODE_MARGINREQUIRED:
         return(0);
      case MODE_FREEZELEVEL:
         return((double)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL));
   
      default: return(0);
     }
   return(0);
}

interface ITickFunction
{
   void Evaluate();
   void Init();
};

interface IIntTickFunction : public ITickFunction
{
   int GetValue(int index = 0);
};

interface IDoubleTickFunction : public ITickFunction
{
   double GetValue(int index = 0);
};

interface IDateTimeTickFunction : public ITickFunction
{
   datetime GetValue(int index = 0);
};

class IntTickFunction : public IIntTickFunction
{
   private: 
      int _values[];
      int _zeroIndex;
      int _valueCount;

   protected:
      int GetValueCount()
      {
         return _valueCount;
      }
      
      virtual int GetCurrentValue() = 0;

   public: 
      IntTickFunction(int valueCount)
      {
         _valueCount = valueCount;
      }
      
      void Init()
      {
         _zeroIndex = -1;
         ArrayResize(_values, _valueCount);
         ArrayInitialize(_values, GetCurrentValue());
      }

      void Evaluate()
      {
         // add value to collection
         int currentValue = GetCurrentValue();
         
         _zeroIndex = (_zeroIndex + 1) % _valueCount;
         _values[_zeroIndex] = currentValue;
      }
   
      int GetValue(int index = 0)
      {
          int requiredIndex = (_zeroIndex + _valueCount - index) % _valueCount; 
          return _values[requiredIndex]; 
      }
};

class DoubleTickFunction : public IDoubleTickFunction
{
   private: 
      double _values[];
      int _zeroIndex;
      int _valueCount;

   protected:
      int GetValueCount()
      {
         return _valueCount;
      }
      
      virtual double GetCurrentValue() = 0;
      
   public: 
      DoubleTickFunction(int valueCount)
      {
         _valueCount = valueCount;
      }
      
      void Init()
      {
         _zeroIndex = -1;
         ArrayResize(_values, _valueCount);
         ArrayInitialize(_values, GetCurrentValue());
      }

      void Evaluate()
      {
         // add value to collection
         double currentValue = GetCurrentValue();
         
         _zeroIndex = (_zeroIndex + 1) % _valueCount;
         _values[_zeroIndex] = currentValue;
      }
   
      double GetValue(int index = 0)
      {
          int requiredIndex = (_zeroIndex + _valueCount - index) % _valueCount; 
          return _values[requiredIndex]; 
      }
};

class DateTimeTickFunction : public IDateTimeTickFunction
{
   private: 
      datetime _values[];
      int _zeroIndex;
      int _valueCount;

   protected:
      int GetValueCount()
      {
         return _valueCount;
      }
      
      virtual datetime GetCurrentValue() = 0;
      
   public: 
      DateTimeTickFunction(int valueCount)
      {
         _valueCount = valueCount;
      }
      
      void Init()
      {
         _zeroIndex = -1;
         ArrayResize(_values, _valueCount);
         ArrayInitialize(_values, GetCurrentValue());
      }

      void Evaluate()
      {
         // add value to collection
         datetime currentValue = GetCurrentValue();
         
         _zeroIndex = (_zeroIndex + 1) % _valueCount;
         _values[_zeroIndex] = currentValue;
      }
   
      datetime GetValue(int index = 0)
      {
          int requiredIndex = (_zeroIndex + _valueCount - index) % _valueCount; 
          return _values[requiredIndex]; 
      }
};

class AskFunction : public DoubleTickFunction
{
   protected:
      double GetCurrentValue()
      {
         return Ask_LibFunc();
      }
   
   public:
      AskFunction() : DoubleTickFunction(2)
      {
      }
};

class BidFunction : public DoubleTickFunction
{
   protected:
      double GetCurrentValue()
      {
         return Bid_LibFunc();
      }
   
   public:
      BidFunction() : DoubleTickFunction(2)
      {
      }
};

class TimeFunction : public DateTimeTickFunction
{
   protected:
      datetime GetCurrentValue()
      {
         return iTime(_Symbol, _Period, 0);
      }
   
   public:
      TimeFunction() : DateTimeTickFunction(10)
      {
      }
};

int NewBarOnTick(int period = PERIOD_CURRENT)
{
  int bars = Bars(_Symbol, (ENUM_TIMEFRAMES)period, TimeFunc.GetValue(1),  TimeFunc.GetValue(0));
  
  if (bars > 0)
    return bars - 1;
  else 
    return 0; 
}

IDoubleTickFunction *AskFunc;
IDoubleTickFunction *BidFunc;
IDateTimeTickFunction *TimeFunc;

uint GetFillingType()
{
   uint fillingType = -1;

   uint filling = (uint)SymbolInfoInteger(OrderSymbolTarget, SYMBOL_FILLING_MODE);
   if ((filling&SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
   {
      fillingType = ORDER_FILLING_FOK;
      Print("Filling type: FOK");
   }
   else if ((filling&SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
   {
      fillingType = ORDER_FILLING_IOC;
      Print("Filling type: IOC");
   }
   else
   {
      fillingType = ORDER_FILLING_RETURN;
      Print("Filling type: RETURN");
   }
   
   return fillingType;
}

uint GetExecutionType()
{
   // If it returns SYMBOL_TRADE_EXECUTION_INSTANT (or SYMBOL_TRADE_EXECUTION_REQUEST) then you can use "deviation" with OrderSend. Otherwise you can't.
   uint executionType = -1;

   uint execution = (uint)SymbolInfoInteger(OrderSymbolTarget, SYMBOL_TRADE_EXEMODE);
   if ((execution & SYMBOL_TRADE_EXECUTION_MARKET) == SYMBOL_TRADE_EXECUTION_MARKET)
   {
      executionType = SYMBOL_TRADE_EXECUTION_MARKET;
      Print("Deal execution mode: Market execution, deviation setting will be ignored.");
   }
   else if ((execution & SYMBOL_TRADE_EXECUTION_INSTANT) == SYMBOL_TRADE_EXECUTION_INSTANT)
   {
      executionType = SYMBOL_TRADE_EXECUTION_INSTANT;
      Print("Deal execution mode: Instant execution, deviation setting might be taken into account, depending on your broker.");
   }
   else if ((execution & SYMBOL_TRADE_EXECUTION_REQUEST) == SYMBOL_TRADE_EXECUTION_REQUEST)
   {
      executionType = SYMBOL_TRADE_EXECUTION_REQUEST;
      Print("Deal execution mode: Request execution, deviation setting might be taken into account, depending on your broker.");
   }
   else if ((execution & SYMBOL_TRADE_EXECUTION_EXCHANGE) == SYMBOL_TRADE_EXECUTION_EXCHANGE)
   {
      executionType = SYMBOL_TRADE_EXECUTION_EXCHANGE;
      Print("Deal execution mode: Exchange execution, deviation setting will be ignored.");
   }
   
   return executionType;
}

uint GetAccountMarginMode()
{
   uint marginMode = -1;

   marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if (marginMode == ACCOUNT_MARGIN_MODE_RETAIL_NETTING)
   {
      Print("Account margin mode: Netting");
   }
   else if (marginMode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("Account margin mode: Hedging");
   }
   else if (marginMode == ACCOUNT_MARGIN_MODE_EXCHANGE)
   {
      Print("Account margin mode: Exchange");
   }
   else
   {
      Print("Unkown margin type");
   }

   return marginMode;
}


string GetErrorDescription(int error_code)
{
    string description = "";
    switch (error_code)
    {
        case 10004: description = "Requote"; break;
        case 10006: description = "Request rejected"; break;
        case 10007: description = "Request canceled by trader"; break;
        case 10008: description = "Order placed"; break;
        case 10009: description = "Request completed"; break;
        case 10010: description = "Only part of the request was completed"; break;
        case 10011: description = "Request processing error"; break;
        case 10012: description = "Request canceled by timeout"; break;
        case 10013: description = "Invalid request"; break;
        case 10014: description = "Invalid volume in the request"; break;
        case 10015: description = "Invalid price in the request"; break;
        case 10016: description = "Invalid stops in the request"; break;
        case 10017: description = "Trade is disabled"; break;
        case 10018: description = "Market is closed"; break;
        case 10019: description = "There is not enough money to complete the request"; break;
        case 10020: description = "Prices changed"; break;
        case 10021: description = "There are no quotes to process the request"; break;
        case 10022: description = "Invalid order expiration date in the request"; break;
        case 10023: description = "Order state changed"; break;
        case 10024: description = "Too frequent requests"; break;
        case 10025: description = "No changes in request"; break;
        case 10026: description = "Autotrading disabled by server"; break;
        case 10027: description = "Autotrading disabled by client terminal"; break;
        case 10028: description = "Request locked for processing"; break;
        case 10029: description = "Order or position frozen"; break;
        case 10030: description = "Invalid order filling type"; break;
        case 10031: description = "No connection with the trade server"; break;
        case 10032: description = "Operation is allowed only for live accounts"; break;
        case 10033: description = "The number of pending orders has reached the limit"; break;
        case 10034: description = "The volume of orders and positions for the symbol has reached the limit"; break;
        case 10035: description = "Incorrect or prohibited order type"; break;
        case 10036: description = "Position with the specified POSITION_IDENTIFIER has already been closed"; break;
        case 10038: description = "A close volume exceeds the current position volume"; break;
        case 10039: description = "A close order already exists for a specified position"; break;
        case 10040: description = "The number of open positions simultaneously present on an account has reached the limit"; break;
        case 10041: description = "The pending order activation request is rejected, the order is canceled"; break;
        case 10042: description = "The request is rejected, because the 'Only long positions are allowed' rule is set for the symbol"; break;
        case 10043: description = "The request is rejected, because the 'Only short positions are allowed' rule is set for the symbol"; break;
        case 10044: description = "The request is rejected, because the 'Only position closing is allowed' rule is set for the symbol"; break;
        case 10045: description = "The request is rejected, because 'Position closing is allowed only by FIFO rule' flag is set for the trading account"; break;
        case 10046: description = "The request is rejected, because the 'Opposite positions on a single symbol are disabled' rule is set for the trading account"; break;
        default: description = "Unknown error code " + IntegerToString(error_code); break;
    }
    return description;
}

string GetErrorDescriptionTip(int error_code)
{
    string description = "";
    switch (error_code)
    {
        case 10022: description = " Try setting expiration to at least 10 minutes (not seconds)."; break;
    }
    return description;
}

void SetPipPoint()
{
   PipPoint = PipPointOverride != 0 ? PipPointOverride : GetRealPipPoint(Symbol());
   Print("Pip (forex)/ Point (indices): " + DoubleToStr(PipPoint, 5));
}

void SetSymbol()
{
   OrderSymbolTarget = OrderSymbolOverride != "" ? OrderSymbolOverride : Symbol();
   Print("Reading data from chart (" + Symbol() + "), sending orders to symbol: " + OrderSymbolTarget);
}

// Pip Point Function
double GetRealPipPoint(string symbol)
{
	double calcPoint = 0;
    long calcDigits = SymbolInfoInteger(symbol, SYMBOL_DIGITS);
 
	if (calcDigits == 0)
	{
		calcPoint = 1;
	}
	else if (calcDigits == 1)
	{
		calcPoint = 1;
	}
	else if(calcDigits == 2)
	{
	   calcPoint = 0.1;
	}
	else if (calcDigits == 3) 
	{
		calcPoint = 0.01;
    }
	else if(calcDigits == 4 || calcDigits == 5) 
		calcPoint = 0.0001;

	return(calcPoint);
}

bool MarginRequired(ENUM_ORDER_TYPE type, double volume, double &marginRequired)
{
   double price;
   
   if (type == ORDER_TYPE_BUY)
   {
      price = Ask_LibFunc();
   }
   else if (type == ORDER_TYPE_SELL)
   {
      price = Bid_LibFunc();
   }
   else
   {
      string message = "MarginRequired: Unsupported ENUM_ORDER_TYPE";
      HandleErrors(message);

      price = Ask_LibFunc();
   }

   if (!OrderCalcMargin(type, OrderSymbolTarget, volume, price, marginRequired))
   {
      HandleErrors(StringFormat("Couldn't calculate required margin, error: %d", GetLastError()));
      return false;
   }

   return true;
}

bool HLineCreate(const long            chart_ID = 0,        // chart's ID 
                 const string          name = "HLine",      // line name 
                 const int             sub_window = 0,      // subwindow index 
                 double                price = 0,           // line price 
                 const color           clr = clrRed,        // line color 
                 const ENUM_LINE_STYLE style = STYLE_SOLID, // line style 
                 const int             width = 1,           // line width 
                 const bool            back = false,        // in the background 
                 const bool            selection = true,    // highlight to move 
                 const bool            hidden = true,       // hidden in the object list 
                 const long            z_order = 0)         // priority for mouse click 
{
    uint lineFindResult = ObjectFind(chart_ID, name);
    if (lineFindResult != UINT_MAX)
    {
        Print("HLineCreate object already exists: " + name);
        return false;
    }
    
    if(!price)
    {
        price = Bid_LibFunc();
    }
    
    ResetLastError(); 

    if(!ObjectCreate(chart_ID, name, OBJ_HLINE, sub_window, 0, price)) 
    {
        Print(__FUNCTION__, ": failed to create a horizontal line! Error code = ", GetLastError()); 
        return(false); 
    }

    ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr); 
    ObjectSetInteger(chart_ID, name, OBJPROP_STYLE, style); 
    ObjectSetInteger(chart_ID, name, OBJPROP_WIDTH, width); 
    ObjectSetInteger(chart_ID, name, OBJPROP_BACK, back); 
    //--- enable (true) or disable (false) the mode of moving the line by mouse 
    //--- when creating a graphical object using ObjectCreate function, the object cannot be 
    //--- highlighted and moved by default. Inside this method, selection parameter 
    //--- is true by default making it possible to highlight and move the object 
    if (AllowManualTPSLChanges)
    {
      ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, selection); 
      ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, selection); 
    }
    //--- hide (true) or display (false) graphical object name in the object list 
    ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, hidden); 
    //--- set the priority for receiving the event of a mouse click in the chart 
    ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, z_order); 
    //--- successful execution 
    
    return(true);
} 

bool HLineMove(const long   chart_ID=0,   // chart's ID 
               const string name="HLine", // line name 
               double       price=0)      // line price 
{
    uint lineFindResult = ObjectFind(ChartID(), name);
    if (lineFindResult == UINT_MAX)
    {
        Print("HLineMove didn't find object: " + name);
        return false;
    }

    if(!price)
    {
        price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    }
    
    ResetLastError(); 
    
    if(!ObjectMove(chart_ID, name, 0, 0, price)) 
    { 
        Print(__FUNCTION__, ": failed to move the horizontal line! Error code = ", GetLastError()); 
        return(false); 
    } 
    return(true); 
}

bool AnyChartObjectDelete(const long chart_ID = 0,   // chart's ID 
                 const string name = "") // line name 
{
    uint lineFindResult = ObjectFind(ChartID(), name);
    if (lineFindResult == UINT_MAX)
    {
        return false;
    }

    ResetLastError();

    if(!ObjectDelete(chart_ID, name)) 
    { 
        Print(__FUNCTION__, ": failed to delete a horizontal line! Error code = ", GetLastError()); 
        return(false); 
    } 
    
    return(true); 
};

bool IsBullishOrderType(ENUM_ORDER_TYPE orderType)
{
   return orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP;
}

bool IsBearishOrderType(ENUM_ORDER_TYPE orderType)
{
   return orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL_STOP;
}

bool IsPendingOrderType(ENUM_ORDER_TYPE orderType)
{
   return orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL_STOP;
}

//
//  Array Functions
//
class ArrayFunctions
{
   public:
      static void Add(ulong item, ulong &array[])
      {
         int size = ArraySize(array);
         ArrayResize(array, size + 1);
         array[size] = item;
      }
      
      static void Remove(ulong item, ulong &array[])
      {
         int size = ArraySize(array);
         bool found = false;
      
         for (int i = 0; i < size; i++) {
            if (array[i] == item) {
               found = true;
            }
            if (found && i < size - 1) {
               array[i] = array[i + 1];
            }
         }
      
         if (found) {
            ArrayResize(array, size - 1);
         }
      }
      
      static bool Contains(ulong item, ulong &array[])
      {
         int size = ArraySize(array);
         for (int i = 0; i < size; i++) {
            if (array[i] == item) {
               return true;
            }
         }
      
         return false;
      }
};

// Don't remove
int Dummy(string message)
{   
    return 0;
}
//
//  Indicator Inputs
//
input group "Indicator Inputs"
input int QQEAdv_QQE7142_SF = 7;
input int QQEAdv_QQE7142_RSI_Period = 14;
input int QQEAdv_QQE7142_WP = 2;
input int QMPFilter_QMPFilter1_Fast = 12;
input int QMPFilter_QMPFilter1_Slow = 26;
input int QMPFilter_QMPFilter1_Smooth = 9;
input int QMPFilter_QMPFilter1_SF = 1;
input int QMPFilter_QMPFilter1_RSI_Period = 8;
input int QMPFilter_QMPFilter1_WP = 3;
input int TheBreakEvenIndi_Breakeven1_BuyLineWidth = 2;
input int TheBreakEvenIndi_Breakeven1_SellLineWidth = 2;
input int TheBreakEvenIndi_Breakeven1_AllLineWidth = 2;
input double TheBreakEvenIndi_Breakeven1_PipOffset = 10.0;
input int TheBreakEvenIndi_Breakeven1_LabelXOffset = 250;
input int TheBreakEvenIndi_Breakeven1_LabelYSpacing = 15;
input int TheBreakEvenIndi_Breakeven1_LabelFontSize = 10;

//
//  Indicators
//
int hd_QQEAdv_QQE7142;
double fn_QQEAdv_QQE7142(string symbol,int mode,uint shift)
{
    int index = 0;
    index = mode;

    return CopyBufferOneValue(hd_QQEAdv_QQE7142, index, shift);
}

int hd_QMPFilter_QMPFilter1;
double fn_QMPFilter_QMPFilter1(string symbol,int mode,uint shift)
{
    int index = 0;
    index = mode;

    return CopyBufferOneValue(hd_QMPFilter_QMPFilter1, index, shift);
}

int hd_TheBreakEvenIndi_Breakeven1;
double fn_TheBreakEvenIndi_Breakeven1(string symbol,int mode,uint shift)
{
    int index = 0;
    index = mode;

    return CopyBufferOneValue(hd_TheBreakEvenIndi_Breakeven1, index, shift);
}

//
//  Commission
//
double CommissionAmountPerTrade = 0.0;
double CommissionPercentagePerLot = 0.0;
double CommissionAmountPerLot = 0.0;
double TotalCommission = 0.0;
bool UseCommissionInProfitInPips = false;

//
//  OrderCloseInfo
//
class OrderCloseInfo
{
	public:
		string ModuleCode;
		double Price;
		int Percentage;
		SL_TP_DIRECTION Direction;
		CLOSE_INFO_STATUS Status;

		void OrderCloseInfo()
		{
		}

		void OrderCloseInfo(OrderCloseInfo* ordercloseinfo)
		{
			ModuleCode = ordercloseinfo.ModuleCode;
			Price = ordercloseinfo.Price;
			Percentage = ordercloseinfo.Percentage;
			Direction = ordercloseinfo.Direction;
			Status = ordercloseinfo.Status;
		}

		bool IsClosePriceSLHit(ENUM_ORDER_TYPE type, double ask, double bid)
		{
			if (Direction != Auto)
			{
				return IsDirectionHit(type, ask, bid, false);
			}
			else
			{
				// No explicit direction, fallback on logic (likely obsolete)
		   	    switch (type)
		   	    {
		   		    case ORDER_TYPE_BUY:
		   		    {
		   			    return bid <= Price;
		   		    }
		   		    case ORDER_TYPE_SELL:
		   		    {
		   			    return ask >= Price;
		   		    }
		   	    }
			}

			return false;
		}

		bool IsClosePriceTPHit(ENUM_ORDER_TYPE type, double ask, double bid)
		{
		    if (Direction != Auto)
			{
				return IsDirectionHit(type, ask, bid, true);
			}
			else
		    {
		        // No explicit direction, fallback on logic (likely obsolete)
		   	    switch (type)
		   	    {
		   		    case ORDER_TYPE_BUY:
		   		    {
		   			    return bid >= Price;
		   		    }
		   		    case ORDER_TYPE_SELL:
		   		    {
		   			    return ask <= Price;
		   		    }
		   	    }
		    }

			return false;
		}

		void ~OrderCloseInfo()
		{
		}
	private:
bool IsDirectionHit(ENUM_ORDER_TYPE type, double ask, double bid, bool isTP)
{
   // There are 8 scenario's:
   // 1. Buy SL - Favorable - due to the weight of the order group the SL is above the buy order - use Ask
   // 2. Buy SL - Unfavorable - normal scenario - use Bid
   // 3. Buy TP - Favorable - normal scenario - use Bid
   // 4. Buy TP - Unfavorable - due to the weight of the order group the TP is under the buy order - use Ask
   // 5. Sell SL - Favorable - due to the weight of the order group the SL is under the sell order - use Bid
   // 6. Sell SL - Unfavorable - normal scenario - use Ask
   // 7. Sell TP - Favorable - normal scenario - use Ask
   // 8. Sell TP - Unfavorable - due to the weight of the order group the TP is above the sell order - use Bid

	switch (type)
	{
		case ORDER_TYPE_BUY:
		{
		   if (Direction == Favorable)
		   {
		      return (isTP && bid >= Price) || (!isTP && ask >= Price);     // Scenario 3 || Scenario 1
		   }
		   else if (Direction == Unfavorable)
		   {
		      return (isTP && ask <= Price) || (!isTP && bid <= Price);     // Scenario 4 || Scenario 2
		   }
		}
		case ORDER_TYPE_SELL:
		{
			if (Direction == Favorable)
		   {
		      return (isTP && ask <= Price) || (!isTP && bid <= Price);     // Scenario 7 || Scneario 5
		   }
		   else if (Direction == Unfavorable)
		   {
		      return (isTP && bid >= Price) || (!isTP && ask >= Price);     // Scenario 8 || Scenario 6
		   }
		}
	}

	return false;
}

};

//
//  Order
//
class Order
{
	public:
		ulong Ticket;
		ulong PositionId;
		ENUM_ORDER_TYPE Type;
		ENUM_ORDER_STATE State;
		long MagicNumber;
		double PreAssumedLots;
		double Lots;
		double OrderFilledLots;
		double OrderExitedLots;
		datetime OpenTime;
		double OpenPrice;
		datetime CloseTime;
		double ClosePrice;
		double StopLoss;
		double StopLossManual;
		double TakeProfit;
		double TakeProfitManual;
		datetime Expiration;
		double CurrentProfitPips;
		double HighestProfitPips;
		double LowestProfitPips;
		string Comment;
		uint TradeRetCode;
		ulong TradeDealTicket;
		double TradePrice;
		double TradeVolume;
		double Commission;
		double CommissionInPips;
		string SymbolCode;
		bool IsAwaitingDealExecution;
		OrderCloseInfo* CloseInfosTP[];
		OrderCloseInfo* CloseInfosSL[];
		Order* ParentOrder;
		bool MustBeVisibleOnChart;

		void Order(bool mustBeVisibleOnChart)
		{
			OrderFilledLots = 0.0;
			OrderExitedLots = 0.0;
			OpenPrice = 0.0;
			ClosePrice = 0.0;
			Commission = 0.0;
			CommissionInPips = 0.0;
			MustBeVisibleOnChart = mustBeVisibleOnChart;
		}

		void Order(Order* order, bool mustBeVisibleOnChart)
		{
			Ticket = order.Ticket;
			PositionId = order.PositionId;
			Type = order.Type;
			State = order.State;
			MagicNumber = order.MagicNumber;
			PreAssumedLots = order.PreAssumedLots;
			Lots = order.Lots;
			OpenTime = order.OpenTime;
			OpenPrice = order.OpenPrice;
			CloseTime = order.CloseTime;
			ClosePrice = order.ClosePrice;
			StopLoss = order.StopLoss;
			StopLossManual = order.StopLossManual;
			TakeProfit = order.TakeProfit;
			TakeProfitManual = order.TakeProfitManual;
			Expiration = order.Expiration;
			CurrentProfitPips = order.CurrentProfitPips;
			HighestProfitPips = order.HighestProfitPips;
			LowestProfitPips = order.LowestProfitPips;
			Comment = order.Comment;
			TradeRetCode = order.TradeRetCode;
			TradeDealTicket = order.TradeDealTicket;
			TradePrice = order.TradePrice;
			TradeVolume = order.TradeVolume;
			Commission = order.Commission;
			CommissionInPips = order.CommissionInPips;
			SymbolCode = order.SymbolCode;
			IsAwaitingDealExecution = order.IsAwaitingDealExecution;
			ParentOrder = order.ParentOrder;
			MustBeVisibleOnChart = mustBeVisibleOnChart;
        
		    for (int i = 0; i < ArraySize(order.CloseInfosSL); i++)
		    {
			    OrderCloseInfo* closeInfo = order.CloseInfosSL[i];
			    SetCloseInfo(CloseInfosSL, closeInfo.ModuleCode, closeInfo.Price, closeInfo.Percentage, closeInfo.Direction, closeInfo.Status);
		    }

		    for (int i = 0; i < ArraySize(order.CloseInfosTP); i++)
		    {
			    OrderCloseInfo* closeInfo = order.CloseInfosTP[i];
			    SetCloseInfo(CloseInfosTP, closeInfo.ModuleCode, closeInfo.Price, closeInfo.Percentage, closeInfo.Direction, closeInfo.Status);
		    }
		}

		void TransformToOpened()
		{
		    if (Type == ORDER_TYPE_BUY_LIMIT || Type == ORDER_TYPE_BUY_STOP)
		    {
		        Type = ORDER_TYPE_BUY;
		        Print("Transformed limit order into buy order");
		    }
		    else if (Type == ORDER_TYPE_SELL_LIMIT || Type == ORDER_TYPE_SELL_STOP)
		    {
		        Type = ORDER_TYPE_SELL;
		        Print("Transformed limit order into sell order");
		    }
		}

		Order* SplitOrder(int percentageToSplitOff)
		{
			Order* splittedOffPieceOfOrder = new Order(&this, true);
			splittedOffPieceOfOrder.Lots = CalcVolumePartialClose(this.Lots, percentageToSplitOff);

			if (this.Lots - splittedOffPieceOfOrder.Lots < 1e-13)
			{
		        // nothing can be split off anymore
		        splittedOffPieceOfOrder.MustBeVisibleOnChart = false;
				splittedOffPieceOfOrder.Lots = 0;
			}
			else
			{
				this.Lots = this.Lots - splittedOffPieceOfOrder.Lots;
			}

			return splittedOffPieceOfOrder;
		}

		double CalculateProfitPipettes()
		{
		    double closePrice = GetClosePrice();

		    switch (Type)
		    {
				case ORDER_TYPE_BUY:
				{
				    return (closePrice - OpenPrice);
				    break;
				}

				case ORDER_TYPE_SELL:
				{
				    return (OpenPrice - closePrice);
				    break;
				}
		    }

		    return 0;
		}

		double CalculateProfitPips()
		{
		    double pipettes = CalculateProfitPipettes();
		    double pipPoint;
		    
		    if (SymbolCode == Symbol())
		    {
			    pipPoint = PipPoint;                    // use this PipPoint, because the value could have a manual override for the current symbol
		    }
		    else
		    {
			    pipPoint = GetRealPipPoint(SymbolCode); // Use GetRealPipPoint because each symbol evaluated can be different (basket of orders of different symbols)
		    }
				    
		    double pips = pipettes / pipPoint; 

		    if (UseCommissionInProfitInPips)
		        return pips - CommissionInPips;
		    else
		        return pips;
		}

		double CalculateProfitCurrency()
		{
		    double tickValue = SymbolInfoDouble(SymbolCode, SYMBOL_TRADE_TICK_VALUE);
			double tickSize = SymbolInfoDouble(SymbolCode, SYMBOL_TRADE_TICK_SIZE);
			double valuePerPip = (PipPoint/ tickSize) * tickValue;

		    switch (Type)
			{
		        case ORDER_TYPE_BUY:
		            return (((GetClosePrice() - OpenPrice) / PipPoint) * valuePerPip * TradeVolume) - Commission;
		        case ORDER_TYPE_SELL:
		            return (((OpenPrice - GetClosePrice()) / PipPoint) * valuePerPip * TradeVolume) - Commission;
			}
		    return 0;
		}

		double CalculateProfitEquityPercentage()
		{
		    double tickValue = SymbolInfoDouble(OrderSymbolTarget, SYMBOL_TRADE_TICK_VALUE);
			double tickSize = SymbolInfoDouble(OrderSymbolTarget, SYMBOL_TRADE_TICK_SIZE);
			double valuePerPip = (PipPoint/ tickSize) * tickValue;

		    switch (Type)
			{
		        case ORDER_TYPE_BUY:
		            return 100 * ((((GetClosePrice() - OpenPrice) / PipPoint) * valuePerPip * TradeVolume) - Commission) / AccountBalance_LibFunc();
		        case ORDER_TYPE_SELL:
		            return 100 * ((((OpenPrice - GetClosePrice()) / PipPoint) * valuePerPip * TradeVolume) - Commission) / AccountBalance_LibFunc();
			}
		    return 0;
		}

		double CalculateValueDifferencePips(double value)
		{
		    double divOpenPrice = 0.0;
		    switch (Type)
		    {
		        case ORDER_TYPE_BUY:
		            divOpenPrice = (value - OpenPrice);
		            break;

		        case ORDER_TYPE_SELL:
		            divOpenPrice = (OpenPrice - value);
		            break;
		    }

		    double pipsDivOpenPrice = divOpenPrice / PipPoint;
		    return pipsDivOpenPrice;
		}

		double GetProfitPips()
		{
		    if (CloseTime > 0)
		    {
		        switch (Type)
		        {
		            case ORDER_TYPE_BUY:
		                {
		                    double pipettes = ClosePrice - OpenPrice;
		                    return pipettes / PipPoint;
		                }

		            case ORDER_TYPE_SELL:
		                {
		                    double pipettes = OpenPrice - ClosePrice;
		                    return pipettes / PipPoint;
		                }
		        }
		    }

		    return 0;
		}

		bool IsAlreadyProcessedByModule(string moduleCode, OrderCloseInfo* &closeInfos[])
		{
			for(int i = 0; i < ArraySize(closeInfos); i++)
			{
				if (closeInfos[i].ModuleCode == moduleCode
				&& closeInfos[i].Status == Old)
				{
				    return true;
				}
			}

			return false;
		}

		bool HasAValueAlreadyByModule(string moduleCode, OrderCloseInfo* &closeInfos[])
				{
				   for(int i = 0; i < ArraySize(closeInfos); i++)
				   {
				      if (closeInfos[i].ModuleCode == moduleCode
				      && !closeInfos[i].Status == Old)
				      {
				         return true;
				      }
				   }

				   return false;
				}

		void Paint()
		{
			if (IsDemoLiveOrVisualMode)
			{
		        PaintTPInfo();
		        PaintSLInfo();
			}
		}

		bool SetTPInfo(string moduleCode, double tpPrice, int percentage, SL_TP_DIRECTION direction)
		{
			uint result = SetCloseInfo(CloseInfosTP, moduleCode, tpPrice, percentage, direction);
			if (result != NoAction)
			{
				if (IsDemoLiveOrVisualMode && MustBeVisibleOnChart && !SendSlTpToBroker)
				{
					PaintTPInfo();
				}
				return true;
			}

			return false;
		}

		bool SetSLInfo(string moduleCode, double slPrice, int percentage, SL_TP_DIRECTION direction)
		{
			uint result = SetCloseInfo(CloseInfosSL, moduleCode, slPrice, percentage, direction);
			if (result != NoAction)
			{
				if (IsDemoLiveOrVisualMode && MustBeVisibleOnChart && !SendSlTpToBroker)
				{
					PaintSLInfo();
				}

				return true;
			}

			return false;
		}

		double GetClosestSL()
		{
		    if (StopLossManual != 0)
			{
				return StopLossManual;
			}

			double closestSL = 0;
			double currentDistance = 0;

			// If the old TP/ TP does't fully close the order, we'll evaluate the new info
			for (int cli = 0; cli < ArraySize(CloseInfosSL); cli++)
			{
				if (CloseInfosSL[cli].Status == Old)
				    continue;

		        double distance = MathAbs(CloseInfosSL[cli].Price - GetClosePrice());
				if (distance < currentDistance || closestSL == 0)
				{
				    closestSL = CloseInfosSL[cli].Price;
				    currentDistance = distance;
				}
			}
				    
			return closestSL;
		}

		double GetClosestTP()
		{
		    if (TakeProfitManual != 0)
			{
				return TakeProfitManual;
			}

			double closestTP = 0;
			double currentDistance = 0;

			// If the old TP/ TP does't fully close the order, we'll evaluate the new info
			for (int cli = 0; cli < ArraySize(CloseInfosTP); cli++)
			{
				if (CloseInfosTP[cli].Status == Old)
				    continue;
		        
		        double distance = MathAbs(CloseInfosTP[cli].Price - GetClosePrice());
				if (distance < currentDistance || closestTP == 0)
				{
				    closestTP = CloseInfosTP[cli].Price;
				    currentDistance = distance;
				}
			}

			return closestTP;
		}

		void SetCloseInfosToOld(bool setParentExecutingCloseInfosToOld = true)
		{
			for(int i = 0; i < ArraySize(CloseInfosSL); i++)
		    {
		        OrderCloseInfo* closeInfo = CloseInfosSL[i];
		        closeInfo.Status = Old;
		    }

		    for(int i = 0; i < ArraySize(CloseInfosTP); i++)
		    {
		        OrderCloseInfo* closeInfo = CloseInfosTP[i];
		        closeInfo.Status = Old;
		    }

		    if (setParentExecutingCloseInfosToOld)
		    {
		        if (ParentOrder == NULL)
		            return;

		        for(int j = 0; j < ArraySize(ParentOrder.CloseInfosSL); j++)
		        {
		            OrderCloseInfo* closeInfo = ParentOrder.CloseInfosSL[j];
		            if (closeInfo.Status == Executing)
		                closeInfo.Status = Old;
		        }

		        for(int j = 0; j < ArraySize(ParentOrder.CloseInfosTP); j++)
		        {
		            OrderCloseInfo* closeInfo = ParentOrder.CloseInfosTP[j];
		            if (closeInfo.Status == Executing) 
		                closeInfo.Status = Old;
		        }
		    }
		}

		bool RemoveSLInfo(string moduleCode)
		{
			// Remove value
			RemoveCloseInfo(CloseInfosSL, moduleCode);

			if (IsDemoLiveOrVisualMode)
			{
		   	    // Set line to 'highest' next value
		   	    double newValue = NULL;
		   	    for(int i = 0; i < ArraySize(CloseInfosSL); i++)
		   	    {
					if ((Type == ORDER_TYPE_BUY && (newValue == NULL || CloseInfosSL[i].Price > newValue))
						|| (Type == ORDER_TYPE_SELL && (newValue == NULL || CloseInfosSL[i].Price < newValue)))
					{
						newValue = CloseInfosSL[i].Price;
					}
		        }

		        if (newValue == NULL)
		        {
		            AnyChartObjectDelete(ChartID(), IntegerToString(Ticket) + "_SL");
		        }
		        else
		        {
		            HLineMove(ChartID(), IntegerToString(Ticket) + "_SL", newValue);
		        }
		    }
			return true;
		}

		bool RemoveTPInfo(string moduleCode)
		{
			// Remove value
			RemoveCloseInfo(CloseInfosTP, moduleCode);

			if (IsDemoLiveOrVisualMode)
			{
		   	    // Set line to 'lowest' next value
		   	    double newValue = NULL;
		   	    for(int i = 0; i < ArraySize(CloseInfosTP); i++)
		   	    {
					if ((Type == ORDER_TYPE_BUY && (newValue == NULL || CloseInfosTP[i].Price < newValue))
						|| (Type == ORDER_TYPE_SELL && (newValue == NULL || CloseInfosTP[i].Price > newValue)))
					{
						newValue = CloseInfosTP[i].Price;
					}
		        }

		        if (newValue == NULL)
		        {
		            AnyChartObjectDelete(ChartID(), IntegerToString(Ticket) + "_TP");
		        }
		        else
		        {
		            HLineMove(ChartID(), IntegerToString(Ticket) + "_TP", newValue);
		        }
		    }
			return true;
		}

		CRUD SetCloseInfo(OrderCloseInfo* &closeInfos[], string moduleCode, double price, int percentage, SL_TP_DIRECTION direction, CLOSE_INFO_STATUS status = New)
		{
			for(int i = 0; i < ArraySize(closeInfos); i++)
			{
				if (closeInfos[i].ModuleCode == moduleCode)
				{
		      		closeInfos[i].Price = price;
		            closeInfos[i].Direction = direction; // It's possible to transition from direction after hedging
		            closeInfos[i].Status = status;
		      		return Updated;
				}
			}

		    int newSize = ArraySize(closeInfos) + 1;
		    ArrayResize(closeInfos, newSize);
		    closeInfos[newSize-1] = new OrderCloseInfo();
		    closeInfos[newSize-1].Price = price;
		    closeInfos[newSize-1].Percentage = percentage;
		    closeInfos[newSize-1].ModuleCode = moduleCode;
		    closeInfos[newSize-1].Direction = direction;
		    closeInfos[newSize-1].Status = status;

		    return Created;
		}

		CRUD RemoveCloseInfo(OrderCloseInfo* &closeInfos[], string moduleCode)
		{
			int removedCount = 0;
			int arraySize = ArraySize(closeInfos);

			for(int i = 0; i<arraySize; i++)
			{
				if (closeInfos[i].ModuleCode == moduleCode)
				{
					removedCount++;

		            if (closeInfos[i] != NULL && CheckPointer(closeInfos[i]) == POINTER_DYNAMIC)
		                delete(closeInfos[i]);

					continue;
				}
		        closeInfos[i - removedCount] = closeInfos[i];
			}

			ArrayResize(closeInfos, arraySize - removedCount);
		    return Deleted;
		}

		void ~Order()
		{
			for (int i = 0; i < ArraySize(CloseInfosTP); i++)
			{
				if (CloseInfosTP[i] != NULL && CheckPointer(CloseInfosTP[i]) == POINTER_DYNAMIC)
					delete(CloseInfosTP[i]);
			}
			for (int i = 0; i < ArraySize(CloseInfosSL); i++)
			{
				if (CloseInfosSL[i] != NULL && CheckPointer(CloseInfosSL[i]) == POINTER_DYNAMIC)
					delete(CloseInfosSL[i]);
			}
         if (IsDemoLiveOrVisualMode && MustBeVisibleOnChart && !SendSlTpToBroker) // SL and TP must also be set during backtest
         {
            AnyChartObjectDelete(ChartID(), IntegerToString(Ticket) + "_TP");
            AnyChartObjectDelete(ChartID(), IntegerToString(Ticket) + "_SL");
         }

		}
	private:

    double GetClosePrice()
    {
	    if (ClosePrice > 1e-5)
	    {
		    return ClosePrice;
	    }
	    else if (Type == ORDER_TYPE_BUY)
	    {
		    return SymbolInfoDouble(SymbolCode, SYMBOL_BID);
	    }

        return SymbolInfoDouble(SymbolCode, SYMBOL_ASK);
    }

    double CalcVolumePartialClose(double orderVolume, int percentage)
    {
        return RoundVolume(orderVolume * ((double)percentage / 100));
    }

    double RoundVolume(double volume)
    {
        double  lotStep = MarketInfo_LibFunc(OrderSymbolTarget, MODE_LOTSTEP),
        minLot  = MarketInfo_LibFunc(OrderSymbolTarget, MODE_MINLOT);
        volume = MathRound(volume/lotStep) * lotStep;
        if (volume < minLot) volume = minLot;
        return volume;
    }

    void PaintSLInfo()
	{
        double closestSL = GetClosestSL();
        if (closestSL < 1e-13)
        {
            return;
        }

		double currentValue;
		if (ObjectGetDouble(ChartID(), IntegerToString(Ticket) + "_SL", OBJPROP_PRICE, 0, currentValue))
		{
            if (MathAbs(currentValue - closestSL) > 1e-13)
		        HLineMove(ChartID(), IntegerToString(Ticket) + "_SL", closestSL);
		}
		else
		{
		    HLineCreate(ChartID(), IntegerToString(Ticket) + "_SL", 0, closestSL, clrRed);
		}
	}

	void PaintTPInfo()
	{
        double closestTP = GetClosestTP();
        if (closestTP < 1e-13)
        {
            return;
        }   

		double currentValue;
		if (ObjectGetDouble(ChartID(), IntegerToString(Ticket) + "_TP", OBJPROP_PRICE, 0, currentValue))
		{
            if (MathAbs(currentValue - closestTP) > 1e-13)
	            HLineMove(ChartID(), IntegerToString(Ticket) + "_TP", closestTP);
	    }
	    else
		{
		    HLineCreate(ChartID(), IntegerToString(Ticket) + "_TP", 0, closestTP, clrGreen);
		}
	}


};

//
//  OrderCollection
//
class OrderCollection
{
    private:
        Order* _orders[];
        int _pointer;
        int _size;

    public:
        void OrderCollection()
        {
            _pointer = -1;
            _size = 0;
        }

        void ~OrderCollection()
        {
            for (int i = 0; i < ArraySize(_orders); i++)
            {
                delete(_orders[i]);
            }
        }

        void Add(Order* item)
        {
            _size = _size + 1;
            ArrayResize(_orders, _size, 8);

            _orders[(_size - 1)] = item;
        }

        Order* Remove(int index)
        {
            Order* removed = NULL;

            if (index >= 0 && index < _size)
            {
               removed = _orders[index];
               
               for (int i = index; i < (_size - 1); i++)
               {
                   _orders[i] = _orders[i + 1];
               }
   
               ArrayResize(_orders, ArraySize(_orders) - 1, 8);
               _size = _size - 1;
            }
            
            return removed;
        }

        Order* Get(int index)
        {
            if (index >= 0 && index < _size)
            {
                return _orders[index];
            }

            return NULL;
        }

        int Count()
        {
            return _size;
        }

        void Rewind()
        {
            _pointer = -1;
        }

        Order* Next()
        {
            _pointer++;
            if (_pointer == _size)
            {
                Rewind();
                return NULL;
            }

            return Current();
        }

        Order* Prev()
        {
            _pointer--;
            if (_pointer == -1)
            {
                return NULL;
            }

            return Current();
        }

        bool HasNext()
        {
            return (_pointer < (_size - 1));
        }

        Order* Current()
        {
            return _orders[_pointer];
        }

        int Key()
        {
            return _pointer;
        }
        
		int GetKeyByTicket(ulong ticket)
		{
		    int keyFound = -1;
		    for (int i = 0; i < ArraySize(_orders); i++)
		    {
		        if (_orders[i].Ticket == ticket)
		        {
		            keyFound = i;
		        }
		    }
		    return keyFound;
		}

};

//
//  OrderRepository
//
class OrderRepository
{
   private:
      static Order* getByTicket(ulong ticket)
      {
         bool orderSelected = OrderSelect(ticket);
         if (orderSelected) 
         {
            Order* order = new Order(false);
            OrderRepository::FetchSelected(order);
            return order;
         } 
         else 
         {
            return NULL;
         }
      }

      static datetime OrderCloseTimeMQL4(ulong ticket)
      {
         return (datetime)(HistoryOrderGetInteger(ticket, ORDER_TIME_DONE_MSC) / 1000);
      }
      
      static double OrderClosePriceMQL4(ulong ticket)
      {
         return HistoryOrderGetDouble(ticket, ORDER_PRICE_CURRENT);
      }
   
      static void FetchSelected(Order& order)
      {
         COrderInfo orderInfo;
         
         order.Ticket = orderInfo.Ticket();
         order.Type = orderInfo.OrderType();
         order.State = orderInfo.State();
         order.MagicNumber = orderInfo.Magic();
         order.Lots = orderInfo.VolumeInitial();
         order.OpenPrice = orderInfo.PriceOpen();
         order.StopLoss = orderInfo.StopLoss();
         order.TakeProfit = orderInfo.TakeProfit();
         order.Expiration = orderInfo.TimeExpiration();
         order.Comment = orderInfo.Comment();
         order.OpenTime = orderInfo.TimeSetup();
         order.CloseTime = OrderCloseTimeMQL4(order.Ticket);
         order.SymbolCode = orderInfo.Symbol();
         order.TradeVolume = orderInfo.VolumeInitial();
         
         CalculateAndSetCommision(order);
      }
      
   public:
      static OrderCollection* GetOpenOrders(int magic = NULL, int type = NULL, string symbolCode = NULL)
      {
         OrderCollection* orders = new OrderCollection();
         
         // Open orders by positions
         int total = PositionsTotal();
         for (int i = total - 1; i >= 0; i--)
         {
            ulong  position_ticket = PositionGetTicket(i);
            string position_symbol = PositionGetString(POSITION_SYMBOL);
            long  position_magicNumber = PositionGetInteger(POSITION_MAGIC);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
            ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            if (position_magicNumber == MagicNumber)
            {
               Order* order = new Order(false);
               order.Ticket = position_ticket;
               order.PositionId = position_ticket;
               if (positionType == POSITION_TYPE_BUY)
               {
                  order.Type = ORDER_TYPE_BUY;
               } else if (positionType == POSITION_TYPE_SELL)
               {
                  order.Type = ORDER_TYPE_SELL;
               }

               order.Lots = volume;
               order.TradeVolume = volume;
               order.OpenPrice = open_price;
               order.OpenTime = open_time;
               order.MagicNumber = position_magicNumber;
               order.SymbolCode = position_symbol;
               
               if ((magic == NULL || magic == order.MagicNumber)
                  && (type == NULL || type == order.Type)
                  && (symbolCode == NULL || symbolCode == order.SymbolCode)) 
               {
                  orders.Add(order);
               } 
               else 
               {
                  if (CheckPointer(order) == POINTER_DYNAMIC)
                  {
                      order.Ticket = -1;
                      delete(order);
                  }
               }
            }
         }   
         
         return orders;
      }
   
      static OrderCollection* GetOpenPendingOrders(int magic = NULL, int type = NULL, string symbolCode = NULL)
      {
         OrderCollection* pendingOrders = new OrderCollection();
         
         int totalOrders = OrdersTotal();
         for (int i = totalOrders - 1; i >= 0; i--)
         {
             ulong orderTicket = OrderGetTicket(i);
             Order* order = GetOpenOrder(orderTicket, magic, type, symbolCode);            
             if (order != NULL)
             {
               if (order.Type == ORDER_TYPE_BUY_LIMIT || order.Type == ORDER_TYPE_SELL_LIMIT ||
                  order.Type == ORDER_TYPE_BUY_STOP || order.Type == ORDER_TYPE_SELL_STOP)
               {
                  pendingOrders.Add(order);
               }
               else
               {
                  delete(order);
               }
             }
         }
         
         return pendingOrders;
      }
      
      static Order* GetOpenOrder(ulong orderTicket, int magic = NULL, int type = NULL, string symbolCode = NULL)
      {
         Order* order = NULL;
         
         if (OrderSelect(orderTicket))
         {
            order = FillOrder();
            
            if ((magic == NULL || magic == order.MagicNumber)
              && (type == NULL || type == order.Type)
              && (symbolCode == NULL || symbolCode == order.SymbolCode))
            {
               return order;
            }
            else
            {
               delete(order);
            }
         }
         
         return NULL;
      }
   
      static ulong ExecuteOpenOrder(Order* order)
      {
         ulong orderTicket = ULONG_MAX;

         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action         = IsPendingOrderType(order.Type) ? TRADE_ACTION_PENDING : TRADE_ACTION_DEAL;
         request.symbol         = OrderSymbolTarget;
         request.volume         = order.Lots;
         request.type           = order.Type;
         request.price          = IsPendingOrderType(order.Type) ? order.OpenPrice : order.Type == ORDER_TYPE_BUY ? Ask_LibFunc() : Bid_LibFunc();    // Using Ask/ Bid for non-pending orders because of slippage (orders gets tuck in open-loop without renewing price)
         request.deviation      = MaxDeviationSlippage;
         request.magic          = MagicNumber;
         
         if (SendSlTpToBroker)
         {
            double closestSL = order.GetClosestSL();
            if (closestSL != 0)
               request.sl = closestSL;
               
            double closestTP = order.GetClosestTP();
            if (closestTP != 0)
               request.tp = closestTP;
         }

         request.comment        = order.Comment;
         request.type_filling   = (ENUM_ORDER_TYPE_FILLING)OrderFillingType;

         if (order.Expiration != 0)
         {
            request.type_time      = ORDER_TIME_SPECIFIED;
            request.expiration     = order.Expiration;
         }
         
         ResetLastError();

         if(OrderSend(request, result))
         {
            if (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
            {
               orderTicket = result.order;
               
               order.Ticket = orderTicket;
               
               return orderTicket;
            }
            else
            {
               Print(StringFormat("OrderSend: retcode=%u", result.retcode));
            }
         }
         else
         {
            string additionalTip = "";
            if (order.Expiration != 0) // Expiry too short
            {
               additionalTip = GetErrorDescriptionTip(result.retcode);
            }
            HandleErrors(StringFormat("OrderSend: error %d: %s", GetLastError(), GetErrorDescription(result.retcode) + additionalTip));
         }
         
         return ULONG_MAX;
      }
   
      static bool ClosePendingOrder(Order* order)
      {
         CTrade m_trade;
         
         bool success = m_trade.OrderDelete(order.Ticket);
         
         return success;
      }

      static bool Modify(ulong ticket, double stopLoss = NULL, double takeProfit = NULL)
      {
         // ref to trade functions
         CTrade trade;
         /*
         // select the order
         Order* order = OrderRepository::getByTicket(ticket);
        
         double price = order.OpenPrice;
         stopLoss = (stopLoss == NULL)? order.StopLoss: stopLoss;
         takeProfit = (takeProfit == NULL)? order.TakeProfit: takeProfit;
         datetime expiration = order.Expiration;
         
         // check state, and moify according to current state
         bool result = false;
         if (order.State == ORDER_STATE_PLACED)
            result = trade.OrderModify(ticket, price, stopLoss, takeProfit, ORDER_TIME_SPECIFIED, expiration, 0);
         else if (order.State == ORDER_STATE_FILLED)
         */
         bool success = trade.PositionModify(ticket, stopLoss, takeProfit);
         
        //if (CheckPointer(order) == POINTER_DYNAMIC)
         //   delete(order);

         return success;
      }
      
      // This function is only used for hedging accounts, since it assumes the order ticket and the position ticket are the same for open orders.
      // For Netting accounts the reversed open order is used.
      static bool ClosePosition(Order* order)
      {
         CPositionInfo  m_position;
         CTrade         m_trade;
      
         bool foundPosition = false;
         for(int i = PositionsTotal() -1; i >= 0; i--)
         {
            if(m_position.SelectByIndex(i))
            {
               if(m_position.Ticket() == order.Ticket) // On a hedging account the open order ticket and the position ticket are the same number
               {
                  foundPosition = true;
                  uint returnCode = 0;

                  if (m_trade.PositionClosePartial(order.Ticket, order.Lots, MaxDeviationSlippage))
                  {
                     returnCode = m_trade.ResultRetcode();
                     if (returnCode == TRADE_RETCODE_DONE || returnCode == TRADE_RETCODE_PLACED)
                     {
                        ulong orderTicket = m_trade.ResultOrder();
                        order.Ticket = orderTicket; // the close order gets a new order ticket, so it must be updated

                        Print(StringFormat("Successfully created a close order (%d) by EA (%d). Awaiting execution.", orderTicket, MagicNumber));
                        return true;                     
                     }

                     Print(StringFormat("Placing close order failed, Return code: %d", returnCode));
                  }
               }
            }     
         }

         return false;
      }

	  static OrderCollection* GetLastClosedOrders(datetime startDatetime = NULL)
      {
           OrderCollection* lastClosedOrders = new OrderCollection();
           
           // First get all history positions
           long positionIds[];
           if (HistorySelect(0, TimeCurrent()))
           {
             for (int i = HistoryDealsTotal() - 1; i >= 0; i--)
             {
               ulong dealId = HistoryDealGetTicket(i);
               long magicNumber = HistoryDealGetInteger(dealId, DEAL_MAGIC);
               string symbol = HistoryDealGetString(dealId, DEAL_SYMBOL);
               
               if ((magicNumber != MagicNumber && magicNumber != 0) || symbol != OrderSymbolTarget) // manual closes (magicNumber 0) will count too. This can be removed once we create 'Close' buttons per chart.
                  continue;

               if (HistoryDealGetInteger(dealId, DEAL_ENTRY) == DEAL_ENTRY_OUT)
               {
                  datetime closetime = (datetime)HistoryDealGetInteger(dealId, DEAL_TIME);
                  if (startDatetime > closetime)
                  {
                     break;
                  }
                  
                  long positionId = HistoryDealGetInteger(dealId, DEAL_POSITION_ID);
                  
                  // Does not exist in the list yet
                  for (int pi = 0; pi < ArraySize(positionIds); pi++)
                  {
                     if (positionIds[pi] == positionId)
                        continue;
                  }
                  
                  int size = ArraySize(positionIds);
                  ArrayResize(positionIds, size + 1);
                  positionIds[size] = positionId;
                }   
             }
           }   
           
           for (int i = 0; i < ArraySize(positionIds); i++)
           {
              if (HistorySelectByPosition(positionIds[i]))
              {
                Order* order = new Order(false);
                double currentOutVolume = 0;
                for (int j = 0; j < HistoryDealsTotal(); j++)
                {
                  ulong ticket = HistoryDealGetTicket(j);
                  if (HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
                  {
                     datetime openTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                     double openPrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
                     double lots = HistoryDealGetDouble(ticket, DEAL_VOLUME);
                     
                     if (order.Ticket == 0)
                     {
                        order.Ticket = HistoryDealGetInteger(ticket, DEAL_ORDER); // Use first deal's order ticket
                        long dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);

                        if (dealType == DEAL_TYPE_BUY)
                        {
                           order.Type = ORDER_TYPE_BUY;
                        }
                        else if (dealType == DEAL_TYPE_SELL)
                        {
                           order.Type = ORDER_TYPE_SELL;
                        }
                        else
                        {
                           Alert("Unkown order.Type in GetLastClosedOrders");
                        }
                        order.OpenTime = openTime;
                        order.OpenPrice = openPrice;
                        order.Lots = lots;
                     }
                     else
                     {
                        // Additional deal to increase the position size or partial fills
                        double averagePrice = ((order.OpenPrice * order.Lots) + (openPrice * lots)) / (order.Lots + lots);
                        order.Lots = order.Lots + lots;
                        order.OpenPrice = averagePrice;
                     }
                  }
                  else if (HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
                  {
                     double dealLots = HistoryDealGetDouble(ticket, DEAL_VOLUME);
                     double dealClosePrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
                     
                     if (order.CloseTime == 0)
                     {
                        // First close deal
                        order.CloseTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                        order.ClosePrice = dealClosePrice;
                        
                        currentOutVolume = dealLots;
                     }
                     else
                     {
                        double averagePrice = ((order.ClosePrice * currentOutVolume) + (dealClosePrice * dealLots)) / (currentOutVolume + dealLots);
                        order.CloseTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME); // Update close time to the last deal
                        order.ClosePrice = averagePrice;
                        currentOutVolume += dealLots;
                     }
                  }
               }
   
               lastClosedOrders.Add(order);
            }
         }   
         
         return lastClosedOrders;
      }
   
      static bool OpenOrder(Order* order, bool isNettingCloseOrder = false) // Netting account orders are actually closed by opening an order in the opposite direction
      {
         double price = NULL;
         ulong ticketId = -1;

         double currentFreeMargin = AccountFreeMargin_LibFunc();
         double requiredMargin = 0; 

         if (IsBullishOrderType(order.Type))
         {
             if (UseValidateOrderMargin && !isNettingCloseOrder && !MarginRequired(ORDER_TYPE_BUY, order.Lots, requiredMargin))
             {
                UseValidateOrderMargin = false;
                HandleErrors("Couldn't calculate required margin for lot size calculation. Disabled automatic margin validation.");
             }
            
             if (UseValidateOrderMargin && currentFreeMargin < requiredMargin)
             {
                 HandleErrors("Not enough free margin to open buy order. Reduce lot size.");
                 return false;
             }
         }
         else if (IsBearishOrderType(order.Type))
         {
             if (UseValidateOrderMargin && !isNettingCloseOrder && !MarginRequired(ORDER_TYPE_SELL, order.Lots, requiredMargin))
             {
                UseValidateOrderMargin = false;
                HandleErrors("Couldn't calculate required margin for lot size calculation. Disabled automatic margin validation.");
             }
            
             if (UseValidateOrderMargin && currentFreeMargin < requiredMargin)
             {
                 HandleErrors("Not enough free margin to open sell order. Reduce lot size.");
                 return false;
             }
         }

         ticketId = ExecuteOpenOrder(order);
         
         bool success = ticketId != ULONG_MAX;
         if (success)
         {
            Print(StringFormat("Successfully opened an order (%d) by EA (%d)", ticketId, MagicNumber));
         }

         return success;
      }

      static void CalculateAndSetCommision(Order& order)
      {
         order.Commission = 0.0;
         order.CommissionInPips = 0.0;

         order.Commission = 2.0 * // roundtrip 
            CommissionAmountPerTrade + // fixed (not encountered yet)
            CommissionPercentagePerLot * order.Lots * UnitsOneLot + // percentage (cTrader)
            CommissionAmountPerLot * order.Lots;
             
         if (order.Lots > 1.0e-5 && order.Commission > 1.0e-5)
            order.CommissionInPips = order.Commission / (order.Lots * UnitsOneLot * PipPoint);
      }

    private:
      static Order* FillOrderHistory(int ticketId)
      {
         ulong  order_ticket = ticketId;
         string order_symbol = HistoryOrderGetString(ticketId, ORDER_SYMBOL);
         long   order_magicNumber = HistoryOrderGetInteger(ticketId, ORDER_MAGIC);
         double order_volume = HistoryOrderGetDouble(ticketId, ORDER_VOLUME_CURRENT);
         double order_price = HistoryOrderGetDouble(ticketId, ORDER_PRICE_OPEN);
         datetime order_time = (datetime)HistoryOrderGetInteger(ticketId, ORDER_TIME_SETUP);
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticketId, ORDER_TYPE);

         Order* order = new Order(true);
         order.Ticket = order_ticket;
         order.Type = orderType;
         order.Lots = order_volume;
         order.TradeVolume = order_volume;
         order.OpenPrice = order_price;
         order.OpenTime = order_time;
         order.MagicNumber = order_magicNumber;
         order.SymbolCode = order_symbol;
         
         return order;
      }
      
      static Order* FillOrder()
      {
         ulong  order_ticket = OrderGetInteger(ORDER_TICKET);
         string order_symbol = OrderGetString(ORDER_SYMBOL);
         long   order_magicNumber = OrderGetInteger(ORDER_MAGIC);
         double order_volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
         double order_price = OrderGetDouble(ORDER_PRICE_OPEN);
         datetime order_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

         Order* order = new Order(true);
         order.Ticket = order_ticket;
         order.Type = orderType;
         order.Lots = order_volume;
         order.TradeVolume = order_volume;
         order.OpenPrice = order_price;
         order.OpenTime = order_time;
         order.MagicNumber = order_magicNumber;
         order.SymbolCode = order_symbol;
         
         return order;
      } 
};

//
//  OrderGroupData
//
class OrderGroupData
{
	public:
		ulong OrderTicketIds[];

		void OrderGroupData()
		{
		}

		void OrderGroupData(OrderGroupData* ordergroupdata)
		{
		}

		void Add(ulong ticketId)
		        {
			        int size = ArraySize(OrderTicketIds);
			        ArrayResize(OrderTicketIds, size + 1);

			        OrderTicketIds[size] = ticketId;
		        }

		        void Remove(ulong ticketId)
		        {
		        int size = ArraySize(OrderTicketIds);

		        int counter = 0;
		        int counterFound = 0;
		        for (int i = 0; i < size; i++)
		        {
		   	        if (OrderTicketIds[i] == ticketId)
		   	        {
		   	            counterFound++;
		   	            continue;
		   	        }
		   	        else
		   	        {
		                OrderTicketIds[counter] = OrderTicketIds[i];
		                counter++;
		   	        }
		        }

		        if (counterFound > 0)
				        ArrayResize(OrderTicketIds, counter);
		        }

		void ~OrderGroupData()
		{
		}
};

//
//  OrderGroupHashMap
//
class OrderGroupHashEntry 
{
    public:
        string _key;
        OrderGroupData* _val;
        OrderGroupHashEntry *_next;

        OrderGroupHashEntry() 
        {
            _key=NULL;
            _val=NULL;
            _next=NULL;
        }

        OrderGroupHashEntry(string key, OrderGroupData *val) 
        {
            _key=key;
            _val=val;
            _next=NULL;
        }

        ~OrderGroupHashEntry() 
        {
            if (_val != NULL && CheckPointer(_val) == POINTER_DYNAMIC)
			    delete(_val);
        }
};

class OrderGroupHashMap 
{
    private:
        uint _hashSlots; 
        int _resizeThreshold;
        int _hashEntryCount;
        OrderGroupHashEntry* _buckets[];
   
        bool _adoptValues;
   
        void init(uint size, bool adoptValues)
        {
            _hashSlots = 0;
            _hashEntryCount = 0;
            _adoptValues = adoptValues;
   
            rehash(size);
        }

        uint hash(string s)
        {
            uchar c[];
            uint h = 0;
   
            if (s != NULL) 
            {
                h = 5381;
                int n = StringToCharArray(s,c);
                for(int i = 0 ; i < n ; i++) 
                {
                    h = ((h << 5 ) + h ) + c[i];
                }
            }
           
            return h % _hashSlots;
        }

        uint _foundIndex;
        OrderGroupHashEntry* _foundEntry;
        OrderGroupHashEntry* _foundPrev;
                             
        bool find(string keyName) 
        {
            bool found = false;
           
            _foundPrev = NULL;
            _foundIndex = hash(keyName);

            if (_foundIndex <= _hashSlots) 
            {
                for (OrderGroupHashEntry *e = _buckets[_foundIndex]; e != NULL ; e = e._next)  
                {
                    if (e._key == keyName) 
                    {
                        _foundEntry = e;
                        found=true;
                        break;
                    }
                   
                    _foundPrev = e;
                }
            }
   
            return found;
        }

        uint getSlots() 
        {
            return _hashSlots;
        }
   
        bool rehash(uint newSize) 
        {
            bool ret = false;
            OrderGroupHashEntry* oldTable[];
   
            uint oldSize = _hashSlots;
   
            if (newSize <= getSlots()) 
            {
                ret = false;
            } 
            else if (ArrayResize(_buckets,newSize) != newSize) 
            {
                ret = false;
            } 
            else if (ArrayResize(oldTable,oldSize) != oldSize) 
            {
                ret = false; 
            } 
            else 
            {
                uint i = 0;
                for(i = 0; i < oldSize; i++) oldTable[i] = _buckets[i];
                for(i = 0; i < newSize; i++) _buckets[i] = NULL;
   
                _hashSlots = newSize;
                _resizeThreshold = (int)_hashSlots / 4 * 3; 
   
                for (uint oldHashCode = 0; oldHashCode < oldSize; oldHashCode++) 
                {
                    OrderGroupHashEntry *next = NULL;
   
                    for (OrderGroupHashEntry *e = oldTable[oldHashCode]; e != NULL; e = next)  
                    {
                        next = e._next;
   
                        uint newHashCode = hash(e._key);
   
                        e._next = _buckets[newHashCode];
                        _buckets[newHashCode] = e;
                    }
   
                    oldTable[oldHashCode] = NULL;
                }
                ret = true;
            }
            return ret;
        }
       
    public:
        OrderGroupHashMap() 
        {
            init(13, false);
        }
   
        OrderGroupHashMap(bool adoptValues) 
        {
            init(13, adoptValues);
        }
   
        OrderGroupHashMap(int size) 
        {
            init(size, false);
        }
   
        OrderGroupHashMap(int size, bool adoptValues) 
        {
            init(size, adoptValues);
        }
   
        ~OrderGroupHashMap() 
        {
            for(uint i = 0; i < _hashSlots; i++) 
            {
                OrderGroupHashEntry *nextEntry = NULL;
                for (OrderGroupHashEntry *entry = _buckets[i] ; entry!= NULL ; entry = nextEntry) 
                {
                    nextEntry = entry._next;
   
                    if (_adoptValues && entry._val != NULL && CheckPointer(entry._val) == POINTER_DYNAMIC) 
                    {
                        delete entry._val;
                    }
                    delete entry;
                }
                _buckets[i] = NULL;
            }
        }
   
        bool ContainsKey(string keyName) 
        {
            return find(keyName);
        }
   
        OrderGroupData* Get(string keyName) 
        {
            OrderGroupData *obj = NULL;
   
            if (find(keyName)) 
            {
                obj = _foundEntry._val;
            } 

            return obj;
        }

        void GetAllData(OrderGroupData* &data[])
        {
            for(uint i = 0 ; i < _hashSlots ; i++) 
            {
                OrderGroupHashEntry *nextEntry = NULL;
                for (OrderGroupHashEntry *entry = _buckets[i]; entry != NULL ; entry = nextEntry) 
                {
                    if (entry._val != NULL)
                    {
                        int size = ArraySize(data);
                        ArrayResize(data, size + 1);
                
                        data[size] = entry._val;
                        nextEntry = entry._next;
                    }
                }
            }
        }


        OrderGroupData* Put(string keyName, OrderGroupData *obj) 
        {
            OrderGroupData *ret = NULL;
            
            if (find(keyName)) 
            {
                ret = _foundEntry._val;
   
                if (_adoptValues && _foundEntry._val != NULL && CheckPointer(_foundEntry._val) == POINTER_DYNAMIC ) 
                {
                    delete _foundEntry._val;
                }
   
                _foundEntry._val = obj;
   
            } 
            else 
            {
                OrderGroupHashEntry* e = new OrderGroupHashEntry(keyName,obj);
                OrderGroupHashEntry* first = _buckets[_foundIndex];
                e._next = first;
                _buckets[_foundIndex] = e;
                _hashEntryCount++;
   
                if (_hashEntryCount > _resizeThreshold) 
                {
                    rehash(_hashSlots/2*3); 
                }
            }
            return ret;
        }
   
        bool Delete(string keyName) 
        {
            bool found = false;
   
            if (find(keyName)) 
            {
                OrderGroupHashEntry *next = _foundEntry._next;
                if (_foundPrev != NULL) 
                {
                    _foundPrev._next = next;
                } 
                else 
                {
                    _buckets[_foundIndex] = next;
                }
   
                if (_adoptValues && _foundEntry._val != NULL&& CheckPointer(_foundEntry._val) == POINTER_DYNAMIC) 
                {
                    delete _foundEntry._val;
                }
               
                delete _foundEntry;
                _hashEntryCount--;
                found=true;
            }
            return found;
        }

        int DeleteKeys(const string& keys[])
        {
           int count = 0;
           
           // delete key if found
           for (int i=0; i<ArraySize(keys); i++)
           {
              if (Delete(keys[i]))
                 count++;
           }
           
           return count;
        }
        
        int DeleteKeysExcept(const string& keys[])
        {
           int index = 0, count = 0;
           
           string hashedKeys[];
           ArrayResize(hashedKeys, _hashEntryCount);
           
           for(uint i=0; i < _hashSlots; i++)
           {
              OrderGroupHashEntry *nextEntry = NULL;
              for (OrderGroupHashEntry *entry = _buckets[i] ; entry!= NULL ; entry = nextEntry) 
              {
                 nextEntry = entry._next;
            
                 if (entry._key != NULL) 
                 {
                    hashedKeys[index] = entry._key;
                    index++;
                 }
              }
           }
            
           // delete other keys if found
           for (int i=0; i < ArraySize(hashedKeys); i++)
           {
              bool keep = false;
              for (int j=0; j < ArraySize(keys); j++)
              {
                 if (hashedKeys[i] == keys[j])
                 {
                    keep = true;
                    break;
                 }
              }
              
              if (!keep)
              {
                 if (Delete(hashedKeys[i]))
                    count++;
              }
           }
           
           return count;
        }
};

//
//  Wallet
//
int LastOrderResults[];
int LastOrderResultsBuy[];
int LastOrderResultsSell[];

class Wallet
{
    private:
      int _openBuyOrderCount;
      int _openPendingBuyOrderCount;
      int _openSellOrderCount;
      int _openPendingSellOrderCount;
      ulong _closedOrderCount;
      int _lastOrderResultSize;
      int _lastOrderResultSizeBuy;
      int _lastOrderResultSizeSell;

      ENUM_TIMEFRAMES _lastOrderResultByTimeframe;
      datetime _lastBarStartTime;

      // Orders currently open
      ulong _brokerAddedOrderHistoryWaitingList[];
      // Queued open orders (local)
      OrderCollection* _queuedOpenOrders;
      // Queued close orders (local)
      OrderCollection* _queuedCloseOrders;

      // Orders currently open (at broker)
      OrderCollection* _openOrders;
      // Pending Orders currently open (at broker)
      OrderCollection* _openPendingOrders;
      // Orders currently open by Symbol + Type
      OrderGroupHashMap* _openOrdersSymbolType;
      // Orders currently open by Symbol
      OrderGroupHashMap* _openOrdersSymbol;
      // Most recent open order
      Order* _mostRecentOpenOrder;
      // Most recent closed order
      Order* _mostRecentClosedOrder;
      // Recent closed orders
      OrderCollection* _recentClosedOrders;

   public:            
      void Wallet()
      {
         _openBuyOrderCount = 0;
         _openSellOrderCount = 0;
         _closedOrderCount = 0;
         _lastOrderResultSize = 0;
         _lastOrderResultSizeBuy = 0;
         _lastOrderResultSizeSell = 0;
         _lastOrderResultByTimeframe = NULL;     
         _lastBarStartTime = NULL;
         
         ArrayInitialize(_brokerAddedOrderHistoryWaitingList, ULONG_MAX);
         _queuedOpenOrders = new OrderCollection();
         _queuedCloseOrders = new OrderCollection();

         _openOrders = new OrderCollection();
         _openPendingOrders = new OrderCollection();
         _mostRecentOpenOrder = NULL;
         _mostRecentClosedOrder = NULL;
         
         _recentClosedOrders = new OrderCollection();
         _openOrdersSymbolType = NULL;
         _openOrdersSymbol = NULL;
      }
      
      void ~Wallet()
      {
         delete(_queuedOpenOrders);
         delete(_queuedCloseOrders);
         delete(_recentClosedOrders);

         if (_openPendingOrders != NULL)
            delete(_openPendingOrders);

         if (_openOrders != NULL)
            delete(_openOrders);
            
         if (_mostRecentClosedOrder != NULL)            
            delete(_mostRecentClosedOrder);

         if (_openOrdersSymbolType != NULL)
            delete(_openOrdersSymbolType);
            
         if (_openOrdersSymbol != NULL)
            delete (_openOrdersSymbol);   
      }

      void HandleTick()
      {
         if (_lastOrderResultByTimeframe != NULL)
         {
             datetime newBarStartTime = iTime(_Symbol, _lastOrderResultByTimeframe, 0);     
             if (_lastBarStartTime == newBarStartTime)
	         {
	            return;
	         }
	         else
	         {
	            _lastBarStartTime = newBarStartTime;
	            
	            for (int i = 0; i < _recentClosedOrders.Count(); i++)
	            {
	                Order* order = _recentClosedOrders.Get(i);
	                if (CheckPointer(order) != POINTER_INVALID && CheckPointer(order) == POINTER_DYNAMIC)
                    {
                        delete(order);
                    }
                    _recentClosedOrders.Remove(i);
	            }
	            
	            PrintOrderChanges();
	         }
         }
      }

      void SetInitialLastOrderResultsSize(int size)
      {
         if (size > _lastOrderResultSize)
         {
            ArrayResize(LastOrderResults, size);
            ArrayInitialize(LastOrderResults, 1);
            _lastOrderResultSize = size;
         }

         if (size > _lastOrderResultSizeBuy)
         {
            ArrayResize(LastOrderResultsBuy, size);
            ArrayInitialize(LastOrderResultsBuy, 1);
            _lastOrderResultSizeBuy = size;
         }
         
         if (size > _lastOrderResultSizeSell)
         {
            ArrayResize(LastOrderResultsSell, size);
            ArrayInitialize(LastOrderResultsSell, 1);
            _lastOrderResultSizeSell = size;
         }
      }

      void SetLastClosedOrdersByTimeframe(ENUM_TIMEFRAMES timeframe)
      {
         if (_lastOrderResultByTimeframe != NULL && timeframe <= _lastOrderResultByTimeframe)
         {
            return;
         }

         _lastOrderResultByTimeframe = timeframe;
         _lastBarStartTime = iTime(_Symbol, _lastOrderResultByTimeframe, 0);
      }
      
      OrderCollection* GetRecentClosedOrders()
      {
         return _recentClosedOrders;
      }

      void ActivateOrderGroups(ORDER_GROUP_TYPE &groupTypes[])
      {
         for (int i = 0; i < ArrayRange(groupTypes,0); i++)
         {
            if (groupTypes[i] == SymbolOrderType && _openOrdersSymbolType == NULL)
            {
               _openOrdersSymbolType = new OrderGroupHashMap();
            }
            else if (groupTypes[i] == SymbolCode && _openOrdersSymbol == NULL)
            {
               _openOrdersSymbol = new OrderGroupHashMap();
            }
         }
      }
      
      OrderCollection* GetOpenOrders()
      {
         if (_openOrders == NULL)
            LoadOrdersFromBroker();
            
         return _openOrders;
      }

      OrderCollection* GetOpenPendingOrders()
      {
         if (_openPendingOrders == NULL)
            LoadPendingOrdersFromBroker();
            
         return _openPendingOrders;
      }

      Order* GetOpenOrder(ulong ticketId)
      {
         int index = _openOrders.GetKeyByTicket(ticketId);
         if (index == -1)
         {
            return NULL;
         }
         
         return _openOrders.Get(index);
      }
      
      OrderGroupData* GetOpenOrdersByGroupType(ORDER_GROUP_TYPE groupType, Order* order)
      {
         if (groupType == SymbolOrderType)
         {
            string key = GetOrderGroupSymbolOrderTypeKey(order);
            return _openOrdersSymbolType.Get(key);
         }
         else if (groupType == SymbolCode)
         {
            string key = GetOrderGroupSymbolKey(order);
            return _openOrdersSymbol.Get(key);
         }
         
         return NULL;
      }

      void AddTerminalAddedOrderDataWaitingList(ulong ticketId)
      {
         ArrayFunctions::Add(ticketId, _brokerAddedOrderHistoryWaitingList);
      }
      
      void RemoveBrokerAddedOrderHistoryWaitingList(ulong ticketId)
      {
         ArrayFunctions::Remove(ticketId, _brokerAddedOrderHistoryWaitingList);
      }
      
      bool IsTicketInHistoryWaitingList(ulong ticketId)
      {
         return ArrayFunctions::Contains(ticketId, _brokerAddedOrderHistoryWaitingList);
      }

      OrderCollection* GetQueuedOpenOrders()
      {
         return _queuedOpenOrders;
      }
      
      OrderCollection* GetQueuedCloseOrders()
      {
         return _queuedCloseOrders;
      }

      int GetPendingPartialCloseOrderCount()
      {
         int count = 0;
         for (int i = _queuedCloseOrders.Count()-1; i >= 0; i--)
         {
            if (_queuedCloseOrders.Get(i).ParentOrder != NULL)
            {
               count++;
            }
         }
         return count;
      }

	  void ResetQueuedOrders()
      {
         delete(_queuedOpenOrders);
         delete(_queuedCloseOrders);

         _queuedOpenOrders = new OrderCollection();
         _queuedCloseOrders = new OrderCollection();
         
         Print("Wallet has " + IntegerToString(_queuedOpenOrders.Count()) + " queued open orders now.");
         Print("Wallet has " + IntegerToString(_queuedCloseOrders.Count()) + " queued close orders now.");
      }

      bool AreOrdersBeingOpened()
      {
         for (int i = _queuedOpenOrders.Count()-1; i >= 0; i--)
         {
            if (_queuedOpenOrders.Get(i).IsAwaitingDealExecution)
            {
               return true;
            }
         }
         return false;
      }
      
      bool AreOrdersBeingClosed()
      {
         for (int i = _queuedCloseOrders.Count()-1; i >= 0; i--)
         {
            if (_queuedCloseOrders.Get(i).IsAwaitingDealExecution)
            {
               return true;
            }
         }
         return false;
      }

      void ResetOpenPendingOrders()
      {
         _openPendingBuyOrderCount = 0;
         _openPendingSellOrderCount = 0;

         if (_openPendingOrders != NULL)
         {
            delete(_openPendingOrders);
            _openPendingOrders = new OrderCollection();
         }
      }

      void ResetOpenOrders()
      {
         _openBuyOrderCount = 0;
         _openSellOrderCount = 0;

         if (_openOrders != NULL)
         {
            delete(_openOrders);
            _openOrders = new OrderCollection();
         }
         
         if (_openOrdersSymbol != NULL)
         {
            delete(_openOrdersSymbol);
            _openOrdersSymbol = new OrderGroupHashMap();
         }
         
         if (_openOrdersSymbolType != NULL)
         {
            delete(_openOrdersSymbolType);
            _openOrdersSymbolType = new OrderGroupHashMap();
         }
      }
      
      Order* GetMostRecentOpenOrder()
      {
         return _mostRecentOpenOrder != NULL && CheckPointer(_mostRecentOpenOrder) != POINTER_INVALID && CheckPointer(_mostRecentOpenOrder) == POINTER_DYNAMIC ? _mostRecentOpenOrder : NULL;
      }

      Order* GetNewestOpenOrder(int orderType = -1) // You can't use ENUM_ORDER_TYPE type == NULL because NULL == 0 (which is also the value of the enum) is true
      {
         ENUM_ORDER_TYPE type = -1;
      
         if (orderType != -1)
            type = (ENUM_ORDER_TYPE)orderType;

         Order* mostRecentOpenOrder = GetMostRecentOpenOrder();
         if (mostRecentOpenOrder != NULL && (orderType == -1 || mostRecentOpenOrder.Type == type)) // fast search
         {
            return mostRecentOpenOrder;
         }

         OrderCollection* openOrders = GetOpenOrders();  // slow search
         for (int i = openOrders.Count() - 1; i >= 0; i--)
         {
            Order* order = openOrders.Get(i);
            if (orderType == -1 || order.Type == type)
            {
               return order;
            }
         }

         OrderCollection* queuedCloseOrders = GetQueuedCloseOrders();  // slow search
         for (int i = queuedCloseOrders.Count()-1; i >= 0; i--)
         {
            Order* order = queuedCloseOrders.Get(i);
            if (orderType == -1 || order.Type == type)
            {
               return order;
            }
         }
            
         return NULL;
      }
   
      Order* GetOldestOpenOrder(int orderType = -1)  // You can't use ENUM_ORDER_TYPE type == NULL because NULL == 0 (which is also the value of the enum) is true
      {
         ENUM_ORDER_TYPE type = -1;
      
         if (orderType != -1)
            type = (ENUM_ORDER_TYPE)orderType;

         OrderCollection* openOrders = GetOpenOrders(); // slow search
         for (int i = 0; i < openOrders.Count(); i++)
         {
            Order* order = openOrders.Get(i);
            if (orderType == -1 || order.Type == type)
            {
               return order;
            }
         }
         
         OrderCollection* queuedCloseOrders = GetQueuedCloseOrders();  // slow search
         for (int i = 0; i < queuedCloseOrders.Count(); i++)
         {
            Order* order = queuedCloseOrders.Get(i);
            if (orderType == -1 || order.Type == type)
            {
               return order;
            }
         }
            
         return NULL;
      }
   
      double GetHighestOpenPriceOpenOrder(int orderType = -1)
      {
         ENUM_ORDER_TYPE type = -1;
      
         if (orderType != -1)
            type = (ENUM_ORDER_TYPE)orderType;

         double result = 0;
         
         OrderCollection* openOrders = GetOpenOrders();
         for (int i = openOrders.Count() - 1; i >= 0; i--)
         {
            Order* order = openOrders.Get(i);
            if (order.OpenPrice > result && (orderType == -1 || order.Type == type))
               result = order.OpenPrice;
         }
            
         // To keep the interface consistent we return EMPTY_Value if there was no open price
         return result == 0 ? EMPTY_VALUE : result;
      }
      
      double GetLowestOpenPriceOpenOrder(int orderType = -1)
      {
         ENUM_ORDER_TYPE type = -1;
      
         if (orderType != -1)
            type = (ENUM_ORDER_TYPE)orderType;

         double result = EMPTY_VALUE;
         
         OrderCollection* openOrders = GetOpenOrders();
         for (int i = openOrders.Count() - 1; i >= 0; i--)
         {
            Order* order = openOrders.Get(i);
            if (order.OpenPrice < result && (orderType == -1 || order.Type == type))
               result = order.OpenPrice;
         }
            
         return result;
      }

      double GetTotalVolume(OrderCollection* orderCollection)
      {
         double volume = 0;
         for (int i = 0; i < orderCollection.Count(); i++)
         {
            Order* order = orderCollection.Get(i); // Could be removed asynchronously
            if (order != NULL && CheckPointer(order) != POINTER_INVALID)
            {
               volume += orderCollection.Get(i).Lots;
            }
         }
         
         return volume;
      }

      Order* GetMostRecentClosedOrder()
      {
         return _mostRecentClosedOrder != NULL && CheckPointer(_mostRecentClosedOrder) != POINTER_INVALID && CheckPointer(_mostRecentClosedOrder) == POINTER_DYNAMIC ? _mostRecentClosedOrder : NULL;
      }

      Order* GetLastClosedOrder(int orderType = -1) // You can't use ENUM_ORDER_TYPE type == NULL because NULL == 0 (which is also the value of the enum) is true
      {
         ENUM_ORDER_TYPE type = -1;
      
         if (orderType != -1)
            type = (ENUM_ORDER_TYPE)orderType;

         Order* mostRecentClosedOrder = GetMostRecentClosedOrder();
         if (mostRecentClosedOrder != NULL && (orderType == -1 || mostRecentClosedOrder.Type == type)) // fast search
         {
            return mostRecentClosedOrder;
         }

         OrderCollection* closedOrders = GetRecentClosedOrders();  // slow search
         for (int i = closedOrders.Count() - 1; i >= 0; i--)
         {
            Order* order = closedOrders.Get(i);
            if (orderType == -1 || order.Type == type)
            {
               return order;
            }
         }

         return NULL;
      }

      double GetOpenOrderVolume(int orderType = -1)
      {
         ENUM_ORDER_TYPE type = -1;
      
         if (orderType != -1)
            type = (ENUM_ORDER_TYPE)orderType;

         double result = EMPTY_VALUE;
         
         OrderCollection* openOrders = GetOpenOrders();
         for (int i = openOrders.Count() - 1; i >= 0; i--)
         {
            Order* order = openOrders.Get(i);
            if (orderType == -1 || order.Type == type)
               result += order.Lots;
         }
            
         return result;
      }

      void LoadOrdersFromBroker()
      {
          OrderCollection* openBrokerOrders = OrderRepository::GetOpenOrders(MagicNumber, NULL, OrderSymbolTarget);
          for(int i = 0; i < openBrokerOrders.Count(); i++)
          {
              Order* brokerOrder = openBrokerOrders.Get(i);
              Order* openOrder = AddOrderToOpenOrderCollections(brokerOrder);
          }

          // Check if manual closed order is maybe the latest opened or closed order
          OrderCollection* lastClosedBrokerOrders = OrderRepository::GetLastClosedOrders(_lastBarStartTime);
          
          delete(_recentClosedOrders);
          _recentClosedOrders = new OrderCollection();    

          for(int i = 0; i < lastClosedBrokerOrders.Count(); i++)
          {
              Order* closedBrokerOrder = lastClosedBrokerOrders.Get(i);

              _recentClosedOrders.Add(new Order(closedBrokerOrder, true));
              SetPotentialMostRecentOpenOrClosedOrder(new Order(closedBrokerOrder, true));
          }

          delete(lastClosedBrokerOrders);
          delete(openBrokerOrders);

          Print("Wallet has " + IntegerToString(GetOpenOrderCount()) + " open orders now.");
      }

      void LoadPendingOrdersFromBroker()
      {
          OrderCollection* openBrokerPendingOrders = OrderRepository::GetOpenPendingOrders(MagicNumber, NULL, OrderSymbolTarget);
          for(int i = 0; i < openBrokerPendingOrders.Count(); i++)
          {
              Order* brokerOrder = openBrokerPendingOrders.Get(i);
              Order* openOrder = AddOrderToOpenPendingOrderCollections(brokerOrder);

              CountAddedOpenOrder(openOrder);
          }

          delete(openBrokerPendingOrders);

          Print("Wallet has " + IntegerToString(GetOpenPendingOrderCount()) + " pending orders now.");
      }

      void AddManualOpenOrder(Order* justOpenedOrder)
      {
         AddOrderToOpenOrderCollections(justOpenedOrder);

         delete(justOpenedOrder);
      }

      void AddManualOpenPendingOrder(Order* justOpenedPendingOrder)
      {
         AddOrderToOpenPendingOrderCollections(justOpenedPendingOrder);
         CountAddedOpenOrder(justOpenedPendingOrder);

         delete(justOpenedPendingOrder);
      }

      void MoveQueuedOpenOrderToOpenOrders(Order* justOpenedOrder)
      {
         int key = _queuedOpenOrders.GetKeyByTicket(justOpenedOrder.Ticket);
         if (key != -1)
         {
            AddOrderToOpenOrderCollections(justOpenedOrder);

            _queuedOpenOrders.Remove(key);

            delete(justOpenedOrder);
         }
         else
         {
            Alert("Couldn't move queued open order to opened orders for ticketid: " + IntegerToString(justOpenedOrder.Ticket));
         }
      }

      void MoveQueuedOpenOrderToOpenPendingOrders(Order* justOpenedPendingOrder)
      {
         int key = _queuedOpenOrders.GetKeyByTicket(justOpenedPendingOrder.Ticket);
         if (key != -1)
         {
            AddOrderToOpenPendingOrderCollections(justOpenedPendingOrder);
            CountAddedOpenOrder(justOpenedPendingOrder);
            
            _queuedOpenOrders.Remove(key);
            
            delete(justOpenedPendingOrder);
         }
         else
         {
            Alert("Couldn't move pending open order to opened orders for ticketid: " + IntegerToString(justOpenedPendingOrder.Ticket));
         }
      }

      void MoveOpenPendingOrderToOpenOrders(Order* openPendingOrder)
      {
         int key = _openPendingOrders.GetKeyByTicket(openPendingOrder.Ticket);
         if (key != -1)
         {
            _openPendingOrders.Remove(key);
            CountRemovedOpenOrder(openPendingOrder);
            
            openPendingOrder.TransformToOpened();
            
            _mostRecentOpenOrder = AddOrderToOpenOrderCollections(openPendingOrder);
            
            delete(openPendingOrder);
         }
         else
         {
            Alert("Couldn't move open pending order to opened orders for ticketid: " + IntegerToString(openPendingOrder.Ticket));
         }
      }

      void RemoveOpenPendingOrder(Order* openPendingOrder)
      {
         int key = _openPendingOrders.GetKeyByTicket(openPendingOrder.Ticket);
         if (key != -1)
         {
            _openPendingOrders.Remove(key);
            CountRemovedOpenOrder(openPendingOrder);
            
            delete(openPendingOrder);
         }
         else
         {
            Alert("Couldn't move open pending order to opened orders for ticketid: " + IntegerToString(openPendingOrder.Ticket));
         }
      }
      
      Order* MoveQueuedCloseOrderToPendingOpenOrders(Order* queuedCloseOrder)
      {
         Order* pendingOrder = NULL;
         
         int key = _queuedCloseOrders.GetKeyByTicket(queuedCloseOrder.Ticket);
         if (key != -1)
         {
            pendingOrder = AddOrderToOpenPendingOrderCollections(queuedCloseOrder);
            CountAddedOpenOrder(queuedCloseOrder);

            _queuedCloseOrders.Remove(key);
            delete(queuedCloseOrder);
         }
         else
         {
            Alert("Couldn't move queued close order to pending open orders for ticketid: " + IntegerToString(queuedCloseOrder.Ticket));
         }
         
         return pendingOrder;
      }
      
      void RemoveQueuedClosePendingOrder(Order* queuedClosePendingOrder)
      {
         int key = _queuedCloseOrders.GetKeyByTicket(queuedClosePendingOrder.Ticket);
         if (key != -1)
         {
            _queuedCloseOrders.Remove(key);
            
            delete(queuedClosePendingOrder);
         }
         else
         {
            Alert("Couldn't delete open pending order for ticketid: " + IntegerToString(queuedClosePendingOrder.Ticket));
         }
      }

      bool CancelQueuedOpenOrder(Order* justOpenedOrder)
      {
         int key = _queuedOpenOrders.GetKeyByTicket(justOpenedOrder.Ticket);
         if (key != -1)
         {
            delete(justOpenedOrder);
            _queuedOpenOrders.Remove(key);
         }
         else
         {
            Alert("Couldn't cancel queued open order for ticketid: " + IntegerToString(justOpenedOrder.Ticket));
         }
        
         return key != -1;
      }

      void SetAllOpenOrdersToQueuedClose()
      {
         for (int i = _openOrders.Count() - 1; i >= 0; i--)
         {
            Order* order = _openOrders.Get(i);
            MoveOpenOrderToQueuedCloseOrders(order);
         }
      }
      
      bool MoveOpenPendingOrderToQueuedClose(Order* orderToClose)
      {
         bool success = MoveOpenPendingOrderToQueuedCloseOrders(orderToClose);
         if (success)
         {
            return true;
         }
      
         Alert("Couldn't move open pending order to queued close orders for ticketid: " + IntegerToString(orderToClose.Ticket));
        
         return false;
      }

      bool SetOpenOrderToAwaitingClose(Order* orderToClose, OrderCloseInfo* orderCloseInfo = NULL)
      {
         bool success = MoveOpenOrderToQueuedCloseOrders(orderToClose, orderCloseInfo);
         if (success)
         {
            return true;
         }
      
         Alert("Couldn't move open order to queued close orders for ticketid: " + IntegerToString(orderToClose.Ticket));
        
         return false;
      }

      bool AddQueuedCloseOrder(Order* orderToClose)
      {
         _queuedCloseOrders.Add(new Order(orderToClose, false));
         
         if (CheckPointer(orderToClose) != POINTER_INVALID
            && CheckPointer(orderToClose) == POINTER_DYNAMIC)
            delete(orderToClose);
         
         return true;
      }

      // This scenario should only happen when the order is closed externally (in the terminal by either the broker or the user)
      bool SetOpenOrderToClosed(Order* justClosedOrder)
      {
         if (RemoveOrderFromOpenOrderCollections(justClosedOrder))
         {
            CountRemovedOpenOrder(justClosedOrder);
            
            SetOrderToClosed(justClosedOrder);
            
            delete(justClosedOrder);
            
            return true;
         }
         
         return false;
      }
      
      bool SetAwaitingCloseOrderToClosed(Order* justClosedOrder)
      {
         int key = _queuedCloseOrders.GetKeyByTicket(justClosedOrder.Ticket);
         if (key != -1)
         {
            if (!IsPendingOrderType(justClosedOrder.Type))
               SetOrderToClosed(justClosedOrder);
            
            _queuedCloseOrders.Remove(key);
            delete(justClosedOrder);

            return true;
         }
         
         return false;
      }
      
      int GetOpenOrderCount()
      {
         return _openBuyOrderCount + _openSellOrderCount;
      }
      
      int GetOpenPendingOrderCount()
      {
         return _openPendingBuyOrderCount + _openPendingSellOrderCount;
      }

      int GetOpenBuyOrderCount()
      {
         return _openBuyOrderCount;
      }
      
      int GetOpenPendingBuyOrderCount()
      {
         return _openPendingBuyOrderCount;
      }
      
      int GetOpenSellOrderCount()
      {
         return _openSellOrderCount;
      }
      
      int GetOpenPendingSellOrderCount()
      {
         return _openPendingSellOrderCount;
      }
      
      ulong GetClosedOrderCount()
      {
         return _closedOrderCount;
      }

      void PrintOrderChanges()
      {
         if (DisplayOrderInfo && IsDemoLiveOrVisualMode)
         {
            string comment = "\n     ------------------------------------------------------------";
            comment += "\n      :: Queued open orders: " + IntegerToString(_queuedOpenOrders.Count());
            comment += "\n      :: Open pending orders: " + IntegerToString(_openPendingBuyOrderCount) + " (Buy), " + IntegerToString(_openPendingSellOrderCount) + " (Sell)";
            comment += "\n      :: Open orders: " + IntegerToString(_openBuyOrderCount) + " (Buy), " + IntegerToString(_openSellOrderCount) + " (Sell)";
            comment += "\n      :: Queued close orders: " + IntegerToString(_queuedCloseOrders.Count());
            comment += "\n      :: Recently closed orders: " + IntegerToString(_recentClosedOrders.Count());
            OrderInfoComment = comment;
         }
      }

    private:
      Order* AddOrderToOpenOrderCollections(Order* order)
      {
         Order* newOpenOrder = new Order(order, true);
         _openOrders.Add(newOpenOrder);
         
         if (IsSymbolOrderTypeOrderGroupActivated())
         {
            string key = GetOrderGroupSymbolOrderTypeKey(order);
            OrderGroupData *orderGroupData = _openOrdersSymbolType.Get(key);
            if (orderGroupData == NULL)
            {
               orderGroupData = new OrderGroupData();
            }
             
            orderGroupData.Add(newOpenOrder.Ticket);
             
            _openOrdersSymbolType.Put(key, orderGroupData);
         }
         if (IsSymbolOrderGroupActivated())
         {
            string key = GetOrderGroupSymbolKey(order);
            OrderGroupData *orderGroupData = _openOrdersSymbol.Get(key);
            if (orderGroupData == NULL)
            {
               orderGroupData = new OrderGroupData();
            }
             
            orderGroupData.Add(newOpenOrder.Ticket);
             
            _openOrdersSymbol.Put(key, orderGroupData);
         }

         // Check if order is latest opened or closed order
         SetPotentialMostRecentOpenOrClosedOrder(newOpenOrder);

         CountAddedOpenOrder(newOpenOrder);

         return newOpenOrder;
      }

      Order* AddOrderToOpenPendingOrderCollections(Order* order)
      {
         Order* newOpenOrder = new Order(order, true);
         _openPendingOrders.Add(newOpenOrder);

         return newOpenOrder;
      }
      
      bool RemoveOrderFromOpenPendingOrderCollections(Order* order)
      {
         int key = GetOpenPendingOrders().GetKeyByTicket(order.Ticket);
         if (key != -1)
         {        
            GetOpenPendingOrders().Remove(key);
         }
         
         return key != -1;
      }

      void SetOrderToClosed(Order* justClosedOrder)
      {
         if (_lastOrderResultSize > 0)
         {
            for (int i = ArraySize(LastOrderResults)-1; i > 0; i--)
            {
                LastOrderResults[i] = LastOrderResults[i-1];
            }
            LastOrderResults[0] = justClosedOrder.CalculateProfitPips() > 0 ? 1 : 0;
         }

         if (justClosedOrder.Type == ORDER_TYPE_BUY && _lastOrderResultSizeBuy > 0)
         {
            for (int i = ArraySize(LastOrderResultsBuy)-1; i > 0; i--)
            {
                LastOrderResultsBuy[i] = LastOrderResultsBuy[i-1];
            }
            LastOrderResultsBuy[0] = justClosedOrder.CalculateProfitPips() > 0 ? 1 : 0;
         }
         else if (justClosedOrder.Type == ORDER_TYPE_SELL && _lastOrderResultSizeSell > 0)
         {
            for (int i = ArraySize(LastOrderResultsSell)-1; i > 0; i--)
            {
                LastOrderResultsSell[i] = LastOrderResultsSell[i-1];
            }
            LastOrderResultsSell[0] = justClosedOrder.CalculateProfitPips() > 0 ? 1 : 0;
         }

         if (GetMostRecentClosedOrder() != NULL)
         {
             delete(_mostRecentClosedOrder);
         }

         _mostRecentClosedOrder = new Order(justClosedOrder, false);
         _recentClosedOrders.Add(new Order(justClosedOrder, true));
         
         _closedOrderCount++;
      }
      
      bool RemoveOrderFromOpenOrderCollections(Order* order)
      {
         int key = GetOpenOrders().GetKeyByTicket(order.Ticket);
         if (key != -1)
         {        
            GetOpenOrders().Remove(key);
   
            // remove orders from buckets
            if (_openOrdersSymbolType != NULL)
            {
               string symbolOrderTypeKey = GetOrderGroupSymbolOrderTypeKey(order);
               OrderGroupData* symbolOrderTypeGroupData = _openOrdersSymbolType.Get(symbolOrderTypeKey);
               symbolOrderTypeGroupData.Remove(order.Ticket);
            }
            if (_openOrdersSymbol != NULL)
            {
               string symbolKey = GetOrderGroupSymbolKey(order);
               OrderGroupData* symbolGroupData = _openOrdersSymbol.Get(symbolKey);
               symbolGroupData.Remove(order.Ticket);
            }
         }
         
         return key != -1;
      }

      void SetMostRecentOpenOrder(Order* order)
      {
         _mostRecentOpenOrder = order;
      }

      void SetPotentialMostRecentOpenOrClosedOrder(Order* order)
      {
         if (order.CloseTime == 0)
         {
            // Open order
            if (GetMostRecentOpenOrder() == NULL || _mostRecentOpenOrder.OpenTime < order.OpenTime)
            {
               _mostRecentOpenOrder = order;
            }
         }
         else if (GetMostRecentClosedOrder() == NULL || _mostRecentClosedOrder.CloseTime < order.CloseTime)
         {
            if (CheckPointer(_mostRecentClosedOrder) != POINTER_INVALID
                && CheckPointer(_mostRecentClosedOrder) == POINTER_DYNAMIC)
                delete(_mostRecentClosedOrder);

            _mostRecentClosedOrder = order;
         }
         else
         {
            delete(order);
         }
      }

      bool MoveOpenPendingOrderToQueuedCloseOrders(Order* orderToClose)
      {
         if (RemoveOrderFromOpenPendingOrderCollections(orderToClose))
         {
            CountRemovedOpenOrder(orderToClose);

            _queuedCloseOrders.Add(new Order(orderToClose, false));

            if (CheckPointer(orderToClose) != POINTER_INVALID
               && CheckPointer(orderToClose) == POINTER_DYNAMIC)
               delete(orderToClose);
            
            return true;
         }
        
         return false;
      }
      
      bool MoveOpenOrderToQueuedCloseOrders(Order* orderToClose, OrderCloseInfo* orderCloseInfo = NULL)
      {
         if (RemoveOrderFromOpenOrderCollections(orderToClose))
         {
            CountRemovedOpenOrder(orderToClose);

            if (orderCloseInfo != NULL && CheckPointer(orderCloseInfo) == POINTER_DYNAMIC)
            {
               orderCloseInfo.Status = Executing;
            }

            _queuedCloseOrders.Add(new Order(orderToClose, false));
            
            if (GetMostRecentOpenOrder() != NULL && orderToClose.OpenTime == _mostRecentOpenOrder.OpenTime)
            {
               Order* newMostRecentOpenOrder = GetLastOpenOrder();
               if (newMostRecentOpenOrder != NULL)
               {
                  SetMostRecentOpenOrder(newMostRecentOpenOrder);
               }
               else
               {
                  _mostRecentOpenOrder = NULL;
               }
            }

            if (CheckPointer(orderToClose) != POINTER_INVALID
               && CheckPointer(orderToClose) == POINTER_DYNAMIC)
               delete(orderToClose);
            
            return true;
         }
        
         return false;
      }

      Order* GetLastOpenOrder()
      {
         Order* order = NULL;
         for (int i = _openOrders.Count()-1; i >= 0; i--)
         {
            return _openOrders.Get(i);
         }
         return NULL;
      }
      
      string GetOrderGroupSymbolOrderTypeKey(Order* order)
      {
         return order.SymbolCode + IntegerToString(order.Type);
      }
      
      string GetOrderGroupSymbolKey(Order* order)
      {
         return order.SymbolCode;
      }
      
      bool IsSymbolOrderTypeOrderGroupActivated()
      {
         return _openOrdersSymbolType != NULL;
      }
      
      bool IsSymbolOrderGroupActivated()
      {
         return _openOrdersSymbol != NULL;
      }
      	
      void CountAddedOpenOrder(Order* order)
      {
         if (order.Type == ORDER_TYPE_BUY)
         {
            _openBuyOrderCount++;
         }
         else if (order.Type == ORDER_TYPE_SELL)
         {
            _openSellOrderCount++;
         }
         else if (order.Type == ORDER_TYPE_BUY_LIMIT || order.Type == ORDER_TYPE_BUY_STOP)
         {
            _openPendingBuyOrderCount++;
         }
         else if (order.Type == ORDER_TYPE_SELL_LIMIT || order.Type == ORDER_TYPE_SELL_STOP)
         {
            _openPendingSellOrderCount++;
         }
      }
      
      void CountRemovedOpenOrder(Order* order)
      {
         if (order.Type == ORDER_TYPE_BUY)
         {
            _openBuyOrderCount--;
         }
         else if (order.Type == ORDER_TYPE_SELL)
         {
            _openSellOrderCount--;
         }
         else if (order.Type == ORDER_TYPE_BUY_LIMIT || order.Type == ORDER_TYPE_BUY_STOP)
         {
            _openPendingBuyOrderCount--;
         }
         else if (order.Type == ORDER_TYPE_SELL_LIMIT || order.Type == ORDER_TYPE_SELL_STOP)
         {
            _openPendingSellOrderCount--;
         }
      }
};
//
//  OrderLib
//
class OrderLib
{
public:
      static double OrderOpenPrice(ENUM_ORDER_TYPE orderType)
      {
         Order* openOrderInContext = _ea.GetWallet().GetNewestOpenOrder(orderType);
         return OrderOpenPrice(openOrderInContext);
      }

      static double OrderOpenPrice(Order* openOrderInContext)
      {
         return (openOrderInContext != NULL ? openOrderInContext.OpenPrice : EMPTY_VALUE);
      }

      static double OrderOpenSeconds(ENUM_ORDER_TYPE orderType)
      {
        Order* openOrderInContext = _ea.GetWallet().GetNewestOpenOrder(orderType);
        return OrderOpenSeconds(openOrderInContext);
      }

      static double OrderOpenSeconds(Order* openOrderInContext)
      {
        return (openOrderInContext != NULL ? TimeCurrent() - (double)openOrderInContext.OpenTime : EMPTY_VALUE);
      }

      static double ClosestStopLoss(ENUM_ORDER_TYPE orderType)
      {
         Order* openOrderInContext = _ea.GetWallet().GetNewestOpenOrder(orderType);
         return ClosestStopLoss(openOrderInContext);
      }

      static double ClosestStopLoss(Order* openOrderInContext)
      {
         return (openOrderInContext != NULL && openOrderInContext.GetClosestSL() != 0 ? openOrderInContext.GetClosestSL() : EMPTY_VALUE);
      }

      static double ClosestTakeProfit(ENUM_ORDER_TYPE orderType)
      {
         Order* openOrderInContext = _ea.GetWallet().GetNewestOpenOrder(orderType);
         return ClosestTakeProfit(openOrderInContext);
      }

      static double ClosestTakeProfit(Order* openOrderInContext)
      {
         return (openOrderInContext != NULL && openOrderInContext.GetClosestTP() != 0 ? openOrderInContext.GetClosestTP() : EMPTY_VALUE);
      }

      static int NumberOfOpenOrders()
      {
         return _ea.GetWallet().GetOpenOrderCount();
      }

      static int NumberOfOpenBuyOrders()
      {
         return _ea.GetWallet().GetOpenBuyOrderCount();
      }

      static int NumberOfOpenSellOrders()
      {
         return _ea.GetWallet().GetOpenSellOrderCount();
      }

      static double OrderOpenPriceBuy()
      {
         Order* openOrderNewestBuy = _ea.GetWallet().GetNewestOpenOrder(ORDER_TYPE_BUY);
         return (openOrderNewestBuy != NULL ? openOrderNewestBuy.OpenPrice : EMPTY_VALUE);
      }

      static double ClosestStopLossBuy()
      {
         Order* openOrderNewestBuy = _ea.GetWallet().GetNewestOpenOrder(ORDER_TYPE_BUY);
         return (openOrderNewestBuy != NULL && openOrderNewestBuy.GetClosestSL() != 0 ? openOrderNewestBuy.GetClosestSL() : EMPTY_VALUE);
      }

      static double ClosestTakeProfitBuy()
      {
         Order* openOrderNewestBuy = _ea.GetWallet().GetNewestOpenOrder(ORDER_TYPE_BUY);
         return (openOrderNewestBuy != NULL && openOrderNewestBuy.GetClosestTP() != 0 ? openOrderNewestBuy.GetClosestTP() : EMPTY_VALUE);
      }

      static double OrderOpenPriceSell()
      {
         Order* openOrderNewestSell = _ea.GetWallet().GetNewestOpenOrder(ORDER_TYPE_SELL);
         return (openOrderNewestSell != NULL ? openOrderNewestSell.OpenPrice : EMPTY_VALUE);
      }

      static double ClosestStopLossSell()
      {
         Order* openOrderNewestSell = _ea.GetWallet().GetNewestOpenOrder(ORDER_TYPE_SELL);
         return (openOrderNewestSell != NULL && openOrderNewestSell.GetClosestSL() != 0 ? openOrderNewestSell.GetClosestSL() : EMPTY_VALUE);
      }

      static double ClosestTakeProfitSell()
      {
         Order* openOrderNewestSell = _ea.GetWallet().GetNewestOpenOrder(ORDER_TYPE_SELL);
         return (openOrderNewestSell != NULL && openOrderNewestSell.GetClosestTP() != 0 ? openOrderNewestSell.GetClosestTP() : EMPTY_VALUE);
      }

      static double OrderOpenSecondsBuy()
      {
         Order* openOrderNewestBuy = _ea.GetWallet().GetNewestOpenOrder(ORDER_TYPE_BUY);
         return (openOrderNewestBuy != NULL ? TimeCurrent() - (double)openOrderNewestBuy.OpenTime : EMPTY_VALUE);
      }

      static double OrderOpenSecondsSell()
      {
         Order* openOrderNewestSell = _ea.GetWallet().GetNewestOpenOrder(ORDER_TYPE_SELL);
         return (openOrderNewestSell != NULL ? TimeCurrent() - (double)openOrderNewestSell.OpenTime : EMPTY_VALUE);
      }

      static double OrderOpenPriceOldest()
      {
         Order* openOrderOldest = _ea.GetWallet().GetOldestOpenOrder();
         return (openOrderOldest != NULL ? openOrderOldest.OpenPrice : EMPTY_VALUE);
      }

      static double OrderOpenPriceOldestBuy()
      {
         Order* openOrderOldestBuy = _ea.GetWallet().GetOldestOpenOrder(ORDER_TYPE_BUY);
         return (openOrderOldestBuy != NULL ? openOrderOldestBuy.OpenPrice : EMPTY_VALUE);
      }

      static double OrderOpenPriceOldestSell()
      {
         Order* openOrderOldestSell = _ea.GetWallet().GetOldestOpenOrder(ORDER_TYPE_SELL);
         return (openOrderOldestSell != NULL ? openOrderOldestSell.OpenPrice : EMPTY_VALUE);
      }

      static double OrderOpenPriceHighest()
      {
         return _ea.GetWallet().GetHighestOpenPriceOpenOrder();
      }

      static double OrderOpenPriceHighestBuy()
      {
         return _ea.GetWallet().GetHighestOpenPriceOpenOrder(ORDER_TYPE_BUY);
      }

      static double OrderOpenPriceHighestSell()
      {
         return _ea.GetWallet().GetHighestOpenPriceOpenOrder(ORDER_TYPE_SELL);
      }

      static double OrderOpenPriceLowest()
      {
         return _ea.GetWallet().GetLowestOpenPriceOpenOrder();
      }

      static double OrderOpenPriceLowestBuy()
      {
         return _ea.GetWallet().GetLowestOpenPriceOpenOrder(ORDER_TYPE_BUY);
      }

      static double OrderOpenPriceLowestSell()
      {
         return _ea.GetWallet().GetLowestOpenPriceOpenOrder(ORDER_TYPE_SELL);
      }

      static double OrderOpenPriceNewest()
      {
         Order* openOrderNewest = _ea.GetWallet().GetNewestOpenOrder();
         return (openOrderNewest != NULL ? openOrderNewest.OpenPrice : EMPTY_VALUE);
      }

      static double OrderOpenSecondsNewest()
      {
         Order* openOrderNewest = _ea.GetWallet().GetNewestOpenOrder();
         return (openOrderNewest != NULL ? TimeCurrent() - (double)openOrderNewest.OpenTime : EMPTY_VALUE);
      }

      static double ClosestStopLossNewest()
      {
         Order* openOrderNewest = _ea.GetWallet().GetNewestOpenOrder();
         return (openOrderNewest != NULL && openOrderNewest.GetClosestSL() != 0 ? openOrderNewest.GetClosestSL() : EMPTY_VALUE);
      }

      static double ClosestTakeProfitNewest()
      {
         Order* openOrderNewest = _ea.GetWallet().GetNewestOpenOrder();
         return (openOrderNewest != NULL && openOrderNewest.GetClosestTP() != 0 ? openOrderNewest.GetClosestTP() : EMPTY_VALUE);
      }

      static double OrderClosedSeconds()
      {
         Order* closedOrderLast = _ea.GetWallet().GetLastClosedOrder();
         return (closedOrderLast != NULL ? TimeCurrent() - (double)closedOrderLast.CloseTime : EMPTY_VALUE);
      }

      static double OrderClosedSecondsBuy()
      {
         Order* closedOrderLastBuy = _ea.GetWallet().GetLastClosedOrder(ORDER_TYPE_BUY);
         return (closedOrderLastBuy != NULL ? TimeCurrent() - (double)closedOrderLastBuy.CloseTime : EMPTY_VALUE);
      }

      static double OrderClosedSecondsSell()
      {
         Order* closedOrderLastSell = _ea.GetWallet().GetLastClosedOrder(ORDER_TYPE_SELL);
         return (closedOrderLastSell != NULL ? TimeCurrent() - (double)closedOrderLastSell.CloseTime : EMPTY_VALUE);
      }

      static double OrderVolume(int orderType = -1)
      {
         return _ea.GetWallet().GetOpenOrderVolume(orderType);
      }

      static double OrderOpenPriceClosed()
      {
         Order* closedOrderLast = _ea.GetWallet().GetLastClosedOrder();
         return (closedOrderLast != NULL ? closedOrderLast.OpenPrice : EMPTY_VALUE);
      }

      static double OrderOpenPriceClosedBuy()
      {
         Order* closedOrderLastBuy = _ea.GetWallet().GetLastClosedOrder(ORDER_TYPE_BUY);
         return (closedOrderLastBuy != NULL ? closedOrderLastBuy.OpenPrice : EMPTY_VALUE);
      }

      static double OrderOpenPriceClosedSell()
      {
         Order* closedOrderLastSell = _ea.GetWallet().GetLastClosedOrder(ORDER_TYPE_SELL);
         return (closedOrderLastSell != NULL ? closedOrderLastSell.OpenPrice : EMPTY_VALUE);
      }

      static double OrderClosePriceClosed()
      {
         Order* closedOrderLast = _ea.GetWallet().GetLastClosedOrder();
         return (closedOrderLast != NULL ? closedOrderLast.ClosePrice : EMPTY_VALUE);
      }

      static double OrderClosePriceClosedBuy()
      {
         Order* closedOrderLastBuy = _ea.GetWallet().GetLastClosedOrder(ORDER_TYPE_BUY);
         return (closedOrderLastBuy != NULL ? closedOrderLastBuy.ClosePrice : EMPTY_VALUE);
      }

      static double OrderClosePriceClosedSell()
      {
         Order* closedOrderLastSell = _ea.GetWallet().GetLastClosedOrder(ORDER_TYPE_SELL);
         return (closedOrderLastSell != NULL ? closedOrderLastSell.ClosePrice : EMPTY_VALUE);
      }

      static double ProfitPipsOpenOrders()
      {
         return ModuleCalculationsBase::CalculateOrderCollectionProfit(_ea.GetWallet().GetOpenOrders(), Pips);
      }

      static double ProfitPipsBuyOrders()
      {
         return ModuleCalculationsBase::CalculateOrderCollectionProfit(_ea.GetWallet().GetOpenOrders(), Pips, ORDER_TYPE_BUY);
      }

      static double ProfitPipsSellOrders()
      {
         return ModuleCalculationsBase::CalculateOrderCollectionProfit(_ea.GetWallet().GetOpenOrders(), Pips, ORDER_TYPE_SELL);
      }

      static double ProfitMoneyOpenOrders()
      {
         return ModuleCalculationsBase::CalculateOrderCollectionProfit(_ea.GetWallet().GetOpenOrders(), Money);
      }

      static double ProfitMoneyBuyOrders()
      {
         return ModuleCalculationsBase::CalculateOrderCollectionProfit(_ea.GetWallet().GetOpenOrders(), Money, ORDER_TYPE_BUY);
      }

      static double ProfitMoneySellOrders()
      {
         return ModuleCalculationsBase::CalculateOrderCollectionProfit(_ea.GetWallet().GetOpenOrders(), Money, ORDER_TYPE_SELL);
      }

      static double OrderTakeProfitOldest()
      {
         Order* openOrderOldest = _ea.GetWallet().GetOldestOpenOrder();
         return (openOrderOldest != NULL && openOrderOldest.GetClosestTP() != 0 ? openOrderOldest.GetClosestTP() : EMPTY_VALUE);
      }

      static double OrderTakeProfitOldestBuy()
      {
         Order* openOrderOldestBuy = _ea.GetWallet().GetOldestOpenOrder(ORDER_TYPE_BUY);
         return (openOrderOldestBuy != NULL && openOrderOldestBuy.GetClosestTP() != 0 ? openOrderOldestBuy.GetClosestTP() : EMPTY_VALUE);
      }

      static double OrderTakeProfitOldestSell()
      {
         Order* openOrderOldestSell = _ea.GetWallet().GetOldestOpenOrder(ORDER_TYPE_SELL);
         return (openOrderOldestSell != NULL && openOrderOldestSell.GetClosestTP() != 0 ? openOrderOldestSell.GetClosestTP() : EMPTY_VALUE);
      }

      static double OrderStopLossOldest()
      {
         Order* openOrderOldest = _ea.GetWallet().GetOldestOpenOrder();
         return (openOrderOldest != NULL && openOrderOldest.GetClosestSL() != 0 ? openOrderOldest.GetClosestSL() : EMPTY_VALUE);
      }

      static double OrderStopLossOldestBuy()
      {
         Order* openOrderOldestBuy = _ea.GetWallet().GetOldestOpenOrder(ORDER_TYPE_BUY);
         return (openOrderOldestBuy != NULL && openOrderOldestBuy.GetClosestSL() != 0 ? openOrderOldestBuy.GetClosestSL() : EMPTY_VALUE);
      }

      static double OrderStopLossOldestSell()
      {
         Order* openOrderOldestSell = _ea.GetWallet().GetOldestOpenOrder(ORDER_TYPE_SELL);
         return (openOrderOldestSell != NULL && openOrderOldestSell.GetClosestSL() != 0 ? openOrderOldestSell.GetClosestSL() : EMPTY_VALUE);
      }
};

//
//  TradeAction
//
enum TradeAction
{
	UnknownAction = 0,
	OpenBuyAction = 1,
	OpenSellAction = 2,
	CloseBuyAction = 3,
	CloseSellAction = 4
};

//
//  AdvisorStrategyExpression interfaces
//
interface IAdvisorStrategyBoolExpression
{
   bool Evaluate();
   bool GetFireOnlyWhenReset();
   void SetFireOnlyWhenReset(bool value);
   void ResetSignalValue();
};

interface IAdvisorStrategyValueExpression
{
   double Evaluate();
};

class AdvisorStrategyBoolExpression : public IAdvisorStrategyBoolExpression
{
private:
   bool _fireOnlyWhenReset;
   int _previousSignalValue;
   int _signalValue;

protected:
   bool virtual EvaluateSignal() = 0;

public:
   void AdvisorStrategyBoolExpression()
   {
      _fireOnlyWhenReset = false;

      _previousSignalValue = -1;
      _signalValue = -1;
   }

   bool Evaluate()
   {
      if (_signalValue == -1)
         _signalValue = EvaluateSignal();

      if (_fireOnlyWhenReset)
         return (_previousSignalValue <= 0 && _signalValue == 1);
      else
         return _signalValue == 1;
   }

   bool GetFireOnlyWhenReset() { return _fireOnlyWhenReset; }
   void SetFireOnlyWhenReset(bool value) { _fireOnlyWhenReset = value; }

   void ResetSignalValue()
   {
      _previousSignalValue = _signalValue;
      _signalValue = -1;
   }
};

class AdvisorStrategyValueExpression : public IAdvisorStrategyValueExpression
{
protected:
   double virtual EvaluateValue() = 0;

public:
   void AdvisorStrategyValueExpression()
   {
   }

   double Evaluate()
   {
      double evaluateValue = EvaluateValue();
      return evaluateValue == EMPTY_VALUE ? 0 : evaluateValue;
   }
};

interface IAdvisorStrategySignal
{
   void RegisterSignalExpression(IAdvisorStrategyBoolExpression* expression);
   void RegisterOpenPriceExpression(IAdvisorStrategyValueExpression* expression);
   void RegisterExpirationExpression(IAdvisorStrategyBoolExpression* expression);
   
   IAdvisorStrategyBoolExpression* Signal();
   bool Evaluate();
   void ResetSignalValue();
   
   ENUM_ORDER_TYPE GetType();
   double GetOpenPrice();
   bool IsExpired();
   void SetExpiryTimeSpan(datetime expiryTimeSpan);
   datetime GetExpiryTimeSpan();
};

class ASSignal : public IAdvisorStrategySignal
{
private:
   ENUM_ORDER_TYPE _type;
   IAdvisorStrategyBoolExpression* _signalExpression;
   IAdvisorStrategyValueExpression* _openPriceExpression;
   IAdvisorStrategyBoolExpression* _expiryExpression;
   datetime _expiryTimeSpan;

public:
   void ASSignal(ENUM_ORDER_TYPE type) {
      _type = type;
      _openPriceExpression = NULL;
      _expiryExpression = NULL;
   }
      
   void ~ASSignal()
	{
	   if (_signalExpression != NULL)
		   delete(_signalExpression);
		   
		if (_openPriceExpression != NULL)   
		   delete(_openPriceExpression);
		   
		if (_expiryExpression != NULL)   
		   delete(_expiryExpression);
	}

   void RegisterSignalExpression(IAdvisorStrategyBoolExpression* expression)
   	{
   		_signalExpression = expression;
   	}
   	
   	void RegisterOpenPriceExpression(IAdvisorStrategyValueExpression* expression)
   	{
   		_openPriceExpression = expression;
   	}
   	
   	void RegisterExpirationExpression(IAdvisorStrategyBoolExpression* expression)
   	{
   		_expiryExpression = expression;
   	}
   	
   	void SetExpiryTimeSpan(datetime expiryTimeSpan)
   	{
   	   _expiryTimeSpan = expiryTimeSpan;
   	}
   	
   	IAdvisorStrategyBoolExpression* Signal()
   	{
   	   return _signalExpression;
   	}
   	
   	ENUM_ORDER_TYPE GetType()
   	{
   	   return _type;
   	}
   	
   	bool Evaluate()
   	{
   	   return _signalExpression.Evaluate();
   	}
   	
   	double GetOpenPrice()
   	{
   	   if (_openPriceExpression != NULL)
   	      return _openPriceExpression.Evaluate();
   	   
   	   return NULL;   
   	}
   	
   	bool IsExpired()
   	{
   	   if (_expiryExpression != NULL)
   	      return _expiryExpression.Evaluate();
   	   
   	   return false;   
   	}
   	
   	datetime GetExpiryTimeSpan()
   	{
   	   return _expiryTimeSpan;
   	}
   	
   	void ResetSignalValue()
   	{
   	   _signalExpression.ResetSignalValue();
   	   
   	   if (_expiryExpression != NULL)
   	      _expiryExpression.ResetSignalValue();
   	}
};

class SignalResult
{
   public:
      ENUM_ORDER_TYPE OrderType;
      bool Activated;
      double OpenPrice;
      datetime ExpiryTimeSpan;  
   
      void SignalResult(SignalResult* item)
      {
         OrderType = item.OrderType;
         Activated = item.Activated;
         OpenPrice = item.OpenPrice;
         ExpiryTimeSpan = item.ExpiryTimeSpan;
      }
   
      void SignalResult()
      {
         Activated = false;
         ExpiryTimeSpan = 0;     // If you change this default value, it impacts opening orders for orders without expiry (market orders)
      }
};

//
//  SignalResultCollection
//
class SignalResultCollection
{
    private:
        SignalResult* _signalResults[];
        int _pointer;
        int _size;

    public:
        void SignalResultCollection()
        {
            _pointer = -1;
            _size = 0;
        }

        void ~SignalResultCollection()
        {
            for (int i = 0; i < ArraySize(_signalResults); i++)
            {
                delete(_signalResults[i]);
            }
        }

        void Add(SignalResult* item)
        {
            _size = _size + 1;
            ArrayResize(_signalResults, _size, 8);

            _signalResults[(_size - 1)] = item;
        }

        SignalResult* Remove(int index)
        {
            SignalResult* removed = NULL;

            if (index >= 0 && index < _size)
            {
               removed = _signalResults[index];
               
               for (int i = index; i < (_size - 1); i++)
               {
                   _signalResults[i] = _signalResults[i + 1];
               }
   
               ArrayResize(_signalResults, ArraySize(_signalResults) - 1, 8);
               _size = _size - 1;
            }
            
            return removed;
        }

        SignalResult* Get(int index)
        {
            if (index >= 0 && index < _size)
            {
                return _signalResults[index];
            }

            return NULL;
        }

        int Count()
        {
            return _size;
        }

        void Rewind()
        {
            _pointer = -1;
        }

        SignalResult* Next()
        {
            _pointer++;
            if (_pointer == _size)
            {
                Rewind();
                return NULL;
            }

            return Current();
        }

        SignalResult* Prev()
        {
            _pointer--;
            if (_pointer == -1)
            {
                return NULL;
            }

            return Current();
        }

        bool HasNext()
        {
            return (_pointer < (_size - 1));
        }

        SignalResult* Current()
        {
            return _signalResults[_pointer];
        }

        int Key()
        {
            return _pointer;
        }
        
};

//
//  TradeSignalCollection
//
class TradeSignalCollection
{
    private:
        IAdvisorStrategySignal* _tradeSignals[];
        int _pointer;
        int _size;

    public:
        void TradeSignalCollection()
        {
            _pointer = -1;
            _size = 0;
        }

        void ~TradeSignalCollection()
        {
            for (int i = 0; i < ArraySize(_tradeSignals); i++)
            {
                delete(_tradeSignals[i]);
            }
        }

        void Add(IAdvisorStrategySignal* item)
        {
            _size = _size + 1;
            ArrayResize(_tradeSignals, _size, 8);

            _tradeSignals[(_size - 1)] = item;
        }

        IAdvisorStrategySignal* Remove(int index)
        {
            IAdvisorStrategySignal* removed = NULL;

            if (index >= 0 && index < _size)
            {
               removed = _tradeSignals[index];
               
               for (int i = index; i < (_size - 1); i++)
               {
                   _tradeSignals[i] = _tradeSignals[i + 1];
               }
   
               ArrayResize(_tradeSignals, ArraySize(_tradeSignals) - 1, 8);
               _size = _size - 1;
            }
            
            return removed;
        }

        IAdvisorStrategySignal* Get(int index)
        {
            if (index >= 0 && index < _size)
            {
                return _tradeSignals[index];
            }

            return NULL;
        }

        int Count()
        {
            return _size;
        }

        void Rewind()
        {
            _pointer = -1;
        }

        IAdvisorStrategySignal* Next()
        {
            _pointer++;
            if (_pointer == _size)
            {
                Rewind();
                return NULL;
            }

            return Current();
        }

        IAdvisorStrategySignal* Prev()
        {
            _pointer--;
            if (_pointer == -1)
            {
                return NULL;
            }

            return Current();
        }

        bool HasNext()
        {
            return (_pointer < (_size - 1));
        }

        IAdvisorStrategySignal* Current()
        {
            return _tradeSignals[_pointer];
        }

        int Key()
        {
            return _pointer;
        }
        
};

//
//  AdvisorStrategy
//
class AdvisorStrategy
{
private:
	TradeSignalCollection* _openBuySignals;
	TradeSignalCollection* _openSellSignals;
	
	TradeSignalCollection* _closeBuySignals;
	TradeSignalCollection* _closeSellSignals;

	SignalResult* EvaluateASLevel(TradeSignalCollection* signals, int level)
	{
	   SignalResult* signalProperties = new SignalResult();
	
		if (level > 0
			&& level <= signals.Count())
		{
		   IAdvisorStrategySignal* signal = signals.Get(level-1);
		   
		   signalProperties.Activated = signal.Evaluate();
		   if (signalProperties.Activated)
		   {
		      signalProperties.OrderType = signal.GetType();		 
		      signalProperties.OpenPrice = signal.GetOpenPrice();
		      signalProperties.ExpiryTimeSpan = signal.GetExpiryTimeSpan();
		   }
		}
	
		return signalProperties;
	}
	
	bool EvaluateASLevelExpiry(TradeSignalCollection* signals, int level)
	{
		if (level > 0
			&& level <= signals.Count())
		{
			return signals.Get(level-1).IsExpired();
		}
	
		return false;
	}
   
public:
	void AdvisorStrategy()
	{
		_openBuySignals = new TradeSignalCollection();
		_openSellSignals = new TradeSignalCollection();
		_closeBuySignals = new TradeSignalCollection();
		_closeSellSignals = new TradeSignalCollection();
	}
   
	void ~AdvisorStrategy()
	{
		delete(_openBuySignals);
		delete(_openSellSignals);
		delete(_closeBuySignals);
		delete(_closeSellSignals);
	}
   
	SignalResult* GetAdvice(TradeAction tradeAction, int level)
	{
		if (tradeAction == OpenBuyAction)
		{
			return EvaluateASLevel(_openBuySignals, level);
		}
		else if (tradeAction == OpenSellAction)
		{
			return EvaluateASLevel(_openSellSignals, level);
		}
		else if (tradeAction == CloseBuyAction)
		{
			return EvaluateASLevel(_closeBuySignals, level);
		}
		else if (tradeAction == CloseSellAction)
		{
			return EvaluateASLevel(_closeSellSignals, level);
		}
		else
		{
			Alert("Unsupported TradeAction in Advisor Strategy. TradeAction: " + DoubleToStr(tradeAction));
		}

		return NULL;
	}

	TradingModuleDemand GetExpiry(TradeAction tradeAction, int level)
	{
		if (tradeAction == CloseBuyAction)
		{
		   if (EvaluateASLevelExpiry(_openBuySignals, level))
		      return CloseBuyDemand;
		}
		else if (tradeAction == CloseSellAction)
		{
		   if (EvaluateASLevelExpiry(_openSellSignals, level))
			   return CloseSellDemand;
		}
		else
		{
			Alert("Unsupported TradeAction in Advisor Strategy GetExpiry. TradeAction: " + DoubleToStr(tradeAction));
		}

		return NULL;
	}
   
	void RegisterOpenBuy(IAdvisorStrategySignal* openBuySignal, int level)
	{
		if (level <= _openBuySignals.Count())
		{
			Alert("Register Open Buy failed: level already set.");
			return;
		}
   
		_openBuySignals.Add(openBuySignal);
	}
   
	void RegisterOpenSell(IAdvisorStrategySignal* openSellSignal, int level)
	{
		if (level <= _openSellSignals.Count())
		{
			Alert("Register Open Sell failed: level already set.");
			return;
		}
   
		_openSellSignals.Add(openSellSignal);
	}
   
	void RegisterCloseBuy(IAdvisorStrategySignal* closeBuySignal, int level)
	{
		if (level <= _closeBuySignals.Count())
		{
			Alert("Register Close Buy failed: level already set.");
			return;
		}
   
		_closeBuySignals.Add(closeBuySignal);
	}
   
	void RegisterCloseSell(IAdvisorStrategySignal* closeSellSignal, int level)
	{
		if (level <= _closeSellSignals.Count())
		{
			Alert("Register Close Buy failed: level already set.");
			return;
		}
   
		_closeSellSignals.Add(closeSellSignal);
	}

	int GetNumberOfExpressions(TradeAction tradeAction)
	{
		if (tradeAction == OpenBuyAction)
		{
			return _openBuySignals.Count();
		}
		else if (tradeAction == OpenSellAction)
		{
			return _openSellSignals.Count();
		}
		else if (tradeAction == CloseBuyAction)
		{
			return _closeBuySignals.Count();
		}
		else if (tradeAction == CloseSellAction)
		{
			return _closeSellSignals.Count();
		}
		return 0;
	}

	void SetFireOnlyWhenReset(bool valueOpenSignals, bool valueCloseSignals)
	{
		_openBuySignals.Rewind();
		while (_openBuySignals.Next() != NULL)
		    _openBuySignals.Current().Signal().SetFireOnlyWhenReset(valueOpenSignals);
		      
		_openSellSignals.Rewind();
		while (_openSellSignals.Next() != NULL)
		    _openSellSignals.Current().Signal().SetFireOnlyWhenReset(valueOpenSignals); 

		_closeBuySignals.Rewind();
		while (_closeBuySignals.Next() != NULL)
		    _closeBuySignals.Current().Signal().SetFireOnlyWhenReset(valueCloseSignals); 

		_closeSellSignals.Rewind();
		while (_closeSellSignals.Next() != NULL)
		    _closeSellSignals.Current().Signal().SetFireOnlyWhenReset(valueCloseSignals); 
	}
		
	void HandleTick()
	{
		_openBuySignals.Rewind();
		while (_openBuySignals.Next() != NULL)
		{
		    _openBuySignals.Current().ResetSignalValue();
		    if (_openBuySignals.Current().Signal().GetFireOnlyWhenReset())
		        _openBuySignals.Current().Signal().Evaluate(); 
	    }
		      
		_openSellSignals.Rewind();
		while (_openSellSignals.Next() != NULL)
		{
		    _openSellSignals.Current().ResetSignalValue(); 
		    if (_openSellSignals.Current().Signal().GetFireOnlyWhenReset())
		        _openSellSignals.Current().Signal().Evaluate(); 
	    }
	      
		_closeBuySignals.Rewind();
		while (_closeBuySignals.Next() != NULL)
		{
		    _closeBuySignals.Current().ResetSignalValue(); 
		    if (_closeBuySignals.Current().Signal().GetFireOnlyWhenReset())
		        _closeBuySignals.Current().Signal().Evaluate(); 
	    }
	      
		_closeSellSignals.Rewind();
		while (_closeSellSignals.Next() != NULL)
		{
		    _closeSellSignals.Current().ResetSignalValue(); 
		    if (_closeSellSignals.Current().Signal().GetFireOnlyWhenReset())
		        _closeSellSignals.Current().Signal().Evaluate(); 
	    }
	}
};

//
//  AdvisorStrategySignals
//
input group "OpenBuySignal Constants"
input double OpenBuySignal_Const_InpQQEOversold = 40;
input double OpenBuySignal_Const_OneDisableBuyTrades = 0;
input double OpenBuySignal_Const_TwoDisableFollowUpBuys = 1;

class ASOpenBuySignalLevel1 : public AdvisorStrategyBoolExpression
{
protected:
   bool EvaluateSignal()
   {
      
      if ((((OrderLib::NumberOfOpenBuyOrders() == OpenBuySignal_Const_OneDisableBuyTrades)
 && (fn_QMPFilter_QMPFilter1(Symbol(),0,1) != 1.7976931348623157E+308)
)
 && (fn_QQEAdv_QQE7142(Symbol(),0,1) <= OpenBuySignal_Const_InpQQEOversold)
)
 || ((OrderLib::NumberOfOpenBuyOrders() >= OpenBuySignal_Const_TwoDisableFollowUpBuys)
 && (fn_QMPFilter_QMPFilter1(Symbol(),0,1) != 1.7976931348623157E+308)
)
)

      {
         return true;
      }

      return false;
   }
public:
   void ASOpenBuySignalLevel1()
   {
   }
};

input group "OpenSellSignal Constants"
input double OpenSellSignal_Const_InpQQEOverbought = 60;
input double OpenSellSignal_Const_OneDisableSellTrades = 0;
input double OpenSellSignal_Const_TwoDisableFollowUpSells = 1;

class ASOpenSellSignalLevel1 : public AdvisorStrategyBoolExpression
{
protected:
   bool EvaluateSignal()
   {
      
      if ((((OrderLib::NumberOfOpenSellOrders() == OpenSellSignal_Const_OneDisableSellTrades)
 && (fn_QMPFilter_QMPFilter1(Symbol(),1,1) != 1.7976931348623157E+308)
)
 && (fn_QQEAdv_QQE7142(Symbol(),0,1) >= OpenSellSignal_Const_InpQQEOverbought)
)
 || ((OrderLib::NumberOfOpenSellOrders() >= OpenSellSignal_Const_TwoDisableFollowUpSells)
 && (fn_QMPFilter_QMPFilter1(Symbol(),1,1) != 1.7976931348623157E+308)
)
)

      {
         return true;
      }

      return false;
   }
public:
   void ASOpenSellSignalLevel1()
   {
   }
};

input group "CloseBuySignal Constants"
input double CloseBuySignal_Const_BalPercenToClose = 0;
input double CloseBuySignal_Const_ProfitMoneyCloseBuy = 0;
input double CloseBuySignal_Const_QQECloseBuyLevel = 50;

class ASCloseBuySignalLevel1 : public AdvisorStrategyBoolExpression
{
protected:
   bool EvaluateSignal()
   {
      
      if (((fn_QQEAdv_QQE7142(Symbol(),0,1) >= CloseBuySignal_Const_QQECloseBuyLevel)
 && (OrderLib::ProfitMoneyBuyOrders() >= CloseBuySignal_Const_ProfitMoneyCloseBuy)
)
 || (AccountEquity_LibFunc() < (AccountBalance_LibFunc() * CloseBuySignal_Const_BalPercenToClose)
)
)

      {
         return true;
      }

      return false;
   }
public:
   void ASCloseBuySignalLevel1()
   {
   }
};

input group "CloseSellSignal Constants"
input double CloseSellSignal_Const_BalPercenToClose = 0;
input double CloseSellSignal_Const_ProfitMoneyCloseSell = 0;
input double CloseSellSignal_Const_QQECloseSellLevel = 50;

class ASCloseSellSignalLevel1 : public AdvisorStrategyBoolExpression
{
protected:
   bool EvaluateSignal()
   {
      
      if (((fn_QQEAdv_QQE7142(Symbol(),0,1) <= CloseSellSignal_Const_QQECloseSellLevel)
 && (OrderLib::ProfitMoneySellOrders() >= CloseSellSignal_Const_ProfitMoneyCloseSell)
)
 || (AccountEquity_LibFunc() < (AccountBalance_LibFunc() * CloseSellSignal_Const_BalPercenToClose)
)
)

      {
         return true;
      }

      return false;
   }
public:
   void ASCloseSellSignalLevel1()
   {
   }
};

input group "Module Inputs"
//
//  MoneyManager Interface
//
interface IMoneyManager
{
   double GetLotSize(Wallet* wallet, Order* order);
   int GetNextLevel(Wallet* wallet);
};

input string ManualLotSizeSequence = "0.02,0.06,0.1,0.16,0.26,0.42,0.68,1.1,1.78,2.88,*1.619"; // MM Manual Sequence - Lot size sequence
input bool SplitSequenceForBuyAndSellOrders = false; // MM Manual Sequence - Split sequence for buy and sell orders
input bool UseCurrentLotSize = true; // MM Manual Sequence - Use current lot size for additional orders

class MoneyManager : public IMoneyManager
{
   private:
      double MarginRequiredBuy;
      double MarginRequiredSell;

   public:
      void MoneyManager(Wallet* wallet)
      {
         _minLot = MarketInfo_LibFunc(OrderSymbolTarget, MODE_MINLOT);
         _maxLot = MarketInfo_LibFunc(OrderSymbolTarget, MODE_MAXLOT);
         _lotStep = MarketInfo_LibFunc(OrderSymbolTarget, MODE_LOTSTEP);

         if (!OrderCalcMargin(ORDER_TYPE_BUY, OrderSymbolTarget, 1, Bid_LibFunc(), MarginRequiredBuy))
         {
            HandleErrors(StringFormat("Couldn't calculate required margin for lot size calculation, error: %d", GetLastError()));
            MarginRequiredBuy = DBL_MAX;
            return;
         }

         if (!OrderCalcMargin(ORDER_TYPE_SELL, OrderSymbolTarget, 1, Bid_LibFunc(), MarginRequiredSell))
         {
            HandleErrors(StringFormat("Couldn't calculate required margin for lot size calculation, error: %d", GetLastError()));
            MarginRequiredSell = DBL_MAX;
            return;
         }

         double rawLotsize1Percent = ((double)1)/100*AccountInfoDouble(ACCOUNT_EQUITY)/(MarginRequiredBuy);
         double roundedLotSize1Percent = NormalizeLots(((double)1)/100*AccountInfoDouble(ACCOUNT_EQUITY)/(MarginRequiredBuy));

         Print("MM Percentage 1 results in volume: " + DoubleToStr(roundedLotSize1Percent) + StringFormat(" (rounded from %s)", DoubleToStr(rawLotsize1Percent)));
         Print("MM Percentage 10 results in volume: " + DoubleToStr(NormalizeLots(((double)10)/100*AccountInfoDouble(ACCOUNT_EQUITY)/(MarginRequiredBuy))));
         Print("MM Percentage 25 results in volume: " + DoubleToStr(NormalizeLots(((double)25)/100*AccountInfoDouble(ACCOUNT_EQUITY)/(MarginRequiredBuy))));
      }

      double GetLotSize(Wallet* wallet, Order* order)
      {
         double lotSize = 0;
         
         string operators[] = {"+", "-", "*", "/"};
         string lotSizes[];
         int ManualLotSizeSequenceSize = StringSplit(ManualLotSizeSequence, ',', lotSizes);
         
         int orderNumber = 0; // real order number
         if (SplitSequenceForBuyAndSellOrders)
         {
            orderNumber = order.Type == ORDER_TYPE_BUY ? wallet.GetOpenBuyOrderCount() + 1 : wallet.GetOpenSellOrderCount() + 1;
         }
         else
         {
            orderNumber = wallet.GetOpenOrderCount() + 1;
         }
         
         int iManualSequenceStartIndex; // If we take the calculated lot size, we start from the beginning. If we take the real (manual) opened lot size, we start from there
         if (UseCurrentLotSize)
         {
            int openedOrdersCount;
            
            if (SplitSequenceForBuyAndSellOrders)
            {
               openedOrdersCount = order.Type == ORDER_TYPE_BUY ? wallet.GetOpenBuyOrderCount() : wallet.GetOpenSellOrderCount();
            }
            else
            {
               openedOrdersCount = wallet.GetOpenOrderCount();
            }
            
            iManualSequenceStartIndex = openedOrdersCount > 0 ? openedOrdersCount : 0;
            
            if (SplitSequenceForBuyAndSellOrders)
            {
               lotSize = openedOrdersCount > 0 ? wallet.GetNewestOpenOrder(order.Type).Lots : 0;
            }
            else
            {
               lotSize = openedOrdersCount > 0 ? wallet.GetNewestOpenOrder().Lots : 0;
            }
         }
         else
         {
            iManualSequenceStartIndex = 0;
         }
         
         for (int i = iManualSequenceStartIndex; i < orderNumber; i++) 
         {
            int lotPartIndex = i < ManualLotSizeSequenceSize ? i : ManualLotSizeSequenceSize - 1; // Once there are more orders than sequence parts, we use the last sequence part
         
            string lotPart = lotSizes[lotPartIndex];
            bool operatorFound = false;
         
            // Check for operators in the current lotPart
            for (int j = 0; j < ArraySize(operators); j++) 
            {
               if (StringFind(lotPart, operators[j]) >= 0) 
               {
                   string operatorValue = operators[j];

                   StringReplace(lotPart, " ", "");
                   double value = StringToDouble(StringSubstr(lotPart, 1));
            
                   if (operatorValue == "+") {
                       lotSize += value;
                   } else if (operatorValue == "-") {
                       lotSize -= value;
                   } else if (operatorValue == "*") {
                       lotSize *= value;
                   } else if (operatorValue == "/") {
                       lotSize /= value;
                   }
            
                   operatorFound = true;
                   break;
               }
            }
         
            // If no operator is found, simply set the lotSize to the current lotPart
            if (!operatorFound) 
            {
               // Either percentage or fixed value
               if (StringFind(lotPart, "%") >= 0)             
               {
                  double value = StringToDouble(StringSubstr(lotPart, 0, StringLen(lotPart) -1));
                  lotSize = value/100*AccountInfoDouble(ACCOUNT_EQUITY) / (order.Type == ORDER_TYPE_BUY ? MarginRequiredBuy : MarginRequiredSell);
               }
               else
               {
                  lotSize = StringToDouble(lotPart);
               }
            }
         }
         
         return NormalizeLots(lotSize);
      }

      int GetNextLevel(Wallet* wallet)
      {
         return wallet.GetOpenOrderCount() + wallet.GetOpenPendingOrderCount() + 1;
      }

   private:
      double _minLot;
      double _maxLot;
      double _lotStep;
      double _tickValue;
      double _tickSize;
      double _point;

      double NormalizeLots(double lots)
      {
          lots = MathRound(lots/_lotStep) * _lotStep; // Using MathRound, because if lots is 0.999999999 / 0.01 it will result in 0.89999999 using MathFloor, which is 0.01 too low. I'm not sure why other modules use MathFloor, we have to check the scenario which led up to that decision.
          if (lots < _minLot)
          {
            HandleErrors("Falling back to minimum lot size for this symbol. Risk possibly larger than set.");
            lots = _minLot;
          }
          else if (lots > _maxLot) lots = _maxLot;

          return lots;
      }
};

//
//  TradingModuleExpression Interface
//
interface ITradingModuleSignal
        {
            string GetName();
            bool Evaluate(Order* openOrderInContext = NULL);
        };
        
interface ITradingModuleValue
        {
            string GetName();
            double Evaluate(Order* openOrderInContext = NULL);
        };
        
//
//  TradeStrategyModule Interface
//
interface ITradeStrategyModule
        {
            TradingModuleDemand Evaluate(Wallet* wallet, TradingModuleDemand demand, int level = 1);
            void RegisterTradeSignal(ITradingModuleSignal* tradeSignal);
        };
        
//
//  TradeStrategyOpenModule Interface
//
interface ITradeStrategyOpenModule : public ITradeStrategyModule
        {
            TradingModuleDemand EvaluateOpenSignals(Wallet* wallet, TradingModuleDemand demand, int requestedEvaluationLevel = 0);
            TradingModuleDemand EvaluateOpenPendingOrderExpiry(Wallet* wallet, int requestedEvaluationLevel);
            TradingModuleDemand EvaluateCloseSignals(Wallet* wallet, TradingModuleDemand demand);

            int GetVersion();
        };
        
//
//  Close TradeStrategy module Interface
//
interface ITradeStrategyCloseModule : public ITradeStrategyModule
        {
            void EvaluateOrder(Wallet* wallet, Order* order);
            ORDER_GROUP_TYPE GetOrderGroupingType();
            bool UsesOrderTrailing();
            string GetWarning();
            void RegisterTradeValue(ITradingModuleValue* tradeValue);
        };
        
//
//  TradeStrategy
//
class TradeStrategy
{
    private:
      ITradeStrategyModule* _preventOpenModules[];
      ITradeStrategyOpenModule* _openModule;
      IMoneyManager* _moneyManager;

    public:
      ITradeStrategyCloseModule* CloseModules[];
    
      void TradeStrategy(ITradeStrategyOpenModule* openCloseSignalModule, IMoneyManager* moneyManager)
      {
         _openModule = openCloseSignalModule;
         _moneyManager = moneyManager;
      }
      
      void Evaluate(Wallet* wallet)
      {
         int openPendingOrderCount = wallet.GetOpenPendingOrders().Count();
         if (openPendingOrderCount > 0)
         {
            TradingModuleDemand expiryDemand = _openModule.EvaluateOpenPendingOrderExpiry(wallet, 1);
            if (expiryDemand != NoneDemand)
            {
               ProcessExpiryConditions(wallet, expiryDemand);
            }
         }
      
         int openOrderCount = wallet.GetOpenOrders().Count();

         TradingModuleDemand finalPreventOpenAdvice = EvaluatePreventOpenModules(wallet, NoneDemand, openOrderCount + 1);
         
         if (openOrderCount > 0)
         {
            // Close modules set the TP/ SL in memory, don't persist to broker
            EvaluateCloseModules(wallet, NoneDemand);
            
            TradingModuleDemand signalCloseDemand = _openModule.EvaluateCloseSignals(wallet, finalPreventOpenAdvice);       

            // TP and SL can be modified by multiple modules. Here we evaluate the order's TP/SL with the current quote
            ProcessCloseConditions(wallet, signalCloseDemand);
         }

         // Evaluate Open module and inform module of NoOpen demands
         TradingModuleDemand openResult = _openModule.Evaluate(wallet, finalPreventOpenAdvice, 0);
         if (openResult != NoneDemand)
         {
            // orders were possibly opened, let's check
            OrderCollection* queuedOpenOrders = wallet.GetQueuedOpenOrders();
            for (int i = queuedOpenOrders.Count() - 1; i >= 0; i--)
            {
                Order* queuedOpenOrder = queuedOpenOrders.Get(i);

                if (!queuedOpenOrder.IsAwaitingDealExecution)
                {
                  if (queuedOpenOrder.OpenPrice == 0)
                  {
                    queuedOpenOrder.OpenPrice = IsBullishOrderType(queuedOpenOrder.Type) ? Ask_LibFunc() : Bid_LibFunc();
                  }

                  // Calculate the projected SL/ TP after calculatinig Open Price, because SL sometimes depends on open price and later MM depends on SL, so order is very important.
                  for (int j = ArraySize(CloseModules) - 1; j >= 0; j--)
                  {
                     CloseModules[j].EvaluateOrder(wallet, queuedOpenOrder);
                  }
                  
                  // Now that Open price and SL/ TP are clear, we can decide the lot size (some MM rely on this data)
                  queuedOpenOrder.Lots = _moneyManager.GetLotSize(wallet, queuedOpenOrder);
               }
            }
         }
      }
      
      void RegisterPreventOpenModule(ITradeStrategyModule* preventOpenModule)
      {
         int size = ArraySize(_preventOpenModules);
         ArrayResize(_preventOpenModules, size + 1, 8);
         _preventOpenModules[size] = preventOpenModule;
      }
      
      void RegisterCloseModule(ITradeStrategyCloseModule* closeModule)
      {
         int size = ArraySize(CloseModules);
         ArrayResize(CloseModules, size + 1, 8);
         CloseModules[size] = closeModule;
      }

      void ~TradeStrategy()
      {
         for (int i=ArraySize(_preventOpenModules)-1; i >= 0; i--)
         {
            delete(_preventOpenModules[i]);
         }
         
         delete(_openModule);
         
         for (int i=ArraySize(CloseModules)-1; i >= 0; i--)
         {
            delete(CloseModules[i]);
         }
      }
    
    private:
      TradingModuleDemand EvaluatePreventOpenModules(Wallet* wallet, TradingModuleDemand preventOpenDemand, int evaluationLevel = 1)
      {
         // Check PreventOpen demands
         TradingModuleDemand preventOpenDemands[];
         ArrayResize(preventOpenDemands, ArraySize(_preventOpenModules), 8);

         for (int i = 0; i < ArraySize(_preventOpenModules); i++) 
         {
            preventOpenDemands[i] = _preventOpenModules[i].Evaluate(wallet, NoneDemand, evaluationLevel);
         }
         
         // Combine the advices into 1 advice (None, NoBuy, NoSell or NoOpen)
         return PreventOpenModuleBase::GetCombinedPreventOpenDemand(preventOpenDemands);
      }
      
      TradingModuleDemand EvaluateCloseModules(Wallet* wallet, TradingModuleDemand closeDemand, int evaluationLevel = 1)
      {
         // Check Close demands
         TradingModuleDemand closeDemands[];
         ArrayResize(closeDemands, ArraySize(CloseModules), 8);

         for (int i = 0; i < ArraySize(CloseModules); i++) 
         {
            closeDemands[i] = CloseModules[i].Evaluate(wallet, NoneDemand, evaluationLevel);
         }

         // Combine the advices into 1 advice (None, NoBuy, NoSell or NoOpen)
         return CloseModuleBase::GetCombinedCloseDemand(closeDemands);
      }

      void ProcessExpiryConditions(Wallet* wallet, TradingModuleDemand expireSignalDemand)
      {
         if (expireSignalDemand == NoneDemand)
            return;
      
         for(int i = 0; i < wallet.GetOpenPendingOrderCount(); i++)
         {
            Order* openPendingOrder = wallet.GetOpenPendingOrders().Get(i);
            
            if ((expireSignalDemand == CloseBuySellDemand)
               || (IsBullishOrderType(openPendingOrder.Type) && expireSignalDemand == CloseBuyDemand)
               || (IsBearishOrderType(openPendingOrder.Type) && expireSignalDemand == CloseSellDemand))
            {
               wallet.MoveOpenPendingOrderToQueuedClose(openPendingOrder);
            }
         }
      }
      
      // This method puts orders in the pendingCloseOrders collection if the TP/ SL are hit
      void ProcessCloseConditions(Wallet* wallet, TradingModuleDemand closeSignalDemand)
      {
         OrderCollection* openOrders = wallet.GetOpenOrders();
         if (openOrders.Count() == 0)
         {
            return;
         }
         
         double bid = Bid_LibFunc();
         double ask = Ask_LibFunc();

         for (int i = openOrders.Count()-1; i >= 0; i--)
         {
            Order* order = openOrders.Get(i);
            if (order == NULL || CheckPointer(order) == POINTER_INVALID) // Racing condition with terminal transactions
               continue;
            
            bool fullOrderCloseBySignal = 
               (order.Type == ORDER_TYPE_BUY && closeSignalDemand == CloseBuyDemand)
               || (order.Type == ORDER_TYPE_SELL && closeSignalDemand == CloseSellDemand)
               || closeSignalDemand == CloseBuySellDemand;   
 
            bool fullOrderCloseByManualSLTP = AllowManualTPSLChanges && ((order.StopLossManual != 0 && order.Type == ORDER_TYPE_BUY && bid <= order.StopLossManual)
               || (order.StopLossManual != 0 && order.Type == ORDER_TYPE_SELL && ask >= order.StopLossManual)
               || (order.TakeProfitManual != 0 && order.Type == ORDER_TYPE_BUY && bid >= order.TakeProfitManual)
               || (order.TakeProfitManual != 0 && order.Type == ORDER_TYPE_SELL && ask <= order.TakeProfitManual));
 
            // If the conditions above are met it means 100% of the position has to be closed
            bool fullOrderCloseByModuleSLTP = false;
            OrderCloseInfo* hitSlTpCloseInfo = NULL;
            
            if (!fullOrderCloseBySignal && !fullOrderCloseByManualSLTP)
            {
               if (!AllowManualTPSLChanges || order.StopLossManual == 0)
               {
                   // If the old SL/ TP does't fully close the order, we'll evaluate the new info
                   for(int cli = 0; cli < ArraySize(order.CloseInfosSL); cli++)
                   {
                      if (order.CloseInfosSL[cli].Status == Old || order.CloseInfosSL[cli].Status == Executing)
                         continue;
               
                      if (order.CloseInfosSL[cli].IsClosePriceSLHit(order.Type, ask, bid))
                      {
                         if (hitSlTpCloseInfo == NULL
                            || order.CloseInfosSL[cli].Percentage > hitSlTpCloseInfo.Percentage)
                         {
                            hitSlTpCloseInfo = order.CloseInfosSL[cli];
                         }
                      }
                   }
               }

               if (!AllowManualTPSLChanges || order.TakeProfitManual == 0)
               {
                   for(int cli = 0; cli < ArraySize(order.CloseInfosTP); cli++)
                   {
                      if (order.CloseInfosTP[cli].Status == Old || order.CloseInfosTP[cli].Status == Executing)
                         continue;
               
                      if (order.CloseInfosTP[cli].IsClosePriceTPHit(order.Type, ask, bid))
                      {
                         if (hitSlTpCloseInfo == NULL
                            || order.CloseInfosTP[cli].Percentage > hitSlTpCloseInfo.Percentage)
                         {
                            hitSlTpCloseInfo = order.CloseInfosTP[cli];
                         }
                      }
                   }
               }
               
               fullOrderCloseByModuleSLTP = hitSlTpCloseInfo != NULL && hitSlTpCloseInfo.Percentage == 100;
            }
            
            if (fullOrderCloseBySignal 
               || (fullOrderCloseByModuleSLTP && !SendSlTpToBroker)
               || fullOrderCloseByManualSLTP)
            {
               // With the V2 Open module every quote would give a buy/ sell signal. This would re-open orders even on an old signal.
               // The V3 open module doesn't do this, it only gives a buy/ sell signal on fresh signals, thus we shouldn't block closing orders all the time
               // This behavior unfortunately prevents orders from closing without a good reason, so we will only sustain this behavior for V2 modules.
               bool signalActiveOnEveryMetQuote = _openModule.GetVersion() == 2;
               if (signalActiveOnEveryMetQuote)
               {
                  bool closeCancelled = false;

                  // Evaluate prevent open modules, use level 0 so the modules know it's used for evaluating closing orders             
                  TradingModuleDemand finalPreventOpenAdvice = EvaluatePreventOpenModules(wallet, NoneDemand, 0);
                  
                  int orderTypeOfOpeningOrder = wallet.GetOpenOrders().Get(0).Type;
                  
                  // Evaluate Open module as if there are no open orders and inform module of NoOpen demands
                  TradingModuleDemand openDemand = _openModule.EvaluateOpenSignals(wallet, finalPreventOpenAdvice, 1);
                  
                  if ((orderTypeOfOpeningOrder == ORDER_TYPE_BUY && openDemand == OpenBuyDemand)
                     || (orderTypeOfOpeningOrder == ORDER_TYPE_SELL && openDemand == OpenSellDemand)
                     || (openDemand == OpenBuySellDemand))
                  {
                      // block close, because the order will be opened straight away again anyway
                     HandleErrors("Order not closing! Close Signal activated at the same time as Open Signal was activated.");
                     return;
                  }
               }
               
               // Move order to QueuedCloseOrders
               wallet.SetOpenOrderToAwaitingClose(order, hitSlTpCloseInfo);
            }
            else if (hitSlTpCloseInfo != NULL && !SendSlTpToBroker)
            {
               Order* partialCloseOrder = order.SplitOrder(hitSlTpCloseInfo.Percentage);
               if (partialCloseOrder.Lots < 1e-13)
               {
                  // This was the last piece of the order, no need to partially close it
                  delete(partialCloseOrder);
                  wallet.SetOpenOrderToAwaitingClose(order, hitSlTpCloseInfo);
               }
               else
               {
                  partialCloseOrder.ParentOrder = order;
                  if (wallet.AddQueuedCloseOrder(partialCloseOrder))
                  {
                     hitSlTpCloseInfo.Status = Executing;
                  }
               }
            }
         }
      }
};

//
//  OnSignalModuleOrderType
//
enum OnSignalModuleOrderType
{
	IsEnabledForBuyOrderOnSignalModuleOrderType = 1,
	IsEnabledForSellOrderOnSignalModuleOrderType = 2,
	IsEnabledForBuyAndSellOrderOnSignalModuleOrderType = 3
};

//
//  ModuleSignalData
//
class ModuleSignalData
{
	public:
		bool IsActivated;
		bool IsInvalidated;
		double ThresholdValue;
		double InitialProfitValue;
		double HighestProfitSinceSignalPips;
		double LowestProfitSinceSignalPips;

		void ModuleSignalData()
		{
			HighestProfitSinceSignalPips = -DBL_MAX;
			LowestProfitSinceSignalPips = DBL_MAX;
		}

		void ModuleSignalData(ModuleSignalData* modulesignaldata)
		{
			IsActivated = modulesignaldata.IsActivated;
			IsInvalidated = modulesignaldata.IsInvalidated;
			ThresholdValue = modulesignaldata.ThresholdValue;
			InitialProfitValue = modulesignaldata.InitialProfitValue;
			HighestProfitSinceSignalPips = modulesignaldata.HighestProfitSinceSignalPips;
			LowestProfitSinceSignalPips = modulesignaldata.LowestProfitSinceSignalPips;
		}

		void ~ModuleSignalData()
		{
		}
};

//
//  ModuleSignalDataHashMap
//
class ModuleSignalDataHashEntry 
{
    public:
        string _key;
        ModuleSignalData* _val;
        ModuleSignalDataHashEntry *_next;

        ModuleSignalDataHashEntry() 
        {
            _key=NULL;
            _val=NULL;
            _next=NULL;
        }

        ModuleSignalDataHashEntry(string key, ModuleSignalData *val) 
        {
            _key=key;
            _val=val;
            _next=NULL;
        }

        ~ModuleSignalDataHashEntry() 
        {
            if (_val != NULL && CheckPointer(_val) == POINTER_DYNAMIC)
			    delete(_val);
        }
};

class ModuleSignalDataHashMap 
{
    private:
        uint _hashSlots; 
        int _resizeThreshold;
        int _hashEntryCount;
        ModuleSignalDataHashEntry* _buckets[];
   
        bool _adoptValues;
   
        void init(uint size, bool adoptValues)
        {
            _hashSlots = 0;
            _hashEntryCount = 0;
            _adoptValues = adoptValues;
   
            rehash(size);
        }

        uint hash(string s)
        {
            uchar c[];
            uint h = 0;
   
            if (s != NULL) 
            {
                h = 5381;
                int n = StringToCharArray(s,c);
                for(int i = 0 ; i < n ; i++) 
                {
                    h = ((h << 5 ) + h ) + c[i];
                }
            }
           
            return h % _hashSlots;
        }

        uint _foundIndex;
        ModuleSignalDataHashEntry* _foundEntry;
        ModuleSignalDataHashEntry* _foundPrev;
                             
        bool find(string keyName) 
        {
            bool found = false;
           
            _foundPrev = NULL;
            _foundIndex = hash(keyName);

            if (_foundIndex <= _hashSlots) 
            {
                for (ModuleSignalDataHashEntry *e = _buckets[_foundIndex]; e != NULL ; e = e._next)  
                {
                    if (e._key == keyName) 
                    {
                        _foundEntry = e;
                        found=true;
                        break;
                    }
                   
                    _foundPrev = e;
                }
            }
   
            return found;
        }

        uint getSlots() 
        {
            return _hashSlots;
        }
   
        bool rehash(uint newSize) 
        {
            bool ret = false;
            ModuleSignalDataHashEntry* oldTable[];
   
            uint oldSize = _hashSlots;
   
            if (newSize <= getSlots()) 
            {
                ret = false;
            } 
            else if (ArrayResize(_buckets,newSize) != newSize) 
            {
                ret = false;
            } 
            else if (ArrayResize(oldTable,oldSize) != oldSize) 
            {
                ret = false; 
            } 
            else 
            {
                uint i = 0;
                for(i = 0; i < oldSize; i++) oldTable[i] = _buckets[i];
                for(i = 0; i < newSize; i++) _buckets[i] = NULL;
   
                _hashSlots = newSize;
                _resizeThreshold = (int)_hashSlots / 4 * 3; 
   
                for (uint oldHashCode = 0; oldHashCode < oldSize; oldHashCode++) 
                {
                    ModuleSignalDataHashEntry *next = NULL;
   
                    for (ModuleSignalDataHashEntry *e = oldTable[oldHashCode]; e != NULL; e = next)  
                    {
                        next = e._next;
   
                        uint newHashCode = hash(e._key);
   
                        e._next = _buckets[newHashCode];
                        _buckets[newHashCode] = e;
                    }
   
                    oldTable[oldHashCode] = NULL;
                }
                ret = true;
            }
            return ret;
        }
       
    public:
        ModuleSignalDataHashMap() 
        {
            init(13, false);
        }
   
        ModuleSignalDataHashMap(bool adoptValues) 
        {
            init(13, adoptValues);
        }
   
        ModuleSignalDataHashMap(int size) 
        {
            init(size, false);
        }
   
        ModuleSignalDataHashMap(int size, bool adoptValues) 
        {
            init(size, adoptValues);
        }
   
        ~ModuleSignalDataHashMap() 
        {
            for(uint i = 0; i < _hashSlots; i++) 
            {
                ModuleSignalDataHashEntry *nextEntry = NULL;
                for (ModuleSignalDataHashEntry *entry = _buckets[i] ; entry!= NULL ; entry = nextEntry) 
                {
                    nextEntry = entry._next;
   
                    if (_adoptValues && entry._val != NULL && CheckPointer(entry._val) == POINTER_DYNAMIC) 
                    {
                        delete entry._val;
                    }
                    delete entry;
                }
                _buckets[i] = NULL;
            }
        }
   
        bool ContainsKey(string keyName) 
        {
            return find(keyName);
        }
   
        ModuleSignalData* Get(string keyName) 
        {
            ModuleSignalData *obj = NULL;
   
            if (find(keyName)) 
            {
                obj = _foundEntry._val;
            } 

            return obj;
        }

        void GetAllData(ModuleSignalData* &data[])
        {
            for(uint i = 0 ; i < _hashSlots ; i++) 
            {
                ModuleSignalDataHashEntry *nextEntry = NULL;
                for (ModuleSignalDataHashEntry *entry = _buckets[i]; entry != NULL ; entry = nextEntry) 
                {
                    if (entry._val != NULL)
                    {
                        int size = ArraySize(data);
                        ArrayResize(data, size + 1);
                
                        data[size] = entry._val;
                        nextEntry = entry._next;
                    }
                }
            }
        }


        ModuleSignalData* Put(string keyName, ModuleSignalData *obj) 
        {
            ModuleSignalData *ret = NULL;
            
            if (find(keyName)) 
            {
                ret = _foundEntry._val;
   
                if (_adoptValues && _foundEntry._val != NULL && CheckPointer(_foundEntry._val) == POINTER_DYNAMIC ) 
                {
                    delete _foundEntry._val;
                }
   
                _foundEntry._val = obj;
   
            } 
            else 
            {
                ModuleSignalDataHashEntry* e = new ModuleSignalDataHashEntry(keyName,obj);
                ModuleSignalDataHashEntry* first = _buckets[_foundIndex];
                e._next = first;
                _buckets[_foundIndex] = e;
                _hashEntryCount++;
   
                if (_hashEntryCount > _resizeThreshold) 
                {
                    rehash(_hashSlots/2*3); 
                }
            }
            return ret;
        }
   
        bool Delete(string keyName) 
        {
            bool found = false;
   
            if (find(keyName)) 
            {
                ModuleSignalDataHashEntry *next = _foundEntry._next;
                if (_foundPrev != NULL) 
                {
                    _foundPrev._next = next;
                } 
                else 
                {
                    _buckets[_foundIndex] = next;
                }
   
                if (_adoptValues && _foundEntry._val != NULL&& CheckPointer(_foundEntry._val) == POINTER_DYNAMIC) 
                {
                    delete _foundEntry._val;
                }
               
                delete _foundEntry;
                _hashEntryCount--;
                found=true;
            }
            return found;
        }

        int DeleteKeys(const string& keys[])
        {
           int count = 0;
           
           // delete key if found
           for (int i=0; i<ArraySize(keys); i++)
           {
              if (Delete(keys[i]))
                 count++;
           }
           
           return count;
        }
        
        int DeleteKeysExcept(const string& keys[])
        {
           int index = 0, count = 0;
           
           string hashedKeys[];
           ArrayResize(hashedKeys, _hashEntryCount);
           
           for(uint i=0; i < _hashSlots; i++)
           {
              ModuleSignalDataHashEntry *nextEntry = NULL;
              for (ModuleSignalDataHashEntry *entry = _buckets[i] ; entry!= NULL ; entry = nextEntry) 
              {
                 nextEntry = entry._next;
            
                 if (entry._key != NULL) 
                 {
                    hashedKeys[index] = entry._key;
                    index++;
                 }
              }
           }
            
           // delete other keys if found
           for (int i=0; i < ArraySize(hashedKeys); i++)
           {
              bool keep = false;
              for (int j=0; j < ArraySize(keys); j++)
              {
                 if (hashedKeys[i] == keys[j])
                 {
                    keep = true;
                    break;
                 }
              }
              
              if (!keep)
              {
                 if (Delete(hashedKeys[i]))
                    count++;
              }
           }
           
           return count;
        }
};

//
//  Module BaseClass
//
class ModuleCalculationsBase
{
   public:
      static double CalculateOrderCollectionProfit(OrderCollection &orders, ORDER_PROFIT_CALCULATION_TYPE calculationType, int orderType = -1)
      {
         double collectionProfit = 0;
         for(int i = 0; i < orders.Count(); i++)
         {
            Order* order = orders.Get(i);

            if (orderType == -1 || orderType == order.Type)
                collectionProfit += CalculateOrderProfit(order, calculationType);
         }
         
         return collectionProfit;
      }
      
      static double CalculateOrderProfit(Order* order, ORDER_PROFIT_CALCULATION_TYPE calculationType)
      {
         if (calculationType == Pips)
         {
            return order.CalculateProfitPips();
         }
         else if (calculationType == Money)
         {
            return order.CalculateProfitCurrency();
         }
         else if (calculationType == EquityPercentage)
         {
            return order.CalculateProfitEquityPercentage();
         }
         else
         {
            Alert("Can't execute CalculateOrderCollectionProfit. Unknown calculationType: " + IntegerToString(calculationType) );
            return 0;
         }
      }
};
//
//  OpenModule BaseClass
//
class OpenModuleBase : public ITradeStrategyOpenModule
{
   protected:
      AdvisorStrategy* _advisorStrategy;

      IMoneyManager* _moneyManager;

      Order* OpenOrder(Wallet* wallet, ENUM_ORDER_TYPE orderType, bool mustBeVisibleOnChart, double openPrice, datetime expiry = 0)
      {
         Order* order = new Order(mustBeVisibleOnChart);
         order.MagicNumber = MagicNumber;
         order.SymbolCode = OrderSymbolTarget;
         order.Type = orderType;
         order.OpenPrice = openPrice;
         order.PreAssumedLots = _moneyManager.GetLotSize(wallet, order);
         order.LowestProfitPips = DBL_MAX;
         order.HighestProfitPips = -DBL_MAX;
         order.Comment = OrderComment;
         
         if (expiry != 0)
            order.Expiration = TimeCurrent() + expiry;

         if (IsBullishOrderType(order.Type))
         {
            order.StopLoss = -DBL_MAX;
            order.TakeProfit = DBL_MAX;
         }
         else if (IsBearishOrderType(order.Type))
         {
            order.StopLoss = DBL_MAX;
            order.TakeProfit = -DBL_MAX;
         }

         OrderRepository::CalculateAndSetCommision(order);

         return order;
      }
      
   public:
      
      void OpenModuleBase(AdvisorStrategy* advisorStrategy, IMoneyManager* moneyManager)
      {
         _advisorStrategy = advisorStrategy;
         _moneyManager = moneyManager;
      }
      
      virtual void RegisterTradeSignal(ITradingModuleSignal* tradeSignal)
      {
	     // nothing to do here	 
      }
      
      static TradingModuleDemand GetCombinedOpenDemand(TradingModuleDemand &openDemands[])
      {
         TradingModuleDemand result = NoneDemand;
         
         for (int i = 0; i < ArraySize(openDemands); i++) 
         {
            if (result == OpenBuySellDemand)
               return OpenBuySellDemand;
            
            if (openDemands[i] == OpenBuySellDemand)
            {
               result = OpenBuySellDemand;
            }
            else if (result == NoneDemand && openDemands[i] == OpenBuyDemand)
            {
               result = OpenBuyDemand;
            }
            else if (result == NoneDemand && openDemands[i] == OpenSellDemand)
            {
               result = OpenSellDemand;
            }
            else if (result == OpenBuyDemand && openDemands[i] == OpenSellDemand)
            {
               result = OpenBuySellDemand;
            }
            else if (result == OpenSellDemand && openDemands[i] == OpenBuyDemand)
            {
               result = OpenBuySellDemand;
            }
         }
         return result;    
      }

	  static TradingModuleDemand GetCombinedCloseDemand(TradingModuleDemand &closeDemands[])
      {
         TradingModuleDemand result = NoneDemand;
         
         for (int i = 0; i < ArraySize(closeDemands); i++) 
         {
            if (result == CloseBuySellDemand)
               return CloseBuySellDemand;
            
            if (closeDemands[i] == CloseBuySellDemand)
            {
               result = CloseBuySellDemand;
            }
            else if (result == NoneDemand && closeDemands[i] == CloseBuyDemand)
            {
               result = CloseBuyDemand;
            }
            else if (result == NoneDemand && closeDemands[i] == CloseSellDemand)
            {
               result = CloseSellDemand;
            }
            else if (result == CloseBuyDemand && closeDemands[i] == CloseSellDemand)
            {
               result = CloseBuySellDemand;
            }
            else if (result == CloseSellDemand && closeDemands[i] == CloseBuyDemand)
            {
               result = CloseBuySellDemand;
            }
         }
         return result;  
      }

      int GetNumberOfOpenOrders(Wallet* wallet)		
      {		
         return wallet.GetOpenOrders().Count();		
      } 
};

//
//  Multi-order OpenModule 1
//

input int MaxNumberOfOpenOrders = 10; // Open order - Maximum open orders
input bool AllowHedging = true; // Open order - Hedging
bool UseHedging = false;

class MultipleOpenModule_1 : public OpenModuleBase
{
   protected:
      TradingModuleDemand previousSignalDemand;
      
   public:
  
      void MultipleOpenModule_1(AdvisorStrategy* advisorStrategy, MoneyManager* moneyManager)
         : OpenModuleBase(advisorStrategy, moneyManager)
      {
         // configure advisorstrategy for signal only when reset
         _advisorStrategy.SetFireOnlyWhenReset(true, false);
      }

      /*
      // This function evaluates and acts by queueing orders
      */
      TradingModuleDemand Evaluate(Wallet* wallet, TradingModuleDemand preventOpenDemand, int level)
      {
         SignalResultCollection* newSignals = EvaluateSignals(wallet, preventOpenDemand, level);
         if (newSignals.Count() > 0)
         {
            ProcessSignalDemands(wallet, newSignals);
         }
         
         // Transform signals into demand enum
         TradingModuleDemand newSignalDemand = TransformSignalsIntoOpenDemandsEnum(newSignals);

         delete newSignals;        
         return newSignalDemand;
      }

      /*
      // This function is only used for evaluation purposes, but doesn't do any acting
      */
      TradingModuleDemand EvaluateOpenSignals(Wallet* wallet, TradingModuleDemand preventOpenDemand, int requestedEvaluationLevel)
      {
         // Get tradeactions to evaluate
         TradeAction tradeActionsToEvaluate[];
         GetTradeActions(wallet, preventOpenDemand, tradeActionsToEvaluate);
         
         // Previousdemand should always be evaluated
         AddPreviousDemandTradeActionIfMissing(tradeActionsToEvaluate);
         
         int level;
         if (requestedEvaluationLevel == 0)
         {
            level = _moneyManager.GetNextLevel(wallet);
         }
         else
         {
            level = requestedEvaluationLevel;
         }

         SignalResultCollection* openSignalDemands = new SignalResultCollection();
         
         for(int i = 0; i < ArraySize(tradeActionsToEvaluate); i++)
         {
            // Refactor this for performance
            if (tradeActionsToEvaluate[i] == CloseBuyAction || tradeActionsToEvaluate[i] == CloseSellAction)
            {
                continue;
            }

            if (requestedEvaluationLevel == 0)
            {
                // Cap the number of orders by raising the level beyond the number of Expressions (somewhat of a hack) change later
                level = GetTopLevel(tradeActionsToEvaluate[i], level);
                if ((wallet.GetOpenOrderCount() + wallet.GetOpenPendingOrderCount()) >= MaxNumberOfOpenOrders)
                {
                    level += 1;
                }
            }

            SignalResult* signalResult = _advisorStrategy.GetAdvice(tradeActionsToEvaluate[i], level);
            if (signalResult.Activated)
            {
               openSignalDemands.Add(signalResult);
            }
            else
            {
               delete(signalResult);
            }
         }

         // The open signal taking into account that only re-newed signals count for a > 2nd order
         GetOpenDemandBasedOnPreviousOpenDemand(openSignalDemands, level-1);
         
         // Filter preventOpenDemands
         FilterPreventOpenDemand(openSignalDemands, preventOpenDemand);
         
         // Transform signal collection into openDemands enum
         TradingModuleDemand multiOrderOpenSignal = TransformSignalsIntoOpenDemandsEnum(openSignalDemands);
         
         delete openSignalDemands;
         
         return multiOrderOpenSignal;
     }

     TradingModuleDemand EvaluateOpenPendingOrderExpiry(Wallet* wallet, int requestedEvaluationLevel)
     {
        TradingModuleDemand closeDemands[];
      
        // Get tradeactions to evaluate
        TradeAction tradeActionsToEvaluate[];
         
        if (wallet.GetOpenPendingBuyOrderCount() > 0)
        {
           ArrayResize(tradeActionsToEvaluate, ArraySize(tradeActionsToEvaluate) + 1, 8);
           tradeActionsToEvaluate[ArraySize(tradeActionsToEvaluate)-1] = CloseBuyAction;
        }
         
        if (wallet.GetOpenPendingSellOrderCount() > 0)
        {
           ArrayResize(tradeActionsToEvaluate, ArraySize(tradeActionsToEvaluate) + 1, 8);
           tradeActionsToEvaluate[ArraySize(tradeActionsToEvaluate)-1] = CloseSellAction;
        }
         
        for(int i = 0; i < ArraySize(tradeActionsToEvaluate); i++)
        {
           if (_advisorStrategy.GetExpiry(tradeActionsToEvaluate[i], requestedEvaluationLevel))
           {
              if (tradeActionsToEvaluate[i] == CloseBuyAction)
              {
                 ArrayResize(closeDemands, ArraySize(closeDemands) + 1, 8);
                 closeDemands[ArraySize(closeDemands)-1] = CloseBuyDemand;
              }
              else if (tradeActionsToEvaluate[i] == CloseSellAction)
              {
                 ArrayResize(closeDemands, ArraySize(closeDemands) + 1, 8);
                 closeDemands[ArraySize(closeDemands)-1] = CloseSellDemand;
              }
           }
        }
      
        TradingModuleDemand combinedCloseSignalDemand = OpenModuleBase::GetCombinedCloseDemand(closeDemands);
      
        return combinedCloseSignalDemand;
    }

    // The MultipleOpenModule has it's own GetTradeActions because it's not allowed to filter preventOpen
    // or the previousdemand would be broken
    void GetTradeActions(Wallet* wallet, TradingModuleDemand preventOpenDemand, TradeAction& result[])
    {
        TradeAction tempresult[];

        if (UseHedging || (wallet.GetOpenOrderCount() == 0 && wallet.GetOpenPendingOrderCount() == 0))
        {
            ArrayResize(tempresult, ArraySize(tempresult) + 1, 8);
            tempresult[0] = OpenBuyAction;
         
            ArrayResize(tempresult, ArraySize(tempresult) + 1, 8);
            tempresult[1] = OpenSellAction;
        }
        else
        {
           // First open order is buy? then only reevaluate the buy AS levels for adding buys
           Order* firstOrder = NULL;
            
           if (wallet.GetOpenOrders().Count() > 0)
           {
              firstOrder = wallet.GetOpenOrders().Get(0);
              if (CheckPointer(firstOrder) == POINTER_INVALID || CheckPointer(firstOrder) != POINTER_DYNAMIC)
              {
                 firstOrder = NULL;
              }
           }
           else if (wallet.GetOpenPendingOrders().Count() > 0)
           {
              firstOrder = wallet.GetOpenPendingOrders().Get(0);
              if (CheckPointer(firstOrder) == POINTER_INVALID || CheckPointer(firstOrder) != POINTER_DYNAMIC)
              {
                  firstOrder = NULL;
              }
           }
           
           if (firstOrder != NULL) // Racing condition with terminal transactions
           {
               if (IsBullishOrderType(firstOrder.Type))
               {
                  ArrayResize(tempresult, ArraySize(tempresult) + 1, 8);
                  tempresult[0] = OpenBuyAction;
               }
               else if (IsBearishOrderType(firstOrder.Type))
               {
                  ArrayResize(tempresult, ArraySize(tempresult) + 1, 8);
                  tempresult[0] = OpenSellAction;
               }
            }
        }
           
        if (wallet.GetOpenBuyOrderCount() > 0) // pending orders are closed by expiry/ expiry expression only
        {
           ArrayResize(tempresult, ArraySize(tempresult) + 1, 8);
           tempresult[ArraySize(tempresult)-1] = CloseBuyAction;
        }
         
        if (wallet.GetOpenSellOrderCount() > 0) // pending orders are closed by expiry/ expiry expression only
        {
           ArrayResize(tempresult, ArraySize(tempresult) + 1, 8);
           tempresult[ArraySize(tempresult)-1] = CloseSellAction;
        }

        // filter prevent open demands
        for(int i = 0; i < ArraySize(tempresult); i++)
        {         
            if ((preventOpenDemand == NoOpenDemand && (tempresult[i] == OpenBuyAction || tempresult[i] == OpenSellAction))
                   || (preventOpenDemand == NoBuyDemand && tempresult[i] == OpenBuyAction)
                   || (preventOpenDemand == NoSellDemand && tempresult[i] == OpenSellAction))
                {
                    continue;
                }
              
            ArrayResize(result, ArraySize(result) + 1, 8);
            result[ArraySize(result)-1] = tempresult[i];     
        }
      }

      TradingModuleDemand EvaluateCloseSignals(Wallet* wallet, TradingModuleDemand preventOpenDemand)
      {
         TradingModuleDemand closeDemands[];
         
         // Get tradeactions to evaluate
         TradeAction tradeActionsToEvaluate[];
         GetTradeActions(wallet, preventOpenDemand, tradeActionsToEvaluate);
         
         for(int i = 0; i < ArraySize(tradeActionsToEvaluate); i++)
         {         
            // Refactor this for performance
            if (tradeActionsToEvaluate[i] != CloseBuyAction
                && tradeActionsToEvaluate[i] != CloseSellAction)
            {
                continue;
            }

            // Close only has a level 1
            SignalResult* signalResult = _advisorStrategy.GetAdvice(tradeActionsToEvaluate[i], 1);
            if (signalResult.Activated)
            {
               if (tradeActionsToEvaluate[i] == CloseBuyAction)
               {
                  int size = ArraySize(closeDemands);
                  int newSize = size + 1;
                  ArrayResize(closeDemands, newSize, 8);
                  closeDemands[newSize - 1] = CloseBuyDemand;
               }
               else if (tradeActionsToEvaluate[i] == CloseSellAction)
               {
                  int size = ArraySize(closeDemands);
                  int newSize = size + 1;
                  ArrayResize(closeDemands, newSize, 8);
                  closeDemands[newSize - 1] = CloseSellDemand;
               }
            }

            delete(signalResult);
         }

         TradingModuleDemand combinedCloseSignalDemand = OpenModuleBase::GetCombinedCloseDemand(closeDemands);
         
         return combinedCloseSignalDemand;
     } 

     int GetVersion()
     {
         return 3;
     }   
      
    private:
    SignalResultCollection* EvaluateSignals(Wallet* wallet, TradingModuleDemand preventOpenDemand, int requestedEvaluationLevel)
    {
        SignalResultCollection* openDemandsCollection = new SignalResultCollection();
         
        // Get tradeactions to evaluate
        TradeAction tradeActionsToEvaluate[];
        GetTradeActions(wallet, preventOpenDemand, tradeActionsToEvaluate);
         
        // Previousdemand should always be evaluated
        AddPreviousDemandTradeActionIfMissing(tradeActionsToEvaluate);
         
        int moneyManagementLevel;
        if (requestedEvaluationLevel == 0)
        {
            moneyManagementLevel = _moneyManager.GetNextLevel(wallet);
        }
        else
        {
            moneyManagementLevel = requestedEvaluationLevel;
        }
         
        for(int i = 0; i < ArraySize(tradeActionsToEvaluate); i++)
        {
            int tradeActionEvaluationLevel = GetTopLevel(tradeActionsToEvaluate[i], moneyManagementLevel);

            // Cap the number of orders by raising the level beyond the number of Expressions (somewhat of a hack) change later
            if (wallet.GetOpenOrderCount() + wallet.GetOpenPendingOrderCount() >= MaxNumberOfOpenOrders)
            {
                tradeActionEvaluationLevel += 1;
            }

            SignalResult* signalResult = _advisorStrategy.GetAdvice(tradeActionsToEvaluate[i], tradeActionEvaluationLevel);
            if (signalResult.Activated)
            {
                openDemandsCollection.Add(signalResult);
            }
            else
            {
                delete(signalResult);
            }
        }
         
        // The open signal taking into account that only re-newed signals count for a > 2nd order
        GetOpenDemandBasedOnPreviousOpenDemand(openDemandsCollection, GetNumberOfOpenOrders(wallet));
         
        // Set the previous signal for the next evaluation round
        previousSignalDemand = TransformSignalsIntoOpenDemandsEnum(openDemandsCollection);

        // Filter preventOpenDemands
        FilterPreventOpenDemand(openDemandsCollection, preventOpenDemand);
         
        return openDemandsCollection;
    } 

    void ProcessSignalDemands(Wallet* wallet, SignalResultCollection* signalDemands)
    {
        bool openBuy = false;
        bool openSell = false;
     
        for(int i = 0; i < signalDemands.Count(); i++)
        {
            SignalResult* signalResult = signalDemands.Get(i);
            if (!signalResult.Activated)
                continue;
            
            // Open orders based on openDemand
            if (IsBullishOrderType(signalResult.OrderType) && ((wallet.GetOpenBuyOrderCount() + wallet.GetOpenPendingBuyOrderCount()) == 0 || UseHedging))
            {
                openBuy = true;
            }
            
            if (IsBearishOrderType(signalResult.OrderType) && ((wallet.GetOpenSellOrderCount() + wallet.GetOpenPendingSellOrderCount()) == 0 || UseHedging))
            {
                openSell = true;
            }
   
            if (openBuy && openSell && !UseHedging)
            {
                HandleErrors("Open Buy and Open Sell signal activated at the same time, but hedging is disabled. Visit: eabuilderpro.com/troubleshoot-ea.html");
                return;
            }
        }
         
        for(int i = 0; i < signalDemands.Count(); i++)
        {
            SignalResult* signalResult = signalDemands.Get(i);
            if (!signalResult.Activated)
                continue;
               
            wallet.GetQueuedOpenOrders().Add(OpenOrder(wallet, signalResult.OrderType, false, signalResult.OpenPrice, signalResult.ExpiryTimeSpan));   
        }
    }
      
    void GetOpenDemandBasedOnPreviousOpenDemand(SignalResultCollection* openSignalDemands, int numberOfOpenOrders)
    {
        for(int i = openSignalDemands.Count()-1; i >= 0; i--)
        {
            SignalResult* openDemand = openSignalDemands.Get(i);

            if (IsBullishOrderType(openDemand.OrderType) && (previousSignalDemand == OpenBuyDemand || previousSignalDemand == OpenBuySellDemand))
            {
                openSignalDemands.Remove(i);
                delete(openDemand);
            }
            else if (IsBearishOrderType(openDemand.OrderType) && (previousSignalDemand == OpenSellDemand || previousSignalDemand == OpenBuySellDemand))
            {
                openSignalDemands.Remove(i);
                delete(openDemand);
            }
        }
    }
    
    private:
    int GetTopLevel(TradeAction tradeAction, int level)
	{
		int numberOfExpressions = _advisorStrategy.GetNumberOfExpressions(tradeAction);
		   
		if (level > numberOfExpressions)
		{
		    level = numberOfExpressions;
		}
		   
		return level;
	}

    void AddPreviousDemandTradeActionIfMissing(TradeAction& result[])
	{
		if (previousSignalDemand == NoneDemand)
		{
		return;
		}
		   
		if (previousSignalDemand == OpenBuyDemand)
		{
		    AddPreviousDemandTradeAction(result, OpenBuyDemand, OpenBuyAction);
		} else if (previousSignalDemand == OpenSellDemand)
		{
		    AddPreviousDemandTradeAction(result, OpenSellDemand, OpenSellAction);
		} else if (previousSignalDemand == OpenBuySellDemand)
		{
		    AddPreviousDemandTradeAction(result, OpenBuyDemand, OpenBuyAction);
		    AddPreviousDemandTradeAction(result, OpenSellDemand, OpenSellAction);
		}
	}
		
	void AddPreviousDemandTradeAction(TradeAction& result[], TradingModuleDemand demand, TradeAction action)
	{
		bool foundPreviousDemand = false;
		   
		if (previousSignalDemand == demand)
		{
		    for(int i = 0; i < ArraySize(result); i++)
            {        
                if (action == result[i])
                {
                    foundPreviousDemand = true;
                }
            }
            
            if (!foundPreviousDemand)
            {
                ArrayResize(result, ArraySize(result) + 1, 8);
                result[ArraySize(result)-1] = action;     
            }
		} 
	}
		
	void FilterPreventOpenDemand(SignalResultCollection* openSignalDemands, TradingModuleDemand preventOpenDemand)
	{
		if (preventOpenDemand == NoneDemand)
		    return;
		
		for (int i = openSignalDemands.Count()-1; i >= 0; i--)
		{
		    SignalResult* signalDemand = openSignalDemands.Get(i);
		      
		    if (preventOpenDemand == NoOpenDemand
		        || (preventOpenDemand == NoBuyDemand && (IsBullishOrderType(signalDemand.OrderType)))
		        || (preventOpenDemand == NoSellDemand && (IsBearishOrderType(signalDemand.OrderType)))
		        )
	        {
	            openSignalDemands.Remove(i);
                delete(signalDemand);
	        }
		}
	}
		
	TradingModuleDemand TransformSignalsIntoOpenDemandsEnum(SignalResultCollection* openSignalDemands)
	{
        TradingModuleDemand openDemands[];
        for (int i = 0; i < openSignalDemands.Count(); i++)
        {
            if (IsBullishOrderType(openSignalDemands.Get(i).OrderType))
            {
                    int size = ArraySize(openDemands);
                    int newSize = size + 1;
                    ArrayResize(openDemands, newSize, 8);
                    openDemands[newSize-1] = OpenBuyDemand;
            }
            else if (IsBearishOrderType(openSignalDemands.Get(i).OrderType))
            {
                int size = ArraySize(openDemands);
                int newSize = size + 1;
                ArrayResize(openDemands, newSize, 8);
                openDemands[newSize-1] = OpenSellDemand;
            }
        }
         
        return OpenModuleBase::GetCombinedOpenDemand(openDemands);
    }
};

//
//  CloseModule BaseClass
//
class CloseModuleBase : public ITradeStrategyCloseModule
{
   protected:

      double CalculateOrderProfitSingleOrder(Order* order, ORDER_GROUP_TYPE groupType, ORDER_PROFIT_CALCULATION_TYPE calculationType)
      {
         if (calculationType == Pips)
         {
            return order.CalculateProfitPips();
         }
         else if (calculationType == Money)
         {
            return order.CalculateProfitCurrency();
         }
         else if (calculationType == EquityPercentage)
         {
            return order.CalculateProfitEquityPercentage();
         }
         else
         {
            Alert("Can't execute CalculateOrderProfit. Unknown calculationType: " + IntegerToString(calculationType) );
         }
         
         return 0;
      }

      double CalculateOrderClosePrice(Order* order, double referenceStartPrice, ORDER_PROFIT_CALCULATION_TYPE calculationType, double targetValue)
      {
         double result = -1;
         
         if (calculationType == Pips)
         {
            result = order.Type == ORDER_TYPE_BUY ? (referenceStartPrice + (targetValue * PipPoint)) : (referenceStartPrice - (targetValue * PipPoint));
         }
         else if (calculationType == Money)
         {
            double orderEvaluatedLots = order.Lots != 0 ? order.Lots : order.PreAssumedLots;

            double priceOffset = CalculateProfitPriceOffset(targetValue, order.Commission, orderEvaluatedLots);
            
            switch (order.Type) 
   			{
		        case ORDER_TYPE_BUY:
		            result = order.OpenPrice + priceOffset;
		            break;
		        case ORDER_TYPE_SELL:
		            result = order.OpenPrice - priceOffset;
		            break;
			   }
         }
         else if (calculationType == EquityPercentage)
         {
            double orderEvaluatedLots = order.Lots != 0 ? order.Lots : order.PreAssumedLots;

            double priceOffset = CalculateProfitPriceOffset(((AccountEquity_LibFunc() * targetValue) / 100), order.Commission, orderEvaluatedLots);
            
            switch (order.Type) 
   			{
		        case ORDER_TYPE_BUY:
		            result = order.OpenPrice + priceOffset;
		            break;
		        case ORDER_TYPE_SELL:
		            result = order.OpenPrice - priceOffset;
		            break;
			   }
         }
         else
         {
            Alert("Can't execute CalculateOrderProfit. Unknown calculationType: " + IntegerToString(calculationType));
         }
         
         return result;
      }

      // orderEvaluated must not be included in the otherOpenOrderTickets array
      double CalculateOrderCollectionClosePrice(Wallet* wallet, ulong &otherOpenOrderTickets[], Order* orderEvaluated, ORDER_PROFIT_CALCULATION_TYPE calculationType, double targetValue, SL_TP_DIRECTION& direction)
      {
         double result = -1;
         
         double orderEvaluatedWeight = GetWeight(calculationType, orderEvaluated);
         double orderEvaluatedOpenPrice = orderEvaluated.OpenPrice != NULL ? orderEvaluated.OpenPrice : GetOpenPrice(orderEvaluated.Type);
         
         double totalWeight = 0;
         double totalContraWeight = 0;
         double totalProfit = 0;
         bool isHedgeGroup = false;
         
         // Calculate total relative (compared to the first order) order weight
         for (int i = 0; i < ArraySize(otherOpenOrderTickets); i++)
         {
            Order* order = wallet.GetOpenOrder(otherOpenOrderTickets[i]);
            if (calculationType == Pips)
            { 
               totalProfit += order.CalculateProfitPips();
            }
            else if (calculationType == Money)
            {
               totalProfit += order.CalculateProfitCurrency();
            }
            else if (calculationType == EquityPercentage)
            {
               totalProfit += order.CalculateProfitEquityPercentage();
            }

            if (order.Type == orderEvaluated.Type)
            {
               totalWeight += GetWeight(calculationType, order);
            }
            else
            {
               isHedgeGroup = true;
               totalContraWeight += GetWeight(calculationType, order);
            }
         }
         
         double weightMultiplicationFactor = (totalWeight + orderEvaluatedWeight - totalContraWeight) / orderEvaluatedWeight;
         if (weightMultiplicationFactor < 1e-5 && weightMultiplicationFactor > -1e-5)
         {
            return -1; // Since weights are equally strong the close price will be infinite far away
         }
         
         double basePrice = 0;
         // If you're a buy order without sell orders (without hedging) or you're hedging but you've got the biggest weight, then your close price counts for all orders, also for the contra orders, to make sure all orders close on the same quote
         bool addValue = false; // Add or Substract from basePrice
         if (orderEvaluated.Type == ORDER_TYPE_BUY)
         {
            if (!isHedgeGroup || totalWeight + orderEvaluatedWeight > totalContraWeight)
            {
               addValue = true;
               basePrice = Bid_LibFunc();
               direction = targetValue >= 0 ? Favorable : Unfavorable;
            }
            else
            {
               addValue = false;
               basePrice = Ask_LibFunc();
               direction = targetValue <= 0 ? Favorable : Unfavorable;
            }
         }
         else if (orderEvaluated.Type == ORDER_TYPE_SELL)
         {
            if (!isHedgeGroup || totalWeight + orderEvaluatedWeight > totalContraWeight)
            {
               addValue = false;
               basePrice = Ask_LibFunc();
               direction = targetValue >= 0 ? Favorable : Unfavorable;
            }   
            else
            {
               addValue = true;
               basePrice = Bid_LibFunc();
               direction = targetValue <= 0 ? Favorable : Unfavorable;
            }
         }
         
         if (calculationType == Pips)
         {
            double currentProfit = orderEvaluated.CalculateProfitPips();
            totalProfit += currentProfit;

            targetValue = targetValue - totalProfit;

            // targetValue is devided by the surplus number of orders going in the target direction
            targetValue = targetValue / MathAbs((totalWeight + orderEvaluatedWeight) - totalContraWeight);
            
            result = addValue
               ? basePrice + (targetValue * PipPoint)
               : basePrice - (targetValue * PipPoint); 
         }
         else if (calculationType == Money)
         {
            double currentProfit = orderEvaluated.CalculateProfitCurrency();
            totalProfit += currentProfit;
         
            targetValue = targetValue - totalProfit;
            
            double weight = MathAbs((totalWeight + orderEvaluatedWeight) - totalContraWeight); 
            
            double priceOffsetToMoneyGoal = CalculateProfitPriceOffset(targetValue, orderEvaluated.Commission, weight);
            
            result = addValue
               ? basePrice + priceOffsetToMoneyGoal
               : basePrice - priceOffsetToMoneyGoal;
         }
         else if (calculationType == EquityPercentage)
         {
            double currentProfit = orderEvaluated.CalculateProfitEquityPercentage();
            totalProfit += currentProfit;
         
            targetValue = targetValue - totalProfit;
            
            double weight = MathAbs((totalWeight + orderEvaluatedWeight) - totalContraWeight); 
         
            double priceOffsetToEquityGoal = CalculateProfitPriceOffset(((AccountBalance_LibFunc() * targetValue) / 100), orderEvaluated.Commission, weight);
            
            result = addValue
               ? basePrice + priceOffsetToEquityGoal
               : basePrice - priceOffsetToEquityGoal;
         }
         else
         {
            Alert("Can't execute CalculateOrderCollectionClosePrice. Unknown calculationType: " + IntegerToString(calculationType) );
         }
      
         return result;
      }

      double CalculateProfitPriceOffset(double targetPrice, double commission, double volume)
      {
         double tickValue = SymbolInfoDouble(OrderSymbolTarget, SYMBOL_TRADE_TICK_VALUE_LOSS);
         double tickSize = SymbolInfoDouble(OrderSymbolTarget, SYMBOL_TRADE_TICK_SIZE);
         double offset = targetPrice / ((tickValue / tickSize) * volume);
         
         return offset;
      }

      static double GetOpenPrice(int orderType)
      {
         switch (orderType)
         {
             case ORDER_TYPE_SELL:
                 return Bid_LibFunc();
             case ORDER_TYPE_BUY:
                 return Ask_LibFunc();
             default:
                 return 0;
         }
      }
      
      static double GetClosePrice(int orderType)
      {
         switch (orderType)
         {
             case ORDER_TYPE_SELL:
                 return Ask_LibFunc();
             case ORDER_TYPE_BUY:
                 return Bid_LibFunc();
             default:
                 return 0;
         }
      }

      static double GetWeight(ORDER_PROFIT_CALCULATION_TYPE calculationType, Order* order)
      {
         if (calculationType == Pips)
         { 
            return 1; // The weight of an order in pips is always 1. An order with a volume of 0.01 has the same weight as an order of 1 lot in pips.            
         }
         else
         {
            return order.Lots != 0 ? order.Lots : order.PreAssumedLots;
         }
      }
      
public:
      virtual void RegisterTradeSignal(ITradingModuleSignal* tradeSignal)
      {
	     // nothing to do here	 
      }
      
      virtual void RegisterTradeValue(ITradingModuleValue* tradeValue)
      {
	     // nothing to do here	 
      }
      
      static TradingModuleDemand GetCombinedCloseDemand(TradingModuleDemand &closeDemands[])
      {
         TradingModuleDemand result = NoneDemand;
         
         for (int i = 0; i < ArraySize(closeDemands); i++) 
		 {
            if (result == CloseBuySellDemand)
               return CloseBuySellDemand;
            
            if (closeDemands[i] == CloseBuySellDemand)
            {
               result = CloseBuySellDemand;
            }
            else if (result == NoneDemand && closeDemands[i] == CloseBuyDemand)
            {
               result = CloseBuyDemand;
            }
            else if (result == NoneDemand && closeDemands[i] == CloseSellDemand)
            {
               result = CloseSellDemand;
            }
            else if (result == CloseBuyDemand && closeDemands[i] == CloseSellDemand)
            {
               result = CloseBuySellDemand;
            }
            else if (result == CloseSellDemand && closeDemands[i] == CloseBuyDemand)
            {
               result = CloseBuySellDemand;
            }
         }
         return result;  
      }    

      virtual ORDER_GROUP_TYPE GetOrderGroupingType() = NULL;   
};
//
//  TrailingTakeProfitOnSignalV2 CloseModule 1
//

input double TrailingTakeProfitOnSignalV2OffsetPipValue1 = 5; // Take profit - Conditional Pro (1) - Trail distance (pips)
input double TrailingTakeProfitOnSignalV2StepFactor1 = 0; // Take profit - Conditional Pro (1) - Trail step size
OnSignalModuleOrderType TrailingTakeProfitOnSignalV2ModuleOrderType1 = 1;
input int TrailingTakeProfitOnSignalV2ClosePercentage1 = 100; // Take profit - Conditional Pro (1) - Close percentage
input bool TrailingTakeProfitOnSignalV2ResetAfterPartialClose1 = false; // Take profit - Conditional Pro (1) - Reuse module after partial close

ORDER_GROUP_TYPE TrailingTakeProfitOnSignalV2ModuleGroupType1 = Single;

class TrailingTakeProfitOnSignalV2CloseModule_1 : public CloseModuleBase
{
   private:
      ITradingModuleSignal* _trailingTakeProfitSignal;      
      ITradingModuleSignal* _trailingTakeProfitInvalidationSignal;
      ITradingModuleValue* _trailingTakeProfitValue;      
      ModuleSignalDataHashMap* _signalDataByOrderTicket;      

   public:
      void TrailingTakeProfitOnSignalV2CloseModule_1()
      {
         _trailingTakeProfitSignal = NULL;
         _trailingTakeProfitInvalidationSignal = NULL;
         _trailingTakeProfitValue = NULL;
         _signalDataByOrderTicket = new ModuleSignalDataHashMap(true);
      }

      void ~TrailingTakeProfitOnSignalV2CloseModule_1()
      {
         if (_trailingTakeProfitSignal != NULL)
             delete(_trailingTakeProfitSignal);
         
         if (_trailingTakeProfitInvalidationSignal != NULL)
             delete(_trailingTakeProfitInvalidationSignal);

         if (_trailingTakeProfitValue != NULL)
             delete(_trailingTakeProfitValue);
         
         delete(_signalDataByOrderTicket);
      }
      
      TradingModuleDemand Evaluate(Wallet* wallet, TradingModuleDemand demand, int level = 1)
      {
         string keysToKeep[];

         OrderCollection* openOrders = wallet.GetOpenOrders();
         
         for(int i = 0; i < openOrders.Count(); i++)
         {
            Order* openOrder = openOrders.Get(i);
            if (openOrder == NULL || CheckPointer(openOrder) == POINTER_INVALID) // Racing condition with terminal transactions
                continue;
            
            if ((TrailingTakeProfitOnSignalV2ModuleOrderType1 == 0)
            || (openOrder.Type == ORDER_TYPE_BUY 
                && (TrailingTakeProfitOnSignalV2ModuleOrderType1 != 1 && TrailingTakeProfitOnSignalV2ModuleOrderType1 != 3))
            || (openOrder.Type == ORDER_TYPE_SELL 
                && (TrailingTakeProfitOnSignalV2ModuleOrderType1 != 2 && TrailingTakeProfitOnSignalV2ModuleOrderType1 != 3))
            )
            {
                continue;
            }

            // Don't throw away data from open orders
            int newSize = ArraySize(keysToKeep) + 1;
		    ArrayResize(keysToKeep, newSize);
		    keysToKeep[newSize-1] = IntegerToString(openOrder.Ticket);

            if (openOrder.IsAlreadyProcessedByModule("TrailingTakeProfitOnSignalV2CloseModule_1", openOrder.CloseInfosTP))
            {
               if (!TrailingTakeProfitOnSignalV2ResetAfterPartialClose1)
               {
                  continue;
               }
               
               openOrder.RemoveTPInfo("TrailingTakeProfitOnSignalV2CloseModule_1");
               _signalDataByOrderTicket.Delete(IntegerToString(openOrder.Ticket));
            }

            EvaluateOrder(wallet, openOrder);
         }
         
         _signalDataByOrderTicket.DeleteKeysExcept(keysToKeep);

         return NoneDemand;
      }

      // order can be an executed order or a non-executed order (for pre-evaluation)
      void EvaluateOrder(Wallet* wallet, Order* order)
      {
         if ((TrailingTakeProfitOnSignalV2ModuleOrderType1 == 0)
         || (order.Type == ORDER_TYPE_BUY 
            && (TrailingTakeProfitOnSignalV2ModuleOrderType1 != 1 && TrailingTakeProfitOnSignalV2ModuleOrderType1 != 3))
         || (order.Type == ORDER_TYPE_SELL 
            && (TrailingTakeProfitOnSignalV2ModuleOrderType1 != 2 && TrailingTakeProfitOnSignalV2ModuleOrderType1 != 3))
         )
         {
            return;
         }

         bool signalEvaluated = false, invalidationSignalEvaluated = false, signalEvaluatedResult = false, invalidationSignalEvaluatedResult = false;
         
         ModuleSignalData* signalData = NULL;
            
         string orderKey = IntegerToString(order.Ticket);
         if (!_signalDataByOrderTicket.ContainsKey(orderKey))
         {
            signalData = new ModuleSignalData();
            signalData.IsActivated = false;
            signalData.IsInvalidated  = false;
            
            // 0 is an order which isn't executed yet
            if (orderKey != "0")
               _signalDataByOrderTicket.Put(orderKey, signalData);
         }
               
         // check the signal evaluator for this order
         if (signalData == NULL)
            signalData = _signalDataByOrderTicket.Get(orderKey);
               
         if (!signalData.IsActivated)
         {
            // evaluate the signal
            if (!signalEvaluated)
            {
                signalEvaluatedResult = _trailingTakeProfitSignal == NULL || _trailingTakeProfitSignal.Evaluate(order);
                signalEvaluated = true;
            } 
                
            if (!signalEvaluatedResult)
            {
                if (orderKey == "0") // cleanup temp data not managed by the module
                    delete(signalData);
                  
                return;
            }

            signalData.IsActivated = true;
 
            double valueEvaluatedResult = _trailingTakeProfitValue.Evaluate(order);
            signalData.ThresholdValue = order.CalculateValueDifferencePips(valueEvaluatedResult);
            signalData.InitialProfitValue = order.CalculateProfitPips(); 
         }
         else if (_trailingTakeProfitInvalidationSignal != NULL && !signalData.IsInvalidated)
         {
            // evaluate the signal
            if (!invalidationSignalEvaluated)
            {
                invalidationSignalEvaluatedResult = _trailingTakeProfitInvalidationSignal.Evaluate(order);
                invalidationSignalEvaluated = true;
            } 
                
            if (invalidationSignalEvaluatedResult)
            {
                signalData.IsInvalidated = true;
                order.RemoveTPInfo("TrailingTakeProfitOnSignalV2CloseModule_1");
                return;
            }
         }

         if (signalData.IsInvalidated)
            return;
            
         double profit = order.CalculateProfitPips();
         if (profit < signalData.LowestProfitSinceSignalPips)
         {
            double differenceProfitThreshold = profit - signalData.InitialProfitValue;
            double pipsDroppedInclRatio = differenceProfitThreshold * TrailingTakeProfitOnSignalV2StepFactor1;
            double trailStartPips = signalData.ThresholdValue + TrailingTakeProfitOnSignalV2OffsetPipValue1;
            double currentTrailPips = trailStartPips + pipsDroppedInclRatio;
            double possibleNewTakeProfitPips = profit - currentTrailPips;
            
            // Calculate where it should stop
            double possibleNewTakeProfit = 0;
            double closePrice = 0;
            switch (order.Type) 
            {
                case ORDER_TYPE_BUY:
                    closePrice = CloseModuleBase::GetClosePrice(order.Type);
                    possibleNewTakeProfit = closePrice - (possibleNewTakeProfitPips * PipPoint);
                    break;
                case ORDER_TYPE_SELL:
                    closePrice = CloseModuleBase::GetClosePrice(order.Type);
                    possibleNewTakeProfit = closePrice + (possibleNewTakeProfitPips * PipPoint);
                    break;
            }
               
            if (order.SetTPInfo("TrailingTakeProfitOnSignalV2CloseModule_1", possibleNewTakeProfit, TrailingTakeProfitOnSignalV2ClosePercentage1, Favorable))
            {
                signalData.LowestProfitSinceSignalPips = profit;
            }
         }
            
         if (orderKey == "0") // cleanup temp data not managed by the module
            delete(signalData);
      }

      virtual void RegisterTradeSignal(ITradingModuleSignal* signal)
	  {
	     // assign the signal if not yet assigned
         if (_trailingTakeProfitSignal == NULL && signal.GetName() == "Signal")
         {
            _trailingTakeProfitSignal = signal;
         }
         else if (_trailingTakeProfitInvalidationSignal == NULL && signal.GetName() == "InvalidationSignal")
         {
            _trailingTakeProfitInvalidationSignal = signal;
         }
	  }
 
      virtual void RegisterTradeValue(ITradingModuleValue* tradeValue)
	  {
	     // assign the value if not yet assigned
         if (_trailingTakeProfitValue == NULL && tradeValue.GetName() == "RefValue")
            _trailingTakeProfitValue = tradeValue;
	  }

      ORDER_GROUP_TYPE GetOrderGroupingType()
      {
         return TrailingTakeProfitOnSignalV2ModuleGroupType1;
      }

      bool UsesOrderTrailing()
      {
         return TrailingTakeProfitOnSignalV2StepFactor1 != 0;
      }
      
      string GetWarning()
      {
        return NULL;
      }
};

input group "OnSignalTPV2_Signal31052347_Constants"
input double OnSignalTPV2_Signal31052347_Const_DoNotEditZeroIsBreakeven = 0;
input double OnSignalTPV2_Signal31052347_Const_InpRiskReductionMinTrades = 3;
input double OnSignalTPV2_Signal31052347_Const_ProfitMoneyBuyOrders = 0;
input double OnSignalTPV2_Signal31052347_Const_QQECloseBuyLevel = 50;
input double OnSignalTPV2_Signal31052347_Const_RecoveryAfterOrderNoEdit = 1;

class TMSOnSignalTPV2_SignalId31052347 : public ITradingModuleSignal
{
   public:

   void TMSOnSignalTPV2_SignalId31052347()
   {
   }

   string GetName()
   {
      return "Signal";
   }

   bool Evaluate(Order* openOrderInContext = NULL)
   {
      
      return (((OrderLib::NumberOfOpenBuyOrders() >= OnSignalTPV2_Signal31052347_Const_InpRiskReductionMinTrades)
 && (OrderLib::ProfitMoneyBuyOrders() > OnSignalTPV2_Signal31052347_Const_ProfitMoneyBuyOrders)
)
 || ((((fn_QQEAdv_QQE7142(Symbol(),0,1) >= OnSignalTPV2_Signal31052347_Const_QQECloseBuyLevel)
 && (OrderLib::ProfitMoneyBuyOrders() <= OnSignalTPV2_Signal31052347_Const_DoNotEditZeroIsBreakeven)
)
 && (OrderLib::NumberOfOpenBuyOrders() >= OnSignalTPV2_Signal31052347_Const_RecoveryAfterOrderNoEdit)
)
 && (OrderLib::NumberOfOpenBuyOrders() < 3)
)
)
;
   }
};

class TMVOnSignalTPV2_RefValueId31052348 : public ITradingModuleValue
{
   public:

   void TMVOnSignalTPV2_RefValueId31052348()
   {
   }

   string GetName()
   {
      return "RefValue";
   }

   double Evaluate(Order* openOrderInContext = NULL)
   {
      
      return fn_TheBreakEvenIndi_Breakeven1(Symbol(),0,0);
   }
};

//
//  TrailingTakeProfitOnSignalV2 CloseModule 2
//

input double TrailingTakeProfitOnSignalV2OffsetPipValue2 = 5; // Take profit - Conditional Pro (2) - Trail distance (pips)
input double TrailingTakeProfitOnSignalV2StepFactor2 = 0; // Take profit - Conditional Pro (2) - Trail step size
OnSignalModuleOrderType TrailingTakeProfitOnSignalV2ModuleOrderType2 = 2;
input int TrailingTakeProfitOnSignalV2ClosePercentage2 = 100; // Take profit - Conditional Pro (2) - Close percentage
input bool TrailingTakeProfitOnSignalV2ResetAfterPartialClose2 = false; // Take profit - Conditional Pro (2) - Reuse module after partial close

ORDER_GROUP_TYPE TrailingTakeProfitOnSignalV2ModuleGroupType2 = Single;

class TrailingTakeProfitOnSignalV2CloseModule_2 : public CloseModuleBase
{
   private:
      ITradingModuleSignal* _trailingTakeProfitSignal;      
      ITradingModuleSignal* _trailingTakeProfitInvalidationSignal;
      ITradingModuleValue* _trailingTakeProfitValue;      
      ModuleSignalDataHashMap* _signalDataByOrderTicket;      

   public:
      void TrailingTakeProfitOnSignalV2CloseModule_2()
      {
         _trailingTakeProfitSignal = NULL;
         _trailingTakeProfitInvalidationSignal = NULL;
         _trailingTakeProfitValue = NULL;
         _signalDataByOrderTicket = new ModuleSignalDataHashMap(true);
      }

      void ~TrailingTakeProfitOnSignalV2CloseModule_2()
      {
         if (_trailingTakeProfitSignal != NULL)
             delete(_trailingTakeProfitSignal);
         
         if (_trailingTakeProfitInvalidationSignal != NULL)
             delete(_trailingTakeProfitInvalidationSignal);

         if (_trailingTakeProfitValue != NULL)
             delete(_trailingTakeProfitValue);
         
         delete(_signalDataByOrderTicket);
      }
      
      TradingModuleDemand Evaluate(Wallet* wallet, TradingModuleDemand demand, int level = 1)
      {
         string keysToKeep[];

         OrderCollection* openOrders = wallet.GetOpenOrders();
         
         for(int i = 0; i < openOrders.Count(); i++)
         {
            Order* openOrder = openOrders.Get(i);
            if (openOrder == NULL || CheckPointer(openOrder) == POINTER_INVALID) // Racing condition with terminal transactions
                continue;
            
            if ((TrailingTakeProfitOnSignalV2ModuleOrderType2 == 0)
            || (openOrder.Type == ORDER_TYPE_BUY 
                && (TrailingTakeProfitOnSignalV2ModuleOrderType2 != 1 && TrailingTakeProfitOnSignalV2ModuleOrderType2 != 3))
            || (openOrder.Type == ORDER_TYPE_SELL 
                && (TrailingTakeProfitOnSignalV2ModuleOrderType2 != 2 && TrailingTakeProfitOnSignalV2ModuleOrderType2 != 3))
            )
            {
                continue;
            }

            // Don't throw away data from open orders
            int newSize = ArraySize(keysToKeep) + 1;
		    ArrayResize(keysToKeep, newSize);
		    keysToKeep[newSize-1] = IntegerToString(openOrder.Ticket);

            if (openOrder.IsAlreadyProcessedByModule("TrailingTakeProfitOnSignalV2CloseModule_2", openOrder.CloseInfosTP))
            {
               if (!TrailingTakeProfitOnSignalV2ResetAfterPartialClose2)
               {
                  continue;
               }
               
               openOrder.RemoveTPInfo("TrailingTakeProfitOnSignalV2CloseModule_2");
               _signalDataByOrderTicket.Delete(IntegerToString(openOrder.Ticket));
            }

            EvaluateOrder(wallet, openOrder);
         }
         
         _signalDataByOrderTicket.DeleteKeysExcept(keysToKeep);

         return NoneDemand;
      }

      // order can be an executed order or a non-executed order (for pre-evaluation)
      void EvaluateOrder(Wallet* wallet, Order* order)
      {
         if ((TrailingTakeProfitOnSignalV2ModuleOrderType2 == 0)
         || (order.Type == ORDER_TYPE_BUY 
            && (TrailingTakeProfitOnSignalV2ModuleOrderType2 != 1 && TrailingTakeProfitOnSignalV2ModuleOrderType2 != 3))
         || (order.Type == ORDER_TYPE_SELL 
            && (TrailingTakeProfitOnSignalV2ModuleOrderType2 != 2 && TrailingTakeProfitOnSignalV2ModuleOrderType2 != 3))
         )
         {
            return;
         }

         bool signalEvaluated = false, invalidationSignalEvaluated = false, signalEvaluatedResult = false, invalidationSignalEvaluatedResult = false;
         
         ModuleSignalData* signalData = NULL;
            
         string orderKey = IntegerToString(order.Ticket);
         if (!_signalDataByOrderTicket.ContainsKey(orderKey))
         {
            signalData = new ModuleSignalData();
            signalData.IsActivated = false;
            signalData.IsInvalidated  = false;
            
            // 0 is an order which isn't executed yet
            if (orderKey != "0")
               _signalDataByOrderTicket.Put(orderKey, signalData);
         }
               
         // check the signal evaluator for this order
         if (signalData == NULL)
            signalData = _signalDataByOrderTicket.Get(orderKey);
               
         if (!signalData.IsActivated)
         {
            // evaluate the signal
            if (!signalEvaluated)
            {
                signalEvaluatedResult = _trailingTakeProfitSignal == NULL || _trailingTakeProfitSignal.Evaluate(order);
                signalEvaluated = true;
            } 
                
            if (!signalEvaluatedResult)
            {
                if (orderKey == "0") // cleanup temp data not managed by the module
                    delete(signalData);
                  
                return;
            }

            signalData.IsActivated = true;
 
            double valueEvaluatedResult = _trailingTakeProfitValue.Evaluate(order);
            signalData.ThresholdValue = order.CalculateValueDifferencePips(valueEvaluatedResult);
            signalData.InitialProfitValue = order.CalculateProfitPips(); 
         }
         else if (_trailingTakeProfitInvalidationSignal != NULL && !signalData.IsInvalidated)
         {
            // evaluate the signal
            if (!invalidationSignalEvaluated)
            {
                invalidationSignalEvaluatedResult = _trailingTakeProfitInvalidationSignal.Evaluate(order);
                invalidationSignalEvaluated = true;
            } 
                
            if (invalidationSignalEvaluatedResult)
            {
                signalData.IsInvalidated = true;
                order.RemoveTPInfo("TrailingTakeProfitOnSignalV2CloseModule_2");
                return;
            }
         }

         if (signalData.IsInvalidated)
            return;
            
         double profit = order.CalculateProfitPips();
         if (profit < signalData.LowestProfitSinceSignalPips)
         {
            double differenceProfitThreshold = profit - signalData.InitialProfitValue;
            double pipsDroppedInclRatio = differenceProfitThreshold * TrailingTakeProfitOnSignalV2StepFactor2;
            double trailStartPips = signalData.ThresholdValue + TrailingTakeProfitOnSignalV2OffsetPipValue2;
            double currentTrailPips = trailStartPips + pipsDroppedInclRatio;
            double possibleNewTakeProfitPips = profit - currentTrailPips;
            
            // Calculate where it should stop
            double possibleNewTakeProfit = 0;
            double closePrice = 0;
            switch (order.Type) 
            {
                case ORDER_TYPE_BUY:
                    closePrice = CloseModuleBase::GetClosePrice(order.Type);
                    possibleNewTakeProfit = closePrice - (possibleNewTakeProfitPips * PipPoint);
                    break;
                case ORDER_TYPE_SELL:
                    closePrice = CloseModuleBase::GetClosePrice(order.Type);
                    possibleNewTakeProfit = closePrice + (possibleNewTakeProfitPips * PipPoint);
                    break;
            }
               
            if (order.SetTPInfo("TrailingTakeProfitOnSignalV2CloseModule_2", possibleNewTakeProfit, TrailingTakeProfitOnSignalV2ClosePercentage2, Favorable))
            {
                signalData.LowestProfitSinceSignalPips = profit;
            }
         }
            
         if (orderKey == "0") // cleanup temp data not managed by the module
            delete(signalData);
      }

      virtual void RegisterTradeSignal(ITradingModuleSignal* signal)
	  {
	     // assign the signal if not yet assigned
         if (_trailingTakeProfitSignal == NULL && signal.GetName() == "Signal")
         {
            _trailingTakeProfitSignal = signal;
         }
         else if (_trailingTakeProfitInvalidationSignal == NULL && signal.GetName() == "InvalidationSignal")
         {
            _trailingTakeProfitInvalidationSignal = signal;
         }
	  }
 
      virtual void RegisterTradeValue(ITradingModuleValue* tradeValue)
	  {
	     // assign the value if not yet assigned
         if (_trailingTakeProfitValue == NULL && tradeValue.GetName() == "RefValue")
            _trailingTakeProfitValue = tradeValue;
	  }

      ORDER_GROUP_TYPE GetOrderGroupingType()
      {
         return TrailingTakeProfitOnSignalV2ModuleGroupType2;
      }

      bool UsesOrderTrailing()
      {
         return TrailingTakeProfitOnSignalV2StepFactor2 != 0;
      }
      
      string GetWarning()
      {
        return NULL;
      }
};

input group "OnSignalTPV2_Signal31052355_Constants"
input double OnSignalTPV2_Signal31052355_Const_DoNotEditZeroIsBreakeven = 0;
input double OnSignalTPV2_Signal31052355_Const_InpRiskReductionMinTrades = 3;
input double OnSignalTPV2_Signal31052355_Const_ProfitMoneySellOrders = 0;
input double OnSignalTPV2_Signal31052355_Const_QQECloseSellLevel = 50;
input double OnSignalTPV2_Signal31052355_Const_RecoveryAfterOrderNoEdit = 1;

class TMSOnSignalTPV2_SignalId31052355 : public ITradingModuleSignal
{
   public:

   void TMSOnSignalTPV2_SignalId31052355()
   {
   }

   string GetName()
   {
      return "Signal";
   }

   bool Evaluate(Order* openOrderInContext = NULL)
   {
      
      return (((OrderLib::NumberOfOpenSellOrders() >= OnSignalTPV2_Signal31052355_Const_InpRiskReductionMinTrades)
 && (OrderLib::ProfitMoneySellOrders() > OnSignalTPV2_Signal31052355_Const_ProfitMoneySellOrders)
)
 || ((((fn_QQEAdv_QQE7142(Symbol(),0,1) <= OnSignalTPV2_Signal31052355_Const_QQECloseSellLevel)
 && (OrderLib::ProfitMoneySellOrders() <= OnSignalTPV2_Signal31052355_Const_DoNotEditZeroIsBreakeven)
)
 && (OrderLib::NumberOfOpenSellOrders() >= OnSignalTPV2_Signal31052355_Const_RecoveryAfterOrderNoEdit)
)
 && (OrderLib::NumberOfOpenSellOrders() < 3)
)
)
;
   }
};

class TMVOnSignalTPV2_RefValueId31052356 : public ITradingModuleValue
{
   public:

   void TMVOnSignalTPV2_RefValueId31052356()
   {
   }

   string GetName()
   {
      return "RefValue";
   }

   double Evaluate(Order* openOrderInContext = NULL)
   {
      
      return fn_TheBreakEvenIndi_Breakeven1(Symbol(),1,0);
   }
};

//
//  PreventOpenModule BaseClass
//
class PreventOpenModuleBase : public ITradeStrategyModule
{
   public:
      virtual void RegisterTradeSignal(ITradingModuleSignal* tradeSignal)
      {
	     // nothing to do here	 
      }
      
      static TradingModuleDemand GetCombinedPreventOpenDemand(TradingModuleDemand &preventOpenAdvices[])
      {
         TradingModuleDemand result = NoneDemand;
         
         for (int i = 0; i < ArraySize(preventOpenAdvices); i++) 
         {
            if (result == NoOpenDemand)
               return NoOpenDemand;
            
            if (preventOpenAdvices[i] == NoOpenDemand)
            {
               result = NoOpenDemand;
            }
            else if (result == NoneDemand && preventOpenAdvices[i] == NoBuyDemand)
            {
               result = NoBuyDemand;
            }
            else if (result == NoneDemand && preventOpenAdvices[i] == NoSellDemand)
            {
               result = NoSellDemand;
            }
            else if (result == NoBuyDemand && preventOpenAdvices[i] == NoSellDemand)
            {
               result = NoOpenDemand;
            }
            else if (result == NoSellDemand && preventOpenAdvices[i] == NoBuyDemand)
            {
               result = NoOpenDemand;
            }
         }
         return result;    
      }    
};

//
//  MaxSpread PreventOpenModule 1
//

input double MaxSpreadInPips1 = 30; // Maximum spread - Maximum spread (pips)

class MaxSpreadPreventOpenModule_1: public PreventOpenModuleBase
{
   public:
    void MaxSpreadPreventOpenModule_1()
    {
    }

    TradingModuleDemand Evaluate(Wallet* wallet, TradingModuleDemand demand, int level = 1)
    {
        if (level == 0) // never evaluate when evaluating close conditions
        {
            return NoneDemand;
        }

        TradingModuleDemand result = NoneDemand;

        double spread = MathAbs(Bid_LibFunc() - Ask_LibFunc());    
        if (spread / PipPoint > MaxSpreadInPips1)
        {
            return NoOpenDemand;
        }
        
        return result;
    }
};

//
//  Pipgap PreventOpenModule 1
//

input double PipGapInPips1 = 10; // Pip gap between orders (1) - Pip gap (pips)
input bool PipGapPositiveEnabled1 = false; // Pip gap between orders (1) - Apply to orders in profit
input bool PipGapNegativeEnabled1 = false; // Pip gap between orders (1) - Apply to orders in loss
input bool PipGapAllowReverseOrdersAtAllTimes1 = false; // Pip gap between orders (1) - Allow reverse order

class PipGapPreventOpenModule_1: public PreventOpenModuleBase
{
   public:
    void PipGapPreventOpenModule_1()
      {
      }

      TradingModuleDemand Evaluate(Wallet* wallet, TradingModuleDemand demand, int level = 1)
      {
         TradingModuleDemand result = NoneDemand;
         TradingModuleDemand preventOpenAdvices[];
         
        if (level <= 1 || wallet.GetOpenOrders().Count() == 0) // never evaluate when no orders are open or when evaluating close conditions
        {
            return NoneDemand;
        }

        Order* lastOpenOrder = wallet.GetNewestOpenOrder();
        if (lastOpenOrder == NULL)
        {
            return NoneDemand;
        }

        double lastOpenOrderProfitPips = lastOpenOrder.CalculateProfitPips();
        if (
            (PipGapPositiveEnabled1 && (lastOpenOrderProfitPips >= 0 || !PipGapNegativeEnabled1) && lastOpenOrderProfitPips < PipGapInPips1)
            || (PipGapNegativeEnabled1 && (lastOpenOrderProfitPips < 0 || !PipGapPositiveEnabled1) && lastOpenOrderProfitPips > -PipGapInPips1)
            )
        {
            TradingModuleDemand resultDemand = GetDemandFromOrderType(lastOpenOrder.Type);
            return resultDemand;
        }
         
        return NoneDemand;
      }

    private:
     TradingModuleDemand GetDemandFromOrderType(ENUM_ORDER_TYPE orderType)
     {
         if (orderType == ORDER_TYPE_BUY)
         {
             if (PipGapAllowReverseOrdersAtAllTimes1)
             {
                 return NoBuyDemand;
             }
             else
             {
                 return NoOpenDemand;
             }
         }
         else if (orderType == ORDER_TYPE_SELL)
         {
             if (PipGapAllowReverseOrdersAtAllTimes1)
             {
                 return NoSellDemand;
             }
             else
             {
                 return NoOpenDemand;
             }
         }
         else
         {
             Alert("Unkown ordertype PipGapPreventOpenModule");
             return NoneDemand;
         }
     }
};

//
//  TradingSession PreventOpenModule 1
//

input int StartOpeningHourServerTime1 = 0; // Trading session - Start Hour (servertime)
input int StartOpeningMinuteServerTime1 = 0; // Trading session - Start Minute (servertime)
input int StopOpeningHourServerTime1 = 23; // Trading session - Stop Hour (servertime)
input int StopOpeningMinuteServerTime1 = 59; // Trading session - Stop Minute (servertime)
input bool MondayEnabled1 = true; // Trading session - Apply on Monday
input bool TuesdayEnabled1 = true; // Trading session - Apply on Tuesday
input bool WednesdayEnabled1 = true; // Trading session - Apply on Wednesday
input bool ThursdayEnabled1 = true; // Trading session - Apply on Thursday
input bool FridayEnabled1 = true; // Trading session - Apply on Friday
input bool SaturdayEnabled1 = false; // Trading session - Apply on Saturday
input bool SundayEnabled1 = false; // Trading session - Apply on Sunday

class TradingSessionPreventOpenModule_1: public PreventOpenModuleBase
{
public:
   void TradingSessionPreventOpenModule_1()
   {
   }

   TradingModuleDemand Evaluate(Wallet* wallet, TradingModuleDemand demand, int level = 1)
   {
      datetime currentServerTime = TimeCurrent();
      bool isWithinTimeSession = IsInTimeSession(StartOpeningHourServerTime1, StartOpeningMinuteServerTime1, 
         StopOpeningHourServerTime1, StopOpeningMinuteServerTime1, currentServerTime);
      if (!isWithinTimeSession)
      {
         MqlDateTime sTime;
         TimeToStruct(currentServerTime, sTime);

         if ((MondayEnabled1 && sTime.day_of_week == 1) 
         || (TuesdayEnabled1 && sTime.day_of_week == 2) 
         || (WednesdayEnabled1 && sTime.day_of_week == 3)
         || (ThursdayEnabled1 && sTime.day_of_week == 4)
         || (FridayEnabled1 && sTime.day_of_week == 5)
         || (SaturdayEnabled1 && sTime.day_of_week == 6)
         || (SundayEnabled1 && sTime.day_of_week == 7))
         {
            return NoOpenDemand;
         }
      }
      
      return NoneDemand;
    }

private:
    bool IsInTimeSession(int startHourServerTime, int startMinuteServerTime, int stopHourServerTime, int stopMinuteServerTime, datetime currentServerTime)
    {
        //--- session start time
        int startTime = 3600 * startHourServerTime + 60 * startMinuteServerTime;

        //--- session end time
        int stopTime = 3600 * stopHourServerTime + 60 * stopMinuteServerTime;
   
        //--- current time in seconds since the day start
        currentServerTime = currentServerTime % 86400;
   
        if (stopTime < startTime)
        {
            //--- going past midnight
            if (currentServerTime >= startTime || currentServerTime < stopTime)
            {
                return(true);
            }
        }
        else
        {
            //--- within one day
            if ((currentServerTime >= startTime && currentServerTime < stopTime)
            || (startTime == 0 && stopTime == 0))
            {
                return(true);
            }
        }
        return(false);
    }
};

//
//  TradingSessionExclusion PreventOpenModule 1
//

input int TradeSessionExclusionStartOpeningHourServerTime1 = 0; // Trading session exclusion (1) - Start Hour (servertime)
input int TradeSessionExclusionStartOpeningMinuteServerTime1 = 0; // Trading session exclusion (1) - Start Minute (servertime)
input int TradeSessionExclusionStopOpeningHourServerTime1 = 23; // Trading session exclusion (1) - Stop Hour (servertime)
input int TradeSessionExclusionStopOpeningMinuteServerTime1 = 59; // Trading session exclusion (1) - Stop Minute (servertime)
input bool TradeSessionExclusionMondayEnabled1 = false; // Trading session exclusion (1) - Apply on Monday
input bool TradeSessionExclusionTuesdayEnabled1 = false; // Trading session exclusion (1) - Apply on Tuesday
input bool TradeSessionExclusionWednesdayEnabled1 = false; // Trading session exclusion (1) - Apply on Wednesday
input bool TradeSessionExclusionThursdayEnabled1 = false; // Trading session exclusion (1) - Apply on Thursday
input bool TradeSessionExclusionFridayEnabled1 = false; // Trading session exclusion (1) - Apply on Friday
input bool TradeSessionExclusionSaturdayEnabled1 = true; // Trading session exclusion (1) - Apply on Saturday
input bool TradeSessionExclusionSundayEnabled1 = true; // Trading session exclusion (1) - Apply on Sunday

class TradingSessionExclusionPreventOpenModule_1: public PreventOpenModuleBase
{
public:
   void TradingSessionExclusionPreventOpenModule_1()
   {
   }

   TradingModuleDemand Evaluate(Wallet* wallet, TradingModuleDemand demand, int level = 1)
   {
      datetime currentServerTime = TimeCurrent();
      bool isWithinTimeSession = IsInTimeSession(TradeSessionExclusionStartOpeningHourServerTime1, TradeSessionExclusionStartOpeningMinuteServerTime1, 
      TradeSessionExclusionStopOpeningHourServerTime1, TradeSessionExclusionStopOpeningMinuteServerTime1, currentServerTime);

      if (isWithinTimeSession)
      {
         MqlDateTime sTime;
         TimeToStruct(currentServerTime, sTime);

         if ((TradeSessionExclusionMondayEnabled1 && sTime.day_of_week == 1) 
         || (TradeSessionExclusionTuesdayEnabled1 && sTime.day_of_week == 2) 
         || (TradeSessionExclusionWednesdayEnabled1 && sTime.day_of_week == 3)
         || (TradeSessionExclusionThursdayEnabled1 && sTime.day_of_week == 4)
         || (TradeSessionExclusionFridayEnabled1 && sTime.day_of_week == 5)
         || (TradeSessionExclusionSaturdayEnabled1 && sTime.day_of_week == 6)
         || (TradeSessionExclusionSundayEnabled1 && sTime.day_of_week == 7))
         {
            return NoOpenDemand;
         }
      }
      
      return NoneDemand;
    }

private:
    bool IsInTimeSession(int startHourServerTime, int startMinuteServerTime, int stopHourServerTime, int stopMinuteServerTime, datetime currentServerTime)
    {
        //--- session start time
        int startTime = 3600 * startHourServerTime + 60 * startMinuteServerTime;

        //--- session end time
        int stopTime = 3600 * stopHourServerTime + 60 * stopMinuteServerTime;
   
        //--- current time in seconds since the day start
        currentServerTime = currentServerTime % 86400;
   
        if (stopTime < startTime)
        {
            //--- going past midnight
            if (currentServerTime >= startTime || currentServerTime < stopTime)
            {
                return(true);
            }
        }
        else
        {
            //--- within one day
            if ((currentServerTime >= startTime && currentServerTime < stopTime)
            || (startTime == 0 && stopTime == 0))
            {
                return(true);
            }
        }
        return(false);
    }
};

//
//  Trader Interface
//
interface ITrader
{
    void HandleTick();
    void Init();
    Wallet* GetWallet();
};

ITrader *_ea;

//
//  Expert Advisor Class
//
class EA : public ITrader
{
    private:
        bool _firstTick;
        TradeStrategy* _tradeStrategy;
        AdvisorStrategy* _advisorStrategy;
        IMoneyManager* _moneyManager;
        Wallet* _wallet;

        bool _inconsistenciesInOrderCount;
        string _lastError;
 
    public:
        void EA()
        {
            _firstTick = true;

            UseValidateOrderMargin = ValidateOrderMargin; // Setting can be automatically disabled on an error. Only for some MM this is mandatory.

            _wallet = new Wallet();
            _wallet.SetLastClosedOrdersByTimeframe(DisplayOrderDuringTimeframe);

            // Advisor Strategy
            _advisorStrategy = new AdvisorStrategy();

            IAdvisorStrategySignal* openBuySignal = new ASSignal(ORDER_TYPE_BUY);
            openBuySignal.RegisterSignalExpression(new ASOpenBuySignalLevel1());
            _advisorStrategy.RegisterOpenBuy(openBuySignal, 1);

            IAdvisorStrategySignal* openSellSignal = new ASSignal(ORDER_TYPE_SELL);
            openSellSignal.RegisterSignalExpression(new ASOpenSellSignalLevel1());
            _advisorStrategy.RegisterOpenSell(openSellSignal, 1);

            IAdvisorStrategySignal* closeBuySignal = new ASSignal(ORDER_TYPE_SELL);
            closeBuySignal.RegisterSignalExpression(new ASCloseBuySignalLevel1());
            _advisorStrategy.RegisterCloseBuy(closeBuySignal, 1);

            IAdvisorStrategySignal* closeSellSignal = new ASSignal(ORDER_TYPE_BUY);
            closeSellSignal.RegisterSignalExpression(new ASCloseSellSignalLevel1());
            _advisorStrategy.RegisterCloseSell(closeSellSignal, 1);

            // MoneyManager
            _moneyManager = new MoneyManager(_wallet);

            // Trader Strategy
            _tradeStrategy = new TradeStrategy(new MultipleOpenModule_1(_advisorStrategy, _moneyManager), _moneyManager);

            // Dynamic Modules
            ITradeStrategyCloseModule* trailingTakeProfitOnSignalV2CloseModule_1 = new TrailingTakeProfitOnSignalV2CloseModule_1();
            trailingTakeProfitOnSignalV2CloseModule_1.RegisterTradeSignal(new TMSOnSignalTPV2_SignalId31052347());
            trailingTakeProfitOnSignalV2CloseModule_1.RegisterTradeValue(new TMVOnSignalTPV2_RefValueId31052348());
            _tradeStrategy.RegisterCloseModule(trailingTakeProfitOnSignalV2CloseModule_1);
            ITradeStrategyCloseModule* trailingTakeProfitOnSignalV2CloseModule_2 = new TrailingTakeProfitOnSignalV2CloseModule_2();
            trailingTakeProfitOnSignalV2CloseModule_2.RegisterTradeSignal(new TMSOnSignalTPV2_SignalId31052355());
            trailingTakeProfitOnSignalV2CloseModule_2.RegisterTradeValue(new TMVOnSignalTPV2_RefValueId31052356());
            _tradeStrategy.RegisterCloseModule(trailingTakeProfitOnSignalV2CloseModule_2);
            _tradeStrategy.RegisterPreventOpenModule(new MaxSpreadPreventOpenModule_1());
            _tradeStrategy.RegisterPreventOpenModule(new PipGapPreventOpenModule_1());
            _tradeStrategy.RegisterPreventOpenModule(new TradingSessionPreventOpenModule_1());
            _tradeStrategy.RegisterPreventOpenModule(new TradingSessionExclusionPreventOpenModule_1());

            
        }

        void ~EA()
        {
            delete(_tradeStrategy);
            delete(_moneyManager);
            delete(_advisorStrategy);
            delete(_wallet);

        }

        void Init()
        {
            IsDemoLiveOrVisualMode = !MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE);
            UnitsOneLot = MarketInfo_LibFunc(OrderSymbolTarget, MODE_LOTSIZE);

            // Check hedging
            if (AllowHedging)
            {
               ENUM_ACCOUNT_MARGIN_MODE accountMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
               UseHedging = accountMode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING;
               if (!UseHedging)
               {
                  HandleErrors("Unable to allow hedging on non-hedging account.");
               }
            }

            SetOrderGrouping();
            SetOrderTrailing();
            
            SetConfigWarnings();

            _wallet.LoadPendingOrdersFromBroker();
            _wallet.LoadOrdersFromBroker();
            _wallet.PrintOrderChanges();
        }

        void HandleTick()
        {
            // Only check on demo/live trading
            if (_firstTick == true && MQLInfoInteger(MQL_TESTER) == 0)
            {
               // if number of open orders is incorrect, reset in memory pending orders and load open orders
               SyncOrders();
            }

            if (AllowManualTPSLChanges)
            {
               SyncManualTPSLChanges();
            }


            // Update functions with latest info
            AskFunc.Evaluate();
            BidFunc.Evaluate();
            TimeFunc.Evaluate();

            // Update orders with latest tick quote
            UpdateOrders();

            if (!StopEA)
            {
                // Update wallet for new tick
                _wallet.HandleTick();

                // Update advisorstrategy for new tick and optional evaluation
                _advisorStrategy.HandleTick();

                if (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED) == 1) 
                {
                    if (_wallet.GetQueuedOpenOrders().Count() == 0 && _wallet.GetQueuedCloseOrders().Count() == 0)
                    {
                        _tradeStrategy.Evaluate(_wallet);
                    }

                    bool executedCloseOrdersSuccessfully = ExecuteAwaitingCloseOrders();
                    
                    if (UsesBrokerOrderTrailing)
                        ExecuteModifySlTpOrders();
                    
                    if (executedCloseOrdersSuccessfully) // Don't open orders until currently closing orders are closed.
                    {
                        if (!ExecuteAwaitingOpenOrders())
                        {
                            HandleErrors(StringFormat("Open (all) order(s) failed. Please check EA %d and look at the Journal and Expert tab.", MagicNumber));
                        }
                    }
                    else
                    {
                        HandleErrors(StringFormat("Close (all) order(s) failed! Please check EA %d and look at the Journal and Expert tab.", MagicNumber));
                    }
                }
            }
            else
            {
                // First close all orders which were already closing and then the orders which were still open
                if (ExecuteAwaitingCloseOrders())
                {
                    _wallet.SetAllOpenOrdersToQueuedClose();
                }
                else
                {
                    HandleErrors(StringFormat("Close (all) order(s) failed! Please check EA %d and look at the Journal and Expert tab.", MagicNumber));
                }
            }

            if (_firstTick)
               _firstTick = false;
        }

        Wallet* GetWallet()
        {
            return _wallet;
        }

        private:

        void SetOrderGrouping()
        {
            int size = ArraySize(_tradeStrategy.CloseModules);
            ORDER_GROUP_TYPE groups[];
            ArrayResize(groups, size);

            for(int i = 0; i < ArraySize(_tradeStrategy.CloseModules); i++)
            {
               groups[i] = _tradeStrategy.CloseModules[i].GetOrderGroupingType();
            }

            _wallet.ActivateOrderGroups(groups);
        }

        void SetOrderTrailing()
        {
            if (!SendSlTpToBroker)
               return;
        
            int size = ArraySize(_tradeStrategy.CloseModules);
            ORDER_GROUP_TYPE groups[];
            ArrayResize(groups, size);

            for(int i = 0; i < ArraySize(_tradeStrategy.CloseModules); i++)
            {
               bool isOrderTrailingEnabled = _tradeStrategy.CloseModules[i].UsesOrderTrailing();
               if (isOrderTrailingEnabled)
               {
                  // If any module uses trailing we'll process if an order should be updated every quote
                  UsesBrokerOrderTrailing = true;
               }
            }

            _wallet.ActivateOrderGroups(groups);
        }
        
        void SetConfigWarnings()
        {
            for(int i = 0; i < ArraySize(_tradeStrategy.CloseModules); i++)
            {
               string warning = _tradeStrategy.CloseModules[i].GetWarning();
               if (warning != NULL)
               {
                  // If any module uses trailing we'll process if an order should be updated every quote
                  Warning = warning;
               }
            }
        }

        void SyncOrders()
        {
            bool differenceBetweenWalletAndBroker = false;

            OrderCollection* currentBrokerOpenOrders = OrderRepository::GetOpenOrders(MagicNumber, NULL, OrderSymbolTarget);
            OrderCollection* currentBrokerOpenPendingOrders = OrderRepository::GetOpenPendingOrders(MagicNumber, NULL, OrderSymbolTarget);
            
            if (AccountMarginMode == ACCOUNT_MARGIN_MODE_RETAIL_NETTING || AccountMarginMode == ACCOUNT_MARGIN_MODE_EXCHANGE)
            {
               // on netting accounts we have to sum the volume, not the number of orders.
               double currentOpenVolumeBroker = 0;
               double currentOpenVolumeWallet = 0;
               for (int i = 0; i < currentBrokerOpenOrders.Count(); i++)
               {
                  currentOpenVolumeBroker += currentBrokerOpenOrders.Get(i).Lots;
               }
               for (int i = 0; i < currentBrokerOpenPendingOrders.Count(); i++)
               {
                  currentOpenVolumeBroker += currentBrokerOpenPendingOrders.Get(i).Lots;
               }
               
               currentOpenVolumeWallet = _wallet.GetTotalVolume(_wallet.GetOpenOrders());
               currentOpenVolumeWallet += _wallet.GetTotalVolume(_wallet.GetOpenPendingOrders());
               currentOpenVolumeWallet += _wallet.GetTotalVolume(_wallet.GetQueuedCloseOrders());
               
               if (MathAbs(currentOpenVolumeBroker - currentOpenVolumeWallet) > 1e-5)
               {
                  string error = "(Manual) orderchanges detected by volume" + " (found in MT: " + DoubleToString(currentOpenVolumeBroker) + " and in wallet: " + DoubleToString(currentOpenVolumeWallet) + ").";
                  
                  if (_lastError != error)
                  {
                     Print(error);
                     _lastError = error;   
                  }
                  
                  differenceBetweenWalletAndBroker = true;
               }
            }
            else
            {
               // count the number of orders
               int currentOpenordersCountBroker = currentBrokerOpenOrders.Count() + currentBrokerOpenPendingOrders.Count();
               int currentOpenOrdersCountWallet = _wallet.GetOpenOrderCount() + _wallet.GetOpenPendingOrderCount() + (_wallet.GetQueuedCloseOrders().Count() - _wallet.GetPendingPartialCloseOrderCount());
               
               if (currentOpenordersCountBroker != currentOpenOrdersCountWallet)
               {
                  string error = "(Manual) orderchanges detected by count" + " (found in MT: " + IntegerToString(currentOpenordersCountBroker) + " and in wallet: " + IntegerToString(currentOpenOrdersCountWallet) + ").";
               
                  if (_lastError != error)
                  {
                     Print(error);
                     Print("Inconsistent order count detected... This situation should solve itself.");
                     _lastError = error;   
                  }
                  differenceBetweenWalletAndBroker = true;
               }
            }
            
            if (!_inconsistenciesInOrderCount && differenceBetweenWalletAndBroker)
            {
               _inconsistenciesInOrderCount = true;  
            }
            else if (_inconsistenciesInOrderCount && !differenceBetweenWalletAndBroker)
            {
               _inconsistenciesInOrderCount = false;
               Print("Inconsistent order counts SOLVED.");
            }

            delete(currentBrokerOpenOrders);
            delete(currentBrokerOpenPendingOrders);
        }

        void SyncManualTPSLChanges()
        {
            _wallet.GetOpenOrders().Rewind();
            while(_wallet.GetOpenOrders().HasNext())
            {
                Order* order = _wallet.GetOpenOrders().Next();
                if (order == NULL || CheckPointer(order) == POINTER_INVALID) // Racing condition with terminal transactions
                  continue;

                uint lineFindResult = ObjectFind(ChartID(), IntegerToString(order.Ticket) + "_SL");
                if (lineFindResult != UINT_MAX)
                {
                    double currentPosition = ObjectGetDouble(ChartID(), IntegerToString(order.Ticket) + "_SL", OBJPROP_PRICE);
                    if ((order.StopLossManual == 0 && currentPosition != order.GetClosestSL()) || (order.StopLossManual != 0 && currentPosition != order.StopLossManual))
                    {
                        order.StopLossManual = currentPosition;
                    }
                }

                lineFindResult = ObjectFind(ChartID(), IntegerToString(order.Ticket) + "_TP");
                if (lineFindResult != UINT_MAX)
                {
                    double currentPosition = ObjectGetDouble(ChartID(), IntegerToString(order.Ticket) + "_TP", OBJPROP_PRICE);
                    if ((order.TakeProfitManual == 0 && currentPosition != order.GetClosestTP()) || (order.TakeProfitManual != 0 && currentPosition != order.TakeProfitManual))
                    {
                        order.TakeProfitManual = currentPosition;
                    }
                }
            }
        }

        void UpdateOrders()
        {
            _wallet.GetOpenOrders().Rewind();
            while(_wallet.GetOpenOrders().HasNext())
            {
                Order* order = _wallet.GetOpenOrders().Next();
                if (order == NULL || CheckPointer(order) == POINTER_INVALID) // Racing condition with terminal transactions
                  continue;

                double pipsProfit = order.CalculateProfitPips();
                order.CurrentProfitPips = pipsProfit;

                if (pipsProfit < order.LowestProfitPips)
                {
                    order.LowestProfitPips = pipsProfit;
                }
                else if (pipsProfit > order.HighestProfitPips)
                {
                    order.HighestProfitPips = pipsProfit;
                }
            }
        }

        bool ExecuteAwaitingCloseOrders()
        {
            OrderCollection* pendingCloseOrders = _wallet.GetQueuedCloseOrders();
            int ordersToCloseCount = pendingCloseOrders.Count();
            if (ordersToCloseCount == 0)
            {
               return true;
            }

            // Check if orders are still being opened currently
            if (_wallet.AreOrdersBeingOpened())
            {
               return true;
            }

            int ordersCloseSuccessCount = 0;

            for (int i = ordersToCloseCount - 1; i >= 0; i--)
            {
               Order* pendingCloseOrder = pendingCloseOrders.Get(i);
               if (pendingCloseOrder.IsAwaitingDealExecution)
               {
                  ordersCloseSuccessCount++;
                  continue;
               }

               bool success;
               
               // Set to awaiting before sending order to broker, to prevent racing condition (transaction being processed before boolean set and then being overwritten to IsAwaiting)
               pendingCloseOrder.IsAwaitingDealExecution = true;
               
               if (IsPendingOrderType(pendingCloseOrder.Type))
               {
                  success = OrderRepository::ClosePendingOrder(pendingCloseOrder);
               }
               else
               {
                  if (AccountMarginMode == ACCOUNT_MARGIN_MODE_RETAIL_NETTING || AccountMarginMode == ACCOUNT_MARGIN_MODE_EXCHANGE)
                  {
                     // Orders for netting accounts are closed by opening a reverse order
                     Order* reversedOrder = new Order(pendingCloseOrder, false);
                     reversedOrder.Type = pendingCloseOrder.Type == ORDER_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                     
                     success = OrderRepository::OpenOrder(reversedOrder, true);
                     if (success)
                     {
                        pendingCloseOrder.Ticket = reversedOrder.Ticket;
                     }
   
                     delete(reversedOrder);
                  }
                  else // Hedging account
                  {
                     success = OrderRepository::ClosePosition(pendingCloseOrder);
                  }
               }

               if (success)
               {
                  ordersCloseSuccessCount++;
               }
               else
               {
                  pendingCloseOrder.IsAwaitingDealExecution = false; // Don't wait for execution anymore, since order failed
               }
            }

            return ordersCloseSuccessCount == ordersToCloseCount;
        }

        bool ExecuteModifySlTpOrders()
        {
            int openOrdersCount = _wallet.GetOpenOrderCount();
            if (openOrdersCount == 0)
            {
               return true;
            }
            
            if (TimeCurrent() - OrdersModifiedLast < TrailUpdateStepSeconds)
            {
               return true; // Too soon to send updates yet. The broker may block you for sending updates too frequently
            }

            bool ordersUpdated = false;
            
            OrderCollection* openOrders = _wallet.GetOpenOrders();
            for (int i = 0; i < openOrdersCount; i++)
            {
               Order* order = openOrders.Get(i);
               
               bool shouldUpdateOrderAtBroker = false;

               double pipSlDifference = MathAbs(order.StopLoss - order.GetClosestSL()) / PipPoint;
               if (pipSlDifference >= TrailUpdateStepPip)
               {
                  shouldUpdateOrderAtBroker = true;
               }
               
               if (!shouldUpdateOrderAtBroker)
               {
                  // only evaluate TP difference if SL hasn't changed enough yet
                  double pipTpDifference = MathAbs(order.TakeProfit - order.GetClosestTP()) / PipPoint;
                  if (pipTpDifference >= TrailUpdateStepPip)
                  {
                     shouldUpdateOrderAtBroker = true;
                  }
               }
               
               if (shouldUpdateOrderAtBroker)
               {
                  if (OrderRepository::Modify(order.Ticket, order.GetClosestSL(), order.GetClosestTP()))
                  {
                     order.StopLoss = order.GetClosestSL();
                     order.TakeProfit = order.GetClosestTP();
                     ordersUpdated = true;
                  }
               }
            }

            if (ordersUpdated)
            {
               OrdersModifiedLast = TimeCurrent();
            }

            return true;
        }

        bool ExecuteAwaitingOpenOrders()
        {
            OrderCollection* awaitingOpenOrders = _wallet.GetQueuedOpenOrders();
            int ordersToOpenCount = awaitingOpenOrders.Count();
            if (ordersToOpenCount == 0)
            {
                return true;
            }

            int ordersOpenSuccessCount = 0;

            for (int i = ordersToOpenCount - 1; i >= 0; i--)
            {
                Order* order = awaitingOpenOrders.Get(i);
                if (order == NULL) // Racing condition possibility when deleting orders manually
                {
                    continue;
                }

                if (order.IsAwaitingDealExecution)
                {
                    ordersOpenSuccessCount++;
                    continue;
                }

                bool isTradeContextFree = false;
                double StartWaitingTime = GetTickCount();

                order.IsAwaitingDealExecution = true;

                while (true)
                {
                    // if the trade context has become free
                    if (MQLInfoInteger(MQL_TRADE_ALLOWED))
                    {
                        isTradeContextFree = true;
                        break;
                    }

                    int MaxWaiting_sec = 10;
                    // if the expert was terminated by the user, stop operation
                    if (IsStopped())
                    {
                        HandleErrors("The expert was stopped by a user action.");
                        break;
                    }

                    // if it is waited longer than it is specified in the variable named
                    // MaxWaiting_sec, stop operation, as well
                    if (GetTickCount() - StartWaitingTime > MaxWaiting_sec * 1000)
                    {
                        HandleErrors(StringFormat("The (%d seconds) waiting time exceeded. Trade not allowed: EA disabled, market closed or trade context still not free.", MaxWaiting_sec));
                        break;
                    }

                    Sleep(100);
                }

                if (!isTradeContextFree)
                {
                    if (!_wallet.CancelQueuedOpenOrder(order))
                        HandleErrors("Failed to cancel an order (because it couldn't open). Please see the Journal and Expert tab in Metatrader for more information.");

                    continue;
                }

                bool success = OrderRepository::OpenOrder(order);
                if (success)
                {
                    ordersOpenSuccessCount++;
                }
                else
                {
                    // Wallet remove pending open order, on next tick it will be evaluated if signal is still valid
                    if (!_wallet.CancelQueuedOpenOrder(order))
                        HandleErrors("Failed to cancel an order (because it couldn't open). Please see the Journal and Expert tab in Metatrader for more information.");
                }
            }

            return ordersOpenSuccessCount == ordersToOpenCount;
        }
};

//+------------------------------------------------------------------------+
//|  Chart setup                                                           |
//+------------------------------------------------------------------------+

void SetupChart()
{
	
	ChartSetInteger(ChartID(), CHART_FOREGROUND, 0, false);
}

//+------------------------------------------------------------------------+
//|  Expert Initialization Function                                        |
//+------------------------------------------------------------------------+

int OnInit()
{
	
	OrderFillingType = GetFillingType();
	if ((int)OrderFillingType == -1)
	{
	    HandleErrors("Unsupported filling type " + IntegerToString((int)OrderFillingType));
	    return (INIT_FAILED);
	}
	
	GetExecutionType();
	AccountMarginMode = GetAccountMarginMode();
	
	SetSymbol();
	
	SetPipPoint();
	if (PipPoint == 0)
	{
		HandleErrors("Couldn't find correct pip/point for symbol.");
	    return (INIT_FAILED);
	}
	
	AskFunc = new AskFunction();
	AskFunc.Init();
	BidFunc = new BidFunction();
	BidFunc.Init();
	TimeFunc = new TimeFunction();
	TimeFunc.Init();
	
	OrderInfoComment = "";
	
	_ea = new EA();
	_ea.Init();
	
	SetupChart();
	
	hd_QQEAdv_QQE7142 = iCustom(NULL,PERIOD_CURRENT,"QQE Adv",QQEAdv_QQE7142_SF,QQEAdv_QQE7142_RSI_Period,QQEAdv_QQE7142_WP);
	if(hd_QQEAdv_QQE7142 < 0)
	{
	    HandleErrors(StringFormat("Cannot find indicator 'QQE Adv'. Please make sure this indicator is in your Indicators folder, not a subfolder. Error: %d", GetLastError()));
	    return -1;
	}
	hd_QMPFilter_QMPFilter1 = iCustom(NULL,PERIOD_CURRENT,"QMP Filter",PERIOD_D1,QMPFilter_QMPFilter1_Fast,QMPFilter_QMPFilter1_Slow,QMPFilter_QMPFilter1_Smooth,true,QMPFilter_QMPFilter1_SF,QMPFilter_QMPFilter1_RSI_Period,QMPFilter_QMPFilter1_WP,false,false);
	if(hd_QMPFilter_QMPFilter1 < 0)
	{
	    HandleErrors(StringFormat("Cannot find indicator 'QMP Filter'. Please make sure this indicator is in your Indicators folder, not a subfolder. Error: %d", GetLastError()));
	    return -1;
	}
	hd_TheBreakEvenIndi_Breakeven1 = iCustom(NULL,PERIOD_CURRENT,"TheBreakEvenIndicatorFinal",true,0x4dfcff,0,TheBreakEvenIndi_Breakeven1_BuyLineWidth,true,0xfebb48,0,TheBreakEvenIndi_Breakeven1_SellLineWidth,true,0xfc3dff,0,TheBreakEvenIndi_Breakeven1_AllLineWidth,true,TheBreakEvenIndi_Breakeven1_PipOffset,TheBreakEvenIndi_Breakeven1_LabelXOffset,TheBreakEvenIndi_Breakeven1_LabelYSpacing,"Courier",TheBreakEvenIndi_Breakeven1_LabelFontSize);
	if(hd_TheBreakEvenIndi_Breakeven1 < 0)
	{
	    HandleErrors(StringFormat("Cannot find indicator 'TheBreakEvenIndicatorFinal'. Please make sure this indicator is in your Indicators folder, not a subfolder. Error: %d", GetLastError()));
	    return -1;
	}
	
	return (INIT_SUCCEEDED);
	
}

//+------------------------------------------------------------------------+
//|  Expert OnTransaction Function                                         |
//+------------------------------------------------------------------------+

void HistorySelectPreviousDay()
{
	
	// Load deals from previous day in cache
	   datetime timeCurrent = TimeCurrent();                         // current server time
	   datetime start = timeCurrent - PeriodSeconds(PERIOD_D1);      // decrease 1 day
	   HistorySelect(start, timeCurrent + PeriodSeconds(PERIOD_D1)); // +1 in case of time difference between local and trade server
	
}

void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
{
	
	    bool foundOrderUpdate = false;
	   
	    // HistorySelectPreviousDay(); // Only required when using the HistoryTotal function. If you already know the ticketId, then you can just load the History Order/ Deal itself by using the functions with TicketId (https://www.mql5.com/en/articles/211).
	   
	    /*string desc=EnumToString(trans.type)+"\r\n";
	    desc+="Symbol: "+trans.symbol+"\r\n";
	    desc+="Deal ticket: "+(string)trans.deal+"\r\n";
	    desc+="Deal type: "+EnumToString(trans.deal_type)+"\r\n";
	    desc+="Order ticket: "+(string)trans.order+"\r\n";
	    desc+="Order type: "+EnumToString(trans.order_type)+"\r\n";
	    desc+="Order state: "+EnumToString(trans.order_state)+"\r\n";
	    desc+="Order time type: "+EnumToString(trans.time_type)+"\r\n";
	    desc+="Order expiration: "+TimeToString(trans.time_expiration)+"\r\n";
	    desc+="Price: "+StringFormat("%G",trans.price)+"\r\n";
	    desc+="Price trigger: "+StringFormat("%G",trans.price_trigger)+"\r\n";
	    desc+="Stop Loss: "+StringFormat("%G",trans.price_sl)+"\r\n";
	    desc+="Take Profit: "+StringFormat("%G",trans.price_tp)+"\r\n";
	    desc+="Volume: "+StringFormat("%G",trans.volume)+"\r\n";
	    desc+="Position: "+(string)trans.position+"\r\n";
	    desc+="Position by: "+(string)trans.position_by+"\r\n";
	    Print("desc " + desc);*/
	
	    if (trans.symbol != OrderSymbolTarget)
	    {
	        return; // transaction for another symbol (not for this EA)
	    }
		
	    switch(trans.type)
	    {
		    // Scenario 1: Pending order was placed by the EA
		    // Scenario 2: Market order was placed by the EA
		    // Scenario 3: Pending order (limit/ stop) was filled by the broker                                   <- This doesn't cause a new order to be opened, it just adds a deal and deletes the order.
		    // Scenario 4: A manual order was opened                                                              <- Use deals for this, because if an unknown order is added you don't know if it's a manual order, or an order meant to close a position.
		    // Scenario 5: An open order was closed
		    // Scenario 6: A pending order was manually closed
		    // Scenario 7: A pending order expired by the broker
		    // Scenario 8: A pending order was expired by the EA through the expiry condition (awaiting close)
	      
	        case TRADE_TRANSACTION_ORDER_ADD:
	        {
	            COrderInfo orderInfo;
	            orderInfo.Select(trans.order);
	         
	            // Scenario 1 + 2
	            OrderCollection* awaitingOpenOrders = _ea.GetWallet().GetQueuedOpenOrders();
	         
	            bool orderAddFound = false;
	            for(int i = 0; i < awaitingOpenOrders.Count(); i++)
	            {
	                Order* order = awaitingOpenOrders.Get(i);
	                if (order.Ticket == orderInfo.Ticket() || order.Ticket == trans.order)
	                {
		                orderAddFound = true;
		                foundOrderUpdate = true; // Order change which changes order count
	
	                    if (IsPendingOrderType(order.Type))
	                    {
	                        // Scenario 1: Pending order was placed by the EA
	                        Print(TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS) +  "Pending order was placed by the EA.");
	                        order.IsAwaitingDealExecution = false;
	                        _ea.GetWallet().MoveQueuedOpenOrderToOpenPendingOrders(order);
	                        break;
	                    }
	                    else
	                    {
	                        // Scenario 2: Market order was placed by the EA
	                        Print(TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS) +  "Market order was placed by the EA."); // No further action required. DEAL_ADD will fill the order.
	                        break;
	                    }
	                }
	            }
	         
	            if (orderAddFound)
	                break;
	         
	            // Scenario 4: A manual order was opened 
	            if (trans.position == 0) // If it's not a close order
	            {
	                Print(TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS) +  " (Manual) order adding detected.");
	            
	                Order* newOrder = OrderRepository::GetOpenOrder(trans.order);
	                if (newOrder == NULL)
	                {
	                    PrintFormat(TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS) +  " Adding order to waiting list (data not yet available): %s", IntegerToString(trans.order));
	                    _ea.GetWallet().AddTerminalAddedOrderDataWaitingList(trans.order);
	                }
	                else
	                {
	                    if (newOrder.MagicNumber != MagicNumber)
	      	            {
	      	                delete(newOrder); // order of another EA - ignore
	      	                break;
	      	            }
	
	                    // Data was already found
	                    newOrder.IsAwaitingDealExecution = false;
	               
	                    if (IsPendingOrderType(newOrder.Type))
	                    {
	                        foundOrderUpdate = true; // Order change which changes order count
	
	                        _ea.GetWallet().AddManualOpenPendingOrder(newOrder);
	                    }
	                    else
	                    {
	                        PrintFormat(TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS) +  " Adding order to waiting list (some data not yet available): %s", IntegerToString(trans.order));
	                        _ea.GetWallet().AddTerminalAddedOrderDataWaitingList(trans.order);
	                    }
	                }
	            
	                break;
	            }
	         
	            break;
	        }
	        case TRADE_TRANSACTION_ORDER_DELETE:
	        {
	            COrderInfo orderInfo;
	            orderInfo.Select(trans.order);
	        
	            if (trans.order_state == ORDER_STATE_EXPIRED)
		        {
		            // Scenario 7: A pending order expired
		            OrderCollection* pendingOrders = _ea.GetWallet().GetOpenPendingOrders();
		            for(int i = 0; i < pendingOrders.Count(); i++)
		            {
		                Order* pendingOrder = pendingOrders.Get(i);
		                if (IsPendingOrderType(pendingOrder.Type) && pendingOrder.Ticket == trans.order) // pending orders are deleted after expiry, normal orders are closed trough 1 or multiple DEAL_ENTRY_OUT
		                {
		                    foundOrderUpdate = true; // Order change which changes order count
		
		                    _ea.GetWallet().RemoveOpenPendingOrder(pendingOrder);
		                    break;
		                }
		            }
		        }
		        else if (trans.order_state == ORDER_STATE_CANCELED)
	            {
	                // Scenario 6: A pending order was manually closed
	                // Scenario 7: A pending order expired
	                OrderCollection* pendingOrders = _ea.GetWallet().GetOpenPendingOrders();
	                for(int i = 0; i < pendingOrders.Count(); i++)
	                {
	                    Order* pendingOrder = pendingOrders.Get(i);
	                    if (IsPendingOrderType(pendingOrder.Type) && pendingOrder.Ticket == trans.order) // pending orders are deleted after expiry, normal orders are closed trough 1 or multiple DEAL_ENTRY_OUT
	                    {
	                        foundOrderUpdate = true; // Order change which changes order count
	
	                        _ea.GetWallet().RemoveOpenPendingOrder(pendingOrder);
	                        break;
	                    }
	                }
	            
	                // Scenario 8: A pending order was expired by the EA through the expiry condition (awaiting close)
	                OrderCollection* awaitingCloseOrders = _ea.GetWallet().GetQueuedCloseOrders();
	                for(int i = 0; i < awaitingCloseOrders.Count(); i++)
	                {
	                    Order* awaitingCloseOrder = awaitingCloseOrders.Get(i);
	                    if (IsPendingOrderType(awaitingCloseOrder.Type) && awaitingCloseOrder.Ticket == trans.order) // pending orders are deleted after expiry, normal orders are closed trough 1 or multiple DEAL_ENTRY_OUT
	                    {
	                        foundOrderUpdate = true; // Order change which changes order count
	
	                        _ea.GetWallet().SetAwaitingCloseOrderToClosed(awaitingCloseOrder);
	                        break;
	                    }
	                }
	            }
	         
	            break;
	        }
	        case TRADE_TRANSACTION_DEAL_ADD:
	        {
	            HistoryDealSelect(trans.deal);
	         
	            CDealInfo dealInfo;
	            dealInfo.Ticket(trans.deal);
	         
	            ENUM_DEAL_ENTRY deal_entry = dealInfo.Entry();
	         
	            bool foundOrderForDeal = false;
		
	            if (deal_entry == DEAL_ENTRY_IN) // entry in is for updating pending open orders
	            {
	                Order* order = NULL;
	                bool readyFillingOrder = false;
	       
	                // Scenario 2: Market order was placed by the EA
	                OrderCollection* awaitingOpenOrders = _ea.GetWallet().GetQueuedOpenOrders();
	                for(int i = 0; i < awaitingOpenOrders.Count(); i++)
	                {
	                    Order* awaitingOrder = awaitingOpenOrders.Get(i);
	                    if (awaitingOrder.Ticket == trans.order)
	                    {
	                        PrintFormat("%s Market order opened: %s", TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS), IntegerToString(trans.order));
	                        foundOrderForDeal = true;
	                        order = awaitingOrder;
	                        break;
	                    }
	                }
	            
	                // Scenario 3: Pending order (limit/ stop) was filled by the broker
	                if (order == NULL)
	                {
	                    OrderCollection* openPendingOrders = _ea.GetWallet().GetOpenPendingOrders();
	                    for(int i = 0; i < openPendingOrders.Count(); i++)
	                    {
	                        Order* openPendingOrder = openPendingOrders.Get(i);
	                        if (openPendingOrder.Ticket == trans.order)
	                        {
	                            PrintFormat("%s Pending order filled: %s", TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS), IntegerToString(trans.order));
	                            foundOrderForDeal = true;
	                            order = openPendingOrder;
	                            break;
	                        }
	                    }
	                }
	            
	                // Scenario 3(B): Pending order (limit/ stop) was filled by the broker just a fraction before expiry could cancel it
	                if (order == NULL)
	                {
	                    // It's still a happy flow that the order is filled just a fraction before the expiry cancelled the order
	                    OrderCollection* awaitingCloseOrders = _ea.GetWallet().GetQueuedCloseOrders();
	                    for(int i = 0; i < awaitingCloseOrders.Count(); i++)
	                    {
	                        Order* awaitingCloseOrder = awaitingCloseOrders.Get(i);
	                        if (IsPendingOrderType(awaitingCloseOrder.Type) && awaitingCloseOrder.Ticket == trans.order)
	                        {
	                            // Racing condition detected
	                            HandleErrors("Tried closing Pending order, but order was filled by the broker just before.");
	                     
	                            foundOrderForDeal = true;
	                            foundOrderUpdate = true; // Order change which changes order count
	                     
	                            order = _ea.GetWallet().MoveQueuedCloseOrderToPendingOpenOrders(awaitingCloseOrder);
	                     
	                            break;
	                        }
	                    }
	                }
	            
	                // Scenario 4: A manual market order was opened
	                if (order == NULL && _ea.GetWallet().IsTicketInHistoryWaitingList(trans.order))
	                {
	                    if (dealInfo.Magic() != MagicNumber) // If data turns out to be from another EA, remove data
		                {
		                    _ea.GetWallet().RemoveBrokerAddedOrderHistoryWaitingList(trans.order);
		                    break;
		                }
	
	                    Print(TimeToStr(TimeCurrent(),TIME_DATE|TIME_SECONDS) + " (Manual) order adding detected.");
	               
	                    foundOrderForDeal = true;
	                    foundOrderUpdate = true; // Order change which changes order count
	               
	                    order = new Order(true);
	                    order.Lots = trans.volume;
	                    order.Ticket = trans.order;
	                    order.IsAwaitingDealExecution = true;
	                    order.Type = trans.deal_type == DEAL_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
	               
	                    _ea.GetWallet().GetQueuedOpenOrders().Add(order);
	                }
	           
	                if (order != NULL)
	                {
	                    order.PositionId = dealInfo.PositionId();
	                    order.OpenTime = dealInfo.Time();
	                    order.OpenPrice = trans.price;
	                    order.TradePrice = order.OpenPrice;
	                    order.OrderFilledLots += trans.volume;
	                    order.TakeProfit = trans.price_tp;
	                    order.StopLoss = trans.price_sl;
	               
	                    // For FOK it means that a deal can be executed only with the specified volume, but may consist of several offers (deals)
	                    if (OrderFillingType == ORDER_FILLING_FOK)
	                    {
	                        // Only continue when all deals have been processed
	                        if (MathAbs(order.Lots - order.OrderFilledLots) < 1e-5) // order could be filled by multiple deals. Waiting for order to be filled completely.
	                        {
	                            readyFillingOrder = true;
	                            order.IsAwaitingDealExecution = false;
	                            order.TradeVolume = order.Lots;
	                        }
	                    }
	                    // For the other types (IOC/ Return) the rest of the order may be cancelled or continued.
	                    else
	                    {
	                        readyFillingOrder = true;
	                        order.IsAwaitingDealExecution = false;
	               
	                        // Calculate this before setting the new lots volume
	                        bool actualVolumeDiffers = MathAbs(order.Lots - trans.volume) > 1e-5;
	               
	                        order.Lots = order.OrderFilledLots;
	                        order.TradeVolume = order.Lots;
	               
	                        if (actualVolumeDiffers)
	                        {
	                            Print("Broker executed volume differs from requested volume. Executed volume: " + DoubleToStr(trans.volume));
	               
	                            // Recalculate commission on basis of actual volume
	                            OrderRepository::CalculateAndSetCommision(order);
	                        }
	                    }
	               
	                    if (readyFillingOrder)
	                    {
	                        if (IsPendingOrderType(order.Type))
	                        {
	                            foundOrderUpdate = true; // Order change which changes order count
	                            _ea.GetWallet().MoveOpenPendingOrderToOpenOrders(order);
	                        }
	                        else
	                        {
	                            foundOrderUpdate = true; // Order change which changes order count
	                            _ea.GetWallet().MoveQueuedOpenOrderToOpenOrders(order);
	                        }
	                  
	                        Print(StringFormat("Execution done for order (%d) by EA (%d)", trans.order, MagicNumber));
	                    }
	                }
	            }
	            // entry out is for updating pendingclose orders
	            else if (deal_entry == DEAL_ENTRY_OUT)
	            {
	                OrderCollection* potentialClosingOrders = new OrderCollection();
	            
	                // Maybe the order was closed manually. In that case we can only work with the PositionId because there's no order from our side
	                bool closedInTerminal = false;
	            
	                OrderCollection* pendingCloseOrders = _ea.GetWallet().GetQueuedCloseOrders(); // Check this list first because it's most likely these are closed right now. Imagine scenario of a partial close. If we first check the open orders, then the part which should remain open would be closed first.
	                for (int i = 0; i < pendingCloseOrders.Count(); i++)
	                {
	                   Order* order = pendingCloseOrders.Get(i);
	                   if (order.Ticket == trans.order || order.PositionId == trans.position)
	                   {
	                       foundOrderForDeal = true;
	                       potentialClosingOrders.Add(order);
	                   }
	                }
		            
	                OrderCollection* openOrders = _ea.GetWallet().GetOpenOrders();
		            for(int i = 0; i < openOrders.Count(); i++)
		            {
		                Order* openOrder = openOrders.Get(i);
		                if (trans.position == openOrder.PositionId)
		                {
		                    foundOrderForDeal = true;
		                    closedInTerminal = true;
		                    potentialClosingOrders.Add(openOrder);
		                }                   
		            }	 
	            
	                double totalVolumeOfTransactionClosed = 0;
	                for (int i = 0; i < potentialClosingOrders.Count(); i++)
	                {
	                    foundOrderUpdate = true; // Order change which changes order count
	
	                    if (trans.volume - totalVolumeOfTransactionClosed < 1e-5)
	                    {
	                        // The entire amount of the deal out has been closed now
	                        break;
	                    }
	            
	                    Order* closingOrder = potentialClosingOrders.Get(i);
	               
	                    double lotsStillToBeExited = closingOrder.Lots - closingOrder.OrderExitedLots;
	                    double exitingLots = MathMin(lotsStillToBeExited, (trans.volume - totalVolumeOfTransactionClosed)); // What's less? The amount that still needs to be closed, or the remaining volume of the transaction?
	               
	                    totalVolumeOfTransactionClosed += exitingLots; // one close deal could close multiple orders (the entire position)
	                    closingOrder.OrderExitedLots += exitingLots; // one order clould be closed by multiple deals
	               
	                    if (MathAbs(closingOrder.Lots - closingOrder.OrderExitedLots) < 1e-5)   // order could be filled by multiple deals. Waiting for order to be filled completely.
	                    {
	                        // Closing is done (full volume filled)
	                        closingOrder.SetCloseInfosToOld();
	                  
	                        closingOrder.IsAwaitingDealExecution = false;
	                        closingOrder.CloseTime = dealInfo.Time();
	                        closingOrder.ClosePrice = trans.price;   
	                  
	                        if (closingOrder.MagicNumber == MagicNumber) // check required given the basket behaviour
	                            TotalCommission += closingOrder.Commission;
	                     
	                        if (IsDemoLiveOrVisualMode)
	                        {
	                            AnyChartObjectDelete(ChartID(), IntegerToString(closingOrder.Ticket) + "_TP");
	                            AnyChartObjectDelete(ChartID(), IntegerToString(closingOrder.Ticket) + "_SL");
	                        }
	                  
	                        if (closingOrder.ParentOrder != NULL)
	                        {
	                            closingOrder.ParentOrder.Paint();
	                        }
	                  
	                        if (!_ea.GetWallet().SetAwaitingCloseOrderToClosed(closingOrder)) // Closed by EA
	                        {
	                            if (closedInTerminal && !_ea.GetWallet().SetOpenOrderToClosed(closingOrder))   // Closed by broker or manually
	                            {
	                                Alert("Couldn't move order to closed order. TicketId: " + IntegerToString(closingOrder.Ticket));
	                            }
	                        }
	               
	                        Print(StringFormat("Execution done for order (%d) by EA (%d)", trans.order, MagicNumber));
	                    }
	                    else
	                    {
	                        Print(StringFormat("Waiting for remainder deals for order (%d) by EA (%d)", trans.order, MagicNumber));
	                    }
	                }
	
	                int potentialClosingOrdersCount = potentialClosingOrders.Count();
	                for(int i = potentialClosingOrdersCount - 1; i >= 0; i--)            
	                    potentialClosingOrders.Remove(i);
	               
	                delete(potentialClosingOrders);   
	            }
	         
	            if (foundOrderForDeal)
	            {
	                Print("Updated wallet order with info from deal.");
	            }
	            else if (trans.symbol == OrderSymbolTarget && dealInfo.Magic() == MagicNumber) // only report if it was not expected
	            {
	                PrintFormat("Couldn't find order in wallet belonging to deal. Possible manual transaction. Deal: %s", IntegerToString(trans.deal));
	            }
	         
	            break;
	        }
	    }
	   
	    if (foundOrderUpdate)
	    {
	        _ea.GetWallet().PrintOrderChanges();
	    }
}

//+------------------------------------------------------------------------+
//|  Error Handling                                                        |
//+------------------------------------------------------------------------+

void HandleErrors(string errorMessage)
{
	Print(errorMessage);
	
	if (Error != NULL             // Already had an error this quote
	|| errorMessage == ErrorPreviousQuote) // Error is the same as previous quote
	{
	    return;
	}
	
	if (AlertOnError) Alert(errorMessage);
	if (NotificationOnError) SendNotification(StringFormat("Error by EA (%d) %s", MagicNumber, errorMessage));
	if (EmailOnError) SendMail(StringFormat("Error by EA (%d)", MagicNumber), errorMessage);
	
	Error = errorMessage;
	ErrorPreviousQuote = Error;
	ErrorPreviousQuoteDateTime = TimeCurrent();
	
}

//+------------------------------------------------------------------------+
//|  Expert Deinitialization Function                                      |
//+------------------------------------------------------------------------+

void OnDeinit(const int reason)
{
	delete(_ea);
	delete(AskFunc);
	delete(BidFunc);
	delete(TimeFunc);
}

//+------------------------------------------------------------------------+
//|  Expert Advisor Function                                               |
//+------------------------------------------------------------------------+

datetime LastActionTime = 0;
void OnTick()
{
	if (OneQuotePerBar)
	{
	    datetime currentTime = iTime(_Symbol, _Period, 0);
	    if (LastActionTime == currentTime)
	    {
	        return;
	    }
	    else
	    {
	        LastActionTime = currentTime;
	    }
	}
	
	Error = NULL;
	
	_ea.HandleTick();
	
	if (IsDemoLiveOrVisualMode)
	{
	    MqlDateTime mql_datetime;
	    TimeCurrent(mql_datetime);
	    string comment = "\n      :: Server Date Time : " + (string)mql_datetime.year + "." + (string)mql_datetime.mon + "." + (string)mql_datetime.day + "   " + TimeToString(TimeCurrent(), TIME_SECONDS)
	    + OrderInfoComment;
	
	    if (DisplayOnChartError)
		{
		   if (Error != NULL) comment += "\n      :: Current error : " + Error;
		   if (ErrorPreviousQuote != NULL) comment += "\n      :: Last error (" + TimeToString(ErrorPreviousQuoteDateTime) + "): " + ErrorPreviousQuote;
	    }
	    if (DisplayOnChartWarning)
		{
		   if (Warning != NULL) comment += "\n      :: Warning : " + Warning;
	    }
	
	    comment += "\n     ------------------------------------------------------------";
	    Comment(comment);
	}
}


