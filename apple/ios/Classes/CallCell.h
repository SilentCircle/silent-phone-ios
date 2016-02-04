/*
Copyright (C) 2012, Tivi LTD, www.tiviphone.com. All rights reserved.
Copyright (C) 2012-2015, Silent Circle, LLC.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Any redistribution, use, or modification is done solely for personal
      benefit and not for any commercial purpose or for monetary gain
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name Silent Circle nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SILENT CIRCLE, LLC BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <UIKit/UIKit.h>

#define _T_WO_GUI
#include "../../../baseclasses/CTEditBase.h"
@class CallCell;

const char *tg_translate(const char *key, int iKeyLen);
#define T_TR(_T_KEY) tg_translate(_T_KEY, sizeof(_T_KEY)-1)
#define T_TRL(_T_KEY, _T_KL) tg_translate(_T_KEY, _T_KL)
#define T_TRNS(_T_KEY) [NSString stringWithUTF8String:tg_translate(_T_KEY, sizeof(_T_KEY)-1)]
#define T_TRNSL(_T_KEY, _T_KL) [NSString stringWithUTF8String:tg_translate(_T_KEY, _T_KL)]
/*
typedef struct{
   int iShowVerifySas;
   int iShowEnroll;
   int iShowWarningForNSec;
}T_CALL_DATA;
*/

unsigned int getTickCount();
int getCallInfo(int iCallID, const char *key, char *p, int iMax);


class CTCall{
   int iIsNameFromSipChecked;
public:
   CTCall(){iUserDataLoaded=0;img=nil;reset();}
   
   void reset(){

      if(img && (iUserDataLoaded==2 || iUserDataLoaded==4)){
        // 
         iUserDataLoaded=0;
         int rc=(int)[img retainCount];
         printf("[%p rc=%d %d]",img,rc,iImgRetainCnt);void freemem_to_log();freemem_to_log();
         while(iImgRetainCnt>0){
            iImgRetainCnt--;
            [img release];
         }
         printf("[rel img ok]");freemem_to_log();
      }
      img=nil;

      nameFromAB.reset();
      zrtpWarning.reset();
      zrtpPEER.reset();
      
      incomCallPriority.reset();
      
      iIsNameFromSipChecked=0;
      memset(bufDialed,0,sizeof(bufDialed));
      memset(bufServName,0,sizeof(bufServName));
      memset(bufPeer,0,sizeof(bufPeer));
      memset(bufMsg,0,sizeof(bufMsg));

      memset(bufSAS,0,sizeof(bufSAS));
      memset(bufSecureMsg,0,sizeof(bufSecureMsg));
      memset(bufSecureMsgV,0,sizeof(bufSecureMsgV));
      
      iShowVideoSrcWhenAudioIsSecure=0;
      iDontAddMissedCall=0;
      uiStartTime=0;
      iInUse=0;
      iDuration=0;
      iIsIncoming=0;
      iActive=0;
      iEnded=0;
      iIsOnHold=0;
      iIsInConferece=0;
      iMuted=0;
      iSipHasErrorMessage=0;
      iRecentsUpdated=0;
      iUserDataLoaded=0;
      uiRelAt=0;
      uiEndedAt=0;
      iCallId=0;
      pEng=NULL;
      iImgRetainCnt=0;
      cell=NULL;
      
      iShowEnroll=iShowWarningForNSec=iShowVerifySas=0;
      
      iZRTPPopupsShowed=0;
      iZRTPShowPopup=0;
      iIsZRTPError=0;
      iReplaceSecMessage[0]=iReplaceSecMessage[1]=0;
      szPeerAssertedUsername[0]=0;

   }
   
   UIImage *img;//TODO void *userDataFromGui;
   CTEditBuf<128> zrtpWarning;
   CTEditBuf<128> zrtpPEER;
   CTEditBuf<128> nameFromAB;//or from sip
   char szPeerAssertedUsername[64];
   
   CTEditBuf<32> incomCallPriority;
    
