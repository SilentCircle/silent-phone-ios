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
//  SCPCallManager.m
//  SilentConference
//
//  Created by Eric Turner on 5/9/15.
//  Based on original work by mahboud on 11/15/13.
//  Copyright (c) 2013 Silent Circle. All rights reserved.
//

#ifndef NULL
#ifdef  __cplusplus
#define NULL    0
#else
#define NULL    ((void *)0)
#endif
#endif

#include "engcb.h"
#include <stdio.h>
#import "axolotl_glue.h"

#import "SCPCallManager.h"
#import "SCPCallManager_Private.h"
#import "SCPCallManager+Utilities.h"

#import "ChatUtilities.h"
#import "ProviderDelegate.h"
#import "Reachability.h"
#import "SCPCall.h"
#import "SCPCallbackInterface.h"
#import "SCPNetworkManager.h"
#import "SCPNotificationKeys.h"
#import "SCPSettingsManager.h"
#import "SCSAudioManager.h"
#import "SCSEnums.h"
#import "SCVideoVC.h"
#import "SystemPermissionManager.h"
#import "UserService.h"
#import "Silent_Phone-Swift.h"


NSString * const SCSCallManagerErrorDomain = @"SCSCallManagerErrorDomain";

SCPCallManager *SPCallManager = nil;

static time_t const ENDED_CALL_OBJECT_TTL = 9.0;
static NSInteger const MAX_CALL_COUNT = 12;

NSTimer *networkTimer;

@interface SCPCallManager ()

@property (copy, atomic) NSMutableSet *callObjects;
@property (strong, nonatomic) DTMFPlayer *dtmfPlayer;
@property (strong, nonatomic) NSString *cachedMediaType;
@property (strong, nonatomic) ProviderDelegate *providerDelegate;

@end

@implementation SCPCallManager


- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    
    _callObjects = [NSMutableSet set];
    for (int i=0; i<MAX_CALL_COUNT; i++) {
        [_callObjects addObject:[[SCPCall alloc] init]];
    }
    
    _providerDelegate = [ProviderDelegate new];
    
    [self initCountryCodes];
    
    SPCallManager = self;
    
    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Call Collection Methods

-(NSArray *)allCallObjects{
    return [_callObjects allObjects];
}
- (NSUInteger)allCallsCount {
    return [[self allCallObjects] count];
}

// Array copy of non-ended calls, including incomingRinging
- (NSArray<SCPCall*> *)activeCalls {
    NSArray *allCalls = [self allCallObjects];
    __block NSMutableArray *mArr = [NSMutableArray arrayWithCapacity:allCalls.count];
    [allCalls enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
        if (call.isInUse && !call.isEnded && (call.iCallId>0 || (call.bufDialed && call.bufDialed.length>0))) {
            [mArr addObject:call];
        }
    }];
    
    return [NSArray arrayWithArray:mArr];
}

- (NSUInteger)activeCallCount {
    return [[self activeCalls] count];
}

- (NSUInteger)activeConferenceCallCount {
 
    __block NSUInteger count = 0;
    
    [[self activeCalls] enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
        if(call.isInConference)
            count++;
    }];

    return count;
}

- (NSUInteger)activeCallKitCallCount {

    if(!_providerDelegate)
        return 0;
    
    return [_providerDelegate callkitCalls];
}

- (NSArray *)unansweredOutgoingCalls {
    NSArray *allCalls = [self allCallObjects];
    __block NSMutableArray *mArr = [NSMutableArray arrayWithCapacity:allCalls.count];
    [allCalls enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
        if(call.isInUse && !call.isIncoming && call.isInProgress){
            [mArr addObject:call];
        }
    }];
    
    return [NSArray arrayWithArray:mArr];
}


- (NSArray *)endedCalls {
    NSArray *allCalls = [self allCallObjects];
    __block NSMutableArray *mArr = [NSMutableArray arrayWithCapacity:allCalls.count];
    [allCalls enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
        if (call.isEnded) {
            [mArr addObject:call];
        }
    }];
    
    return [NSArray arrayWithArray:mArr];
}

- (NSArray *)unusedCalls {
    __block NSMutableArray *disusedCalls = [NSMutableArray arrayWithCapacity:[self allCallsCount]];
    [[self allCallObjects] enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
        if (!call.isInUse) {
            [disusedCalls addObject:call];
        }
    }];
    
    return [NSArray arrayWithArray:disusedCalls];
}

-(SCPCall *)callWithId:(UInt32)iCallId
{
   if(!iCallId)return nil;
    
    NSArray *allCalls = [self allCallObjects];
    __block SCPCall *retCall = nil;
    [allCalls enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
        if (iCallId == call.iCallId && !call.isEnded) {
            retCall = call;
            *stop = YES;
        }
    }];
    
    return retCall;
}

-(SCPCall *)callWithUUID:(NSUUID *)uuid {
    
    if(!uuid)
        return nil;
    
    __block SCPCall *retCall = nil;
    
    [[self allCallObjects] enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
        
        if ([uuid.UUIDString isEqualToString:call.uniqueCallId]) {
            
            retCall = call;
            *stop = YES;
        }
    }];
    
    return retCall;
}

