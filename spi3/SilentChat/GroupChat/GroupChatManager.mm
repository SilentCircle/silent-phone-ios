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
//  GroupChatManager.m
//  SPi3
//
//  Created by Gints Osis on 28/10/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "GroupChatManager.h"
#import "axolotl_glue.h"
#include "interfaceApp/AppInterfaceImpl.h"
#include <cryptcommon/aescpp.h>
#include "storage/sqlite/SQLiteStoreConv.h"

#import "GroupChatManager+UI.h"
#import "GroupChatManager+Members.h"
#import "GroupChatManager+AvatarUpdate.h"
#import "UserService.h"
#import "SCAttachment.h"
#import "SCPCallbackInterface.h"
#import "SCSConstants.h"
#import "ChatManager.h"
#import "DBManager+MessageReceiving.h"
#import "DBManager+DeviceList.h"
#import "GroupChatManager+Messages.h"
#import "SCSAvatarManager+Updating.h"

using namespace zina;
using namespace std;

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

@interface GroupChatManager()

@property (readonly) AppInterfaceImpl *appInterface;

/*
 Dictionary of offline stored command dictionaries
 
 command dictionary format
 Keys - grpUUID
 Value - dictionary with key as stackedCommand and value as commandDict or grpUUID for leave command
 
 stackedCommand = "leave" || "join" || "declined"
 
 */
@property (nonatomic, strong) NSMutableDictionary *stackedOfflineGroupCommands;
@property int readReceiptsLastLoadedMsgNumber;

@end

@implementation GroupChatManager

#pragma mark - Lifecycle

+(GroupChatManager *)sharedInstance
{
    static dispatch_once_t once;
    static GroupChatManager *sharedInstance;
    
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init
{
    if(self = [super init])
    {
        CTAxoInterfaceBase::setGroupCallbacks(groupState, receiveGroupMessage, groupCommand);

        NSMutableArray *stackedOfflineGroupCommands = [[NSUserDefaults standardUserDefaults] objectForKey:@"stackedOfflineGroupCommands"];
        
        NSMutableDictionary *cachedReadStatuses = [[NSUserDefaults standardUserDefaults] objectForKey:@"cachedReadStatuses"];
        
        if (cachedReadStatuses)
            [[self class] setCachedReadStatuses:cachedReadStatuses];
        
        if(stackedOfflineGroupCommands)
            self.stackedOfflineGroupCommands = [stackedOfflineGroupCommands mutableCopy];
        else
            self.stackedOfflineGroupCommands = [NSMutableDictionary new];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateGroupAvatarsWithMember:)
                                                     name:kSCSAvatarAssigned
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(recentObjectResolved:)
                                                     name:kSCSRecentObjectResolvedNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(engineStateDidChange:)
                                                     name:kSCPEngineStateDidChangeNotification
                                                   object:nil];
        _readReceiptsLastLoadedMsgNumber = -1;
    }

    return self;
}

#pragma mark - Notifications

- (void)recentObjectResolved:(NSNotification *)notification
{

    __block RecentObject *blockConversation = [notification.userInfo objectForKey:kSCPRecentObjectDictionaryKey];
    
    if (!blockConversation)
        return;
    
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,blockConversation.contactName);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *grpIds = [[self class] getGroupsWithUUID:[[ChatUtilities utilitiesInstance] removePeerInfo:blockConversation.contactName lowerCase:YES]];
        for (NSString *grpId in grpIds)
        {
            RecentObject *existingGroup = [[DBManager dBManagerInstance] getRecentByName:grpId];
            if (existingGroup && !existingGroup.hasGroupNameBeenSetExplicitly)
                [[self class] updateImplicitGroupNameForGroup:existingGroup];
            
            
            if (existingGroup && !existingGroup.hasGroupAvatarBeenSetExplicitly)
            {
                [AvatarManager updateAvatarForGroup:existingGroup withMemberList:nil];
            }
        }
    });
}

