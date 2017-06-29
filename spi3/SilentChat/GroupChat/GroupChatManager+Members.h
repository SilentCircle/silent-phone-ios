//
//  GroupChatManager+Members.h
//  SPi3
//
//  Created by Gints Osis on 24/01/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "GroupChatManager.h"
#import "../../../libs/libzina/util/Utilities.h"

@interface GroupChatManager (Members)

/*
 Returns array of all available info for group member
 Currently returns array of dictionary objects with keys ..
 contactName,
 joinTime
 */
+(NSMutableArray *) getAllGroupMemberInfo:(NSString *) groupUUID;

/*
 Returns array of all group members as RecentObject's
 Existing recents in conversations are taken out of database
 Non existing recents are created new with only contactname assigned
 */
+(NSMutableArray *) getAllGroupMemberRecentObjects:(NSString *) groupUUID;



/*
 returns array of grpIds in which passed uuid is a member of
 @param - uuid uuid of a member
 
 @return NSArray of grpId NSStrings
 */
+(NSArray *) getGroupsWithUUID:(NSString *) uuid;
@end
