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
//  ProviderDelegate.m
//  SPi3
//
//  Created by Stylianos Petrakis on 09/09/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "ProviderDelegate.h"
#import "SCPCallManager.h"
#import "SCSAudioManager.h"
#import "SCSEnums.h"
#import "ChatUtilities.h"
#import "SCPPasscodeManager.h"
#import "UserService.h"
#import "SCPNotificationKeys.h"
#import "SCSContactsManager.h"
#import "DBManager.h"
#import "SCPCallbackInterface.h"
#import "SCLoggingManager.h"
#import "SCPSettingsManager.h"

#import <CallKit/CallKit.h>

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelWarning;
//#endif

@interface ProviderDelegate () <CXProviderDelegate> {
    
    CXProvider *_provider;
    CXCallController *_callController;
    NSMutableArray *_callkitCalls;
}
@end

@implementation ProviderDelegate

- (instancetype)init {
    
    if(self = [super init]) {
        
        CXProviderConfiguration *configuration = [self configurationWithEmergencyRingtone:NO
                                                                                 drStatus:(SCSDRStatusLocalDRDisabled | SCSDRStatusRemoteDRDisabled)];
        
        _callkitCalls = [NSMutableArray new];

        _provider = [[CXProvider alloc] initWithConfiguration:configuration];
        
        [_provider setDelegate:self
                         queue:nil];

        _callController = [CXCallController new];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(userInfoDidUpdate:)
                                                     name:kSCSUserServiceUserDidUpdateNotification
                                                   object:nil];
    }
    
    return self;
}

#pragma mark - Notifications

- (void)userInfoDidUpdate:(NSNotification *)notification {
    
    CXProviderConfiguration *configuration = [self configurationWithEmergencyRingtone:NO
                                                                             drStatus:(SCSDRStatusLocalDRDisabled | SCSDRStatusRemoteDRDisabled)];
    
    [_provider setConfiguration:configuration];
}

#pragma mark - Class

+ (BOOL)isEnabled {

    // Detect if Passcode is set
    if([[SCPPasscodeManager sharedManager] doesPasscodeExist])
        return NO;

    // Detect if user has disabled CallKit support from settings
    SCSettingsItem *setting = [[SCPSettingsManager shared] settingForKey:@"iDisableCallKit"];
    if ( (setting) && ([setting boolValue]) )
        return NO; // callKitDisabledByUser
        
    return [[self class] isSupported];
}

+ (BOOL)isSupported {
    
    // Check if CallKit framework exists
    if([CXProvider class])
        return YES;
    else
        return NO;
}

#pragma mark - Public

- (NSUInteger)callkitCalls {
    
    @synchronized (self) {
        return [_callkitCalls count];
    }
}

- (BOOL)isCallkitCall:(SCPCall *)call {
    
    @synchronized (self) {
        return [_callkitCalls containsObject:call];
    }
}

- (void)reportCallEnded:(SCPCall *)call {

    CallKitLogInfo(@"%s", __PRETTY_FUNCTION__);
    
    @synchronized (self) {
        [_callkitCalls removeObject:call];
    }
    
    NSUUID *callUUID = [[NSUUID alloc] initWithUUIDString:call.uniqueCallId];

    CXCallEndedReason reason = CXCallEndedReasonRemoteEnded;

    if(!call.didRecv180 && call.iSIPErrorCode > 0)
        reason = CXCallEndedReasonFailed;
    else if(call.shouldNotAddMissedCall)
        reason = (call.isAnswered ? CXCallEndedReasonAnsweredElsewhere : CXCallEndedReasonDeclinedElsewhere);
    else if(!call.isAnswered)
        reason = CXCallEndedReasonUnanswered;
    
    // If the call ended is the active one
    if(!call.isOnHold) {
        
        // If remote peer ends the call, stop the audio unit after 1.8 secs
        // in order to let app play back the end call tone
        if(reason == CXCallEndedReasonRemoteEnded) {
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                if([SPCallManager activeCallCount] == 0)
                    [SPAudioManager audioUnitStopByProvider];
            });
        }
        // Stop AU immediately
        //
        // Note: No need to check the activeCallCount here
        // as the reportCallWithUUID:endedAtDate:reason: method
        // triggers a didActivate: event by CallKit if needed
        //
        // Update: As of 10.2 stable, CallKit does not re-activate
        // the AudioUnit automatically by calling the onActivate: method
        // in the following case:
        //
        // While already on a call with another call on hold,
        // receive a new incoming one. If the remote peer ends the call
        // before you accept or decline, then if audio unit was stopped (here)
        // CallKit wouldn't call didActivate: delegate method automatically
        // or unhold the last call
        else if([SPCallManager activeCallCount] == 0)
            [SPAudioManager audioUnitStopByProvider];
    }
    
    [_provider reportCallWithUUID:callUUID
                      endedAtDate:[NSDate date]
                           reason:reason];
}