- (void)updateGroupAvatarsWithMember:(NSNotification *)notification
{
    __block RecentObject *blockConversation = [notification.userInfo objectForKey:kSCPRecentObjectDictionaryKey];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification object:self userInfo:@{kSCPRecentObjectDictionaryKey:blockConversation}];
    
    if (!blockConversation)
        return;
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,blockConversation.contactName);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *grpIds = [[self class] getGroupsWithUUID:[[ChatUtilities utilitiesInstance] removePeerInfo:blockConversation.contactName lowerCase:YES]];
        for (NSString *grpId in grpIds)
        {
            RecentObject *existingGroup = [[DBManager dBManagerInstance] getRecentByName:grpId];
            if (existingGroup && !existingGroup.hasGroupAvatarBeenSetExplicitly)
            {
                [AvatarManager updateAvatarForGroup:existingGroup withMemberList:nil];
            }
        }
    });
}

/*
 When engine is online send all group commands stored in stackedOfflineGroupCommands
 */
// FIXME: Should we stack all other group commands when offline? (e.g "join", "declined" etc)
-(void) engineStateDidChange:(NSNotification *) notification
{
    if(![Switchboard allAccountsOnline])
        return;
    
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)
        return;

    NSMutableDictionary *stackedCommands = self.stackedOfflineGroupCommands;

    for (NSString *grpId in stackedCommands.allKeys)
    {
        NSDictionary *dict = [stackedCommands objectForKey:grpId];
       
        for (NSString *key in dict.allKeys)
        {
            if([key isEqualToString:@"leave"])
            {
                NSString  *grpUUID = [dict objectForKey:key];
                DDLogDebug(@"%s leaving: %@",__FUNCTION__,grpUUID);
                [self leaveGroup:grpUUID];
            }
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.stackedOfflineGroupCommands removeAllObjects];
       /* if ([[NSUserDefaults standardUserDefaults] objectForKey:@"stackedOfflineGroupCommands"])
        {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"stackedOfflineGroupCommands"];
        }*/
    });
}

#pragma mark - Public

-(NSString *)createGroup
{
    DDLogDebug(@"%s",__FUNCTION__);
    string nameStr = "";
    string groupDescriptionStr = "";
    string result;
    
    if(self.appInterface == NULL)
        return nil;
    
    result = self.appInterface->createNewGroup(nameStr, groupDescriptionStr);
    
    return [NSString stringWithUTF8String:result.c_str()];
}

-(void)addUser:(RecentObject *)conversation inGroup:(NSString *)uuid
{
    if(!uuid)
        return;
    
    if(!conversation)
        return;
    DDLogDebug(@"%s : %@",__FUNCTION__,uuid);
    
   __block NSString *blockGrpId = [[self class] normalizeGroupUUID:uuid];
   __block NSString *blockUUID = [[ChatUtilities utilitiesInstance] removePeerInfo:conversation.contactName
                                                                              lowerCase:NO];
    __block RecentObject *blockConversation = conversation;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *deviceList = [DBManager deviceListForDisplayUUID:blockUUID];
        if (deviceList.count == 0)
        {
            NSString *noDeviceMessage = [NSString stringWithFormat:@"%@ %@",blockConversation.displayName,kNoDevices];
            [[self class] createGroupStatusMessageWithDict:@{@"grpId":blockGrpId} message:noDeviceMessage showAlert:NO];
        }
    });

    
    if(self.appInterface == NULL)
        return;
    
    int32_t result = self.appInterface->addUser(blockGrpId.UTF8String, blockUUID.UTF8String);
    
    if (result < 0)
    {
        NSString *errorMessage = [NSString stringWithFormat:@"%@ %i",kGroupAddUserFail,result];
        
        [GroupChatManager createGroupErrorForUUID:blockGrpId
                                          message:errorMessage];
    }
}

