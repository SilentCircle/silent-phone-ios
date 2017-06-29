//
//  GroupChatManager+AvatarUpdate.m
//  SPi3
//
//  Created by Gints Osis on 27/02/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "GroupChatManager+AvatarUpdate.h"
#import "GroupChatManager+Members.h"
#import "GroupChatManager+UI.h"
#import "AttachmentManager.h"
#import "SCAttachment.h"
#import "SCSConstants.h"
#import "SCloudObject.h"
#import "SCSAvatarManager.h"
#import "SCSAvatarManager+Updating.h"

static SCAttachment *tempAvatarAttachment = nil;

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

@implementation GroupChatManager (AvatarUpdate)

-(void) updateGroupAvatarWithCommandDict:(NSDictionary *) dict
{
    if (!dict)
        return;
    NSString *grpCommand = [dict objectForKey:@"grp"];
    NSString *uuid = [dict objectForKey:@"grpId"];
    NSArray *members = [dict objectForKey:@"mbrs"];
    
    DDLogDebug(@"%s : uuid = %@ : grpCommand = %@",__FUNCTION__,uuid,grpCommand);
    if (!uuid || !members)
    {
        return;
    }
    
    RecentObject *recentToUpdate = [[DBManager dBManagerInstance] getRecentByName:uuid];
    if (!recentToUpdate)
        return;
    if (recentToUpdate.hasGroupAvatarBeenSetExplicitly)
    {
        return;
    }
    
    NSMutableArray *existingMembers = [[self class] getAllGroupMemberRecentObjects:uuid];
    
    [AvatarManager updateAvatarForGroup:recentToUpdate withMemberList:existingMembers];
}


-(void) setExplicitAvatar:(NSDictionary *) info forGroup:(NSString *) uuid
{
    if (!uuid || !info)
        return;
    __strong NSString *strongUUID = uuid;
    DDLogDebug(@"%s : %@",__FUNCTION__,strongUUID);
    if(![[DBManager dBManagerInstance] existsRecentByName:strongUUID])
        return;
   NSString *msgId = [[self class] createGroupStatusMessageWithDict:@{@"grpId":uuid} message:kGroupAvatarWasUpdated showAlert:NO];
    if (!msgId)
        return;
   tempAvatarAttachment = [SCAttachment attachmentFromImagePickerInfo:info withScale:1.0f thumbSize:CGSizeZero location:nil];
    
    
    [[AttachmentManager sharedManager] uploadAttachment:tempAvatarAttachment forMsgId:msgId completionBlock:^(NSError *error, NSDictionary *infoDict) {
        [[[self class] sharedInstance] setExplicitAvatarWithAttachmentDict:@{@"cloud_url":tempAvatarAttachment.cloudLocator,@"cloud_key":tempAvatarAttachment.cloudKey} inGroup:strongUUID];
        [[[self class] sharedInstance] applyGroupChanges:strongUUID];
    }];
}

-(void) resetGeneratedAvatarForGroup:(NSString *) uuid showAlert:(BOOL) showAlert showMessage:(BOOL) showMessage
{
    if (!uuid)
        return;
    DDLogDebug(@"%s : %@",__FUNCTION__,uuid);
    
    RecentObject *recentToUpdate = [[DBManager dBManagerInstance] getRecentByName:uuid];
    
    if(!recentToUpdate)
        return;
    if (recentToUpdate.hasGroupAvatarBeenSetExplicitly)
    {
        recentToUpdate.hasGroupAvatarBeenSetExplicitly = NO;
        [[DBManager dBManagerInstance] saveRecentObject:recentToUpdate];
    }
    
    NSMutableArray *existingMembers = [[self class] getAllGroupMemberRecentObjects:uuid];
    
    [AvatarManager updateAvatarForGroup:recentToUpdate withMemberList:existingMembers];
    if (showMessage)
    {
        [[self class] createGroupStatusMessageWithDict:@{@"grpId":uuid} message:kGroupAvatarWasRemoved showAlert:showAlert];
    }
}


-(void) parseReceivedAvatar:(NSDictionary *) dict forGroupCommand:(NSDictionary *)commandDict
{
    if (!commandDict)
        return;
    NSString *uuid = [commandDict objectForKey:@"grpId"];
    DDLogDebug(@"%s : %@",__FUNCTION__,uuid);
    
    if (!dict || !uuid)
        return;
    __block SCAttachment *avatarAttachment = [[SCAttachment alloc] init];
    __block NSString *strongUUID = uuid;
    __block NSDictionary *blockCommandDict = commandDict;
    avatarAttachment.cloudLocator = [dict objectForKey:@"cloud_url"];
    NSObject *cloudKey = [dict objectForKey:@"cloud_key"];
    
    if (!cloudKey || !avatarAttachment.cloudLocator)
        return;
    if(![[DBManager dBManagerInstance] existsRecentByName:strongUUID])
        return;
    
    // FROM DBMANAGER + MESSAGERECEIVING
    // from iOS: cloudKey was already turned into a NSDictionary due to JSON serialization above
    // from Android: cloudKey is a string
    if ([cloudKey isKindOfClass:[NSDictionary class]])
    {
        NSData *keyData = [NSJSONSerialization dataWithJSONObject:cloudKey options:kNilOptions error:nil];
        avatarAttachment.cloudKey = [[NSString alloc] initWithData:keyData encoding:NSUTF8StringEncoding];
    } else if ([cloudKey isKindOfClass:[NSString class]])
        avatarAttachment.cloudKey = (NSString *)cloudKey;
    
    
    // all attachment downloading must be done sequentially
    // SCAttachment file has to persist while this download is happening
    [[AttachmentManager sharedManager] downloadAttachmentTOC:avatarAttachment withMessageID:strongUUID completionBlock:^(NSError *error, NSDictionary *infoDict) {
        [[AttachmentManager sharedManager] downloadAttachmentFull:avatarAttachment withMessageID:strongUUID completionBlock:^(NSError *error, NSDictionary *infoDict) {
            [[AttachmentManager sharedManager] decryptAttachment:avatarAttachment completionBlock:^(NSError *error, NSDictionary *infoDict) {
                UIImage* decryptedGroupImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:avatarAttachment.decryptedObject.decryptedFileURL]];
                
                // set downloaded attachment to RecentObject
                // avatar will be saved when setting it on recentObject with setExplicitAvatarForGroup:
                // We don't need SCAttachment file anymore
                RecentObject *recent = [[DBManager dBManagerInstance] getRecentByName:strongUUID];
                
                if (recent)
                {
                    DDLogDebug(@"%s decrypted and assigned group avatar",__FUNCTION__);
                    [AvatarManager setExplicitAvatar:decryptedGroupImage forGroup:recent];
                    [[self class] createGroupStatusMessageWithDict:blockCommandDict message:kGroupAvatarWasUpdated showAlert:YES];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification object:self userInfo:@{kSCPRecentObjectDictionaryKey:recent}];
                    
                }
                SCloudObject *scloud = [[SCloudObject alloc] initWithLocatorString:avatarAttachment.cloudLocator keyString:avatarAttachment.cloudKey fyeo:NO segmentList:avatarAttachment.segmentList];
                [scloud clearCache];
            }];
        }];
    }];
}



@end
