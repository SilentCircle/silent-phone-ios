/*
Copyright (C) 2016-2017, Silent Circle, LLC.  All rights reserved.

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
//
//  SCPSettingsManager.m
//  SPi3
//
//  Created by Eric Turner on 11/1/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import "SCPSettingsManager+Advanced.h"

//#import "ChatUtilities.h"
//#import "CTListBase.h"
//#import "SCPCallbackInterface.h"
//#import "SCPTranslateDefs.h"
//#import "SettingsCell.h"
//#import "SCPNotificationKeys.h"
//#import "Prov.h"
//#include <string.h>
//#import "SCPNotificationKeys.h"
//#import "SCSAudioManager.h"
//#import "SCPPasscodeManager.h"
//#import "SCSFeatures.h"
//#import "UserService.h"
//#import "UIViewController+TopMostViewController.h"
//#import "ProviderDelegate.h"

BOOL onChange386(SCSettingsItem *setting);
BOOL onChangeSHA384(SCSettingsItem *setting);
BOOL onChangeAES256(SCSettingsItem *setting);
BOOL onChange386(SCSettingsItem *setting);
BOOL onChangePref2K(SCSettingsItem *setting);
BOOL onChangeDis2K(SCSettingsItem *setting);


extern BOOL onChangeNist(SCSettingsItem *setting); // in SCPSettingsManager

@implementation SCPSettingsManager (Advanced)


- (void)initAdvancedSettings {
    //		loadAccountSection(l);
    [self addSection:@"Account" withSettings:[SCPSettingsManager accountSettings]];
    [self addSection:@"ZRTP" withSettings:[SCPSettingsManager zrtpSettings]];
}

+ (NSArray *)accountSettings {
    NSMutableArray *serverSettings = [NSMutableArray arrayWithArray:@[
          SETTING_TEXT(@"szTitle", @"Account title")
          ,SETTING_ITEM(@"iAccountIsDisabled", @"Enabled", SettingType_Bool, @YES, SettingFlag_Inverse)

          ]];
/* TODO: accountSettings is multiple sections

    // section
    @[SETTING_TEXT(@"un",@"User name")
      ,SETTING_TEXT(@"pwd",@"Password")
      ,SETTING_TEXT(@"tmpServ",@"Domain")
      ,SETTING_TEXT(@"nick",@"Display name")
      ];
 */   
//    CTList *x=addSectionP(n,@"Server settings",NULL);
    NSArray *accountSettings = serverSettings;
    
    return accountSettings;
    
