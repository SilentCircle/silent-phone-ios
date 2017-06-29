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
//  SCPCallManager.h
//  SilentConference
//
//  Created by Eric Turner on 5/9/15.
//  Based on original work by mahboud on 11/15/13.
//  Copyright (c) 2013 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>

//#ifdef __cplusplus
//extern "C" {
//#endif

void dialJanis(void);
int dial(const char *);
	
@class SCPCallManager;
extern SCPCallManager *SPCallManager;

@class SCPCall;

extern NSString *const SCSCallManagerErrorDomain;

typedef NS_ENUM(NSInteger, SCSCallManagerErrorCode) {
    /** Error (reason unknown).*/
    SCSCallManagerErrorUnknown,
    /** User not allowed to make any outgoing calls. */
    SCSCallManagerErrorOutgoingCallPermissionDisabled,
    /** User not allowed to make any outgoing PSTN calls. */
    SCSCallManagerErrorOutgoingCallPSTNPermissionDisabled,
    /** There is already an active call to that number. */
    SCSCallManagerErrorCallAlreadyExists,
    /** User email / sip address couldn't be found in the directory. */
    SCSCallManagerErrorUserNotFound
};


@interface SCPCallManager : NSObject

//+ (SCPCallManager *)sharedInstance;

- (void)dialJanis;

// ObjC wrapper for scAccountAvailability()
- (int)scAccountAvailability;
- (NSArray *)allCallObjects;
- (NSUInteger)allCallsCount;
// Array copy of non-ended calls, including incomingRinging
- (NSArray<SCPCall *> *)activeCalls;
- (NSUInteger)activeCallCount;
- (NSUInteger)activeConferenceCallCount;
- (NSUInteger)activeCallKitCallCount;
- (NSArray *)endedCalls;

- (SCPCall *)callWithId:(UInt32)iCallId;
- (SCPCall *)callWithUUID:(NSUUID *)uuid;

-(SCPCall *)dial:(NSString *)number uuid:(NSString *)uuid isPSTN:(BOOL)isPSTN displayName:(NSString *)displayName queuedVideoRequest:(BOOL)queuedVideoRequest error:(NSError **)outError;
-(void)onDial:(SCPCall *)call;

-(void)initDTMF;
-(void)stopDTMF;
-(void)resetDTMF;
-(void)playDTMFTone:(NSString*)dtmfValue call:(SCPCall *)call;
-(void)onPlayDTMFTone:(NSString *)dtmfValue;
-(void)pauseDTMFTone;

-(void)stopRingtone:(SCPCall *)c showMissedCall:(BOOL)showMissedCall forceStop:(BOOL)forceStop;

- (void)answerCall:(SCPCall *)c;
- (void)onAnswerCall:(SCPCall *)c;

- (void)onMuteCall:(SCPCall *)c muted:(BOOL)muted;

- (void)terminateCall:(SCPCall *)c;
- (void)onTerminateCall:(SCPCall *)c;

-(void)holdCall:(SCPCall *)c onHold:(BOOL)onHold;
-(void)onHoldCall:(SCPCall *)c onHold:(BOOL)onHold;

-(void)switchToVideo:(SCPCall *)call on:(BOOL)on;

// Utilities - wraps +Utilities
- (NSString *)formattedCallNumber:(NSString *)ns;
- (NSString *)lastCalledNumber;

// Conference
-(void)moveCallToConference:(SCPCall *)aCall;
-(void)onMoveCallToConference:(SCPCall *)aCall;

-(void)moveCallFromConfToPrivate:(SCPCall *)aCall;
-(void)onMoveCallFromConfToPrivate:(SCPCall *)aCall;

- (void)setSelectedCall:(SCPCall *)aCall informProvider:(BOOL)informProvider;

-(void)setVerifyFlag:(BOOL)flag call:(SCPCall *) call;
-(void)setCacheName:(NSString*)cacheName call:(SCPCall *) call;

- (int)handleFncCallback:(void*)ret ph:(void*)ph iCallID:(int)iCallID msgid:(int)msgid ns:(NSString*)ns;
-(SCPCall *)tryFetchCallObjectUsingNumberAndCallIdisNull:(NSString *)str;


@end