-(void) leaveGroup:(NSString *) groupUUID
{
    if(!groupUUID)
        return;
    
    DDLogDebug(@"%s : %@",__FUNCTION__,groupUUID);
    if (![Switchboard allAccountsOnline] || self.appInterface == NULL)
    {
        [self.stackedOfflineGroupCommands setObject:@{@"leave":groupUUID} forKey:groupUUID];
        [[NSUserDefaults standardUserDefaults] setObject:self.stackedOfflineGroupCommands forKey:@"stackedOfflineGroupCommands"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        groupUUID = [[self class] normalizeGroupUUID:groupUUID];
        
        self.appInterface->leaveGroup(groupUUID.UTF8String);
    }
}

-(int32_t) sendGroupMessage:(ChatObject *)chatObject uuid:(NSString *)uuid deviceIds:(NSArray <NSString *> *)deviceIds {

    if(!chatObject)
        return -1;
    
    if(!uuid)
        return -1;
    
    
    DDLogDebug(@"%s : %@",__FUNCTION__,uuid);
    
    string messageDescriptor = [[self class] getStringFromDict:[[self class] getMessageDescriptorFromChatObject:chatObject]];
    
    string attributesDescriptor = [[self class] getStringFromDict:[[self class] getAttributeDescriptorFromChatObject:chatObject]];
    
    string attachmentDescriptor;
    
    if (chatObject.isAttachment)
        attachmentDescriptor = [[self class] getStringFromDict:[[self class] getAttachmentDescriptorFromChatObject:chatObject]];
    
    if(self.appInterface == NULL)
        return -1;

    if(!deviceIds || [deviceIds count] == 0)
        return self.appInterface->sendGroupMessageToMember(messageDescriptor, attachmentDescriptor, attributesDescriptor, uuid.UTF8String, "");
    else {
        
        int32_t messageId = -1;
        
        for (NSString *devId in deviceIds) {
            
            messageId = self.appInterface->sendGroupMessageToMember(messageDescriptor, attachmentDescriptor, attributesDescriptor, uuid.UTF8String, devId.UTF8String);
        }

        return messageId;
    }
}

-(int32_t) sendGroupMessage:(ChatObject*) chatObject {
    
    if(!chatObject)
        return -1;
    DDLogDebug(@"%s : %@",__FUNCTION__,chatObject.messageText);
    
    string messageDescriptor = [[self class] getStringFromDict:[[self class] getMessageDescriptorFromChatObject:chatObject]];
    
    string attributesDescriptor = [[self class] getStringFromDict:[[self class] getAttributeDescriptorFromChatObject:chatObject]];
    
    string attachmentDescriptor;
    
    if (chatObject.isAttachment)
        attachmentDescriptor = [[self class] getStringFromDict:[[self class] getAttachmentDescriptorFromChatObject:chatObject]];
    
    if(self.appInterface == NULL)
        return -1;
    
    return self.appInterface->sendGroupMessage(messageDescriptor, attachmentDescriptor, attributesDescriptor);
}

-(void) applyGroupChanges:(NSString *) uuid
{
    if(!uuid)
        return;
        
    NSString *groupUUID = [[self class] normalizeGroupUUID:uuid];
    DDLogDebug(@"%s : %@",__FUNCTION__,groupUUID);
    
    if(self.appInterface == NULL)
        return;
    
    int32_t result = self.appInterface->applyGroupChangeSet(groupUUID.UTF8String);
    
    // we have to ignore error code for a user added changeset with no messages
    // We display group status saying that user has no messaging devices instead
    if (result < 0 && result != zina::NO_DEVS_FOUND)
    {
        NSString *errorMessage = [NSString stringWithFormat:@"%@ %i",kGroupApplyChangesFail,result];
        
        [GroupChatManager createGroupErrorForUUID:uuid
                                          message:errorMessage];
    }
}

-(void)setBurnTime:(long)burnTime inGroup:(NSString *)uuid
{
    if (!uuid)
        return;
    if(![[DBManager dBManagerInstance] existsRecentByName:uuid])
        return;
    
    NSString *groupUUID = [[self class] normalizeGroupUUID:uuid];
    DDLogDebug(@"%s : %@",__FUNCTION__,groupUUID);
    
    if(self.appInterface == NULL)
        return;
    
    int32_t result = self.appInterface->setGroupBurnTime(groupUUID.UTF8String, burnTime, 1);
    
    if (result < 0)
    {
        NSString *errorMessage = [NSString stringWithFormat:@"%@ %i",kSetGroupBurnFail,result];
        
        [GroupChatManager createGroupErrorForUUID:groupUUID
                                          message:errorMessage];
    }
    else
    {
        NSString *burnTimeString = [[ChatUtilities utilitiesInstance] getBurnValueStringFromSeconds:(int)burnTime];
        NSString *message = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(kUserBurnChange, nil), burnTimeString];
        
        [[DBManager dBManagerInstance] deleteMessagesBeforeBurnTime:(int)burnTime
                                                               uuid:groupUUID];
            
        [[self class] createGroupStatusMessageWithDict:@{ @"grpId" : groupUUID}
                                               message:message
                                             showAlert:NO];                
    }
}