    NSString *getUsernameFromCall(){
        findAssertedName();
        NSString * contactUsername = [NSString stringWithUTF8String:& szPeerAssertedUsername[0]];
        if(!szPeerAssertedUsername[0]){
            char *p = &bufPeer[0];
            if(!p[0])p = &bufDialed[0];
            
            if(strncmp(p,"sip:",4)==0) p+=4;
            if(isalpha(p[0])){
                contactUsername = [NSString stringWithUTF8String:p];
            }
        }
        return contactUsername;
    }

   int sipDispalyNameEquals(CTEditBase &e){
      char bufRet3[128];
      int l=getCallInfo(iCallId,"peername", bufRet3,127);
      if(l<=0 || l>127)return 0;
      bufRet3[l]=0;
      
      if(l>0)findAssertedName();
      
      return e==bufRet3;
   }
   int findAssertedName(){
      if(szPeerAssertedUsername[0])return 1;
      if(!iInUse)return 0;
      if(!iIsIncoming && !iCallId)return 0;
      
      int l=getCallInfo(iCallId,"AssertedId", szPeerAssertedUsername,sizeof(szPeerAssertedUsername)-1);
      return l;
   }
   
   int findSipName(){
      //?? VISS ir labi ,bet kapeec PRZ tas neiet? parbaudiit kapeec pirms calling nav ab match
      if(iIsNameFromSipChecked || nameFromAB.getLen())return 0;
      
      char bufRet3[128];
      int l=getCallInfo(iCallId,"peername", bufRet3,127);
      if(l>0){
         nameFromAB.setText(bufRet3,l);
         findAssertedName();
      }
      iIsNameFromSipChecked=1;
      return 1;
   }
   
   
   inline int mustShowAnswerBT(){
      return iInUse && iIsIncoming && !iEnded && !iActive;
   }
   
   void setPeerName(const char *p, int iLen){
      if(!iInUse){
         NSLog(@"Err call !iInUse");
         return ;
      }
      int ml=sizeof(this->bufPeer)-1;
      
      if(!p){p="Err";iLen=3;}
      if(iLen==0)iLen=(int)strnlen(p, ml);
      if(p && strncmp(p,"sip:",4)==0){p+=4;iLen-=4;}
      else if(p && strncmp(p,"sips:",5)==0){p+=5;iLen-=5;}
      
      safeStrCpy(&this->bufPeer[0], p, min(iLen, ml));
   }
   
   int setSecurityLines(UILabel *lb, UILabel *lbDesc, int iIsVideo=0){
      
      char *pSM = iIsVideo? &bufSecureMsgV[0] : &bufSecureMsg[0];
      
      char bufTmp[64];
      strncpy(bufTmp, pSM, 63);
      bufTmp[63]=0;
      pSM=&bufTmp[0];
      
      
      const char *pNotSecureSDES = "Not SECURE SDES without TLS";
      const char *pNotSecure_no_c_e = "Not SECURE no crypto enabled";
      
      int iSecDisabled = strcmp(pSM, pNotSecure_no_c_e)==0;
      int iSecureViaSDES = !iSecDisabled && strcmp(pSM,"SECURE SDES")==0;

      if(iSecureViaSDES)strcpy(pSM, "SECURE to server");
      
      
      if(iSecureViaSDES){
         const char* sendEngMsg(void *pEng, const char *p);
         const char *p=sendEngMsg(pEng,".isTLS");
         if(!(p && p[0]=='1')){
            strcpy(pSM,pNotSecureSDES);
         }
      }
      
      char bufTmpS[64]="";
      int iSecureInGreen=0;
      
#define NOT_SECURE "Not SECURE"
#define NOT_SECURE_L (sizeof(NOT_SECURE)-1)
      
#define T_SECURE "SECURE"
#define T_SECURE_L (sizeof(T_SECURE)-1)
      
      if(strncmp(pSM,T_SECURE,T_SECURE_L)==0){
         int  isSilentCircleSecure(int cid, void *pEng);
         iSecureInGreen=!iSecureViaSDES && isSilentCircleSecure(iCallId, pEng);
         int l=strlen(pSM);
         if(l>T_SECURE_L && !iSecureInGreen){
            strcpy(bufTmpS,&pSM[T_SECURE_L]);
         }
         if(lbDesc)bufTmp[T_SECURE_L]=0;//if we have only one label - dont zero terminate
         if(iSecureInGreen){
            bufTmpS[0]=0;
         }
      }
      else if(strncmp(pSM, NOT_SECURE, NOT_SECURE_L)==0){
         strcpy(bufTmpS,&pSM[NOT_SECURE_L]);
         if(lbDesc)bufTmp[NOT_SECURE_L]=0;//if we have only one label - dont zero terminate
      }
      if (lbDesc)
         [lbDesc setText:T_TRNSL(bufTmpS,0)];

      [lb setText:T_TRNSL(bufTmp,0)];
      
      UIColor *col = iSecureInGreen ? [UIColor greenColor]:(iSecureViaSDES ? [UIColor yellowColor]: [UIColor whiteColor] );
      [lb setTextColor:col];
      
      return iSecureInGreen;
   }
   
   
   int iShowEnroll,iShowVerifySas,iShowWarningForNSec;
   