- (void)reportCallConnected:(SCPCall *)call {

    NSUUID *callUUID = [[NSUUID alloc] initWithUUIDString:call.uniqueCallId];

    [_provider reportOutgoingCallWithUUID:callUUID
                          connectedAtDate:[NSDate date]];
}

- (void)reportCallStartedConnecting:(SCPCall *)call {
    
    NSUUID *callUUID = [[NSUUID alloc] initWithUUIDString:call.uniqueCallId];
 
    [_provider reportOutgoingCallWithUUID:callUUID
                  startedConnectingAtDate:[NSDate date]];
}

- (void)reportIncomingCall:(SCPCall *)call drStatus:(SCSDRStatus)drStatus completion:(void (^)(NSError *error))completion {

    if(!call)
        return;
    
    @synchronized (self) {
        [_callkitCalls addObject:call];
    }
    
    CXProviderConfiguration *configuration = [self configurationWithEmergencyRingtone:call.isEmergency
                                                                             drStatus:drStatus];

    [_provider setConfiguration:configuration];

    NSString *displayAlias = [call alias];

    NSString *peerAddress = [[ChatUtilities utilitiesInstance] removePeerInfo:[call bufPeer]
                                                                    lowerCase:YES];

    if(!displayAlias)
        displayAlias = peerAddress;
    
    CXHandleType type = CXHandleTypeGeneric; // used for sip usernames
    
    if([[ChatUtilities utilitiesInstance] isEmail:displayAlias] && ![[ChatUtilities utilitiesInstance] isSipEmail:displayAlias])
        type = CXHandleTypeEmailAddress; // used for emails (e.g. sso users)
    else if([[ChatUtilities utilitiesInstance] isNumber:displayAlias]) {
        
        // If the incoming call is from a phone number then strip the + if exists
        // so to be sure that iOS is going to match it with an address book contact
        // Note: iOS contact matching doesn't work if we strip the whole country code
        // and leave only the national part of the number.
        if([displayAlias hasPrefix:@"+"])
            displayAlias = [displayAlias substringFromIndex:[@"+" length]];
        
        type = CXHandleTypePhoneNumber; // used for PSTN numbers
    }
    
    CXHandle *cxHandle = [[CXHandle alloc] initWithType:type
                                                  value:displayAlias];

    CXCallUpdate *update = [CXCallUpdate new];
    [update setSupportsHolding:YES];
    [update setSupportsDTMF:YES];
    [update setLocalizedCallerName:[call getName]];
    [update setRemoteHandle:cxHandle];
    
    // Note: There is an issue here with UserService class
    // The incoming call event might wake up the app and the UserService will not
    // be able to get the user info via the HTTP request in time to figure out if user
    // has the permission to create conferences or not.
    [update setSupportsGrouping:YES];
    [update setSupportsUngrouping:YES];
  
    NSUUID *callUUID = [[NSUUID alloc] initWithUUIDString:call.uniqueCallId];
    
    [_provider reportNewIncomingCallWithUUID:callUUID
                                      update:update
                                  completion:^(NSError * _Nullable error) {
        
                                      if(error) {
                                          
                                          NSLog(@"%s Error: %@", __PRETTY_FUNCTION__, error);
                                          
                                          // NOTE:
                                          // If local user has blocked the remote user from iOS, then this completion block will fail
                                          // with error code CXErrorCodeIncomingCallErrorFilteredByBlockList
                                          
                                          // If the call is filtered due to user having enabled the DND (Do Not Disturb)
                                          // then issue a regular local notification
                                          // Somewhat related to #NGI-790
                                          if(error.code == CXErrorCodeIncomingCallErrorFilteredByDoNotDisturb)
                                              [Switchboard.notificationsManager presentIncomingCallNotificationForCall:call];
                                      }
                                      
                                      if(completion)
                                          completion(error);
                                  }];
}