// - finds oldest of calls not inUse
// - invokes call clearState to clear state values
// - sets inUse flag and uniqueCallId
- (SCPCall *)configuredNewCallObject {

    int now = (int)time(NULL);
    __block SCPCall *retCall = nil;
    __block int longest = 0;
   
   // Moved from createCallObject
    if ([self activeCallCount] == 0) {
       [SPAudioManager setMuteMic:NO];
    }

   
    [[self unusedCalls] enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
        int compare = now - (int)call.endTime;
        if (compare > longest) {
            longest = compare;
            retCall = call;
        }
    }];
    
    [retCall clearState];
    retCall.inUse = YES;
    
    // Initialize uniqueCallId here?
    retCall.uniqueCallId = [self uniqueCallId];
    
    return retCall;
}

#pragma mark - Answer/End Call Methods

- (void)answerCall:(SCPCall *)c {
    
    if(!c)
        return;
    
    if([_providerDelegate isCallkitCall:c])
        [_providerDelegate requestTransaction:ProviderDelegateAnswerCallAction
                                         call:c
                               infoDictionary:nil];
    else
        [self onAnswerCall:c];
}

- (void)onAnswerCall:(SCPCall *)c {
    
    if(c.isEnded)
        return;
    
    [self setSelectedCall:c];
    
    doCmd("*a",c.iCallId);
}

- (void)onMuteCall:(SCPCall *)c muted:(BOOL)muted {
    
    if([_providerDelegate isCallkitCall:c])
        [_providerDelegate requestTransaction:ProviderDelegateSetMutedCallAction
                                         call:c
                               infoDictionary:@{ @"muted" : @(muted) }];
    else
        [SPAudioManager setMuteMic:muted];
}

- (void)terminateCall:(SCPCall *)c {

    // Prevent subsequent terminal call requests
    // after the first one has been fulfilled
    if(c.isEnded)
        return;

    c.iEnded = eCallUserLocal;

    if([_providerDelegate isCallkitCall:c])
        [_providerDelegate requestTransaction:ProviderDelegateEndCallAction
                                         call:c
                               infoDictionary:nil];
    else
        [self onTerminateCall:c];
}

- (void)onTerminateCall:(SCPCall *)c {
    
    if (!c || c.isEnded)
        return;
    if(c.iEnded == eCallUserLocal) {
        
        int callID = c.iCallId;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            doCmd("*e", callID);
        });
    }
    
    if(!c.sipHasErrorMessage)
        [c setBufMsg:@"Call ended"];
    
    if(!c.iEnded) {
        
        c.iEnded = eCallUserPeer;
        
        [SPAudioManager vibrateOnce];
    }
    
    if(c.endTime==0)
        c.endTime=(unsigned int)time(NULL);
    
    [self stopRingtone:c showMissedCall:c.isIncoming forceStop:NO];
   
    //if c is ended and c is selected call then we have to find a new selected call
    //
    // TODO: Update this
    //
    // ET: is this true? On 02/26/16 Janis and ET considered that keeping a reference
    // to a single "selected" call may not be quite right. By (one) definition, "selected"
    // simply means "not on hold". For example, all calls in a conference are "selected" by
    // virtue of being "not on hold", except when conference is put on hold, in which case,
    // conference calls are on hold and the selected call is not.
    //
    // Note that the setSelectedCall: method sets all other calls
    // on hold EXCEPT calls in conference (isInConference).
    //
    // So, "selected" seems to really mean "not on hold".

    // Note: multiple calls may be selected but we only ever want to auto-select a call if
    // there is only one remaining.
    //
    // Historical notes:
    // if c is ended and c is selected call then we have to find a new selected call
    NSUInteger activeConferenceCallCount = [self activeConferenceCallCount];
    NSUInteger activeCallCount = [self activeCallCount];
    
    // If there is just one call left or if the only calls left are part of the conference
    // then autoswitch to that call(s). Otherwise, let user choose.
    if (activeCallCount == 1 || (activeCallCount >= 1 && activeCallCount == activeConferenceCallCount)) {

        SCPCall *firstCall = [[self activeCalls] firstObject];
        
        if(firstCall)
            [self setSelectedCall:firstCall informProvider:YES];
    }

    /*
     * It was previously supposed that the call object would never be
     * nil here, but it was discovered (by NSAssert) that, in fact, when
     * an echo call is placed and immediately ended, the call object
     * could be nil. Therefore, we now check for nil so as not to crash
     * when creating the userInfo dictionary.
     */
    NSDictionary *userInfo = c ? @{ kSCPCallDictionaryKey : c } : nil;
    
    [self postNotification:kSCPCallDidEndNotification
                       obj:self
                  userInfo:userInfo];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ENDED_CALL_OBJECT_TTL * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        c.inUse = NO;
    });
}

#pragma mark - Dialing