-(void)resetAvatarInGroup:(NSString *)uuid
{
    if(self.appInterface == NULL)
        return;
    
    if(!uuid)
        return;
    
    uuid = [[self class] normalizeGroupUUID:uuid];
    DDLogDebug(@"%s : %@",__FUNCTION__,uuid);

    string empty = kResetAvatarCommand.UTF8String;
    
    int32_t result = self.appInterface->setGroupAvatar(uuid.UTF8String, &empty);
    
    if (result < 0)
    {
        NSString *errorMessage = [NSString stringWithFormat:@"%@ %i",kSetGroupAvatarFail,result];
        [GroupChatManager createGroupErrorForUUID:uuid message:errorMessage];
    }
}

-(int32_t)setName:(NSString *)name inGroup:(NSString *)uuid
{
    if(!uuid)
        return -1;
    
    uuid = [[self class] normalizeGroupUUID:uuid];
    DDLogDebug(@"%s : %@",__FUNCTION__,uuid);
    
    if(self.appInterface == NULL)
        return -1;
    
    string nameStr = name.UTF8String;
    int32_t result = self.appInterface->setGroupName(uuid.UTF8String, &nameStr);
    
    if (result < 0)
    {
        NSString *errorMessage = [NSString stringWithFormat:@"%@ %i",kSetGroupNameFail,result];
        [GroupChatManager createGroupErrorForUUID:uuid message:errorMessage];
    }
    
    return result;
}

-(int32_t) setExplicitAvatarWithAttachmentDict:(NSDictionary *) attachmentDict inGroup:(NSString *) uuid
{
    if(!uuid)
        return -1;
    
    uuid = [[self class] normalizeGroupUUID:uuid];
    DDLogDebug(@"%s : %@",__FUNCTION__,uuid);

    NSError *writeError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:attachmentDict options:0 error:&writeError];
    string jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding].UTF8String;

    if (writeError)
        return -1;
    
    if(self.appInterface == NULL)
        return -1;

    int32_t result = self.appInterface->setGroupAvatar(uuid.UTF8String, &jsonString);
    
    if (result < 0)
    {
        NSString *errorMessage = [NSString stringWithFormat:@"%@ %i",kSetGroupAvatarFail,result];
        [GroupChatManager createGroupErrorForUUID:uuid message:errorMessage];
    }
    
    return result;
}

