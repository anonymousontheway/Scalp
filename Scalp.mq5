#property strict
#property version   "0.100"
#property description "Scalp ICT baseline EA - Strategy Tester prototype; validate before live use."

#include <Trade/Trade.mqh>
CTrade trade;

input string InpTradeSymbol = "XAUUSDb"; // Must exactly match this broker symbol
input ulong InpMagic = 26101701;
input double InpInitialAccountBalance = 0.0; // Set explicitly before testing; zero blocks entries
input double InpRiskPercent = 0.50;
input double InpRecoveryRiskPercent = 0.25;
input double InpMaxOpenRiskPercent = 2.0;
input double InpDailyLossLimitPercent = 2.0;
input double InpDailyProfitLimitPercent = 2.0;
input int InpMaxEntriesPerDay = 3;
input int InpPivotLeftRight = 2;
input int InpSwingLookback = 120;
input int InpSetupExpiryM15Bars = 16;
input int InpMaxSpreadPoints = 0; // 0 = disabled; use dynamic filter below if enabled
input bool InpUseDynamicSpreadFilter = false;
input int InpSpreadAverageMinutes = 60;
input double InpSpreadMultiplier = 1.5;
input bool InpUseSessionFilter = true;
input bool InpForceLondonCloseExit = true;
input bool InpUseNewsFilter = false; // News calendar feed is not implemented in this prototype
input int InpDeviationPoints = 30;
input bool InpAllowTrading = true;

enum SetupState { ST_IDLE=0, ST_WAIT_MSS=1, ST_WAIT_FVG=2, ST_WAIT_RETRACE=3 };
int g_state=ST_IDLE;
int g_sweepDir=0;
double g_sweepExtreme=0.0;
double g_mssLevel=0.0;
datetime g_sweepTime=0;
datetime g_setupTime=0;
datetime g_fvgTime=0;
double g_fvgLow=0.0, g_fvgHigh=0.0;
datetime g_lastM15Bar=0, g_lastM1Bar=0;
double g_prevAsk=0.0, g_prevBid=0.0;
datetime g_lastSpreadSample=0;
double g_spreadSamples[60];
int g_spreadCount=0, g_spreadIndex=0;
double g_dailyStartBalance=0.0;
int g_dayKey=-1;
int g_entriesToday=0;
bool g_lockOwned=false;
string g_lockName="";
int g_bias=0;