   char bufDialed[128];
   char bufPeer[128];
   char bufServName[128];
   char bufMsg[512];
   char bufSAS[64];
   char bufSecureMsg[64];

   char bufSecureMsgV[64];
   
   char szSIPCallId[64];//storing SIP call-id here, we need this to identify this call in a log
   
   int iInUse;
   
   unsigned int uiStartTime;
   int iDuration;
   int iTmpDur;
   
   int iIsIncoming;
   int iActive;
   int iEnded;
   int iDontAddMissedCall;
   unsigned int uiEndedAt;
   int iIsOnHold;
   int iMuted;
   
   int iIsVideo;
   
   int iShowVideoSrcWhenAudioIsSecure;
   
   int iIsInConferece;
   
   int iSipHasErrorMessage;
   
   int iRecentsUpdated;
   int iUserDataLoaded;
   
   unsigned int uiRelAt;
   
   int iCallId;//from eng
   void *pEng;
   
   
   int iImgRetainCnt;
   
   int iZRTPPopupsShowed,iZRTPShowPopup,iIsZRTPError;
   int iReplaceSecMessage[2];//audio,video
   
   CallCell *cell;///tmp
   
   int isDisappearing(){return uiEndedAt && iEnded && (int)(getTickCount()-uiEndedAt)<800;}
};
#define T_MAX_CALLS 21



class CTCalls{
   int iLocked;
public:
   CTCall *curCall;
   enum{eConfCall, ePrivateCall, eStartupCall};
   
   void syncCallsWithEng(){
      //warn if probl deteced
   }
   
   
   CTCalls(){
      for(int i=0;i<T_MAX_CALLS;i++)calls[i].reset();
   }
   ~CTCalls(){
      
   }
   void lock(){
      int n=0;
      //TODO mutex
      while(iLocked>0){n++;usleep(1000);if(n>1000)break;}
      iLocked++;
   }
   void unLock(){
      iLocked--;
      if(iLocked<0){
         NSLog(@"c m err");
      }
   }
   
   void relCallsNotInUse(){
      lock();
      unsigned int ui=getTickCount();
      
      for(int i=0;i<T_MAX_CALLS;i++){
         int d=(int)(ui-calls[i].uiRelAt);
         if(d>5000 && calls[i].iInUse && calls[i].uiRelAt){
            calls[i].reset();
         }
      }
      unLock();
   }
   
   void init(){
      iLocked=0;
      iCurrentCallID=0;
      for(int i=0;i<T_MAX_CALLS;i++)calls[i].reset();
      curCall=NULL;
   }
   void setCurCall(CTCall *c){
      curCall=c;
   }
   
   static inline int isCallType(CTCall *c, int iType){
      if(!c->iInUse /*|| c->iRecentsUpdated || c->uiRelAt*/)return 0;
      int iEnded = c->iEnded && !c->isDisappearing();
      if(iType==eConfCall && !iEnded && c->iActive && c->iIsInConferece)return 1;
      if(iType==ePrivateCall && !iEnded && c->iActive && !c->iIsInConferece)return 1;
      if(iType==eStartupCall && !iEnded && !c->iActive)return 1;
      return 0;
   }
   