-(SCPCall *)dial:(NSString *)number uuid:(NSString *)uuid isPSTN:(BOOL)isPSTN displayName:(NSString *)displayName queuedVideoRequest:(BOOL)queuedVideoRequest error:(NSError **)outError {

    if(!number)
        return nil;
    
    const char *pNr = number.UTF8String;

    // Handle magic codes
    if(strncmp(pNr, "*##*" , 4)==0){

        unsigned int calcMD5(const char *p, int iLen, int n);
        unsigned int code=calcMD5(pNr+4,0,20000000);
        printf("[md5=0x%08x]\n",code);
        
        if(code==0x448683f6){
            void switchToTest443();
            switchToTest443();
            return nil;
        }
        
        // Basic Cfg
        if(code==0x678fe423){
            [SCPSettingsManager setCfgLevel:1];
            return nil;
        }
        
        // Adv Cfg
        if(code==0x58e7fa40){// && canEnableCFG()){
            [SCPSettingsManager setCfgLevel:2];
            return nil;
        }
        
        // provisioning without a username/pwd UI (Prov.mm), provision using
        //"*##*7786*" prefix, followed by username*pwd
        if(strlen(pNr)>10 && strncmp(pNr, "*##*7786*", 9)==0){
            //doProv(numberStr +  9);
            char buf[128];
            snprintf(buf, sizeof(buf), "%s", pNr + 9);
            const char *pass = "";
            char *p = &buf[0];
            while(p[0]){
                if(p[0]=='*'){pass=p+1;p[0]=0;}
                p++;
            }
            return nil;
        }
        
        doCmd(pNr);
        return nil;
    }

    // Prevent calling the same number twice
    for(SCPCall *call in [self activeCalls]) {
        
        NSString *caller = nil;
        
        if(call.isIncoming)
            caller = [call bufPeer];
        else
            caller = [call bufDialed];
        
        if(!caller)
            continue;
        
        caller = [[ChatUtilities utilitiesInstance] removePeerInfo:caller
                                                         lowerCase:NO];
        
        if([caller isEqualToString:number]) {

            // Allow multiple echo test calls
            if([number isEqualToString:@"*3246"])
                break;
            
            if(queuedVideoRequest)
                call.hasQueuedVideoRequest = queuedVideoRequest;

            if (outError) {
                
                *outError = [[NSError alloc] initWithDomain:SCSCallManagerErrorDomain
                                                       code:SCSCallManagerErrorCallAlreadyExists
                                                   userInfo: @{ kSCPCallDictionaryKey : call }];
            }
                        
            return nil;
        }
    }
    
    SCPCall *call = [self configuredNewCallObject];
    
    if(!call)
        return nil;

    call.bufDialed = number;
    call.isPSTN = isPSTN;
    
    if(queuedVideoRequest)
        call.hasQueuedVideoRequest = queuedVideoRequest;
    
    if(uuid)
        call.bufDstUUID = uuid;

    if(displayName)
        call.nameFromWeb = displayName;

    if([self allowCallKit])
        [_providerDelegate requestTransaction:ProviderDelegateStartCallAction
                                         call:call
                               infoDictionary:nil];
    else
        [self onDial:call];
    
    return call;
}

-(void)onDial:(SCPCall *)c {

    if (!c)
        return;
    
    [self setSelectedCall:c];
    [self saveLastCalledNumber:c.bufDialed];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        int dialed = 0;

        if(c.isPSTN) // For PSTN calls
            dialed = dial([NSString stringWithFormat:@"%@;pstn", c.bufDialed].UTF8String);
        else if(c.bufDstUUID) // For UUID calls
            dialed = dial(c.bufDstUUID.UTF8String);
        else // For device calls
            dialed = dial(c.bufDialed.UTF8String);
        
        if(dialed) {
            [self postNotification:kSCPOutgoingCallNotification
                               obj:self
                          userInfo:@{ kSCPCallDictionaryKey: c }];
        }
        else {
            [self terminateCall:c];
        }
    });
    
    [self startReachabilityObserver];
}

#pragma mark - Call Management Methods

-(void)moveCallToConference:(SCPCall *)aCall {
    
    BOOL moveToConference = YES;
    
    if([_providerDelegate isCallkitCall:aCall]) {
        
        // Try to find another call that already is in the conference
        __block NSString *callUUIDtoGroupWith = nil;
        
        [[self allCallObjects] enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
            if (call.isInConference) {
                callUUIDtoGroupWith = call.uniqueCallId;
                *stop = YES;
            }
        }];
        
        if(callUUIDtoGroupWith != nil) {
            
            NSUUID *groupCallUUID= [[NSUUID alloc] initWithUUIDString:callUUIDtoGroupWith];
            SCPCall *callToGroup = [self callWithUUID:groupCallUUID];
            
            if([_providerDelegate isCallkitCall:callToGroup]) {
                
                [_providerDelegate requestTransaction:ProviderDelegateSetGroupCallAction
                                                 call:aCall
                                       infoDictionary:@{ @"callUUID": callUUIDtoGroupWith }];
                
                moveToConference = NO;
            }
        }
    }
    
    if(moveToConference)
    {
        [self onMoveCallToConference:aCall];
        [self holdCall:aCall onHold:NO];
    }
}

-(void)onMoveCallToConference:(SCPCall *)aCall {
    if (!aCall)
        return;
    
    doCmd("*+",aCall.iCallId);//add to conference
    aCall.isInConference = YES;

    [self putAllConferenceCallsOnHold:NO];
    [self putAllPrivateCallsOnHoldExceptCall:aCall];

    [self postNotification:kSCPCallStateDidChangeNotification
                       obj:self
                  userInfo:@{
                             kSCPCallDictionaryKey: aCall,
                             kSCPReloadCellDictionaryKey: @(YES)
                             }];
}