/*
    s=addSectionP(n,@"",NULL);
    CTList *adv=addNewLevelP(s,@"Advanced");
    
    s=addSection(adv,@"ZRTP",NULL);
    i=addItemByKey(s,"iZRTP_On",@"Enable ZRTP");i->sc.onChange=switchOfTunneling;
    i=addItemByKey(s,"iSDES_On",@"Enable SDES");i->sc.onChange=switchOfTunneling;
    i=addItemByKey(s,"iZRTPTunnel_On",@"Enable ZRTP tunneling");i->sc.onChange=switchOnSDES_ZRTP;
    
    s=addSection(adv,@"",NULL);
    addItemByKey(s,"nr",@"SIP user-ID");
    
    s=addSection(adv,@"Network",NULL);
    addItemByKey(s,"szSipTransport",@"SIP transport");
    addItemByKey(s,"uiExpires",@"Reregistration time(s)");
    addItemByKey(s,"bufpxifnat",@"Proxy");//TODO outgoing
    
    addItemByKey(s,"iSipPortToBind",@"SIP Port");
    addItemByKey(s,"iRtpPort",@"RTP Port");
    i=addItemByKey(s,"iDoNotRandomizePort",@"Randomize RTP Port");if(i)i->sc.iInverseOnOff=1;
    
    
    
    
    addItemByKey(s,"iSipKeepAlive",@"Send SIP keepalive");
    addItemByKey(s,"iUseStun",@"Use STUN");
    addItemByKey(s,"bufStun",@"STUN server");
    addItemByKey(s,"iUseOnlyNatIp",@"Use device IP only");
    
    
    
    s=addSection(adv,@"Media",NULL);
    i=addItemByKey(s,"iCanUseP2Pmedia",@"Use media relay");i->sc.iInverseOnOff=1;//disables enables ice
    
    addItemByKey(s,"bufTMRAddr",@"TMR server");
    
    addItemByKey(s,"iResponseOnlyWithOneCodecIn200Ok",@"One codec in 200OK");
    addItemByKey(s,"iPermitSSRCChange",@"Allow SSRC change");
    
    s=addSection(adv,@"Audio",NULL);
    CTList *l2;
    CTList *s2;
    CTList *cod;
    //--------------------->>----
    l2=addNewLevel(s,@"WIFI");
    s2=addSection(l2,@"",NULL);
    cod=addNewLevel(s2,@"Codecs",1);
    
    addCodecKey(cod,"szACodecs",@"Enabled",NULL);
    addCodecKey(cod,"szACodecsDisabled",@"Disabled",NULL);
    
    addItemByKey(s2,"iPayloadSizeSend",@"RTP Packet size(ms)");
    addItemByKey(s2,"iUseVAD",@"Use SmartVAD®");
    //---------------------<<-----
    //---------------------
    l2=addNewLevel(s,@"3G");
    s2=addSection(l2,@"",NULL);
    cod=addNewLevel(s2,@"Codecs",1);
    
    addCodecKey(cod,"szACodecs3G",@"Enabled",NULL);
    addCodecKey(cod,"szACodecsDisabled3G",@"Disabled",NULL);
    
    addItemByKey(s2,"iPayloadSizeSend3G",@"RTP Packet size(ms)");
    addItemByKey(s2,"iUseVAD3G",@"Use SmartVAD®");
    
    
    
    
    //   l2=addNewLevel(s,@"If bad network(TODO)");
    
    
    // addItemByKey(s,"iUseAEC",@"Use software EC");
    
    s=addSection(adv,@"Video",NULL);
    
    CTSettingsItem *liv=addItemByKey(s,"iDisableVideo",@"Video call");//TODO rename
    if(liv)liv->sc.iInverseOnOff=1;
    addItemByKey(s,"iCanAttachDetachVideo",@"Can Add Video");
    
    addItemByKey(s,"iVideoKbps",@"Max Kbps");
    addItemByKey(s,"iVideoFrameEveryMs",@"Frame Interval(ms)");
    addItemByKey(s,"iVCallMaxCpu",@"Max CPU usage %");//TODO can change in call
    
    s=addSection(adv,@"",NULL);
    addItemByKey(s,"iDebug",@"Debug");
    liv=addItemByKey(s,"bCreatedByUser",@"Can reprovision");
    
    if(liv)liv->sc.iInverseOnOff=1;
    
    addItemByKey(s,"iDisableDialingHelper",@"Disable Dialer Helper");
 */
}

+ (NSArray *)zrtpSettings {
    NSMutableArray *zrtpSettings = [NSMutableArray arrayWithArray:@[
        SETTING_ITEM(@"iDisableBernsteinCurve3617", @"ECDH-414", SettingType_Bool, @NO, SettingFlag_Inverse, nil, onChange386)
        ,SETTING_ITEM(@"iDisableBernsteinCurve25519", @"ECDH-255", SettingType_Bool, @NO, SettingFlag_Inverse)
        ,SETTING_ITEM(@"iDisableECDH384", @"NIST ECDH-384", SettingType_Bool, @NO, SettingFlag_Inverse, nil, onChange386)
        ,SETTING_ITEM(@"iDisableECDH256", @"NIST ECDH-256", SettingType_Bool, @NO, SettingFlag_Inverse)
        ,SETTING_ITEM(@"iDisableDH2K", @"DH-2048", SettingType_Bool, @NO, SettingFlag_Inverse, nil, onChangeDis2K)
        ,SETTING_ITEM(@"iPreferDH2K", @"Prefer DH-2048", SettingType_Bool, @NO, 0, nil, onChangePref2K)
        ,SETTING_ITEM(@"iDisableAES256", @"256-bit cipher key", SettingType_Bool, @NO, SettingFlag_Inverse, nil, onChangeAES256)
        ,SETTING_ITEM(@"iEnableSHA384", @"384-bit hash", SettingType_Bool, @NO, 0, nil, onChangeSHA384)
        
        // symmetric algorithms
        ,SETTING_ITEM(@"iDisableTwofish", @"Twofish", SettingType_Bool, @NO, SettingFlag_Inverse)
        ,SETTING_ITEM(@"iDisableSkeinHash", @"Skein", SettingType_Bool, @NO, SettingFlag_Inverse)
        
        // top
        ,SETTING_ITEM(@"iPreferNIST", @"Prefer Non-NIST Suite", SettingType_Bool, @YES, SettingFlag_Inverse, nil, onChangeNist)
        ,SETTING_ITEM(@"iDisable256SAS", @"SAS word list", SettingType_Bool, @YES, SettingFlag_Inverse, nil)

        // mac
        ,SETTING_ITEM(@"iDisableSkein", @"SRTP Skein-MAC", SettingType_Bool, @NO)

        ,SETTING_ITEM(@"iClearZRTPCaches", @"Clear caches", SettingType_Button, nil, SettingFlag_IsLink, @"Use with caution")//, onClickWipeAllData)
    ]];
    return zrtpSettings;
}

