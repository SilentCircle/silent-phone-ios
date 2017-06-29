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
//  SCPCallHelper.h
//  SPi3
//
//  Created by Stelios Petrakis on 20/12/2016.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 SCPCallHelper acts like an intermediate between SCSRootViewController that
 receives the call requests from every point inside (and outside via Intents) SPi
 and SCPCallManager that actually makes -or not- the call.
 
 The purpose of SCPCallHelper is:
 
 a. To figure out and display a dial assist selector based on the options that user has already set.
 b. To delay the call until the user data have been fetched from the API.
 c. Check user permissions and fail gracefully (posts failure notification @see kSCPOutgoingCallRequestFailedNotification).
 d. No notify via the NSNotificationCenter any subscribed class (in our case SCSRootViewController),
    if the call request has been fulfilled (kSCPOutgoingCallRequestFulfilledNotification) or 
    failed due to permissions (kSCPOutgoingCallRequestFailedNotification).
 */
@interface SCPCallHelper : NSObject

/**
 Checks if a given number
 is a star call (starts with a star).

 @param number The number in question.
 @return YES if it is a star call, NO otherwise.
 */
+ (BOOL)isStarCall:(NSString *)number;

/**
 Checks if a given number (phone number, email address, sip address)
 is a magic code or not (e.g. *##*[code]).

 @param number The number in question.
 @return YES if it is a magic number, NO otherwise.
 */
+ (BOOL)isMagicNumber:(NSString *)number;

/**
 Called by a View Controller with a number (phone number, email address, sip address)
 in order to generate a call (or an error)

 @param vc The view controller that initiates the call
 @param nr The phone number, email address, sip address to call
 */
- (void)placeCallFromVC:(UIViewController *)vc withNumber:(NSString *)nr;

/**
 Request an outgoing call from any view controller in the app for a specific number.
 
 SCPCallHelper figures out and displays a dial assist in that particular view controller
 and also checks whether the user data has been loaded or not to delay the request if needed.

 @param viewController The view controller that makes the call request.
 @param number The number (which can be a username, email or phone number) to call.
 @param queueVideoRequest Whether a video request for that outgoing call should be queued and sent when b leg accepts.
 */
- (void)requestOutgoingCallFromViewController:(UIViewController *)viewController withNumber:(NSString *)number queueVideoRequest:(BOOL)queueVideoRequest;

@end