-(void)moveCallFromConfToPrivate:(SCPCall *)aCall {
    
    if([_providerDelegate isCallkitCall:aCall]) {
        
        [_providerDelegate requestTransaction:ProviderDelegateSetGroupCallAction
                                         call:aCall
                               infoDictionary:nil];
    }
    else {
        [self onMoveCallFromConfToPrivate:aCall];
    }
}

-(void)onMoveCallFromConfToPrivate:(SCPCall *)aCall {
    if (!aCall)
        return;
    doCmd("*-",aCall.iCallId);//remove from conference
    aCall.isInConference = NO;
    
    [self putAllConferenceCallsOnHold:YES];
    [self putAllPrivateCallsOnHoldExceptCall:aCall];

    [self onHoldCall:aCall onHold:NO];

    [self postNotification:kSCPCallStateDidChangeNotification
                       obj:self
                  userInfo:@{
                             kSCPCallDictionaryKey: aCall,
                             kSCPReloadCellDictionaryKey: @(YES)
                             }];
}

-(void)holdCall:(SCPCall *)c onHold:(BOOL)onHold {
    
    if([_providerDelegate isCallkitCall:c]) {
        
        [_providerDelegate requestTransaction:ProviderDelegateSetHeldCallAction
                                         call:c
                               infoDictionary:@{ @"onHold": @(onHold) }];
    }
    else
        [self onHoldCall:c onHold:onHold];
}

-(void)onHoldCall:(SCPCall *)c onHold:(BOOL)onHold {
 
    if(c.isEnded || !c.isAnswered)
        return;
    
    if(onHold && !c.isOnHold)
        doCmd("*h", c.iCallId);
    
    if(!onHold && c.isOnHold)
        doCmd("*u", c.iCallId);
    
    c.onHold = onHold;
}

- (void)putAllPrivateCallsOnHoldExceptCall:(SCPCall*)aCall {
    
    [[self activeCalls] enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
        
        if (!call.isInConference && ![call isEqual:aCall]) {

            [self onHoldCall:call onHold:YES];
            
            DDLogVerbose(@"%s set hold state:%@ for private call.%@", __FUNCTION__,
                         (call.isOnHold)?@"ON":@"OFF", call.uniqueCallId);
        }
    }];
}

-(void)putAllConferenceCallsOnHold:(BOOL)on{
    
    [[self activeCalls] enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
        
        if(call.isInConference) {
            DDLogVerbose(@"%s set hold state:%@ for in-conference call.%@", __FUNCTION__,
                         (on)?@"ON":@"OFF", call.uniqueCallId);
                         
            [self onHoldCall:call onHold:on];
        }
    }];
}

#pragma mark - Selected Call Methods 

- (void)setSelectedCall:(SCPCall *)aCall {

    [self setSelectedCall:aCall informProvider:NO];
}

/**
 * This implementation handles replacing the selectedCall property,
 * ensuring the given call is not on hold,
 * ensuring conference calls are put on or taken off hold, conditional
 * on whether the given call is a conference call or not,
 * and ensures all private calls except the given one (which may be a
 * private call or not) are on hold.
 */
- (void)setSelectedCall:(SCPCall *)aCall informProvider:(BOOL)informProvider {
    
    if(!aCall)
        return;
    
    BOOL wasOnHold = aCall.isOnHold;
    
    [self putAllConferenceCallsOnHold:!aCall.isInConference];
    [self putAllPrivateCallsOnHoldExceptCall:aCall];

    if(informProvider && [_providerDelegate isCallkitCall:aCall]) {
        
        if(!aCall.isOnHold && aCall.isInConference) {
            
            // Start, or restart the AudioUnit if the conference was
            // previously on hold.
            //
            // Note: This needs to happen when there is an active conference
            // and a new private call comes in (or goes out).
            // When this private call ends (by the local user or the remote peer),
            // then the local user will need to tap on the conference section to
            // unhold the conference calls.
            if(wasOnHold)
                [SPAudioManager audioUnitStartByProvider];
            
            return;
        }
        
        // If call is on hold, unhold that call
        [_providerDelegate requestTransaction:ProviderDelegateSetHeldCallAction
                                         call:aCall
                               infoDictionary:@{ @"onHold": @(NO) }];
    }
    else {
        [self onHoldCall:aCall onHold:NO];
    }
}

#pragma mark - ZRTP Methods

-(void)refreshZRTP:(SCPCall *)c msgid:(int)msgid{
    
    NSAssert(c != nil, @"UNEXPECTED NIL CALL");
    // post ZRTP updated notif
    [self postNotification:kSCPZRTPDidUpdateNotification obj:self userInfo:@{kSCPCallDictionaryKey:c}];
   
   void checkSDES(SCPCall *c, void *ret, void *ph, int iCallID, int msgid);
   checkSDES(c, NULL,c.pEng,c.iCallId,msgid);
}

