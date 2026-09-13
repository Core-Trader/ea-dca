//+------------------------------------------------------------------+
//|                                                       DCA_EA.mq5 |
//|                          Dollar-Cost-Averaging Expert Advisor    |
//|                          Entries: QMP Filter (MACD_Platinum +    |
//|                          QQE Adv) dots, gated by BB and/or QQE   |
//|                          zone breach. See EA_User_Guide.docx.    |
//+------------------------------------------------------------------+
#property copyright   "EA-DCA-V1.0"
#property version     "1.00"
#property description "Dollar-Cost-Averaging (DCA) trade management EA."
#property description "Build phase: input block + indicator handles + OnInit validation checks +"
#property description "entry-signal pipeline, sequence tracking, and position sizing. Exit logic"
#property description "and state persistence are added in the next drafting phase."

#include <Trade\Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//| Enumerations for dropdown-style inputs                            |
//| (native MQL5 enums are used where one already exists — see the    |
//| analysis report §13, item 6)                                      |
//+------------------------------------------------------------------+
enum ENUM_MULTIPLIER_SYSTEM
  {
   MULT_SAFE = 0,          // Safe (Delayed Fib): 1,1,1,2,3,5,8
   MULT_LINEAR,            // Linear (Arithmetic): 1,2,3,4,5,6,7
   MULT_FIBONACCI,         // Classic Fibonacci: 1,2,3,5,8,13
   MULT_AGGRESSIVE,        // Aggressive (Lucas): 1,2,4,6,10,16
   MULT_MARTINGALE,        // Martingale: 1,2,4,8,16,32
   MULT_CUSTOM             // Custom (uses InpFibSequence string below)
  };

enum ENUM_LOT_SIZING_MODE
  {
   LOT_FIXED = 0,          // Fixed Lot Size
   LOT_PERCENT_BALANCE,    // % of Balance per Trade
   LOT_PERCENT_EQUITY,     // % of Equity per Trade
   LOT_STEP_BALANCE,       // Step-Based (Account Balance)
   LOT_STEP_EQUITY         // Step-Based (Account Equity)
  };

enum ENUM_TRADE_DIRECTION
  {
   DIRECTION_BOTH = 0,     // Both Buy & Sell
   DIRECTION_BUY_ONLY,     // Buy Only
   DIRECTION_SELL_ONLY     // Sell Only
  };

enum ENUM_INDICATOR_MODE
  {
   INDICATOR_BB_ONLY = 0,  // Bollinger Bands Only
   INDICATOR_QQE_ONLY,     // QQE Adv Only
   INDICATOR_BOTH          // Both Bollinger Bands & QQE
  };

enum ENUM_EXIT_STRATEGY
  {
   EXIT_BB_CENTRE_BAND = 0,  // BB Centre Band          (BB Mode)
   EXIT_BB_OPPOSITE_BAND,    // BB Opposite Band        (BB Mode)
   EXIT_QQE50_RECOVERY,      // QQE 50 + Recovery       (QQE Mode)
   EXIT_FIRST_PROFITABLE,    // First Profitable Close  (Both Modes)
   EXIT_FIXED_TARGET,        // Fixed Profit Target     (Both Modes)
   EXIT_PURE_TRAILING        // Pure Trailing Stop      (Both Modes)
  };

enum ENUM_FIXED_TARGET_TYPE
  {
   TARGET_CURRENCY = 0,    // Fixed Currency Amount
   TARGET_PIPS,            // Fixed Pips From Entry
   TARGET_ATR              // ATR Multiple
  };

enum ENUM_TIME_REFERENCE
  {
   TIME_BROKER = 0,        // Broker Time (Server)
   TIME_LOCAL,             // Local Time (Computer)
   TIME_GMT_OFFSET         // GMT +/- Offset
  };

enum ENUM_EOX_ACTION       // shared by End of Day and End of Week
  {
   EOX_CLOSE_IF_PROFITABLE = 0,  // Close Sequences If Profitable
   EOX_CLOSE_IF_LOSING,          // Close Sequences If Losing
   EOX_CLOSE_ALL,                // Close All Sequences Regardless
   EOX_DO_NOTHING                // Do Nothing (let sequences run their course)
  };

enum ENUM_PARTIAL_CLOSE_PERCENT
  {
   PARTIAL_CLOSE_NONE = 0,  // None (leave full remaining position open)
   PARTIAL_CLOSE_50   = 50  // 50% of the remaining position — value kept at 50
                             // (not 1) so the original default.set's
                             // InpPartialClosePercent=50 still imports correctly
  };

enum ENUM_MA_FILTER_BEHAVIOUR
  {
   MA_BUY_ABOVE_SELL_BELOW = 0,  // Buy Above MA / Sell Below MA (trend-following)
   MA_BUY_BELOW_SELL_ABOVE       // Buy Below MA / Sell Above MA (reversion to mean)
  };

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

input group "Position Sizing"
input ENUM_MULTIPLIER_SYSTEM InpMultiplierSystem      = MULT_LINEAR;      // Multiplier System
input string                 InpFibSequence           = "1,3,5,8,13";     // Custom Multiplier String (if System = Custom)
input double                 InpInitialLot            = 0.01;             // Initial (Base) Lot Size
input ENUM_LOT_SIZING_MODE   InpLotSizeMode           = LOT_FIXED;        // Lot Sizing Mode
input double                 InpLotPercent            = 15.0;             // % of Balance/Equity per Trade
input double                 InpStepAmount            = 1000.0;           // Step Amount (account increment)
input double                 InpLotPerStep            = 0.01;             // Lot Size per Step
input double                 InpMaxInitialLot         = 1.0;              // Max Initial Lot Size (0 = uncapped)

input group "Trading Parameters"
input long                   InpMagicNumber            = 123456;           // Magic Number (must be unique per Symbol)
input int                    InpSlippage               = 3;                // Slippage (points)
input int                    InpMaxSpread              = 40;               // Max Spread (points)
input int                    InpMaxTradesPerSequence   = 0;                // Max Trades per Sequence (0 = unlimited)
input int                    InpMaxSequencesPerDirection = 3;              // Max Concurrent Sequences per Direction
input ENUM_TRADE_DIRECTION   InpTradeDirection         = DIRECTION_BOTH;   // Allowed Trade Direction
input bool                   InpAllowBuySellAtSameTime = true;             // Allow Buy & Sell at the Same Time (needs hedging account)
input string                 InpUserComment            = "EA-DCA-V1.0";      // Trade Comment

input group "Indicator Mode"
input ENUM_INDICATOR_MODE    InpIndicatorMode          = INDICATOR_BB_ONLY; // Entry Indicator Mode

input group "QMP Filter Settings"
input int                    InpQMPFast                = 12;    // QMP: MACD Fast EMA Period
input int                    InpQMPSlow                = 26;    // QMP: MACD Slow EMA Period
input int                    InpQMPSmooth              = 9;     // QMP: MACD Signal Smoothing Period
input int                    InpQMPSF                  = 1;     // QMP: QQE Smoothing Factor
input int                    InpQMPRSI_Period          = 8;     // QMP: QQE RSI Period
input int                    InpQMPWP                  = 3;     // QMP: QQE Wilders Period Multiplier

input group "Bollinger Band Settings"
input int                    InpBBPeriod                     = 35;           // BB Period
input double                 InpBBDeviation                  = 2.25;         // BB Deviation
input ENUM_APPLIED_PRICE     InpBBAppliedPrice               = PRICE_HIGH;   // BB Applied Price
input bool                   InpUseBBWidthFilter             = false;        // Use BB Width Filter
input double                 InpBBMinWidthPercent            = 0.5;          // BB Min Width %
input bool                   InpRequireCenterBandCross       = true;         // Require Centre Band Cross Before New Sequence
input bool                   InpNoTriggerOnCentralBandBreach = true;         // Don't Open 1st Trade on Centre Band Breach
input bool                   InpRequireBBBandTouchForReentry = false;        // Require Band Touch Before Re-Entry
input bool                   InpBBExitOnBreach               = true;         // Exit on Breach, Not Just Close (Centre Band Exit)
input bool                   InpAlwaysCloseOnOppositeBand    = false;        // Always Close on Opposite Band (Opposite Band Exit)

input group "QQE Settings"
input double                 InpQQEOverbought                 = 60.0;   // QQE Overbought Level (>= 50)
input double                 InpQQEOversold                   = 40.0;   // QQE Oversold Level (<= 50)
input int                    InpQQESmoothingPeriod            = 7;      // QQE Smoothing Factor (SF)
input int                    InpQQERSIPeriod                  = 14;     // QQE RSI Period
input int                    InpQQEMultiplier                 = 1;      // QQE Wilders Period Multiplier (WP)
input bool                   InpRequireQQEScenarioBForReentry = false;  // Require QQE Extreme Before Re-Entry

input group "Exit Strategy"
input ENUM_EXIT_STRATEGY     InpExitStrategy            = EXIT_BB_CENTRE_BAND; // Exit Strategy
input bool                   InpUseDynamicStop          = false;               // Use Dynamic Stop (not compatible with Partial Close)
input double                 InpDynamicStopDistancePips = 20.0;                // Dynamic Stop Distance (pips)

input group "Recovery Mode Settings"
input double                 InpBreakevenBufferPips     = 10.0;   // Recovery Buffer Above Breakeven (pips)

input group "Exit Parameters - Fixed Target"
input ENUM_FIXED_TARGET_TYPE InpFixedTargetType         = TARGET_PIPS;  // Fixed Target Type
input double                 InpProfitTargetCurrency    = 50.0;         // Profit Target (Account Currency)
input double                 InpProfitTargetPips        = 50.0;         // Profit Target (Pips)
input int                    InpATRPeriod               = 14;           // ATR Period (also shared by Trailing & Signal Distance ATR options)
input double                 InpATRMultiplier           = 2.0;          // ATR Multiplier (Fixed Target)
input bool                   InpShowTakeProfitLine      = true;         // Show Take Profit Line (Pips/ATR modes only)
input color                  InpTakeProfitLineColor     = clrDodgerBlue; // Take Profit Line Colour

input group "Exit Parameters - Trailing Stop"
input string                 TRAILING_START_INFO              = "Info only: whichever of Trailing Start (pips) or Trailing Start ($) triggers first drives the trail; the other is then ignored.";
input int                    InpTrailingStartPips             = 50;     // Trailing Start (profit in pips, 0 = disabled)
input double                 InpTrailingStartDollars          = 50.0;   // Trailing Start (profit in $, 0 = disabled)
input double                 InpTrailingStepPips              = 40;     // Trailing Distance (pips)
input bool                   InpUseATRForTrailingStart        = false;  // Use ATR for Trailing Start
input double                 InpTrailingStartATRMultiplier    = 1.5;    // Trailing Start ATR Multiplier
input bool                   InpUseATRForTrailingDistance     = false;  // Use ATR for Trailing Distance
input double                 InpTrailingDistanceATRMultiplier = 1.0;    // Trailing Distance ATR Multiplier
input int                    InpTrailingStepBlockPips         = 1;      // Trailing Step Block (pips granularity)

input group "Risk Reduction"
input bool                   InpUseRiskReduction        = false; // Enable Risk Reduction
input int                    InpRiskReductionMinTrades  = 5;     // Minimum Trades to Activate
input double                 InpRiskReductionBufferPips = 10.0;  // Breakeven + Buffer (pips)

input group "Trading Session Times"
input bool                   InpUseTimeFilter    = false;         // Enable Trading Hours Filter
input ENUM_TIME_REFERENCE    InpTimeReference    = TIME_BROKER;   // Time Reference
input int                    InpGMTOffset        = 0;             // GMT Offset Hours (-12..+12, only if Time Reference = GMT)
input string                 InpTradingStartTime = "08:00";        // Trading Start Time (HH:MM)
input string                 InpTradingEndTime   = "20:00";        // Trading End Time (HH:MM)
input bool                   InpTradeMonday      = true;           // Trade Monday
input bool                   InpTradeTuesday     = true;           // Trade Tuesday
input bool                   InpTradeWednesday   = true;           // Trade Wednesday
input bool                   InpTradeThursday    = true;           // Trade Thursday
input bool                   InpTradeFriday      = true;           // Trade Friday
input bool                   InpTradeSaturday    = true;           // Trade Saturday
input bool                   InpTradeSunday      = true;           // Trade Sunday

input group "End of Day"
input bool                   InpUseEOD    = false;                    // Enable End of Day Actions
input string                 InpEODTime   = "20:00";                  // Daily Close Time (independent of Trading Hours)
input ENUM_EOX_ACTION        InpEODAction = EOX_CLOSE_IF_PROFITABLE;  // End of Day Action

input group "End of Week"
input bool                   InpUseEOW    = false;                    // Enable End of Week Actions (Friday)
input string                 InpEOWTime   = "22:00";                  // Friday Close Time
input ENUM_EOX_ACTION        InpEOWAction = EOX_CLOSE_IF_PROFITABLE;  // End of Week Action

input group "Advanced - Partial Close Management"
input string                     InpPartialClose_Info            = "Info only: this closes all but one trade in the sequence. Only works with Exit Strategy = BB Centre Band or QQE 50 + Recovery. Not compatible with Dynamic Stop.";
input bool                       InpUsePartialClose              = false;             // Enable Partial Close Management
input ENUM_PARTIAL_CLOSE_PERCENT InpPartialClosePercent          = PARTIAL_CLOSE_50;  // Percent to Close on Remaining Position
input double                     InpPartialCloseBreakevenStepPips = 10.0;             // Trailing Distance for Remaining Position (pips, 0 = disabled -> breakeven only)

input group "Advanced - Signal Distance Filter"
input bool                   InpUseMinimumSignalDistance = false; // Enable Minimum Distance Between Signals
input double                 InpMinDistancePips          = 10.0;  // Minimum Distance Between Signals (pips)
input bool                   InpUseATRForMinDistance     = false; // Use ATR for Minimum Distance
input double                 InpMinDistanceATRMultiplier = 1.5;   // Minimum Distance ATR Multiplier
input string                 SIGNAL_DISTANCE_ATR_INFO    = "Info only: ATR Period is taken from the Exit Parameters - Fixed Target section (InpATRPeriod).";

input group "Advanced - Session Profit Limit"
input double                  InpStopAfterProfitPerSession = 0.0; // Stop New Trades After Profit per Session ($, 0 = off)

input group "Advanced - Entry Options"
input string                  InpAllDCA_SignalsMatchEntry_Info = "Info only: if enabled, only one sequence per direction runs, and every add-on trade must match the same entry rules (not just a QMP dot).";
input bool                    InpAllSignalsMatchEntryCriteria  = false; // All DCA Signals Must Match Entry Criteria

input group "Advanced - Higher Timeframe Direction Filter"
input bool                    InpTradeInHigherTFDirection = false;     // Trade Only in Higher Timeframe Direction
input ENUM_TIMEFRAMES         InpHigherTimeframe          = PERIOD_H4; // Higher Timeframe (must be > chart timeframe)

input group "Advanced - MA Filter (First Trade Only)"
input bool                    InpUseMAFilter        = false;                    // Use MA Filter
input ENUM_MA_FILTER_BEHAVIOUR InpMAFilterBehaviour  = MA_BUY_ABOVE_SELL_BELOW; // MA Filter Behaviour
input int                     InpMAPeriod           = 50;                       // MA Period
input ENUM_MA_METHOD          InpMAMethod           = MODE_EMA;                 // MA Method
input ENUM_APPLIED_PRICE      InpMAAppliedPrice     = PRICE_CLOSE;              // MA Applied Price

input group "On Screen Displays"
input bool                    InpShowTrailingStops       = true;         // Show Trailing Stop Lines
input color                   InpBuyTrailingColor        = clrLime;      // Buy Trailing Stop Colour
input color                   InpSellTrailingColor       = clrRed;       // Sell Trailing Stop Colour
input ENUM_LINE_STYLE         InpTrailingLineStyle       = STYLE_DASH;   // Trailing Stop Line Style
input int                     InpTrailingLineWidth       = 1;            // Trailing Stop Line Width
input bool                    InpShowBreakevenBufferLine = true;         // Show Breakeven Buffer Line
input color                   InpBreakevenBufferColor    = clrOrange;    // Breakeven Buffer Line Colour
input bool                    InpShowBreakevenLine       = true;         // Show Breakeven Line
input color                   InpBreakevenLineColor      = clrYellow;    // Breakeven Line Colour
input bool                    InpShowRiskReductionLine   = true;         // Show Risk Reduction Line
input color                   InpRiskReductionColor      = clrAqua;      // Risk Reduction Line Colour
input bool                    InpShowSequenceStartEndLines = true;       // Show Sequence Start/End Lines
input color                   InpSequenceStartColor      = clrDodgerBlue;// Sequence Start Line Colour
input color                   InpSequenceEndColor        = clrMagenta;   // Sequence End Line Colour
input ENUM_LINE_STYLE         InpSequenceLineStyle       = STYLE_DOT;    // Sequence Start/End Line Style
input int                     InpSequenceLineWidth       = 1;            // Sequence Start/End Line Width

