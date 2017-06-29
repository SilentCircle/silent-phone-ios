//
//  SCSAvatarManager+Updating.h
//  SPi3
//
//  Created by Gints Osis on 18/05/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCSAvatarManager.h"

@interface SCSAvatarManager (Updating)

/**
 Generate new avatar for group consisting of first four member images
 
 When generating group we need first four members in memberlist to be resolved. If we have more than 4 members we resolve first three and show +count image as the fourth one
 
 
 If we find an unresolved ConversationObject in passed memberList we post kSCSRecentObjectShouldResolveNotification and return. Which will call this function again on all groups which will contain resolved RecentObject

 @param conversation group conversation
 @param memberList member list for group, if passed nil memberlist is taken from the group. Since it's taken directly from zina it takes some time to fetch it
 */
-(void)updateAvatarForGroup:(RecentObject *) conversation withMemberList:(NSArray *) memberList;
@end