-(void)setVerifyFlag:(BOOL)flag call:(SCPCall *)c {

    if(flag)
        doCmd("*V",c.iCallId); //set ZRTP verify flag
    else
        doCmd("*v",c.iCallId);
    
    c.sasVerified = (flag==NO) ? 0 : 1;
}

-(void)setCacheName:(NSString*)cacheName call:(SCPCall *)c{
    if(c.isEnded)return;
    
    [c setZrtpPEER:cacheName];

    char buf[256];
    const char *p = cacheName.UTF8String;
    if(!p) p = "";
    snprintf(buf, sizeof(buf), "*z%d %s", c.iCallId, p);
    puts(buf);
    
    doCmd(buf);
}


#pragma mark - Other methods

// fncCallback calls here with audio/video or video/audio change. this
// method sets the shouldShowVideoScreen flag (may need renaming) and it
// then posts the didChangeState notification
-(void)checkMedia:(NSString *)callType forCall:(SCPCall *)c{
    if (!c)
        return;
    BOOL previousShouldShowVideoScreen = c.shouldShowVideoScreen;

    c.callType = callType;
    c.shouldShowVideoScreen = ![callType isEqualToString:@"audio"];

    BOOL callStatusDidChange = (previousShouldShowVideoScreen != c.shouldShowVideoScreen);
    
    if(!callStatusDidChange)
        return;

    dispatch_async(dispatch_get_main_queue(), ^{

        if(c.shouldShowVideoScreen) {
            
            if([UIApplication sharedApplication].applicationState != UIApplicationStateActive)
                [Switchboard.notificationsManager presentVideoRequestNotificationForCall:c];
            else
                [[NSNotificationCenter defaultCenter] postNotificationName:kSCPCallIncomingVideoRequestNotification
                                                                    object:self
                                                                  userInfo:@{ kSCPCallDictionaryKey : c }];
        }
        else
            [Switchboard.notificationsManager cancelNotificationForCall:c];
    });
}

-(void)switchToVideo:(SCPCall *)call on:(BOOL)on{
    doCmd(on ? "*C" : "*c", call.iCallId);
   call.userDidPressVideoButton = on;
   call.shouldShowVideoScreen = on;
}


#pragma mark - DTMF Methods

-(void)initDTMF{

    if(!_dtmfPlayer)
        _dtmfPlayer = [DTMFPlayer new];
}

-(void)stopDTMF{
    
    if(_dtmfPlayer) {
        [_dtmfPlayer stop];
        _dtmfPlayer = nil;
    }
}

-(void)resetDTMF {
    
    if(_dtmfPlayer)
        [_dtmfPlayer reset];
}

-(void)pauseDTMFTone{
    
    if(_dtmfPlayer)
        [_dtmfPlayer pause];
}

-(void)playDTMFTone:(NSString*)dtmfValue call:(SCPCall *)call {
    
    if(call && [_providerDelegate isCallkitCall:call])
        [_providerDelegate requestTransaction:ProviderDelegatePlayDTMFCallAction
                                         call:call
                               infoDictionary:@{ @"digit" : dtmfValue }];
    else
        [self onPlayDTMFTone:dtmfValue];
}

-(void)onPlayDTMFTone:(NSString *)dtmfValue {
    
    if(_dtmfPlayer)
        [_dtmfPlayer play:dtmfValue];
    
    if([self activeCallCount] > 0) {
        
        const char *p= [dtmfValue UTF8String];

        char b[4];
        b[0]=':';
        b[1]='D';
        b[2]=p[0];
        b[3]=0;
        
        doCmd(b);
    }
}

#pragma mark - Ringtone Methods

-(void)tryToPlayRingtone:(SCPCall *)c{
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [SPAudioManager playIncomingRingtone:c.isEmergency];
    });
}

-(void)stopRingtone:(SCPCall *)c showMissedCall:(BOOL)showMissedCall forceStop:(BOOL)forceStop {
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        [Switchboard.notificationsManager cancelNotificationForCall:c];

        if(showMissedCall)
            [Switchboard.notificationsManager presentMissedCallNotificationForCall:c];
        
        __block int iMustStop=1;
        
        if(!forceStop) {
            
            [[self activeCalls] enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
                if(call.isIncomingRinging){
                    iMustStop=0;
                }
                else if(call.isAnswered || call.isInProgress){
                    iMustStop=1;
                    *stop = YES;//we should not play a ringtone if we have any active calls
                }
            }];
        }
        
        if(iMustStop){
            
            [SPAudioManager stopIncomingRingtone];
        }
    });
}

#pragma mark - Utilities

/**
 Checks whether the app is allowed to route the next
 incoming or outgoing call via CallKit.
 
 The requirements are that CallKit has to be supported
 by the device and enabled by the user
 (check the ProviderDelegate isEnabled method for more)
 and there are no other calls active.
 
 That essentially means that we allow only the first
 call to be handled as a CallKit call and any other
 calls as non-CallKit.

 @return YES if the next call is allowed to be routed via CallKit, NO otherwise.
 */
- (BOOL)allowCallKit {
    return ([ProviderDelegate isEnabled] && [self activeCallCount] == 1 && [_providerDelegate callkitCalls] == 0);
}

- (NSString *)formattedCallNumber:(NSString *)ns {
    return [self getFormattedCallNumber:ns];
}

