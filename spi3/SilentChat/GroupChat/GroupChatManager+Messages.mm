//
//  GroupChatManager+Messages.m
//  SPi3
//
//  Created by Gints Osis on 21/04/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "GroupChatManager+Messages.h"
#import "DBManager.h"
#import "ChatObject.h"
#import "ChatUtilities.h"

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

@implementation GroupChatManager (Messages)

/*
 Static variable containing received read receipt msgId's for which there is no message received yet
 key - msgId
 value - read time in ISO format
 
 When a group message is received we check if its msgId is found in this cache, if it is then we mark the message as read and skip addition of badge number for it and remove it
 
 Whenever cache is changed it's stored in NsUserDefaults with cachedReadStatuses as key
 */
static NSMutableDictionary *cachedReadStatuses;

+(void)processMessageReadReceiptsCommand:(NSDictionary *)readCommand
{
    NSDictionary *msgIDs = [readCommand objectForKey:@"msgIds"];
    NSString *grpId = [readCommand objectForKey:@"grpId"];
    
    DDLogDebug(@"%s : uuid = %@  msgIds = %@",__FUNCTION__,grpId,msgIDs);
    
    // timestamp is passed in ISO format to avoid collision with calendars
    NSString *readTime = [readCommand objectForKey:@"rr_time"];
    
    long unixReadTimeStamp = [[ChatUtilities utilitiesInstance] getUnixTimeFromISO8601:readTime];
    for (NSString *msgId in msgIDs)
    {
        ChatObject *chatObject = [[DBManager dBManagerInstance] loadEventWithMessageID:msgId andContactName:grpId];
        if (chatObject)
        {
            if (chatObject.isRead != 1)
            {
                chatObject.isRead = 1;
                chatObject.unixReadTimeStamp = unixReadTimeStamp;
                [[DBManager dBManagerInstance] saveMessage:chatObject];
                [[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectUpdatedNotification object:self userInfo:@{kSCPChatObjectDictionaryKey:chatObject}];
                [[ChatUtilities utilitiesInstance] removeBadgeNumberForChatObject:chatObject];
                
            }
        } else
        {
            [[self class] addReadStatusMsgIdToCache:msgId readTime:readTime];
        }
    }
}

+(void) removeCachedReadStatusMsgId:(NSString *) msgId
{
    DDLogDebug(@"%s : %@",__FUNCTION__,msgId);
    if (cachedReadStatuses)
    {
        [cachedReadStatuses removeObjectForKey:msgId];
        [[NSUserDefaults standardUserDefaults] setObject:cachedReadStatuses forKey:@"cachedReadStatuses"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+(BOOL) existsCachedReadStatusMsgId:(NSString *) msgId
{
    return [cachedReadStatuses.allKeys containsObject:msgId];
}

+(void)addReadStatusMsgIdToCache:(NSString *)msgId readTime:(NSString *) readTime
{
    DDLogDebug(@"%s : %@",__FUNCTION__,msgId);
    if (!cachedReadStatuses)
    {
        cachedReadStatuses = [NSMutableDictionary new];
    }
    [cachedReadStatuses setObject:readTime forKey:msgId];
    [[NSUserDefaults standardUserDefaults] setObject:cachedReadStatuses forKey:@"cachedReadStatuses"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
+(long)getCachedReadTimeForMsgId:(NSString *)msgId
{
    DDLogDebug(@"%s : %@",__FUNCTION__,msgId);
    NSString *readTime = [cachedReadStatuses objectForKey:msgId];
    long unixReadTimeStamp = [[ChatUtilities utilitiesInstance] getUnixTimeFromISO8601:readTime];
    return unixReadTimeStamp;
}

+(void) setCachedReadStatuses:(NSDictionary *) dict
{
    cachedReadStatuses = [dict mutableCopy];
}

@end