-(NSString *) getDisplayNameForGroupMembers:(NSArray *) members
{
    if(!members)
        return nil;
    
    if([members count] == 0)
        return nil;
    DDLogDebug(@"%s : %@",__FUNCTION__,members);
    
    NSMutableArray *memberNames = [NSMutableArray new];
    BOOL containsOwnUserName = NO;
    
    for (RecentObject *recent in members)
    {
        if(!recent.displayAlias)
            continue;
        
        if ([recent.displayAlias isEqualToString:[UserService currentUser].displayAlias])
            containsOwnUserName = YES;
        
        NSString *firstName = nil;
        if (recent.displayName)
        {
            firstName = [[ChatUtilities utilitiesInstance] firstNameFromFullName:recent.displayName];
        }
        else
        {
           firstName = [[ChatUtilities utilitiesInstance] getDisplayNameFromUserOrAlias:recent.displayAlias];
        }
        [memberNames addObject:firstName];
    }
    
    if (!containsOwnUserName)
    {
        NSString *localUserDisplayName = [UserService currentUser].displayName;
        
        if(localUserDisplayName)
        {
            NSString *localUserFirstName = [[ChatUtilities utilitiesInstance] firstNameFromFullName:localUserDisplayName];
            
            if(localUserFirstName)
                [memberNames addObject:localUserFirstName];
        }
        else
        {
            NSString *localUserDisplayAlias = [UserService currentUser].displayAlias;
            
            if(localUserDisplayAlias)
                [memberNames addObject:localUserDisplayAlias];
        }
    }
    
    NSArray *sortedNames = [memberNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    return [sortedNames componentsJoinedByString:@", "];
}

- (BOOL)burnGroupMessages:(NSArray<NSString *> *)messageIds inGroup:(NSString *)groupId
{
    if(!messageIds)
        return NO;
    
    if(!groupId)
        return NO;
    
    if([messageIds count] == 0)
        return NO;
    
    NSString *groupUUID = [[self class] normalizeGroupUUID:groupId];
    DDLogDebug(@"%s : %@",__FUNCTION__,groupUUID);
    
    if(!groupUUID)
        return NO;
    
    auto messageIdsVector = vector<std::string>();
    
    for (NSString *messageId in messageIds)
    {
        messageIdsVector.push_back(messageId.UTF8String);
    }
    
    if(self.appInterface == NULL)
        return NO;
    
    int32_t burnGroupMessages = self.appInterface->burnGroupMessage(groupUUID.UTF8String, messageIdsVector);
    
    BOOL succeeded = (burnGroupMessages == 0);
    
    if(succeeded)
        [self applyGroupChanges:groupUUID];
    
    return succeeded;
}

+ (NSString *)normalizeGroupUUID:(NSString *)groupUUID
{
    if(!groupUUID)
        return nil;
    
    return [[[ChatUtilities utilitiesInstance] removePeerInfo:groupUUID lowerCase:NO] uppercaseString];
}

-(void) sendGroupReadReceiptsForGroup:(RecentObject *)groupRecent
{
    DDLogDebug(@"%s : %@",__FUNCTION__, groupRecent);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [[DBManager dBManagerInstance] loadEventsForRecent:groupRecent
                                                    offset:_readReceiptsLastLoadedMsgNumber
                                                     count:50
                                           completionBlock:^(NSMutableArray *array, int lastMsgNumber) {
            
            NSMutableArray *unreadArray = [[NSMutableArray alloc] init];
            for (ChatObject *chatObject in array)
            {
                if (chatObject.isReceived == 1 && chatObject.isInvitationChatObject != 1 && chatObject.isRead != 1)
                {
                    [unreadArray addObject:chatObject];
                }
            }
            if (unreadArray.count > 0)
            {
                [[GroupChatManager sharedInstance] sendGroupReadReceipts:unreadArray];
            }
            _readReceiptsLastLoadedMsgNumber = lastMsgNumber;
            if (_readReceiptsLastLoadedMsgNumber > 0)
            {
                [self sendGroupReadReceiptsForGroup:groupRecent];
            }
        }];
    });
}

-(void) sendGroupReadReceipts:(NSArray <ChatObject*>*) array;
{
    if (!array) return;
    if (array.count == 0) return;
    DDLogDebug(@"%s",__FUNCTION__);
    
    NSMutableDictionary *readCommand = [[NSMutableDictionary alloc] init];
    NSString *date = [[ChatUtilities utilitiesInstance] iso8601formatForTimestamp:time(NULL)];
    [readCommand setObject:date forKey:@"rr_time"];
    [readCommand setObject:@"rr" forKey:@"grp"];
    ChatObject *anyChatObject = array[0];
    NSString *grpId = [[[ChatUtilities utilitiesInstance] removePeerInfo:anyChatObject.contactName lowerCase:YES] uppercaseString];
    [readCommand setObject:grpId forKey:@"grpId"];
    
    NSMutableArray *msgIds = [[NSMutableArray alloc] init];
    NSMutableArray *unreadChatObjects = [[NSMutableArray alloc] init];
    
    for (ChatObject *chatObject in array)
    {
        if (chatObject.isInvitationChatObject != 1 && chatObject.isReceived == 1 && chatObject.isGroupChatObject && chatObject.isRead != 1)
        {
            [msgIds addObject:chatObject.msgId];
            [unreadChatObjects addObject:chatObject];
        }
    }
    
    if (msgIds.count > 0)
    {
        [readCommand setObject:msgIds forKey:@"msgIds"];
        string readCommandStr = [[self class] getStringFromDict:readCommand];
        string ownUserName = [[ChatUtilities utilitiesInstance] getOwnUserName].UTF8String;
        int32_t result = self.appInterface->sendGroupCommandToMember(grpId.UTF8String, ownUserName, "", readCommandStr);
        if (result > 0)
        {
            for (ChatObject *chatObject in unreadChatObjects)
            {
                chatObject.isRead = 1;
                [[DBManager dBManagerInstance] saveMessage:chatObject];
            }
        } else
        {
            [self sendGroupReadReceipts:array];
        }
    }
}

#pragma mark - Zina callbacks

void groupState (int32_t errorCode, const string& stateInformation)
{
    DDLogInfo(@"%s %d %s", __PRETTY_FUNCTION__, errorCode, stateInformation.c_str());
}