// Wraps +Utilities method 
- (NSString *)lastCalledNumber {
    return [self getLastCalledNumber];
}

-(void)dialJanis{
    doCmd(":c 22146864");
}

- (int)scAccountAvailability {
    return getPhoneState();
}

-(SCPCall *)tryFetchCallObjectUsingNumberAndCallIdisNull:(NSString *)str{
    SCPCall *c = nil;
    
    int iCharsMatch = 0;

    //03/29/16
    NSArray *calls = [self allCallObjects];
    for(int i=0;i<calls.count;i++){
        SCPCall *o = calls[i];

        if(o.iCallId == 0 && !o.isEnded && o.bufDialed.length>0){
            int cm = charsMatch(str.UTF8String, (int)str.length, o.bufDialed.UTF8String);
            int cmUUID = charsMatch(str.UTF8String, (int)str.length, o.bufDstUUID.UTF8String);
            if(cmUUID < cm)cm = cmUUID;
            if(!c || cm > iCharsMatch){
                c = o;
                iCharsMatch = cm;
            }
        }
    }
    
    return c;
}

// Create uniqueCallId from timeStamp

- (NSString *)uniqueCallId {
    
    NSString *timeString = [NSString stringWithFormat:@"%li",time(NULL)];
    uuid_string_t callId;
    NSString *ucid = [NSString stringWithFormat:@"%s",
                             CTAxoInterfaceBase::generateMsgID(timeString.UTF8String, (char*)&callId[0], sizeof(callId))];
    return ucid;
}

#pragma mark - callbackFunction()

