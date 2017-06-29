//
//  GroupChatManager+Messages.h
//  SPi3
//
//  Created by Gints Osis on 21/04/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "GroupChatManager.h"

@interface GroupChatManager (Messages)

/**
 Includes everything reguarding message updating for group chats
 */


/*
 Processes passed group command with "rr" group command
 Finds messages in DB by passed msgIds and marks them as read if they are not already read
 saves messages again, removes badge for marked messages and post ChatObjectUpdated notification for each one
 */
+(void) processMessageReadReceiptsCommand:(NSDictionary *) readCommand;

/*
 Removes msgID from read status cache and saves userdefaults
 */
+(void) removeCachedReadStatusMsgId:(NSString *) msgId;


// Check comment on cachedReadStatuses static variable in this categories implementation

/*
 Checks if message exists in cache, wrapper for containsObject: check
 */
+(BOOL) existsCachedReadStatusMsgId:(NSString *) msgId;

/*
 Adds msgId and readtime to cache
 */
+(void)addReadStatusMsgIdToCache:(NSString *)msgId readTime:(NSString *) readTime;

/*
 Assign entire cache usually from NsUserDefaults
*/
+(void) setCachedReadStatuses:(NSDictionary *) array;

/*
 Returns readTime for msgId from cache
 */
+(long) getCachedReadTimeForMsgId:(NSString *) msgId;
@end
