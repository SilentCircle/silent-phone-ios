/*
Copyright (C) 2013-2017, Silent Circle, LLC.  All rights reserved.

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
//  SCPCall.m
//  SilentConference
//
//  Created by mahboud on 11/15/13.
//  Update by Eric Turner and Janis Narbuts, 2015/2016
//  Copyright (c) 2013 - 2016 Silent Circle. All rights reserved.
//

#ifndef NULL
#ifdef  __cplusplus
#define NULL    0
#else
#define NULL    ((void *)0)
#endif
#endif

#import "SCPCall.h"

#import "ChatUtilities.h"
#import "engcb.h"
#import "SCPCallbackInterface.h"
#import "SCPCallManager.h"
#import "SCPCallManager+Utilities.h"
#import "SCPTranslateDefs.h"
#import "SCSContactsManager.h"
#import "AddressBookContact.h"
#import "SCPNotificationKeys.h"

@implementation SCPCall
{
    // private ivars
    int iIsNameFromSipChecked;
    int iPhoneBookChecked;
    
    NSString *_alias;
}

@synthesize bufMsg=_bufMsg;

- (instancetype)init {
    
    if(self = [super init]) {
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(contactsUpdated:)
                                                     name:SCSContactsManagerAddressBookRefreshedNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)contactsUpdated:(NSNotification *)notification {
    
    if(!iPhoneBookChecked)
        return;
    
    iPhoneBookChecked = NO;
    
    [self tryFindPerson];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSCPCallStateDidChangeNotification
                                                        object:self];
}

// show answer button
-(BOOL)isIncomingRinging{
   return self.isIncoming && !self.isAnswered && !self.isEnded;
}

// these are ringing calls, dialing calls, calls that have not yet been answered
-(BOOL)isInProgress {
	return !self.isAnswered && !self.isEnded;
}

-(NSString *)getBufAssertedID{
   if(_bufAssertedID.length>0)return _bufAssertedID;
   
   _bufAssertedID = [self callInfoForKey:@"AssertedId"];
   
   return _bufAssertedID;
}

-(BOOL)hasVideo{
   int isVideoCall(int iCallID);
   return isVideoCall(_iCallId) ? YES : NO;
}

-(void)setBufPeer:(NSString*)ns{
   
   if(!ns)return;
   
   if([ns.lowercaseString hasPrefix:@"sip:"]) ns = [ns substringFromIndex:4];
   else if([ns.lowercaseString hasPrefix:@"sips:"]) ns = [ns substringFromIndex:5];
   _bufPeer = nil;
   _bufPeer = ns;
   
}

- (NSString *)bufMsg {
    return [_bufMsg copy];
}

-(void)setBufMsg:(NSString *)msg {
    _bufMsg = nil;
   
    if(msg.length > 4 && isdigit(msg.UTF8String[0]) && !self.isAnswered && !self.isIncoming){
       _iSIPErrorCode = atoi(msg.UTF8String);
       if(!_didRecv180 && (_iSIPErrorCode==480 || _iSIPErrorCode==408)){
          msg = NSLocalizedString(@"User not online", nil);
       }
       else {
          msg = [NSString stringWithUTF8String:msg.UTF8String+4];//remove 3 digits and space
       }
    }
   
//    const char *tg_translate(const char *key, int iKeyLen);
//    _bufMsg = [NSString stringWithUTF8String:tg_translate(msg.UTF8String, (int)msg.length)];
    
    _bufMsg = NSLocalizedString(msg, nil);
    
    [self getBufAssertedID];//we should get this as soon as posible
}

-(UIImage *)callerImage{
   [self tryFindPerson];
   return _callerImage;
}

//replaces findName function in AppDelegate
-(NSString*)getName{
   
   [self tryFindPerson];
   if(_nameFromAB && _nameFromAB.length > 0)return _nameFromAB;
   if(_nameFromWeb && _nameFromWeb.length > 0)return _nameFromWeb;
   
   return [self displayNumber];//TODO tmp
}

-(NSString*)displayNumberPriv{
   if(_bufDialed)return _bufDialed;
   NSString *nr = [[ChatUtilities utilitiesInstance] removePeerInfo:_bufPeer lowerCase:NO];
   //[_bufPeer componentsSeparatedByString:@"@"];//remove server addr
    
   //if(nr && nr.count) return [nr objectAtIndex:0];
   return nr;
}

- (void)setAlias:(NSString *)alias {
    
    _alias = alias;
}

-(NSString *)alias {
    
   if(_alias && _alias.length > 0)
       return _alias;
    
   NSString *ns = [self callInfoForKey:@"x-sc-alias"];
    
   if(!ns || ns.length < 1)
       return _alias;
   
   NSArray *a = [ns componentsSeparatedByString:@";"];
    
   if(!a || a.count<2)
       return _alias;
   
    NSString *tempAlias = a[0];

    NSString *prefixToRemove = @"X-SC-Display-Alias: ";
    
    if ([tempAlias hasPrefix:prefixToRemove])
        tempAlias = [tempAlias substringFromIndex:[prefixToRemove length]];

    _alias = tempAlias;

    return _alias;
}

-(NSString*)displayNumber{
    NSString *nr = [self displayNumberPriv];
    nr = [[ChatUtilities utilitiesInstance] removePeerInfo:nr lowerCase:NO];
    if([[ChatUtilities utilitiesInstance]isUUID:nr]){
       return self.alias;
    }
    return [SPCallManager formattedCallNumber:nr];
}


-(void)tryFindPerson{

    if(!iPhoneBookChecked){

        iPhoneBookChecked=1;

        NSString *userInfo = (_bufPeer ? _bufPeer : _bufDialed);

        AddressBookContact *matchedContact = [[SCSContactsManager sharedManager] contactWithInfo:userInfo];
        
        if(matchedContact) {
            
            _nameFromAB = matchedContact.fullName;

            __weak SCPCall *weakSelf = self;
            
            [[SCSContactsManager sharedManager] addressBookContactWithInfo:userInfo
                                                                completion:^(AddressBookContact *contact) {
                                                                    
                                                                    __strong SCPCall *strongSelf = weakSelf;
                                                                    
                                                                    if(!strongSelf)
                                                                        return;
                                                                    
                                                                    if(!contact)
                                                                        return;
                                                                    
                                                                    strongSelf.callerImage = contact.cachedContactImage;
                                                                }];
        }
   }
    
   if(!(self.isIncoming || self.isAnswered))return ;
   if(iIsNameFromSipChecked || (_nameFromAB && _nameFromAB.length>0))return;
   
   char bufRet3[128];
   int l=getCallInfo(self.iCallId,"peername", bufRet3,127);
   if(l>0){
      self.nameFromAB = [NSString stringWithUTF8String:&bufRet3[0]];
   }
   iIsNameFromSipChecked=1;
}

// 02/22/16 (refactored from iActive)
// these are calls which have been answered by the self or peer user.
// They may be onhold.
-(BOOL)isAnswered {
    return _startTime > 0;
}

-(BOOL)isEnded {
    return _endTime > 0;
}

- (BOOL)isEqual:(id)object {
    
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[SCPCall class]]) {
        return NO;
    }
    
    return [self.uniqueCallId isEqualToString:((SCPCall *)object).uniqueCallId];
}

- (BOOL)isOCA{
    if (self.isIncoming) {
        // if incoming call does not have "AssertedId" in call header info, then it's OCA
        return ([[self getBufAssertedID] length] == 0);
    } else {
        // if outgoing and UUID nil, then it is OCA
        return _bufDstUUID==nil;
    }
}

#pragma mark - Duration

- (NSString *)durationString {
    
    return [[self class] durationStringForCallDuration:self.duration];
}

/**
 * @return delta between start time and end time if call is ended,
 * (_endTime > 0), otherwise, return delta between call start time and now.
 */