   CTCall* getCall(int ofs){
      int n=0;
      for(int i=0;i<T_MAX_CALLS;i++){
         if(isCallType(&calls[i],eConfCall) || isCallType(&calls[i],ePrivateCall)){
            if(n==ofs)return &calls[i];
            n++;
         }
      }
      return  0;
   }
    
   
   CTCall* getCall(int iType, int ofs){
      int n=0;
      for(int i=0;i<T_MAX_CALLS;i++){
         if(isCallType(&calls[i],iType)){
            if(n==ofs)return &calls[i];
            n++;
         }
      }
      return  0;
   }

   int getCallCnt(int iType){
      int n=0;
      for(int i=0;i<T_MAX_CALLS;i++){
         if(isCallType(&calls[i],iType))n++;
      }
      return n;
   }
   int videoCallsActive(CTCall *c=NULL){
      int isVideoCall(int iCallID);
      int n=0;
      for(int i=0;i<T_MAX_CALLS;i++){
         if(c!=&calls[i] && calls[i].iInUse && !calls[i].iEnded && !calls[i].uiRelAt && isVideoCall(calls[n].iCallId))n++;
      }
      
      return n;
   }
  
   int getCallCnt(){
      int n=0;
      for(int i=0;i<T_MAX_CALLS;i++){
         if(calls[i].iInUse && !calls[i].iEnded  && !calls[i].uiRelAt)n++; //calls[i].isDisappearing() ??
      }
      if(!n)curCall=NULL;
      return n;
   }
   int getCallCntIncudeDisappearing(){
      int n=0;
      for(int i=0;i<T_MAX_CALLS;i++){
         if(calls[i].iInUse && (!calls[i].iEnded ||  calls[i].isDisappearing()))n++; //calls[i].isDisappearing() ??
      }
      if(!n)curCall=NULL;
      return n;
   }
   CTCall* getLastCall(){
      
      CTCall *c=NULL;
      for(int i=0;i<T_MAX_CALLS;i++){
         if(calls[i].iInUse && !calls[i].iEnded &&  !calls[i].uiRelAt){c=&calls[i];break;}
      }
      return c;
   }
   CTCall *getEmptyCall(int iIsMainThread){
      lock();
      unsigned int ui=getTickCount();
      int rc=0;

      for(int i=0;i<T_MAX_CALLS;i++){
         int d=(int)(ui-calls[i].uiRelAt);//loops ui>0xffff fffa
         if(d<0)d=-d;
         if(calls[i].iInUse && calls[i].uiRelAt && d>10000){
            if(iIsMainThread)calls[i].reset();
            calls[i].iInUse=0;calls[i].uiRelAt=0;
            rc++;
            //TODO rel img
         }
      }
   
      if(iCurrentCallID>=T_MAX_CALLS)iCurrentCallID=T_MAX_CALLS;
      
      for(int i=iCurrentCallID;i<T_MAX_CALLS;i++){
         if(!calls[i].iInUse){
            calls[i].reset();
            calls[i].iInUse=1;
            iCurrentCallID=i+1;
            unLock();
            return &calls[i]; 
         }
         
      }
      for(int i=0;i<iCurrentCallID;i++){
         if(!calls[i].iInUse){
            calls[i].reset();
            calls[i].iInUse=1;
            iCurrentCallID=i+1;
            unLock();
            return &calls[i]; 
         }
      }
      for(int i=iCurrentCallID;i<T_MAX_CALLS;i++){
         if(!calls[i].iInUse){
            calls[i].reset();
            calls[i].iInUse=1;
            iCurrentCallID=i+1;
            unLock();
            return &calls[i]; 
         }
         
      }
      unLock();
      return NULL;
   }
private:
   int charsMatch(const char *a, int iALen, const char *bSZ){
      int n=0;
      if(!bSZ[0])return 0;
    
       if(iALen>4 && strncmp(a,"sip:",4)){
           bSZ+=4;
           iALen-=4;
       }
       if(iALen>4 && strncmp(bSZ,"sip:",4)){
           bSZ+=4;

       }
      int ibzlen = (int)strlen(bSZ);
    
      
      if(ibzlen==iALen && strncmp(a,bSZ,iALen)==0)return 0x7fffffff;
      if(ibzlen<iALen && strncmp(a,bSZ,ibzlen)==0 && a[ibzlen]=='@')return 0x7ffffffe;
      
      for(int i=0;i<iALen;i++){
         
         if(a[i]=='@'){ break;}
         
         if(a[i]==bSZ[0]){
            n++;
            do{
               if(!bSZ[0] || bSZ[0]=='@')break;
               bSZ++;
            }while(!isalnum(*bSZ));
            
            if(!bSZ[0] || bSZ[0]=='@')break;
         }
      }
      return n;
   }
public:
   