- (void)requestTransaction:(ProviderDelegateAction)transactionAction call:(SCPCall *)call infoDictionary:(NSDictionary *)infoDictionary {
    
    CallKitLogInfo(@"%s %ld %@ %@", __PRETTY_FUNCTION__, (long)transactionAction, call, infoDictionary);
    
    CXTransaction *transaction  = [CXTransaction new];
    NSUUID *callUUID            = [[NSUUID alloc] initWithUUIDString:call.uniqueCallId];
    
    switch (transactionAction) {
            
        case ProviderDelegateStartCallAction:
        {
            @synchronized (self) {
                [_callkitCalls addObject:call];
            }
            
            NSString *peerAddress = [[ChatUtilities utilitiesInstance] removePeerInfo:[call bufDialed]
                                                                            lowerCase:YES];

            // This is an ugly hack but until we pass around objects (like RecentObject or something like that) for the app
            // to use for calling instead of just strings, we have to rely on hacks like this one.
            // So the theory goes that we can search user's recents (aka existing conversations) with the bufDialed as key
            // (which typically is the uuid) to find if there is an existing conversation. If this is the case, we then use the
            // existing conversation's displayAlias (if it exists), otherwise we use the bufDialed itself to search in the address book
            
            NSString *addressToSearch = peerAddress;
            RecentObject *recent = [[DBManager dBManagerInstance] getRecentByName:[call bufDialed]];
            
            if(recent && recent.displayAlias)
                addressToSearch = recent.displayAlias;

            NSString *displayAlias = [[ChatUtilities utilitiesInstance] removePeerInfo:addressToSearch
                                                                             lowerCase:YES];
            
            CXHandleType type = CXHandleTypeGeneric;
            
            if([[ChatUtilities utilitiesInstance] isEmail:displayAlias] && ![[ChatUtilities utilitiesInstance] isSipEmail:displayAlias])
                type = CXHandleTypeEmailAddress;
            else if([[ChatUtilities utilitiesInstance] isNumber:displayAlias])
                type = CXHandleTypePhoneNumber;

            CXHandle *cxHandle = [[CXHandle alloc] initWithType:type
                                                          value:displayAlias];
            
            CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:callUUID
                                                                                      handle:cxHandle];
            
            NSString *cnIdentifier = [[SCSContactsManager sharedManager] cnIdentifierForContactWithAlias:addressToSearch];
            
            // Note: Do we want to expose the connected contact?
            if(cnIdentifier)
                [startCallAction setContactIdentifier:cnIdentifier];

            [transaction addAction:startCallAction];
            
            __weak ProviderDelegate *weakSelf = self;
            
            // Check the DR status before making an outgoing call with CallKit
            [[ChatUtilities utilitiesInstance] checkIfDRIsBlockingCommunicationWithContactName:peerAddress
                                                                                    completion:^(BOOL exists, BOOL blocked, SCSDRStatus drStatus) {
        
                                                                                        __strong ProviderDelegate *strongSelf = weakSelf;
                                                                                        
                                                                                        if(!strongSelf)
                                                                                            return;
                                                                                        
                                                                                        CXProviderConfiguration *configuration = [strongSelf configurationWithEmergencyRingtone:NO
                                                                                                                                                                       drStatus:drStatus];
                                                                            
                                                                                        [_provider setConfiguration:configuration];
                                                                                        
                                                                                        [strongSelf requestTransaction:transaction
                                                                                                               forCall:call];
                                                                                }];
            
            return;
        }
            break;
            
        case ProviderDelegateAnswerCallAction:
        {
            CXAnswerCallAction *answerCallAction = [[CXAnswerCallAction alloc] initWithCallUUID:callUUID];
            
            [transaction addAction:answerCallAction];
        }
            break;
            
        case ProviderDelegateEndCallAction:
        {
            CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:callUUID];

            [transaction addAction:endCallAction];
        }
            break;

        case ProviderDelegateSetHeldCallAction:
        {
            BOOL isOnHold = NO;
            
            if(infoDictionary)
                isOnHold = [[infoDictionary objectForKey:@"onHold"] boolValue];
            
            CXSetHeldCallAction *setHeldCallAction = [[CXSetHeldCallAction alloc] initWithCallUUID:callUUID
                                                                                            onHold:isOnHold];

            [transaction addAction:setHeldCallAction];
        }
            break;
            
        case ProviderDelegateSetGroupCallAction:
        {
            NSUUID *callUUIDToGroupWith = nil;
            
            if(infoDictionary)
                callUUIDToGroupWith = [[NSUUID alloc] initWithUUIDString:(NSString*)[infoDictionary objectForKey:@"callUUID"]];
            
            CXSetGroupCallAction *setGroupCallAction = [[CXSetGroupCallAction alloc] initWithCallUUID:callUUID
                                                                                  callUUIDToGroupWith:callUUIDToGroupWith];
            
            [transaction addAction:setGroupCallAction];
        }
            break;
            
        case ProviderDelegateSetMutedCallAction:
        {
            BOOL muted = NO;
            
            if(infoDictionary)
                muted = [[infoDictionary objectForKey:@"muted"] boolValue];
            
            CXSetMutedCallAction *setMutedCallAction = [[CXSetMutedCallAction alloc] initWithCallUUID:callUUID
                                                                                                muted:muted];
            [transaction addAction:setMutedCallAction];
        }
            break;
            
        case ProviderDelegatePlayDTMFCallAction:
        {
            NSString *digit = nil;

            if(infoDictionary && [infoDictionary objectForKey:@"digit"])
                digit = (NSString *)[infoDictionary objectForKey:@"digit"];
            
            if(!digit)
                return;
            
            CXPlayDTMFCallAction *playDTMFCallAction = [[CXPlayDTMFCallAction alloc] initWithCallUUID:callUUID
                                                                                               digits:digit
                                                                                                 type:CXPlayDTMFCallActionTypeSingleTone];
            
            [transaction addAction:playDTMFCallAction];
        }
            break;
            
        default:
            break;
    }

    [self requestTransaction:transaction
                     forCall:call];
}

