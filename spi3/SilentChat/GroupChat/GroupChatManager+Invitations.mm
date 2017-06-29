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
//  GroupChatManager+Invitations.m
//  SPi3
//
//  Created by Gints Osis on 03/11/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "GroupChatManager+Invitations.h"
#import "GroupChatManager+Members.h"
#import "axolotl_glue.h"
#import "DBManager+MessageReceiving.h"

@implementation GroupChatManager (Invitations)


NSString * const kUserJoined = @"joined";
NSString * const kUserDeclined = @"declined";
NSString * const kInviteAccepted = @", accepted invite!";
NSString * const kInviteDeclined = @", declined invite!";
NSString * const kUserLeft = @"left";
NSString * const kGroupCreated = @"Group Created";

NSString * const kPendingInvitation = @"Pending Invitation to join group";


-(void)createPendingInvitationForGroupWithDict:(NSDictionary *) dict
{
    NSString *grpUUID = [dict objectForKey:@"grpId"];
    NSString *displayName = [dict objectForKey:@"name"];
    
    
    ChatObject *chatObject = [[ChatObject alloc] initWithText:kPendingInvitation];
    
    chatObject.contactName = grpUUID;
    chatObject.displayName = displayName;
    
    [[DBManager dBManagerInstance] showMsgNotif:chatObject];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"updateAppBadge" object:nil];
    [self finishCreatingChatObject:chatObject];
}

-(void)createJoinedGroupChatMessage:(NSDictionary *) dict
{
    NSString *grpUUID = [dict objectForKey:@"grpId"];
    NSString *displayName = [dict objectForKey:@"name"];
    
    
    ChatObject *chatObject = [[ChatObject alloc] initWithText:@"You have been invited to this group"];
    
    chatObject.contactName = grpUUID;
    chatObject.displayName = displayName;
    [self finishCreatingChatObject:chatObject];
}

-(void)addCreateGroupMessage:(RecentObject *) recent
{
    NSString *grpUUID = recent.contactName;
    NSString *displayName = recent.displayName;
    
    
    ChatObject *chatObject = [[ChatObject alloc] initWithText:kGroupCreated];
    
    chatObject.contactName = grpUUID;
    chatObject.displayName = displayName;
    [self finishCreatingChatObject:chatObject];
}
/*
 Displays user accepted or declined chat bubble usually this comes before user joined command
 */
-(void) createUserReactedToInvitationToGroupWithDict:(NSDictionary *) dict
{
    NSString *grpUUID = [dict objectForKey:@"grpId"];
    RecentObject *recentObject = [[DBManager dBManagerInstance] getRecentByName:grpUUID];
    
    // we have left this group
    if (!recentObject) {
        return;
    }
    // group chats should always have display name
    NSString *displayName = recentObject.displayName;
    
    NSString *memberName = [dict objectForKey:@"mbrId"];
    
    NSString *userDisplayName = [[ChatUtilities utilitiesInstance] getDisplayNameFromUserOrAlias:memberName];
    
    int acceptedInt = [[dict objectForKey:@"acc"] intValue];
    BOOL accepted = NO;
    if(acceptedInt == 1)
        accepted = YES;
    
    [self createInvitationAnswerForGroup:grpUUID memberName:userDisplayName displayName:displayName didAccept:accepted forUser:NO];
}

/*
 Creates user joined chat bubble
 */
-(void) createUserJoinedGroupWithDict:(NSDictionary *) dict
{
     NSString *memberName = [dict objectForKey:@"mbrId"];
    NSString *userDisplayName = [[ChatUtilities utilitiesInstance] getDisplayNameFromUserOrAlias:memberName];
    NSString *grpUUID = [dict objectForKey:@"grpId"];
    
    NSMutableArray *currentMembers = [[GroupChatManager getAllGroupMembers:grpUUID] mutableCopy];
    
    if (![currentMembers containsObject:memberName])
    {
        [currentMembers addObject:memberName];
    }
    
    RecentObject *recent = [[DBManager dBManagerInstance] getRecentByName:grpUUID];
    [recent updateGroupAvatarWithMemberList:currentMembers];
    
    
    [self createInvitationAnswerForGroup:grpUUID memberName:userDisplayName displayName:recent.displayName didAccept:YES forUser:YES];
}

-(void) createInvitationAnswerForGroup:(NSString *) grpUUID memberName:(NSString *) memberName displayName:(NSString *) displayName didAccept:(BOOL) accept forUser:(BOOL) forUser
{
    NSString *action = nil;
    NSString *messageText = nil;
    if (accept)
    {
        action = forUser?kUserJoined:kInviteAccepted;
    } else
    {
        action = forUser?kUserLeft:kInviteDeclined;
    }
    if (forUser)
    {
        messageText = [NSString stringWithFormat:@"%@ %@",memberName,action];
    } else
    {
        messageText = [NSString stringWithFormat:@"%@%@",memberName,action];
    }
    ChatObject *chatObject = [[ChatObject alloc] initWithText:messageText];
    
    chatObject.contactName = grpUUID;
    chatObject.displayName = displayName;
    [self finishCreatingChatObject:chatObject];
}




-(void) createLeaveGroup:(NSDictionary *) dict
{
    NSString *memberName = [dict objectForKey:@"mbrId"];
    NSString *userDisplayName = [[ChatUtilities utilitiesInstance] getDisplayNameFromUserOrAlias:memberName];
    NSString *grpUUID = [dict objectForKey:@"grpId"];
    
    NSMutableArray *currentMembers = [[GroupChatManager getAllGroupMembers:grpUUID] mutableCopy];
    
    RecentObject *recent = [[DBManager dBManagerInstance] getRecentByName:grpUUID];
    
    if (!recent)
    {
        return;
    }
    
    [recent updateGroupAvatarWithMemberList:currentMembers];
    
    ChatObject *chatObject = [[ChatObject alloc] initWithText:[NSString stringWithFormat:@"%@ %@",userDisplayName,kUserLeft]];
    
    chatObject.contactName = grpUUID;
    chatObject.displayName = recent.displayName;
    [self finishCreatingChatObject:chatObject];
    
    
}

-(void) finishCreatingChatObject:(ChatObject *) chatObject
{
    chatObject.isInvitationChatObject = 1;
    chatObject.isGroupChatObject = YES;
    
    
    chatObject.isReceived = 0;
    chatObject.isRead = 0;
    chatObject.iSendingNow = 0;
    
    uuid_string_t msgid;
    chatObject.msgId = [NSString stringWithFormat:@"%s",CTAxoInterfaceBase::generateMsgID(chatObject.messageText.UTF8String, msgid, sizeof(msgid))];
    
    
    // TODO should disable burn for group chats
    chatObject.burnTime = 999999999;
    [chatObject takeTimeStamp];
    [[DBManager dBManagerInstance] saveMessage:chatObject];
    
     [[NSNotificationCenter defaultCenter] postNotificationName:kSCPReceiveMessageNotification object:chatObject];

}
@end
