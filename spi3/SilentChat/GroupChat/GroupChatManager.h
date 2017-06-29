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
//  GroupChatManager.h
//  SPi3
//
//  Created by Gints Osis on 28/10/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "ChatObject.h"
#import "ChatUtilities.h"
#import "RecentObject.h"
#import "DBManager.h"
#import "DBManager+MessageReceiving.h"
#import "SCPNotificationKeys.h"

/**
 GroupChatManager
 
 For group changes to take effect we have to call applyGroupChanges:
 which will send a vector clock of only necessary group changes made 
 since last applyChanges call.

 All group chat commands come in groupCommand() containing a dictionary
 with the neccessary info. Group command types are defined at SCSConstants.h
 
 When there is no network all group commands are stacked in 
 stackedOfflineGroupCommands property and stored in NsUserDefaults.
 
 This class contains 3 Categories
 +UI - Everything for updating Chat UI when group status changes
 +Members - Contains class functions to return memberList with different variations
 +AvatarUpdate - Update avatar when someone is removed or added to group
 */
@interface GroupChatManager : NSObject

/**
 The singleton instance of GroupChatManager.

 Do not use multiple instances of this class.
 
 @return The singleton instance of GroupChatManager
 */
+(GroupChatManager *)sharedInstance;

/**
 Sends a chat object as a group message.

 @param chatObject The chat object
 @return The zina response code
 */
-(int32_t) sendGroupMessage:(ChatObject*) chatObject;

/**
 Sends a chat object to a specific user and to specific devices (if provided).

 @param chatObject The chat object
 @param uuid The user's UUID
 @param deviceIds The array of device ids (can be nil)
 @return The zina response code
 */
-(int32_t) sendGroupMessage:(ChatObject *)chatObject uuid:(NSString *)uuid deviceIds:(NSArray <NSString *> *)deviceIds;

/**
 Leaves a given group.

 @param groupUUID The group uuid
 */
-(void) leaveGroup:(NSString *) groupUUID;

/**
 Creates a new group.
 
 This is synchronous call and may take some time.
 
 @return The group uuid
 */
-(NSString *) createGroup;

/**
 Adds a user to the group.

 @param Conversation object to add
 @param uuid The group uuid
 */
-(void) addUser:(RecentObject *) conversation inGroup:(NSString *) uuid;

/**
 Sets the burn time.

 @param burnTime The burn time
 @param uuid The group uuid
 */
-(void)setBurnTime:(long)burnTime inGroup:(NSString *)uuid;

/**
 Resets the group avatar.

 @param uuid The group id
 */
-(void)resetAvatarInGroup:(NSString *) uuid;

/**
 Sets the group name.

 @param name The custom group name
 @param uuid The group uuid
 @return The zina response code
 */
-(int32_t) setName:(NSString *) name inGroup:(NSString *) uuid;

/**
 Applies any group changes to other participants.

 @param uuid The group uuid
 */
-(void) applyGroupChanges:(NSString *) uuid;

/**
 Constructs displayname string for given array of members.

 @param members Array of RecentObject's, contains displayName or display alias downloading for contactnames
 @return displayname for group
 */
-(NSString *) getDisplayNameForGroupMembers:(NSArray *) members;

/**
 Sets an attachment as an avatar image and
 sends it to other participants.
 
 @param attachmentDict The attachment dictionary containing the image
 @param uuid The group uuid
 @return The zina response code
 */
-(int32_t) setExplicitAvatarWithAttachmentDict:(NSDictionary *) attachmentDict inGroup:(NSString *) uuid;

/**
 Manually burns one or more group messages.

 @param messageIds The array of message ids.
 @param groupId The group UUID.
 @return YES if everything was OK, NO otherwise.
 */
- (BOOL)burnGroupMessages:(NSArray<NSString *> *)messageIds inGroup:(NSString *)groupId;

/**
 Returns a normalized version of a given group UUID.
 
 It removes the @sip.silentcircle.net suffix and uppercases the string.

 @param groupUUID The provided group UUID.
 @return The normalized group UUID string.
 */
+ (NSString *)normalizeGroupUUID:(NSString *)groupUUID;

/**
 Sends group command to sibling about read messages

 @param array array of ChatObjects to mark as read
 */
-(void) sendGroupReadReceipts:(NSArray <ChatObject*>*) array;

/**
 Sends read receipts for all unread messages in group
 
  @param groupRecent The provided group RecentObject.
 */
-(void) sendGroupReadReceiptsForGroup:(RecentObject *)groupRecent;

@end