input group "Display Panel"
input bool                    InpShowDisplayPanel  = true;                 // Show Info Panel on Chart
input int                     InpPanelX            = 12;                   // Panel X Offset (pixels)
input int                     InpPanelY            = 24;                   // Panel Y Offset (pixels)
input color                   InpPanelHeaderColor  = clrGold;              // Panel Header Colour
input color                   InpPanelProfitColor  = clrLime;              // Panel Profit Colour
input color                   InpPanelLossColor    = clrTomato;            // Panel Loss Colour
input color                   InpPanelInfoColor    = clrSilver;            // Panel Info Text Colour
input color                   InpPanelBgColor      = (color)2103830;       // Panel Background Colour
input color                   InpPanelBorderColor  = (color)5916220;       // Panel Border Colour

//+------------------------------------------------------------------+
//| Global indicator handles                                          |
//+------------------------------------------------------------------+
int g_qmpHandle    = INVALID_HANDLE;  // QMP Filter — entry trigger dots (current TF)
int g_qqeHandle    = INVALID_HANDLE;  // QQE Adv — standalone entry-zone breach (current TF)
int g_bbHandle     = INVALID_HANDLE;  // native iBands() — standalone entry-zone breach (current TF)
int g_atrHandle    = INVALID_HANDLE;  // native iATR() — shared by Fixed Target / Trailing / Signal Distance
int g_maHandle     = INVALID_HANDLE;  // native iMA() — MA Filter (first trade only)
int g_qqeHtfHandle = INVALID_HANDLE;  // QQE Adv on the Higher Timeframe (HTF Direction Filter)
int g_bbHtfHandle  = INVALID_HANDLE;  // native iBands() on the Higher Timeframe (HTF Direction Filter)

//+------------------------------------------------------------------+
//| Sequence tracking (in-memory only for now — see report §10;       |
//| MQL5/Files/ persistence is a later phase).                        |
//|                                                                    |
//| Design note: while a sequence remains open, every further         |
//| same-direction signal adds to it as a DCA trade — this is the     |
//| core DCA mechanic. A genuinely NEW, parallel sequence only forms  |
//| once an existing sequence's trade count is at the                 |
//| InpMaxTradesPerSequence cap (0 = never, i.e. unlimited adds to a   |
//| single sequence).                                                  |
//+------------------------------------------------------------------+
struct Sequence
  {
   ulong    tickets[];      // position tickets belonging to this sequence, in open order
   int      count;          // number of trades in the sequence (== ArraySize(tickets))
   double   avgPrice;       // volume-weighted average entry price across all trades
   double   totalVolume;    // sum of all trade volumes in the sequence
   datetime lastEntryTime;  // time of the most recent trade — for the Signal Distance filter (later phase)
   double   lastEntryPrice; // price of the most recent trade — for the Signal Distance filter (later phase)
   double   lockedBaseLot;  // base lot (pre-multiplier), fixed at trade #1 and reused for the whole sequence
   bool     recoveryModeActive; // BB Centre/BB Opposite(non-forced)/QQE50 condition met but not yet profitable
   bool     trailStopActive;    // shared by Dynamic Stop and Pure Trailing Stop (mutually exclusive by Exit Strategy)
   double   trailStopPrice;     // current virtual stop level for whichever trailing mechanism is active
   bool     partialCloseDone;   // true once Partial Close has executed; also pauses new entries to this sequence
   long     sequenceId;         // stable identifier for chart-object naming — array index gets reused on removal, this doesn't
   datetime startTime;          // when trade #1 opened — for the Sequence Start chart line
  };

Sequence g_buySequences[];
Sequence g_sellSequences[];

long g_nextSequenceId = 1;   // monotonically increasing — never reused, unlike array indices

datetime g_lastBarTime = 0;
ulong    g_lastSaveTickMs = 0;   // GetTickCount64() at the last state save — throttles routine per-tick saves
double   g_pipSize = 0.0;   // price value of "1 pip" for this symbol — computed once in OnInit()

//--- Zone-breach "armed" latches. Each stays true once triggered until the
//--- (not-yet-built) re-entry logic resets it — see the TODO in
//--- CloseSequenceAndCleanup() below.
bool g_bbBuyArmed=false, g_bbSellArmed=false, g_qqeBuyArmed=false, g_qqeSellArmed=false;

//--- Require Centre Band Cross Before New Sequence — starts TRUE so the
//--- very first sequence at EA startup isn't blocked artificially.
bool g_centreCrossReadyBuy = true, g_centreCrossReadySell = true;

//--- Higher Timeframe Direction Filter — same latching pattern as the
//--- current-timeframe zone-armed flags above, but read from the HTF's
//--- own closed bars.
bool g_bbBuyArmedHtf=false, g_bbSellArmedHtf=false, g_qqeBuyArmedHtf=false, g_qqeSellArmedHtf=false;
datetime g_lastHtfBarTime = 0;

//+------------------------------------------------------------------+
//| EFFICIENCY: per-closed-bar indicator snapshot. BB/QQE/ATR values   |
//| at shift=1 don't change again once that bar closes, so fetching    |
//| them ONCE per bar (here) and reusing the cached value everywhere   |
//| else — instead of each check function independently calling        |
//| CopyBuffer() for the same data — removes several redundant         |
//| terminal calls per bar (BB alone was being fetched up to 6x).       |
//+------------------------------------------------------------------+
double g_bar1High=0, g_bar1Low=0, g_bar1Close=0;
double g_bbMiddle1=0, g_bbUpper1=0, g_bbLower1=0; bool g_bbSnapshotValid=false;
double g_qqeLine1=0;                              bool g_qqeSnapshotValid=false;
double g_atr1=0;                                  bool g_atrSnapshotValid=false;

//+------------------------------------------------------------------+
//| EFFICIENCY: per-tick Bid/Ask snapshot, refreshed once at the top   |
//| of OnTick() instead of every per-tick check function independently |
//| calling SymbolInfoDouble() (11 call sites collapsed to 1 fetch).   |
//+------------------------------------------------------------------+
double g_tickBid=0, g_tickAsk=0;

//+------------------------------------------------------------------+
//| Pending QMP signal — persists across bars until the zone arms.     |
//| Guide: "there is a QMP dot but the QQE level has not yet been      |
//| breached, but a few candles later there is a breach... that        |
//| previous QMP dot is still a valid trade signal... no time limit."  |
//| A newer dot (either direction) always supersedes an older pending  |
//| one, matching QMP's own trend-flip semantics. The signal bar's own |
//| centre-band relationship is captured at record time (not           |
//| recomputed later) since NoTriggerOnCentreBandBreachPasses() needs  |
//| the ORIGINAL signal candle's state, which may be many bars in the  |
//| past by the time the zone finally arms.                            |
//+------------------------------------------------------------------+
bool g_pendingSignal=false, g_pendingSignalIsBuy=false, g_pendingSignalCentreBreached=false;

//+------------------------------------------------------------------+
//| Session / EOD / EOW / Session Profit Limit tracking.               |
//+------------------------------------------------------------------+
bool     g_wasInSession=false;
double   g_sessionRealizedProfit=0.0;
datetime g_lastEODActionDay=0, g_lastEOWActionDay=0;

//+------------------------------------------------------------------+
//| Pip conversion, matching the same 3/5-digit-broker convention      |
//| already used by QMP_Filter.mq5's own point-doubling logic, so all  |
//| "pips" inputs behave consistently with the existing indicators.    |
//+------------------------------------------------------------------+
double PipsToPrice(double pips)
  {
   return(pips * g_pipSize);
  }

//+------------------------------------------------------------------+
//| Refreshes the per-closed-bar snapshot (see globals above). Called  |
//| once at the top of ProcessNewBar(), before anything that reads     |
//| BB/QQE/ATR/bar-OHLC for the just-closed bar.                       |
//+------------------------------------------------------------------+
void RefreshBarSnapshot()
  {
   g_bar1High  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   g_bar1Low   = iLow(_Symbol,  PERIOD_CURRENT, 1);
   g_bar1Close = iClose(_Symbol, PERIOD_CURRENT, 1);

   g_bbSnapshotValid = false;
   if(g_bbHandle != INVALID_HANDLE)
     {
      double mid[1], up[1], low[1];
      if(CopyBuffer(g_bbHandle, 0, 1, 1, mid) > 0 &&
         CopyBuffer(g_bbHandle, 1, 1, 1, up)  > 0 &&
         CopyBuffer(g_bbHandle, 2, 1, 1, low) > 0)
        {
         g_bbMiddle1 = mid[0];
         g_bbUpper1  = up[0];
         g_bbLower1  = low[0];
         g_bbSnapshotValid = true;
        }
     }

   g_qqeSnapshotValid = false;
   if(g_qqeHandle != INVALID_HANDLE)
     {
      double q[1];
      if(CopyBuffer(g_qqeHandle, 0, 1, 1, q) > 0)
        {
         g_qqeLine1 = q[0];
         g_qqeSnapshotValid = true;
        }
     }

   g_atrSnapshotValid = false;
   if(g_atrHandle != INVALID_HANDLE)
     {
      double a[1];
      if(CopyBuffer(g_atrHandle, 0, 1, 1, a) > 0)
        {
         g_atr1 = a[0];
         g_atrSnapshotValid = true;
        }
     }
  }

//+====================================================================+
//| CHART DISPLAY (Step 7) — low-level object helpers                  |
//| Defined here (ahead of RemoveSequenceAt(), which needs them to      |
//| clean up a closed sequence's objects) rather than down with the     |
//| rest of the display code, to keep every function defined before     |
//| its first use.                                                      |
//+====================================================================+
#define EA_DCA_OBJ_PREFIX "EA-DCA_"

string SeqObjName(string kind, bool isBuy, long sequenceId)
  {
   return(StringFormat("%s%s_%s_%I64d", EA_DCA_OBJ_PREFIX, kind, isBuy ? "Buy" : "Sell", sequenceId));
  }

void DeleteObjectIfExists(string name)
  {
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
  }

void DrawOrUpdateHLine(string name, double price, color clr, ENUM_LINE_STYLE style, int width)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
     }
   else
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
  }

//+------------------------------------------------------------------+
//| Deletes the "live" per-sequence lines (trail/breakeven/buffer/     |
//| risk-reduction) once a sequence closes. The Sequence Start/End     |
//| vertical markers are deliberately NOT touched here — they're meant |
//| to persist as a historical record of the sequence's lifetime.      |
//+------------------------------------------------------------------+
void DeleteSequenceChartObjects(bool isBuy, long sequenceId)
  {
   DeleteObjectIfExists(SeqObjName("Trail",   isBuy, sequenceId));
   DeleteObjectIfExists(SeqObjName("BE",      isBuy, sequenceId));
   DeleteObjectIfExists(SeqObjName("BEBuf",   isBuy, sequenceId));
   DeleteObjectIfExists(SeqObjName("RiskRed", isBuy, sequenceId));
  }

void DrawSequenceEndLine(bool isBuy, long sequenceId)
  {
   if(!InpShowSequenceStartEndLines) return;
   string endName = SeqObjName("SeqEnd", isBuy, sequenceId);
   if(ObjectFind(0, endName) >= 0) return;   // already drawn
   ObjectCreate(0, endName, OBJ_VLINE, 0, TimeCurrent(), 0);
   ObjectSetInteger(0, endName, OBJPROP_COLOR, InpSequenceEndColor);
   ObjectSetInteger(0, endName, OBJPROP_STYLE, InpSequenceLineStyle);
   ObjectSetInteger(0, endName, OBJPROP_WIDTH, InpSequenceLineWidth);
   ObjectSetInteger(0, endName, OBJPROP_BACK, true);
   ObjectSetInteger(0, endName, OBJPROP_SELECTABLE, false);
  }

//+------------------------------------------------------------------+
//| Re-syncs a sequence's tickets/count/avgPrice/volume against what's |
//| actually still open — positions can disappear outside the EA's    |
//| control (broker stop-out, manual intervention, our own partial    |
//| close), so tracking must never assume the in-memory state is      |
//| still accurate without checking. Also guards against ticket reuse |
//| by re-verifying symbol and magic number on every position.         |
//| (Lives here, ahead of OnInit(), because LoadState() needs it.)     |
//+------------------------------------------------------------------+
void SyncSequenceFromLivePositions(bool isBuy, int seqIdx)
  {
   int n = isBuy ? g_buySequences[seqIdx].count : g_sellSequences[seqIdx].count;
   ulong liveTickets[];
   ArrayResize(liveTickets, n);
   double liveVolume = 0.0, weightedPriceSum = 0.0;
   int liveCount = 0;

   for(int i = 0; i < n; i++)
     {
      ulong ticket = isBuy ? g_buySequences[seqIdx].tickets[i] : g_sellSequences[seqIdx].tickets[i];
      if(PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
         double vol       = PositionGetDouble(POSITION_VOLUME);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         liveTickets[liveCount] = ticket;
         liveCount++;
         weightedPriceSum += openPrice * vol;
         liveVolume += vol;
        }
     }
   ArrayResize(liveTickets, liveCount);

   if(isBuy)
     {
      ArrayCopy(g_buySequences[seqIdx].tickets, liveTickets);
      g_buySequences[seqIdx].count       = liveCount;
      g_buySequences[seqIdx].totalVolume = liveVolume;
      if(liveVolume > 0.0) g_buySequences[seqIdx].avgPrice = weightedPriceSum / liveVolume;
     }
   else
     {
      ArrayCopy(g_sellSequences[seqIdx].tickets, liveTickets);
      g_sellSequences[seqIdx].count       = liveCount;
      g_sellSequences[seqIdx].totalVolume = liveVolume;
      if(liveVolume > 0.0) g_sellSequences[seqIdx].avgPrice = weightedPriceSum / liveVolume;
     }
  }

//+------------------------------------------------------------------+
//| Removes a sequence via swap-with-last-and-shrink (order among      |
//| sequences carries no meaning beyond "most recently opened", which  |
//| FindOpenSequenceWithRoom() already handles by scanning). Relies on |
//| MQL5's documented struct-assignment behavior of deep-copying       |
//| dynamic array members (tickets[]) — this is standard, well-        |
//| established behavior, not an assumption specific to this EA.       |
//| Also draws the sequence's end-marker line and cleans up its live   |
//| chart objects (Step 7) before the slot is reused.                  |
//+------------------------------------------------------------------+
void RemoveSequenceAt(bool isBuy, int idx)
  {
   long sequenceId = isBuy ? g_buySequences[idx].sequenceId : g_sellSequences[idx].sequenceId;
   DrawSequenceEndLine(isBuy, sequenceId);
   DeleteSequenceChartObjects(isBuy, sequenceId);

   int total = isBuy ? ArraySize(g_buySequences) : ArraySize(g_sellSequences);
   int last  = total - 1;
   if(idx != last)
     {
      if(isBuy) g_buySequences[idx]  = g_buySequences[last];
      else      g_sellSequences[idx] = g_sellSequences[last];
     }
   if(isBuy) ArrayResize(g_buySequences, last);
   else      ArrayResize(g_sellSequences, last);
  }

//+====================================================================+
//| STATE PERSISTENCE (report §10)                                     |
//|                                                                    |
//| Plain delimited text under MQL5/Files/, one file per (Symbol,      |
//| Magic Number), rewritten in full on every save rather than         |
//| appended — simpler to reason about than incremental updates, and   |
//| cheap enough given this EA trades on bar closes, not every tick.   |
//| Saved unconditionally once per tick (see OnTick()) rather than via |
//| a fine-grained dirty flag — simpler and harder to get wrong than   |
//| tracking "did anything change" across two dozen call sites, at the |
//| cost of a small, inconsequential amount of extra disk I/O.         |
//+====================================================================+
string GetStateFilePath()
  {
   return(StringFormat("EA-DCA-V1.0_state_%s_%I64d.txt", _Symbol, InpMagicNumber));
  }

