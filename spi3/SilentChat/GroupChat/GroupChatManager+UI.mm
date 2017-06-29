//
//  GroupChatManager+UI.m
//  SPi3
//
//  Created by Gints Osis on 13/02/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "ChatObject.h"
#import "ChatUtilities.h"
#import "RecentObject.h"
#import "DBManager.h"
#import "SCPNotificationKeys.h"
#import "GroupChatManager+UI.h"
#import "GroupChatManager+Members.h"
#import "SCSConstants.h"

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

@implementation GroupChatManager (UI)

+(void) createMemberCountChangedMessageFromGroupCommand:(NSDictionary *) dict byUserAction:(BOOL) userAction showAlert:(BOOL) showAlert
{
    if (!dict)
        return;
    NSArray *members = [dict objectForKey:@"mbrs"];
    __block NSString *blockUUID = [dict objectForKey:@"grpId"];
    __block NSString *grpCommand = [dict objectForKey:@"grp"];
    __block NSDictionary *blockDict = dict;
    if (!blockUUID)
        return;
    
    DDLogDebug(@"%s : %@",__FUNCTION__,blockUUID);
    if (![[DBManager dBManagerInstance] existsRecentByName:blockUUID])
        return;
    for (NSString *contactName in members)
    {
        [[ChatUtilities utilitiesInstance] getPrimaryAliasAndDisplayName:contactName completion:^(NSString *displayName, NSString *displayAlias)
        {
            BOOL isMemberNameFirst = NO;
            NSString *messageString = nil;
            if ([grpCommand isEqualToString:@"addm"])
            {
                if (userAction)
                {
                    isMemberNameFirst = NO;
                    messageString = kYouAdded;
                } else
                {
                    isMemberNameFirst = YES;
                    messageString = kJoined;
                }
            } else if([grpCommand isEqualToString:@"rmm"])
            {
                if (userAction)
                {
                    isMemberNameFirst = NO;
                    messageString = kYouRemoved;
                } else
                {
                    isMemberNameFirst = YES;
                    messageString = kLeft;
                }
            }
            if (displayName || displayAlias)
            {
                NSString *name = displayName?displayName:displayAlias;
                NSString *statusString = nil;
                if (!isMemberNameFirst)
                {
                    statusString = [NSString stringWithFormat:@"%@ %@",messageString,name];
                } else
                {
                    statusString = [NSString stringWithFormat:@"%@ %@",name,messageString];
                }
                
                [[self class] createGroupStatusMessageWithDict:blockDict message:statusString showAlert:showAlert];
            }
        }];
    }
}

+(void) updateBurnFromGroupCommand:(NSDictionary *) commandDict
{
    if (!commandDict)
        return;
    NSString *uuid = [commandDict objectForKey:@"grpId"];
    
    DDLogDebug(@"%s : %@",__FUNCTION__,uuid);
    int seconds = [[commandDict objectForKey:@"BSec"] intValue];
    if (!uuid || seconds == 0)
        return;
    RecentObject *recent = [[DBManager dBManagerInstance] getRecentByName:uuid];
    if (recent)
    {
        recent.burnDelayDuration = seconds;
        NSString *burnTimeString = [[ChatUtilities utilitiesInstance] getBurnValueStringFromSeconds:(int)seconds];
        NSString *message = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(kBurnChange, nil),burnTimeString];
        
        [[DBManager dBManagerInstance] deleteMessagesBeforeBurnTime:seconds uuid:uuid];
        [[self class] createGroupStatusMessageWithDict:commandDict message:message showAlert:YES];
        [[DBManager dBManagerInstance] saveRecentObject:recent];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification
                                                            object:[[self class] sharedInstance]
                                                          userInfo:@{ kSCPRecentObjectDictionaryKey:recent }];
    }
}

+(NSString *)createGroupStatusMessageWithDict:(NSDictionary *) dict message:(NSString *) message showAlert:(BOOL) showAlert
{
    if (!dict)
        return nil;
    
    NSString *grpUUID = [dict objectForKey:@"grpId"];
    DDLogDebug(@"%s : %@",__FUNCTION__,grpUUID);
    
    NSString *displayName = [dict objectForKey:@"name"];
    long unixTimeStamp = [[dict objectForKey:@"cmd_time"] longValue];
    if (!message || !grpUUID)
    {
        return nil;
    }
    if (unixTimeStamp == 0)
        unixTimeStamp = time(NULL);
    ChatObject *chatObject = [[ChatObject alloc] initWithText:message];
    
    chatObject.contactName = grpUUID;
    chatObject.displayName = displayName;
    chatObject.unixTimeStamp = unixTimeStamp;
    [[self class] finishCreatingChatObject:chatObject];
    
    if (showAlert)
    {
        [[ChatUtilities utilitiesInstance] showLocalAlertFromChatObject:chatObject];
    }
    return chatObject.msgId;
}