BOOL onChange386(SCSettingsItem *setting) {
// TODO: IMPLEMENT THIS
//    const char *p=it->getValue();
//    if(p[0]=='0')return 0;
//    
//    x=(CTSettingsItem *)it->findInSections((void*)"iEnableSHA384", sizeof("iEnableSHA384")-1);
//    if(x)x->setValue("1");
//    
//    x=(CTSettingsItem *)it->findInSections((void*)"iDisableAES256", sizeof("iDisableAES256")-1);
//    if(x)x->setValue("1");//label is inversed
    
    return YES;
}

BOOL onChangeSHA384(SCSettingsItem *setting) {
// TODO: IMPLEMENT THIS
//    CTSettingsItem *x;
//    CTSettingsItem *it=(CTSettingsItem*)pSelf;
//    if(!it)return -1;
//    
//    const char *p=it->getValue();
//    if(p[0]=='1')return 0;
//    
//    
//    CTList *l=(CTList *)it->parent;
//    if(!l)return -2;
//    
//    x=(CTSettingsItem *)it->findInSections((void*)"iDisableECDH384", sizeof("iDisableECDH384")-1);
//    if(x)x->setValue("0");//inv
//    
//    x=(CTSettingsItem *)it->findInSections((void*)"iDisableBernsteinCurve3617", sizeof("iDisableBernsteinCurve3617")-1);
//    if(x)x->setValue("0");//inv
    
    return YES;
}

BOOL onChangeAES256(SCSettingsItem *setting){
// TODO: IMPLEMENT THIS
//    CTSettingsItem *x;
//    CTSettingsItem *it=(CTSettingsItem*)pSelf;
//    if(!it)return -1;
//    
//    const char *p=it->getValue();
//    if(p[0]=='1')return 0;
//    
//    
//    CTList *l=(CTList *)it->parent;
//    if(!l)return -2;
//    
//    x=(CTSettingsItem *)it->findInSections((void*)"iDisableECDH384", sizeof("iDisableECDH384")-1);
//    if(x)x->setValue("0");//inv
//    
//    x=(CTSettingsItem *)it->findInSections((void*)"iDisableBernsteinCurve3617", sizeof("iDisableBernsteinCurve3617")-1);
//    if(x)x->setValue("0");//inv
    
    return YES;
}

BOOL onChangePref2K(SCSettingsItem *setting){
// TODO: IMPLEMENT THIS
//    CTSettingsItem *it=(CTSettingsItem*)pSelf;
//    CTSettingsItem *x;
//    if(!it)return -1;
//    
//    const char *p=it->getValue();
//    if(p[0]=='0')return 0;
//    
//    
//    CTList *l=(CTList *)it->parent;
//    if(!l)return -2;
//    
//    
//    x=(CTSettingsItem *)it->findInSections((void*)"iDisableDH2K", sizeof("iDisableDH2K")-1);
//    if(x)x->setValue("1");//label is inversed
    return YES;
}

BOOL onChangeDis2K(SCSettingsItem *setting){
// TODO: IMPLEMENT THIS
//    CTSettingsItem *it=(CTSettingsItem*)pSelf;
//    CTSettingsItem *x;
//    if(!it)return -1;
//    
//    const char *p=it->getValue();
//    if(p[0]=='1')return 0;
//    
//    CTList *l=(CTList *)it->parent;
//    if(!l)return -2;
//    
//    
//    x=(CTSettingsItem *)it->findInSections((void*)"iPreferDH2K", sizeof("iPreferDH2K")-1);
//    if(x)x->setValue("0");//label is inversed
    return YES;
}