void WriteSequencesToFile(int handle, bool isBuy)
  {
   int total = isBuy ? ArraySize(g_buySequences) : ArraySize(g_sellSequences);
   for(int i = 0; i < total; i++)
     {
      int    count          = isBuy ? g_buySequences[i].count          : g_sellSequences[i].count;
      double avgPrice       = isBuy ? g_buySequences[i].avgPrice       : g_sellSequences[i].avgPrice;
      double totalVolume    = isBuy ? g_buySequences[i].totalVolume    : g_sellSequences[i].totalVolume;
      double lockedBaseLot  = isBuy ? g_buySequences[i].lockedBaseLot  : g_sellSequences[i].lockedBaseLot;
      int    recoveryActive = isBuy ? g_buySequences[i].recoveryModeActive : g_sellSequences[i].recoveryModeActive;
      int    trailActive    = isBuy ? g_buySequences[i].trailStopActive   : g_sellSequences[i].trailStopActive;
      double trailPrice     = isBuy ? g_buySequences[i].trailStopPrice    : g_sellSequences[i].trailStopPrice;
      int    partialDone    = isBuy ? g_buySequences[i].partialCloseDone  : g_sellSequences[i].partialCloseDone;
      long   lastTime       = isBuy ? (long)g_buySequences[i].lastEntryTime  : (long)g_sellSequences[i].lastEntryTime;
      double lastPrice      = isBuy ? g_buySequences[i].lastEntryPrice   : g_sellSequences[i].lastEntryPrice;
      long   sequenceId     = isBuy ? g_buySequences[i].sequenceId       : g_sellSequences[i].sequenceId;
      long   startTime      = isBuy ? (long)g_buySequences[i].startTime : (long)g_sellSequences[i].startTime;

      string ticketsStr = "";
      for(int t = 0; t < count; t++)
        {
         ulong ticket = isBuy ? g_buySequences[i].tickets[t] : g_sellSequences[i].tickets[t];
         ticketsStr += (t > 0 ? ";" : "") + (string)ticket;
        }

      string line = StringFormat("SEQ|%s|%d|%.5f|%.2f|%.5f|%d|%d|%.5f|%d|%I64d|%.5f|%I64d|%I64d|%s",
                                  isBuy ? "BUY" : "SELL", count, avgPrice, totalVolume, lockedBaseLot,
                                  recoveryActive, trailActive, trailPrice, partialDone, lastTime, lastPrice,
                                  sequenceId, startTime, ticketsStr);
      FileWriteString(handle, line + "\n");
     }
  }

//+------------------------------------------------------------------+
//| BUG FIX: state persistence must never run inside the Strategy      |
//| Tester. Files written via FileOpen()/FileWrite() persist between   |
//| SEPARATE backtest runs of the same EA on the same symbol — so      |
//| without this guard, a fresh backtest's OnInit() would load         |
//| whatever zone-armed/centre-cross/pending-signal state a PREVIOUS   |
//| run happened to end in, then replay the same historical period     |
//| from the beginning with that leftover, mismatched state. This was  |
//| the primary cause of a reported large, hard-to-explain drop in     |
//| trade count between consecutive backtests with identical settings. |
//| State persistence exists for live/demo crash recovery only — a     |
//| backtest has no such concept and must always start clean.          |
//+------------------------------------------------------------------+
void SaveState()
  {
   if(MQLInfoInteger(MQL_TESTER)) return;

   int handle = FileOpen(GetStateFilePath(), FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      Print("EA-DCA: failed to open state file for writing. Error ", GetLastError());
      return;
     }

   string globalLine = StringFormat("GLOBAL|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%.2f|%d|%I64d|%I64d",
                                     (int)g_bbBuyArmed, (int)g_bbSellArmed, (int)g_qqeBuyArmed, (int)g_qqeSellArmed,
                                     (int)g_centreCrossReadyBuy, (int)g_centreCrossReadySell,
                                     (int)g_bbBuyArmedHtf, (int)g_bbSellArmedHtf,
                                     (int)g_qqeBuyArmedHtf, (int)g_qqeSellArmedHtf,
                                     (int)g_pendingSignal, (int)g_pendingSignalIsBuy, (int)g_pendingSignalCentreBreached,
                                     g_sessionRealizedProfit, (int)g_wasInSession,
                                     (long)g_lastEODActionDay, (long)g_lastEOWActionDay);
   FileWriteString(handle, globalLine + "\n");

   WriteSequencesToFile(handle, true);
   WriteSequencesToFile(handle, false);

   FileClose(handle);
   g_lastSaveTickMs = GetTickCount64();
  }

//+------------------------------------------------------------------+
//| PERFORMANCE FIX: calling SaveState() unconditionally on every tick |
//| does a full FileOpen()+write+FileClose() cycle every tick — a      |
//| known severe MQL5 performance anti-pattern, and the root cause of  |
//| the slowness/freezing reported after the previous change (this is  |
//| exactly where SaveState() was being called from OnTick()).         |
//|                                                                    |
//| Routine saves are now throttled to roughly once every 2 real       |
//| seconds using GetTickCount64() (wall-clock time, unaffected by     |
//| Strategy Tester's simulated time). Anything that actually needs to |
//| survive a crash without delay calls SaveState() directly instead — |
//| see the forced calls after a trade opens, a sequence closes, and a |
//| partial close executes.                                            |
//+------------------------------------------------------------------+
#define STATE_SAVE_THROTTLE_MS 2000

void SaveStateThrottled()
  {
   if(GetTickCount64() - g_lastSaveTickMs < STATE_SAVE_THROTTLE_MS)
      return;
   SaveState();
  }

//+------------------------------------------------------------------+
//| Loads persisted state at startup. Missing file = fresh start, not  |
//| an error. After loading, every sequence is immediately re-synced   |
//| against live positions, since positions or account state may have  |
//| changed while the EA was offline (manual close, broker stop-out).  |
//|                                                                    |
//| The read loop is bounded by a sane maximum line count as a         |
//| defensive measure against a corrupted/malformed state file (e.g.   |
//| left mid-write by a crash) causing FileIsEnding() to never trip —   |
//| a real state file never remotely approaches this many lines.       |
//+------------------------------------------------------------------+
void LoadState()
  {
   if(MQLInfoInteger(MQL_TESTER)) return;   // see the guard note on SaveState() above

   int handle = FileOpen(GetStateFilePath(), FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return;   // no prior state file — fresh start

   const int MAX_STATE_LINES = 10000;
   int linesRead = 0;

   while(!FileIsEnding(handle) && linesRead < MAX_STATE_LINES)
     {
      linesRead++;
      string line = FileReadString(handle);
      if(StringLen(line) == 0) continue;

      string parts[];
      int n = StringSplit(line, '|', parts);
      if(n < 1) continue;

      if(parts[0] == "GLOBAL" && n >= 11)
        {
         g_bbBuyArmed           = (StringToInteger(parts[1])  != 0);
         g_bbSellArmed          = (StringToInteger(parts[2])  != 0);
         g_qqeBuyArmed          = (StringToInteger(parts[3])  != 0);
         g_qqeSellArmed         = (StringToInteger(parts[4])  != 0);
         g_centreCrossReadyBuy  = (StringToInteger(parts[5])  != 0);
         g_centreCrossReadySell = (StringToInteger(parts[6])  != 0);
         g_bbBuyArmedHtf        = (StringToInteger(parts[7])  != 0);
         g_bbSellArmedHtf       = (StringToInteger(parts[8])  != 0);
         g_qqeBuyArmedHtf       = (StringToInteger(parts[9])  != 0);
         g_qqeSellArmedHtf      = (StringToInteger(parts[10]) != 0);

         //--- fields added after the first release of the state format —
         //--- guarded separately so an older state file (n==11) still loads
         //--- cleanly, just without these, rather than being rejected outright
         if(n >= 18)
           {
            g_pendingSignal               = (StringToInteger(parts[11]) != 0);
            g_pendingSignalIsBuy          = (StringToInteger(parts[12]) != 0);
            g_pendingSignalCentreBreached = (StringToInteger(parts[13]) != 0);
            g_sessionRealizedProfit       = StringToDouble(parts[14]);
            g_wasInSession                = (StringToInteger(parts[15]) != 0);
            g_lastEODActionDay            = (datetime)StringToInteger(parts[16]);
            g_lastEOWActionDay            = (datetime)StringToInteger(parts[17]);
           }
        }
      else if(parts[0] == "SEQ" && n >= 13)
        {
         bool isBuy = (parts[1] == "BUY");
         Sequence s;
         s.count              = (int)StringToInteger(parts[2]);
         s.avgPrice           = StringToDouble(parts[3]);
         s.totalVolume        = StringToDouble(parts[4]);
         s.lockedBaseLot      = StringToDouble(parts[5]);
         s.recoveryModeActive = (StringToInteger(parts[6]) != 0);
         s.trailStopActive    = (StringToInteger(parts[7]) != 0);
         s.trailStopPrice     = StringToDouble(parts[8]);
         s.partialCloseDone   = (StringToInteger(parts[9]) != 0);
         s.lastEntryTime      = (datetime)StringToInteger(parts[10]);
         s.lastEntryPrice     = StringToDouble(parts[11]);

         //--- fields added after the first release of the state format —
         //--- default to a fresh ID/start-time if loading an older file
         int ticketsField = 12;
         if(n >= 15)
           {
            s.sequenceId  = (long)StringToInteger(parts[12]);
            s.startTime   = (datetime)StringToInteger(parts[13]);
            ticketsField  = 14;
            if(s.sequenceId >= g_nextSequenceId)
               g_nextSequenceId = s.sequenceId + 1;   // never reuse a loaded ID
           }
         else
           {
            s.sequenceId = g_nextSequenceId++;
            s.startTime  = TimeCurrent();
           }

         string ticketParts[];
         int tCount = (StringLen(parts[ticketsField]) > 0) ? StringSplit(parts[ticketsField], ';', ticketParts) : 0;
         ArrayResize(s.tickets, tCount);
         for(int t = 0; t < tCount; t++)
            s.tickets[t] = (ulong)StringToInteger(ticketParts[t]);

         if(isBuy)
           {
            int idx = ArraySize(g_buySequences);
            ArrayResize(g_buySequences, idx + 1);
            g_buySequences[idx] = s;
           }
         else
           {
            int idx = ArraySize(g_sellSequences);
            ArrayResize(g_sellSequences, idx + 1);
            g_sellSequences[idx] = s;
           }
        }
     }

   if(linesRead >= MAX_STATE_LINES)
      Print("EA-DCA: state file read aborted after ", MAX_STATE_LINES, " lines — the file may be corrupted. "
            "Delete it under Files > Open Data Folder > MQL5 > Files if this EA fails to initialize.");

   FileClose(handle);

   //--- re-sync every loaded sequence against live positions, and drop any
   //--- that turn out to be fully closed already. Uses the same re-check-the-
   //--- same-index pattern as CheckExitsPerBar(), since RemoveSequenceAt()
   //--- swaps the last element into the removed slot.
   for(int i = ArraySize(g_buySequences) - 1; i >= 0; i--)
     {
      SyncSequenceFromLivePositions(true, i);
      if(g_buySequences[i].count == 0)
        {
         RemoveSequenceAt(true, i);
         if(i < ArraySize(g_buySequences)) i++;
        }
     }
   for(int i = ArraySize(g_sellSequences) - 1; i >= 0; i--)
     {
      SyncSequenceFromLivePositions(false, i);
      if(g_sellSequences[i].count == 0)
        {
         RemoveSequenceAt(false, i);
         if(i < ArraySize(g_sellSequences)) i++;
        }
     }
  }

//+------------------------------------------------------------------+
//| OnInit helper: trading permissions (hard fail — the EA genuinely  |
//| cannot place trades without these, so there's nothing useful to   |
//| do by continuing).                                                |
//+------------------------------------------------------------------+
bool CheckAlgoTradingAllowed()
  {
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      Alert("EA-DCA: Algo trading is disabled for this EA. Enable it from the toolbar (Ctrl+E) "
            "or the EA's 'Common' properties tab.");
      return(false);
     }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      Alert("EA-DCA: Algo trading is disabled in the terminal. Enable 'Allow Algo Trading' under "
            "Tools > Options > Expert Advisors.");
      return(false);
     }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
     {
      Alert("EA-DCA: Trading is not allowed on this account (it may be an investor/read-only login).");
      return(false);
     }
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     {
      Alert("EA-DCA: Expert Advisor trading is disabled on this account by the broker/server.");
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| OnInit helper: hedging-account check — soft warning only.         |
//| Decision (report §13, item 7): does not block initialization.     |
//+------------------------------------------------------------------+
void CheckHedgingAccount()
  {
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Print("EA-DCA WARNING: this account is not in Hedging mode. 'Allow Buy & Sell at the Same Time' "
            "and running multiple sequences per direction will NOT behave as described in the guide — "
            "opposite-direction trades will net against each other instead of running as independent "
            "sequences. The EA will continue to run (see the project analysis report, §13 item 7).");
     }
  }

//+------------------------------------------------------------------+
//| OnInit helper: Symbol + Magic Number collision check — hard fail. |
//| Decision (report §13, item 9). Uses a terminal Global Variable as |
//| a lightweight lock keyed by Symbol+Magic, holding the owning      |
//| chart's ID. A lock is "stale" (safe to reclaim) if the chart that |
//| set it no longer exists.                                         |
//|                                                                    |
//| NOTE: Global Variables are always double-typed in MQL5, so the    |
//| chart ID (a long) is round-tripped through a double here. This is |
//| safe for realistic chart-ID magnitudes but could theoretically    |
//| lose precision at extreme values — worth hardening once the       |
//| file-based state store (report §10) exists and can hold the       |
//| chart id as an exact string instead.                               |
//+------------------------------------------------------------------+
string MagicLockName()
  {
   return(StringFormat("EA-DCA-LOCK-%s-%I64d", _Symbol, InpMagicNumber));
  }

bool CheckMagicNumberCollision()
  {
   if(MQLInfoInteger(MQL_TESTER)) return(true);   // Terminal Global Variables can persist across
                                                    // separate tester runs in the same terminal
                                                    // session — same risk category as the
                                                    // SaveState()/LoadState() fix above, and the
                                                    // whole point of this lock (detect a second
                                                    // LIVE chart using the same Magic Number) has
                                                    // no meaning inside an isolated backtest.

   string lockName = MagicLockName();
   if(GlobalVariableCheck(lockName))
     {
      long ownerChart = (long)GlobalVariableGet(lockName);
      if(ownerChart != ChartID() && ChartSymbol(ownerChart) != "")
        {
         Alert("EA-DCA: Magic Number ", InpMagicNumber, " is already in use on ", _Symbol,
               " by another chart. Each chart/symbol combination must use a unique Magic Number "
               "(see the project analysis report, §13 item 9). This instance will not initialize.");
         return(false);
        }
      //--- stale lock from a closed chart, or this chart re-initializing — safe to reclaim
     }
   GlobalVariableSet(lockName, (double)ChartID());
   return(true);
  }

void ReleaseMagicNumberLock()
  {
   if(MQLInfoInteger(MQL_TESTER)) return;

   string lockName = MagicLockName();
   if(GlobalVariableCheck(lockName) && (long)GlobalVariableGet(lockName) == ChartID())
      GlobalVariableDel(lockName);
  }

//+------------------------------------------------------------------+
//| OnInit helper: Indicator Mode / Exit Strategy / Dynamic Stop /     |
//| Partial Close compatibility gate (report §5.4). Hard fail —        |
//| an invalid combination means the EA cannot generate correct        |
//| entries or exits at all.                                           |
//+------------------------------------------------------------------+
bool ValidateExitStrategyCompatibility()
  {
   bool ok = true;

   switch(InpExitStrategy)
     {
      case EXIT_BB_CENTRE_BAND:
      case EXIT_BB_OPPOSITE_BAND:
         if(InpIndicatorMode != INDICATOR_BB_ONLY && InpIndicatorMode != INDICATOR_BOTH)
           {
            Print("EA-DCA: Exit Strategy '", EnumToString(InpExitStrategy),
                  "' requires Indicator Mode = Bollinger Bands Only or Both.");
            ok = false;
           }
         break;
      case EXIT_QQE50_RECOVERY:
         if(InpIndicatorMode != INDICATOR_QQE_ONLY && InpIndicatorMode != INDICATOR_BOTH)
           {
            Print("EA-DCA: Exit Strategy 'QQE 50 + Recovery' requires Indicator Mode = QQE Adv Only or Both.");
            ok = false;
           }
         break;
      default:
         //--- First Profitable Close, Fixed Target, Pure Trailing — valid with any Indicator Mode
         break;
     }

   bool exitSupportsAdvanced = (InpExitStrategy == EXIT_BB_CENTRE_BAND || InpExitStrategy == EXIT_QQE50_RECOVERY);

   if(InpUseDynamicStop && !exitSupportsAdvanced)
     {
      Print("EA-DCA: Dynamic Stop is only compatible with Exit Strategy = BB Centre Band or QQE 50 + Recovery.");
      ok = false;
     }
   if(InpUsePartialClose && !exitSupportsAdvanced)
     {
      Print("EA-DCA: Partial Close is only compatible with Exit Strategy = BB Centre Band or QQE 50 + Recovery.");
      ok = false;
     }
   if(InpUseDynamicStop && InpUsePartialClose)
     {
      Print("EA-DCA: Dynamic Stop and Partial Close cannot both be enabled at the same time.");
      ok = false;
     }

   return(ok);
  }

