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

#import "DBManager.h"
#import "axolotl_glue.h"

extern NSDictionary *dictFromCString(const std::string& str);

@class ChatObject;

void stateAxoMsg(int64_t messageIdentfier, int32_t statusCode, const std::string& stateInformation);
int32_t receiveAxoMsg(const std::string& messageDescriptor, const std::string& attachementDescriptor, const std::string& messageAttributes);
void notifyCallback(int32_t notifyAction, const std::string& actionInformation, const std::string& devId);

@interface DBManager (MessageReceiving)
-(int64_t) sendReadNotificationFromTheSameThread:(ChatObject *) thisChatObject;
-(void) sendReadNotification:(ChatObject *) thisChatObject;
-(void) sendForceBurn:(ChatObject *) thisChatObject;
-(int64_t) sendForceBurnFromTheSameThread:(ChatObject *) thisChatObject;
-(int) receiveMessageDict:(NSDictionary*) userData;
-(int) storeMessageDict:(NSDictionary*) userData attributeDict:(NSDictionary *)attributeDict attachmentDict:(NSDictionary *)attachmentDict;
- (BOOL)shouldIgnoreIncomingMessageAsDuplicateUsingMessageDict:(NSDictionary *)messageDict attributeDict:(NSDictionary *)attributeDict attachmentDict:(NSDictionary *)attachmentDict;
-(void)showMsgNotif:(ChatObject*)o;

+(ChatObject *) getLastSentChatObjectForUUID:(NSString *) uuid;

+(ChatObject *) getLastSentChatObjectForRecent:(RecentObject *) recentObject;

/**
 Resends last message for all conversations (including groups)
 for a specific uuid and device ids.
 
 Used when the notify callback is called with a DEVICE_SCAN notifyAction.
 
 @param uuid The user's UUID
 @param deviceIds The array of device ids of the user
 */
+ (void)resendLastMessageForUUID:(NSString *)uuid deviceIds:(NSArray <NSString *> *)deviceIds;

/**
 Removes an array of message ids from a certain group.
 
 @param messages The array of message ids.
 @param groupUUID The group unique identifier.
 */
+ (void)removeMessages:(NSArray <NSString *> *)messages fromRecentWithID:(NSString *)recentID;

@end