/*
void* getAccountCfg(void *eng);
const char *getAccountTitle(void *pS);
void *findGlobalCfgKey(const char *key);
//const char * getRingtone(const char *p);
const char * getTexttone(const char *p);

// From Release.cpp
//int canAddAccounts(){return 1;}
int canAddAccounts();

////////////////////////////////////////////////////////////////////////

static const int translateType[]={CTSettingsCell::eUnknown,CTSettingsCell::eOnOff,CTSettingsCell::eEditBox,CTSettingsCell::eInt,CTSettingsCell::eInt, CTSettingsCell::eSecure,CTSettingsCell::eUnknown};
static const int translateTypeInt[]={-1,1,0,1,1,0,-1,-1};



static void loadAccountSection(CTList *l);
void addCodecKey(CTList *l, const char *key, NSString *hdr, NSString *footer);
CTList *addAcount(CTList *l, const char *name, int iDel);

int onDeleteAccount(void *pSelf, void *pRetCB);

int switchOfTunneling(void *pSelf, void *pRetCB);
int switchOnSDES_ZRTP(void *pSelf, void *pRetCB);

static void loadAccountSection(CTList *l){
    CTList *as=addSection(l,@" ",@"");
    CTList *ac=addNewLevel(as,@"Accounts");
    CTList *n=addSection(ac,@"Enabled",@"");
    
    int cnt=0;
    
    for(int i=0;i<20;i++){
//                pCurService=getAccountByID(cnt,1);
        pCurService = [Switchboard accountAtIndex:cnt isActive:YES];
        if(pCurService){
            cnt++;
            pCurCfg=getAccountCfg(pCurService);
            const char *title = [[Switchboard titleForAccount:pCurService] UTF8String];
//            addAcount(n,getAccountTitle(pCurService),1);
            addAcount(n,title,1);
        }
    }
    
    cnt=0;
    for(int i=0;i<20;i++){
//        pCurService=getAccountByID(cnt,0);
        pCurService=[Switchboard accountAtIndex:cnt isActive:NO];
        
        if(pCurService){
            if(!cnt)n=addSection(ac,@"Disabled",NULL);
            cnt++;
            pCurCfg=getAccountCfg(pCurService);
            addAcount(n,getAccountTitle(pCurService),1);
        }
    }
    
    //TODO check can we add new account
    if(iCfgOn!=2){
        pCurService=NULL;
        pCurCfg=NULL;
        return;
    }
    
    
    if(canAddAccounts()){
        n=addSection(ac,NULL,NULL);
        
        int createNewAccount(void *pSelf, void *pRet);
//        void *getEmptyAccount();
//        pCurService=getEmptyAccount();
        pCurService = [Switchboard emptyAccount];
        
        if(pCurService){
            pCurCfg=getAccountCfg(pCurService);
            CTList *rr=addAcount(n,"New",0);
            if(rr){
                CTSettingsItem *ri=(CTSettingsItem *)n->getLTail();
                if(ri){
                    ri->sc.pRetCB=NULL;
                    ri->sc.onChange=createNewAccount;
                }
            }
        }
    }
    
    pCurService=NULL;
    pCurCfg=NULL;
}

CTList * addSection(CTList *l, NSString *hdr, NSString *footer, const char *key){
    if(!l)return NULL;
    CTSettingsItem *i = new CTSettingsItem(l);
    l->addToTail(i);
    CTList *nl = i->initSection(hdr,footer);
    
    if(key){
        strcpy(i->sc.key,key);
        i->sc.iKeyLen=(uint32_t)strlen(key);
    }
    i->sc.pCfg=pCurCfg;
    i->sc.pEng=pCurService;
    nl->pUserStorage=l;
    // i->parent=
    return nl;
}

CTList * addNewLevel(CTList *l, NSString *lev, int iIsCodec){
    if(!l)return NULL;
    CTSettingsItem *i=new CTSettingsItem(l);
    l->addToTail(i);
    l=i->initNext(lev);
    if(iIsCodec)i->sc.iType=CTSettingsCell::eCodec;
    i->sc.pCfg=pCurCfg;
    i->sc.pEng=pCurService;
    return l;
}

CTList * addNewLevelP(CTList *l, NSString *lev, int iIsCodec){
    // if(!iCfgOn || !l)return NULL;
    return addNewLevel(l ,lev, iIsCodec);
}

void addChooseKey(CTList *l, const char *key, NSString *label){
    CTSettingsItem *i=new CTSettingsItem(l);
    l->addToTail(i);
    setValueByKey(i,key,label);
    i->sc.iType=CTSettingsCell::eRadioItem;
}

void addReorderKey(CTList *l, const char *key, NSString *label){
    CTSettingsItem *i=new CTSettingsItem(l);
    l->addToTail(i);
    setValueByKey(i,key,label);
    i->sc.iType=CTSettingsCell::eReorder;
    // i->sc.iReleaseLabel=iReleaseLabel;
}

CTSettingsItem* addItemByKey(CTList *l, const char *key, NSString *label){
    if(!l)return NULL;
    CTSettingsItem *i=new CTSettingsItem(l);
    l->addToTail(i);
    i->section = (CTList*)l->pUserStorage;
    setValueByKey(i,key,label);
    return i;
}

static CTSettingsItem* addItemByKeyF(CTList *l, const char *key, NSString *label, NSString *footer){
    
    CTList *n=addSection(l,NULL,footer);
    CTSettingsItem *i=addItemByKey(n,key,label);
    
    return i;
}

CTSettingsItem* addItemByKeyP(CTList *l, const char *key, NSString *label){
    // if(!iCfgOn || !l)return NULL;
    return addItemByKey(l, key, label);
}
 */