//+------------------------------------------------------------------+
//| OnInit helper: create every indicator handle the EA needs.        |
//| QMP Filter's own HigherTimeFrame input is left at PERIOD_CURRENT  |
//| (legacy/visual feature, not used — report §13 item 1). The QQE    |
//| embedded inside QMP Filter is created internally by that          |
//| indicator itself; this EA only ever opens ONE direct QQE Adv      |
//| handle (the standalone entry-zone instance).                      |
//+------------------------------------------------------------------+
bool CreateIndicatorHandles()
  {
//--- QMP Filter: entry trigger dots
   g_qmpHandle = iCustom(_Symbol, PERIOD_CURRENT, "QMP Filter",
                          PERIOD_CURRENT,                       // HigherTimeFrame — unused, see note above
                          InpQMPFast, InpQMPSlow, InpQMPSmooth, // MACD component
                          true,                                 // ZeroLag — fixed true, per guide default
                          InpQMPSF, InpQMPRSI_Period, InpQMPWP, // QQE component
                          false, false);                        // PopUp_Alert / PushNotifications off
   if(g_qmpHandle == INVALID_HANDLE)
     {
      Print("EA-DCA: failed to create the QMP Filter indicator handle. Error ", GetLastError());
      return(false);
     }

//--- Standalone QQE Adv: entry-zone breach detection
   if(InpIndicatorMode == INDICATOR_QQE_ONLY || InpIndicatorMode == INDICATOR_BOTH)
     {
      g_qqeHandle = iCustom(_Symbol, PERIOD_CURRENT, "QQE Adv",
                             InpQQESmoothingPeriod, InpQQERSIPeriod, InpQQEMultiplier);
      if(g_qqeHandle == INVALID_HANDLE)
        {
         Print("EA-DCA: failed to create the standalone QQE Adv indicator handle. Error ", GetLastError());
         return(false);
        }
     }

//--- Bollinger Bands: native iBands() — no external BB.mq5 dependency (report §13 item 5)
   if(InpIndicatorMode == INDICATOR_BB_ONLY || InpIndicatorMode == INDICATOR_BOTH)
     {
      g_bbHandle = iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, 0, InpBBDeviation, InpBBAppliedPrice);
      if(g_bbHandle == INVALID_HANDLE)
        {
         Print("EA-DCA: failed to create the native iBands() handle. Error ", GetLastError());
         return(false);
        }
     }

//--- Shared ATR handle (Fixed Target / Trailing / Signal Distance ATR options)
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if(g_atrHandle == INVALID_HANDLE)
     {
      Print("EA-DCA: failed to create the iATR() handle. Error ", GetLastError());
      return(false);
     }

//--- MA Filter (first trade only) — only needed if enabled
   if(InpUseMAFilter)
     {
      g_maHandle = iMA(_Symbol, PERIOD_CURRENT, InpMAPeriod, 0, InpMAMethod, InpMAAppliedPrice);
      if(g_maHandle == INVALID_HANDLE)
        {
         Print("EA-DCA: failed to create the iMA() handle. Error ", GetLastError());
         return(false);
        }
     }