- (time_t)duration {
    if (_endTime > 0) {
        return (_endTime - _startTime);
    }
    
    if (_startTime == 0) {
        return 0;
    }
    
    time_t now = time(NULL);
    return (now - _startTime);
}

+(NSString*)durationStringForCallDuration:(time_t)duration {
    
    NSString *newDuration = @"00:00";
    
    if(duration >= 3600.0)
        newDuration = [NSString stringWithFormat:@"%02lu:%02lu:%02lu", duration/3600UL, ((duration / 60UL) % 60UL), duration % 60UL];
    else
        newDuration = [NSString stringWithFormat:@"%02lu:%02lu", duration / 60UL, duration % 60UL];
    
    return newDuration;
}

#pragma mark - Security/ZRTP Methods

-(BOOL)isSCGreenSecure{

   char buf[64];
   int getMediaInfo(int iCallID, const char *key, char *p, int iMax);
   int r=getMediaInfo(_iCallId,"zrtp.sc_secure",&buf[0],63);
   if(r==1 && buf[0]=='1'){
      NSString *s=[Switchboard sendEngMsg:_pEng msg:@".isTLS"];
      if(s && s.UTF8String[0]=='1')return YES;
   }
   return NO;
   
}

-(int)setSecurityLabel:(UILabel *)lb desc:(UILabel *)lbDesc withBackgroundView:(UIView *)view{
   
   int iIsVideo = 0;
    
    // following line crashes on strncpy later if ivars are nill
    //   char *pSM = iIsVideo? (char*)&_bufSecureMsgV.UTF8String[0] :  (char*)&_bufSecureMsg.UTF8String[0];
    
    char *pSM = (char*)"";
    if(iIsVideo && _bufSecureMsgV) pSM =(char*) &_bufSecureMsgV.UTF8String[0];
    else if(!iIsVideo && _bufSecureMsg) pSM =(char*)&_bufSecureMsg.UTF8String[0];
   
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
      //const char* SW(void *pEng, const char *p);
      NSString *s = [Switchboard sendEngMsg:_pEng msg:@".isTLS"];
      //const char *p=sendEngMsg(pEng,".isTLS");
      if(!(s && s.UTF8String[0]=='1')){
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
      iSecureInGreen=!iSecureViaSDES && [self isSCGreenSecure];
      int l = (int)strlen(pSM);
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
       [lbDesc setText:NSLocalizedString([[NSString alloc]initWithUTF8String:bufTmpS], nil)];
//      [lbDesc setText:T_TRNSL(bufTmpS,0)];
   
//   [lb setText:T_TRNSL(bufTmp,0)];
    [lb setText:NSLocalizedString([[NSString alloc]initWithUTF8String:bufTmp], nil)];
   
   UIColor *col = iSecureInGreen ? [UIColor greenColor]:(iSecureViaSDES ? [UIColor yellowColor]: [UIColor whiteColor] );
    if (view) {
        [view setBackgroundColor:col];
    } else {
        lb.textColor = col;
        lbDesc.textColor = col;
    }
   
   return iSecureInGreen;
}

- (BOOL)hasSAS {
    return (self.bufSAS && self.bufSAS.length >= 4);
}

-(BOOL)getIsEmergency{
   if(self.priority == nil || self.priority.length < 1)return NO;
   return [[self.priority lowercaseString] isEqualToString:@"emergency"];
}

#pragma mark - callInfoByKey

- (int) getCallInfoByKey :(char *)key p:(char *)p iMaxLen:(int)iMaxLen {
    if(iMaxLen>2)iMaxLen--;
    return getCallInfo(_iCallId, key, p, iMaxLen);
}


- (NSString *)callInfoForKey:(NSString *)key {
    char sz[1024] = "";
    int r = getCallInfo(_iCallId, key.UTF8String, sz, sizeof(sz)-1);
    if(r < 1 && [key isEqualToString: @"AssertedId"])return _bufAssertedID;
    
    return [NSString stringWithUTF8String:sz];
}


-(UIColor *)getSecureColor{
    //TODO check TLS
    if(!self.isSecure)return [UIColor whiteColor];
    //sdes return yellow (??)
//    return _iShowVerifySas ? [UIColor whiteColor] : [UIColor greenColor];
    return self.isSASVerified ? [UIColor greenColor] : [UIColor whiteColor];
}

-(BOOL)isSecure{
    return !self.isEnded && self.isAnswered && [self.bufSecureMsg isEqualToString:@"SECURE"];
}

// 03/29/16 - clear all property values
// Called by SCPCallManager to clear call state for reuse
// IMPORTANT:
// If non-derived properties are added, this method must be updated to
// clear those values. Otherwise there could be lingering state between
// call instances.
- (void)clearState {
    _incomingCallNotif = nil;
    _bufDialed = nil;
    _bufPeer = nil;
    _bufAssertedID = nil;
    _bufDstUUID = nil;
    _bufServName = nil;
    _bufMsg = nil;
    _shouldNotAddMissedCall = NO;
    _iCallId = 0;
    _SIPCallId = nil;
    _pEng = NULL;
    _uniqueCallId = nil;
    _callerImage = nil;
    _startTime = 0;
    _endTime = 0;
    _isIncoming = NO;
    _iEnded = 0;
    _onHold = NO;
    _isInConference = NO;
    _shouldShowVideoScreen = NO;
    _callType = @"audio";
    _userDidPressVideoButton = NO;
    _sdesActive = NO;
    _zrtpWarning = nil;
    _zrtpPEER = nil;
    _nameFromAB = nil;
    _nameFromWeb = nil;
    _bufSAS = nil;
    _bufSecureMsg = nil;
    _bufSecureMsgV = nil;
    _sasVerified = NO;
    _inUse = NO;
    _didRecv180 = NO;
    _iSIPErrorCode = 0;
    _sipHasErrorMessage = NO;
    _priority = nil;
    _alias = nil;
}

@end