- (int)handleFncCallback:(void*)ret ph:(void*)ph iCallID:(int)iCallID msgid:(int)msgid ns:(NSString*)ns {
    
    __block SCPCall *c = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if(msgid == CT_cb_msg::eCalling) {
            
            c = [SPCallManager tryFetchCallObjectUsingNumberAndCallIdisNull:ns];
            
            if(!c) {
                
                // Terminate the call if cannot fetch a call object (all call objects are busy)
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    doCmd("*e", iCallID);
                });
                
                return;
            }
        }
        else
            c = [self callWithId:iCallID];
        
        // Note: the refreshZRTP: method posts kSCPZRTPDidUpdateNotification
        switch (msgid) {
                
            case CT_cb_msg::eNewMedia:

                if (c)
                    [self checkMedia:ns
                             forCall:c];
                else
                    _cachedMediaType = [[NSString alloc] initWithString:ns];

                break;
                
            case CT_cb_msg::eEnrroll:
                
                if(!c)
                    break;
                
                c.sasVerified=0;
                
                [self refreshZRTP:c
                            msgid:msgid];
                
                break;
                
            // Video: ns string contains security state
            case CT_cb_msg::eZRTPMsgV:
                
                if(!c)
                    break;
                
                [c setBufSecureMsgV:ns];
                
                [self refreshZRTP:c
                            msgid:msgid];
                
                break;
                
            // Audio: ns string contains security state
            case CT_cb_msg::eZRTPMsgA:
                
                if(!c)
                    break;
                
                [c setBufSecureMsg:ns];
                
                [self refreshZRTP:c
                            msgid:msgid];
                
                break;
                
            // Update SAS label
            case CT_cb_msg::eZRTP_sas:
                
                if(!c)
                    break;
                
                if(ns)
                    [c setBufSAS:ns];
                
                [self refreshZRTP:c
                            msgid:msgid];
                
                break;
                
            case CT_cb_msg::eZRTP_peer_not_verifed:
                
                if(!c)
                    break;
                
                c.sasVerified = 0;
                
                if(ns)
                    [c setZrtpPEER:ns];
                
                [self refreshZRTP:c
                            msgid:msgid];
                
                break;
                
            // Peer name (same as cache name)
            // need SPI to set cache name
            case CT_cb_msg::eZRTP_peer:
                
                if(!c)
                    break;
                
                if(!ns)
                    c.sasVerified = 0;
                else {
                    c.sasVerified = 1;
                    [c setZrtpPEER:ns];
                }
                
                [self refreshZRTP:c
                            msgid:msgid];
                
                break;
                
            case CT_cb_msg::eZRTPErrV:
                
                if(!c)
                    break;
                
                c.bufSecureMsgV = NSLocalizedString(@"ZRTP Error", nil);
                
                if(ns)
                    c.zrtpWarning = ns;
    
                [self refreshZRTP:c
                            msgid:msgid];
                
                break;
                
            case CT_cb_msg::eZRTPErrA:
                
                if(!c)
                    break;
                
                c.bufSecureMsg = NSLocalizedString(@"ZRTP Error", nil);
                
                [self refreshZRTP:c
                            msgid:msgid];
                
                break;
                
            case CT_cb_msg::eZRTPWarn:
                
                if(!c)
                    break;
                
                if(ns)
                    c.zrtpWarning = ns;
                
                [self refreshZRTP:c
                            msgid:msgid];
                
                break;
        
            // Update calling state UI with setBufMsg
            case CT_cb_msg::eRinging:
                
                c.didRecv180 = YES;
                
                [c setBufMsg:NSLocalizedString(@"Ringing", nil)];
                
                break;
                
            case CT_cb_msg::eCalling:
                
                if([_providerDelegate isCallkitCall:c])
                    [_providerDelegate reportCallStartedConnecting:c];
                
                [c setBufMsg:NSLocalizedString(@"Calling...", nil)];
                
                c.iCallId=iCallID;
                c.pEng = ph;
                
                if(c.bufDialed==nil || c.bufDialed.length<1)
                    [c setBufDialed:ns];
                
                if(c.bufPeer==nil || c.bufPeer.length<1)
                    [c setBufPeer:ns];
                
                [self stopRingtone:c
                    showMissedCall:NO
                         forceStop:NO];
                
                break;
                
            // Functionality moved to onEndCall:
            case CT_cb_msg::eEndCall:
                
                if(c) {
                    
                   if(ns)
                       c.shouldNotAddMissedCall = ([ns caseInsensitiveCompare:@"Call completed elsewhere"] == NSOrderedSame);
                    
                    if(!c.iEnded)
                        c.iEnded = eCallUserPeer;

                    if(!c.isEnded && c.iEnded == eCallUserPeer) {

                        if([_providerDelegate isCallkitCall:c])
                            [_providerDelegate reportCallEnded:c];
                        
                        [self onTerminateCall:c];
                    }
                }

                [self removeReachabilityObserver];
                
                break;
                
            // Call answered
            case CT_cb_msg::eStartCall:
                
                if([_providerDelegate isCallkitCall:c])
                    [_providerDelegate reportCallConnected:c];
                
                if(!c.bufSecureMsg) {
                    
                    [c setBufMsg: NSLocalizedString(@"Connecting...", nil)];
                    [self refreshZRTP:c
                                msgid:msgid];
                }
                else 
                    [c setBufMsg:@" "];

                if(!c.startTime)
                    c.startTime=(unsigned int)time(NULL);

                // record "callid"
                c.SIPCallId = [c callInfoForKey:@"callid"];
                
                [self stopRingtone:c
                    showMissedCall:NO
                         forceStop:YES];
                
                [self removeReachabilityObserver];
                
                break;
                
            // Declined or timeout or error:
            // TODO: display setBufMsg string (more than 2 lines)
            case CT_cb_msg::eError:
                
                if(c){
                    
                    c.sipHasErrorMessage = YES;
                    [c setBufMsg:ns];
                }
                
                break;

            case CT_cb_msg::eIncomCall: {

                _cachedMediaType = nil;

                if (![SystemPermissionManager hasPermission:SystemPermission_Microphone]) {
                    [self terminateIncomingCall:iCallID ns:ns sipMsg:@"No Mic permission" sipCode:486];
                    break;
                }

#if HAS_DATA_RETENTION                

                // local user DR block check
                if ( ([UserService currentUser].drEnabled) && ([UserService currentUserBlocksLocalDR]) ) {
                    // if I am subject to DR, but have DR blocked, my phone is a brick and I cannot receive this
                    NSString *terminateMsg = @"Policy Conflict #1984";
                    NSString *terminateS = [NSString stringWithFormat:@"*e%d;%@", iCallID, terminateMsg];
                    doCmd(terminateS.UTF8String);
                    break;
                }

                // remote DR block check
                NSString *recipient = [[ChatUtilities utilitiesInstance] removePeerInfo:ns
                                                                          lowerCase:YES];
                
                [[ChatUtilities utilitiesInstance] checkIfDRIsBlockingCommunicationWithContactName:recipient 
                                                                                    completion:^(BOOL exists, BOOL blocked, SCSDRStatus drStatus) {
                    if (blocked) {
                        
                        // Inform Tivi engine to kill the call
                        // We have to do this from a different thread, the end mutex would deadlock
                       dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                           
                           NSString *terminateMsg = @"Data Retention Rejected";
                           NSString *terminateS = [NSString stringWithFormat:@"*e%d;%@", iCallID, terminateMsg];
                           
                           doCmd(terminateS.UTF8String);
                       });
                        
                    } else {
#else
                        SCSDRStatus drStatus = 0;
                        
#endif // HAS_DATA_RETENTION
                        
                        // Follow the incoming call notification logic
                        c = [self handleIncomingCallMsg:ph
                                                iCallID:iCallID
                                                     ns:ns
                                               drStatus:drStatus];
                        
                        if (_cachedMediaType) {
                            [self checkMedia:_cachedMediaType forCall:c];
                            _cachedMediaType = nil;
                        }                        
                        
                        // Issue the incoming call notification
                        if(c) {
                            [self postNotification:kSCPIncomingCallNotification
                                               obj:self
                                          userInfo:@{ kSCPCallDictionaryKey: c }];
                        }
#if HAS_DATA_RETENTION
                        
                    }
                }];
#endif // HAS_DATA_RETENTION
    
                break;
            }

            default:
                break;
        }
        
        if (c) {
            [self postNotification:kSCPCallStateDidChangeNotification
                               obj:self
                          userInfo:@{ kSCPCallDictionaryKey: c }];
        }
    });

    return 0;
}

