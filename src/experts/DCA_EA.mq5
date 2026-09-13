//+------------------------------------------------------------------+
//|                                                       DCA_EA.mq5 |
//|                          Dollar-Cost-Averaging Expert Advisor    |
//|                                                                    |
//| Entries: QMP Filter (MACD_Platinum + QQE Adv) dots, gated by a    |
//| Bollinger Band and/or QQE zone breach. Adds to a losing position  |
//| in stages ("sequences") and manages the whole sequence to one of  |
//| six exit strategies. See DCA_EA_Analysis_Report.md for the full   |
//| spec this file is built from.                                     |
//|                                                                    |
//| Build phase 1: enums, full input block (matches default.set),     |
//| indicator handles, and OnInit() validation checks (algo-trading   |
//| permissions, hedging-account warning, magic-number collision      |
//| lock, exit-strategy/indicator-mode compatibility). Sequence        |
//| tracking, entry/exit logic, and state persistence follow in later |
//| phases.                                                            |
//+------------------------------------------------------------------+
#property copyright   "EA-DCA-V1.0"
#property version     "1.00"
#property description "Dollar-Cost-Averaging (DCA) trade management EA."
#property description "No fixed stop-loss: risk is controlled entirely by lot sizing, sequence"
#property description "caps, and the chosen exit strategy. Read the User Guide before live use."
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//| Enumerations for dropdown-style inputs.                           |
//| Native MQL5 enums are used wherever one already fits              |
//| (ENUM_APPLIED_PRICE, ENUM_MA_METHOD, ENUM_TIMEFRAMES, etc.).       |
//+------------------------------------------------------------------+
enum ENUM_MULTIPLIER_SYSTEM
  {
   MULT_SAFE = 0,          // Safe (Delayed Fib): 1,1,1,2,3,5,8
   MULT_LINEAR,            // Linear (Arithmetic): 1,2,3,4,5,6,7
   MULT_FIBONACCI,         // Classic Fibonacci: 1,2,3,5,8,13
   MULT_AGGRESSIVE,        // Aggressive (Lucas): 1,2,4,6,10,16
   MULT_MARTINGALE,        // Martingale: 1,2,4,8,16,32
   MULT_CUSTOM             // Custom (uses the Custom Multiplier String below)
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
   EXIT_FIRST_PROFITABLE,    // First Profitable Close  (Any Mode)
   EXIT_FIXED_TARGET,        // Fixed Profit Target     (Any Mode)
   EXIT_PURE_TRAILING        // Pure Trailing Stop      (Any Mode)
  };

enum ENUM_FIXED_TARGET_TYPE
  {
   TARGET_CURRENCY = 0,    // Fixed Currency Amount
   TARGET_PIPS,            // Fixed Pips From Average Entry
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
   PARTIAL_CLOSE_50   = 50  // 50% of the remaining position — value kept at 50,
                             // not 1, so default.set's InpPartialClosePercent=50
                             // still imports correctly against this enum.
  };

enum ENUM_MA_FILTER_BEHAVIOUR
  {
   MA_BUY_ABOVE_SELL_BELOW = 0,  // Buy Above MA / Sell Below MA (trend-following)
   MA_BUY_BELOW_SELL_ABOVE       // Buy Below MA / Sell Above MA (reversion to mean)
  };

//+------------------------------------------------------------------+
//| Input Parameters — order/grouping/names match default.set exactly |
//| so the shipped .set file imports cleanly against this input block.|
//+------------------------------------------------------------------+

input group "Position Sizing"
input ENUM_MULTIPLIER_SYSTEM InpMultiplierSystem      = MULT_LINEAR;      // Multiplier System
input string                 InpFibSequence           = "1,3,5,8,13";     // Custom Multiplier String (used only if System = Custom)
input double                 InpInitialLot            = 0.01;             // Initial (Base) Lot Size
input ENUM_LOT_SIZING_MODE   InpLotSizeMode           = LOT_FIXED;        // Lot Sizing Mode
input double                 InpLotPercent            = 15.0;             // % of Balance/Equity per Trade
input double                 InpStepAmount            = 1000.0;           // Step Amount (account increment)
input double                 InpLotPerStep            = 0.01;             // Lot Size per Step
input double                 InpMaxInitialLot         = 1.0;              // Max Initial Lot Size (0 = uncapped)

input group "Trading Parameters"
input long                   InpMagicNumber              = 123456;             // Magic Number (must be unique per Symbol)
input int                    InpSlippage                 = 3;                  // Slippage (points)
input int                    InpMaxSpread                = 40;                 // Max Spread (points)
input int                    InpMaxTradesPerSequence     = 0;                  // Max Trades per Sequence (0 = unlimited)
input int                    InpMaxSequencesPerDirection = 3;                  // Max Concurrent Sequences per Direction
input ENUM_TRADE_DIRECTION   InpTradeDirection           = DIRECTION_BOTH;     // Allowed Trade Direction
input bool                   InpAllowBuySellAtSameTime   = true;               // Allow Buy & Sell at the Same Time (needs a hedging account)
input string                 InpUserComment              = "DCA-EA-V21.0";     // Trade Comment

input group "Indicator Mode"
input ENUM_INDICATOR_MODE    InpIndicatorMode          = INDICATOR_BB_ONLY;  // Entry Indicator Mode

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
input double                 InpBBMinWidthPercent            = 0.5;          // BB Min Width % (of middle band price)
input bool                   InpRequireCenterBandCross       = true;         // Require Centre Band Cross Before New Sequence
input bool                   InpNoTriggerOnCentralBandBreach = true;         // Don't Open 1st Trade if Signal Candle Already Breached Centre Band
input bool                   InpRequireBBBandTouchForReentry = false;        // Require Band Touch Before Re-Entry (after a sequence closes)
input bool                   InpBBExitOnBreach               = true;         // Exit on Breach, Not Just Close (BB Centre Band Exit)
input bool                   InpAlwaysCloseOnOppositeBand    = false;        // Always Close on Opposite Band (BB Opposite Band Exit)

input group "QQE Settings"
input double                 InpQQEOverbought                 = 60.0;   // QQE Overbought Level (>= 50)
input double                 InpQQEOversold                   = 40.0;   // QQE Oversold Level (<= 50)
input int                    InpQQESmoothingPeriod            = 7;      // QQE Smoothing Factor (SF) — standalone instance
input int                    InpQQERSIPeriod                  = 14;     // QQE RSI Period — standalone instance
input int                    InpQQEMultiplier                 = 1;      // QQE Wilders Period Multiplier (WP) — standalone instance
input bool                   InpRequireQQEScenarioBForReentry = false;  // Require QQE Extreme Before Re-Entry (after a sequence closes)

input group "Exit Strategy"
input ENUM_EXIT_STRATEGY     InpExitStrategy            = EXIT_BB_CENTRE_BAND; // Exit Strategy
input bool                   InpUseDynamicStop          = false;               // Use Dynamic Stop (not compatible with Partial Close)
input double                 InpDynamicStopDistancePips = 20.0;                // Dynamic Stop Distance (pips)

input group "Recovery Mode Settings"
input double                 InpBreakevenBufferPips     = 10.0;   // Recovery Buffer Above Breakeven (pips)

input group "Exit Parameters - Fixed Target"
input ENUM_FIXED_TARGET_TYPE InpFixedTargetType         = TARGET_PIPS;   // Fixed Target Type
input double                 InpProfitTargetCurrency    = 50.0;         // Profit Target (Account Currency)
input double                 InpProfitTargetPips        = 50.0;         // Profit Target (Pips)
input int                    InpATRPeriod               = 14;           // ATR Period (also shared by Trailing & Signal Distance ATR options)
input double                 InpATRMultiplier           = 2.0;          // ATR Multiplier (Fixed Target)
input bool                   InpShowTakeProfitLine      = true;         // Show Take Profit Line (Pips/ATR modes only, per the guide)
input color                  InpTakeProfitLineColor     = (color)16748574; // Take Profit Line Colour (Dodger Blue)

input group "Exit Parameters - Trailing Stop"
input string                 TRAILING_START_INFO              = "Info only: whichever of Trailing Start (pips) or Trailing Start ($) triggers first drives the trail; the other is then ignored.";
input int                    InpTrailingStartPips             = 50;     // Trailing Start (profit in pips, 0 = disabled)
input double                 InpTrailingStartDollars          = 50.0;   // Trailing Start (profit in account currency, 0 = disabled)
input double                 InpTrailingStepPips              = 40;     // Trailing Distance (pips behind price)
input bool                   InpUseATRForTrailingStart        = false;  // Use ATR for Trailing Start
input double                 InpTrailingStartATRMultiplier    = 1.5;    // Trailing Start ATR Multiplier
input bool                   InpUseATRForTrailingDistance     = false;  // Use ATR for Trailing Distance
input double                 InpTrailingDistanceATRMultiplier = 1.0;    // Trailing Distance ATR Multiplier
input int                    InpTrailingStepBlockPips         = 1;      // Trailing Step Block (min. move before the stop re-adjusts, pips)

input group "Risk Reduction"
input bool                   InpUseRiskReduction        = false; // Enable Risk Reduction
input int                    InpRiskReductionMinTrades  = 5;     // Minimum Trades in Sequence to Activate
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
input string                     InpPartialClose_Info             = "Info only: this closes all but one trade in the sequence. Only works with Exit Strategy = BB Centre Band or QQE 50 + Recovery. Not compatible with Dynamic Stop.";
input bool                       InpUsePartialClose               = false;             // Enable Partial Close Management
input ENUM_PARTIAL_CLOSE_PERCENT InpPartialClosePercent           = PARTIAL_CLOSE_50;  // Percent to Close, Leaving the Remainder Open
input double                     InpPartialCloseBreakevenStepPips = 10.0;              // Trailing Distance for the Remaining Position (pips, 0 = breakeven only)

input group "Advanced - Signal Distance Filter"
input bool                   InpUseMinimumSignalDistance = false; // Enable Minimum Distance Between Signals
input double                 InpMinDistancePips          = 10.0;  // Minimum Distance Between Signals (pips)
input bool                   InpUseATRForMinDistance     = false; // Use ATR for Minimum Distance
input double                 InpMinDistanceATRMultiplier = 1.5;   // Minimum Distance ATR Multiplier
input string                 SIGNAL_DISTANCE_ATR_INFO    = "Info only: ATR Period is taken from the Exit Parameters - Fixed Target section (InpATRPeriod).";

input group "Advanced - Session Profit Limit"
input double                  InpStopAfterProfitPerSession = 0.0; // Stop New Sequences After Profit per Session ($, 0 = off)

input group "Advanced - Entry Options"
input string                  InpAllDCA_SignalsMatchEntry_Info = "Info only: if enabled, only one sequence per direction runs, and every add-on trade must match the same entry rules (not just a QMP dot).";
input bool                    InpAllSignalsMatchEntryCriteria  = false; // All DCA Signals Must Match Entry Criteria

input group "Advanced - Higher Timeframe Direction Filter"
input bool                    InpTradeInHigherTFDirection = false;     // Trade Only in Higher Timeframe Direction
input ENUM_TIMEFRAMES         InpHigherTimeframe          = PERIOD_H4; // Higher Timeframe (must be greater than the chart's own timeframe)

input group "Advanced - MA Filter (First Trade Only)"
input bool                    InpUseMAFilter        = false;                     // Use MA Filter
input ENUM_MA_FILTER_BEHAVIOUR InpMAFilterBehaviour = MA_BUY_ABOVE_SELL_BELOW;   // MA Filter Behaviour
input int                     InpMAPeriod           = 50;                        // MA Period
input ENUM_MA_METHOD          InpMAMethod           = MODE_EMA;                  // MA Method
input ENUM_APPLIED_PRICE      InpMAAppliedPrice     = PRICE_CLOSE;               // MA Applied Price

input group "On Screen Displays"
input bool                    InpShowTrailingStops         = false;              // Show Trailing Stop Lines
input color                   InpBuyTrailingColor          = (color)65280;      // Buy Trailing Stop Colour (Lime)
input color                   InpSellTrailingColor         = (color)255;        // Sell Trailing Stop Colour (Red)
input ENUM_LINE_STYLE         InpTrailingLineStyle         = STYLE_DASH;        // Trailing Stop Line Style
input int                     InpTrailingLineWidth         = 1;                 // Trailing Stop Line Width
input bool                    InpShowBreakevenBufferLine   = true;              // Show Breakeven Buffer Line
input color                   InpBreakevenBufferColor      = (color)42495;      // Breakeven Buffer Line Colour
input bool                    InpShowBreakevenLine         = true;              // Show Breakeven Line
input color                   InpBreakevenLineColor        = (color)65535;      // Breakeven Line Colour (Yellow)
input bool                    InpShowRiskReductionLine     = true;              // Show Risk Reduction Line
input color                   InpRiskReductionColor        = (color)16776960;   // Risk Reduction Line Colour (Aqua)
input bool                    InpShowSequenceStartEndLines = true;              // Show Sequence Start/End Lines
input color                   InpSequenceStartColor        = (color)16748574;   // Sequence Start Line Colour (Dodger Blue)
input color                   InpSequenceEndColor          = (color)16711935;   // Sequence End Line Colour (Magenta)
input ENUM_LINE_STYLE         InpSequenceLineStyle         = STYLE_DOT;         // Sequence Start/End Line Style
input int                     InpSequenceLineWidth         = 1;                 // Sequence Start/End Line Width

input group "Display Panel"
input bool                    InpShowDisplayPanel  = false;               // Show Info Panel on Chart
input int                     InpPanelX            = 12;                 // Panel X Offset (pixels)
input int                     InpPanelY            = 24;                 // Panel Y Offset (pixels)
input color                   InpPanelHeaderColor  = (color)55295;       // Panel Header Colour
input color                   InpPanelProfitColor  = (color)65280;       // Panel Profit Colour (Lime)
input color                   InpPanelLossColor    = (color)4678655;     // Panel Loss Colour (Tomato)
input color                   InpPanelInfoColor    = (color)12632256;   // Panel Info Text Colour (Silver)
input color                   InpPanelBgColor      = (color)2103830;    // Panel Background Colour
input color                   InpPanelBorderColor  = (color)5916220;    // Panel Border Colour

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

