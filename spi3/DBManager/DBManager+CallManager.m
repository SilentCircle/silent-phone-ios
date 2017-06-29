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
//  DBManager+CallManager.m
//  SPi3
//
//  Created by Gints Osis on 01/08/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "DBManager+CallManager.h"
#import "SCPCall.h"
#import "SCSEnums.h"
#import "ChatUtilities.h"
#import "UserService.h"
#import "DBManager.h"
#import "SCPCallbackInterface.h"
#import "SCPNotificationKeys.h"

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelWarning;
//#endif

@implementation DBManager (CallManager)
/*
 Take call info from SCPCall and add it to chatObject, refresh Recents and Chat tableViews
 */
-(void)callDidEnd:(NSNotification *) notification
{
    DDLogInfo(@"%s callDidEndNotification.userInfo: %@", __FUNCTION__, notification.userInfo);
    
    /*
     * NOTE: in at least one (hopefully rare) case, the notification
     * userInfo could be nil.
     * @see [SCPCallManager onEndCall:] for details.
     */
    SCPCall *call = (SCPCall *)notification.userInfo[kSCPCallDictionaryKey];
    if (!call)
        return;
    
    ChatObject *callObject = [[ChatObject alloc] initWithCall];
    NSString *assertedID = call.bufAssertedID;
    NSString *contactName = nil;
    if(assertedID.length)
    {
        contactName = assertedID;
    }
    else if(call.bufDstUUID.length)
    {
        contactName = call.bufDstUUID;
    }
    else if(call.bufPeer.length)
    {
        contactName = call.bufPeer;
    }
    else
    {
        contactName = call.bufDialed;
    }
    if ([contactName hasPrefix:@"+"]) {
        //  contactName = [contactName substringFromIndex:1];
        contactName = [[ChatUtilities utilitiesInstance] cleanPhoneNumber:contactName];
    }
    
    if (!contactName) {
        return;
    }
    if ([[[ChatUtilities utilitiesInstance] removePeerInfo:contactName lowerCase:NO] isEqualToString:[UserService currentUser].userID] )
    {
        return;
    }
    contactName = [[ChatUtilities utilitiesInstance] addPeerInfo:contactName lowerCase:NO];
    callObject.contactName = contactName;
    callObject.displayName = [call getName];
    callObject.msgId = call.uniqueCallId;
    callObject.isCall = YES;
    callObject.isRead = 1;
    callObject.isIncomingCall = call.isIncoming;
    //TODO copy end reason, error message
    
    // detect callState for CallState enum
    if (call.sipHasErrorMessage) {
        callObject.callState = eSipError;
        callObject.messageText = call.bufMsg;
    } else
    {
        if([call isAnswered])
        {
            callObject.callState = eIncomingAnswered;
            
            if(call.bufDialed)
            {
                callObject.callState = eDialedEnded;
            } else
            {
                callObject.callState = eIncomingAnswered;
            }
            callObject.callDuration = call.duration;
            
        } else
        {
            if(call.bufDialed)
            {
                callObject.callState = eDialedNoAnswer;
            } else
            {
                if (call.iEnded == 1) {
                    callObject.callState = eIncomingDeclined;
                } else
                {
                    callObject.callState = eIncomingMissed;
                    RecentObject *openedRecent = [ChatUtilities utilitiesInstance].selectedRecentObject;
                    
                    // if call doesn't specifically say's not to treat it as missed call, in case of answered elsewhere
                    if (!call.shouldNotAddMissedCall) {
                        if (openedRecent) {
                            NSString *openedChatUserName = [[ChatUtilities utilitiesInstance] addPeerInfo:openedRecent.contactName lowerCase:YES];
                            
                            if ([openedChatUserName isEqualToString:contactName]) {
                                [[ChatUtilities utilitiesInstance] addBadgeNumberWithChatObject:callObject];
                                callObject.isRead = -1;
                            }
                        } else
                        {
                            [[ChatUtilities utilitiesInstance] addBadgeNumberWithChatObject:callObject];
                            callObject.isRead = -1;
                        }
                    }
                }
            }
        }
    }
    
    

    [callObject addCall:call];
    
    // if call doesn't have sipError to set as messageText
    // calculate our own call bubble text from callstate
    if (!call.sipHasErrorMessage) {
        callObject.messageText = [[ChatUtilities utilitiesInstance] getCallInfoFromCallChatObject:callObject];
    }
    if(call.shouldNotAddMissedCall){
        callObject.messageText = NSLocalizedString(@"Answered elsewhere", nil);
    }
    callObject.unixTimeStamp = time(NULL);
    callObject.unixReadTimeStamp = time(NULL);

    RecentObject *recentObject = [[DBManager dBManagerInstance] getOrCreateRecentObjectWithContactName:contactName];
    
    if(recentObject) {
    
        if(recentObject.isPartiallyLoaded) {
            
            [recentObject setIsPartiallyLoaded:NO];
            [recentObject setDisplayName:[call getName]];
            [recentObject setDisplayAlias:[call alias]];
            
            [[DBManager dBManagerInstance] saveRecentObject:recentObject];

            [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification
                                                                object:self
                                                              userInfo:@{ kSCPRecentObjectDictionaryKey : recentObject }];
        }

        callObject.burnTime = recentObject.burnDelayDuration;
    }
    
    // there is no burn timers for callobject's
    /*
     //deal with burntimer
     RecentObject *thisRecent = [[DBManager dBManagerInstance]getOrCreateRecent:callObject.contactName];
     if(thisRecent)
     callObject.burnTime = thisRecent.burnDelayDuration;
     else
     callObject.burnTime = [ChatUtilities utilitiesInstance].kDefaultBurnTime;
     
     
     [self setOffBurnTimerForBurnTime:callObject.burnTime andChatObject:callObject checkForRemoveal:NO];
     */
#if HAS_DATA_RETENTION
    callObject.drEnabled = ([Switchboard doesUserRetainDataType:kDRType_Call_Metadata] || [Switchboard doesUserRetainDataType:kDRType_Call_PlainText]);

#endif // HAS_DATA_RETENTION

    [[DBManager dBManagerInstance] saveMessage:callObject];

#if HAS_DATA_RETENTION
    if ([Switchboard doesUserRetainDataType:kDRType_Call_Metadata]) {
        // retain call metadata in a background thread
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [Switchboard retainCallMetadata:call];
        });
    }
#endif // HAS_DATA_RETENTION
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSCPReceiveMessageNotification object:self userInfo:@{kSCPChatObjectDictionaryKey:callObject}];
}
@end