- (SCPCall *)handleIncomingCallMsg:(void*)ph iCallID:(int)iCallID ns:(NSString *)ns drStatus:(SCSDRStatus)drStatus {

    SCPCall *c = [self configuredNewCallObject];

    if (!c)
        return nil;

    [c setIsIncoming:YES];
    [c setICallId:iCallID];
    [c setPriority:[c callInfoForKey:@"getPriority"]];
    [c setPEng:ph];
    [c setBufPeer:ns];
    [c setBufMsg:NSLocalizedString(@"Incoming call", nil)];

    if([self activeCallCount] > 1)
        doCmd("*r", c.iCallId); //plays beep sound, will stop automaticaly if a call is answered or ended
    
    if([self allowCallKit]) {

        __weak SCPCallManager *weakSelf = self;
        
        [_providerDelegate reportIncomingCall:c
                                     drStatus:drStatus
                                   completion:^(NSError *error) {
                                       
                                       __strong SCPCallManager *strongSelf = weakSelf;
                                       
                                       if(!strongSelf)
                                           return;
                                       
                                       if(error)
                                           [strongSelf terminateCall:c];
                                    }];
    }
    else {

        [self tryToPlayRingtone:c];
        
        [Switchboard.notificationsManager presentIncomingCallNotificationForCall:c];
    }

	return c;
}

- (void)terminateIncomingCall:(int)iCallID ns:(NSString *)ns sipMsg:(NSString *)sipMsg sipCode:(int)sipCode {
    // send Tivi termination code to indicate this device can not receive the call
    NSString *terminateS = [NSString stringWithFormat:@"*e%d;%@;%d", iCallID, sipMsg, sipCode];
    doCmd(terminateS.UTF8String);

    // locally create a terminated call and notify local user
    SCPCall *c = [self configuredNewCallObject];
    if (!c)
        return;
    
    NSString *errorMsg = [NSString stringWithFormat:@"Missed call (%@)", sipMsg];
    NSString *localizedErrorMsg = NSLocalizedString(errorMsg, nil); // how to localize this?
    
    [c setIsIncoming:YES];
    [c setICallId:iCallID];
    //[c setPriority:[c callInfoForKey:@"getPriority"]];
    //[c setPEng:ph];
    [c setBufPeer:ns]; //sipMsg];
    c.sipHasErrorMessage = YES; // set sipHasErrorMessage true to display custom error message
    [c setBufMsg:localizedErrorMsg];
    [c setIEnded:eCallUserNone]; // set iEnded to None to enable sending out local notification
    [c setEndTime:(unsigned int)time(NULL)];
    
    // let DBManager, etc. know about the ending call
    [self postNotification:kSCPCallDidEndNotification
                       obj:self
                  userInfo:@{kSCPCallDictionaryKey: c}];
    
    // let the user know about the missed call
    if([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        // we're in the foreground, use our own local alert
        [[ChatUtilities utilitiesInstance] showLocalAlertFromCall:c];
    } else {
        // in the background, use notificationsManager
        [Switchboard.notificationsManager presentMissedCallNotificationForCall:c];
    }
}

- (void) startReachabilityObserver {
    //add network status observer for eCalling to eRinging states only,
    //it will be removed in dealloc method
    //ensure there is only one ReachabilityObserver
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
   
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
}

- (void) removeReachabilityObserver {
    if([[self unansweredOutgoingCalls] count] == 0){
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    }
}

- (void) checkCallState {
    //A non-repeating timer invalidates itself immediately after it fires.
    //but it's not hurt to manually clean it up.
    [networkTimer invalidate];
    networkTimer = nil;
    
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus netStatus = [reachability currentReachabilityStatus];
    if(netStatus == NotReachable){
        NSArray *uCalls = [self unansweredOutgoingCalls];
        if([uCalls count] > 0) {
            // if it's in eCalling, eRinging states without network connection for 60 seconds, call will be ended, it's similar to the
            // remote party ends call after certain period of time in Ringing state.
            for (SCPCall *call in uCalls){
                [self terminateCall:call];
            }
            
        }
    }
}

#pragma mark - Reachability Handler

- (void)reachabilityChanged:(NSNotification *)notification {
    Reachability *curReach = [notification object];
    NetworkStatus netStatus = [curReach currentReachabilityStatus];
    if(netStatus == NotReachable){
        if([[self unansweredOutgoingCalls] count] > 0) {
            if(networkTimer == nil){
                //recheck in 60 secs which was suggested by Ivo and Janis in NGA-561
                networkTimer = [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(checkCallState) userInfo:nil repeats:NO];
            }
        }
    }
}

#pragma mark - Notifications

- (void)postNotification:(NSString *)key obj:(id)obj userInfo:(NSDictionary *)uInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:key object:obj userInfo:uInfo];
    });
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - End ObjC
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@end


int charsMatch(const char *a, int iALen, const char *bSZ){
    int n=0;
    if(!bSZ || !bSZ[0])return 0;
    //sip:15551234567@sip.sc.com
    //+1(555)123-4567
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


int dial(const char *numberStr)
{
    if(numberStr == NULL)
        return 0;
    
    if(!strlen(numberStr))
        return 0;

    char cmd[256];
    sprintf(cmd,":c %s", numberStr);
    doCmd(cmd);
    
    return 1;
}