//--- Higher Timeframe Direction Filter — only needed if enabled, and only if
//--- the chosen higher timeframe is genuinely higher than the chart's own.
   if(InpTradeInHigherTFDirection)
     {
      if((int)InpHigherTimeframe <= Period())
        {
         Print("EA-DCA: Higher Timeframe (", EnumToString(InpHigherTimeframe),
               ") must be greater than the chart timeframe. The Higher Timeframe Direction "
               "Filter will be treated as disabled.");
        }
      else
        {
         if(InpIndicatorMode == INDICATOR_BB_ONLY || InpIndicatorMode == INDICATOR_BOTH)
           {
            g_bbHtfHandle = iBands(_Symbol, InpHigherTimeframe, InpBBPeriod, 0, InpBBDeviation, InpBBAppliedPrice);
            if(g_bbHtfHandle == INVALID_HANDLE)
              {
               Print("EA-DCA: failed to create the HTF iBands() handle. Error ", GetLastError());
               return(false);
              }
           }
         if(InpIndicatorMode == INDICATOR_QQE_ONLY || InpIndicatorMode == INDICATOR_BOTH)
           {
            g_qqeHtfHandle = iCustom(_Symbol, InpHigherTimeframe, "QQE Adv",
                                      InpQQESmoothingPeriod, InpQQERSIPeriod, InpQQEMultiplier);
            if(g_qqeHtfHandle == INVALID_HANDLE)
              {
               Print("EA-DCA: failed to create the HTF QQE Adv handle. Error ", GetLastError());
               return(false);
              }
           }
        }
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| BUG FIX: explicitly resets every piece of EA state to its correct  |
//| fresh-start value. OnInit() must never rely on global variables    |
//| simply "starting fresh" — the Strategy Tester can reuse the same   |
//| loaded module across consecutive runs within one session, in      |
//| which case ALL of these globals (including the full sequence-      |
//| tracking arrays) would otherwise carry over from the END of the    |
//| previous run into the START of the next one. This was the actual  |
//| root cause of trade-count drift and, in the worst cases, runaway   |
//| losses: a leftover phantom sequence from a prior run could         |
//| coincidentally match a real position's ticket number in the new    |
//| run (backtest ticket numbering restarts low each time), corrupting |
//| that sequence's average price and exit targets from the start.     |
//|                                                                    |
//| Called unconditionally as the very first step of OnInit(), before  |
//| anything else — including before LoadState(), which (for live/demo |
//| trading, where it isn't skipped) is expected to run right after    |
//| this and correctly restore any persisted state on top of these     |
//| clean defaults.                                                     |
//+------------------------------------------------------------------+
void ResetGlobalState()
  {
   ArrayResize(g_buySequences, 0);
   ArrayResize(g_sellSequences, 0);
   g_nextSequenceId = 1;

   g_lastBarTime    = 0;
   g_lastSaveTickMs = 0;
   g_pipSize        = 0.0;   // recomputed immediately afterward in OnInit()

   g_bbBuyArmed = false; g_bbSellArmed = false; g_qqeBuyArmed = false; g_qqeSellArmed = false;

   g_centreCrossReadyBuy  = true;   // correct fresh-start value — NOT false
   g_centreCrossReadySell = true;

   g_bbBuyArmedHtf = false; g_bbSellArmedHtf = false; g_qqeBuyArmedHtf = false; g_qqeSellArmedHtf = false;
   g_lastHtfBarTime = 0;

   g_bar1High = 0; g_bar1Low = 0; g_bar1Close = 0;
   g_bbMiddle1 = 0; g_bbUpper1 = 0; g_bbLower1 = 0; g_bbSnapshotValid = false;
   g_qqeLine1 = 0;  g_qqeSnapshotValid = false;
   g_atr1 = 0;      g_atrSnapshotValid = false;

   g_tickBid = 0; g_tickAsk = 0;

   g_pendingSignal = false; g_pendingSignalIsBuy = false; g_pendingSignalCentreBreached = false;

   g_wasInSession          = false;
   g_sessionRealizedProfit = 0.0;
   g_lastEODActionDay      = 0;
   g_lastEOWActionDay      = 0;
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
  {
   ResetGlobalState();   // must run before anything else — see the note above

//--- 1) Trading permissions — hard fail, the EA cannot function without these
   if(!CheckAlgoTradingAllowed())
      return(INIT_FAILED);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   long digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      g_pipSize *= 10;   // matches QMP_Filter.mq5's own 3/5-digit-broker convention

//--- 2) Hedging account check — soft warning only (decision, report §13 item 7)
   CheckHedgingAccount();

//--- 3) Symbol + Magic Number collision check — hard fail (decision, report §13 item 9)
   if(!CheckMagicNumberCollision())
      return(INIT_FAILED);

//--- 4) Indicator Mode / Exit Strategy / feature compatibility gate (report §5.4)
   if(!ValidateExitStrategyCompatibility())
     {
      Alert("EA-DCA: invalid Exit Strategy / Indicator Mode / feature combination — see the Experts log for details.");
      return(INIT_PARAMETERS_INCORRECT);
     }

//--- 5) Indicator handles
   if(!CreateIndicatorHandles())
      return(INIT_FAILED);

//--- 6) Restore any persisted sequence/flag state from a prior run
   LoadState();

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   SaveState();

   if(g_qmpHandle    != INVALID_HANDLE) IndicatorRelease(g_qmpHandle);
   if(g_qqeHandle    != INVALID_HANDLE) IndicatorRelease(g_qqeHandle);
   if(g_bbHandle     != INVALID_HANDLE) IndicatorRelease(g_bbHandle);
   if(g_atrHandle    != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_maHandle     != INVALID_HANDLE) IndicatorRelease(g_maHandle);
   if(g_qqeHtfHandle != INVALID_HANDLE) IndicatorRelease(g_qqeHtfHandle);
   if(g_bbHtfHandle  != INVALID_HANDLE) IndicatorRelease(g_bbHtfHandle);

   ReleaseMagicNumberLock();

   ObjectsDeleteAll(0, EA_DCA_OBJ_PREFIX);   // display panel + all sequence lines (Step 7)
  }

//+------------------------------------------------------------------+
//| New-bar detection                                                  |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t != g_lastBarTime)
     {
      g_lastBarTime = t;
      return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Zone-breach detection (BB and/or QQE, per Indicator Mode).         |
//| BB uses the closed bar's actual High/Low against the band values   |
//| from that same bar (a true "touched at any point in the candle"    |
//| check). QQE has no intrabar buffer available, so its breach is     |
//| checked against the closed bar's line value directly — matching   |
//| the guide's "touch, confirmed by candle close" description.        |
//|                                                                    |
//| These latches are reset on the re-entry-after-close path in        |
//| CloseSequenceAndCleanup() when InpRequireBBBandTouchForReentry /    |
//| InpRequireQQEScenarioBForReentry are enabled, and consumed          |
//| immediately after each use when InpAllSignalsMatchEntryCriteria     |
//| is enabled (see ConsumeZoneArmedFlags()). Otherwise they stay       |
//| latched indefinitely once triggered.                                |
//+------------------------------------------------------------------+
void UpdateZoneBreachState()
  {
   if(g_bbSnapshotValid)
     {
      if(g_bar1High >= g_bbUpper1) g_bbSellArmed = true;
      if(g_bar1Low  <= g_bbLower1) g_bbBuyArmed  = true;
     }

   if(g_qqeSnapshotValid)
     {
      if(g_qqeLine1 >= InpQQEOverbought) g_qqeSellArmed = true;
      if(g_qqeLine1 <= InpQQEOversold)   g_qqeBuyArmed  = true;
     }
  }

bool IsZoneArmed(bool isBuy)
  {
   switch(InpIndicatorMode)
     {
      case INDICATOR_BB_ONLY:
         return(isBuy ? g_bbBuyArmed : g_bbSellArmed);
      case INDICATOR_QQE_ONLY:
         return(isBuy ? g_qqeBuyArmed : g_qqeSellArmed);
      case INDICATOR_BOTH:
         //--- BB drives the breach; QQE must ALSO have breached its matching
         //--- level for the signal to be gated (report §5.1). The two are
         //--- latched independently and don't need to breach on the same bar.
         return(isBuy ? (g_bbBuyArmed && g_qqeBuyArmed) : (g_bbSellArmed && g_qqeSellArmed));
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| QMP Filter dot on the just-closed bar (shift 1). QMP does not      |
//| repaint, so this is stable once read.                              |
//+------------------------------------------------------------------+
bool GetClosedBarQmpSignal(bool &isBuy)
  {
   double up[1], dn[1];
   if(CopyBuffer(g_qmpHandle, 0, 1, 1, up) <= 0) return(false);
   if(CopyBuffer(g_qmpHandle, 1, 1, 1, dn) <= 0) return(false);
   if(up[0] != EMPTY_VALUE) { isBuy = true;  return(true); }
   if(dn[0] != EMPTY_VALUE) { isBuy = false; return(true); }
   return(false);
  }

//+------------------------------------------------------------------+
//| Multiplier System — named sequences match the descriptive enum     |
//| labels added earlier. Custom parses InpFibSequence as CSV.         |
//+------------------------------------------------------------------+
void ParseCustomMultiplierString(const string csv, double &seq[])
  {
   string parts[];
   int n = StringSplit(csv, ',', parts);
   if(n <= 0)
     {
      ArrayResize(seq, 1);
      seq[0] = 1.0;
      return;
     }
   ArrayResize(seq, n);
   for(int i = 0; i < n; i++)
      seq[i] = StringToDouble(parts[i]);
  }

double GetMultiplierForTradeNumber(int tradeNumber)   // 1 = first trade in the sequence
  {
   double seq[];
   switch(InpMultiplierSystem)
     {
      case MULT_SAFE:       { double s[] = {1,1,1,2,3,5,8};  ArrayCopy(seq, s); break; }
      case MULT_LINEAR:     { double s[] = {1,2,3,4,5,6,7};  ArrayCopy(seq, s); break; }
      case MULT_FIBONACCI:  { double s[] = {1,2,3,5,8,13};   ArrayCopy(seq, s); break; }
      case MULT_AGGRESSIVE: { double s[] = {1,2,4,6,10,16};  ArrayCopy(seq, s); break; }
      case MULT_MARTINGALE: { double s[] = {1,2,4,8,16,32};  ArrayCopy(seq, s); break; }
      case MULT_CUSTOM:     ParseCustomMultiplierString(InpFibSequence, seq); break;
     }
   int size = ArraySize(seq);
   if(size == 0) return(1.0);
   int idx = tradeNumber - 1;
   if(idx >= size) idx = size - 1;   // last value repeats beyond the array length (guide's worked example)
   return(seq[idx]);
  }

//+------------------------------------------------------------------+
//| Lot sizing. Fixed and Step-Based modes match the guide's worked    |
//| examples exactly. The %Balance/%Equity modes are a flagged         |
//| placeholder — see the note accompanying this draft.                |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0.0) lotStep = 0.01;
   lot = MathRound(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   return(NormalizeDouble(lot, 2));
  }

double CalculateStepLot(double accountValue)
  {
   if(InpStepAmount <= 0.0) return(InpInitialLot);
   int steps = (int)MathFloor(accountValue / InpStepAmount);
   if(steps < 1) steps = 1;   // always at least one step, even on a smaller account
   double lot = steps * InpLotPerStep;
   if(InpMaxInitialLot > 0.0 && lot > InpMaxInitialLot)
      lot = InpMaxInitialLot;
   return(lot);
  }

//+------------------------------------------------------------------+
//| %Balance/%Equity — margin-based. Sizes the trade so its margin     |
//| requirement equals InpLotPercent% of the given account value.      |
//| Uses OrderCalcMargin() rather than a hand-rolled notional-value    |
//| formula (contract size × price) specifically because that manual   |
//| approach breaks silently on symbols whose quote currency differs   |
//| from the account's deposit currency — OrderCalcMargin() handles    |
//| that conversion, and the symbol's actual leverage/margin tier,     |
//| internally.                                                        |
//+------------------------------------------------------------------+
double CalculatePercentLot(double accountValue, bool isBuy)
  {
   ENUM_ORDER_TYPE orderType = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double marginPerLot = 0.0;

   if(price <= 0.0 || !OrderCalcMargin(orderType, _Symbol, 1.0, price, marginPerLot) || marginPerLot <= 0.0)
     {
      Print("EA-DCA: OrderCalcMargin() failed while sizing a %Balance/%Equity trade — "
            "falling back to Initial Lot Size for this trade.");
      return(InpInitialLot);
     }

   return((accountValue * InpLotPercent / 100.0) / marginPerLot);
  }

double CalculateBaseLot(bool isBuy)
  {
   switch(InpLotSizeMode)
     {
      case LOT_FIXED:
         return(NormalizeLot(InpInitialLot));

      case LOT_PERCENT_BALANCE:
         return(NormalizeLot(CalculatePercentLot(AccountInfoDouble(ACCOUNT_BALANCE), isBuy)));

      case LOT_PERCENT_EQUITY:
         return(NormalizeLot(CalculatePercentLot(AccountInfoDouble(ACCOUNT_EQUITY), isBuy)));

      case LOT_STEP_BALANCE:
         return(NormalizeLot(CalculateStepLot(AccountInfoDouble(ACCOUNT_BALANCE))));

      case LOT_STEP_EQUITY:
         return(NormalizeLot(CalculateStepLot(AccountInfoDouble(ACCOUNT_EQUITY))));
     }
   return(NormalizeLot(InpInitialLot));
  }

//+------------------------------------------------------------------+
//| The base lot (before the multiplier) is calculated ONCE, when a    |
//| sequence's first trade opens, and then locked for the rest of      |
//| that sequence — per the guide's explicit rule for %Balance/         |
//| %Equity ("these will remain constant throughout any sequence once  |
//| a sequence begins... the new account equity or balance would be    |
//| ignored"). Extended here to every Lot Sizing Mode for consistency  |
//| — the guide doesn't say this explicitly for Step-Based mode, but   |
//| leaving Step-Based unlocked while %-modes lock would be an odd     |
//| inconsistency within the same sequence. Flag if Step-Based should  |
//| behave differently.                                                 |
//+------------------------------------------------------------------+
double CalculateLotForTrade(int seqIdx, bool isBuy, int tradeNumber)
  {
   double baseLot;
   if(tradeNumber == 1)
     {
      baseLot = CalculateBaseLot(isBuy);
      if(InpMaxInitialLot > 0.0 && baseLot > InpMaxInitialLot)
         baseLot = InpMaxInitialLot;
      if(isBuy) g_buySequences[seqIdx].lockedBaseLot = baseLot;
      else      g_sellSequences[seqIdx].lockedBaseLot = baseLot;
     }
   else
     {
      baseLot = isBuy ? g_buySequences[seqIdx].lockedBaseLot : g_sellSequences[seqIdx].lockedBaseLot;
     }

   double mult = GetMultiplierForTradeNumber(tradeNumber);
   return(NormalizeLot(baseLot * mult));
  }

//+------------------------------------------------------------------+
//| Sequence-level gating and lookup                                   |
//+------------------------------------------------------------------+
bool DirectionIsAllowed(bool isBuy)
  {
   if(InpTradeDirection == DIRECTION_BUY_ONLY  && !isBuy) return(false);
   if(InpTradeDirection == DIRECTION_SELL_ONLY &&  isBuy) return(false);
   return(true);
  }

bool SpreadIsAcceptable()
  {
   long spreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return(spreadPoints <= InpMaxSpread);
  }

bool OppositeDirectionBlocks(bool isBuy)
  {
   if(InpAllowBuySellAtSameTime) return(false);
   int oppositeCount = isBuy ? ArraySize(g_sellSequences) : ArraySize(g_buySequences);
   return(oppositeCount > 0);
  }

//+====================================================================+
//| TRADING SESSION / SESSION PROFIT LIMIT (Step 5)                    |
//| Needed by TryEnterSequence() below, so placed ahead of it. The EOD/ |
//| EOW action functions live later instead, since they depend on      |
//| GetSequenceFloatingProfit()/CloseSequenceAndCleanup() from the      |
//| exit-logic section further down the file.                          |
//+====================================================================+

int TimeStringToMinutes(const string hhmm)
  {
   string parts[];
   if(StringSplit(hhmm, ':', parts) != 2) return(0);
   return((int)StringToInteger(parts[0]) * 60 + (int)StringToInteger(parts[1]));
  }

//+------------------------------------------------------------------+
//| Enable Trading Hours gate. Broker/Local/GMT+Offset reference per   |
//| InpTimeReference, day-of-week toggles, and a start/end window that |
//| correctly handles wrapping past midnight (e.g. 22:00-06:00).       |
//+------------------------------------------------------------------+
bool IsWithinTradingSession()
  {
   if(!InpUseTimeFilter) return(true);

   datetime now;
   if(InpTimeReference == TIME_LOCAL)          now = TimeLocal();
   else if(InpTimeReference == TIME_GMT_OFFSET) now = TimeGMT() + InpGMTOffset * 3600;
   else                                         now = TimeCurrent();   // TIME_BROKER

   MqlDateTime dt;
   TimeToStruct(now, dt);

   bool dayOk;
   switch(dt.day_of_week)
     {
      case 0: dayOk = InpTradeSunday;    break;
      case 1: dayOk = InpTradeMonday;    break;
      case 2: dayOk = InpTradeTuesday;   break;
      case 3: dayOk = InpTradeWednesday; break;
      case 4: dayOk = InpTradeThursday;  break;
      case 5: dayOk = InpTradeFriday;    break;
      default: dayOk = InpTradeSaturday; break;   // case 6
     }
   if(!dayOk) return(false);

   int nowMinutes   = dt.hour * 60 + dt.min;
   int startMinutes = TimeStringToMinutes(InpTradingStartTime);
   int endMinutes   = TimeStringToMinutes(InpTradingEndTime);

   if(startMinutes <= endMinutes)
      return(nowMinutes >= startMinutes && nowMinutes < endMinutes);
   return(nowMinutes >= startMinutes || nowMinutes < endMinutes);   // overnight session
  }

//+------------------------------------------------------------------+
//| Session Profit Limit — an independent "stop opening new trades"    |
//| gate, tracked as REALIZED profit accumulated since the current     |
//| trading-session window began (reset the moment a new session       |
//| starts). Uses the same Trading Session Times window regardless of  |
//| whether InpUseTimeFilter itself is on, per the guide: "You can     |
//| leave the Enable Trading Hours Filter as 'false' but you would     |
//| have to populate the Trading Start & End times at least."          |
//+------------------------------------------------------------------+
bool IsWithinTradingSessionForProfitLimit()
  {
   datetime now;
   if(InpTimeReference == TIME_LOCAL)          now = TimeLocal();
   else if(InpTimeReference == TIME_GMT_OFFSET) now = TimeGMT() + InpGMTOffset * 3600;
   else                                         now = TimeCurrent();
   MqlDateTime dt; TimeToStruct(now, dt);
   int nowMinutes   = dt.hour * 60 + dt.min;
   int startMinutes = TimeStringToMinutes(InpTradingStartTime);
   int endMinutes   = TimeStringToMinutes(InpTradingEndTime);
   if(startMinutes <= endMinutes)
      return(nowMinutes >= startMinutes && nowMinutes < endMinutes);
   return(nowMinutes >= startMinutes || nowMinutes < endMinutes);
  }

void UpdateSessionProfitTracking()
  {
   if(InpStopAfterProfitPerSession <= 0.0) return;   // feature off — nothing to track
   bool inSession = IsWithinTradingSessionForProfitLimit();
   if(inSession && !g_wasInSession)
      g_sessionRealizedProfit = 0.0;   // a fresh session window just started
   g_wasInSession = inSession;
  }

bool SessionProfitLimitReached()
  {
   if(InpStopAfterProfitPerSession <= 0.0) return(false);
   return(g_sessionRealizedProfit >= InpStopAfterProfitPerSession);
  }

//+====================================================================+
//| ENTRY-SIDE FILTERS (Step 5)                                        |
//| Two categories, applied at different points in TryEnterSequence(): |
//|  - "New sequence only" gates: only checked when genuinely starting |
//|    a brand-new sequence, never for add-on trades or Recovery Mode  |
//|    entries (which explicitly bypass normal gating by design).      |
//|  - "Add-on only" gates: only checked when adding to an already-    |
//|    open sequence.                                                   |
//+====================================================================+

//+------------------------------------------------------------------+
//| BB Width Filter — new-sequence gate only. Width is expressed as a  |
//| percentage of the middle band's price level. The guide gives no    |
//| exact formula ("hard to eyeball what this number should be...      |
//| trial & error"), so this is my best-effort, standard, scale-       |
//| invariant interpretation — flag if a different formula is wanted.  |
//| Unlike the %Balance/%Equity lot formula, getting this slightly     |
//| off only changes filter selectivity, not position sizing, so it    |
//| wasn't treated as a blocking question.                             |
//+------------------------------------------------------------------+
bool BBWidthFilterPasses()
  {
   if(!InpUseBBWidthFilter) return(true);
   if(!g_bbSnapshotValid) return(true);
   if(g_bbMiddle1 <= 0.0) return(true);
   double widthPercent = (g_bbUpper1 - g_bbLower1) / g_bbMiddle1 * 100.0;
   return(widthPercent >= InpBBMinWidthPercent);
  }

//+------------------------------------------------------------------+
//| Require Centre Band Cross Before New Sequence — new-sequence gate  |
//| only. Tracks, per direction, whether price has closed on the "far" |
//| side of the centre band (above it for a future buy, below it for a |
//| future sell) since the flag was last consumed by a new sequence    |
//| actually starting.                                                  |
//+------------------------------------------------------------------+
void UpdateCentreCrossState()
  {
   if(!g_bbSnapshotValid) return;
   if(g_bar1Close > g_bbMiddle1) g_centreCrossReadyBuy  = true;
   if(g_bar1Close < g_bbMiddle1) g_centreCrossReadySell = true;
  }

bool CentreBandCrossGatePasses(bool isBuy)
  {
   if(!InpRequireCenterBandCross) return(true);
   if(g_bbHandle == INVALID_HANDLE) return(true);   // not applicable in QQE-only mode
   return(isBuy ? g_centreCrossReadyBuy : g_centreCrossReadySell);
  }

void ConsumeCentreBandCrossFlag(bool isBuy)
  {
   if(isBuy) g_centreCrossReadyBuy  = false;
   else      g_centreCrossReadySell = false;
  }

//+------------------------------------------------------------------+
//| Don't Open 1st Trades on Centre Band Breach — new-sequence gate     |
//| only. Rejects a brand-new sequence's first trade if the QMP-dot    |
//| bar had already breached back through the centre band the "wrong"  |
//| way (guide: a lower % of winning sequences when this happens).     |
//|                                                                    |
//| Uses g_pendingSignalCentreBreached — captured on the SIGNAL bar     |
//| itself when the dot was first recorded, not recomputed from        |
//| whatever bar happens to be current now. This matters once a QMP    |
//| dot persists waiting for the zone to arm (see g_pendingSignal):     |
//| by the time the zone finally arms, the "current" bar could be many |
//| candles past the actual signal candle the guide is describing.     |
//+------------------------------------------------------------------+
bool NoTriggerOnCentreBandBreachPasses()
  {
   if(!InpNoTriggerOnCentralBandBreach) return(true);
   return(!g_pendingSignalCentreBreached);
  }

//+------------------------------------------------------------------+
//| MA Filter — new-sequence gate only ("first trade only" per the     |
//| guide).                                                             |
//+------------------------------------------------------------------+
bool MAFilterPasses(bool isBuy)
  {
   if(!InpUseMAFilter) return(true);
   if(g_maHandle == INVALID_HANDLE) return(true);
   double ma[1];
   if(CopyBuffer(g_maHandle, 0, 1, 1, ma) <= 0) return(true);

   if(InpMAFilterBehaviour == MA_BUY_ABOVE_SELL_BELOW)
      return(isBuy ? (g_bar1Close > ma[0]) : (g_bar1Close < ma[0]));
   return(isBuy ? (g_bar1Close < ma[0]) : (g_bar1Close > ma[0]));   // MA_BUY_BELOW_SELL_ABOVE
  }

//+------------------------------------------------------------------+
//| Minimum Signal Distance Filter — add-on gate only, measured        |
//| against the sequence's most recently registered entry price.       |
//| Applied uniformly, including to Recovery Mode adds: the guide      |
//| frames Recovery Mode as bypassing the BB/QQE *zone* check           |
//| specifically ("no matter where the QQE level is at"), not every    |
//| other independent risk control, so this filter still applies.      |
//+------------------------------------------------------------------+
bool MinimumSignalDistancePasses(bool isBuy, int seqIdx)
  {
   if(!InpUseMinimumSignalDistance) return(true);

   double minDistance;
   if(InpUseATRForMinDistance)
     {
      if(!g_atrSnapshotValid) return(true);
      minDistance = g_atr1 * InpMinDistanceATRMultiplier;
     }
   else
      minDistance = PipsToPrice(InpMinDistancePips);

   double lastPrice    = isBuy ? g_buySequences[seqIdx].lastEntryPrice : g_sellSequences[seqIdx].lastEntryPrice;
   double currentPrice = isBuy ? g_tickAsk : g_tickBid;
   return(MathAbs(currentPrice - lastPrice) >= minDistance);
  }

//+------------------------------------------------------------------+
//| Higher Timeframe Direction Filter — new-sequence gate only. Mirrors|
//| the current-timeframe zone-armed latch pattern, but reads the      |
//| HTF's own closed bars: "the Daily chart would have to be           |
//| displaying the same signal before any trades are taken."           |
//+------------------------------------------------------------------+
void UpdateHtfZoneBreachState()
  {
   if(!InpTradeInHigherTFDirection) return;
   datetime htfBarTime = iTime(_Symbol, InpHigherTimeframe, 0);
   if(htfBarTime == g_lastHtfBarTime) return;   // no new HTF bar yet
   g_lastHtfBarTime = htfBarTime;

   if(g_bbHtfHandle != INVALID_HANDLE)
     {
      double upperBand[1], lowerBand[1];
      if(CopyBuffer(g_bbHtfHandle, 1, 1, 1, upperBand) > 0 && CopyBuffer(g_bbHtfHandle, 2, 1, 1, lowerBand) > 0)
        {
         if(iHigh(_Symbol, InpHigherTimeframe, 1) >= upperBand[0]) g_bbSellArmedHtf = true;
         if(iLow(_Symbol,  InpHigherTimeframe, 1) <= lowerBand[0]) g_bbBuyArmedHtf  = true;
        }
     }
   if(g_qqeHtfHandle != INVALID_HANDLE)
     {
      double qqeLine[1];
      if(CopyBuffer(g_qqeHtfHandle, 0, 1, 1, qqeLine) > 0)
        {
         if(qqeLine[0] >= InpQQEOverbought) g_qqeSellArmedHtf = true;
         if(qqeLine[0] <= InpQQEOversold)   g_qqeBuyArmedHtf  = true;
        }
     }
  }

bool IsHtfDirectionAligned(bool isBuy)
  {
   if(!InpTradeInHigherTFDirection) return(true);
   switch(InpIndicatorMode)
     {
      case INDICATOR_BB_ONLY:  return(isBuy ? g_bbBuyArmedHtf  : g_bbSellArmedHtf);
      case INDICATOR_QQE_ONLY: return(isBuy ? g_qqeBuyArmedHtf : g_qqeSellArmedHtf);
      case INDICATOR_BOTH:     return(isBuy ? (g_bbBuyArmedHtf && g_qqeBuyArmedHtf)
                                             : (g_bbSellArmedHtf && g_qqeSellArmedHtf));
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| All Signals Must Match Entry Criteria — consumes the zone-armed    |
//| latches immediately after use (rather than leaving them sticky),   |
//| so the NEXT add-on trade needs a fresh breach. Never applied to    |
//| Recovery Mode entries, which explicitly bypass zone gating by      |
//| design — demanding a "fresh" breach there would contradict the     |
//| whole point of Recovery Mode.                                      |
//+------------------------------------------------------------------+
void ConsumeZoneArmedFlags(bool isBuy)
  {
   if(isBuy) { g_bbBuyArmed = false;  g_qqeBuyArmed = false; }
   else      { g_bbSellArmed = false; g_qqeSellArmed = false; }
  }

int FindOpenSequenceWithRoom(bool isBuy)
  {
   int total = isBuy ? ArraySize(g_buySequences) : ArraySize(g_sellSequences);
   for(int i = total - 1; i >= 0; i--)   // most recently opened first
     {
      bool done = isBuy ? g_buySequences[i].partialCloseDone : g_sellSequences[i].partialCloseDone;
      if(done) continue;   // wound down to a managed remnant — no more DCA adds
      int cnt = isBuy ? g_buySequences[i].count : g_sellSequences[i].count;
      if(InpMaxTradesPerSequence == 0 || cnt < InpMaxTradesPerSequence)
         return(i);
     }
   return(-1);
  }

//+------------------------------------------------------------------+
//| A sequence in Recovery Mode (its BB/QQE exit condition fired but   |
//| it wasn't yet profitable) accepts ANY new same-direction QMP dot   |
//| regardless of zone-breach state — the guide: "taking every QMP dot |
//| in that same direction to get to that overall break even plus     |
//| buffer level as soon as possible... no matter where the QQE level  |
//| is at." Checked ahead of the normal zone-gated path in             |
//| TryEnterSequence().                                                 |
//|                                                                    |
//| Simplifying assumption: if multiple sequences are open in the same |
//| direction and one is recovering, ALL new signals route to it first |
//| — ahead of any other open, non-recovering sequence. This could in  |
//| theory starve a separate healthy sequence of a legitimate add in   |
//| the rare case both exist at once; flag if per-sequence targeting   |
//| is wanted instead.                                                  |
//+------------------------------------------------------------------+
int FindRecoveryModeSequence(bool isBuy)
  {
   int total = isBuy ? ArraySize(g_buySequences) : ArraySize(g_sellSequences);
   for(int i = 0; i < total; i++)
     {
      bool recovering = isBuy ? g_buySequences[i].recoveryModeActive : g_sellSequences[i].recoveryModeActive;
      if(!recovering) continue;
      int cnt = isBuy ? g_buySequences[i].count : g_sellSequences[i].count;
      if(InpMaxTradesPerSequence == 0 || cnt < InpMaxTradesPerSequence)
         return(i);
     }
   return(-1);
  }

int CreateNewSequence(bool isBuy)
  {
   int total = isBuy ? ArraySize(g_buySequences) : ArraySize(g_sellSequences);
   //--- guide: "if this feature is activated, then there will only be one
   //--- sequence per direction at any one time" — overrides the configured
   //--- Max Sequences Per Direction regardless of its actual value.
   int cap = InpAllSignalsMatchEntryCriteria ? 1 : InpMaxSequencesPerDirection;
   if(total >= cap)
      return(-1);
   long newId = g_nextSequenceId++;
   if(isBuy)
     {
      ArrayResize(g_buySequences, total + 1);
      g_buySequences[total].sequenceId = newId;
      g_buySequences[total].startTime  = TimeCurrent();
      return(total);
     }
   ArrayResize(g_sellSequences, total + 1);
   g_sellSequences[total].sequenceId = newId;
   g_sellSequences[total].startTime  = TimeCurrent();
   return(total);
  }

//+------------------------------------------------------------------+
//| Rolls back a freshly-created, still-empty sequence slot when its   |
//| opening trade fails to fill — otherwise a rejected order would     |
//| permanently occupy one of the InpMaxSequencesPerDirection slots.   |
//| Only ever called immediately after CreateNewSequence(), so seqIdx  |
//| is always the last element — safe to just shrink the array.        |
//+------------------------------------------------------------------+
void RemoveEmptySequenceSlot(bool isBuy, int seqIdx)
  {
   int total = isBuy ? ArraySize(g_buySequences) : ArraySize(g_sellSequences);
   if(seqIdx == total - 1)
     {
      if(isBuy) ArrayResize(g_buySequences, total - 1);
      else      ArrayResize(g_sellSequences, total - 1);
     }
  }

//+------------------------------------------------------------------+
//| Locate the position ticket for the trade we just opened. Scans     |
//| live positions rather than trusting CTrade's order/deal ticket,    |
//| since that mapping isn't guaranteed identical in every account     |
//| mode.                                                              |
//|                                                                    |
//| BUG FIX — deterministic tie-breaking. POSITION_TIME has only       |
//| ONE-SECOND resolution, and this EA routinely opens several trades  |
//| within the same second (multiple DCA adds, or several sequences    |
//| triggering on the same bar). The previous `openTime >= newestTime` |
//| test resolved those ties by whichever position happened to come    |
//| later in PositionsTotal() enumeration order — an order MQL5 does   |
//| NOT guarantee, particularly after positions have been added and    |
//| removed. A wrong pick here silently binds a new trade to the wrong |
//| ticket, corrupting that sequence's avgPrice and exit target.       |
//|                                                                    |
//| Ticket numbers are strictly increasing, so the highest ticket is   |
//| unambiguously the newest position — deterministic regardless of    |
//| enumeration order. POSITION_TIME_MSC (millisecond precision) is    |
//| used as the primary key, with the ticket breaking any remaining    |
//| tie.                                                                |
//+------------------------------------------------------------------+
ulong GetLastOpenedPositionTicket(bool isBuy)
  {
   ulong newest      = 0;
   long  newestMsc   = -1;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(isBuy  && ptype != POSITION_TYPE_BUY)  continue;
      if(!isBuy && ptype != POSITION_TYPE_SELL) continue;

      long openMsc = (long)PositionGetInteger(POSITION_TIME_MSC);
      if(openMsc > newestMsc || (openMsc == newestMsc && ticket > newest))
        {
         newestMsc = openMsc;
         newest    = ticket;
        }
     }
   return(newest);
  }

void RegisterFilledTrade(int seqIdx, bool isBuy, ulong ticket, double volume, double price)
  {
//--- Mutates the array element's fields directly rather than copying the
//--- struct in and out of a local variable, to avoid any ambiguity around
//--- how struct assignment handles a nested dynamic array (tickets[]) —
//--- correctness here matters more than brevity, since this is the only
//--- record of what's actually open.
   if(isBuy)
     {
      int n = g_buySequences[seqIdx].count;
      ArrayResize(g_buySequences[seqIdx].tickets, n + 1);
      g_buySequences[seqIdx].tickets[n] = ticket;
      double newTotalVolume = g_buySequences[seqIdx].totalVolume + volume;
      g_buySequences[seqIdx].avgPrice = (g_buySequences[seqIdx].avgPrice * g_buySequences[seqIdx].totalVolume
                                          + price * volume) / newTotalVolume;
      g_buySequences[seqIdx].totalVolume    = newTotalVolume;
      g_buySequences[seqIdx].count          = n + 1;
      g_buySequences[seqIdx].lastEntryTime  = TimeCurrent();
      g_buySequences[seqIdx].lastEntryPrice = price;
     }
   else
     {
      int n = g_sellSequences[seqIdx].count;
      ArrayResize(g_sellSequences[seqIdx].tickets, n + 1);
      g_sellSequences[seqIdx].tickets[n] = ticket;
      double newTotalVolume = g_sellSequences[seqIdx].totalVolume + volume;
      g_sellSequences[seqIdx].avgPrice = (g_sellSequences[seqIdx].avgPrice * g_sellSequences[seqIdx].totalVolume
                                           + price * volume) / newTotalVolume;
      g_sellSequences[seqIdx].totalVolume    = newTotalVolume;
      g_sellSequences[seqIdx].count          = n + 1;
      g_sellSequences[seqIdx].lastEntryTime  = TimeCurrent();
      g_sellSequences[seqIdx].lastEntryPrice = price;
     }
  }

//+------------------------------------------------------------------+
//| Attempt to open (or add to) a sequence in the given direction.     |
//| A sequence already in Recovery Mode takes priority and bypasses    |
//| the zone-breach gate AND every new-sequence-only filter below      |
//| (BB Width, Centre Cross, No-Trigger-On-Breach, MA Filter, HTF      |
//| Direction) — it's adding to an existing sequence, not starting a   |
//| new one, and Recovery Mode explicitly overrides normal gating by   |
//| design. Minimum Signal Distance still applies (see its own doc     |
//| comment for why).                                                   |
//|                                                                    |
//| Still deferred: session/EOD/EOW gating.                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Attempts to act on a pending QMP signal. Returns TRUE if the       |
//| signal should be considered consumed (whether by a placed trade or |
//| by a decisive/structural block), or FALSE if it should stay        |
//| pending for a retry on a future bar. Only two conditions keep a    |
//| signal alive: the zone/HTF not yet being aligned (the guide's core |
//| "wait for the breach" case), and the transient Spread/Opposite-    |
//| Direction checks, which could easily clear on their own within a   |
//| bar or two. Everything else — the direction filter (permanent for  |
//| that direction), the new-sequence-only filters (evaluated against  |
//| the specific signal candle), the sequence caps, and the trade      |
//| attempt itself — consumes the signal either way.                   |
//+------------------------------------------------------------------+
bool TryEnterSequence(bool isBuy)
  {
   if(!DirectionIsAllowed(isBuy)) return(true);   // permanently disallowed for this direction — consume
   if(!IsWithinTradingSession())     return(false);   // outside hours — could still be valid once they reopen
   if(SessionProfitLimitReached())   return(false);   // resets at the next session — keep waiting

   bool viaRecovery = false;
   int  seqIdx = FindRecoveryModeSequence(isBuy);
   if(seqIdx >= 0)
      viaRecovery = true;
   else
     {
      if(!IsZoneArmed(isBuy))           return(false);  // keep waiting — the guide's core "no time limit" case
      if(!IsHtfDirectionAligned(isBuy)) return(false);   // HTF could still align on a later bar — keep waiting
      seqIdx = FindOpenSequenceWithRoom(isBuy);
     }

   //--- from here, the underlying setup has genuinely fired. Spread and
   //--- opposite-direction blocking are transient conditions unrelated to
   //--- the signal itself, so they don't consume it — but everything after
   //--- this point does, since it's evaluated specifically against this
   //--- confirmed signal.
   if(!SpreadIsAcceptable())          return(false);
   if(OppositeDirectionBlocks(isBuy)) return(false);

   bool createdNewSequence = false;
   if(seqIdx < 0)
     {
      //--- gates that ONLY apply when genuinely starting a brand-new sequence
      if(!viaRecovery)
        {
         if(!BBWidthFilterPasses())                    return(true);
         if(!CentreBandCrossGatePasses(isBuy))          return(true);
         if(!NoTriggerOnCentreBandBreachPasses())       return(true);
         if(!MAFilterPasses(isBuy))                     return(true);
        }
      seqIdx = CreateNewSequence(isBuy);
      if(seqIdx < 0) return(true);   // at the Max Sequences Per Direction cap (or the All-Signals-Match-Entry cap of 1)
      createdNewSequence = true;
     }
   else if(!viaRecovery)
     {
      //--- adding to an already-open sequence: Minimum Signal Distance filter
      if(!MinimumSignalDistancePasses(isBuy, seqIdx))
         return(true);
     }

   int tradeNumber = (isBuy ? g_buySequences[seqIdx].count : g_sellSequences[seqIdx].count) + 1;
   double lot = CalculateLotForTrade(seqIdx, isBuy, tradeNumber);

   bool ok = isBuy ? trade.Buy(lot, _Symbol, 0, 0, 0, InpUserComment)
                   : trade.Sell(lot, _Symbol, 0, 0, 0, InpUserComment);
   if(!ok)
     {
      Print("EA-DCA: order failed (", isBuy ? "Buy" : "Sell", ", lot ", DoubleToString(lot, 2),
            "). Retcode ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      if(createdNewSequence)
         RemoveEmptySequenceSlot(isBuy, seqIdx);   // don't leave a permanently-empty slot occupying the cap
      return(true);
     }

   ulong  posTicket    = GetLastOpenedPositionTicket(isBuy);
   double filledPrice  = trade.ResultPrice();
   double filledVolume = trade.ResultVolume();
   RegisterFilledTrade(seqIdx, isBuy, posTicket, filledVolume, filledPrice);

   if(!viaRecovery && InpAllSignalsMatchEntryCriteria)
      ConsumeZoneArmedFlags(isBuy);
   if(createdNewSequence && InpRequireCenterBandCross)
      ConsumeCentreBandCrossFlag(isBuy);

   SaveState();   // forced, unthrottled — a newly opened trade should be durable immediately
   return(true);
  }

//+====================================================================+
//| EXIT LOGIC                                                          |
//|                                                                    |
//| Two cadences are used deliberately:                                |
//|  - Per-BAR: BB Centre/Opposite Band, QQE 50, and First Profitable  |
//|    Close are all indicator/candle-close-based checks, matching the |
//|    guide's "confirmed by candle close" language and the same       |
//|    cadence already used for entries.                               |
//|  - Per-TICK: Fixed Target, Pure Trailing Stop, Dynamic Stop, the   |
//|    Partial Close remnant's virtual stop, and Risk Reduction are    |
//|    all live price/money-level crossings that should react          |
//|    immediately rather than waiting for a bar to close.             |
//+====================================================================+
//| NOTE: SyncSequenceFromLivePositions() and RemoveSequenceAt() now    |
//| live earlier in the file (right after PipsToPrice()), since         |
//| LoadState() needs them and is called from OnInit(). Kept the        |
//| exit-logic section's own doc comments there.                        |
//+====================================================================+

double GetSequenceFloatingProfit(bool isBuy, int seqIdx)
  {
   double total = 0.0;
   int n = isBuy ? g_buySequences[seqIdx].count : g_sellSequences[seqIdx].count;
   for(int i = 0; i < n; i++)
     {
      ulong ticket = isBuy ? g_buySequences[seqIdx].tickets[i] : g_sellSequences[seqIdx].tickets[i];
      if(PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return(total);
  }

bool CloseSequence(bool isBuy, int seqIdx)
  {
   bool allClosed = true;
   int n = isBuy ? g_buySequences[seqIdx].count : g_sellSequences[seqIdx].count;
   for(int i = 0; i < n; i++)
     {
      ulong ticket = isBuy ? g_buySequences[seqIdx].tickets[i] : g_sellSequences[seqIdx].tickets[i];
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(!trade.PositionClose(ticket))
        {
         Print("EA-DCA: failed to close position #", ticket, ". Retcode ", trade.ResultRetcode(),
               " - ", trade.ResultRetcodeDescription());
         allClosed = false;
        }
     }
   return(allClosed);
  }

//+------------------------------------------------------------------+
//| Closes a sequence and removes it from tracking once nothing is     |
//| left open. If a close attempt partially failed, the sequence stays |
//| in tracking (with whatever remains) so it's retried next check     |
//| rather than being silently lost. Once actually removed, resets the |
//| relevant zone-armed latch(es) per InpRequireBBBandTouchForReentry / |
//| InpRequireQQEScenarioBForReentry, requiring a fresh touch before    |
//| the next sequence in this direction can start, and folds the       |
//| sequence's realized profit into the Session Profit Limit tracker.  |
//+------------------------------------------------------------------+
void CloseSequenceAndCleanup(bool isBuy, int seqIdx)
  {
   double realizedProfit = GetSequenceFloatingProfit(isBuy, seqIdx);   // captured before closing realizes it
   CloseSequence(isBuy, seqIdx);
   SyncSequenceFromLivePositions(isBuy, seqIdx);
   int remaining = isBuy ? g_buySequences[seqIdx].count : g_sellSequences[seqIdx].count;
   if(remaining == 0)
     {
      RemoveSequenceAt(isBuy, seqIdx);
      g_sessionRealizedProfit += realizedProfit;
      if(InpRequireBBBandTouchForReentry)
        {
         if(isBuy) g_bbBuyArmed  = false;
         else      g_bbSellArmed = false;
        }
      if(InpRequireQQEScenarioBForReentry)
        {
         if(isBuy) g_qqeBuyArmed  = false;
         else      g_qqeSellArmed = false;
        }
     }
   SaveState();   // forced, unthrottled — a sequence closing should be durable immediately
  }

//+====================================================================+
//| END OF DAY / END OF WEEK (Step 5)                                  |
//| Placed here (after GetSequenceFloatingProfit/CloseSequenceAndCleanup |
//| above) since ApplyEndOfPeriodActionToSequence() depends on both.    |
//| The other Trading Session / Session Profit Limit functions don't    |
//| share that dependency and live earlier, ahead of TryEnterSequence() |
//| which calls them.                                                    |
//+====================================================================+

//+------------------------------------------------------------------+
//| End of Day / End of Week. Fire at most once per calendar day by    |
//| comparing against the day the action last ran, using broker/server |
//| time consistently for the "which day is it" comparison.            |
//+------------------------------------------------------------------+
void ApplyEndOfPeriodActionToSequence(bool isBuy, int seqIdx, ENUM_EOX_ACTION action)
  {
   SyncSequenceFromLivePositions(isBuy, seqIdx);
   int n = isBuy ? g_buySequences[seqIdx].count : g_sellSequences[seqIdx].count;
   if(n == 0) { RemoveSequenceAt(isBuy, seqIdx); return; }

   double profit = GetSequenceFloatingProfit(isBuy, seqIdx);
   bool shouldClose;
   switch(action)
     {
      case EOX_CLOSE_IF_PROFITABLE: shouldClose = (profit >= 0.0); break;
      case EOX_CLOSE_IF_LOSING:     shouldClose = (profit <  0.0); break;
      case EOX_CLOSE_ALL:           shouldClose = true;            break;
      default:                      shouldClose = false;           break;   // EOX_DO_NOTHING
     }
   if(shouldClose)
      CloseSequenceAndCleanup(isBuy, seqIdx);
  }

void ApplyEndOfPeriodAction(ENUM_EOX_ACTION action)
  {
   if(action == EOX_DO_NOTHING) return;
//--- same mutation-during-iteration fix as CheckExitsPerBar() — without it, an
//--- EOD/EOW close could skip a sequence that should also have been closed
   for(int i = ArraySize(g_buySequences) - 1; i >= 0; i--)
     {
      int before = ArraySize(g_buySequences);
      ApplyEndOfPeriodActionToSequence(true, i, action);
      if(ArraySize(g_buySequences) < before && i < ArraySize(g_buySequences))
         i++;
     }
   for(int i = ArraySize(g_sellSequences) - 1; i >= 0; i--)
     {
      int before = ArraySize(g_sellSequences);
      ApplyEndOfPeriodActionToSequence(false, i, action);
      if(ArraySize(g_sellSequences) < before && i < ArraySize(g_sellSequences))
         i++;
     }
  }

void CheckEndOfDayAndWeek()
  {
   if(!InpUseEOD && !InpUseEOW) return;

   datetime now = TimeCurrent();   // guide frames EOD/EOW around the broker's own daily/Friday close
   MqlDateTime dt; TimeToStruct(now, dt);
   int nowMinutes = dt.hour * 60 + dt.min;
   datetime today = now - (now % 86400);

   if(InpUseEOD && nowMinutes >= TimeStringToMinutes(InpEODTime) && g_lastEODActionDay != today)
     {
      ApplyEndOfPeriodAction(InpEODAction);
      g_lastEODActionDay = today;
     }

   if(InpUseEOW && dt.day_of_week == 5 &&   // Friday
      nowMinutes >= TimeStringToMinutes(InpEOWTime) && g_lastEOWActionDay != today)
     {
      ApplyEndOfPeriodAction(InpEOWAction);
      g_lastEOWActionDay = today;
     }
  }

//+====================================================================+
//| CHART DISPLAY (Step 7) — per-sequence lines and the info panel      |
//+====================================================================+

//+------------------------------------------------------------------+
//| Trailing stop / Breakeven / Breakeven Buffer / Risk Reduction      |
//| lines for one sequence. Each is drawn only while relevant and      |
//| deleted otherwise, so switching settings or exit strategy mid-run  |
//| cleans up correctly instead of leaving a stale line behind.        |
//+------------------------------------------------------------------+
void UpdateSequenceLines(bool isBuy, int seqIdx)
  {
   long   id       = isBuy ? g_buySequences[seqIdx].sequenceId : g_sellSequences[seqIdx].sequenceId;
   double avgPrice = isBuy ? g_buySequences[seqIdx].avgPrice   : g_sellSequences[seqIdx].avgPrice;
   bool   trailOn  = isBuy ? g_buySequences[seqIdx].trailStopActive : g_sellSequences[seqIdx].trailStopActive;
   double trailPx  = isBuy ? g_buySequences[seqIdx].trailStopPrice  : g_sellSequences[seqIdx].trailStopPrice;
   int    count    = isBuy ? g_buySequences[seqIdx].count : g_sellSequences[seqIdx].count;

   string trailName = SeqObjName("Trail", isBuy, id);
   if(InpShowTrailingStops && trailOn)
      DrawOrUpdateHLine(trailName, trailPx, isBuy ? InpBuyTrailingColor : InpSellTrailingColor,
                        InpTrailingLineStyle, InpTrailingLineWidth);
   else
      DeleteObjectIfExists(trailName);

   string beName = SeqObjName("BE", isBuy, id);
   if(InpShowBreakevenLine)
      DrawOrUpdateHLine(beName, avgPrice, InpBreakevenLineColor, STYLE_SOLID, 1);
   else
      DeleteObjectIfExists(beName);

   //--- Breakeven Buffer line — the Recovery Mode target, so only meaningful
   //--- for the three exit strategies that actually use Recovery Mode
   string bufName = SeqObjName("BEBuf", isBuy, id);
   bool recoveryEligibleStrategy = (InpExitStrategy == EXIT_BB_CENTRE_BAND || InpExitStrategy == EXIT_QQE50_RECOVERY ||
                                     (InpExitStrategy == EXIT_BB_OPPOSITE_BAND && !InpAlwaysCloseOnOppositeBand));
   if(InpShowBreakevenBufferLine && recoveryEligibleStrategy)
     {
      double bufPrice = isBuy ? avgPrice + PipsToPrice(InpBreakevenBufferPips)
                               : avgPrice - PipsToPrice(InpBreakevenBufferPips);
      DrawOrUpdateHLine(bufName, bufPrice, InpBreakevenBufferColor, STYLE_DOT, 1);
     }
   else
      DeleteObjectIfExists(bufName);

   string riskName = SeqObjName("RiskRed", isBuy, id);
   if(InpShowRiskReductionLine && InpUseRiskReduction && count >= InpRiskReductionMinTrades)
     {
      double riskPrice = isBuy ? avgPrice + PipsToPrice(InpRiskReductionBufferPips)
                                : avgPrice - PipsToPrice(InpRiskReductionBufferPips);
      DrawOrUpdateHLine(riskName, riskPrice, InpRiskReductionColor, STYLE_DOT, 1);
     }
   else
      DeleteObjectIfExists(riskName);

   //--- Sequence Start line — drawn once and left alone; RemoveSequenceAt()
   //--- draws the matching End line when the sequence closes
   if(InpShowSequenceStartEndLines)
     {
      string startName = SeqObjName("SeqStart", isBuy, id);
      if(ObjectFind(0, startName) < 0)
        {
         datetime startTime = isBuy ? g_buySequences[seqIdx].startTime : g_sellSequences[seqIdx].startTime;
         ObjectCreate(0, startName, OBJ_VLINE, 0, startTime, 0);
         ObjectSetInteger(0, startName, OBJPROP_COLOR, InpSequenceStartColor);
         ObjectSetInteger(0, startName, OBJPROP_STYLE, InpSequenceLineStyle);
         ObjectSetInteger(0, startName, OBJPROP_WIDTH, InpSequenceLineWidth);
         ObjectSetInteger(0, startName, OBJPROP_BACK, true);
         ObjectSetInteger(0, startName, OBJPROP_SELECTABLE, false);
        }
     }
  }

//+------------------------------------------------------------------+
//| Info panel — account balance/equity, floating P/L, open sequence   |
//| counts, and session-realized profit. A single background rectangle |
//| plus stacked text labels, all keyed off InpPanelX/Y and the panel  |
//| color inputs.                                                      |
//+------------------------------------------------------------------+
#define EA_DCA_PANEL_LINE_COUNT 7   // MQL5 needs a true compile-time constant for a
                                     // static array size — a local const int isn't
                                     // accepted there (this was the compiler error)
void UpdateInfoPanel()
  {
   string bgName = EA_DCA_OBJ_PREFIX + "PanelBg";
   if(!InpShowDisplayPanel)
     {
      ObjectsDeleteAll(0, EA_DCA_OBJ_PREFIX + "Panel");
      return;
     }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   double floatingProfit = 0.0;
   for(int i = 0; i < ArraySize(g_buySequences);  i++) floatingProfit += GetSequenceFloatingProfit(true,  i);
   for(int i = 0; i < ArraySize(g_sellSequences); i++) floatingProfit += GetSequenceFloatingProfit(false, i);

   string lines[EA_DCA_PANEL_LINE_COUNT];
   lines[0] = "EA-DCA-V1.0";
   lines[1] = "Balance: "        + DoubleToString(balance, 2);
   lines[2] = "Equity: "         + DoubleToString(equity, 2);
   lines[3] = "Floating P/L: "   + DoubleToString(floatingProfit, 2);
   lines[4] = "Buy Sequences: "  + (string)ArraySize(g_buySequences);
   lines[5] = "Sell Sequences: " + (string)ArraySize(g_sellSequences);
   lines[6] = "Session Profit: " + DoubleToString(g_sessionRealizedProfit, 2);

   const int LINE_HEIGHT = 16;
   if(ObjectFind(0, bgName) < 0)
     {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 170);
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, EA_DCA_PANEL_LINE_COUNT * LINE_HEIGHT + 10);
      ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
      ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
     }
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, InpPanelX - 6);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, InpPanelY - 6);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, InpPanelBgColor);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, InpPanelBorderColor);

   for(int i = 0; i < EA_DCA_PANEL_LINE_COUNT; i++)
     {
      string name = EA_DCA_OBJ_PREFIX + "PanelLine" + (string)i;
      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
         ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        }
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpPanelX);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpPanelY + i * LINE_HEIGHT);
      ObjectSetString(0, name, OBJPROP_TEXT, lines[i]);

      color clr = InpPanelInfoColor;
      if(i == 0)      clr = InpPanelHeaderColor;
      else if(i == 3) clr = (floatingProfit >= 0.0) ? InpPanelProfitColor : InpPanelLossColor;
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
     }
  }

