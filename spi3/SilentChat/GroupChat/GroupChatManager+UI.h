//
//  GroupChatManager+UI.h
//  SPi3
//
//  Created by Gints Osis on 13/02/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "GroupChatManager.h"
/*
 Category to contain GroupChat functions that update Chat UI directly
 */
@interface GroupChatManager (UI)

/*
 Create group status update ChatObject for group.
 
 Will create a ChatObject with isInvitationChatObject = 1, meaning it will be displayed as centered text in chat thread. 
 Use this to create any overall changes in group that user should know about.
 
 
 @param dict
 "grpId" - key for group uuid
 "name" - display name if necessary for created chatobject
 
 @param message - messageText for ChatObject
 @param showAlert - should show local alert after creation, set this to YES if group status change was caused by another party
 
 @return - created msgid
 */
+(NSString *)createGroupStatusMessageWithDict:(NSDictionary *) dict message:(NSString *) message showAlert:(BOOL) showAlert;

/*
 Creates error chat message in conversation for passed group uuid
 
 @param grpUUID - group uuid
 @param message - error message
 */
+(NSString *) createGroupErrorForUUID:(NSString *) grpUUID message:(NSString *) message;

/*
 Process update displayname command
 @param commandDict - command Dict from group command
 */
+(void) updateGroupNameWithGroupCommand:(NSDictionary *) commandDict;

/**
 Checks if all group members have been resolved
 updates the group name and saves it to the database
 If any of the members of the group hasn't been resolved
 it spawns a kSCSRecentObjectShouldResolveNotification for
 any partially loaded member and sets the group display name
 to kNewGroupConversation if it's nil.

 @param groupRecent The group RecentObject
 */
+ (void)updateImplicitGroupNameForGroup:(RecentObject *)groupRecent;

/*
 Process burn group command
 @param commandDict - command Dict from group command
 */
+(void) updateBurnFromGroupCommand:(NSDictionary *)commandDict;

/*
 Creates group status message about some user joining or leaving the group
 @param dict - groupcommand passed in groupcallback
 @param byUserAction - whether current user made the member count change by adding or removing someone from group. Used to change text in group status message from "member joined" to "you joined member"
 @param showAlert - should show local alertview about group membercount change.
 */
+(void) createMemberCountChangedMessageFromGroupCommand:(NSDictionary *) dict byUserAction:(BOOL) userAction showAlert:(BOOL) showAlert;

/*
 Deletes group with passed uuid and posts kSCSRecentObjectRemovedNotification
 Called after receiving "lve" command
 
  When kSCSRecentObjectRemovedNotification is received passed recentObject can be nil so UI should account for this
  Usually ViewControllers will hold a local reference to opened recentObject which can be nil when kSCSRecentObjectRemovedNotification is called in this case
 */
+(void) removeGroup:(NSString *) grpUUID;
@end