double g_pipSize = 0.0;   // price value of "1 pip" for this symbol, computed once in OnInit()

//+------------------------------------------------------------------+
//| Sequence tracking.                                                 |
//|                                                                    |
//| Design note: while a sequence remains open, every further          |
//| same-direction QMP dot adds to it as a DCA trade — this is the     |
//| core mechanic. A genuinely NEW, parallel sequence only forms once  |
//| every existing sequence in that direction is full (at              |
//| InpMaxTradesPerSequence, 0 = never full, i.e. unlimited adds).     |
//+------------------------------------------------------------------+
struct Sequence
  {
   ulong    tickets[];      // position tickets belonging to this sequence, in open order
   int      count;          // number of trades in the sequence (== ArraySize(tickets))
   double   avgPrice;       // volume-weighted average entry price across all trades
   double   totalVolume;    // sum of all trade volumes in the sequence
   datetime lastEntryTime;  // time of the most recent trade — for the Signal Distance filter
   double   lastEntryPrice; // price of the most recent trade — for the Signal Distance filter
   double   lockedBaseLot;  // pre-multiplier base lot, fixed at trade #1 and reused for the whole sequence
   long     sequenceId;     // stable identifier, for future chart-object naming (array index gets reused)
   datetime startTime;      // when trade #1 opened
   bool     recoveryModeActive; // exit condition met but not yet at breakeven+buffer (§5.7)
   bool     trailStopActive;    // shared by Dynamic Stop and the Partial-Close remainder stop (mutually exclusive by Exit Strategy/input)
   double   trailStopPrice;     // current stop level for whichever trailing mechanism is active
   bool     partialCloseDone;   // true once Partial Close has executed; also blocks further add-ons to this sequence
  };

Sequence g_buySequences[];
Sequence g_sellSequences[];
long     g_nextSequenceId = 1;

datetime g_lastBarTime = 0;

//--- Multiplier sequence for the active Multiplier System, built once in OnInit()
//--- (Custom is parsed from InpFibSequence, already validated by ValidateCustomMultiplierString()).
double g_multiplierSequence[];

//--- Zone-breach "armed" latches. Per the guide: a QMP dot that appears before the
//--- matching zone has been breached remains a valid trigger once the breach later
//--- confirms, with no time limit — so once a breach arms a latch, it stays armed
//--- until consumed by a brand-new sequence's first trade (add-on trades never
//--- consume it — see the design note above).
//---
//--- FIX (FORENSIC_COMPARISON_REPORT.md §5.3, refined in §11): a blanket
//--- "start all four pre-armed" was tried first and was wrong — it fixed the
//--- BUY side but incorrectly also pre-armed SELL, producing a spurious extra
//--- SELL sequence the reference doesn't open. These now start false, as
//--- before; InitializeZoneLatchesFromHistory() (called once from OnInit(),
//--- before LoadState()) computes each latch's real starting value from a
//--- small bounded window of actual historical bars immediately preceding
//--- the EA's first bar, instead of assuming a fixed default either way.
bool g_bbBuyArmed = false, g_bbSellArmed = false, g_qqeBuyArmed = false, g_qqeSellArmed = false;

//--- Re-entry-after-close gates (InpRequireBBBandTouchForReentry / InpRequireQQEScenarioBForReentry).
//--- Start ready so the very first sequence at EA startup isn't blocked artificially;
//--- a later build phase (exit logic) sets these false when a sequence closes, and
//--- the zone-breach detection re-arms them on a fresh qualifying touch/extreme.
bool g_reentryReadyBuy = true, g_reentryReadySell = true;

//--- Require Centre Band Cross Before New Sequence (InpRequireCenterBandCross).
//--- A STATEFUL latch, not a positional snapshot: starts ready (so the very
//--- first sequence isn't blocked), is consumed when a new sequence opens in
//--- that direction, and only re-arms once price closes on the OPPOSITE side
//--- of the centre band at least once afterward. A plain "is price currently
//--- below/above centre right now" check (tried first, see
//--- FORENSIC_COMPARISON_REPORT.md §9) is nearly always true throughout a
//--- single sustained excursion, letting new sequences open far more often
//--- than the reference does — the whole point of this gate is to require a
//--- genuine recovery-then-reversal, not just "still on the same side."
bool g_centreCrossReadyBuy = true, g_centreCrossReadySell = true;

//--- Higher Timeframe Direction Filter bias, recomputed once per new bar.
int g_htfDirection = 0;   // -1 bearish, 0 unknown/neutral (both directions blocked), +1 bullish

//--- Pending QMP signal for starting a NEW sequence — persists across bars until the
//--- zone arms. Add-on signals (into an already-open sequence) are handled immediately
//--- and never go through this pending mechanism. The signal bar's own centre-band
//--- relationship is captured at record time (not recomputed later), since
//--- NoTriggerOnCentralBandBreach needs the ORIGINAL signal candle's state, which may
//--- be many bars in the past by the time the zone finally arms.
bool g_pendingSignal = false, g_pendingSignalIsBuy = false, g_pendingSignalCentreBreached = false;

//--- Per-closed-bar indicator snapshot. BB/QQE/ATR/MA values at shift=1 don't change
//--- again once that bar closes, so they're fetched once per bar and reused by every
//--- gate function instead of each one independently calling CopyBuffer().
double g_bar1High = 0, g_bar1Low = 0, g_bar1Close = 0;
double g_bbMiddle1 = 0, g_bbUpper1 = 0, g_bbLower1 = 0; bool g_bbSnapshotValid = false;
double g_qqeLine1 = 0;                                  bool g_qqeSnapshotValid = false;
double g_atr1 = 0;                                      bool g_atrSnapshotValid = false;
double g_ma1 = 0;                                       bool g_maSnapshotValid = false;

//--- Session Profit Limit / End of Day / End of Week tracking (Phase 4).
double   g_sessionRealizedProfit = 0.0;
datetime g_sessionDate           = 0;
datetime g_lastEODActionDate     = 0;
datetime g_lastEOWActionDate     = 0;

//--- State persistence (Phase 4): wall-clock throttle for routine per-tick saves.
ulong g_lastSaveTickMs = 0;

//+------------------------------------------------------------------+
//| Pip conversion. A "pip" is defined as 10x point on a 3/5-digit    |
//| broker (fractional-pip quoting) and 1x point otherwise, matching  |
//| the convention already used by QMP_Filter.mq5's own point-        |
//| doubling logic, so every "pips" input behaves consistently with   |
//| the existing indicators.                                          |
//+------------------------------------------------------------------+
double PipsToPrice(double pips)
  {
   return(pips * g_pipSize);
  }

//+------------------------------------------------------------------+
//| OnInit helper: trading permissions — hard fail. The EA genuinely   |
//| cannot place trades without these, so there is nothing useful to   |
//| do by continuing.                                                  |
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
//| OnInit helper: hedging-account check — soft warning only.          |
//| This EA can hold multiple simultaneous same-direction and          |
//| opposite-direction positions on one symbol; a netting account      |
//| nets those into a single position instead, which changes the       |
//| EA's behavior from what the guide describes but does not make it   |
//| unsafe to run, so this does not block initialization.              |
//+------------------------------------------------------------------+
void CheckHedgingAccount()
  {
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Print("EA-DCA WARNING: this account is not in Hedging mode. 'Allow Buy & Sell at the Same Time' "
            "and running multiple sequences per direction will NOT behave as described in the guide — "
            "opposite-direction trades will net against each other instead of running as independent "
            "sequences. The EA will continue to run.");
     }
  }

//+------------------------------------------------------------------+
//| OnInit helper: Symbol + Magic Number collision check — hard fail.  |
//| A second live chart running the same Symbol+Magic combination      |
//| would silently corrupt sequence tracking once state persistence    |
//| is added, so this is treated as a data-integrity risk, not a       |
//| behavior trade-off — unlike the hedging check above.               |
//|                                                                    |
//| Implementation: a terminal Global Variable keyed by Symbol+Magic,  |
//| holding the owning chart's ID. A lock is stale (safe to reclaim)   |
//| if the chart that set it no longer exists.                        |
//+------------------------------------------------------------------+
string MagicLockName()
  {
   return(StringFormat("EA-DCA-LOCK-%s-%I64d", _Symbol, InpMagicNumber));
  }

bool CheckMagicNumberCollision()
  {
   if(MQLInfoInteger(MQL_TESTER))
      return(true);   // Terminal Global Variables can persist across separate tester
                       // runs in the same terminal session; this lock only guards
                       // against a second LIVE chart using the same Magic Number,
                       // which has no meaning inside an isolated backtest.

   string lockName = MagicLockName();
   if(GlobalVariableCheck(lockName))
     {
      long ownerChart = (long)GlobalVariableGet(lockName);
      if(ownerChart != ChartID() && ChartSymbol(ownerChart) != "")
        {
         Alert("EA-DCA: Magic Number ", InpMagicNumber, " is already in use on ", _Symbol,
               " by another chart. Each chart/symbol combination must use a unique Magic Number. "
               "This instance will not initialize.");
         return(false);
        }
      //--- stale lock from a closed chart, or this chart re-initializing — safe to reclaim
     }
   GlobalVariableSet(lockName, (double)ChartID());
   return(true);
  }

void ReleaseMagicNumberLock()
  {
   if(MQLInfoInteger(MQL_TESTER))
      return;

   string lockName = MagicLockName();
   if(GlobalVariableCheck(lockName) && (long)GlobalVariableGet(lockName) == ChartID())
      GlobalVariableDel(lockName);
  }