/*
void addCodecKey(CTList *l, const char *key, NSString *hdr, NSString *footer){
    if(!l)return;
    l=addSection(l,hdr,footer,key);
#if 1
    char *opt=NULL;
    int iType;
    int iSize;
    void *ret=findCfgItemByServiceKey(pCurService, (char*)key, iSize, &opt, &iType);
    if(ret && ((char*)ret)[0]){
        char bufTmp[256];
        strcpy(bufTmp,(char*)ret);
        int pos=0;
        int iPrevPos=0;
        int iLast=0;
        
        while(!iLast){
            if(pos>=iSize || bufTmp[pos]=='.' || bufTmp[pos]==',' || bufTmp[pos]==0){
                if(pos>=iSize  || bufTmp[pos]==0)iLast=1;
                bufTmp[pos]=0;
                if(isdigit(bufTmp[iPrevPos])){
                    const char *codecID_to_sz(int id);
                    const char *pid=codecID_to_sz(atoi(&bufTmp[iPrevPos]));
                    if(pid)
                        addReorderKey(l,key,[NSString stringWithUTF8String:pid]);
                }
                else{
                    addReorderKey(l,key,[NSString stringWithUTF8String:&bufTmp[iPrevPos]]);
                }
                iPrevPos=pos+1;
            }
            pos++;
        }
        
    }
    
#endif
    
}
*/
/*

CTList *addAcount(CTList *l, const char *name, int iDel){
    
    CTSettingsItem *i;
    CTList *n=addNewLevel(l,[[NSString alloc]initWithUTF8String:name]);
    CTSettingsItem *ac=(CTSettingsItem *)l->getLTail();
    ac->sc.iCanDelete=iDel;
    ac->sc.onDelete=onDeleteAccount;
    
    CTList *x=addSectionP(n,@"Server settings",NULL);
    
    addItemByKey(x,"szTitle",@"Account title");
    CTSettingsItem *ii=addItemByKey(x,"iAccountIsDisabled",@"Enabled");
    if(ii)ii->sc.iInverseOnOff=1;
    
    CTList *s=addSection(n,@"",NULL);
    
    addItemByKeyP(s,"un",@"User name");
    addItemByKeyP(s,"pwd",@"Password");
    addItemByKeyP(s,"tmpServ",@"Domain");
    addItemByKey(s,"nick",@"Display name");
    
    
    s=addSectionP(n,@"",NULL);
    CTList *adv=addNewLevelP(s,@"Advanced");
    
    s=addSection(adv,@"ZRTP",NULL);
    i=addItemByKey(s,"iZRTP_On",@"Enable ZRTP");i->sc.onChange=switchOfTunneling;
    i=addItemByKey(s,"iSDES_On",@"Enable SDES");i->sc.onChange=switchOfTunneling;
    i=addItemByKey(s,"iZRTPTunnel_On",@"Enable ZRTP tunneling");i->sc.onChange=switchOnSDES_ZRTP;
    
    s=addSection(adv,@"",NULL);
    addItemByKey(s,"nr",@"SIP user-ID");
    
    s=addSection(adv,@"Network",NULL);
    addItemByKey(s,"szSipTransport",@"SIP transport");
    addItemByKey(s,"uiExpires",@"Reregistration time(s)");
    addItemByKey(s,"bufpxifnat",@"Proxy");//TODO outgoing
    
    addItemByKey(s,"iSipPortToBind",@"SIP Port");
    addItemByKey(s,"iRtpPort",@"RTP Port");
    i=addItemByKey(s,"iDoNotRandomizePort",@"Randomize RTP Port");if(i)i->sc.iInverseOnOff=1;
   
    
    
    
    addItemByKey(s,"iSipKeepAlive",@"Send SIP keepalive");
    addItemByKey(s,"iUseStun",@"Use STUN");
    addItemByKey(s,"bufStun",@"STUN server");
    addItemByKey(s,"iUseOnlyNatIp",@"Use device IP only");
    
    
    
    s=addSection(adv,@"Media",NULL);
    i=addItemByKey(s,"iCanUseP2Pmedia",@"Use media relay");i->sc.iInverseOnOff=1;//disables enables ice
    
    addItemByKey(s,"bufTMRAddr",@"TMR server");
    
    addItemByKey(s,"iResponseOnlyWithOneCodecIn200Ok",@"One codec in 200OK");
    addItemByKey(s,"iPermitSSRCChange",@"Allow SSRC change");
    
    s=addSection(adv,@"Audio",NULL);
    CTList *l2;
    CTList *s2;
    CTList *cod;
    //--------------------->>----
    l2=addNewLevel(s,@"WIFI");
    s2=addSection(l2,@"",NULL);
    cod=addNewLevel(s2,@"Codecs",1);
    
    addCodecKey(cod,"szACodecs",@"Enabled",NULL);
    addCodecKey(cod,"szACodecsDisabled",@"Disabled",NULL);
    
    addItemByKey(s2,"iPayloadSizeSend",@"RTP Packet size(ms)");
    addItemByKey(s2,"iUseVAD",@"Use SmartVAD®");
    //---------------------<<-----
    //---------------------
    l2=addNewLevel(s,@"3G");
    s2=addSection(l2,@"",NULL);
    cod=addNewLevel(s2,@"Codecs",1);
    
    addCodecKey(cod,"szACodecs3G",@"Enabled",NULL);
    addCodecKey(cod,"szACodecsDisabled3G",@"Disabled",NULL);
    
    addItemByKey(s2,"iPayloadSizeSend3G",@"RTP Packet size(ms)");
    addItemByKey(s2,"iUseVAD3G",@"Use SmartVAD®");
    
    
    
    
    //   l2=addNewLevel(s,@"If bad network(TODO)");
    
    
    // addItemByKey(s,"iUseAEC",@"Use software EC");
    
    s=addSection(adv,@"Video",NULL);
    
    CTSettingsItem *liv=addItemByKey(s,"iDisableVideo",@"Video call");//TODO rename
    if(liv)liv->sc.iInverseOnOff=1;
    addItemByKey(s,"iCanAttachDetachVideo",@"Can Add Video");
    
    addItemByKey(s,"iVideoKbps",@"Max Kbps");
    addItemByKey(s,"iVideoFrameEveryMs",@"Frame Interval(ms)");
    addItemByKey(s,"iVCallMaxCpu",@"Max CPU usage %");//TODO can change in call
    
    s=addSection(adv,@"",NULL);
    addItemByKey(s,"iDebug",@"Debug");
    liv=addItemByKey(s,"bCreatedByUser",@"Can reprovision");
    
    if(liv)liv->sc.iInverseOnOff=1;
    
    addItemByKey(s,"iDisableDialingHelper",@"Disable Dialer Helper");
    
    
    //   addItemByKey(s,"iIsTiViServFlag",@"Is Tivi server?");
    
    return n;
}

void setValueByKey(CTSettingsItem *i, const char *key, NSString *label){
    
    CTSettingsCell *sc=&i->sc;
    char *opt=NULL;
    int iType;
    int iSize;
    
    {
        char bufTmp[64];
        int iKeyLen=(uint32_t)strlen(key);
        void *ret=findCfgItemByServiceKey(pCurService, (char*)key, iSize, &opt, &iType);
        
       bufTmp[0]=0;
        
        if(ret){
            
            sc->iType=translateType[iType];
            sc->iPhoneEngineType=iType;;
            sc->iIsInt=translateTypeInt[iType];
            
            if(opt){strncpy(sc->bufOptions,opt,sizeof(sc->bufOptions));sc->bufOptions[sizeof(sc->bufOptions)-1]=0;}
            
            if(sc->iType==CTSettingsCell::eInt || sc->iType==CTSettingsCell::eOnOff){
                sprintf(bufTmp,"%d",*(int*)ret);
                ret=&bufTmp[0];
            }
            if(sc->bufOptions[0]){
                sc->iType=CTSettingsCell::eChoose;
            }
            
            if(i->sc.iType==CTSettingsCell::eChoose){
                static int iRecursiveSkip=0;
                if(!iRecursiveSkip){
                    iRecursiveSkip=1;
                    CTList *l = i->parent;
                    i->root = new CTList();
                    l = addSection(i->root,NSLocalizedString(@"Choose", nil),NULL);
                    //char bufTmp[sizeof(i->sc.bufOptions)+1];
                    //strncpy(bufTmp,i->sc.bufOptions,sizeof(i->sc.bufOptions));bufTmp[sizeof(bufTmp)-1]=0;
                    char *bufTmp=opt;
                    int pos=0;
                    int iPrevPos=0;
                    int iLast=0;
                    while(!iLast){
                        if(bufTmp[pos]==',' || bufTmp[pos]==0){
                            if(bufTmp[pos]==0)iLast=1;
                            //bufTmp[pos]=0;
                            addChooseKey(l,key,[NSString stringWithFormat:@"%.*s",pos-iPrevPos, &bufTmp[iPrevPos]]);
                            iPrevPos=pos+1;
                        }
                        pos++;
                    }
                    iRecursiveSkip=0;
                }
                
            }
            
//            if(sc->value)[sc->value release];
            sc->value=[[NSString alloc]initWithUTF8String:(const char *)ret];
        }
        
        //  else sc->value=nil;
        
        sc->setLabel(label);
        strcpy(sc->key,key);
        sc->iKeyLen=iKeyLen;
        sc->pCfg=pCurCfg;
        sc->pEng=pCurService;
    }
    
}
*/