+(NSString *) createGroupErrorForUUID:(NSString *) grpUUID message:(NSString *) message
{
    if (!grpUUID)
        return nil;
    
    DDLogDebug(@"%s : %@",__FUNCTION__,grpUUID);
    if (![[DBManager dBManagerInstance] getRecentByName:grpUUID])
        return nil;
    
    ChatObject *chatObject = [[ChatObject alloc] initWithText:@""];
    
    chatObject.contactName = grpUUID;
    chatObject.errorString = message;
    chatObject.messageText = message;
    [[self class] finishCreatingChatObject:chatObject];
    [[ChatUtilities utilitiesInstance] showLocalAlertFromChatObject:chatObject];
    return chatObject.msgId;
}


+(void) updateGroupNameWithGroupCommand:(NSDictionary *)commandDict
{
    if (!commandDict)
        return;
    
    NSString *name = [commandDict objectForKey:@"name"];
    NSString *uuid = [commandDict objectForKey:@"grpId"];
    
    DDLogDebug(@"%s : uuid = %@ name = %@",__FUNCTION__,uuid,name);

    if (!uuid)
        return;

    RecentObject *recent = [[DBManager dBManagerInstance] getRecentByName:uuid];
    
    if (!recent)
        return;
    
    if (name) {

        NSString *message = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(kGroupNameChange, nil),name];
        recent.displayName = name;
        recent.hasGroupNameBeenSetExplicitly = YES;
        
        [self createGroupStatusMessageWithDict:commandDict
                                       message:message
                                     showAlert:YES];

        [[DBManager dBManagerInstance] saveRecentObject:recent];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification
                                                            object:[[self class] sharedInstance]
                                                          userInfo:@{ kSCPRecentObjectDictionaryKey:recent }];
    }
    else
        [self updateImplicitGroupNameForGroup:recent];
}

+ (void)updateImplicitGroupNameForGroup:(RecentObject *)groupRecent {
    
    if(!groupRecent || groupRecent.hasGroupNameBeenSetExplicitly)
        return;
    
    // FIXME: We do this temporarily until we also
    // save the member's RecentObjects instances in
    // the database (with the RecentObject refactor).
    BOOL allMembersCached = YES;
    
    NSArray *members = [self getAllGroupMemberRecentObjects:groupRecent.contactName];
    
    for (RecentObject *member in members) {
        
        if(member.isPartiallyLoaded) {

            allMembersCached = NO;
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectShouldResolveNotification
                                                                object:[[self class] sharedInstance]
                                                              userInfo:@{ kSCPRecentObjectDictionaryKey : member }];
        }
    }
    
    NSString *newGroupName = nil;
    
    if(!allMembersCached && !groupRecent.displayName)
        newGroupName = NSLocalizedString(kNewGroupConversation, nil);
    else if(allMembersCached)
        newGroupName = [[self sharedInstance] getDisplayNameForGroupMembers:members];

    if(newGroupName && ![groupRecent.displayName isEqualToString:newGroupName]) {
        
        groupRecent.displayName = newGroupName;
        
        [[DBManager dBManagerInstance] saveRecentObject:groupRecent];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification
                                                            object:[[self class] sharedInstance]
                                                          userInfo:@{ kSCPRecentObjectDictionaryKey: groupRecent }];
    }
}

/*
 Assign required properties for ChatObject
 saves ChatObject to DB
 and post receiveMessage notification
 */
+(void) finishCreatingChatObject:(ChatObject *) chatObject
{
    if (!chatObject)
        return;
    chatObject.isInvitationChatObject = 1;
    chatObject.isGroupChatObject = YES;
    
    
    chatObject.isReceived = 0;
    chatObject.isRead = 1;
    chatObject.iSendingNow = 0;
    
    uuid_string_t msgid;
    chatObject.msgId = [NSString stringWithFormat:@"%s",CTAxoInterfaceBase::generateMsgID(chatObject.messageText.UTF8String, msgid, sizeof(msgid))];
    
    [chatObject takeTimeStamp];
    [[DBManager dBManagerInstance] saveMessage:chatObject];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSCPReceiveMessageNotification
                                                        object:[[self class] sharedInstance]
                                                      userInfo:@{ kSCPChatObjectDictionaryKey:chatObject }];
}

+(void) removeGroup:(NSString *) grpUUID
{
    DDLogDebug(@"%s : %@",__FUNCTION__,grpUUID);
    RecentObject *recent = [[DBManager dBManagerInstance] getRecentByName:grpUUID];
    if (recent)
    {
        [[DBManager dBManagerInstance] removeChatWithContact:recent];
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectRemovedNotification object:self userInfo:@{kSCPRecentObjectDictionaryKey:recent}];
    }
}

@end