- (void)requestTransaction:(CXTransaction *)transaction forCall:(SCPCall *)call {

    if([[transaction actions] count] == 0)
        return;
    
    [_callController requestTransaction:transaction
                             completion:^(NSError * _Nullable error) {
    
                                 if(error) {
                                     
                                     NSLog(@"%s Error: %@", __PRETTY_FUNCTION__, error);
                                     
                                     if(call)
                                         [SPCallManager onTerminateCall:call];
                                 }
                             }];
}

#pragma mark - Private

- (CXProviderConfiguration *)configurationWithEmergencyRingtone:(BOOL)isEmergency drStatus:(SCSDRStatus)drStatus {
    
    CXProviderConfiguration *providerConfiguration = [[CXProviderConfiguration alloc] initWithLocalizedName:NSLocalizedString(@"Silent Phone", nil)];
    
    if(isEmergency) {
        
        const char * getEmergencyRingtone(void);
        
        [providerConfiguration setRingtoneSound:[NSString stringWithFormat:@"%s.caf", getEmergencyRingtone()]];
    }
    else {
        
        // Detect if user has enabled native ringtone option
        
        void *findGlobalCfgKey(const char *key);
        int *enableNativeRingtoneP = (int*)findGlobalCfgKey("iEnableNativeRingtone");
        
        BOOL nativeRingtoneEnabled = NO;
        
        if(enableNativeRingtoneP != nil)
            nativeRingtoneEnabled = (*enableNativeRingtoneP == 1);

        if(!nativeRingtoneEnabled)
            [providerConfiguration setRingtoneSound:[self selectedRingtoneSound]];
    }
    
    NSSet *supportedHandleTypes = [NSSet setWithArray:@[
                                                        @(CXHandleTypePhoneNumber)
                                                        ,@(CXHandleTypeEmailAddress)
                                                        ,@(CXHandleTypeGeneric)
                                                        ]];

    [providerConfiguration setSupportedHandleTypes:supportedHandleTypes];
    
    [providerConfiguration setSupportsVideo:YES];
    
    BOOL drEnabled = (drStatus & SCSDRStatusLocalDREnabled || drStatus & SCSDRStatusRemoteDREnabled);

    if(drEnabled)
        [providerConfiguration setIconTemplateImageData:UIImagePNGRepresentation([UIImage imageNamed:@"drIconMask"])];
    else
        [providerConfiguration setIconTemplateImageData:UIImagePNGRepresentation([UIImage imageNamed:@"IconMask"])];
    
    [providerConfiguration setMaximumCallGroups:30];

    if(![[UserService currentUser] hasPermission:UserPermission_CreateConference])
        [providerConfiguration setMaximumCallsPerCallGroup:1];
    else
        [providerConfiguration setMaximumCallsPerCallGroup:30];
    
    return providerConfiguration;
}