   CTCall *findCallByNumberAndNoCallID(const char *nr, int iNrLen){
      
      CTCall *c=NULL;
      int iCharsMatch=0;
      
       for(int i=0;i<T_MAX_CALLS;i++){
          if(calls[i].iInUse && calls[i].bufDialed[0] && calls[i].iCallId==0 && !calls[i].iEnded){
             int cm = charsMatch(nr, iNrLen, &calls[i].bufDialed[0]);
             if(!c || cm>iCharsMatch){
                c=&calls[i];
                iCharsMatch = cm;
             }
          }
       }
       return c;
      
   }
    
    CTCall *findCallByNumber(const char *nr){
        
        if(!nr)return NULL;
        CTCall *c=NULL;
        int iCharsMatch=0;
        int iNrLen = (int)strlen(nr);
        
        for(int i=0;i<T_MAX_CALLS;i++){
            if(calls[i].iInUse && !calls[i].iEnded){
                int cm1 = charsMatch(nr, iNrLen, &calls[i].bufDialed[0]);
                int cm2 = charsMatch(nr, iNrLen, &calls[i].bufPeer[0]);
                int cm = charsMatch(nr, iNrLen, &calls[i].szPeerAssertedUsername[0]);
                if(cm1<cm)cm = cm1;
                if(cm2<cm)cm = cm2;
                
                if(cm>iCharsMatch && cm>0){//MOSTLY WORKS
                    c=&calls[i];
                    iCharsMatch = cm;
                }
            }
        }
        return c;
        
    }
   
   CTCall *findCallById(int iCallId){

      if(!iCallId)return NULL;
      
      int i;
      for(i=iCurrentCallID;i<T_MAX_CALLS;i++){
         if(calls[i].iInUse && iCallId==calls[i].iCallId && !calls[i].iEnded){
            return &calls[i];
         }
      }
      for(i=0;i<iCurrentCallID;i++){
         if(calls[i].iInUse && iCallId==calls[i].iCallId && !calls[i].iEnded){
            return &calls[i];
         }
      }
      for(i=0;i<T_MAX_CALLS;i++){
         if(calls[i].iInUse && iCallId==calls[i].iCallId){
            return &calls[i];
         }
      }
      return NULL;
   }
   
   
private:
   CTCall calls[T_MAX_CALLS];
   int iCurrentCallID;
   
};




@interface CallCell : UITableViewCell
@property CTCall *cTCall; 

@property (retain, nonatomic) IBOutlet UIButton *sas;
@property (retain, nonatomic) IBOutlet UILabel *lbZRTP;
@property (retain, nonatomic) IBOutlet UILabel *uiName;
@property (retain, nonatomic) IBOutlet UIButton *uiEndCallBt;
@property (retain, nonatomic) IBOutlet UIImageView *uiImg;
@property (retain, nonatomic) IBOutlet UIButton *uiAnswerBt;
@property (retain, nonatomic) IBOutlet UILabel *uiDstNr;
@property (retain, nonatomic) IBOutlet UIImageView *uiBacgrImg;



@end
