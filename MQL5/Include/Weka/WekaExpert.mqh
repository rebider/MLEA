//+------------------------------------------------------------------+
//|                                                   WekaExpert.mqh |
//|                        Copyright 2010, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2010, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#include <Trade\SymbolInfo.mqh>
#include <Files\FileTxt.mqh>
#include <Utils\Utils.mqh>
#include <Trade\AccountInfo.mqh>
//#include <Trade\HistoryOrderInfo.mqh>

#include "RandomClassifier.mqh"
#include "AllTrueClassifier.mqh"
#include "ProbMoneyManagement.mqh"
#include "TpslClassifierInfo.mqh"
#include "HpDbNoDll.mqh"

#define PREV_TIME_CNT 1
#define PERIOD_CNT 1
#define SYMBOL_CNT 1
#define IND_CNT 0
#define IND2_CNT 4

#define BATCH_DEAL_CNT 2
#define BATCH_HOUR_CNT 24

#define BATCH_TP_START 20
#define BATCH_SL_START 20
#define BATCH_TP_DELTA 20
#define BATCH_SL_DELTA 20
#define BATCH_TP_CNT 30
#define BATCH_SL_CNT 30
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CWekaExpert
  {
private:
   int               inds[SYMBOL_CNT][PERIOD_CNT][30];
   CSymbolInfo       m_symbol;
   ENUM_TIMEFRAMES   m_periods[4];
   string            m_symbols[6];

   int               AMA_9_2_30,ADX_14,ADXWilder_14,Bands_20_2,DEMA_14,FrAMA_14,MA_10,SAR_002_02,StdDev_20,TEMA_14,VIDyA_9_12;
   int               ATR_14,BearsPower_13,BullsPower_13,CCI_14,DeMarker_14,MACD_12_26_9,RSI_14,RVI_10,Stochastic_5_3_3,TriX_14,WPR_14;
   datetime          m_lastTime;
   int               m_currentHour;

   int               m_batchTrainMinutes;
   int               m_batchTestMinutes;
   int               m_dealInfoLastMinutes;
   double            m_point;
   datetime          m_lastBuildTime;

   CTpslClassifierInfo *m_classifierInfoIdxs[BATCH_DEAL_CNT][BATCH_TP_CNT][BATCH_SL_CNT][BATCH_HOUR_CNT];
   CHpDb             m_hpDb;
public:
                     CWekaExpert(string symbol);
                    ~CWekaExpert();
   void              BuildModel();
   string            Predict();

   void              PrintDebugInfo();
   void              PrintAccountInfo();
   void              Test();
private:
   void              DoBuildModel(datetime nowTime);
   bool              GetData(datetime startTime,datetime endTime,double &p[],datetime &pTime[]);
   bool              GetHpData(datetime &pTime[],datetime nowTime,int &r[],datetime &rTime[]);
   int               Simulate(int tp,int sl,int dealType,datetime openDate,datetime nowDate,MqlRates &rates[],datetime &closeDate);

   void              Train(datetime nowTime,int numAttr,int numHp,int numInstTrain,double &pTrain[],int &rTrain[],datetime &rTrainTime[],int numInstTest,double &pTest[],int &rTest[],datetime &rTestTime[]);
   string            Test(datetime nowTime,int numAttr,double &p[]);
   void              Now(datetime nowTime,MqlRates &nowPrice);
   void              InitClassifierInfos();
   void              AddInstance(CInstances &hereInstances,double &dp[],int hp,datetime hpTime,int numAttr,int n);
   void              TrainandTest(CTpslClassifierInfo &classifierInfo,CInstances &trainInstances,CInstances &testInstances);
   CTpslClassifierInfo *GetMinScoreClassifierInfo();

   void              SaveCls(datetime now);
   datetime          LoadCls(datetime latest);
   bool              LoadClsAt(datetime saveTime);
   void              PrintClsInfo(CTpslClassifierInfo &clsInfo,string header,string others="");

   void              Now();

  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CWekaExpert::Test()
  {
   for(int k=0; k<BATCH_DEAL_CNT;++k)
     {
      for(int i=0; i<BATCH_TP_CNT;++i)
        {
         for(int j=0; j<BATCH_SL_CNT;++j)
           {
            int tp = BATCH_TP_START + BATCH_TP_DELTA * i;
            int sl = BATCH_SL_START + BATCH_SL_DELTA * j;
            for(int h=0; h<BATCH_HOUR_CNT;++h)
              {
               for(int m=0; m<80;++m)
                 {
                  m_classifierInfoIdxs[k][i][j][h].Deals().AddDeal((datetime)(TimeCurrent()+6),(datetime)(TimeCurrent()+7), 2,
                                                         1.3456,
                                                         'B',
                                                         1.3678,1.3325,
                                                         0.01);
                 }
              }
           }
        }
     }

   Print(TimeLocal());
   MqlRates rate;
   rate.time = TimeCurrent();
   rate.close=1.5678;
   for(int t=0; t<59;++t)
     {
      Now((datetime)(TimeCurrent()+t),rate);
     }
   Print(TimeLocal());
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CWekaExpert::TrainandTest(CTpslClassifierInfo &classifierInfo,CInstances &trainInstances,CInstances &testInstances)
  {
   CClassifier *cls=classifierInfo.Classifier();
   if(cls==NULL)
     {
      //cls = new CRandomClassifier((double)classifierInfo.Tp() / classifierInfo.Sl());
      cls=new CAllTrueClassifier();
      classifierInfo.Classifier(cls);
      Debug("New Classifier");
     }
   cls.buildClassifier(trainInstances);

   CMoneyManagement *mm=classifierInfo.MoneyManagement();
   if(mm==NULL)
     {
      mm=new CProbMoneyManagement((double)classifierInfo.Tp()/classifierInfo.Sl());
      classifierInfo.MoneyManagement(mm);
      Debug("New MoneyManagement");
     }
   mm.Build(trainInstances);

   double cv[];
   ArrayResize(cv,testInstances.numInstances());
   for(int i=0; i<testInstances.numInstances(); i++)
     {
      cv[i]=cls.classifyInstance(testInstances.instance(i));
     }

//classifierInfo.CurrentTestRet = cv;

//classifierInfo.CurrentClassValue = new double[testInstances.numInstances()];
//for (int i = 0; i < testInstances.numInstances(); ++i)
//{
//classifierInfo.CurrentClassValue[i] = testInstances.instance(i).classValue();
//}
   for(int i=0; i<testInstances.numInstances(); i++)
     {
      if(cv[i]==2)
        {
         double openPrice=testInstances.instance(i).value(5);
         double closePriceTp,closePriceSl;
         if(classifierInfo.DealType()=='B')
           {
            closePriceTp = openPrice + classifierInfo.Tp() * m_point * GetPointOffset(m_symbol.Digits());
            closePriceSl = openPrice - classifierInfo.Sl() * m_point * GetPointOffset(m_symbol.Digits());
           }
         else if(classifierInfo.DealType()=='S')
           {
            closePriceTp = openPrice - classifierInfo.Tp() * m_point * GetPointOffset(m_symbol.Digits());
            closePriceSl = openPrice + classifierInfo.Sl() * m_point * GetPointOffset(m_symbol.Digits());
           }
         datetime openDate=(datetime)(testInstances.instance(i).value(0)/1000);
         datetime closeDate=(datetime)(testInstances.instance(i).value(1)/1000);
         classifierInfo.Deals().AddDeal(openDate,closeDate,(int)testInstances.instance(i).classValue(),
                              openPrice,
                              classifierInfo.DealType(),
                              closePriceTp,closePriceSl,
                              classifierInfo.MoneyManagement()==NULL ? 1 : classifierInfo.MoneyManagement().GetVolume(testInstances.instance(i)));
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CWekaExpert::AddInstance(CInstances &hereInstances,double &dp[],int hp,datetime hpTime,int numAttr,int n)
  {
//int numAttr = (IND_CNT + IND2_CNT) * PERIOD_CNT * SYMBOL_CNT * PREV_TIME_CNT + 6;

   int posDp=n*numAttr;
   double mainClose=dp[posDp+5];
   int posInst=0;

   double instanceValue[];
   ArrayResize(instanceValue,numAttr+1);

// row_date, hp_date,hour,day_of_week,vol,mainClose
   for(int i=0; i<6;++i)
     {
      if(i==0)
         instanceValue[posInst]=dp[posDp+i]*1000;
      else if(i==1)
         instanceValue[posInst]=(double)hpTime*1000;
      else
         instanceValue[posInst]=dp[posDp+i];
      posInst++;
     }

   posDp+=6;
   for(int s=0; s<SYMBOL_CNT;++s)
     {
      for(int i=0; i<PERIOD_CNT;++i)
        {
         for(int p=0; p<PREV_TIME_CNT;++p)
           {
            for(int j=0; j<IND2_CNT;++j)
              {
               double v=(double)dp[posDp];
               double ind=v; //WekaUtils.NormalizeValue(kvp.Key, kvp.Value, v, mainClose, Parameters.AllSymbols[s] == "USDJPY" ? 1 : 100);
               instanceValue[posInst]=ind;
               posDp++; posInst++;
              }

            //for (int j = -1; j < Math.Max(0, Math.Min(TestParameters.PeriodTimeCount - i, TestParameters.PeriodTimeNames[i].Length)); ++j)
              {
               for(int j=0; j<IND_CNT;++j)
                 {
                  double v=(double)dp[posDp];
                  double ind=v;//WekaUtils.NormalizeValue(kvp.Key, kvp.Value, v, mainClose, Parameters.AllSymbols[s] == "USDJPY" ? 1 : 100);
                  instanceValue[posInst]=ind;
                  posDp++; posInst++;
                 }
              }
           }
        }
     }

//int hp = 1;
   instanceValue[posInst]=hp;

   CInstance *instance=new CInstance(instanceValue);
   hereInstances.Add(instance);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CWekaExpert::InitClassifierInfos()
  {
   for(int k=0; k<BATCH_DEAL_CNT;++k)
     {
      for(int i=0; i<BATCH_TP_CNT;++i)
        {
         for(int j=0; j<BATCH_SL_CNT;++j)
           {
            int tp = BATCH_TP_START + BATCH_TP_DELTA * i;
            int sl = BATCH_SL_START + BATCH_SL_DELTA * j;
            for(int h=0; h<BATCH_HOUR_CNT;++h)
              {
               char dealType=k==0? 'B' : 'S';
               string name=CharToString(dealType)+"_"+IntegerToString(tp)+"_"+IntegerToString(sl)+"_H"+IntegerToString(h);
               m_classifierInfoIdxs[k][i][j][h]=new CTpslClassifierInfo(name,tp,sl,dealType,m_dealInfoLastMinutes);
               Debug("Create ClassifierInfo "+name+" with dealInfoLastMinutes = "+IntegerToString(m_dealInfoLastMinutes));
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CWekaExpert::Train(datetime nowTime,int numAttr,int numHp,int numInstTrain,double &pTrain[],int &rTrain[],datetime &rTrainTime[],int numInstTest,double &pTest[],int &rTest[],datetime &rTestTime[])
  {
   for(int k=0; k<BATCH_DEAL_CNT;++k)
     {
      for(int i=0; i<BATCH_TP_CNT;++i)
        {
         for(int j=0; j<BATCH_SL_CNT;++j)
           {
            //for (int h = 0; h < BATCH_HOUR_CNT; ++h)
              {
               CInstances trainInstances,testInstances;
               for(int n=0; n<numInstTrain;++n)
                 {
                  int start=n*numAttr;
                  datetime date=(datetime)pTrain[start+0];
                  //if (m_currentTestHour != date.Hour)
                  //    continue;

                  //int hp = drTrain[k * BATCH_TP_CNT * BATCH_SL_CNT * numInstTrain +
                  //    i * BATCH_SL_CNT * numInstTrain +
                  //    j * numInstTrain +
                  //    n];
                  int hp=rTrain[n*BATCH_DEAL_CNT*BATCH_TP_CNT*BATCH_SL_CNT+
                         k*BATCH_TP_CNT*BATCH_SL_CNT+
                         i*BATCH_SL_CNT+
                         j];
                  datetime hpTime=rTrainTime[n*BATCH_DEAL_CNT*BATCH_TP_CNT*BATCH_SL_CNT+
                                  k*BATCH_TP_CNT*BATCH_SL_CNT+
                                  i*BATCH_SL_CNT+
                                  j];
                  AddInstance(trainInstances,pTrain,hp,hpTime,numAttr,n);
                 }

               for(int n=0; n<numInstTest;++n)
                 {
                  int start=n*numAttr;
                  datetime date=(datetime)pTest[start+0];
                  //if (m_currentTestHour != date.Hour)
                  //    continue;

                  //int hp = drTest[k * BATCH_TP_CNT * BATCH_SL_CNT * numInstTest +
                  //    i * BATCH_SL_CNT * numInstTest +
                  //    j * numInstTest +
                  //    n];
                  int hp=rTest[n*BATCH_DEAL_CNT*BATCH_TP_CNT*BATCH_SL_CNT+
                         k*BATCH_TP_CNT*BATCH_SL_CNT+
                         i*BATCH_SL_CNT+
                         j];
                  datetime hpTime=rTestTime[n*BATCH_DEAL_CNT*BATCH_TP_CNT*BATCH_SL_CNT+
                                  k*BATCH_TP_CNT*BATCH_SL_CNT+
                                  i*BATCH_SL_CNT+
                                  j];
                  AddInstance(testInstances,pTest,hp,hpTime,numAttr,n);
                 }

               CTpslClassifierInfo *clsInfo=m_classifierInfoIdxs[k][i][j][m_currentHour];
               TrainandTest(clsInfo,trainInstances,testInstances);

               //Print("7");
               //if (StringFind(clsInfo.Name(), "B_60_60_H0") != -1)
                 {
                  string s=",TrN="+IntegerToString(numInstTrain)+",TeN="+IntegerToString(numInstTest);
                  //string s2 = "";
                  //CMoneyManagement* mm = clsInfo.MoneyManagement();
                  //s = mm.ToString();
                  PrintClsInfo(clsInfo,"CC:",s);
                 }

               //if (k == 0 && i == 0 && j == 0 && m_currentHour == 0)
               //    Info(clsInfo.Classifier().GetDebugInfo());
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CWekaExpert::PrintAccountInfo()
  {
   CAccountInfo accountInfo;
   CPositionInfo positionInfo;

   datetime from=0;
   datetime to=TimeCurrent();
   HistorySelect(from,to);
   int tp=0,fp=0;
   double cost= 0;
   double vol = 0;
   double all_swap=0;
   uint     total=HistoryDealsTotal();
   for(uint i=0;i<total;i++)
     {
      ulong ticket=HistoryDealGetTicket(i);
      ENUM_DEAL_TYPE type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket,DEAL_TYPE);
      if(type==DEAL_TYPE_BALANCE)
         continue;
      ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket,DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_OUT)
         continue;
      double volume= HistoryDealGetDouble(ticket,DEAL_VOLUME);
      double profit= HistoryDealGetDouble(ticket,DEAL_PROFIT);
      double swap=HistoryDealGetDouble(ticket,DEAL_SWAP)+HistoryDealGetDouble(ticket,DEAL_COMMISSION);
      if(profit>0)
         tp++;
      else
         fp++;
      cost+= profit;
      vol += volume;
      all_swap+=swap;
     }
   Notice("TR:NC="+DoubleToString(cost,2)+
        ",NTP="+IntegerToString(tp)+
        ",NFP="+IntegerToString(fp)+
        ",NV="+DoubleToString(vol,2)+
        ",CP="+DoubleToString(accountInfo.Profit(),2)+
        ",CV="+DoubleToString(positionInfo.Volume(),2)+
        ",CD=?"+
        ",SP="+DoubleToString(all_swap,2));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CWekaExpert::PrintClsInfo(CTpslClassifierInfo &clsInfo,string header,string others="")
  {
   Info(header,"N="+clsInfo.Name(),others,
        ",NC="+DoubleToString(clsInfo.Deals().NowScore(),4)+
        ",NTP=" + IntegerToString(clsInfo.Deals().NowTp()) +
        ",NFP=" + IntegerToString(clsInfo.Deals().NowFp()) +
        ",TD="+ IntegerToString(clsInfo.Deals().TotalDeal()),
        ",TV=" + DoubleToString(clsInfo.Deals().TotalVolume(),2));
//clsInfo.Deals().PrintAll();
//Info(",Cls=" + (clsInfo.Classifier() == NULL ? "" : clsInfo.Classifier().ToString()),
//Info((clsInfo.MoneyManagement() == NULL ? "" : clsInfo.MoneyManagement().ToString()));
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string  CWekaExpert::Test(datetime nowTime,int numAttr,double &dp[])
  {
   int numInst=1;
   if(ArraySize(dp)==0 || ArraySize(dp)<numAttr*numInst)
      return "";

   CInstances testInstances;
   for(int n=0; n<numInst;++n)
     {
      int start=n*numAttr;
      datetime date=(datetime)dp[start+0];
      //if (m_currentTestHour != date.Hour)
      //    continue;

      int hp=1;
      datetime hpTime=0;
      AddInstance(testInstances,dp,hp,hpTime,numAttr,n);
     }

   CTpslClassifierInfo *minScoreInfo=GetMinScoreClassifierInfo();
   if(minScoreInfo!=NULL)
     {
      PrintClsInfo(minScoreInfo,"minScoreCls:");
      double r=minScoreInfo.Classifier().classifyInstance(testInstances.instance(0));
      if(r!=2)
        {
         minScoreInfo=NULL;
        }
     }
   else
     {
      Info("No profit classifier.");
     }

   if(minScoreInfo==NULL)
      return "";

   double volume=minScoreInfo.MoneyManagement().GetVolume(testInstances.instance(0));
   return minScoreInfo.Name()+"_"+DoubleToString(volume,2);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CTpslClassifierInfo *CWekaExpert::GetMinScoreClassifierInfo()
  {
   double minScore=DBL_MAX;
   int minNum=0;
   CTpslClassifierInfo *minScoreInfo=NULL;

   for(int k=0; k<BATCH_DEAL_CNT;++k)
     {
      for(int i=0; i<BATCH_TP_CNT;++i)
        {
         for(int j=0; j<BATCH_SL_CNT;++j)
           {
            //for (int h = 0; h < BATCH_HOUR_CNT; ++h)
              {
               CTpslClassifierInfo *clsInfo=m_classifierInfoIdxs[k][i][j][m_currentHour];
               double cost=clsInfo.Deals().NowScore();
               int num=clsInfo.Deals().NowDeal();
               //double score = num == 0 ? 0 : cost / num;
               double score=cost;
               if((score<minScore) || (score==minScore && num>minNum)) // num == 0 && minTc >= 0) || 
                 {
                  minScore=score;
                  minNum=num;
                  minScoreInfo=clsInfo;
                  Debug("clsInfo "+clsInfo.Name()," has min score = ",DoubleToString(score,1)," and minNum = ",IntegerToString(num));
                 }
              }
           }
        }
     }
   if(minScoreInfo==NULL || minScore==DBL_MAX)
     {
      Warn("No Candidate Classifier.");
      return NULL;
     }

// Check other conditions
   if(minScore<0)
     {
      // 和B，S中Score小的一致
      double costPerDeal[BATCH_DEAL_CNT];
      for(int k=0; k<BATCH_DEAL_CNT;++k)
        {
         for(int i=0; i<BATCH_TP_CNT;++i)
           {
            for(int j=0; j<BATCH_SL_CNT;++j)
              {
               costPerDeal[k]+=m_classifierInfoIdxs[k][i][j][m_currentHour].Deals().NowScore();
              }
           }
        }
      Debug("score by deal is ",DoubleToString(costPerDeal[0],1),", ",DoubleToString(costPerDeal[1],1));
      if(costPerDeal[0]<=costPerDeal[1])
        {
         if(minScoreInfo.DealType()!='B' || costPerDeal[0]>=0)
           {
            minScore=0;
           }
        }
      else
        {
         if(minScoreInfo.DealType()!='S' || costPerDeal[1]>=0)
           {
            minScore=0;
           }
        }
     }

   if(minScore<0)
     {
      return minScoreInfo;
     }
   else
     {
      return NULL;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CWekaExpert::Now(datetime nowTime,MqlRates &nowPrice)
  {
   for(int k=0; k<BATCH_DEAL_CNT;++k)
     {
      for(int i=0; i<BATCH_TP_CNT;++i)
        {
         for(int j=0; j<BATCH_SL_CNT;++j)
           {
            for(int h=0; h<BATCH_HOUR_CNT;++h)
              {
               // must be all, because will calculate closeTime
               if(h==m_currentHour)
                 {
                  m_classifierInfoIdxs[k][i][j][h].Deals().Now(nowTime,nowPrice);
                 }
               else
                 {
                  if(m_classifierInfoIdxs[k][i][j][h].Deals().IsCloseTimeNotSet())
                    {
                     Notice(m_classifierInfoIdxs[k][i][j][h].Name()+" is CloseTimeNotSet.");
                     m_classifierInfoIdxs[k][i][j][h].Deals().Now(nowTime,nowPrice);
                    }
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CWekaExpert::CWekaExpert(string symbol)
  {
   m_symbol.Name(symbol);
   m_point=m_symbol.Point(); //0.00001;

   m_hpDb.SetAppend(IntegerToString(BATCH_TP_START)+"_"+IntegerToString(BATCH_TP_DELTA)+"_"+IntegerToString(BATCH_TP_CNT)
                    +"."
                    +IntegerToString(BATCH_SL_START)+"_"+IntegerToString(BATCH_SL_DELTA)+"_"+IntegerToString(BATCH_SL_CNT));

   m_periods[0]=PERIOD_M5;
   if(PERIOD_CNT > 1) m_periods[1] = PERIOD_M15;
   if(PERIOD_CNT > 2) m_periods[2] = PERIOD_H1;
   if(PERIOD_CNT > 3) m_periods[3] = PERIOD_H4;

   m_symbols[0]="EURUSD";
   if(SYMBOL_CNT > 1) m_symbols[1] = "GBPUSD";
   if(SYMBOL_CNT > 2) m_symbols[2] = "USDCHF";
   if(SYMBOL_CNT > 3) m_symbols[3] = "USDCAD";
   if(SYMBOL_CNT > 4) m_symbols[4] = "USDJPY";
   if(SYMBOL_CNT > 5) m_symbols[5] = "AUDUSD";

   AMA_9_2_30=ADX_14=ADXWilder_14=Bands_20_2=DEMA_14=FrAMA_14=MA_10=SAR_002_02=StdDev_20=TEMA_14=VIDyA_9_12=-1;
   ATR_14=BearsPower_13=BullsPower_13=CCI_14=DeMarker_14=MACD_12_26_9=RSI_14=RVI_10=Stochastic_5_3_3=TriX_14=WPR_14=-1;

/*for(int s=0; s<SYMBOL_CNT; ++s)
    {
        for(int i=0; i<PERIOD_CNT; ++i)
        {
            int n = 0;
            inds[s][i][n] = iADXWilder(m_symbols[s], m_periods[i], 14);          ADXWilder_14 = n; n++;
            inds[s][i][n] = iADX(m_symbols[s], m_periods[i], 14);                ADX_14 = n; n++;
            inds[s][i][n] = iAMA(m_symbols[s], m_periods[i], 9, 2, 30, 0, PRICE_CLOSE);   AMA_9_2_30 = n; n++;
            inds[s][i][n] = iATR(m_symbols[s], m_periods[i], 14);                          ATR_14 = n; n++;
            inds[s][i][n] = iBands(m_symbols[s], m_periods[i], 20, 0, 2, PRICE_CLOSE);     Bands_20_2 = n; n++;
            inds[s][i][n] = iBearsPower(m_symbols[s], m_periods[i], 13);                   BearsPower_13 = n; n++;
            inds[s][i][n] = iBullsPower(m_symbols[s], m_periods[i], 13);                   BullsPower_13 = n; n++;
            inds[s][i][n] = iCCI(m_symbols[s], m_periods[i], 14, PRICE_TYPICAL);           CCI_14 = n; n++;
            inds[s][i][n] = iDeMarker(m_symbols[s], m_periods[i], 14);                     DeMarker_14 = n; n++;
            inds[s][i][n] = iDEMA(m_symbols[s], m_periods[i], 14, 0, PRICE_CLOSE);         DEMA_14 = n; n++;
            inds[s][i][n] = iFrAMA(m_symbols[s], m_periods[i], 14, 0, PRICE_CLOSE);        FrAMA_14 = n; n++;
            inds[s][i][n] = iMACD(m_symbols[s], m_periods[i], 12, 26, 9, PRICE_CLOSE);     MACD_12_26_9= n; n++;                       
            inds[s][i][n] = iMA(m_symbols[s], m_periods[i], 10, 0, MODE_SMA, PRICE_CLOSE); MA_10 = n; n++;
            inds[s][i][n] = iRSI(m_symbols[s], m_periods[i], 14, PRICE_CLOSE);             RSI_14 = n; n++;
            inds[s][i][n] = iRVI(m_symbols[s], m_periods[i], 10);                          RVI_10 = n; n++;
            inds[s][i][n] = iStochastic(m_symbols[s], m_periods[i], 5, 3, 3, MODE_SMA, STO_LOWHIGH);       Stochastic_5_3_3 = n; n++;
            inds[s][i][n] = iTEMA(m_symbols[s], m_periods[i], 14, 0, PRICE_CLOSE);         TEMA_14 = n; n++;
            inds[s][i][n] = iTriX(m_symbols[s], m_periods[i], 14, PRICE_CLOSE);            TriX_14 = n; n++;
            inds[s][i][n] = iVIDyA(m_symbols[s], m_periods[i], 9, 12, 0, PRICE_CLOSE);     VIDyA_9_12 = n; n++;
            inds[s][i][n] = iWPR(m_symbols[s], m_periods[i], 14);                          WPR_14 = n; n++;
        }
    }*/

   m_batchTrainMinutes= 2 * 4 * 7 * 24 * 12 * 5;
   m_batchTestMinutes = 1 * 1 * 12 * 5;
   m_dealInfoLastMinutes=2*4*7*24*12*5;

   InitClassifierInfos();

   m_lastBuildTime=0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CWekaExpert::~CWekaExpert()
  {
   for(int s=0; s<SYMBOL_CNT;++s)
     {
      for(int i=0; i<PERIOD_CNT;++i)
        {
         for(int j=0; j<30;++j)
           {
            if(inds[s][i][j]!=NULL)
              {
               IndicatorRelease(inds[s][i][j]);
              }
           }
        }
     }

   for(int k=0; k<BATCH_DEAL_CNT;++k)
     {
      for(int i=0; i<BATCH_TP_CNT;++i)
        {
         for(int j=0; j<BATCH_SL_CNT;++j)
           {
            for(int h=0; h<BATCH_HOUR_CNT;++h)
              {
               delete m_classifierInfoIdxs[k][i][j][h];
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CWekaExpert::SaveCls(datetime now)
  {
   Info("Save DealInfos at ",TimeToString(now));
   for(int k=0; k<BATCH_DEAL_CNT;++k)
     {
      for(int i=0; i<BATCH_TP_CNT;++i)
        {
         for(int j=0; j<BATCH_SL_CNT;++j)
           {
            string fileName="ClsInfo\\"+TimeToString(now,TIME_DATE)+"\\"+m_classifierInfoIdxs[k][i][j][m_currentHour].Name()+".cls";
            CFileBin file;
            file.SetCommon(true);
            int handle = file.Open(fileName, FILE_WRITE);
            if(handle != INVALID_HANDLE)
              {
               m_classifierInfoIdxs[k][i][j][m_currentHour].Deals().Save(handle);
               file.Close();
              }
            else
              {
               Error("Faild to open write "+fileName);
               ErrorCurrentError();
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CWekaExpert::LoadClsAt(datetime saveTime)
  {
   Info("Load DealInfos at ",TimeToString(saveTime));

   bool r=true;
   for(int k=0; k<BATCH_DEAL_CNT;++k)
     {
      for(int i=0; i<BATCH_TP_CNT;++i)
        {
         for(int j=0; j<BATCH_SL_CNT;++j)
           {
            for(int h=0; h<BATCH_HOUR_CNT;++h)
              {
               //if (k != 0 || i != 0 || j != 0 || h != 0)
               //    continue;

               string fileName="ClsInfo\\"+TimeToString(saveTime,TIME_DATE)+"\\"+m_classifierInfoIdxs[k][i][j][h].Name()+".cls";
               CFileBin file;
               file.SetCommon(true);
               int handle = file.Open(fileName, FILE_READ);
               if(handle != INVALID_HANDLE)
                  m_classifierInfoIdxs[k][i][j][h].Deals().Load(handle);
               else
                  r=false;
               file.Close();
              }
           }
        }
     }
   if(!r)
     {
      for(int k=0; k<BATCH_DEAL_CNT;++k)
        {
         for(int i=0; i<BATCH_TP_CNT;++i)
           {
            for(int j=0; j<BATCH_SL_CNT;++j)
              {
               for(int h=0; h<BATCH_HOUR_CNT;++h)
                 {
                  m_classifierInfoIdxs[k][i][j][h].Deals().Clear();
                 }
              }
           }
        }
     }
   return r;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime CWekaExpert::LoadCls(datetime latest)
  {
   datetime saveTime=0;// = D'2009.04.20';

   string filename;
   long search=FileFindFirst("ClsInfo\\*.*",filename,FILE_COMMON);
   if(search!=INVALID_HANDLE)
     {
      do
        {
         int n=StringLen(filename);
         if(StringGetCharacter(filename,n-1)!='\\')
            continue;
         string sd=StringSubstr(filename,0,n-1);
         datetime d=StringToTime(sd);
         if(d>saveTime && d<latest)
            saveTime=d;
        }
      while(FileFindNext(search,filename));

      FileFindClose(search);
     }

   if(saveTime==0)
      return 0;

   bool r=LoadClsAt(saveTime);

   if(r)
      return saveTime+PeriodSeconds(PERIOD_D1);
   else
      return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CWekaExpert::PrintDebugInfo()
  {
   datetime d=D'2009.03.20';
   LoadClsAt(d);
   for(int k=0; k<BATCH_DEAL_CNT;++k)
     {
      for(int i=0; i<BATCH_TP_CNT;++i)
        {
         for(int j=0; j<BATCH_SL_CNT;++j)
           {
            for(int h=0; h<BATCH_HOUR_CNT;++h)
              {
               //if(k!=0 || i!=0 || j!=0 || h!=0)
               //   continue;

               //Print("Cls Name=",m_classifierInfoIdxs[k][i][j][h].Name(),", Count=",m_classifierInfoIdxs[k][i][j][h].Deals().TotalDeal());
               m_classifierInfoIdxs[k][i][j][h].Deals().PrintAll(true);
              }
           }
        }
     }
   Print("PrintDebugInfo Finish.");
  }
//+------------------------------------------------------------------+
void CWekaExpert::Now()
  {
   MqlRates ratesM1[];
   ArraySetAsSeries(ratesM1,true);

   datetime nowTime=TimeCurrent();
   int ri=CopyRates(m_symbols[0],PERIOD_M1,nowTime,nowTime+m_batchTestMinutes*60-60,ratesM1);
   if(ri>0 && ArraySize(ratesM1)>0)
     {
      Info("Execute now from ",TimeToString(ratesM1[ArraySize(ratesM1)-1].time)," to ",TimeToString(ratesM1[0].time));
      for(int i=ArraySize(ratesM1)-1; i>=0; --i)
        {
         Now(ratesM1[i].time+60,ratesM1[i]);
        }
     }
   else
     {
      Error("Failed in CopyRates.");
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CWekaExpert::DoBuildModel(datetime nowTime)
  {
   Info("Now is "+TimeToString(nowTime));

   Info("Get train and test data.");
   datetime trainStartTime=nowTime-m_batchTrainMinutes*60;
   datetime testEndTime=nowTime+m_batchTestMinutes*60;

   double pTrain[];
   datetime pTimeTrain[];
   int rTrain[];
   datetime rTrainTime[];
   bool rb=GetData(trainStartTime,nowTime,pTrain,pTimeTrain);
   rb|=GetHpData(pTimeTrain,nowTime,rTrain,rTrainTime);
   double pTest[];
   datetime pTimeTest[];
   int rTest[];
   datetime rTestTime[];
   rb|=GetData(nowTime,testEndTime,pTest,pTimeTest);
   rb|= GetHpData(pTimeTest,nowTime,rTest,rTestTime);

   if(!rb)
     {
      Error("Error in GetData, continue.");
      return;
     }
   if(ArraySize(pTimeTest)==0 || ArraySize(pTimeTrain)==0)
     {
      Warn("Train or Test Size = 0");
      return;
     }

   Info("Train and Test.");
   int numInst=ArraySize(pTimeTrain);
   int numInst2=ArraySize(pTimeTest);
   int numHp=BATCH_DEAL_CNT*BATCH_TP_CNT*BATCH_SL_CNT;
   int numAttr=(IND_CNT+IND2_CNT)*PERIOD_CNT*SYMBOL_CNT*PREV_TIME_CNT+6;
   Train(nowTime,numAttr,numHp,numInst,pTrain,rTrain,rTrainTime,numInst2,pTest,rTest,rTestTime);

   MqlRates ratesM1[];
   ArraySetAsSeries(ratesM1,true);
   int ri=CopyRates(m_symbols[0],PERIOD_M1,nowTime,nowTime+m_batchTestMinutes*60-60,ratesM1);
   if(ri>0 && ArraySize(ratesM1)>0)
     {
      Info("Execute now from ",TimeToString(ratesM1[ArraySize(ratesM1)-1].time)," to ",TimeToString(ratesM1[0].time));
      for(int i=ArraySize(ratesM1)-1; i>=0; --i)
        {
         Now(ratesM1[i].time+60,ratesM1[i]);
        }
     }
   else
     {
      Warn("Errpr in get data for execute now. continue.");
      DebugCurrentError();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CWekaExpert::BuildModel()
  {
   int batchTestSeconds=m_batchTestMinutes*60;

// 例如，当05PM时，TrainTo 04PM ，Test 04-05
   datetime h1Time=TimeCurrent()/PeriodSeconds(PERIOD_H1)*PeriodSeconds(PERIOD_H1)-batchTestSeconds;
//h1Time = D'2009.05.01';

   if(h1Time==m_lastTime)
      return;
   m_lastTime=h1Time;

   while(true)
     {
      h1Time=TimeCurrent()/PeriodSeconds(PERIOD_H1)*PeriodSeconds(PERIOD_H1)-batchTestSeconds;
      datetime nowTime;
      if(m_lastBuildTime==0)
        {
         m_lastBuildTime=h1Time-m_dealInfoLastMinutes*60;
         nowTime=m_lastBuildTime;

         datetime saveTime=LoadCls(h1Time);
         if(saveTime!=0)
           {
            nowTime=saveTime;
           }
        }
      else
        {
         nowTime=m_lastBuildTime+batchTestSeconds;
        }
      Info("Build model from "+TimeToString(nowTime)+" to "+TimeToString(h1Time));

      nowTime-=batchTestSeconds;
      while(nowTime<h1Time)
        {
         nowTime+=batchTestSeconds;

         MqlDateTime nowDate;
         TimeToStruct(nowTime,nowDate);
         m_currentHour=nowDate.hour;
         if(nowDate.day_of_week==0 || nowDate.day_of_week==6)
           {
            continue;
           }
         DoBuildModel(nowTime);

         bool shouldSave=false;
         if(nowDate.day_of_week!=0 && nowDate.day_of_week!=6 && nowDate.day==20)
            shouldSave=true;
         if(nowDate.day== 21 && nowDate.day_of_week == 1)
            shouldSave = true;
         if(nowDate.day== 22 && nowDate.day_of_week == 1)
            shouldSave = true;
         if(shouldSave)
           {
            SaveCls(nowTime);
           }

         PrintAccountInfo();

         logger.Flush();
        }
      m_lastBuildTime=nowTime;

      datetime h1TimeNow=TimeCurrent()/PeriodSeconds(PERIOD_H1)*PeriodSeconds(PERIOD_H1)-batchTestSeconds;
      if(m_lastBuildTime>=h1TimeNow)
         break;
     }

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CWekaExpert::Predict()
  {
   int numAttr=(IND_CNT+IND2_CNT)*PERIOD_CNT*SYMBOL_CNT*PREV_TIME_CNT+6;

   datetime nowTime = TimeCurrent();
   datetime lastnow = nowTime / PeriodSeconds(m_periods[0]) * PeriodSeconds(m_periods[0]);
   MqlDateTime nowDate;
   TimeToStruct(nowTime,nowDate);
   m_currentHour=nowDate.hour;

   double pTest[];
   datetime pTimeTest[];
   bool rb=GetData(lastnow,lastnow+1,pTest,pTimeTest);
   if(!rb)
     {
      Warn("Error in GetData, return.");
      return "";
     }
   if(ArraySize(pTimeTest)==0)
     {
      Warn("Test Size = 0");
      return "";
     }

   string r=Test(lastnow,numAttr,pTest);
   return r;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CWekaExpert::Simulate(int tp,int sl,int dealType,datetime openTime,datetime nowTime,MqlRates &rates[],datetime &closeTime)
  {
   double m_tp = tp * m_point * GetPointOffset(m_symbol.Digits());;
   double m_sl = sl * m_point * GetPointOffset(m_symbol.Digits());;

   if(dealType==0)
     {
      datetime buyCloseDate=D'1970.1.1';
      int buyRet=1;
      bool isOpen=false;
      // try buy
      datetime buyTime;
      double buyOpen;
      double buyTp;
      double buySl;

      for(int j=ArraySize(rates)-1; j>=0; --j)
        {
         datetime rateTime=rates[j].time+PeriodSeconds(PERIOD_M1);
         if(!isOpen)
           {
            if(rateTime>=openTime)
              {
               if(rateTime>openTime+60*5)
                  break;

               buyTime = rateTime;
               buyOpen = rates[j].close + rates[j].spread * m_point;
               buyTp = buyOpen + m_tp;
               buySl = buyOpen - m_sl;
               isOpen= true;
              }
            continue;
           }
         if(rateTime>=nowTime)
           {
            break;
           }
         if(rates[j].low<=buySl)
           {
            buyRet=0;
            buyCloseDate=rateTime;
            break;
           }
         else if(rates[j].high>=buyTp)
           {
            buyRet=2;
            buyCloseDate=rateTime;
            break;
           }

        }
      if(buyRet!=1)
        {
         closeTime=buyCloseDate;
        }
      else
        {
         closeTime=nowTime;
        }
      return buyRet;
     }
   else if(dealType==1)
     {
      datetime sellCloseDate=D'1970.1.1';
      int sellRet = 1;
      bool isOpen = false;
      // try sell
      datetime sellTime;
      double sellOpen;
      double sellTp;
      double sellSl;
      for(int j=ArraySize(rates)-1; j>=0; --j)
        {
         datetime rateTime=rates[j].time+PeriodSeconds(PERIOD_M1);
         if(!isOpen)
           {
            if(rateTime>=openTime)
              {
               sellTime = rateTime;
               sellOpen = rates[j].close;
               sellTp = sellOpen - m_tp;
               sellSl = sellOpen + m_sl;
               isOpen = true;
              }
            continue;
           }
         if(rateTime>=nowTime)
           {
            break;
           }
         if(rates[j].high+rates[j].spread*m_point>=sellSl)
           {
            sellRet=0;
            sellCloseDate=rateTime;
            break;
           }
         else if(rates[j].low+rates[j].spread*m_point<=sellTp)
           {
            sellRet=2;
            sellCloseDate=rateTime;
            break;
           }
        }
      if(sellRet!=1)
        {
         closeTime=sellCloseDate;
        }
      else
        {
         closeTime=nowTime;
        }
      return sellRet;
     }
   else
     {
      return 1;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CWekaExpert::GetData(datetime startTime,datetime endTime,double &p[],datetime &pTime[])
  {
   Debug("GetData from "+TimeToString(startTime)+" to "+TimeToString(endTime));

   datetime times[];
   ArraySetAsSeries(times,true);
   int ret= CopyTime(m_symbols[0],m_periods[0],startTime-PeriodSeconds(m_periods[0]),endTime,times);
   if(ret == -1)
     {
      Error("Error in CopyTime of GetData");
      ErrorCurrentError();
      return false;
     }

   int numInst=0;
   MqlDateTime date;
   for(int t=0; t<ArraySize(times);++t)
     {
      datetime time=times[ArraySize(times)-1-t]+PeriodSeconds(m_periods[0]);
      TimeToStruct(time,date);
      if(date.hour!=m_currentHour || time<startTime || time>=endTime || (date.min!=0 && date.min!=30))
         continue;
      numInst++;
     }
   int numAttr=(IND_CNT+IND2_CNT)*PERIOD_CNT*SYMBOL_CNT*PREV_TIME_CNT+6;

//double p[];
   ArrayResize(p,numAttr*numInst);
   ArrayResize(pTime,numInst);

   int pos=0;
   for(int t=0; t<ArraySize(times);++t)
     {
      datetime time=times[ArraySize(times)-1-t]+PeriodSeconds(m_periods[0]);
      TimeToStruct(time,date);
      if(date.hour!=m_currentHour || time<startTime || time>=endTime || (date.min!=0 && date.min!=30))
         continue;

      pTime[pos]=time;

      p[pos*numAttr+0]=(double)time;
      p[pos*numAttr+1]=0;    // closeTime
      p[pos * numAttr + 2] = date.hour / 24.0;
      p[pos * numAttr + 3] = date.day_of_week / 5.0;
      p[pos * numAttr + 4] = 0;    // vol
      p[pos * numAttr + 5] = 0.00; // mainClose

      int start=pos*numAttr+6;

      MqlRates rates[];
      ArraySetAsSeries(rates,true);
      double indBuf[];
      ArraySetAsSeries(indBuf,true);

      for(int s=0; s<SYMBOL_CNT;++s)
        {
         double mainClose=0;
         for(int i=0; i<PERIOD_CNT;++i)
           {
            datetime newTime=time-PeriodSeconds(m_periods[i]);
            CopyRates(m_symbols[s],m_periods[i],newTime,2*PREV_TIME_CNT,rates);
            if(i==0)
              {
               mainClose=p[pos*numAttr+5]=rates[0].close;
              }
            for(int prev=0; prev<PREV_TIME_CNT;++prev)
              {
               p[start] = rates[prev].close;  start++;
               p[start] = rates[prev].open;   start++;
               p[start] = rates[prev].high;   start++;
               p[start] = rates[prev].low;    start++;

/*if (ADXWilder_14 != -1)
                    {
                        CopyBuffer(inds[s][i][ADXWilder_14], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                        CopyBuffer(inds[s][i][ADXWilder_14], 1, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                        CopyBuffer(inds[s][i][ADXWilder_14], 2, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start += 3;
                    }
                    
                    if (ADX_14 != -1)
                    {
                        CopyBuffer(inds[s][i][ADX_14], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                        CopyBuffer(inds[s][i][ADX_14], 1, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                        CopyBuffer(inds[s][i][ADX_14], 2, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start += 3;
                    }
                    
                    if (AMA_9_2_30 != -1)
                    {
                        CopyBuffer(inds[s][i][AMA_9_2_30], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }
                    
                    if (ATR_14 != -1)
                    {
                        CopyBuffer(inds[s][i][ATR_14], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }
                    
                    if (Bands_20_2 != -1)
                    {
                        CopyBuffer(inds[s][i][Bands_20_2], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }
                    
                    if (BearsPower_13 != -1)
                    {
                        CopyBuffer(inds[s][i][BearsPower_13], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }
                    
                    if (BullsPower_13 != -1)
                    {
                        CopyBuffer(inds[s][i][BullsPower_13], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }
                    
                    if (CCI_14 != -1)
                    {   
                        CopyBuffer(inds[s][i][CCI_14], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }
                    
                    if (DeMarker_14 != -1)
                    {
                        CopyBuffer(inds[s][i][DeMarker_14], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }
                    
                    if (DEMA_14 != -1)
                    {
                        CopyBuffer(inds[s][i][DEMA_14], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }
                    
                    if (FrAMA_14 != -1)
                    {
                        CopyBuffer(inds[s][i][FrAMA_14], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }
                    
                    if (MACD_12_26_9 != -1)
                    {    
                        CopyBuffer(inds[s][i][MACD_12_26_9], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                        CopyBuffer(inds[s][i][MACD_12_26_9], 1, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start += 2;
                    }
                    
                    if (MA_10 != -1)
                    {    
                        CopyBuffer(inds[s][i][MA_10], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }
                    
                    if (RSI_14 != -1)
                    {
                        CopyBuffer(inds[s][i][RSI_14], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }
                    
                    if (RVI_10 != -1)
                    {
                        CopyBuffer(inds[s][i][RVI_10], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                        CopyBuffer(inds[s][i][RVI_10], 1, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }    
                    else
                    {
                        start += 2;
                    }
                     
                    if (Stochastic_5_3_3 != -1)
                    {
                        CopyBuffer(inds[s][i][Stochastic_5_3_3], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                        CopyBuffer(inds[s][i][Stochastic_5_3_3], 1, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start += 2;
                    }
                    
                    if (TEMA_14 != -1)
                    {
                        CopyBuffer(inds[s][i][TEMA_14], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }
                    
                    if (TriX_14 != -1)
                    {
                        CopyBuffer(inds[s][i][TriX_14], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }
                    
                    if (VIDyA_9_12 != -1)
                    {
                        CopyBuffer(inds[s][i][VIDyA_9_12], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }
                    
                    if (WPR_14 != -1)
                    {
                        CopyBuffer(inds[s][i][WPR_14], 0, newTime, 2 * PREV_TIME_CNT, indBuf);
                        p[start] = indBuf[p];   start++;
                    }
                    else
                    {
                        start ++;
                    }*/
              }
           }
        }
      pos++;
     }

/*CFileTxt file;
    file.Open("p.txt", FILE_WRITE);
    file.Seek(0, SEEK_END);
    for(int i=0; i<ArraySize(rates); ++i)
    {
        for(int j=0; j<numAttr; ++j)
        {
            file.WriteString(DoubleToString(p[i * numAttr + j], 5));
            file.WriteString(", ");
         }
         file.WriteString("\r\n");
    }
    file.Close();*/

   Debug("GetDate End");

   return true;
  }
//+------------------------------------------------------------------+
bool CWekaExpert::GetHpData(datetime &pTime[],datetime nowTime,int &r[],datetime &rTime[])
  {
   Info("Get simulation result.");
   ArrayResize(r,ArraySize(pTime)*BATCH_TP_CNT*BATCH_SL_CNT*BATCH_DEAL_CNT);
   ArrayResize(rTime,ArraySize(pTime)*BATCH_TP_CNT*BATCH_SL_CNT*BATCH_DEAL_CNT);

   MqlRates ratesM1[];
   ArraySetAsSeries(ratesM1,true);
//ArrayFree(ratesM1);
   bool needSave=false;
   int bufferHp[];
   datetime bufferHpTime[];
   ArrayResize(bufferHp,BATCH_DEAL_CNT*BATCH_TP_CNT*BATCH_SL_CNT);
   ArrayResize(bufferHpTime,BATCH_DEAL_CNT*BATCH_TP_CNT*BATCH_SL_CNT);

   for(int t=0; t<ArraySize(pTime);++t)
     {
      m_hpDb.GetHp(pTime[t],bufferHp,bufferHpTime);

      for(int k=0; k<BATCH_DEAL_CNT;++k)
        {
         for(int i=0; i<BATCH_TP_CNT;++i)
           {
            for(int j=0; j<BATCH_SL_CNT;++j)
              {
               int tp = m_classifierInfoIdxs[k][i][j][m_currentHour].Tp();
               int sl = m_classifierInfoIdxs[k][i][j][m_currentHour].Sl();

               Debug("Get simulate of ",IntegerToString(k)+", "+IntegerToString(tp)+", "+IntegerToString(sl),": ",IntegerToString(ArraySize(pTime)));

               int idx=k*BATCH_TP_CNT *BATCH_SL_CNT+
                       i*BATCH_SL_CNT+j;
               if(bufferHp[idx]==-1 || bufferHp[idx]==0xFF
                  || (bufferHp[idx]==1 && bufferHpTime[idx]<=nowTime))
                 {
                  if(ArraySize(ratesM1)==0)
                    {
                     Info("Get simulate M1 data.");

                     int ri= CopyRates(m_symbols[0],PERIOD_M1,pTime[0]-PeriodSeconds(PERIOD_M1),nowTime,ratesM1);
                     if(ri == -1)
                       {
                        Error("Error in get M1 data for simulation. continue.");
                        ErrorCurrentError();
                        continue;
                       }
                    }

                  datetime closeTime;
                  int hp=Simulate(tp,sl,k,pTime[t],nowTime,ratesM1,closeTime);
                  bufferHpTime[idx]=closeTime;
                  needSave=true;
                  if(bufferHp[idx]==1)
                    {
                     Debug("Get simulate result of "+IntegerToString(k)+", "+IntegerToString(tp)+", "+IntegerToString(sl)," at ",TimeToString(pTime[t])," and get hp = ",IntegerToString(hp));
                    }
                  bufferHp[idx]=hp;
                 }
               else
                 {
                  if(bufferHpTime[idx]>=nowTime)
                    {
                     bufferHp[idx]=1;
                    }
                 }
               //Debug(TimeToString(pTimeTrain[t]) + " simulate get " + IntegerToString(rTrain[n1]) + " close at " + TimeToString(closeTime));
              }
            //for(int t=0; t < ArraySize(pTimeTest); ++t)
            //{
            //    datetime closeTime;
            //    rTest[n2] = Simulate(tp, sl, k, pTimeTest[t], nowTime, ratesM1, closeTime);
            //    //Debug(TimeToString(pTimeTest[t]) + " simulate get " + IntegerToString(rTest[n2]) + " close at " + TimeToString(closeTime));
            //    ++n2;
            //}
           }
        }
      ArrayCopy(r,bufferHp,t*BATCH_DEAL_CNT*BATCH_TP_CNT*BATCH_SL_CNT,0);
      ArrayCopy(rTime,bufferHpTime,t*BATCH_DEAL_CNT*BATCH_TP_CNT*BATCH_SL_CNT,0);
      if(needSave)
        {
         m_hpDb.PutHp(pTime[t],bufferHp,bufferHpTime);
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