- (NSString *)selectedRingtoneSound {
    
    const char * getRingtone(const char *p=NULL);
    
    return [NSString stringWithFormat: @"%s.caf", getRingtone()];
}

#pragma mark - CXProviderDelegate

- (void)providerDidReset:(CXProvider *)provider {
    
    CallKitLogInfo(@"%s", __PRETTY_FUNCTION__);

    [SPAudioManager audioUnitStopByProvider];

    for(SCPCall *call in [SPCallManager activeCalls])
        [SPCallManager terminateCall:call];
}

- (void)providerDidBegin:(CXProvider *)provider {

    CallKitLogInfo(@"%s", __PRETTY_FUNCTION__);
}

- (void)provider:(CXProvider *)provider performSetGroupCallAction:(CXSetGroupCallAction *)action {

    CallKitLogInfo(@"%s %@ %@", __PRETTY_FUNCTION__, action.callUUID, action.callUUIDToGroupWith);
    
    // In order to be able to test this behavior do the following:
    //
    // 1) Plug your headphones to the device
    // 2) Call echo test
    // 3) Click the lock button. By having the headphones plugged in, the lock button just locks the device screen
    //      instead of also ending the call
    // 4) While the echo call is active, call from another test account to your account
    // 5) Accept the call
    // 6) While still on the lock screen, tap on the 'Merge calls' button
    // 7) This method gets called

    SCPCall *call = [SPCallManager callWithUUID:action.callUUID];
    
    if(!call) {
        
        [action fail];
        return;
    }
    
    // If callUUIDToGroupWith is nil, then leave any group the call is currently in.
    if(action.callUUIDToGroupWith == nil) {
        
        [SPCallManager onMoveCallFromConfToPrivate:call];
        
        [action fulfill];
        return;
    }
    
    SCPCall *callToGroupWith = [SPCallManager callWithUUID:action.callUUIDToGroupWith];
    
    if(!callToGroupWith) {
        
        [action fail];
        return;
    }
    
    // Move the current call with the call to group with, into the conference
    [SPCallManager onMoveCallToConference:call];
    [SPCallManager onMoveCallToConference:callToGroupWith];
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performPlayDTMFCallAction:(CXPlayDTMFCallAction *)action {

    CallKitLogInfo(@"%s", __PRETTY_FUNCTION__);

    [SPCallManager onPlayDTMFTone:action.digits];
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action {
    
    CallKitLogInfo(@"%s", __PRETTY_FUNCTION__);

    SCPCall *call = [SPCallManager callWithUUID:action.callUUID];
    
    if(!call) {
        
        [action fail];
        return;
    }
    
    [SPAudioManager setMuteMic:action.isMuted];

    [action fulfill];
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    
    CallKitLogInfo(@"%s", __PRETTY_FUNCTION__);

    SCPCall *call = [SPCallManager callWithUUID:action.callUUID];

    if(!call) {
        
        [action fail];
        return;
    }
    
    [SPAudioManager audioUnitInitialize];
    
    [SPCallManager onDial:call];
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action
{
    CallKitLogInfo(@"%s", __PRETTY_FUNCTION__);
    
    SCPCall *call = [SPCallManager callWithUUID:action.callUUID];
    
    if(!call)
    {
        [action fail];
        return;
    }
    
    @synchronized (self) {
        [_callkitCalls addObject:call];
    }
        
    [SPAudioManager audioUnitInitialize];
    
    [SPCallManager onAnswerCall:call];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSCPCallStateCallAnsweredByLocalNotification
                                                        object:self
                                                      userInfo:@{ kSCPCallDictionaryKey : call }];
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    
    CallKitLogInfo(@"%s", __PRETTY_FUNCTION__);
    
    SCPCall *call = [SPCallManager callWithUUID:action.callUUID];
    
    if(!call) {
        
        [action fail];
        return;
    }
    
    @synchronized (self) {
        [_callkitCalls removeObject:call];
    }

    // Note: No need to check the activeCallCount here
    // as CallKit automatically calls onActivate: if there
    // are any other active calls around/
    //
    // This -though- doesn't happen when there's conferencing
    // so hence the check here.

    // Only stop the AudioUnit if there are no other conference calls active
    BOOL doesHaveOtherCallsInConference = ((call.isInConference && [SPCallManager activeConferenceCallCount] > 1) ||
                                           (!call.isInConference && [SPCallManager activeConferenceCallCount] > 0));
        
    if(!doesHaveOtherCallsInConference)
        [SPAudioManager audioUnitStopByProvider];

    if(call.iEnded == eCallUserNone)
        call.iEnded = eCallUserLocal;
    
    [SPCallManager onTerminateCall:call];
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performSetHeldCallAction:(CXSetHeldCallAction *)action {
    
    CallKitLogInfo(@"%s %d", __PRETTY_FUNCTION__, action.isOnHold);

    SCPCall *call = [SPCallManager callWithUUID:action.callUUID];
    
    if(!call) {
        
        [action fail];
        return;
    }

    [SPCallManager onHoldCall:call
                       onHold:action.onHold];

    // Note: No need to check the activeCallCount for
    // stopping the AudioUnit, as CallKit automatically calls
    // onActivate: if there are any other active calls around.
    //
    // This -though- doesn't happen when there's conferencing
    // so hence the check here.
    //
    // Update: As of 10.2 stable, CallKit does not re-activate
    // the AudioUnit automatically by calling the onActivate: method
    // in the following case:
    //
    // While already having a call, initiate a new outgoing one.
    // The first call will be put on hold (so it would stop the audio unit)
    // and the new one upon initiated should have started the AudioUnit,
    // but that does not happen. So we only need to stop the AudioUnit
    // only if we are holding the only active call.
    if(call.isOnHold && [SPCallManager activeCallCount] == 1)
        [SPAudioManager audioUnitStopByProvider];
    else if(!call.isOnHold)
        [SPAudioManager audioUnitStartByProvider];
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider timedOutPerformingAction:(CXAction *)action {

    CallKitLogInfo(@"%s", __PRETTY_FUNCTION__);
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {

    // Do not try to start the AudioUnit if there are no active calls
    if([SPCallManager activeCallCount] == 0) {
        
        CallKitLogError(@"%s Tried to start the audio unit with no active calls.", __PRETTY_FUNCTION__);
        return;
    }
    
    CallKitLogInfo(@"%s", __PRETTY_FUNCTION__);
    
    // Start call audio media, now that the audio session has been activated after having its priority boosted.
    [SPAudioManager audioUnitStartByProvider];
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession {

    CallKitLogInfo(@"%s", __PRETTY_FUNCTION__);
    
    __block BOOL doesUnholdCallExist = NO;
    
    [[SPCallManager activeCalls] enumerateObjectsUsingBlock:^(SCPCall *call, NSUInteger idx, BOOL *stop) {
    
        if(!call.isOnHold) {
            
            doesUnholdCallExist = YES;
            *stop = YES;
        }
    }];
    
    // This happens when we have more than one active conference calls and the last person joined ends the call.
    // CallKit deactivates the AudioUnit automatically for some reason (although there are active calls).
    // So we need to restart the AudioUnit if there is at least one unhold call.
    if(doesUnholdCallExist)
        [SPAudioManager audioUnitStartByProvider];
}

@end
