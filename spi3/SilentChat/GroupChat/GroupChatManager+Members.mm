//
//  GroupChatManager+Members.m
//  SPi3
//
//  Created by Gints Osis on 24/01/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "GroupChatManager+Members.h"

#import "SQLiteStoreConv.h"
#import "ChatUtilities.h"
#import "AppInterfaceImpl.h"
#import "SCPCallbackInterface.h"
#import "DBManager.h"
#import "RecentObject.h"
using namespace std;
using namespace zina;

@implementation GroupChatManager (Members)

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

+(NSMutableArray *) getAllGroupMembers:(NSString *) groupUUID
{
    if(!groupUUID)
        return nil;
    DDLogDebug(@"%s : %@",__FUNCTION__,groupUUID);
    
    NSString * groupUUIDWIthoutPeerInfo = [[self class] normalizeGroupUUID:groupUUID];
    string groupUUIDStr = groupUUIDWIthoutPeerInfo.UTF8String;
    
    SQLiteStoreConv* store = SQLiteStoreConv::getStore();
    NSMutableArray *membersArray = [[NSMutableArray alloc] init];
    list<JsonUnique> members;
    store->getAllGroupMembers(groupUUIDStr, members);
    while (!members.empty())
    {
        string recipient(Utilities::getJsonString(members.front().get(), "mbrId", ""));
        [membersArray addObject:[NSString stringWithUTF8String:recipient.c_str()]];
        members.pop_front();
    }
    
    return membersArray;
}

+(NSMutableArray *) getAllGroupMemberRecentObjects:(NSString *) groupUUID
{
    DDLogDebug(@"%s : %@",__FUNCTION__,groupUUID);
    groupUUID = [GroupChatManager normalizeGroupUUID:groupUUID];
    NSMutableArray *members = [self getAllGroupMembers:groupUUID];
    
    NSMutableArray *memberRecentObjects = [[NSMutableArray alloc] initWithCapacity:members.count];
    
    for (NSString *member in members)
    {
        RecentObject *recent = [[DBManager dBManagerInstance] getRecentByName:member];
        
        if (!recent)
            recent = [Switchboard.userResolver cachedRecentWithUUID:member];
            
        if(!recent)
        {
            recent = [RecentObject new];
            recent.contactName          = member;
            recent.isPartiallyLoaded    = YES;
        }

        [memberRecentObjects addObject:recent];
    }
    
    return memberRecentObjects;
}

+(NSMutableArray *) getAllGroupMemberInfo:(NSString *) groupUUID
{
    if(!groupUUID)
        return nil;
    DDLogDebug(@"%s : %@",__FUNCTION__,groupUUID);
    
    NSString * groupUUIDWIthoutPeerInfo = [[self class] normalizeGroupUUID:groupUUID];

    string groupUUIDStr = groupUUIDWIthoutPeerInfo.UTF8String;
    
    SQLiteStoreConv* store = SQLiteStoreConv::getStore();
    NSMutableArray *membersArray = [[NSMutableArray alloc] init];
    list<JsonUnique> members;
    store->getAllGroupMembers(groupUUIDStr, members);
    while (!members.empty())
    {
        string recipient(Utilities::getJsonString(members.front().get(), "mbrId", ""));
        double joinTime = Utilities::getJsonDouble(members.front().get(), "mbrMT", 0);
        
        // this is not used
        // double memberAttribute = Utilities::getJsonDouble(members->front().get(), "mbrA", 0);
        
        NSString *contactName = [NSString stringWithUTF8String:recipient.c_str()];
        
        NSDictionary *memberInfoDict = @{@"contactName":contactName, @"joinTime":[NSNumber numberWithDouble:joinTime]};
        [membersArray addObject:memberInfoDict];
        members.pop_front();
    }
    
    return membersArray;
}

+(NSArray *) getGroupsWithUUID:(NSString *) uuid
{
    NSMutableArray *memberGroups = [[NSMutableArray alloc] init];
    zina::SQLiteStoreConv* store = zina::SQLiteStoreConv::getStore();
    std::string uuidStr = [[ChatUtilities utilitiesInstance] removePeerInfo:uuid lowerCase:YES].UTF8String;
    std::list<JsonUnique> groups;
    store->listAllGroupsWithMember(uuidStr, groups);
    while (!groups.empty())
    {
        std::string grpId(Utilities::getJsonString(groups.front().get(), "grpId", ""));
        [memberGroups addObject:[NSString stringWithUTF8String:grpId.c_str()]];
        groups.pop_front();
    }
    return [NSArray arrayWithArray:memberGroups];
}
@end
