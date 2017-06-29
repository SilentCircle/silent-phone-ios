//
//  SCSAvatarManager+Updating.m
//  SPi3
//
//  Created by Gints Osis on 18/05/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCSAvatarManager+Updating.h"
#import "SCCImageUtilities.h"
#import "GroupChatManager.h"
#import "SCAvatar.h"
#import "GroupChatManager+Members.h"
#import "UIImage+ApplicationImages.h"
#import "SCPCallbackInterface.h"


@implementation SCSAvatarManager (Updating)
-(void)updateAvatarForGroup:(RecentObject *) conversation withMemberList:(NSArray *) memberList
{
    if (!conversation || conversation.hasGroupAvatarBeenSetExplicitly)
    {
        return;
    }
    NSString *grpId = [[GroupChatManager normalizeGroupUUID:conversation.contactName] lowercaseString];
    
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,grpId);
    if (!memberList)
    {
        memberList = [GroupChatManager getAllGroupMemberRecentObjects:grpId];
    }
    SCAvatar *avatar = [AvatarManager avatarForConversation:conversation];
    
    // cancel avatar updating for groups with no members or one member
    // If there is only one member left it is current user probably
    if (memberList.count == 0 ||memberList.count == 1)
    {
        avatar.avatarImage = [UIImage defaultGroupAvatarImage];
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification object:self userInfo:@{kSCPRecentObjectDictionaryKey:avatar.conversation}];
        return;
    }

    
    NSMutableArray *imageArray = [[NSMutableArray alloc] initWithCapacity:memberList.count];
    
    long displayAbleMembers = memberList.count > 4?3:memberList.count;
    
    
    // do not update avatar until all members are resolved
    for (int i = 0; i<displayAbleMembers; i++)
    {
        RecentObject *member = memberList[i];
        
        NSString *uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:member.contactName lowerCase:YES];
        RecentObject *resolvedConversation = [Switchboard.userResolver cachedRecentWithUUID:uuid];
        if (!resolvedConversation && !member.displayName && !member.abContact)
        {
            DDLogDebug(@"%s should resolve RecentObject to get avatar for = %@",__FUNCTION__,grpId);
            [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectShouldResolveNotification object:self userInfo:@{kSCPRecentObjectDictionaryKey:member}];
            return;
        }
        if (resolvedConversation)
            member = resolvedConversation;
        
        
        UIImage *image = [AvatarManager avatarImageForConversationObject:member size:eAvatarSizeSmall];
        // If we don't have image at this point, wait and return.
        // This means that image is donwloading and will call kSCSAvatarAssigned
        // which will call this function again when done
        if (!image)
            return;
        [imageArray addObject:image];
    }
    if (imageArray.count == 0)
        return;
    
    [SCCImageUtilities constructGroupAvatarFromAvatars:imageArray totalCount:memberList.count completion:^(UIImage *avatarImage)
    {
        avatar.avatarImage = avatarImage;
        [AvatarManager saveImage:avatarImage forAvatar:avatar];
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification object:self userInfo:@{kSCPRecentObjectDictionaryKey:avatar.conversation}];
    }];
}
@end