/*
int onDeleteAccount(void *pSelf, void *pRetCB){
    CTSettingsItem *it=(CTSettingsItem*)pSelf;
    if(!it || !it->sc.pEng)return -1;
    
//    sendEngMsg(it->sc.pEng,"delete");
    [Switchboard sendEngMsg:it->sc.pEng msg:@"delete"];
    
    return 0;
}

int switchOfTunneling(void *pSelf, void *pRetCB)
{
    CTSettingsItem *x;
    CTSettingsItem *it=(CTSettingsItem*)pSelf;
    if(!it)return -1;
    
    const char *p=it->getValue();
    if(p[0]=='1')return 0;
    
    
    CTList *l=(CTList *)it->parent;
    if(!l)return -2;
    
    x=(CTSettingsItem *)l->findItem((void*)"iZRTPTunnel_On", sizeof("iZRTPTunnel_On")-1);
    if(x)x->setValue("0");//inv
    
    return 2;
}

int switchOnSDES_ZRTP(void *pSelf, void *pRetCB){
    CTSettingsItem *x;
    CTSettingsItem *it=(CTSettingsItem*)pSelf;
    if(!it)return -1;
    
    const char *p=it->getValue();
    if(p[0]=='0')return 0;
    
    
    CTList *l=(CTList *)it->parent;
    if(!l)return -2;
    
    x=(CTSettingsItem *)l->findItem((void*)"iSDES_On", sizeof("iSDES_On")-1);
    if(x)x->setValue("1");//inv
    
    x=(CTSettingsItem *)l->findItem((void*)"iZRTP_On", sizeof("iZRTP_On")-1);
    if(x)x->setValue("1");//inv
    
    return 2;
}
*/
@end