void UpdateChartDisplay()
  {
   UpdateInfoPanel();
   for(int i = 0; i < ArraySize(g_buySequences);  i++) UpdateSequenceLines(true,  i);
   for(int i = 0; i < ArraySize(g_sellSequences); i++) UpdateSequenceLines(false, i);
  }

void SetRecoveryMode(bool isBuy, int seqIdx, bool active)
  {
   if(isBuy) g_buySequences[seqIdx].recoveryModeActive = active;
   else      g_sellSequences[seqIdx].recoveryModeActive = active;
  }

void SetTrailStop(bool isBuy, int seqIdx, bool active, double price)
  {
   if(isBuy)
     {
      g_buySequences[seqIdx].trailStopActive = active;
      g_buySequences[seqIdx].trailStopPrice  = price;
     }
   else
     {
      g_sellSequences[seqIdx].trailStopActive = active;
      g_sellSequences[seqIdx].trailStopPrice  = price;
     }
  }

//+------------------------------------------------------------------+
//| Generic trailing-stop mechanic shared by Dynamic Stop and Pure     |
//| Trailing Stop (the two are mutually exclusive at any given time,   |
//| since InpExitStrategy is a single EA-wide setting). Only ever      |
//| moves in the favorable direction, and only once price has moved at |
//| least one full "step" beyond the current stop.                     |
//+------------------------------------------------------------------+
void ActivateOrUpdateTrailingStop(bool isBuy, int seqIdx, double distancePrice, double stepPrice)
  {
   double currentPrice  = isBuy ? g_tickBid : g_tickAsk;
   double candidateStop = isBuy ? currentPrice - distancePrice : currentPrice + distancePrice;

   bool active = isBuy ? g_buySequences[seqIdx].trailStopActive : g_sellSequences[seqIdx].trailStopActive;
   if(!active)
     {
      SetTrailStop(isBuy, seqIdx, true, candidateStop);
      return;
     }

   double current = isBuy ? g_buySequences[seqIdx].trailStopPrice : g_sellSequences[seqIdx].trailStopPrice;
   bool improved = isBuy ? (candidateStop - current >= stepPrice) : (current - candidateStop >= stepPrice);
   if(improved)
      SetTrailStop(isBuy, seqIdx, true, candidateStop);
  }

