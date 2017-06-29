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
//  SCPNotificationsManager.h
//  SPi3
//
//  Created by Stelios Petrakis on 01/11/2016.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPCall.h"
#import "ChatObject.h"
#import "SystemPermissionManager.h"

/**
 Notifications manager abstracts the local notification handling for incoming call and message notifications.
 
 Manager supports both the older UILocalNotification (up to iOS 9) framework and the new User Notification (iOS 10.0+) framework.
 
 There is an object of this class as a public property of the Switchboard singleton instance that is responsible for the notification handling
 throughout the app.
 */
@interface SCPNotificationsManager : NSObject <SystemPermissionManagerDelegate>

/**
 Removes all delivered and pending notifications and sets the badge number to zero.
 */
-(void)cancelAllNotifications;

/**
 Removes any delivered or pending notifications for a call.
 
 Supports both old and new framework.

 @param call The call object
 */
-(void)cancelNotificationForCall:(SCPCall *)call;

/**
 Cancels the delivered notification for a chat object based on its msgId property.
 
 Supports only on the new framework.

 @param chatObject The chat object
 */
-(void)cancelMessageNotificationForChatObject:(ChatObject *)chatObject;

/**
 Legacy method to handle the old UILocalNotification notification framework responses for both calls and messages

 Supports only the old framework.
 
 @param identifier The action identifier (e.g. answer, decline, end etc)
 @param notification The UILocalNotification object
 */
-(void)handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification;

/**
 Present a local notification for an incoming video call request for the active call.
 
 Supports both old and new framework.
 
 @param call The call object
 */
-(void)presentVideoRequestNotificationForCall:(SCPCall *)call;

/**
 Present a local notification for incoming call.
 
 Supports both old and new framework.

 @param call The call object
 */
-(void)presentIncomingCallNotificationForCall:(SCPCall *)call;

/**
 Present a local notification when the remote user ends the call without getting answered (missed).

 Supports both old and new framework.

 @param call The call object
 */
-(void)presentMissedCallNotificationForCall:(SCPCall *)call;

/**
 Presents a local notification for incoming message. 
 
 For the older framework the notification identifier is the contactName property of the chatObject,
 whereas for the new framework the identifier is the msgId property so they can be individually cancelled via the
 cancelMessageNotificationForChatObject: method.

 Supports both old and new framework.

 @param chatObject The chat object
 */
-(void)presentIncomingMessageNotificationForChatObject:(ChatObject *)chatObject;

@end
