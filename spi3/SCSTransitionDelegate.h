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
//  SCSTransitionDelegate.h
//  SCSuite
//
//  Created by Eric Turner on 10/24/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AddressBookContact.h"

@class SCPCall;
@class SCSDualKeyboardsVC;
@class ChatObject;


@protocol SCSTransitionDelegate <NSObject>
@optional

- (void)placeCallFromVC:(UIViewController *)vc withNumber:(NSString *)nr;
- (void)localUserEndedCall:(SCPCall*)aCall;

/**
 Presents the Call Screen and dials the number of the contact name after the app is
 launched with an intent.
 
 @param contactName The contact name that is going to be dialed
 @param queueVideoRequest Whether a video request should be queued for the call and be sent when b leg accepts the call.
 */
- (void)presentCallScreenForContactName:(NSString *)contactName queueVideoRequest:(BOOL)queueVideoRequest;

- (void)transitionToCallScreenFromVC:(UIViewController    *)vc withCall:(SCPCall*)aCall;
- (void)transitionToVideoScreenFromVC:(UIViewController   *)vc withCall:(SCPCall*)aCall;
- (void)transitionToConferenceFromVC:(UIViewController    *)vc withCall:(SCPCall*)aCall;
- (void)transitionToChatFromVC:(UIViewController          *)vc withCall:(SCPCall*)aCall;
- (void)transitionToConversationsFromVC:(UIViewController *)vc;
- (void)transitionToConversationsFromVC:(UIViewController *)vc withCall:(SCPCall*)aCall;

/* burger - refactored to protocol method from showChatForContactName: */
/** [From showChatViewForContactName: - needs doc update]
 Switches to the main tab (conversations), pops to the root controller 
 and opens the chat window for a contact name without making a check.
 
 If you want to first check if the contact name exists 
 (either already in the conversations list or generally in Silent Circle)
 you can use Utilities' singleton's method checkIfContactNameExists:completion:
 
 @param contactName The string of the contact we want to open the chat window for
 
 @see [[ChatUtilities utilitiesInstance] checkIfContactNameExists:completion:]
 */
-(void)transitionToChatWithContactName:(NSString *) contactName;

/**
 *
 * @param searchStr Forward looking param for displaying searchVC with
 * an existing search string. May be nil.
 */
- (void)presentSearchController:(NSString *)searchStr;

/**
 Presents the forwarding interface using SearchViewController on top of the active chat
 */
- (void)presentForwardScreenInController:(UIViewController *)vc withChatObject:(ChatObject*)chatObject;

/**
 Presents the contact selection interface using SearchViewController on top of the active chat
 */
- (void)presentContactSelectionScreenInController:(UIViewController *)vc completion:(void (^)(AddressBookContact *contact))completion;

- (void)displayAlertWithText:(NSString *)text message:(NSString *)message;

- (void)displayDRProhibitionAlert;

@end