bool IsTrailStopHit(bool isBuy, int seqIdx)
  {
   bool active = isBuy ? g_buySequences[seqIdx].trailStopActive : g_sellSequences[seqIdx].trailStopActive;
   if(!active) return(false);
   double stopPrice    = isBuy ? g_buySequences[seqIdx].trailStopPrice : g_sellSequences[seqIdx].trailStopPrice;
   double currentPrice = isBuy ? g_tickBid : g_tickAsk;
   return(isBuy ? (currentPrice <= stopPrice) : (currentPrice >= stopPrice));
  }

//+------------------------------------------------------------------+
//| Per-strategy exit-condition checks (per-bar strategies). Each      |
//| reads the cached per-bar snapshot (see RefreshBarSnapshot()),       |
//| matching the "confirmed by candle close" cadence already used for  |
//| entries.                                                            |
//+------------------------------------------------------------------+
bool CheckBBCentreBandExit(bool isBuy)
  {
   if(!g_bbSnapshotValid) return(false);

   if(InpBBExitOnBreach)
      //--- "breach" = touched at any point in the closed candle
      return(isBuy ? (g_bar1High >= g_bbMiddle1) : (g_bar1Low <= g_bbMiddle1));

   //--- stricter: the candle must have CLOSED on the other side of the band
   return(isBuy ? (g_bar1Close >= g_bbMiddle1) : (g_bar1Close <= g_bbMiddle1));
  }

bool CheckBBOppositeBandExit(bool isBuy)
  {
   if(!g_bbSnapshotValid) return(false);
   //--- the OPPOSITE band from where the sequence entered: upper for a buy, lower for a sell
   return(isBuy ? (g_bar1High >= g_bbUpper1) : (g_bar1Low <= g_bbLower1));
  }

bool CheckQQE50Exit(bool isBuy)
  {
   if(!g_qqeSnapshotValid) return(false);
   return(isBuy ? (g_qqeLine1 >= 50.0) : (g_qqeLine1 <= 50.0));
  }