int32_t receiveGroupMessage (const string& messageDescriptor, const string& attachmentDescriptor, const string& messageAttributes)
{
    NSDictionary *userData = dictFromCString(messageDescriptor);
    NSString *message = [userData objectForKey:@"message"];
    NSDictionary *attachmentDict = dictFromCString(attachmentDescriptor);
    
    DDLogDebug(@"%s : %@",__FUNCTION__,message);
    
    NSDictionary *attributeDict = dictFromCString(messageAttributes);
    
    NSString *grpId = [attributeDict objectForKey:@"grpId"];
    
    if (!grpId)
        return 0;
    
    if (![[DBManager dBManagerInstance] existsRecentByName:grpId])
        return 0;
    
    if (!message && !attachmentDict)
        return 0;
    
    if ([[DBManager dBManagerInstance] shouldIgnoreIncomingMessageAsDuplicateUsingMessageDict:userData
                                                                                attributeDict:attributeDict
                                                                               attachmentDict:attachmentDict])
        return 0;
        
    int ret = [[DBManager dBManagerInstance] storeMessageDict:userData
                                                attributeDict:attributeDict
                                               attachmentDict:attachmentDict];
    
    if(ret != zina::OK)
        return ret;
    
    return [[DBManager dBManagerInstance] receiveMessageDict:userData];
}

int32_t groupCommand (const string& commandMessage)
{
    NSDictionary *commandDict = dictFromCString(commandMessage);
    
    NSString *groupCmd = [commandDict objectForKey:@"grp"];
    NSString *uuid = [commandDict objectForKey:@"grpId"];
    
    DDLogDebug(@"%s : groupCmd = %@:  uuid = %@",__FUNCTION__,groupCmd,uuid);
    
    if(!groupCmd)
        return -1;
    
    if ([groupCmd isEqualToString:kGroupMessageRemoved])
    {
        NSString *uuid = [commandDict objectForKey:@"grpId"];
        NSArray *msgIds= [commandDict objectForKey:@"msgIds"];
        
        if(uuid && msgIds && [msgIds count] > 0)
        {
            [DBManager removeMessages:msgIds
                     fromRecentWithID:uuid];
        }
    }
    else if ([groupCmd isEqualToString:kGroupCreated])
    {
        [GroupChatManager joinGroupWithCommand:commandDict];
    }
    else if ([groupCmd isEqualToString:kGroupNameChanged])
    {
        [GroupChatManager updateGroupNameWithGroupCommand:commandDict];
    }
    else if ([groupCmd isEqualToString:KGroupMembersAdded])
    {
        [GroupChatManager createMemberCountChangedMessageFromGroupCommand:commandDict byUserAction:NO showAlert:YES];
        [[GroupChatManager sharedInstance] updateGroupAvatarWithCommandDict:commandDict];
        [GroupChatManager updateGroupNameWithGroupCommand:@{@"grpId":uuid}];
    }
    else if ([groupCmd isEqualToString:KGroupBurnChanged])
    {
        [GroupChatManager updateBurnFromGroupCommand:commandDict];
    }
    else if ([groupCmd isEqualToString:kGroupMembersRemoved])
    {
        [GroupChatManager createMemberCountChangedMessageFromGroupCommand:commandDict byUserAction:NO showAlert:YES];
        [[GroupChatManager sharedInstance] updateGroupAvatarWithCommandDict:commandDict];
        [GroupChatManager updateGroupNameWithGroupCommand:@{@"grpId":uuid}];
    }
    else if ([groupCmd isEqualToString:kGroupAvatarUpdated])
    {
        NSString *uuid = [commandDict objectForKey:@"grpId"];
        string attachmentDictString = [NSString stringWithFormat:@"%@",[commandDict objectForKey:@"Ava"]].UTF8String;
        NSString *ava = [NSString stringWithFormat:@"%s",attachmentDictString.c_str()];
        
        if ([ava isEqualToString:kResetAvatarCommand])
        {
            [[GroupChatManager sharedInstance] resetGeneratedAvatarForGroup:uuid showAlert:YES showMessage:YES];
        }
        else
        {
            NSDictionary *attachmentDict = dictFromCString(attachmentDictString);
            
            if (attachmentDict)
            {
                [[GroupChatManager sharedInstance] parseReceivedAvatar:attachmentDict forGroupCommand:commandDict];
            }
        }
    } else if ([groupCmd isEqualToString:kGroupReadNotice])
    {
        [GroupChatManager processMessageReadReceiptsCommand:commandDict];
    } else if([groupCmd isEqualToString:kGroupLeave])
    {
        [GroupChatManager removeGroup:uuid];
    }
    
    return 0;
}