string GVPrefix()
{
   return StringFormat("Scalp_%I64d_%s_%I64u_", AccountInfoInteger(ACCOUNT_LOGIN), InpTradeSymbol, InpMagic);
}
int DateKey(datetime t)
{
   MqlDateTime d; TimeToStruct(t,d);
   return d.year*10000+d.mon*100+d.day;
}
datetime DayStart(datetime t)
{
   MqlDateTime d; TimeToStruct(t,d); d.hour=0; d.min=0; d.sec=0;
   return StructToTime(d);
}
double NormalizePrice(double p)
{
   double tick=SymbolInfoDouble(InpTradeSymbol,SYMBOL_TRADE_TICK_SIZE);
   int digits=(int)SymbolInfoInteger(InpTradeSymbol,SYMBOL_DIGITS);
   if(tick>0) p=MathRound(p/tick)*tick;
   return NormalizeDouble(p,digits);
}
bool IsPivotHigh(ENUM_TIMEFRAMES tf,int shift)
{
   if(shift<InpPivotLeftRight+1) return false;
   double h=iHigh(InpTradeSymbol,tf,shift);
   if(h<=0) return false;
   for(int j=1;j<=InpPivotLeftRight;j++)
      if(h<=iHigh(InpTradeSymbol,tf,shift-j) || h<=iHigh(InpTradeSymbol,tf,shift+j)) return false;
   return true;
}
bool IsPivotLow(ENUM_TIMEFRAMES tf,int shift)
{
   if(shift<InpPivotLeftRight+1) return false;
   double l=iLow(InpTradeSymbol,tf,shift);
   if(l<=0) return false;
   for(int j=1;j<=InpPivotLeftRight;j++)
      if(l>=iLow(InpTradeSymbol,tf,shift-j) || l>=iLow(InpTradeSymbol,tf,shift+j)) return false;
   return true;
}
bool LastPivot(ENUM_TIMEFRAMES tf,bool highPivot,double &price,int &pivotShift,int fromShift=3)
{
   int bars=Bars(InpTradeSymbol,tf);
   int maxShift=MathMin(InpSwingLookback,bars-InpPivotLeftRight-1);
   for(int s=MathMax(fromShift,InpPivotLeftRight+1);s<=maxShift;s++)
   {
      bool ok=highPivot?IsPivotHigh(tf,s):IsPivotLow(tf,s);
      if(ok) { price=highPivot?iHigh(InpTradeSymbol,tf,s):iLow(InpTradeSymbol,tf,s); pivotShift=s; return true; }
   }
   return false;
}
int Get4HBias()
{
   // Use the most recent confirmed close-through of a previously confirmed swing.
   int bars=Bars(InpTradeSymbol,PERIOD_H4);
   int maxBar=MathMin(80,bars-5);
   for(int b=1;b<=maxBar;b++)
   {
      double c=iClose(InpTradeSymbol,PERIOD_H4,b), prev=iClose(InpTradeSymbol,PERIOD_H4,b+1);
      for(int s=b+InpPivotLeftRight+1;s<=MathMin(b+40,bars-InpPivotLeftRight-1);s++)
      {
         if(IsPivotHigh(PERIOD_H4,s))
         {
            double p=iHigh(InpTradeSymbol,PERIOD_H4,s);
            if(c>p && prev<=p) return 1;
         }
         if(IsPivotLow(PERIOD_H4,s))
         {
            double p=iLow(InpTradeSymbol,PERIOD_H4,s);
            if(c<p && prev>=p) return -1;
         }
      }
   }
   // If no recent break is found, use the last closed candle relative to latest swings.
   double ph,pl; int sh,sl;
   bool hasH=LastPivot(PERIOD_H4,true,ph,sh), hasL=LastPivot(PERIOD_H4,false,pl,sl);
   double close1=iClose(InpTradeSymbol,PERIOD_H4,1);
   if(hasH && close1>ph) return 1;
   if(hasL && close1<pl) return -1;
   return 0;
}
bool GetTarget(int dir,double &target)
{
   double bid=SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID);
   double ask=SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK);
   double px=(dir>0?ask:bid), best=0.0, bestDist=DBL_MAX;
   int bars=Bars(InpTradeSymbol,PERIOD_H4);
   int maxShift=MathMin(InpSwingLookback,bars-InpPivotLeftRight-1);
   for(int s=InpPivotLeftRight+1;s<=maxShift;s++)
   {
      if(dir>0 && IsPivotHigh(PERIOD_H4,s))
      {
         double p=iHigh(InpTradeSymbol,PERIOD_H4,s);
         if(p>px && p-px<bestDist) { best=p; bestDist=p-px; }
      }
      if(dir<0 && IsPivotLow(PERIOD_H4,s))
      {
         double p=iLow(InpTradeSymbol,PERIOD_H4,s);
         if(p<px && px-p<bestDist) { best=p; bestDist=px-p; }
      }
   }
   if(best==0.0) return false;
   target=NormalizePrice(best); return true;
}
double CurrentSpreadPoints()
{
   double a=SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK), b=SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID);
   double pt=SymbolInfoDouble(InpTradeSymbol,SYMBOL_POINT);
   if(pt<=0) return DBL_MAX;
   return (a-b)/pt;
}
void UpdateSpreadSamples()
{
   datetime now=TimeCurrent();
   if(g_lastSpreadSample==0 || now-g_lastSpreadSample>=60)
   {
      g_spreadSamples[g_spreadIndex]=CurrentSpreadPoints();
      g_spreadIndex=(g_spreadIndex+1)%60;
      if(g_spreadCount<60) g_spreadCount++;
      g_lastSpreadSample=now;
   }
}
bool SpreadAllowed()
{
   double sp=CurrentSpreadPoints();
   if(InpMaxSpreadPoints>0 && sp>InpMaxSpreadPoints) return false;
   if(InpUseDynamicSpreadFilter)
   {
      if(g_spreadCount<MathMax(2,InpSpreadAverageMinutes)) return false;
      double sum=0;
      for(int i=0;i<g_spreadCount;i++) sum+=g_spreadSamples[i];
      double avg=sum/g_spreadCount;
      if(avg<=0 || sp>avg*InpSpreadMultiplier) return false;
   }
   return true;
}
int NthSunday(int year,int month,int nth)
{
   MqlDateTime d; ZeroMemory(d); d.year=year; d.mon=month; d.day=1;
   datetime t=StructToTime(d); TimeToStruct(t,d);
   int firstSunday=(d.day_of_week==0?1:8-d.day_of_week);
   return firstSunday+(nth-1)*7;
}
bool IsNewYorkDST(datetime utc)
{
   MqlDateTime u; TimeToStruct(utc,u);
   int startDay=NthSunday(u.year,3,2), endDay=NthSunday(u.year,11,1);
   MqlDateTime ds; ZeroMemory(ds); ds.year=u.year; ds.mon=3; ds.day=startDay; ds.hour=7;
   datetime start=StructToTime(ds);
   MqlDateTime de; ZeroMemory(de); de.year=u.year; de.mon=11; de.day=endDay; de.hour=6;
   datetime finish=StructToTime(de);
   return utc>=start && utc<finish;
}
datetime NewYorkNow()
{
   datetime utc=TimeGMT();
   return utc+(IsNewYorkDST(utc)?-4:-5)*3600;
}
bool InEntrySession()
{
   if(!InpUseSessionFilter) return true;
   MqlDateTime n; TimeToStruct(NewYorkNow(),n);
   int m=n.hour*60+n.min;
   bool asia=(m>=20*60);
   bool london=(m>=2*60 && m<5*60);
   bool ny=(m>=8*60+30 && m<10*60);
   return asia||london||ny;
}
bool IsLondonCloseOrLater()
{
   MqlDateTime n; TimeToStruct(NewYorkNow(),n);
   return n.hour>12 || (n.hour==12 && n.min>=0);
}
bool IsNewBar(ENUM_TIMEFRAMES tf,datetime &last)
{
   datetime t=iTime(InpTradeSymbol,tf,0);
   if(t==0 || t==last) return false;
   last=t; return true;
}
bool SelectOurPosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   if(PositionGetString(POSITION_SYMBOL)!=InpTradeSymbol) return false;
   if((ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic) return false;
   return true;
}
int OurPositionCount()
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket>0 && SelectOurPosition(ticket)) n++;
   }
   return n;
}
double OpenRiskMoney()
{
   double total=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !SelectOurPosition(ticket)) continue;
      double entry=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL), vol=PositionGetDouble(POSITION_VOLUME);
      if(sl<=0) return DBL_MAX;
      ENUM_ORDER_TYPE type=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
      double result=0;
      if(!OrderCalcProfit(type,InpTradeSymbol,vol,entry,sl,result)) return DBL_MAX;
      total+=MathAbs(result);
   }
   return total;
}
double DailyRealizedPnl()
{
   if(!HistorySelect(DayStart(TimeCurrent()),TimeCurrent())) return 0;
   double pnl=0;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0) continue;
      if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic) continue;
      if(HistoryDealGetString(deal,DEAL_SYMBOL)!=InpTradeSymbol) continue;
      pnl+=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_COMMISSION)+HistoryDealGetDouble(deal,DEAL_SWAP);
   }
   return pnl;
}
int CountEntriesToday()
{
   if(!HistorySelect(DayStart(TimeCurrent()),TimeCurrent())) return 0;
   int n=0;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0) continue;
      if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic) continue;
      if(HistoryDealGetString(deal,DEAL_SYMBOL)!=InpTradeSymbol) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(e==DEAL_ENTRY_IN || e==DEAL_ENTRY_INOUT) n++;
   }
   return n;
}
void RefreshDailyState()
{
   int key=DateKey(TimeCurrent());
   string dayVar=GVPrefix()+"day";
   string balVar=GVPrefix()+"daybal";
   if(key!=g_dayKey)
   {
      g_dayKey=key;
      if(GlobalVariableCheck(dayVar) && (int)GlobalVariableGet(dayVar)==key && GlobalVariableCheck(balVar))
         g_dailyStartBalance=GlobalVariableGet(balVar);
      else
      {
         g_dailyStartBalance=AccountInfoDouble(ACCOUNT_BALANCE);
         GlobalVariableSet(dayVar,key);
         GlobalVariableSet(balVar,g_dailyStartBalance);
      }
      g_entriesToday=CountEntriesToday();
   }
   else g_entriesToday=CountEntriesToday();
}
bool DailyLimitsAllowEntry()
{
   if(g_dailyStartBalance<=0) return false;
   double pnl=DailyRealizedPnl();
   if(pnl<=-g_dailyStartBalance*InpDailyLossLimitPercent/100.0) return false;
   if(pnl>=g_dailyStartBalance*InpDailyProfitLimitPercent/100.0) return false;
   if(g_entriesToday>=InpMaxEntriesPerDay) return false;
   return true;
}
bool CloseAllOurPositions()
{
   bool allClosed=true;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !SelectOurPosition(ticket)) continue;
      if(!trade.PositionClose(ticket,InpDeviationPoints)) allClosed=false;
   }
   return allClosed && OurPositionCount()==0;
}
void ManageForcedExits()
{
   double pnl=DailyRealizedPnl();
   bool dailyLoss=(g_dailyStartBalance>0 && pnl<=-g_dailyStartBalance*InpDailyLossLimitPercent/100.0);
   if(dailyLoss || (InpForceLondonCloseExit && IsLondonCloseOrLater()))
      CloseAllOurPositions();
   // Close all Scalp positions when any Scalp position's own 4H-target TP is touched.
   double bid=SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID), ask=SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK);
   bool targetTouched=false;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !SelectOurPosition(ticket)) continue;
      double tp=PositionGetDouble(POSITION_TP);
      if(tp<=0) continue;
      ENUM_POSITION_TYPE pt=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if((pt==POSITION_TYPE_BUY && bid>=tp) || (pt==POSITION_TYPE_SELL && ask<=tp))
      {
         targetTouched=true;
         break;
      }
   }
   if(targetTouched) CloseAllOurPositions();
}
bool AdjustStops(int dir,double entry,double &sl,double &tp)
{
   double point=SymbolInfoDouble(InpTradeSymbol,SYMBOL_POINT);
   int stops=(int)SymbolInfoInteger(InpTradeSymbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDist=MathMax(point,(stops+1)*point);
   if(dir>0 && sl>entry-minDist) sl=entry-minDist;
   if(dir<0 && sl<entry+minDist) sl=entry+minDist;
   sl=NormalizePrice(sl); tp=NormalizePrice(tp);
   if(dir>0 && (sl>=entry || tp<=entry)) return false;
   if(dir<0 && (sl<=entry || tp>=entry)) return false;
   return true;
}
double NormalizeVolume(double vol)
{
   double minV=SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MIN);
   double maxV=SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(InpTradeSymbol,SYMBOL_VOLUME_STEP);
   if(step<=0) return 0;
   vol=MathMin(maxV,vol);
   vol=MathFloor(vol/step+1e-8)*step;
   if(vol<minV) return 0;
   return NormalizeDouble(vol,8);
}
double VolumeForRisk(int dir,double entry,double sl,double riskMoney)
{
   double oneLot=0;
   ENUM_ORDER_TYPE type=(dir>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(type,InpTradeSymbol,1.0,entry,sl,oneLot)) return 0;
   double loss=MathAbs(oneLot);
   if(loss<=0) return 0;
   return NormalizeVolume(riskMoney/loss);
}
bool RiskAllowsAndSend(int dir,double sweepExtreme,double target)
{
   if(!InpAllowTrading || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)) return false;
   if(InpInitialAccountBalance<=0) { Print("Scalp: set InpInitialAccountBalance explicitly before entries."); return false; }
   if(!SpreadAllowed() || !InEntrySession() || !DailyLimitsAllowEntry()) return false;
   if(g_bias==0 || dir!=g_bias) return false;
   double bid=SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID), ask=SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK);
   double entry=(dir>0?ask:bid);
   double spread=(ask-bid);
   double sl=(dir>0?sweepExtreme-2.0*spread:sweepExtreme+2.0*spread);
   double tp=target;
   if(!AdjustStops(dir,entry,sl,tp)) return false;
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double normalRisk=(bal<InpInitialAccountBalance?InpRecoveryRiskPercent:InpRiskPercent);
   double maxOpen=bal*InpMaxOpenRiskPercent/100.0;
   double openRisk=OpenRiskMoney();
   if(openRisk==DBL_MAX || openRisk>=maxOpen) return false;
   double remaining=maxOpen-openRisk;
   double desired=bal*normalRisk/100.0;
   double riskMoney=MathMin(desired,remaining);
   if(riskMoney<=0) return false;
   double vol=VolumeForRisk(dir,entry,sl,riskMoney);
   if(vol<=0) return false;
   double oneLot=0;
   if(!OrderCalcProfit(dir>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,InpTradeSymbol,vol,entry,sl,oneLot)) return false;
   if(MathAbs(oneLot)>remaining+0.01) return false;
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpDeviationPoints);
   trade.SetTypeFillingBySymbol(InpTradeSymbol);
   bool ok=(dir>0?trade.Buy(vol,InpTradeSymbol,0,sl,tp,"Scalp ICT baseline"):trade.Sell(vol,InpTradeSymbol,0,sl,tp,"Scalp ICT baseline"));
   uint rc=trade.ResultRetcode();
   if(!ok || (rc!=TRADE_RETCODE_DONE && rc!=TRADE_RETCODE_DONE_PARTIAL && rc!=TRADE_RETCODE_PLACED))
   {
      PrintFormat("Scalp order failed retcode=%u %s",rc,trade.ResultRetcodeDescription());
      return false;
   }
   g_entriesToday=CountEntriesToday();
   g_state=ST_IDLE;
   g_sweepDir=0; g_setupTime=0; g_fvgTime=0;
   PrintFormat("Scalp entry sent dir=%d volume=%.2f entry~%.3f SL=%.3f TP=%.3f",dir,vol,entry,sl,tp);
   return true;
}
void ProcessM15()
{
   datetime barTime=iTime(InpTradeSymbol,PERIOD_M15,1);
   if(barTime==0) return;
   if(g_state==ST_WAIT_MSS && g_sweepTime>0)
   {
      int barsSince=iBarShift(InpTradeSymbol,PERIOD_M15,g_sweepTime,false);
      if(barsSince<0 || barsSince>InpSetupExpiryM15Bars) { g_state=ST_IDLE; g_sweepDir=0; }
      else if(barTime>g_sweepTime)
      {
         double close1=iClose(InpTradeSymbol,PERIOD_M15,1);
         if((g_sweepDir>0 && close1>g_mssLevel) || (g_sweepDir<0 && close1<g_mssLevel))
         {
            g_setupTime=barTime; g_state=ST_WAIT_FVG;
            Print("Scalp: 15M MSS confirmed.");
            return;
         }
      }
   }
   if(g_state!=ST_IDLE) return;
   double ph,pl; int sh,sl;
   bool hasH=LastPivot(PERIOD_M15,true,ph,sh), hasL=LastPivot(PERIOD_M15,false,pl,sl);
   if(!hasH || !hasL) return;
   double hi=iHigh(InpTradeSymbol,PERIOD_M15,1), lo=iLow(InpTradeSymbol,PERIOD_M15,1), cl=iClose(InpTradeSymbol,PERIOD_M15,1);
   if(lo<pl && cl>pl)
   {
      g_sweepDir=1; g_sweepExtreme=lo; g_mssLevel=ph; g_sweepTime=barTime; g_state=ST_WAIT_MSS;
      Print("Scalp: bullish 15M liquidity sweep.");
   }
   else if(hi>ph && cl<ph)
   {
      g_sweepDir=-1; g_sweepExtreme=hi; g_mssLevel=pl; g_sweepTime=barTime; g_state=ST_WAIT_MSS;
      Print("Scalp: bearish 15M liquidity sweep.");
   }
}
void ProcessM1()
{
   if(g_state!=ST_WAIT_FVG && g_state!=ST_WAIT_RETRACE) return;
   if(g_state==ST_WAIT_FVG)
   {
      datetime t=iTime(InpTradeSymbol,PERIOD_M1,1);
      if(t<=g_setupTime) return;
      double h1=iHigh(InpTradeSymbol,PERIOD_M1,3), l1=iLow(InpTradeSymbol,PERIOD_M1,3);
      double h3=iHigh(InpTradeSymbol,PERIOD_M1,1), l3=iLow(InpTradeSymbol,PERIOD_M1,1);
      if(g_sweepDir>0 && h1<l3)
      {
         g_fvgLow=h1; g_fvgHigh=l3; g_fvgTime=t; g_state=ST_WAIT_RETRACE;
         PrintFormat("Scalp: bullish M1 FVG %.3f-%.3f",g_fvgLow,g_fvgHigh);
      }
      else if(g_sweepDir<0 && l1>h3)
      {
         g_fvgLow=h3; g_fvgHigh=l1; g_fvgTime=t; g_state=ST_WAIT_RETRACE;
         PrintFormat("Scalp: bearish M1 FVG %.3f-%.3f",g_fvgLow,g_fvgHigh);
      }
   }
}
void TryEntry()
{
   if(g_state==ST_IDLE || g_sweepDir==0) return;
   int age=iBarShift(InpTradeSymbol,PERIOD_M15,g_sweepTime,false);
   if(age<0 || age>InpSetupExpiryM15Bars)
   {
      g_state=ST_IDLE; g_sweepDir=0; g_setupTime=0; g_fvgTime=0;
      return;
   }
   if(g_bias==0 || g_bias!=g_sweepDir)
   {
      g_state=ST_IDLE; g_sweepDir=0; g_setupTime=0; g_fvgTime=0;
      return;
   }
   if(g_state!=ST_WAIT_RETRACE) return;
   double target;
   if(!GetTarget(g_bias,target)) return;
   double ce=(g_fvgLow+g_fvgHigh)/2.0;
   double ask=SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK), bid=SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID);
   bool crossed=(g_sweepDir>0?(g_prevAsk>ce && ask<=ce):(g_prevBid<ce && bid>=ce));
   if(!crossed) return;
   // Do not enter if the FVG was invalidated before the retracement.
   if(g_sweepDir>0 && bid<g_fvgLow) { g_state=ST_IDLE; return; }
   if(g_sweepDir<0 && ask>g_fvgHigh) { g_state=ST_IDLE; return; }
   RiskAllowsAndSend(g_sweepDir,g_sweepExtreme,target);
}
int OnInit()
{
   if(_Symbol!=InpTradeSymbol) Print("Attach to the exact configured trade symbol: ",InpTradeSymbol);
   if(!SymbolSelect(InpTradeSymbol,true)) return INIT_FAILED;
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      Print("Warning: spec expects a Hedging account; verify account mode before testing.");
   trade.SetExpertMagicNumber(InpMagic);
   g_lockName=GVPrefix()+"lock";
   if(!GlobalVariableCheck(g_lockName)) GlobalVariableSet(g_lockName,0.0);
   if(!GlobalVariableSetOnCondition(g_lockName,(double)ChartID(),0.0))
   {
      Print("Scalp: another instance may own the lock. Remove stale terminal Global Variable only after confirming no active instance.");
      return INIT_FAILED;
   }
   g_lockOwned=true;
   g_dayKey=-1;
   RefreshDailyState();
   g_lastM15Bar=iTime(InpTradeSymbol,PERIOD_M15,0);
   g_lastM1Bar=iTime(InpTradeSymbol,PERIOD_M1,0);
   g_prevAsk=SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK);
   g_prevBid=SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID);
   Print("Scalp ICT baseline v0.10 initialized. Prototype: Strategy Tester/demo only.");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   if(g_lockOwned && GlobalVariableCheck(g_lockName))
   {
      double owner=GlobalVariableGet(g_lockName);
      if(owner==(double)ChartID()) GlobalVariableSet(g_lockName,0.0);
   }
}
void OnTick()
{
   if(_Symbol!=InpTradeSymbol) return;
   UpdateSpreadSamples();
   RefreshDailyState();
   g_bias=Get4HBias();
   ManageForcedExits();
   if(InpUseNewsFilter)
   {
      // No calendar integration is bundled in this prototype: fail closed when enabled.
      g_prevAsk=SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK);
      g_prevBid=SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID);
      return;
   }
   if(IsNewBar(PERIOD_M15,g_lastM15Bar)) ProcessM15();
   if(IsNewBar(PERIOD_M1,g_lastM1Bar)) ProcessM1();
   TryEntry();
   g_prevAsk=SymbolInfoDouble(InpTradeSymbol,SYMBOL_ASK);
   g_prevBid=SymbolInfoDouble(InpTradeSymbol,SYMBOL_BID);
}
