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
//  ProviderDelegate.h
//  SPi3
//
//  Created by Stylianos Petrakis on 09/09/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCPCall.h"
#import "ChatUtilities.h"

typedef NS_ENUM(NSInteger, ProviderDelegateAction) {
    ProviderDelegateStartCallAction = 1, // Start a call
    ProviderDelegateAnswerCallAction = 2, // Answer a call
    ProviderDelegateEndCallAction = 3, // End a call
    ProviderDelegateSetHeldCallAction = 4, // Hold a call
    ProviderDelegateSetGroupCallAction = 5, // Group a call (Move to conference)
    ProviderDelegateSetMutedCallAction = 6, // Mute/Unmute a call
    ProviderDelegatePlayDTMFCallAction = 7 // Play DTMF digit(s)
};

/**
 The ProviderDelegate class is the class responsible for the CallKit integration.
 
 It handles both the CXProvider (incoming actions [iOS -> SPi]) and the CXCallController (outgoing actions [SPi -> iOS) objects.
 
 You can use the -(BOOL)isSupported method in order to detect if the device supports CallKit before calling any of its methods.
 */
@interface ProviderDelegate : NSObject

/**
 Use this method to check if CallKit has to be used.
 
 CallKit might be supported by the user's device if it is running iOS 10+ but
 user might have Passcode enabled, which should disable CallKit or he might have disabled
 CallKit support from Settings.
 
 This method encapsulates that logic.
 
 @return YES if CallKit can be used, NO otherwise.
 */
+ (BOOL)isEnabled;

/**
 Use this method to detect if CallKit is supported.
 
 Supporting CallKit means that the device runs iOS10 and there is no passcode in place.

 @return YES if CXProvider is supported, NO otherwise.
 */
+ (BOOL)isSupported;

/**
 The current number of active CallKit calls.

 @return The number of active CallKit calls.
 */
- (NSUInteger)callkitCalls;

/**
 Returns whether a call is a CallKit call or not.

 @param call The call object that will be checked.
 @return YES if the call is a CallKit call, NO otherwise.
 */
- (BOOL)isCallkitCall:(SCPCall *)call;

/**
 Informs the CXProvider that the call has ended with a reason.

 @param call The call object.
 */
- (void)reportCallEnded:(SCPCall *)call;

/**
 Informs the CXProvider that the call has been connected.

 @param call The call object.
 */
- (void)reportCallConnected:(SCPCall *)call;

/**
 Informs the CXProvider that a call has started connecting.

 @param call The call object.
 */
- (void)reportCallStartedConnecting:(SCPCall *)call;

/**
 Informs the CXProvider about the incoming call.

 @param call       The incoming call object
 @param drStatus   The data retention status flag, in order to figure out if DR is not enabled, or enabled locally, remotely, or both
 @param completion The completion handler
 */
- (void)reportIncomingCall:(SCPCall *)call drStatus:(SCSDRStatus)drStatus completion:(void (^)(NSError *error))completion;

/**
 Deals with the outgoing user actions from the app to the iOS.

 @param transactionAction The transaction action that might be some of the ProviderDelegateAction values.
 @param call              The call object.
 @param infoDictionary    Extra information dictionary.
 
 @see ProviderDelegateAction
 */
- (void)requestTransaction:(ProviderDelegateAction)transactionAction call:(SCPCall *)call infoDictionary:(NSDictionary *)infoDictionary;

@end