//+------------------------------------------------------------------+
//| OnInit helper: Indicator Mode / Exit Strategy / Dynamic Stop /     |
//| Partial Close compatibility gate — hard fail. An invalid           |
//| combination means the EA cannot generate correct entries or        |
//| exits at all (see the Exit Strategy Compatibility Matrix in the    |
//| analysis report, §5.4).                                            |
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
//| OnInit helper: Custom Multiplier String sanity check — hard fail   |
//| when enabled. The guide warns that a stray space or a trailing     |
//| comma in the string "will not work correctly"; without this        |
//| check, a bad token would silently parse to 0.0 and zero out a      |
//| trade's lot size instead of raising an error (see analysis         |
//| report §19, item 7).                                               |
//+------------------------------------------------------------------+
bool ValidateCustomMultiplierString()
  {
   if(InpMultiplierSystem != MULT_CUSTOM)
      return(true);

   string tokens[];
   int n = StringSplit(InpFibSequence, ',', tokens);
   if(n <= 0)
     {
      Print("EA-DCA: Custom Multiplier String is empty. Provide a comma-separated list such as \"1,3,5,8,13\".");
      return(false);
     }

   for(int i = 0; i < n; i++)
     {
      if(StringLen(tokens[i]) == 0 || StringFind(tokens[i], " ") >= 0)
        {
         Print("EA-DCA: Custom Multiplier String is malformed at element ", i + 1,
               " — no spaces are allowed anywhere in the string, and there must be no trailing comma.");
         return(false);
        }
      double v = StringToDouble(tokens[i]);
      if(v <= 0.0)
        {
         Print("EA-DCA: Custom Multiplier String element ", i + 1, " (\"", tokens[i],
               "\") did not parse to a positive number.");
         return(false);
        }
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| OnInit helper: create every indicator handle the EA needs.        |
//| QMP Filter's own HigherTimeFrame input is left at PERIOD_CURRENT  |
//| (a legacy/visual feature of that indicator, unrelated to this     |
//| EA's own Higher Timeframe Direction Filter, which is implemented  |
//| independently below). The QQE Adv embedded inside QMP Filter is   |
//| created internally by that indicator itself; this EA only ever    |
//| opens one direct QQE Adv handle — the standalone entry-zone        |
//| instance — plus, optionally, a second one on the higher            |
//| timeframe for the direction filter.                                |
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

//--- Bollinger Bands: native iBands() — no external BB.mq5 dependency
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
      if((int)InpHigherTimeframe <= (int)Period())
        {
         Print("EA-DCA: Higher Timeframe (", EnumToString(InpHigherTimeframe),
               ") must be strictly greater than the chart's own timeframe (", EnumToString((ENUM_TIMEFRAMES)Period()),
               "). The Higher Timeframe Direction Filter will be disabled.");
        }
      else
        {
         if(InpIndicatorMode == INDICATOR_QQE_ONLY || InpIndicatorMode == INDICATOR_BOTH)
           {
            g_qqeHtfHandle = iCustom(_Symbol, InpHigherTimeframe, "QQE Adv",
                                      InpQQESmoothingPeriod, InpQQERSIPeriod, InpQQEMultiplier);
            if(g_qqeHtfHandle == INVALID_HANDLE)
              {
               Print("EA-DCA: failed to create the HTF QQE Adv indicator handle. Error ", GetLastError());
               return(false);
              }
           }
         if(InpIndicatorMode == INDICATOR_BB_ONLY || InpIndicatorMode == INDICATOR_BOTH)
           {
            g_bbHtfHandle = iBands(_Symbol, InpHigherTimeframe, InpBBPeriod, 0, InpBBDeviation, InpBBAppliedPrice);
            if(g_bbHtfHandle == INVALID_HANDLE)
              {
               Print("EA-DCA: failed to create the HTF native iBands() handle. Error ", GetLastError());
               return(false);
              }
           }
        }
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| §5.3 fix (see FORENSIC_COMPARISON_REPORT.md §11). Computes each    |
//| zone-armed latch's real starting value from actual historical bars |
//| immediately preceding the EA's first bar, instead of assuming a    |
//| fixed true/false default either way (the same "no time limit"      |
//| carry-forward rule already confirmed correct for in-test breaches, |
//| applied retroactively to the small window right before startup).   |
//|                                                                     |
//| ASSUMPTION (evidence-based, but the exact window size is inferred  |
//| beyond the one confirmed data point): the reference's own first    |
//| BUY entry is explained by a breach exactly 2 bars before its first  |
//| live bar; its first SELL entry shows no equivalent pre-arming, so   |
//| whatever sell-side breach existed earlier must lie outside whatever |
//| window it uses. A 10-bar lookback is used here as a clearly-        |
//| flagged, generous-but-bounded margin — not a reverse-engineered     |
//| exact constant. Only meaningful for a genuinely fresh start (Strategy|
//| Tester always, or a live chart's very first run) — LoadState(),     |
//| called right after this in OnInit(), overwrites these with the real |
//| persisted values whenever a state file exists.                      |
//+------------------------------------------------------------------+
#define ZONE_STARTUP_LOOKBACK_BARS 10

void InitializeZoneLatchesFromHistory()
  {
   for(int shift = 1; shift <= ZONE_STARTUP_LOOKBACK_BARS; shift++)
     {
      double high  = iHigh(_Symbol, PERIOD_CURRENT, shift);
      double low   = iLow(_Symbol, PERIOD_CURRENT, shift);
      double close = iClose(_Symbol, PERIOD_CURRENT, shift);
      if(high <= 0.0 || low <= 0.0) break;   // ran out of available history

      if(g_bbHandle != INVALID_HANDLE)
        {
         double mid[1], up[1], lo[1];
         if(CopyBuffer(g_bbHandle, 0, shift, 1, mid) > 0 &&
            CopyBuffer(g_bbHandle, 1, shift, 1, up)  > 0 &&
            CopyBuffer(g_bbHandle, 2, shift, 1, lo)  > 0)
           {
            if(!g_bbBuyArmed  && low  <= lo[0] && close <= lo[0]) g_bbBuyArmed  = true;
            if(!g_bbSellArmed && high >= up[0] && close >= up[0]) g_bbSellArmed = true;
           }
        }

      if(g_qqeHandle != INVALID_HANDLE)
        {
         double q[1];
         if(CopyBuffer(g_qqeHandle, 0, shift, 1, q) > 0)
           {
            if(!g_qqeBuyArmed  && q[0] <= InpQQEOversold)   g_qqeBuyArmed  = true;
            if(!g_qqeSellArmed && q[0] >= InpQQEOverbought) g_qqeSellArmed = true;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Releases every indicator handle this EA created. Safe to call     |
//| even if some handles were never created (INVALID_HANDLE guard).   |
//+------------------------------------------------------------------+
void ReleaseIndicatorHandles()
  {
   if(g_qmpHandle    != INVALID_HANDLE) IndicatorRelease(g_qmpHandle);
   if(g_qqeHandle    != INVALID_HANDLE) IndicatorRelease(g_qqeHandle);
   if(g_bbHandle     != INVALID_HANDLE) IndicatorRelease(g_bbHandle);
   if(g_atrHandle    != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_maHandle     != INVALID_HANDLE) IndicatorRelease(g_maHandle);
   if(g_qqeHtfHandle != INVALID_HANDLE) IndicatorRelease(g_qqeHtfHandle);
   if(g_bbHtfHandle  != INVALID_HANDLE) IndicatorRelease(g_bbHtfHandle);
  }

//+====================================================================+
//| PHASE 2: sequence tracking, entry-signal pipeline, lot sizing       |
//+====================================================================+

//+------------------------------------------------------------------+
//| Builds the active multiplier array once at startup (called from   |
//| OnInit(), after ValidateCustomMultiplierString() has already       |
//| confirmed a Custom string parses cleanly, if that system is used). |
//| Trade index 0 = trade #1 of a sequence, index 1 = trade #2, etc.;  |
//| any index beyond the array reuses the last value (see              |
//| GetMultiplierForIndex()).                                          |
//+------------------------------------------------------------------+
void BuildMultiplierSequence()
  {
   switch(InpMultiplierSystem)
     {
      case MULT_SAFE:       { double a[] = {1,1,1,2,3,5,8};   ArrayCopy(g_multiplierSequence, a); break; }
      case MULT_LINEAR:     { double a[] = {1,2,3,4,5,6,7};   ArrayCopy(g_multiplierSequence, a); break; }
      case MULT_FIBONACCI:  { double a[] = {1,2,3,5,8,13};    ArrayCopy(g_multiplierSequence, a); break; }
      case MULT_AGGRESSIVE: { double a[] = {1,2,4,6,10,16};   ArrayCopy(g_multiplierSequence, a); break; }
      case MULT_MARTINGALE: { double a[] = {1,2,4,8,16,32};   ArrayCopy(g_multiplierSequence, a); break; }
      case MULT_CUSTOM:
        {
         string tokens[];
         int n = StringSplit(InpFibSequence, ',', tokens);
         ArrayResize(g_multiplierSequence, n);
         for(int i = 0; i < n; i++)
            g_multiplierSequence[i] = StringToDouble(tokens[i]);
         break;
        }
     }
  }

double GetMultiplierForIndex(int tradeIndex)
  {
   int n = ArraySize(g_multiplierSequence);
   if(n <= 0) return(1.0);
   if(tradeIndex >= n) tradeIndex = n - 1;
   return(g_multiplierSequence[tradeIndex]);
  }

//+------------------------------------------------------------------+
//| Rounds a lot size to the symbol's volume step and clamps it to     |
//| the broker's min/max volume.                                       |
//+------------------------------------------------------------------+
double NormalizeLot(double lots)
  {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;

   double normalized = MathRound(lots / step) * step;
   if(normalized < minLot) normalized = minLot;
   if(maxLot > 0.0 && normalized > maxLot) normalized = maxLot;
   return(NormalizeDouble(normalized, 2));
  }

//+------------------------------------------------------------------+
//| Computes the base (pre-multiplier) lot for trade #1 of a NEW       |
//| sequence, per the selected Lot Sizing Mode. This base is locked    |
//| into the sequence and reused (with the multiplier array) for       |
//| every subsequent add-on.                                           |
//|                                                                    |
//| ASSUMPTION (spec doesn't give an exact formula — flagged to the    |
//| stakeholder): %Balance/%Equity modes size the position so its      |
//| required margin equals InpLotPercent% of the account value,        |
//| using OrderCalcMargin() for a 1.0-lot reference. Step-Balance/      |
//| Step-Equity scale InpInitialLot upward by InpLotPerStep for every   |
//| InpStepAmount of account value, capped at InpMaxInitialLot (if >0). |
//+------------------------------------------------------------------+
double ComputeBaseLotForNewSequence(bool isBuy)
  {
   double base = InpInitialLot;

   switch(InpLotSizeMode)
     {
      case LOT_FIXED:
         base = InpInitialLot;
         break;

      case LOT_PERCENT_BALANCE:
      case LOT_PERCENT_EQUITY:
        {
         double accountValue = (InpLotSizeMode == LOT_PERCENT_BALANCE)
                                ? AccountInfoDouble(ACCOUNT_BALANCE) : AccountInfoDouble(ACCOUNT_EQUITY);
         double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double marginPerLot = 0.0;
         ENUM_ORDER_TYPE type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         if(OrderCalcMargin(type, _Symbol, 1.0, price, marginPerLot) && marginPerLot > 0.0)
            base = (accountValue * InpLotPercent / 100.0) / marginPerLot;
         else
            base = InpInitialLot;   // margin calc failed — fall back rather than risk a huge lot
         break;
        }

      case LOT_STEP_BALANCE:
      case LOT_STEP_EQUITY:
        {
         double accountValue = (InpLotSizeMode == LOT_STEP_BALANCE)
                                ? AccountInfoDouble(ACCOUNT_BALANCE) : AccountInfoDouble(ACCOUNT_EQUITY);
         int steps = (InpStepAmount > 0.0) ? (int)MathFloor(accountValue / InpStepAmount) : 0;
         base = InpInitialLot + steps * InpLotPerStep;
         if(InpMaxInitialLot > 0.0 && base > InpMaxInitialLot)
            base = InpMaxInitialLot;
         break;
        }
     }

   return(NormalizeLot(base));
  }

//+------------------------------------------------------------------+
//| Refreshes the per-closed-bar snapshot. Called once at the top of   |
//| ProcessNewBar(), before anything that reads BB/QQE/ATR/MA/bar-OHLC |
//| for the just-closed bar.                                           |
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

   g_maSnapshotValid = false;
   if(InpUseMAFilter && g_maHandle != INVALID_HANDLE)
     {
      double m[1];
      if(CopyBuffer(g_maHandle, 0, 1, 1, m) > 0)
        {
         g_ma1 = m[0];
         g_maSnapshotValid = true;
        }
     }
  }

//+------------------------------------------------------------------+
//| "Breach" = the closed bar touched the band/level AND closed beyond |
//| it — a mid-candle touch that closes back on the wrong side does    |
//| not count (per the guide).                                         |
//+------------------------------------------------------------------+
bool BBBuyBreach()   { return(g_bbSnapshotValid && g_bar1Low  <= g_bbLower1 && g_bar1Close <= g_bbLower1); }
bool BBSellBreach()  { return(g_bbSnapshotValid && g_bar1High >= g_bbUpper1 && g_bar1Close >= g_bbUpper1); }
bool QQEBuyBreach()  { return(g_qqeSnapshotValid && g_qqeLine1 <= InpQQEOversold); }
bool QQESellBreach() { return(g_qqeSnapshotValid && g_qqeLine1 >= InpQQEOverbought); }

//+------------------------------------------------------------------+
//| Updates the sticky zone-armed latches from this bar's breach       |
//| state. Latches only ever turn on here — they are turned off only   |
//| by ConsumeZoneLatch() when a brand-new sequence's first trade      |
//| opens (see the "armed" latch comment on the globals above).        |
//+------------------------------------------------------------------+
void UpdateZoneBreachLatches()
  {
   if(BBBuyBreach())
     {
      g_bbBuyArmed = true;
      if(InpRequireBBBandTouchForReentry) g_reentryReadyBuy = true;
     }
   if(BBSellBreach())
     {
      g_bbSellArmed = true;
      if(InpRequireBBBandTouchForReentry) g_reentryReadySell = true;
     }
   if(QQEBuyBreach())
     {
      g_qqeBuyArmed = true;
      if(InpRequireQQEScenarioBForReentry) g_reentryReadyBuy = true;
     }
   if(QQESellBreach())
     {
      g_qqeSellArmed = true;
      if(InpRequireQQEScenarioBForReentry) g_reentryReadySell = true;
     }
  }

void ConsumeZoneLatch(bool isBuy)
  {
   if(InpIndicatorMode == INDICATOR_BB_ONLY || InpIndicatorMode == INDICATOR_BOTH)
     { if(isBuy) g_bbBuyArmed = false; else g_bbSellArmed = false; }
   if(InpIndicatorMode == INDICATOR_QQE_ONLY || InpIndicatorMode == INDICATOR_BOTH)
     { if(isBuy) g_qqeBuyArmed = false; else g_qqeSellArmed = false; }
  }

//+------------------------------------------------------------------+
//| Whether the entry zone is currently armed for a NEW sequence in    |
//| the given direction. In Both mode, BB drives the breach and QQE    |
//| must ALSO have breached the matching level (AND, per the guide).   |
//+------------------------------------------------------------------+
bool ZoneArmedForEntry(bool isBuy)
  {
   switch(InpIndicatorMode)
     {
      case INDICATOR_BB_ONLY:  return(isBuy ? g_bbBuyArmed  : g_bbSellArmed);
      case INDICATOR_QQE_ONLY: return(isBuy ? g_qqeBuyArmed : g_qqeSellArmed);
      case INDICATOR_BOTH:     return(isBuy ? (g_bbBuyArmed && g_qqeBuyArmed) : (g_bbSellArmed && g_qqeSellArmed));
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Reads this bar's QMP dot directly from the closed bar (shift 1).   |
//| Returns +1 for an Up dot, -1 for a Dn dot, 0 for no dot.            |
//+------------------------------------------------------------------+
int GetClosedBarQmpDirection()
  {
   if(g_qmpHandle == INVALID_HANDLE) return(0);
   double up[1], dn[1];
   bool haveUp = CopyBuffer(g_qmpHandle, 0, 1, 1, up) > 0;
   bool haveDn = CopyBuffer(g_qmpHandle, 1, 1, 1, dn) > 0;
   if(haveUp && up[0] != EMPTY_VALUE) return(+1);
   if(haveDn && dn[0] != EMPTY_VALUE) return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
//| Entry gate: max spread.                                            |
//+------------------------------------------------------------------+
bool SpreadOk()
  {
   long spreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return(InpMaxSpread <= 0 || spreadPoints <= InpMaxSpread);
  }

bool DirectionAllowed(bool isBuy)
  {
   if(InpTradeDirection == DIRECTION_BUY_ONLY)  return(isBuy);
   if(InpTradeDirection == DIRECTION_SELL_ONLY) return(!isBuy);
   return(true);
  }

int CountOpenSequences(bool isBuy)
  {
   return(isBuy ? ArraySize(g_buySequences) : ArraySize(g_sellSequences));
  }

bool OppositeDirectionBlocked(bool isBuy)
  {
   if(InpAllowBuySellAtSameTime) return(false);
   return(CountOpenSequences(!isBuy) > 0);
  }

//+------------------------------------------------------------------+
//| New-sequence-only entry gates (report §5.3 / §14 step 5 category). |
//| Each is a no-op (returns true) when its governing input is off or  |
//| when it doesn't apply to the active Indicator Mode.                |
//+------------------------------------------------------------------+
bool CentreCrossReady(bool isBuy)
  {
   if(!InpRequireCenterBandCross) return(true);
   if(InpIndicatorMode == INDICATOR_QQE_ONLY) return(true);   // no centre band in QQE-only mode
   return(isBuy ? g_centreCrossReadyBuy : g_centreCrossReadySell);
  }

//+------------------------------------------------------------------+
//| Updates the centre-cross-ready latches from this bar's close       |
//| relative to the middle band — a close on one side re-arms new-      |
//| sequence readiness for the OPPOSITE direction (a close below centre |
//| means price has recovered away from any open SELL sequence's        |
//| territory, so a fresh SELL sequence can only be justified after a   |
//| genuine reversal back above centre, and vice versa).                |
//+------------------------------------------------------------------+
void UpdateCentreCrossReadiness()
  {
   if(!g_bbSnapshotValid) return;
   //--- BUG FIX (FORENSIC_COMPARISON_REPORT.md §11): these two lines were
   //--- swapped — a close BELOW centre was arming BUY-readiness instead of
   //--- SELL-readiness, which is backwards from the reasoning in the comment
   //--- above (and from CentreCrossReady()'s own check a few lines up: a NEW
   //--- buy sequence requires g_centreCrossReadyBuy, i.e. price should have
   //--- recovered ABOVE centre at some point, not stayed below it). The
   //--- inverted version was true on every bar throughout a one-directional
   //--- move, defeating the whole gate exactly like the original stateless
   //--- positional check this replaced.
   if(g_bar1Close > g_bbMiddle1)      g_centreCrossReadyBuy  = true;
   else if(g_bar1Close < g_bbMiddle1) g_centreCrossReadySell = true;
  }

bool NoTriggerOnCentreBreachOk()
  {
   if(!InpNoTriggerOnCentralBandBreach) return(true);
   return(!g_pendingSignalCentreBreached);   // false (BB inactive) never blocks
  }

bool BBWidthOk()
  {
   if(!InpUseBBWidthFilter) return(true);
   if(InpIndicatorMode == INDICATOR_QQE_ONLY) return(true);   // no bands to measure in QQE-only mode
   if(!g_bbSnapshotValid || g_bbMiddle1 <= 0.0) return(false);
   double widthPercent = (g_bbUpper1 - g_bbLower1) / g_bbMiddle1 * 100.0;
   return(widthPercent >= InpBBMinWidthPercent);
  }

bool ReentryReady(bool isBuy)
  {
   bool required = InpRequireBBBandTouchForReentry || InpRequireQQEScenarioBForReentry;
   if(!required) return(true);
   return(isBuy ? g_reentryReadyBuy : g_reentryReadySell);
  }

bool MAFilterOk(bool isBuy)
  {
   if(!InpUseMAFilter) return(true);
   if(!g_maSnapshotValid) return(false);
   bool aboveMA = (g_bar1Close > g_ma1);
   if(InpMAFilterBehaviour == MA_BUY_ABOVE_SELL_BELOW)
      return(isBuy ? aboveMA : !aboveMA);
   return(isBuy ? !aboveMA : aboveMA);
  }

//+------------------------------------------------------------------+
//| Higher Timeframe Direction Filter.                                 |
//|                                                                    |
//| ASSUMPTION (spec doesn't give an exact formula — flagged to the    |
//| stakeholder): bias is bullish/bearish based on the HTF's last      |
//| closed bar close vs. its BB middle band (BB modes) and/or its QQE  |
//| line vs. 50 (QQE modes), reusing the same BB/QQE settings as the   |
//| current-timeframe entry logic (confirmed by the guide for the      |
//| "same settings on both timeframes" wording). In Both mode, BB and  |
//| QQE must agree, or the direction is neutral (blocks both sides).   |
//+------------------------------------------------------------------+
void UpdateHtfDirection()
  {
   g_htfDirection = 0;
   if(!InpTradeInHigherTFDirection) return;

   int  bbBias = 0, qqeBias = 0;
   bool haveBB = false, haveQQE = false;

   if(g_bbHtfHandle != INVALID_HANDLE)
     {
      double mid[1];
      if(CopyBuffer(g_bbHtfHandle, 0, 1, 1, mid) > 0)
        {
         double htfClose = iClose(_Symbol, InpHigherTimeframe, 1);
         bbBias = (htfClose > mid[0]) ? 1 : (htfClose < mid[0] ? -1 : 0);
         haveBB = true;
        }
     }
   if(g_qqeHtfHandle != INVALID_HANDLE)
     {
      double q[1];
      if(CopyBuffer(g_qqeHtfHandle, 0, 1, 1, q) > 0)
        {
         qqeBias = (q[0] > 50.0) ? 1 : (q[0] < 50.0 ? -1 : 0);
         haveQQE = true;
        }
     }

   if(haveBB && haveQQE)      g_htfDirection = (bbBias == qqeBias) ? bbBias : 0;
   else if(haveBB)            g_htfDirection = bbBias;
   else if(haveQQE)           g_htfDirection = qqeBias;
  }

bool HtfDirectionOk(bool isBuy)
  {
   if(!InpTradeInHigherTFDirection) return(true);
   if(g_htfDirection == 0) return(false);
   return(isBuy ? g_htfDirection > 0 : g_htfDirection < 0);
  }

//+====================================================================+
//| Front-loaded PHASE 4 helpers (chart-object primitives, session/     |
//| time-of-day helpers). MQL5 requires define-before-use in the same   |
//| file, and CreateNewSequence()/TryOpenNewSequence() below need these — |
//| so, like the chart-object helpers and Sequence-array plumbing in    |
//| Phase 2, they're defined here rather than down with the rest of     |
//| the Phase 4 code (session/EOD/EOW handling, state persistence, the  |
//| info panel), which is only ever called from OnTick() at the very    |
//| end of the file and has no such ordering constraint.                |
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
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
   else
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
  }

//+------------------------------------------------------------------+
//| Sequence Start/End vertical markers are deliberately kept separate  |
//| from the other per-sequence "live" lines (Trail/BE/BEBuffer/        |
//| RiskRed/TP) — they're meant to persist as a historical record of    |
//| the sequence's lifetime even after it closes, so DeleteSequence-    |
//| ChartObjects() (called on close) never touches them.                |
//+------------------------------------------------------------------+
void DrawSequenceStartLine(bool isBuy, long sequenceId, datetime startTime)
  {
   if(!InpShowSequenceStartEndLines) return;
   string name = SeqObjName("SeqStart", isBuy, sequenceId);
   if(ObjectFind(0, name) >= 0) return;
   ObjectCreate(0, name, OBJ_VLINE, 0, startTime, 0);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpSequenceStartColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, InpSequenceLineStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, InpSequenceLineWidth);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  }

void DrawSequenceEndLine(bool isBuy, long sequenceId)
  {
   if(!InpShowSequenceStartEndLines) return;
   string name = SeqObjName("SeqEnd", isBuy, sequenceId);
   if(ObjectFind(0, name) >= 0) return;
   ObjectCreate(0, name, OBJ_VLINE, 0, TimeCurrent(), 0);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpSequenceEndColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, InpSequenceLineStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, InpSequenceLineWidth);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  }

void DeleteSequenceChartObjects(bool isBuy, long sequenceId)
  {
   DeleteObjectIfExists(SeqObjName("Trail",  isBuy, sequenceId));
   DeleteObjectIfExists(SeqObjName("BE",     isBuy, sequenceId));
   DeleteObjectIfExists(SeqObjName("BEBuf",  isBuy, sequenceId));
   DeleteObjectIfExists(SeqObjName("RiskRed",isBuy, sequenceId));
   DeleteObjectIfExists(SeqObjName("TP",     isBuy, sequenceId));
  }

//+------------------------------------------------------------------+
//| Reference date/time per InpTimeReference — shared by the Trading    |
//| Session filter, End of Day/Week, and Session Profit Limit so they   |
//| all agree on what "now" and "today" mean.                           |
//+------------------------------------------------------------------+
void GetReferenceDateTime(MqlDateTime &dtOut)
  {
   datetime ref;
   switch(InpTimeReference)
     {
      case TIME_LOCAL:      ref = TimeLocal(); break;
      case TIME_GMT_OFFSET: ref = TimeGMT() + InpGMTOffset * 3600; break;
      default:              ref = TimeCurrent(); break;
     }
   TimeToStruct(ref, dtOut);
  }

int CurrentReferenceTimeOfDaySeconds()
  {
   MqlDateTime dt;
   GetReferenceDateTime(dt);
   return(dt.hour * 3600 + dt.min * 60 + dt.sec);
  }

int CurrentReferenceDayOfWeek()
  {
   MqlDateTime dt;
   GetReferenceDateTime(dt);
   return(dt.day_of_week);   // 0 = Sunday .. 6 = Saturday
  }

datetime CurrentReferenceDate()
  {
   MqlDateTime dt;
   GetReferenceDateTime(dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return(StructToTime(dt));
  }

bool ParseHHMM(string s, int &secondsOut)
  {
   string parts[];
   int n = StringSplit(s, ':', parts);
   if(n < 2) return(false);
   int h = (int)StringToInteger(parts[0]);
   int m = (int)StringToInteger(parts[1]);
   if(h < 0 || h > 23 || m < 0 || m > 59) return(false);
   secondsOut = h * 3600 + m * 60;
   return(true);
  }

bool IsDayTradingAllowed(int dayOfWeek)
  {
   switch(dayOfWeek)
     {
      case 0: return(InpTradeSunday);
      case 1: return(InpTradeMonday);
      case 2: return(InpTradeTuesday);
      case 3: return(InpTradeWednesday);
      case 4: return(InpTradeThursday);
      case 5: return(InpTradeFriday);
      case 6: return(InpTradeSaturday);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Trading Session filter — gates ALL new position-opening (both new   |
//| sequences and add-ons), since the guide gives no reason to think    |
//| DCA add-ons should be exempt from the user's chosen trading hours.  |
//| Exits are never gated by this — an existing position must always    |
//| stay manageable regardless of session.                              |
//+------------------------------------------------------------------+
bool IsWithinTradingSession()
  {
   if(!InpUseTimeFilter) return(true);

   if(!IsDayTradingAllowed(CurrentReferenceDayOfWeek())) return(false);

   int startSec, endSec;
   if(!ParseHHMM(InpTradingStartTime, startSec) || !ParseHHMM(InpTradingEndTime, endSec))
      return(true);   // malformed input — fail open rather than silently blocking all trading

   int nowSec = CurrentReferenceTimeOfDaySeconds();
   if(startSec == endSec) return(true);            // zero-length window — treat as "all day"
   if(startSec < endSec)  return(nowSec >= startSec && nowSec < endSec);
   return(nowSec >= startSec || nowSec < endSec);   // overnight window wrapping midnight
  }

//+------------------------------------------------------------------+
//| Session Profit Limit — ASSUMPTION (spec doesn't define "session"    |
//| beyond the input's name/defaults, flagged to the stakeholder):      |
//| "session" = one calendar day in InpTimeReference's timezone.        |
//| g_sessionRealizedProfit is accumulated in CloseSequenceAndCleanup() |
//| and ExecutePartialCloseIfDue() and reset by UpdateSessionProfit-    |
//| Tracking() (Phase 4) whenever the reference date rolls over.        |
//| Only blocks brand-NEW sequences, per the input's own name — existing|
//| sequences and their add-ons are unaffected.                         |
//+------------------------------------------------------------------+
bool SessionProfitLimitReached()
  {
   if(InpStopAfterProfitPerSession <= 0.0) return(false);
   return(g_sessionRealizedProfit >= InpStopAfterProfitPerSession);
  }

//+====================================================================+
//| State persistence — save side (report §10/§13 item 8, §15 fix).     |
//| Plain delimited text under MQL5/Files/, one file per (Symbol,       |
//| Magic Number), rewritten in full on every save. Front-loaded here,  |
//| ahead of LoadState() (later in the file, once its own dependencies  |
//| RemoveSequenceAt()/SyncSequenceFromLivePositions() exist), because   |
//| AddOnToAllOpenSequences()/TryOpenNewSequence() below call SaveState()|
//| directly on a successful entry (a structural event that must         |
//| survive a crash without waiting for the next throttled tick — see    |
//| §15).                                                                 |
//|                                                                      |
//| CRITICAL: never runs inside the Strategy Tester. A saved file        |
//| persists between SEPARATE backtest runs on the same symbol/magic —  |
//| without this guard, a fresh backtest's OnInit() would load whatever  |
//| zone-armed/pending-signal/session state a PREVIOUS run happened to   |
//| end in and replay history with mismatched state (this was the        |
//| documented root cause of a large, unexplained trade-count drop in    |
//| §15's incident writeup). State persistence exists for live/demo      |
//| crash recovery only — every backtest must start clean.               |
//+====================================================================+
string GetStateFilePath()
  {
   return(StringFormat("DCA_EA_state_%s_%I64d.txt", _Symbol, InpMagicNumber));
  }

void WriteSequencesToFile(int handle, bool isBuy)
  {
   int total = isBuy ? ArraySize(g_buySequences) : ArraySize(g_sellSequences);
   for(int i = 0; i < total; i++)
     {
      Sequence s = isBuy ? g_buySequences[i] : g_sellSequences[i];   // deep-copies s.tickets[]

      string ticketsStr = "";
      for(int t = 0; t < s.count; t++)
         ticketsStr += (t > 0 ? ";" : "") + (string)s.tickets[t];

      //--- field order: SEQ|dir|count|avgPrice|totalVolume|lockedBaseLot|sequenceId|
      //--- startTime|recoveryModeActive|trailStopActive|trailStopPrice|partialCloseDone|
      //--- lastEntryTime|lastEntryPrice|tickets — LoadState() below must match exactly.
      string line = StringFormat("SEQ|%s|%d|%.5f|%.2f|%.5f|%I64d|%I64d|%d|%d|%.5f|%d|%I64d|%.5f|%s",
                                  isBuy ? "BUY" : "SELL", s.count, s.avgPrice, s.totalVolume, s.lockedBaseLot,
                                  s.sequenceId, (long)s.startTime,
                                  (int)s.recoveryModeActive, (int)s.trailStopActive, s.trailStopPrice,
                                  (int)s.partialCloseDone, (long)s.lastEntryTime, s.lastEntryPrice, ticketsStr);
      FileWriteString(handle, line + "\n");
     }
  }

void SaveState()
  {
   if(MQLInfoInteger(MQL_TESTER)) return;

   int handle = FileOpen(GetStateFilePath(), FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      Print("EA-DCA: failed to open state file for writing. Error ", GetLastError());
      return;
     }

   //--- field order: GLOBAL|bbBuyArmed|bbSellArmed|qqeBuyArmed|qqeSellArmed|
   //--- reentryReadyBuy|reentryReadySell|pendingSignal|pendingSignalIsBuy|
   //--- pendingSignalCentreBreached|sessionRealizedProfit|sessionDate|
   //--- lastEODActionDate|lastEOWActionDate|nextSequenceId|
   //--- centreCrossReadyBuy|centreCrossReadySell
   string globalLine = StringFormat("GLOBAL|%d|%d|%d|%d|%d|%d|%d|%d|%d|%.2f|%I64d|%I64d|%I64d|%I64d|%d|%d",
                                     (int)g_bbBuyArmed, (int)g_bbSellArmed, (int)g_qqeBuyArmed, (int)g_qqeSellArmed,
                                     (int)g_reentryReadyBuy, (int)g_reentryReadySell,
                                     (int)g_pendingSignal, (int)g_pendingSignalIsBuy, (int)g_pendingSignalCentreBreached,
                                     g_sessionRealizedProfit, (long)g_sessionDate,
                                     (long)g_lastEODActionDate, (long)g_lastEOWActionDate, g_nextSequenceId,
                                     (int)g_centreCrossReadyBuy, (int)g_centreCrossReadySell);
   FileWriteString(handle, globalLine + "\n");

   WriteSequencesToFile(handle, true);
   WriteSequencesToFile(handle, false);

   FileClose(handle);
   g_lastSaveTickMs = GetTickCount64();
  }

//+------------------------------------------------------------------+
//| Routine per-tick saves are throttled to roughly once every 2 real   |
//| seconds (wall-clock, via GetTickCount64() — unaffected by Strategy  |
//| Tester's simulated time) to avoid the per-tick FileOpen()/write/     |
//| FileClose() performance anti-pattern documented in §15. Structural  |
//| events (a trade opening, a sequence closing, a partial close) call  |
//| SaveState() directly instead, bypassing the throttle.               |
//+------------------------------------------------------------------+
#define STATE_SAVE_THROTTLE_MS 2000

void SaveStateThrottled()
  {
   if(GetTickCount64() - g_lastSaveTickMs < STATE_SAVE_THROTTLE_MS) return;
   SaveState();
  }

bool NewSequenceGatesPass(bool isBuy)
  {
   if(SessionProfitLimitReached())     return(false);
   if(!ZoneArmedForEntry(isBuy))       return(false);
   if(!NoTriggerOnCentreBreachOk())    return(false);
   if(!CentreCrossReady(isBuy))        return(false);
   if(!BBWidthOk())                    return(false);
   if(!ReentryReady(isBuy))            return(false);
   if(!MAFilterOk(isBuy))              return(false);
   if(!HtfDirectionOk(isBuy))          return(false);
   return(true);
  }

//+------------------------------------------------------------------+
//| Add-on-only entry gate: Minimum Signal Distance from the target    |
//| sequence's last entry. Still applied even under a future Recovery  |
//| Mode override, since that mode bypasses the BB/QQE zone check      |
//| specifically, not every independent risk control (per the guide).  |
//+------------------------------------------------------------------+
bool MinSignalDistanceOk(bool isBuy, int seqIdx)
  {
   if(!InpUseMinimumSignalDistance) return(true);

   double lastPrice    = isBuy ? g_buySequences[seqIdx].lastEntryPrice : g_sellSequences[seqIdx].lastEntryPrice;
   double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double required = (InpUseATRForMinDistance && g_atrSnapshotValid)
                      ? g_atr1 * InpMinDistanceATRMultiplier
                      : PipsToPrice(InpMinDistancePips);

   return(MathAbs(currentPrice - lastPrice) >= required);
  }

bool AddOnGatesPass(bool isBuy, int seqIdx)
  {
   if(!MinSignalDistanceOk(isBuy, seqIdx)) return(false);
   //--- All-Signals-Must-Match-Entry: an add-on also needs a live, currently-armed
   //--- zone breach — not just a QMP dot — same requirement as a new sequence.
   //--- Recovery Mode (§5.7) waives specifically this requirement — not Minimum
   //--- Signal Distance above — since the guide frames Recovery as bypassing the
   //--- BB/QQE zone check, not every independent risk control.
   bool recoveryActive = isBuy ? g_buySequences[seqIdx].recoveryModeActive : g_sellSequences[seqIdx].recoveryModeActive;
   if(InpAllSignalsMatchEntryCriteria && !recoveryActive && !ZoneArmedForEntry(isBuy)) return(false);
   return(true);
  }

//+------------------------------------------------------------------+
//| Pre-trade margin validation (analysis report §19, item 5). Rejects |
//| the trade with a logged reason rather than letting the broker      |
//| bounce the order at send-time.                                     |
//+------------------------------------------------------------------+
bool MarginOk(bool isBuy, double lot)
  {
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double requiredMargin = 0.0;
   ENUM_ORDER_TYPE type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   if(!OrderCalcMargin(type, _Symbol, lot, price, requiredMargin))
     {
      Print("EA-DCA: OrderCalcMargin failed (error ", GetLastError(), ") — rejecting trade as a precaution.");
      return(false);
     }

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(requiredMargin > freeMargin)
     {
      Print("EA-DCA: insufficient free margin for a ", (isBuy ? "BUY" : "SELL"), " of ", DoubleToString(lot, 2),
            " lots — requires ~", DoubleToString(requiredMargin, 2), ", free margin is ",
            DoubleToString(freeMargin, 2), ". Trade rejected.");
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
//| Sends a market order and resolves the resulting POSITION ticket    |
//| via the deal's DEAL_POSITION_ID — the robust way to identify the   |
//| opened position on a hedging account, where several positions on   |
//| the same symbol can coexist (a plain order/result ticket is not    |
//| guaranteed to equal the position ticket).                          |
//+------------------------------------------------------------------+
ulong SendMarketOrder(bool isBuy, double lot, double &filledPrice)
  {
   bool ok = isBuy ? trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, InpUserComment)
                    : trade.Sell(lot, _Symbol, 0.0, 0.0, 0.0, InpUserComment);
   if(!ok)
     {
      Print("EA-DCA: order send failed. Retcode ", trade.ResultRetcode(), " (", trade.ResultRetcodeDescription(), ")");
      return(0);
     }

   filledPrice = trade.ResultPrice();

   ulong dealTicket = trade.ResultDeal();
   ulong positionId = 0;
   if(dealTicket > 0 && HistoryDealSelect(dealTicket))
      positionId = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

   if(positionId == 0)
      Print("EA-DCA WARNING: order filled but could not resolve a position ticket from the deal — "
            "sequence tracking for this trade may be incomplete.");

   return(positionId);
  }

//+------------------------------------------------------------------+
//| Sequence bookkeeping: create a brand-new sequence, or append an    |
//| add-on trade to an existing one (volume-weighted average price).   |
//+------------------------------------------------------------------+
void CreateNewSequence(bool isBuy, ulong ticket, double baseLot, double price)
  {
   Sequence s;
   ArrayResize(s.tickets, 1);
   s.tickets[0]      = ticket;
   s.count           = 1;
   s.avgPrice        = price;
   s.totalVolume     = NormalizeLot(baseLot * GetMultiplierForIndex(0));
   s.lastEntryTime   = TimeCurrent();
   s.lastEntryPrice  = price;
   s.lockedBaseLot   = baseLot;
   s.sequenceId      = g_nextSequenceId++;
   s.startTime       = TimeCurrent();
   s.recoveryModeActive = false;
   s.trailStopActive    = false;
   s.trailStopPrice     = 0.0;
   s.partialCloseDone   = false;

   DrawSequenceStartLine(isBuy, s.sequenceId, s.startTime);

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

void AppendToSequence(bool isBuy, int seqIdx, ulong ticket, double lot, double price)
  {
   if(isBuy)
     {
      int n = g_buySequences[seqIdx].count;
      ArrayResize(g_buySequences[seqIdx].tickets, n + 1);
      g_buySequences[seqIdx].tickets[n] = ticket;
      double newVolume = g_buySequences[seqIdx].totalVolume + lot;
      g_buySequences[seqIdx].avgPrice = (g_buySequences[seqIdx].avgPrice * g_buySequences[seqIdx].totalVolume + price * lot) / newVolume;
      g_buySequences[seqIdx].totalVolume    = newVolume;
      g_buySequences[seqIdx].count          = n + 1;
      g_buySequences[seqIdx].lastEntryTime  = TimeCurrent();
      g_buySequences[seqIdx].lastEntryPrice = price;
     }
   else
     {
      int n = g_sellSequences[seqIdx].count;
      ArrayResize(g_sellSequences[seqIdx].tickets, n + 1);
      g_sellSequences[seqIdx].tickets[n] = ticket;
      double newVolume = g_sellSequences[seqIdx].totalVolume + lot;
      g_sellSequences[seqIdx].avgPrice = (g_sellSequences[seqIdx].avgPrice * g_sellSequences[seqIdx].totalVolume + price * lot) / newVolume;
      g_sellSequences[seqIdx].totalVolume    = newVolume;
      g_sellSequences[seqIdx].count          = n + 1;
      g_sellSequences[seqIdx].lastEntryTime  = TimeCurrent();
      g_sellSequences[seqIdx].lastEntryPrice = price;
     }
  }

void RemoveSequenceAt(bool isBuy, int idx)
  {
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

//+------------------------------------------------------------------+
//| Re-syncs a sequence's tickets/count/avgPrice/volume against what's |
//| actually still open — a position can disappear outside the EA's   |
//| control (broker stop-out, manual close), so tracking must never    |
//| assume the in-memory state is still accurate without checking.     |
//| Also guards against ticket reuse by re-verifying symbol and magic  |
//| number on every position.                                          |
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
//| Safety net: prunes any sequence that has gone fully flat outside   |
//| the EA's control. Runs once per new bar — cheap, and this EA's     |
//| entries are bar-close driven anyway.                                |
//+------------------------------------------------------------------+
void PruneClosedSequences()
  {
   for(int i = ArraySize(g_buySequences) - 1; i >= 0; i--)
     {
      SyncSequenceFromLivePositions(true, i);
      if(g_buySequences[i].count == 0)
         RemoveSequenceAt(true, i);
     }
   for(int i = ArraySize(g_sellSequences) - 1; i >= 0; i--)
     {
      SyncSequenceFromLivePositions(false, i);
      if(g_sellSequences[i].count == 0)
         RemoveSequenceAt(false, i);
     }
  }

//+------------------------------------------------------------------+
//| §5.2 fix (see FORENSIC_COMPARISON_REPORT.md): a dot's "add to an     |
//| existing sequence" and "open a brand-new parallel sequence" are      |
//| INDEPENDENT triggers, not a mutually-exclusive either/or — both can  |
//| fire from the same dot, confirmed directly by the reference EA's own |
//| deal log (e.g. 2026.06.12: one dot adds to TWO different already-    |
//| open sequences simultaneously; 2026.01.16 and 2026.06.09: one dot    |
//| both adds to an existing sequence AND opens a new parallel one).     |
//|                                                                       |
//| Adds a trade to EVERY currently open, non-full, non-partial-closed   |
//| sequence in the given direction — not just the first one found.     |
//| The general trading-permission gates (session/direction/spread/      |
//| opposite-direction) are checked once, since they don't vary per      |
//| sequence within the same bar.                                        |
//+------------------------------------------------------------------+
void AddOnToAllOpenSequences(bool isBuy)
  {
   if(!IsWithinTradingSession())       return;
   if(!DirectionAllowed(isBuy))        return;
   if(!SpreadOk())                     return;
   if(OppositeDirectionBlocked(isBuy)) return;

   int total = isBuy ? ArraySize(g_buySequences) : ArraySize(g_sellSequences);
   for(int i = 0; i < total; i++)
     {
      int  count      = isBuy ? g_buySequences[i].count          : g_sellSequences[i].count;
      bool partialDone = isBuy ? g_buySequences[i].partialCloseDone : g_sellSequences[i].partialCloseDone;
      if(partialDone) continue;
      if(!(InpMaxTradesPerSequence <= 0 || count < InpMaxTradesPerSequence)) continue;
      if(!AddOnGatesPass(isBuy, i)) continue;

      double baseLot    = isBuy ? g_buySequences[i].lockedBaseLot : g_sellSequences[i].lockedBaseLot;
      int    tradeIndex = isBuy ? g_buySequences[i].count         : g_sellSequences[i].count;
      double lot        = NormalizeLot(baseLot * GetMultiplierForIndex(tradeIndex));

      if(!MarginOk(isBuy, lot)) continue;

      double filledPrice = 0.0;
      ulong  ticket = SendMarketOrder(isBuy, lot, filledPrice);
      if(ticket == 0) continue;

      AppendToSequence(isBuy, i, ticket, lot, filledPrice);
      SaveState();   // structural event — bypass the per-tick throttle (§15)
     }
  }

//+------------------------------------------------------------------+
//| The new-sequence path — independent of AddOnToAllOpenSequences()    |
//| above, and of how many sequences are already open (up to the        |
//| InpMaxSequencesPerDirection cap). Uses the existing sticky zone-     |
//| armed latch exactly as before; ConsumeZoneLatch() on success is      |
//| what naturally rations how often a new parallel sequence can open —  |
//| the latch only re-arms on a genuine fresh breach, which is why new   |
//| sequences are rare in practice despite being checked every bar.      |
//| Returns true only if a trade was actually opened.                    |
//+------------------------------------------------------------------+
bool TryOpenNewSequence(bool isBuy)
  {
   if(!IsWithinTradingSession())       return(false);
   if(!DirectionAllowed(isBuy))        return(false);
   if(!SpreadOk())                     return(false);
   if(OppositeDirectionBlocked(isBuy)) return(false);

   int maxSeq = InpMaxSequencesPerDirection;
   if(InpAllSignalsMatchEntryCriteria && (maxSeq <= 0 || maxSeq > 1))
      maxSeq = 1;
   if(maxSeq > 0 && CountOpenSequences(isBuy) >= maxSeq) return(false);
   if(!NewSequenceGatesPass(isBuy)) return(false);

   double baseLot = ComputeBaseLotForNewSequence(isBuy);
   double lot     = NormalizeLot(baseLot * GetMultiplierForIndex(0));
   if(!MarginOk(isBuy, lot)) return(false);

   double filledPrice = 0.0;
   ulong  ticket = SendMarketOrder(isBuy, lot, filledPrice);
   if(ticket == 0) return(false);

   CreateNewSequence(isBuy, ticket, baseLot, filledPrice);
   ConsumeZoneLatch(isBuy);
   if(isBuy) g_centreCrossReadyBuy = false; else g_centreCrossReadySell = false;
   SaveState();   // structural event — bypass the per-tick throttle (§15)
   return(true);
  }

//+------------------------------------------------------------------+
//| Runs once per closed bar: refreshes the indicator snapshot, updates|
//| the zone-breach latches and HTF bias, prunes any sequence that has |
//| gone flat outside the EA's control, then processes this bar's QMP  |
//| dot. A dot triggers BOTH independent paths — add-ons to every open  |
//| sequence with room, and (separately) an attempt to open a new       |
//| parallel sequence if the zone is armed and the concurrent-sequence   |
//| cap allows it. The new-sequence attempt keeps retrying on every      |
//| future bar (via the pending-signal latch) until the zone arms — no   |
//| time limit, per the guide — even across bars with no further dot.   |
//+------------------------------------------------------------------+
void ProcessNewBar()
  {
   RefreshBarSnapshot();
   UpdateZoneBreachLatches();
   UpdateCentreCrossReadiness();
   UpdateHtfDirection();
   PruneClosedSequences();

   int dot = GetClosedBarQmpDirection();
   if(dot != 0)
     {
      bool isBuy = (dot > 0);

      AddOnToAllOpenSequences(isBuy);

      //--- a fresh dot always supersedes any older pending one, matching
      //--- QMP's own trend-flip semantics.
      g_pendingSignal               = true;
      g_pendingSignalIsBuy          = isBuy;
      g_pendingSignalCentreBreached = g_bbSnapshotValid &&
                                       (g_bar1Low <= g_bbMiddle1 && g_bar1High >= g_bbMiddle1);
     }

   if(g_pendingSignal && TryOpenNewSequence(g_pendingSignalIsBuy))
      g_pendingSignal = false;   // consumed; else keep pending, retry once the zone arms
  }

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

//+====================================================================+
//| PHASE 3: exit strategies, Dynamic Stop, Partial Close,              |
//| Risk Reduction, Recovery Mode                                       |
//|                                                                     |
//| All exit checks run every tick (CheckExitsPerTick(), called from    |
//| OnTick() before the entry pipeline). BB Centre Band's "close" mode  |
//| and the QQE 50 condition read the per-closed-bar snapshot from      |
//| Phase 2 (refreshed once per bar in RefreshBarSnapshot()), so they   |
//| are effectively bar-close driven even though evaluated every tick — |
//| no separate per-bar pass is needed.                                 |
//+====================================================================+

//+------------------------------------------------------------------+
//| Floating profit of a sequence, in account currency (all open       |
//| trades' profit + swap) and in pips relative to the volume-weighted |
//| average entry price. The pip figure is what every breakeven/       |
//| buffer/recovery check in this EA is expressed in, per the guide.   |
//+------------------------------------------------------------------+
double GetSequenceProfitMoney(bool isBuy, int idx)
  {
   int    count = isBuy ? g_buySequences[idx].count : g_sellSequences[idx].count;
   double total = 0.0;
   for(int i = 0; i < count; i++)
     {
      ulong ticket = isBuy ? g_buySequences[idx].tickets[i] : g_sellSequences[idx].tickets[i];
      if(PositionSelectByTicket(ticket))
         total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return(total);
  }

double GetSequenceProfitPips(bool isBuy, int idx)
  {
   double avg     = isBuy ? g_buySequences[idx].avgPrice : g_sellSequences[idx].avgPrice;
   double current = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double diff    = isBuy ? (current - avg) : (avg - current);
   if(g_pipSize <= 0.0) return(0.0);
   return(diff / g_pipSize);
  }

double ATRValue()
  {
   double a[1];
   if(g_atrHandle != INVALID_HANDLE && CopyBuffer(g_atrHandle, 0, 0, 1, a) > 0)
      return(a[0]);
   return(0.0);
  }

double TrailingDistance()
  {
   return(InpUseATRForTrailingDistance ? ATRValue() * InpTrailingDistanceATRMultiplier : PipsToPrice(InpTrailingStepPips));
  }

//+------------------------------------------------------------------+
//| BB Centre Band exit condition. Both modes evaluate the same CLOSED  |
//| bar (Phase 2's per-bar snapshot) — they differ only in the price     |
//| threshold: InpBBExitOnBreach=true is a "touch" (the bar's high/low   |
//| reached the middle band), =false requires the bar to actually       |
//| CLOSE beyond it (a stricter version of the same check). Per the      |
//| input's own name — "Exit on Breach, Not Just Close" — Breach/Close   |
//| are two candidate PRICE thresholds, not two different TIMINGS.       |
//|                                                                      |
//| FIX (see FORENSIC_COMPARISON_REPORT.md §5.1): this function          |
//| previously read the live, still-forming bar (shift 0) against live   |
//| bid/ask every tick, which let a transient intrabar excursion close    |
//| a sequence the reference implementation clearly did not close at     |
//| that moment (confirmed by trade-log comparison against the           |
//| benchmark — our old behavior exited intrabar at a non-bar-boundary   |
//| timestamp mid-sequence; the reference stayed in for four more days). |
//+------------------------------------------------------------------+
bool BBCentreExitConditionTick(bool isBuy)
  {
   if(!g_bbSnapshotValid) return(false);
   return(isBuy ? g_bar1High >= g_bbMiddle1 : g_bar1Low <= g_bbMiddle1);
  }

bool BBCentreExitConditionBar(bool isBuy)
  {
   if(!g_bbSnapshotValid) return(false);
   return(isBuy ? g_bar1Close >= g_bbMiddle1 : g_bar1Close <= g_bbMiddle1);
  }

//+------------------------------------------------------------------+
//| BB Opposite Band exit condition — always a live/per-tick breach of  |
//| the FAR band from the sequence's direction (a BUY sequence exits on |
//| the upper band, a SELL sequence on the lower band). The guide gives |
//| no separate breach-vs-close toggle for this strategy the way it     |
//| does for Centre Band, so it is always reactive.                     |
//+------------------------------------------------------------------+
bool BBOppositeExitCondition(bool isBuy)
  {
   if(g_bbHandle == INVALID_HANDLE) return(false);
   double up[1], low[1];
   if(CopyBuffer(g_bbHandle, 1, 0, 1, up) <= 0) return(false);
   if(CopyBuffer(g_bbHandle, 2, 0, 1, low) <= 0) return(false);
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return(isBuy ? price >= up[0] : price <= low[0]);
  }

//+------------------------------------------------------------------+
//| QQE 50 exit condition — always bar-close driven (QQE has no raw     |
//| price to "breach" the way BB does, and the guide offers no          |
//| breach-vs-close toggle for it). A BUY sequence (opened on oversold) |
//| exits once QQE has recovered back to/above 50; a SELL sequence      |
//| (opened on overbought) exits once QQE has dropped back to/below 50. |
//+------------------------------------------------------------------+
bool QQE50ExitConditionBar(bool isBuy)
  {
   if(!g_qqeSnapshotValid) return(false);
   return(isBuy ? g_qqeLine1 >= 50.0 : g_qqeLine1 <= 50.0);
  }

//+------------------------------------------------------------------+
//| Closes every open trade in a sequence and drops it from tracking.  |
//| Resets the re-entry-after-close gate for this direction so a fresh  |
//| BB touch / QQE extreme is required before the NEXT sequence in this |
//| direction can start (§5.3 item 5) — a no-op when neither            |
//| InpRequireBBBandTouchForReentry nor InpRequireQQEScenarioBForReentry |
//| is enabled, since ReentryReady() only ever reads this when at least |
//| one of them is on.                                                  |
//+------------------------------------------------------------------+
void CloseSequenceAndCleanup(bool isBuy, int idx, string reason)
  {
   long   sequenceId = isBuy ? g_buySequences[idx].sequenceId : g_sellSequences[idx].sequenceId;
   double realized   = GetSequenceProfitMoney(isBuy, idx);   // captured before closing — positions vanish after

   int count = isBuy ? g_buySequences[idx].count : g_sellSequences[idx].count;
   for(int i = 0; i < count; i++)
     {
      ulong ticket = isBuy ? g_buySequences[idx].tickets[i] : g_sellSequences[idx].tickets[i];
      if(PositionSelectByTicket(ticket))
        {
         if(!trade.PositionClose(ticket))
            Print("EA-DCA: failed to close ticket ", ticket, " while closing sequence — retcode ", trade.ResultRetcode());
        }
     }
   Print("EA-DCA: ", (isBuy ? "BUY" : "SELL"), " sequence closed (", count, " trade(s)) — ", reason);

   g_sessionRealizedProfit += realized;
   if(isBuy) g_reentryReadyBuy = false; else g_reentryReadySell = false;

   DrawSequenceEndLine(isBuy, sequenceId);
   DeleteSequenceChartObjects(isBuy, sequenceId);

   RemoveSequenceAt(isBuy, idx);
   SaveState();   // structural event — bypass the per-tick throttle (§15)
  }

//+------------------------------------------------------------------+
//| Manages an already-armed trailing stop (Dynamic Stop, or the        |
//| Partial-Close remainder stop — mutually exclusive by input/exit-    |
//| strategy validation, distinguished here by partialCloseDone).       |
//| Returns true if it closed the sequence (caller must stop touching   |
//| this index afterward — the array has shrunk).                       |
//|                                                                      |
//| Tightens the stop favorably ONLY, never loosens it — this is         |
//| exactly the kind of directionality bug flagged as a design trap in  |
//| the analysis report (§19 item 3); guarded against here by only ever |
//| overwriting trailStopPrice with a strictly-more-favorable value.     |
//+------------------------------------------------------------------+
bool ManageActiveTrailStop(bool isBuy, int idx)
  {
   bool active = isBuy ? g_buySequences[idx].trailStopActive : g_sellSequences[idx].trailStopActive;
   if(!active) return(false);

   double stopPrice = isBuy ? g_buySequences[idx].trailStopPrice : g_sellSequences[idx].trailStopPrice;
   double current    = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool hit = isBuy ? (current <= stopPrice) : (current >= stopPrice);
   if(hit)
     {
      CloseSequenceAndCleanup(isBuy, idx, "trailing/dynamic stop hit");
      return(true);
     }

   bool   partialDone = isBuy ? g_buySequences[idx].partialCloseDone : g_sellSequences[idx].partialCloseDone;
   double distance    = partialDone ? PipsToPrice(InpPartialCloseBreakevenStepPips) : PipsToPrice(InpDynamicStopDistancePips);

   if(distance > 0.0)   // 0 distance = a fixed one-shot breakeven stop, never re-trailed
     {
      double candidate = isBuy ? current - distance : current + distance;
      bool   improves   = isBuy ? (candidate > stopPrice) : (candidate < stopPrice);
      if(improves)
        {
         if(isBuy) g_buySequences[idx].trailStopPrice = candidate;
         else      g_sellSequences[idx].trailStopPrice = candidate;
        }
     }

   //--- Dynamic Stop only (§5.5): if profit falls back to <=0, remove the stop
   //--- entirely and resume normal signal-taking. The Partial-Close remainder
   //--- stop has no such release — once partially closed, it stays protective.
   if(!partialDone && GetSequenceProfitPips(isBuy, idx) <= 0.0)
     {
      if(isBuy) g_buySequences[idx].trailStopActive = false;
      else      g_sellSequences[idx].trailStopActive = false;
     }

   return(false);
  }

bool ArmDynamicStopIfDue(bool isBuy, int idx)
  {
   if(!InpUseDynamicStop) return(false);
   double current  = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double distance = PipsToPrice(InpDynamicStopDistancePips);
   double stop     = isBuy ? current - distance : current + distance;
   if(isBuy) { g_buySequences[idx].trailStopActive = true; g_buySequences[idx].trailStopPrice = stop; }
   else      { g_sellSequences[idx].trailStopActive = true; g_sellSequences[idx].trailStopPrice = stop; }
   return(true);
  }

//+------------------------------------------------------------------+
//| Arms the breakeven(+trailing) stop on a sequence's sole remaining   |
//| trade after Partial Close — InpPartialCloseBreakevenStepPips is the |
//| trailing distance behind price; 0 means a fixed stop pinned exactly |
//| at the average entry price (breakeven only, per the input's doc).  |
//+------------------------------------------------------------------+
void ArmBreakevenTrailingStop(bool isBuy, int idx)
  {
   double avg      = isBuy ? g_buySequences[idx].avgPrice : g_sellSequences[idx].avgPrice;
   double distance = PipsToPrice(InpPartialCloseBreakevenStepPips);
   double stop     = (distance > 0.0) ? (isBuy ? avg + distance : avg - distance) : avg;
   if(isBuy) { g_buySequences[idx].trailStopActive = true; g_buySequences[idx].trailStopPrice = stop; }
   else      { g_sellSequences[idx].trailStopActive = true; g_sellSequences[idx].trailStopPrice = stop; }
  }

//+------------------------------------------------------------------+
//| Executes Partial Close if it hasn't already run for this sequence.  |
//| >=2 trades: closes every trade but the most recent, then applies    |
//| InpPartialClosePercent to the survivor if set to 50%. Exactly 1     |
//| trade: nothing is physically closed — per the guide, a breakeven    |
//| stop is applied to it directly instead (§5.6). Both paths converge  |
//| on the same protective stop via ArmBreakevenTrailingStop().         |
//| Returns true if it took action (caller should not also arm a plain  |
//| Dynamic Stop or close outright on the same tick).                   |
//+------------------------------------------------------------------+
bool ExecutePartialCloseIfDue(bool isBuy, int idx)
  {
   if(!InpUsePartialClose) return(false);
   bool alreadyDone = isBuy ? g_buySequences[idx].partialCloseDone : g_sellSequences[idx].partialCloseDone;
   if(alreadyDone) return(false);

   int count = isBuy ? g_buySequences[idx].count : g_sellSequences[idx].count;
   double closedProfit = 0.0;

   if(count >= 2)
     {
      for(int i = 0; i < count - 1; i++)
        {
         ulong ticket = isBuy ? g_buySequences[idx].tickets[i] : g_sellSequences[idx].tickets[i];
         if(PositionSelectByTicket(ticket))
           {
            closedProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            trade.PositionClose(ticket);
           }
        }
      SyncSequenceFromLivePositions(isBuy, idx);   // re-sync tickets/count/avgPrice to the survivor

      int survivorCount = isBuy ? g_buySequences[idx].count : g_sellSequences[idx].count;
      if(InpPartialClosePercent == PARTIAL_CLOSE_50 && survivorCount > 0)
        {
         double remainingVol   = isBuy ? g_buySequences[idx].totalVolume : g_sellSequences[idx].totalVolume;
         ulong  remainingTicket = isBuy ? g_buySequences[idx].tickets[0] : g_sellSequences[idx].tickets[0];
         double reduceBy = NormalizeLot(remainingVol * 0.5);
         if(reduceBy > 0.0 && reduceBy < remainingVol && PositionSelectByTicket(remainingTicket))
           {
            //--- approximate: the realized share is proportional to the fraction of volume reduced
            double survivorProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            closedProfit += survivorProfit * (reduceBy / remainingVol);
            trade.PositionClosePartial(remainingTicket, reduceBy);
           }
         SyncSequenceFromLivePositions(isBuy, idx);
        }
     }

   g_sessionRealizedProfit += closedProfit;
   ArmBreakevenTrailingStop(isBuy, idx);
   if(isBuy) g_buySequences[idx].partialCloseDone = true;
   else      g_sellSequences[idx].partialCloseDone = true;

   Print("EA-DCA: ", (isBuy ? "BUY" : "SELL"), " sequence Partial Close executed.");
   SaveState();   // structural event — bypass the per-tick throttle (§15)
   return(true);
  }

//+------------------------------------------------------------------+
//| BB Centre Band and QQE 50 + Recovery share the same Dynamic Stop /  |
//| Partial Close / Recovery Mode machinery — they differ only in the   |
//| underlying exit-condition test. Recovery Mode (§5.7): once the      |
//| condition has fired while the sequence is below breakeven+buffer,   |
//| it stays "active" and is re-checked every tick regardless of the    |
//| condition's current state, until profit finally reaches the         |
//| buffer — matching the guide's "no time limit" framing for this.     |
//+------------------------------------------------------------------+
void HandleBBCentreOrQQE50(bool isBuy, int idx, bool isBBMode)
  {
   if(ManageActiveTrailStop(isBuy, idx)) return;

   bool conditionMet = isBBMode
                        ? (InpBBExitOnBreach ? BBCentreExitConditionTick(isBuy) : BBCentreExitConditionBar(isBuy))
                        : QQE50ExitConditionBar(isBuy);

   bool recoveryActive = isBuy ? g_buySequences[idx].recoveryModeActive : g_sellSequences[idx].recoveryModeActive;
   if(!conditionMet && !recoveryActive) return;

   bool atBreakeven = GetSequenceProfitPips(isBuy, idx) >= InpBreakevenBufferPips;
   if(!atBreakeven)
     {
      if(isBuy) g_buySequences[idx].recoveryModeActive = true;
      else      g_sellSequences[idx].recoveryModeActive = true;
      return;
     }

   if(!ExecutePartialCloseIfDue(isBuy, idx) && !ArmDynamicStopIfDue(isBuy, idx))
      CloseSequenceAndCleanup(isBuy, idx, isBBMode ? "BB centre band + breakeven" : "QQE 50 + breakeven");
  }

//+------------------------------------------------------------------+
//| BB Opposite Band. No Dynamic Stop / Partial Close (blocked at       |
//| OnInit). InpAlwaysCloseOnOppositeBand bypasses the breakeven/       |
//| Recovery gate entirely — an unconditional exit at that level even   |
//| at a loss; when false (default), it respects the same breakeven+   |
//| buffer / Recovery Mode logic as the other gated strategies (§5.7    |
//| explicitly lists BB Opposite Band as a Recovery-eligible strategy). |
//+------------------------------------------------------------------+
void HandleBBOpposite(bool isBuy, int idx)
  {
   bool conditionMet   = BBOppositeExitCondition(isBuy);
   bool recoveryActive = isBuy ? g_buySequences[idx].recoveryModeActive : g_sellSequences[idx].recoveryModeActive;
   if(!conditionMet && !recoveryActive) return;

   if(InpAlwaysCloseOnOppositeBand)
     {
      CloseSequenceAndCleanup(isBuy, idx, "BB opposite band (always-close)");
      return;
     }

   if(GetSequenceProfitPips(isBuy, idx) >= InpBreakevenBufferPips)
      CloseSequenceAndCleanup(isBuy, idx, "BB opposite band + breakeven");
   else if(isBuy) g_buySequences[idx].recoveryModeActive = true;
   else            g_sellSequences[idx].recoveryModeActive = true;
  }

void HandleFirstProfitable(bool isBuy, int idx)
  {
   if(GetSequenceProfitMoney(isBuy, idx) > 0.0)
      CloseSequenceAndCleanup(isBuy, idx, "first profitable close");
  }

//+------------------------------------------------------------------+
//| Fixed Profit Target — measured from the sequence's volume-weighted  |
//| average entry price (per the ENUM_FIXED_TARGET_TYPE comment).       |
//+------------------------------------------------------------------+
void HandleFixedTarget(bool isBuy, int idx)
  {
   bool hit = false;
   switch(InpFixedTargetType)
     {
      case TARGET_CURRENCY:
         hit = (GetSequenceProfitMoney(isBuy, idx) >= InpProfitTargetCurrency);
         break;
      case TARGET_PIPS:
         hit = (GetSequenceProfitPips(isBuy, idx) >= InpProfitTargetPips);
         break;
      case TARGET_ATR:
        {
         double atr = ATRValue();
         double target = atr * InpATRMultiplier;
         hit = (target > 0.0 && GetSequenceProfitPips(isBuy, idx) >= target / g_pipSize);
         break;
        }
     }
   if(hit)
      CloseSequenceAndCleanup(isBuy, idx, "fixed profit target");
  }

//+------------------------------------------------------------------+
//| Pure Trailing Stop — its own independent mechanism, unrelated to    |
//| the BB/QQE exit-condition logic above. Starts trailing once either  |
//| the pips-based or dollar-based start threshold fires (whichever     |
//| first, per the input block's own info note); InpTrailingStepBlockPips |
//| is the minimum favorable move required before the stop re-adjusts.  |
//+------------------------------------------------------------------+
void HandlePureTrailing(bool isBuy, int idx)
  {
   double current = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bool   active  = isBuy ? g_buySequences[idx].trailStopActive : g_sellSequences[idx].trailStopActive;

   if(active)
     {
      double stopPrice = isBuy ? g_buySequences[idx].trailStopPrice : g_sellSequences[idx].trailStopPrice;
      bool   hit = isBuy ? (current <= stopPrice) : (current >= stopPrice);
      if(hit)
        {
         CloseSequenceAndCleanup(isBuy, idx, "pure trailing stop hit");
         return;
        }

      double distance      = TrailingDistance();
      double blockDistance = PipsToPrice(InpTrailingStepBlockPips);
      double candidate     = isBuy ? current - distance : current + distance;
      bool   movedEnough   = isBuy ? (candidate - stopPrice >= blockDistance) : (stopPrice - candidate >= blockDistance);
      if(movedEnough)
        {
         if(isBuy) g_buySequences[idx].trailStopPrice = candidate;
         else      g_sellSequences[idx].trailStopPrice = candidate;
        }
      return;
     }

   double avg = isBuy ? g_buySequences[idx].avgPrice : g_sellSequences[idx].avgPrice;
   bool startByPips = false, startByDollars = false;

   bool pipsStartEnabled = InpUseATRForTrailingStart || (InpTrailingStartPips > 0);
   if(pipsStartEnabled)
     {
      double startDistance = InpUseATRForTrailingStart ? ATRValue() * InpTrailingStartATRMultiplier
                                                         : PipsToPrice(InpTrailingStartPips);
      double diff = isBuy ? (current - avg) : (avg - current);
      startByPips = (startDistance > 0.0 && diff >= startDistance);
     }
   if(InpTrailingStartDollars > 0.0)
      startByDollars = (GetSequenceProfitMoney(isBuy, idx) >= InpTrailingStartDollars);

   if(startByPips || startByDollars)
     {
      double distance = TrailingDistance();
      double stop     = isBuy ? current - distance : current + distance;
      if(isBuy) { g_buySequences[idx].trailStopActive = true; g_buySequences[idx].trailStopPrice = stop; }
      else      { g_sellSequences[idx].trailStopActive = true; g_sellSequences[idx].trailStopPrice = stop; }
     }
  }

//+------------------------------------------------------------------+
//| Per-sequence exit dispatcher. Risk Reduction (report §21) is an     |
//| independent safety net checked first, ahead of whatever the primary |
//| Exit Strategy is — ASSUMPTION (spec doesn't give exact behavior,    |
//| flagged to the stakeholder): once a sequence reaches                |
//| InpRiskReductionMinTrades trades, it closes outright as soon as     |
//| profit reaches InpRiskReductionBufferPips, regardless of the        |
//| primary Exit Strategy's own condition.                              |
//+------------------------------------------------------------------+
void CheckSequenceExitPerTick(bool isBuy, int idx)
  {
   if(InpUseRiskReduction)
     {
      int count = isBuy ? g_buySequences[idx].count : g_sellSequences[idx].count;
      if(count >= InpRiskReductionMinTrades && GetSequenceProfitPips(isBuy, idx) >= InpRiskReductionBufferPips)
        {
         CloseSequenceAndCleanup(isBuy, idx, "risk reduction");
         return;
        }
     }

   switch(InpExitStrategy)
     {
      case EXIT_BB_CENTRE_BAND:   HandleBBCentreOrQQE50(isBuy, idx, true);  break;
      case EXIT_BB_OPPOSITE_BAND: HandleBBOpposite(isBuy, idx);             break;
      case EXIT_QQE50_RECOVERY:   HandleBBCentreOrQQE50(isBuy, idx, false); break;
      case EXIT_FIRST_PROFITABLE: HandleFirstProfitable(isBuy, idx);       break;
      case EXIT_FIXED_TARGET:     HandleFixedTarget(isBuy, idx);           break;
      case EXIT_PURE_TRAILING:    HandlePureTrailing(isBuy, idx);          break;
     }
  }

//+------------------------------------------------------------------+
//| Runs every tick, before the entry pipeline. Iterates backwards      |
//| since CloseSequenceAndCleanup()/RemoveSequenceAt() shrink the array |
//| via swap-with-last.                                                 |
//+------------------------------------------------------------------+
void CheckExitsPerTick()
  {
   for(int i = ArraySize(g_buySequences) - 1; i >= 0; i--)
      CheckSequenceExitPerTick(true, i);
   for(int i = ArraySize(g_sellSequences) - 1; i >= 0; i--)
      CheckSequenceExitPerTick(false, i);
  }

//+====================================================================+
//| PHASE 4 (continued): state persistence — load side, session/EOD/    |
//| EOW gating, and the on-screen display. All three are called only    |
//| from OnInit()/OnTick() at the very end of the file, so unlike the   |
//| save-side persistence and session/time helpers front-loaded above   |
//| (needed by TryOpenNewSequence()/NewSequenceGatesPass()), these have |
//| no define-before-use constraint forcing them earlier.               |
//+====================================================================+

//+------------------------------------------------------------------+
//| Loads persisted state at startup. A missing file means a fresh      |
//| start, not an error. Every loaded sequence is immediately re-synced |
//| against live positions, since a position may have changed while     |
//| the EA was offline (manual close, broker stop-out). The read loop   |
//| is bounded by a sane maximum line count as a defensive measure      |
//| against a corrupted/mid-write-interrupted state file.               |
//+------------------------------------------------------------------+
void LoadState()
  {
   if(MQLInfoInteger(MQL_TESTER)) return;   // see the guard note on SaveState() above

   int handle = FileOpen(GetStateFilePath(), FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE) return;     // no prior state file — fresh start

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

      if(parts[0] == "GLOBAL" && n >= 17)
        {
         g_bbBuyArmed                  = (StringToInteger(parts[1])  != 0);
         g_bbSellArmed                 = (StringToInteger(parts[2])  != 0);
         g_qqeBuyArmed                 = (StringToInteger(parts[3])  != 0);
         g_qqeSellArmed                = (StringToInteger(parts[4])  != 0);
         g_reentryReadyBuy             = (StringToInteger(parts[5])  != 0);
         g_reentryReadySell            = (StringToInteger(parts[6])  != 0);
         g_pendingSignal               = (StringToInteger(parts[7])  != 0);
         g_pendingSignalIsBuy          = (StringToInteger(parts[8])  != 0);
         g_pendingSignalCentreBreached = (StringToInteger(parts[9])  != 0);
         g_sessionRealizedProfit       = StringToDouble(parts[10]);
         g_sessionDate                 = (datetime)StringToInteger(parts[11]);
         g_lastEODActionDate           = (datetime)StringToInteger(parts[12]);
         g_lastEOWActionDate           = (datetime)StringToInteger(parts[13]);
         g_nextSequenceId              = StringToInteger(parts[14]);
         g_centreCrossReadyBuy         = (StringToInteger(parts[15]) != 0);
         g_centreCrossReadySell        = (StringToInteger(parts[16]) != 0);
        }
      else if(parts[0] == "SEQ" && n >= 15)
        {
         bool isBuy = (parts[1] == "BUY");
         Sequence s;
         s.count              = (int)StringToInteger(parts[2]);
         s.avgPrice           = StringToDouble(parts[3]);
         s.totalVolume        = StringToDouble(parts[4]);
         s.lockedBaseLot      = StringToDouble(parts[5]);
         s.sequenceId         = (long)StringToInteger(parts[6]);
         s.startTime          = (datetime)StringToInteger(parts[7]);
         s.recoveryModeActive = (StringToInteger(parts[8])  != 0);
         s.trailStopActive    = (StringToInteger(parts[9])  != 0);
         s.trailStopPrice     = StringToDouble(parts[10]);
         s.partialCloseDone   = (StringToInteger(parts[11]) != 0);
         s.lastEntryTime      = (datetime)StringToInteger(parts[12]);
         s.lastEntryPrice     = StringToDouble(parts[13]);

         if(s.sequenceId >= g_nextSequenceId)
            g_nextSequenceId = s.sequenceId + 1;   // never reuse a loaded ID

         string ticketParts[];
         int tCount = (StringLen(parts[14]) > 0) ? StringSplit(parts[14], ';', ticketParts) : 0;
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

   for(int i = ArraySize(g_buySequences) - 1; i >= 0; i--)
     {
      SyncSequenceFromLivePositions(true, i);
      if(g_buySequences[i].count == 0) RemoveSequenceAt(true, i);
      else DrawSequenceStartLine(true, g_buySequences[i].sequenceId, g_buySequences[i].startTime);
     }
   for(int i = ArraySize(g_sellSequences) - 1; i >= 0; i--)
     {
      SyncSequenceFromLivePositions(false, i);
      if(g_sellSequences[i].count == 0) RemoveSequenceAt(false, i);
      else DrawSequenceStartLine(false, g_sellSequences[i].sequenceId, g_sellSequences[i].startTime);
     }
  }

//+------------------------------------------------------------------+
//| Session Profit Limit's rolling window (§21): resets whenever the    |
//| reference date rolls over to a new calendar day.                    |
//+------------------------------------------------------------------+
void UpdateSessionProfitTracking()
  {
   datetime today = CurrentReferenceDate();
   if(g_sessionDate != today)
     {
      g_sessionDate = today;
      g_sessionRealizedProfit = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| End of Day / End of Week actions. Triggers once per calendar day    |
//| (End of Week additionally requires the reference day to be Friday), |
//| the moment the reference time-of-day reaches the configured time —  |
//| guarded by g_lastEODActionDate/g_lastEOWActionDate so it fires only |
//| once even though this is checked every tick.                        |
//+------------------------------------------------------------------+
void ApplyEoxToSequence(bool isBuy, int idx, ENUM_EOX_ACTION action, string label)
  {
   double profit = GetSequenceProfitMoney(isBuy, idx);
   bool shouldClose = false;
   switch(action)
     {
      case EOX_CLOSE_IF_PROFITABLE: shouldClose = (profit > 0.0);  break;
      case EOX_CLOSE_IF_LOSING:     shouldClose = (profit <= 0.0); break;
      case EOX_CLOSE_ALL:           shouldClose = true;            break;
      default:                      shouldClose = false;           break;
     }
   if(shouldClose)
      CloseSequenceAndCleanup(isBuy, idx, label);
  }

void ApplyEndOfPeriodAction(ENUM_EOX_ACTION action, string label)
  {
   if(action == EOX_DO_NOTHING) return;
   for(int i = ArraySize(g_buySequences) - 1; i >= 0; i--)
      ApplyEoxToSequence(true, i, action, label);
   for(int i = ArraySize(g_sellSequences) - 1; i >= 0; i--)
      ApplyEoxToSequence(false, i, action, label);
  }

void CheckEndOfDayAndWeek()
  {
   int      nowSec = CurrentReferenceTimeOfDaySeconds();
   datetime today  = CurrentReferenceDate();

   if(InpUseEOD)
     {
      int eodSec;
      if(ParseHHMM(InpEODTime, eodSec) && nowSec >= eodSec && g_lastEODActionDate != today)
        {
         ApplyEndOfPeriodAction(InpEODAction, "end of day");
         g_lastEODActionDate = today;
        }
     }

   if(InpUseEOW)
     {
      int eowSec;
      if(CurrentReferenceDayOfWeek() == 5 && ParseHHMM(InpEOWTime, eowSec) &&
         nowSec >= eowSec && g_lastEOWActionDate != today)
        {
         ApplyEndOfPeriodAction(InpEOWAction, "end of week");
         g_lastEOWActionDate = today;
        }
     }
  }

//+------------------------------------------------------------------+
//| On-screen display: per-sequence lines + the info panel.             |
//+------------------------------------------------------------------+
void CreateOrUpdateLabel(string name, int x, int y, string text, color clr, int fontSize)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

void CreateOrUpdateRectangle(string name, int x, int y, int w, int h, color bg, color border)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
     }
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
  }

//+------------------------------------------------------------------+
//| Draws/updates the Trail, Breakeven, Breakeven-Buffer, and Risk       |
//| Reduction lines for one open sequence, per each line's own show/     |
//| hide toggle — deletes the object when its toggle is off or the       |
//| underlying condition (e.g. an active trail) doesn't currently apply. |
//+------------------------------------------------------------------+
void UpdateSequenceLines(bool isBuy, int idx)
  {
   long   sequenceId  = isBuy ? g_buySequences[idx].sequenceId    : g_sellSequences[idx].sequenceId;
   double avg         = isBuy ? g_buySequences[idx].avgPrice      : g_sellSequences[idx].avgPrice;
   bool   trailActive = isBuy ? g_buySequences[idx].trailStopActive : g_sellSequences[idx].trailStopActive;
   double trailPrice  = isBuy ? g_buySequences[idx].trailStopPrice  : g_sellSequences[idx].trailStopPrice;
   int    count       = isBuy ? g_buySequences[idx].count          : g_sellSequences[idx].count;

   string trailName = SeqObjName("Trail", isBuy, sequenceId);
   if(InpShowTrailingStops && trailActive)
      DrawOrUpdateHLine(trailName, trailPrice, isBuy ? InpBuyTrailingColor : InpSellTrailingColor,
                        InpTrailingLineStyle, InpTrailingLineWidth);
   else
      DeleteObjectIfExists(trailName);

   string beName = SeqObjName("BE", isBuy, sequenceId);
   if(InpShowBreakevenLine)
      DrawOrUpdateHLine(beName, avg, InpBreakevenLineColor, STYLE_SOLID, 1);
   else
      DeleteObjectIfExists(beName);

   string beBufName = SeqObjName("BEBuf", isBuy, sequenceId);
   if(InpShowBreakevenBufferLine)
     {
      double bufPrice = isBuy ? avg + PipsToPrice(InpBreakevenBufferPips) : avg - PipsToPrice(InpBreakevenBufferPips);
      DrawOrUpdateHLine(beBufName, bufPrice, InpBreakevenBufferColor, STYLE_DOT, 1);
     }
   else
      DeleteObjectIfExists(beBufName);

   string riskName = SeqObjName("RiskRed", isBuy, sequenceId);
   if(InpShowRiskReductionLine && InpUseRiskReduction && count >= InpRiskReductionMinTrades)
     {
      double riskPrice = isBuy ? avg + PipsToPrice(InpRiskReductionBufferPips) : avg - PipsToPrice(InpRiskReductionBufferPips);
      DrawOrUpdateHLine(riskName, riskPrice, InpRiskReductionColor, STYLE_DASHDOT, 1);
     }
   else
      DeleteObjectIfExists(riskName);
  }

//+------------------------------------------------------------------+
//| Take-Profit line — Fixed Target strategy, Pips/ATR modes only, per  |
//| the input's own doc comment (not shown in Currency mode). This is   |
//| the exact feature flagged as missing in the removed draft's review  |
//| (§16 finding 1); implemented here from the start.                    |
//+------------------------------------------------------------------+
void UpdateTakeProfitLine(bool isBuy, int idx)
  {
   long   sequenceId = isBuy ? g_buySequences[idx].sequenceId : g_sellSequences[idx].sequenceId;
   string tpName     = SeqObjName("TP", isBuy, sequenceId);

   bool showable = InpShowTakeProfitLine && InpExitStrategy == EXIT_FIXED_TARGET && InpFixedTargetType != TARGET_CURRENCY;
   if(!showable)
     {
      DeleteObjectIfExists(tpName);
      return;
     }

   double avg = isBuy ? g_buySequences[idx].avgPrice : g_sellSequences[idx].avgPrice;
   double targetPips = (InpFixedTargetType == TARGET_PIPS)
                        ? InpProfitTargetPips
                        : (g_pipSize > 0.0 ? (ATRValue() * InpATRMultiplier) / g_pipSize : 0.0);
   double price = isBuy ? avg + PipsToPrice(targetPips) : avg - PipsToPrice(targetPips);
   DrawOrUpdateHLine(tpName, price, InpTakeProfitLineColor, STYLE_SOLID, 1);
  }

//+------------------------------------------------------------------+
//| Info panel: EA name/symbol header, open sequence counts, floating   |
//| P/L (colour-coded), and the current session's realized profit.      |
//|                                                                      |
//| FIX: OBJ_LABEL does not render embedded "\n" as multiple lines — a   |
//| single label's OBJPROP_TEXT is always shown as one line, so the      |
//| previous three-line body collapsed/garbled. Each line is now its     |
//| own label object at its own Y offset. Also wires up InpPanelInfoColor|
//| (declared since Phase 1, never actually used until now) for the      |
//| neutral lines, reserving Profit/Loss colour for the P/L line only.  |
//+------------------------------------------------------------------+
#define PANEL_BG_NAME     (EA_DCA_OBJ_PREFIX + "PanelBg")
#define PANEL_HEADER_NAME (EA_DCA_OBJ_PREFIX + "PanelHeader")
#define PANEL_LINE1_NAME  (EA_DCA_OBJ_PREFIX + "PanelLine1")
#define PANEL_LINE2_NAME  (EA_DCA_OBJ_PREFIX + "PanelLine2")
#define PANEL_LINE3_NAME  (EA_DCA_OBJ_PREFIX + "PanelLine3")
#define PANEL_LINE_HEIGHT 16

void DeleteInfoPanelObjects()
  {
   DeleteObjectIfExists(PANEL_BG_NAME);
   DeleteObjectIfExists(PANEL_HEADER_NAME);
   DeleteObjectIfExists(PANEL_LINE1_NAME);
   DeleteObjectIfExists(PANEL_LINE2_NAME);
   DeleteObjectIfExists(PANEL_LINE3_NAME);
  }

void UpdateInfoPanel()
  {
   if(!InpShowDisplayPanel)
     {
      DeleteInfoPanelObjects();
      return;
     }

   double totalFloating = 0.0;
   for(int i = 0; i < ArraySize(g_buySequences); i++)  totalFloating += GetSequenceProfitMoney(true, i);
   for(int i = 0; i < ArraySize(g_sellSequences); i++) totalFloating += GetSequenceProfitMoney(false, i);

   string header = StringFormat("EA-DCA - %s", _Symbol);
   string line1  = StringFormat("Buy seq: %d   Sell seq: %d", ArraySize(g_buySequences), ArraySize(g_sellSequences));
   string line2  = StringFormat("Floating P/L: %.2f", totalFloating);
   string line3  = StringFormat("Session realized: %.2f", g_sessionRealizedProfit);
   color  plColor = (totalFloating >= 0.0) ? InpPanelProfitColor : InpPanelLossColor;

   CreateOrUpdateRectangle(PANEL_BG_NAME, InpPanelX - 6, InpPanelY - 4, 220, PANEL_LINE_HEIGHT * 4 + 8,
                            InpPanelBgColor, InpPanelBorderColor);
   CreateOrUpdateLabel(PANEL_HEADER_NAME, InpPanelX, InpPanelY,                          header, InpPanelHeaderColor, 10);
   CreateOrUpdateLabel(PANEL_LINE1_NAME,  InpPanelX, InpPanelY + PANEL_LINE_HEIGHT,       line1,  InpPanelInfoColor,   9);
   CreateOrUpdateLabel(PANEL_LINE2_NAME,  InpPanelX, InpPanelY + PANEL_LINE_HEIGHT * 2,   line2,  plColor,             9);
   CreateOrUpdateLabel(PANEL_LINE3_NAME,  InpPanelX, InpPanelY + PANEL_LINE_HEIGHT * 3,   line3,  InpPanelInfoColor,   9);
  }

void UpdateChartDisplay()
  {
   for(int i = 0; i < ArraySize(g_buySequences); i++)
     {
      UpdateSequenceLines(true, i);
      UpdateTakeProfitLine(true, i);
     }
   for(int i = 0; i < ArraySize(g_sellSequences); i++)
     {
      UpdateSequenceLines(false, i);
      UpdateTakeProfitLine(false, i);
     }
   UpdateInfoPanel();
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!CheckAlgoTradingAllowed())
      return(INIT_FAILED);

   if(!CheckMagicNumberCollision())
      return(INIT_FAILED);

   if(!ValidateExitStrategyCompatibility())
     {
      ReleaseMagicNumberLock();
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(!ValidateCustomMultiplierString())
     {
      ReleaseMagicNumberLock();
      return(INIT_PARAMETERS_INCORRECT);
     }
   BuildMultiplierSequence();

   CheckHedgingAccount();   // soft warning only — does not block initialization

//--- pip size: 10x point on a 3/5-digit (fractional-pip) broker, 1x otherwise
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      g_pipSize *= 10.0;

   if(!CreateIndicatorHandles())
     {
      ReleaseIndicatorHandles();
      ReleaseMagicNumberLock();
      return(INIT_FAILED);
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   g_sessionDate = CurrentReferenceDate();   // seed today's date so the first tick doesn't
                                              // spuriously look like a day rollover
   InitializeZoneLatchesFromHistory();       // §5.3 — overwritten below if a state file exists
   LoadState();

   Print("EA-DCA: initialized on ", _Symbol, " (Magic ", InpMagicNumber, "). "
         "This EA does not place a fixed stop-loss — risk is controlled entirely by lot sizing, "
         "sequence caps, and the chosen exit strategy. Read the User Guide before running live.");

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function. Saves state unconditionally      |
//| (bypassing the throttle) and removes the "live" per-sequence lines |
//| and info panel — the Sequence Start/End markers are deliberately   |
//| left in place as a historical record (see DrawSequenceStartLine/   |
//| DrawSequenceEndLine).                                               |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   SaveState();

   for(int i = 0; i < ArraySize(g_buySequences); i++)
      DeleteSequenceChartObjects(true, g_buySequences[i].sequenceId);
   for(int i = 0; i < ArraySize(g_sellSequences); i++)
      DeleteSequenceChartObjects(false, g_sellSequences[i].sequenceId);
   DeleteInfoPanelObjects();

   ReleaseIndicatorHandles();
   ReleaseMagicNumberLock();
  }

//+------------------------------------------------------------------+
//| Expert tick function.                                              |
//| Order: session bookkeeping -> EOD/EOW (may close sequences) ->      |
//| exits (price-level triggers need every-tick reaction) -> bar-close  |
//| entries (QMP does not repaint, so signal detection only makes       |
//| sense once a bar is final) -> chart display -> throttled state      |
//| save. Structural events (entry, close, partial close) save state    |
//| directly, bypassing the throttle — see SaveStateThrottled().        |
//+------------------------------------------------------------------+
void OnTick()
  {
   UpdateSessionProfitTracking();
   CheckEndOfDayAndWeek();
   CheckExitsPerTick();
   if(IsNewBar())
      ProcessNewBar();
   UpdateChartDisplay();
   SaveStateThrottled();
  }
//+------------------------------------------------------------------+