//+------------------------------------------------------------------+
//| Fixed Target — per-tick, since it's a live price/money level.      |
//+------------------------------------------------------------------+
bool CheckFixedTargetExit(bool isBuy, int seqIdx)
  {
   switch(InpFixedTargetType)
     {
      case TARGET_CURRENCY:
         return(GetSequenceFloatingProfit(isBuy, seqIdx) >= InpProfitTargetCurrency);

      case TARGET_PIPS:
        {
         double avgPrice = isBuy ? g_buySequences[seqIdx].avgPrice : g_sellSequences[seqIdx].avgPrice;
         double target = isBuy ? avgPrice + PipsToPrice(InpProfitTargetPips)
                                : avgPrice - PipsToPrice(InpProfitTargetPips);
         double price = isBuy ? g_tickBid : g_tickAsk;
         return(isBuy ? (price >= target) : (price <= target));
        }

      case TARGET_ATR:
        {
         if(!g_atrSnapshotValid) return(false);
         double avgPrice = isBuy ? g_buySequences[seqIdx].avgPrice : g_sellSequences[seqIdx].avgPrice;
         double distance = g_atr1 * InpATRMultiplier;
         double target = isBuy ? avgPrice + distance : avgPrice - distance;
         double price = isBuy ? g_tickBid : g_tickAsk;
         return(isBuy ? (price >= target) : (price <= target));
        }
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Dynamic Stop. Activation is decided by HandleProfitGatedExit()     |
//| (called from the per-bar BB Centre/QQE50 checks); this function    |
//| only maintains an already-active stop and handles deactivation.    |
//|                                                                    |
//| Deliberately does NOT pause new entries while active — the guide   |
//| says nothing either way for Dynamic Stop specifically, but is      |
//| explicit that the structurally similar Pure Trailing Stop keeps    |
//| taking new signals while trailing ("the EA will continue to take   |
//| new trade signals until the sequence is closed out"), and the      |
//| trailing math here is anchored to current price, not avgPrice, so  |
//| new adds don't corrupt it. Flag if Dynamic Stop should pause       |
//| entries instead.                                                    |
//+------------------------------------------------------------------+
double GetDynamicStopDistance()
  {
   return(PipsToPrice(InpDynamicStopDistancePips));
  }

void HandleDynamicStop(bool isBuy, int seqIdx)
  {
   bool active = isBuy ? g_buySequences[seqIdx].trailStopActive : g_sellSequences[seqIdx].trailStopActive;
   if(!active) return;

   double profit = GetSequenceFloatingProfit(isBuy, seqIdx);
   if(profit <= 0.0)
     {
      //--- deactivates on loss — guide: "the sequence can continue adding trades"
      SetTrailStop(isBuy, seqIdx, false, 0.0);
      return;
     }

   ActivateOrUpdateTrailingStop(isBuy, seqIdx, GetDynamicStopDistance(), 0.0);   // no step-block input exists for Dynamic Stop
  }

//+------------------------------------------------------------------+
//| Pure Trailing Stop — activation via pips, $, or ATR (whichever     |
//| nominated method triggers first), then trails at a fixed distance  |
//| (pips or ATR) with InpTrailingStepBlockPips granularity. Explicitly |
//| does not pause new entries, per the guide.                         |
//+------------------------------------------------------------------+
void HandlePureTrailingStop(bool isBuy, int seqIdx)
  {
   bool active = isBuy ? g_buySequences[seqIdx].trailStopActive : g_sellSequences[seqIdx].trailStopActive;

   if(!active)
     {
      double avgPrice = isBuy ? g_buySequences[seqIdx].avgPrice : g_sellSequences[seqIdx].avgPrice;
      double price    = isBuy ? g_tickBid : g_tickAsk;
      double profit   = GetSequenceFloatingProfit(isBuy, seqIdx);

      bool startByPips = false;
      if(InpUseATRForTrailingStart)
        {
         if(g_atrSnapshotValid)
           {
            double distance = g_atr1 * InpTrailingStartATRMultiplier;
            startByPips = isBuy ? (price - avgPrice >= distance) : (avgPrice - price >= distance);
           }
        }
      else if(InpTrailingStartPips > 0)
        {
         double distance = PipsToPrice(InpTrailingStartPips);
         startByPips = isBuy ? (price - avgPrice >= distance) : (avgPrice - price >= distance);
        }

      bool startByDollars = (InpTrailingStartDollars > 0.0 && profit >= InpTrailingStartDollars);

      if(!(startByPips || startByDollars))
         return;   // not yet time to start trailing
     }

   double distancePrice;
   if(InpUseATRForTrailingDistance)
     {
      if(!g_atrSnapshotValid) return;
      distancePrice = g_atr1 * InpTrailingDistanceATRMultiplier;
     }
   else
      distancePrice = PipsToPrice(InpTrailingStepPips);

   ActivateOrUpdateTrailingStop(isBuy, seqIdx, distancePrice, PipsToPrice(InpTrailingStepBlockPips));
  }

//+------------------------------------------------------------------+
//| Partial Close. Fires instead of a full close when the underlying   |
//| BB Centre Band / QQE 50 + Recovery condition is met in profit.     |
//| Closes all but the most-recently-opened trade (per the guide's     |
//| worked example: "4x trades... close 3x trades and leave the        |
//| remaining 4th trade intact"), then optionally halves that          |
//| remaining trade, and attaches a virtual breakeven (+ optional      |
//| trailing) stop. From this point the sequence takes no further DCA  |
//| adds (see FindOpenSequenceWithRoom()) — it's treated as wound down |
//| to a single managed remnant, per the guide's framing ("It treats   |
//| it as the 'remaining' position").                                  |
//+------------------------------------------------------------------+
void ExecutePartialClose(bool isBuy, int seqIdx)
  {
   int n = isBuy ? g_buySequences[seqIdx].count : g_sellSequences[seqIdx].count;
   bool wasMultiTrade = (n >= 2);   // guide: a lone remaining trade is never closed or reduced —
                                     // only ">=2 trades" sequences get the close-all-but-last + optional-halve treatment

   if(wasMultiTrade)
     {
      for(int i = 0; i < n - 1; i++)
        {
         ulong ticket = isBuy ? g_buySequences[seqIdx].tickets[i] : g_sellSequences[seqIdx].tickets[i];
         if(PositionSelectByTicket(ticket) &&
            PositionGetString(POSITION_SYMBOL) == _Symbol &&
            (long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            trade.PositionClose(ticket);
        }
     }

   SyncSequenceFromLivePositions(isBuy, seqIdx);
   n = isBuy ? g_buySequences[seqIdx].count : g_sellSequences[seqIdx].count;
   if(n == 0)
     {
      RemoveSequenceAt(isBuy, seqIdx);   // the closes above happened to take everything
      SaveState();                       // forced, unthrottled
      return;
     }

   ulong remainingTicket = isBuy ? g_buySequences[seqIdx].tickets[n-1] : g_sellSequences[seqIdx].tickets[n-1];
   if(wasMultiTrade && InpPartialClosePercent == PARTIAL_CLOSE_50 && PositionSelectByTicket(remainingTicket))
     {
      double vol     = PositionGetDouble(POSITION_VOLUME);
      double halfVol = NormalizeLot(vol / 2.0);
      double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(halfVol >= minLot && halfVol < vol)
         trade.PositionClosePartial(remainingTicket, halfVol);
     }

   SyncSequenceFromLivePositions(isBuy, seqIdx);

   double avgPrice = isBuy ? g_buySequences[seqIdx].avgPrice : g_sellSequences[seqIdx].avgPrice;
   SetTrailStop(isBuy, seqIdx, true, avgPrice);   // breakeven to start
   if(isBuy) g_buySequences[seqIdx].partialCloseDone = true;
   else      g_sellSequences[seqIdx].partialCloseDone = true;

   SaveState();   // forced, unthrottled — a partial close should be durable immediately
  }

//+------------------------------------------------------------------+
//| Ongoing per-tick monitoring for a partial-closed sequence's        |
//| remnant. Trails only if InpPartialCloseBreakevenStepPips > 0 —     |
//| otherwise stays fixed at breakeven, per the guide ("If you have    |
//| selected '0' for this field, it will be disabled, however the EA   |
//| will set the Stop at break even").                                  |
//+------------------------------------------------------------------+
void HandlePartialCloseRemnant(bool isBuy, int seqIdx)
  {
   if(InpPartialCloseBreakevenStepPips > 0.0)
      ActivateOrUpdateTrailingStop(isBuy, seqIdx, PipsToPrice(InpPartialCloseBreakevenStepPips), 0.0);

   if(IsTrailStopHit(isBuy, seqIdx))
      CloseSequenceAndCleanup(isBuy, seqIdx);
  }

//+------------------------------------------------------------------+
//| Risk Reduction — an independent override, checked regardless of    |
//| which Exit Strategy is configured, once the sequence has reached   |
//| InpRiskReductionMinTrades.                                          |
//+------------------------------------------------------------------+
bool RiskReductionTargetReached(bool isBuy, int seqIdx)
  {
   double avgPrice = isBuy ? g_buySequences[seqIdx].avgPrice : g_sellSequences[seqIdx].avgPrice;
   double target = isBuy ? avgPrice + PipsToPrice(InpRiskReductionBufferPips)
                          : avgPrice - PipsToPrice(InpRiskReductionBufferPips);
   double price = isBuy ? g_tickBid : g_tickAsk;
   return(isBuy ? (price >= target) : (price <= target));
  }

//+------------------------------------------------------------------+
//| Recovery Mode's own per-tick target check (BB Centre / BB Opposite |
//| non-forced / QQE 50 + Recovery only).                              |
//+------------------------------------------------------------------+
bool RecoveryTargetReached(bool isBuy, int seqIdx)
  {
   double avgPrice = isBuy ? g_buySequences[seqIdx].avgPrice : g_sellSequences[seqIdx].avgPrice;
   double target = isBuy ? avgPrice + PipsToPrice(InpBreakevenBufferPips)
                          : avgPrice - PipsToPrice(InpBreakevenBufferPips);
   double price = isBuy ? g_tickBid : g_tickAsk;
   return(isBuy ? (price >= target) : (price <= target));
  }

//+------------------------------------------------------------------+
//| Dispatches a met-but-not-yet-closed exit condition: if the         |
//| sequence is in profit, close it (or hand off to Dynamic Stop /     |
//| Partial Close if eligible and enabled); if not, and this exit      |
//| strategy supports Recovery Mode, arm it instead of closing.        |
//+------------------------------------------------------------------+
void HandleProfitGatedExit(bool isBuy, int seqIdx, bool recoveryEligible)
  {
   double profit = GetSequenceFloatingProfit(isBuy, seqIdx);
   if(profit >= 0.0)
     {
      bool advancedEligible = (InpExitStrategy == EXIT_BB_CENTRE_BAND || InpExitStrategy == EXIT_QQE50_RECOVERY);

      if(advancedEligible && InpUseDynamicStop)
        {
         double dist = GetDynamicStopDistance();
         double stopPrice = isBuy ? g_tickBid - dist : g_tickAsk + dist;
         SetTrailStop(isBuy, seqIdx, true, stopPrice);
         return;
        }
      if(advancedEligible && InpUsePartialClose)
        {
         ExecutePartialClose(isBuy, seqIdx);
         return;
        }
      CloseSequenceAndCleanup(isBuy, seqIdx);
     }
   else if(recoveryEligible)
      SetRecoveryMode(isBuy, seqIdx, true);
  }

//+------------------------------------------------------------------+
//| Per-bar exit orchestration.                                        |
//+------------------------------------------------------------------+
void CheckSequenceExitsPerBar(bool isBuy, int seqIdx)
  {
   SyncSequenceFromLivePositions(isBuy, seqIdx);
   int n = isBuy ? g_buySequences[seqIdx].count : g_sellSequences[seqIdx].count;
   if(n == 0) { RemoveSequenceAt(isBuy, seqIdx); return; }

   bool partialDone = isBuy ? g_buySequences[seqIdx].partialCloseDone : g_sellSequences[seqIdx].partialCloseDone;
   if(partialDone) return;   // fully handled per-tick now

   bool recovering = isBuy ? g_buySequences[seqIdx].recoveryModeActive : g_sellSequences[seqIdx].recoveryModeActive;
   if(recovering) return;    // waiting on the per-tick breakeven+buffer check

   switch(InpExitStrategy)
     {
      case EXIT_BB_CENTRE_BAND:
         if(CheckBBCentreBandExit(isBuy))
            HandleProfitGatedExit(isBuy, seqIdx, true);
         break;

      case EXIT_BB_OPPOSITE_BAND:
         if(CheckBBOppositeBandExit(isBuy))
           {
            if(InpAlwaysCloseOnOppositeBand)
               CloseSequenceAndCleanup(isBuy, seqIdx);   // force close regardless of profit
            else
               HandleProfitGatedExit(isBuy, seqIdx, true);
           }
         break;

      case EXIT_QQE50_RECOVERY:
         if(CheckQQE50Exit(isBuy))
            HandleProfitGatedExit(isBuy, seqIdx, true);
         break;

      case EXIT_FIRST_PROFITABLE:
         if(GetSequenceFloatingProfit(isBuy, seqIdx) >= 0.0)
            CloseSequenceAndCleanup(isBuy, seqIdx);
         break;

      default:
         break;   // Fixed Target and Pure Trailing are handled per-tick
     }
  }

//+------------------------------------------------------------------+
//| BUG FIX — array mutation during iteration.                         |
//|                                                                    |
//| RemoveSequenceAt() removes by SWAPPING THE LAST ELEMENT into the   |
//| removed slot, then shrinking. With a plain downward loop, that     |
//| silently skips a live sequence: removing index 1 of 3 moves the    |
//| element from index 2 into index 1, but the loop then decrements    |
//| past it to index 0 — so that swapped-in sequence never gets its    |
//| exit conditions evaluated on this cycle, and runs on past the bar  |
//| where it should have closed.                                       |
//|                                                                    |
//| Because whether this happens depends on WHICH sequence closes and  |
//| in what order, its effects compound differently as soon as         |
//| anything shifts — a primary source of non-deterministic results    |
//| across otherwise-identical runs.                                   |
//|                                                                    |
//| Fix: detect that the array shrank and, if so, re-examine the SAME  |
//| index, since a different live sequence now occupies it. Bounded by |
//| the shrinking array size, so it always terminates.                 |
//+------------------------------------------------------------------+
void CheckExitsPerBar()
  {
   for(int i = ArraySize(g_buySequences) - 1; i >= 0; i--)
     {
      int before = ArraySize(g_buySequences);
      CheckSequenceExitsPerBar(true, i);
      //--- array shrank AND a different element was swapped into slot i → re-check slot i
      if(ArraySize(g_buySequences) < before && i < ArraySize(g_buySequences))
         i++;
     }
   for(int i = ArraySize(g_sellSequences) - 1; i >= 0; i--)
     {
      int before = ArraySize(g_sellSequences);
      CheckSequenceExitsPerBar(false, i);
      if(ArraySize(g_sellSequences) < before && i < ArraySize(g_sellSequences))
         i++;
     }
  }

//+------------------------------------------------------------------+
//| Per-tick exit orchestration.                                       |
//+------------------------------------------------------------------+
void CheckSequenceExitsPerTick(bool isBuy, int seqIdx)
  {
   SyncSequenceFromLivePositions(isBuy, seqIdx);
   int n = isBuy ? g_buySequences[seqIdx].count : g_sellSequences[seqIdx].count;
   if(n == 0) { RemoveSequenceAt(isBuy, seqIdx); return; }

   bool partialDone = isBuy ? g_buySequences[seqIdx].partialCloseDone : g_sellSequences[seqIdx].partialCloseDone;
   if(partialDone)
     {
      HandlePartialCloseRemnant(isBuy, seqIdx);
      return;
     }

   if(InpUseDynamicStop && (InpExitStrategy == EXIT_BB_CENTRE_BAND || InpExitStrategy == EXIT_QQE50_RECOVERY))
      HandleDynamicStop(isBuy, seqIdx);

   bool trailActive = isBuy ? g_buySequences[seqIdx].trailStopActive : g_sellSequences[seqIdx].trailStopActive;
   if(trailActive && IsTrailStopHit(isBuy, seqIdx))
     {
      CloseSequenceAndCleanup(isBuy, seqIdx);
      return;
     }

   bool recovering = isBuy ? g_buySequences[seqIdx].recoveryModeActive : g_sellSequences[seqIdx].recoveryModeActive;
   if(recovering && RecoveryTargetReached(isBuy, seqIdx))
     {
      CloseSequenceAndCleanup(isBuy, seqIdx);
      return;
     }

   if(InpUseRiskReduction && n >= InpRiskReductionMinTrades && RiskReductionTargetReached(isBuy, seqIdx))
     {
      CloseSequenceAndCleanup(isBuy, seqIdx);
      return;
     }

   if(InpExitStrategy == EXIT_FIXED_TARGET && CheckFixedTargetExit(isBuy, seqIdx))
     {
      CloseSequenceAndCleanup(isBuy, seqIdx);
      return;
     }

   if(InpExitStrategy == EXIT_PURE_TRAILING)
      HandlePureTrailingStop(isBuy, seqIdx);
  }

void CheckExitsPerTick()
  {
//--- same mutation-during-iteration fix as CheckExitsPerBar() above
   for(int i = ArraySize(g_buySequences) - 1; i >= 0; i--)
     {
      int before = ArraySize(g_buySequences);
      CheckSequenceExitsPerTick(true, i);
      if(ArraySize(g_buySequences) < before && i < ArraySize(g_buySequences))
         i++;
     }
   for(int i = ArraySize(g_sellSequences) - 1; i >= 0; i--)
     {
      int before = ArraySize(g_sellSequences);
      CheckSequenceExitsPerTick(false, i);
      if(ArraySize(g_sellSequences) < before && i < ArraySize(g_sellSequences))
         i++;
     }
  }

//+------------------------------------------------------------------+
//| Runs once per new bar: refresh the cached bar snapshot, run exit   |
//| checks first (so a sequence that should close this bar does,      |
//| before any new same-bar add), refresh zone-breach/centre-cross/HTF |
//| state, then record or act on a QMP signal.                         |
//|                                                                    |
//| A dot found on the just-closed bar always becomes (or replaces)    |
//| the pending signal; it's then acted on immediately if the zone is  |
//| already armed, or left pending — with no time limit, per the       |
//| guide — until a future bar's zone-arming consumes it.              |
//+------------------------------------------------------------------+
void ProcessNewBar()
  {
   RefreshBarSnapshot();
   CheckExitsPerBar();
   UpdateZoneBreachState();
   UpdateCentreCrossState();
   UpdateHtfZoneBreachState();

   bool freshIsBuy;
   if(GetClosedBarQmpSignal(freshIsBuy))
     {
      g_pendingSignal               = true;
      g_pendingSignalIsBuy          = freshIsBuy;
      g_pendingSignalCentreBreached = g_bbSnapshotValid &&
         (freshIsBuy ? (g_bar1High >= g_bbMiddle1) : (g_bar1Low <= g_bbMiddle1));
     }

   if(g_pendingSignal && TryEnterSequence(g_pendingSignalIsBuy))
      g_pendingSignal = false;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
  {
   g_tickBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_tickAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   CheckExitsPerTick();
   UpdateSessionProfitTracking();
   CheckEndOfDayAndWeek();

   if(IsNewBar())
      ProcessNewBar();

   UpdateChartDisplay();   // cheap object-property updates, not file I/O — fine every tick
   SaveStateThrottled();
  }
//+------------------------------------------------------------------+
