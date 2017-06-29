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
//  SCPCallManager+Utilities.m
//  SCPSwitchboard
//
//  Created by Eric Turner on 5/27/15.
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

#ifndef NULL
#ifdef  __cplusplus
#define NULL    0
#else
#define NULL    ((void *)0)
#endif
#endif


#import "SCPCallManager+Utilities.h"
#import "SCPCallManagerUtilities_Private.h"

#import "SCPCall.h"
#import "SCPCallbackInterface.h"
#import "SCPCallbackInterfaceUtilities_Private.h"
#import "SCPPrivateKeys.h"

#import "engcb.h"

// Note: Country.txt should be included in the bundle.
static NSString * const kCountryCodesFileName = @"Country";
static NSString * const kCountryCodesFileExt = @"txt";


@implementation SCPCallManager (Utilities)


- (void)initCountryCodes {
    NSString *path = [[NSBundle mainBundle] pathForResource:kCountryCodesFileName ofType:kCountryCodesFileExt];
    NSData *data = [NSData dataWithContentsOfFile:path];
    initCC((char *)data.bytes, (int)data.length);
}

// formats given call number if needed
- (NSString *)getFormattedCallNumber:(NSString *)ns {
   
    if(!ns)return @"";
   
    char buf[64];
    if(fixNR(ns.UTF8String,&buf[0],63)){
        return [NSString stringWithUTF8String:&buf[0]];
    }
    return ns;
}

- (NSString *)getLastCalledNumber {
    return [[NSUserDefaults standardUserDefaults] valueForKey:kSCPLastCalledNumberKey];
}

- (void)saveLastCalledNumber:(NSString *)nr {
    if (nr && nr.length > 0) {
        [[NSUserDefaults standardUserDefaults] setValue:nr forKey:kSCPLastCalledNumberKey];
    }
}

@end

int isSDESSecure(int iCallId, int iVideo){
    int v=0;
    if(getCallInfo(iCallId,iVideo?"media.video.zrtp.sec_state": "media.zrtp.sec_state", &v)==0 && v & 0x100)
        return 1;
    return 0;
}

class CRESET_SEC_STEATE{
public:
    CRESET_SEC_STEATE(void *ret, void *ph, int iCallID, int iIsVideo, SCPCall *c)
    :ret(ret),ph(ph),iCallID(iCallID),iIsVideo(iIsVideo),c(c){
    }
    void *ret;
    void *ph;
    int iCallID;
    int iIsVideo;
    SCPCall *c;
};

void checkSDES(SCPCall *c, void *ret, void *ph, int iCallID, int msgid){
    if(!c || c.iEnded)return ;
    
    int iSDESSecure=0;
    int iErr=0;
    int iVideo=0;
    
    switch(msgid){
        case CT_cb_msg::eZRTPErrA: iSDESSecure=::isSDESSecure(iCallID, 0);iErr=1;break;
        case CT_cb_msg::eZRTPErrV: iSDESSecure=::isSDESSecure(iCallID, 1);iErr=1;iVideo=1;break;
        case CT_cb_msg::eZRTPMsgV: iVideo=1;
        case CT_cb_msg::eZRTPMsgA:
            if(strcmp(iVideo? c.bufSecureMsgV.UTF8String :c.bufSecureMsg.UTF8String,"ZRTP Error")==0)
                iErr=1;
            
            if(!iErr)return ;
            
            iSDESSecure=::isSDESSecure(iCallID, iVideo);
            
            break;
            
        default:
            return;
    }
    if(!iSDESSecure)return ;
    
    if(c->iReplaceSecMessage[iVideo])return;
    c->iReplaceSecMessage[iVideo]=1;
    
    CRESET_SEC_STEATE *rs = new CRESET_SEC_STEATE(ret,ph,iCallID, iVideo,c);
    
    void startThX(int (cbFnc)(void *p),void *data);
    int resetSecStateTH(void *p);
    startThX(resetSecStateTH, rs);
    
    return ;
}

int resetSecStateTH(void *p){
    
    CRESET_SEC_STEATE *rs = (CRESET_SEC_STEATE*)p;
    for(int i=0;i<5;i++){
        sleep(1);
        if(!rs || !rs->c || rs->c.iEnded || rs->c.iCallId!=rs->iCallID)return 0;
    }
    
    int iSDESSecure=::isSDESSecure(rs->iCallID, rs->iIsVideo);
    if(!iSDESSecure)return 0;
    
    [SPCallManager handleFncCallback:rs->ret 
                                  ph:rs->ph 
                             iCallID:rs->iCallID 
                               msgid:rs->iIsVideo? CT_cb_msg::eZRTPMsgV : CT_cb_msg::eZRTPMsgA
                                  ns:@"SECURE SDES"];

    return 0;
}