#pragma mark - Private

+(void) joinGroupWithCommand:(NSDictionary *) dict
{
    if (!dict)
        return;
    
    NSString *grpUUID = [[self class] normalizeGroupUUID:[dict objectForKey:@"grpId"]];
    
    
    if (!grpUUID)
        return;
    DDLogDebug(@"%s : %@",__FUNCTION__,grpUUID);
    
    NSString *displayName = @"";
    RecentObject *recent = [[DBManager dBManagerInstance] getOrCreateRecentObjectForReceivedMessage:grpUUID andDisplayName:displayName isGroup:YES];
    
    recent.isGroupRecent = 1;
    [[DBManager dBManagerInstance] saveRecentObject:recent];
    
    // Group name must be updated when group is synchronised
    // chances are kmemberAdded will be received right after this command
    // if that command is not received wwe need some kind of display name
    [self updateGroupNameWithGroupCommand:@{@"grpId":grpUUID}];
        
    //for conversation to appear we need to create first chatobject on it
    [[self class]  createGroupStatusMessageWithDict:dict message:@"Group Created" showAlert:YES];
}

- (AppInterfaceImpl *)appInterface
{
    return (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
}

#pragma mark - Data parsers

+(string) getStringFromDict:(NSDictionary *) dict
{
    if(!dict)
        return NULL;
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:0
                                                         error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString.UTF8String;
}

/*
 Get message descriptor for chatobject
 */
+(NSMutableDictionary *) getMessageDescriptorFromChatObject:(ChatObject *) chatObject
{
    NSMutableDictionary *messageDescriptor = [NSMutableDictionary new];
    
    if (!chatObject)
        return messageDescriptor;

    if (!chatObject.contactName)
        return messageDescriptor;
    
    [messageDescriptor setObject:@"1"
                          forKey:@"version"];
    
    [messageDescriptor setObject:chatObject.msgId
                          forKey:@"msgId"];
    
    NSString *groupUUID = [self normalizeGroupUUID:chatObject.contactName];
    
    [messageDescriptor setObject:groupUUID
                          forKey:@"recipient"];
    
    if(chatObject.messageText)
        [messageDescriptor setObject:chatObject.messageText
                              forKey:@"message"];
    
    return messageDescriptor;
}

/*
 Get attribute descriptor for chatobject
 */
+(NSMutableDictionary *) getAttributeDescriptorFromChatObject:(ChatObject *) chatObject
{
    NSMutableDictionary *attributeDescriptor = [NSMutableDictionary new];
    
    if (!chatObject)
        return attributeDescriptor;

    if (!chatObject.contactName)
        return attributeDescriptor;
    
    NSString *uuid = [self normalizeGroupUUID:chatObject.contactName];

    [attributeDescriptor setObject:uuid
                            forKey:@"grpId"];
    
    [attributeDescriptor setObject:[NSString stringWithFormat:@"%li",chatObject.burnTime]
                            forKey:@"s"];
    
    [[ChatManager sharedManager] addLocationToMessageAttributes:attributeDescriptor];
    
    return attributeDescriptor;
}

/*
 Get attachment descriptor for chatobject
 */
+(NSMutableDictionary *) getAttachmentDescriptorFromChatObject:(ChatObject *) chatObject
{
    NSMutableDictionary *attachmentDescriptor = [NSMutableDictionary new];
    
    if (!chatObject)
        return attachmentDescriptor;
    
    if(!chatObject.attachment)
        return attachmentDescriptor;

    if(chatObject.attachment.cloudLocator)
        [attachmentDescriptor setObject:chatObject.attachment.cloudLocator
                                 forKey:@"cloud_url"];
    
    if(chatObject.attachment.cloudKey)
        [attachmentDescriptor setObject:chatObject.attachment.cloudKey
                                 forKey:@"cloud_key"];
    
    return attachmentDescriptor;
}

@end
