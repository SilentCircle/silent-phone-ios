//
//  SCSAvatarManager.m
//  SPi3
//
//  Created by Gints Osis on 17/05/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCSAvatarManager.h"
#import "ChatUtilities.h"
#import "DBManager.h"
#import "SCFileManager.h"
#import "SCSUserResolver.h"
#import "SCPCallbackInterface.h"
#import "SCAvatar.h"
#import "SCCImageUtilities.h"

#import "GroupChatManager+Members.h"

#import "SCSAvatarManager+Fetching.h"
#import "SCSAvatarManager+Updating.h"

SCSAvatarManager *AvatarManager = nil;
@implementation SCSAvatarManager
{
    NSMutableDictionary <NSString *, SCAvatar *> *avatars;
    NSOperationQueue *avatarDownloadQueue;
}
+(void) setup
{
    DDLogDebug(@"%s",__FUNCTION__);
    static dispatch_once_t once;
    static SCSAvatarManager *instance;
    dispatch_once(&once, ^{
        instance = [self new];
        
        AvatarManager = instance;
        [[NSNotificationCenter defaultCenter] addObserver:instance
                                                 selector:@selector(recentObjectResolved:)
                                                     name:kSCSRecentObjectResolvedNotification
                                                   object:nil];
    });
}

-(instancetype)init
{
    if(self = [super init])
    {
        avatars = [[NSMutableDictionary alloc] init];
        avatarDownloadQueue = [[NSOperationQueue alloc] init];
    }
    return self;
}

+ (SCSAvatarManager *)sharedManager
{
    return AvatarManager;
}

-(NSUInteger)smallSizeAvatarWidth
{
    return 150;
}

-(NSUInteger)fullSizeAvatarWidth
{
    return 512;
}

#pragma mark SCAvatar getters and setters
-(SCAvatar *) avatarForUUID:(NSString *) uuid
{
    if (!uuid)
        return nil;
    
    uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:uuid
                                                                 lowerCase:NO];
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,uuid);
    @synchronized (self)
    {
        return [avatars objectForKey:uuid];
    }
}

-(void) setAvatar:(SCAvatar *) avatar ForUUID:(NSString *) uuid
{
    if (!uuid)
        return;
    uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:uuid
                                                   lowerCase:NO];
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,uuid);
    @synchronized (self)
    {
        [avatars setObject:avatar forKey:uuid];
    }
}

-(SCAvatar *) avatarForChatObject:(ChatObject *) chatObject
{
    if (!chatObject)
        return nil;
    NSString *uuid = nil;
    if (chatObject.isGroupChatObject == 1)
    {
        uuid = chatObject.senderId;
    } else
    {
        uuid = chatObject.contactName;
    }
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,uuid);
    uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:uuid
                                                             lowerCase:YES];
    SCAvatar *avatar = [self avatarForUUID:uuid];
    return avatar;
}

-(SCAvatar *) avatarForConversation:(RecentObject *) conversation
{
    if (!conversation)
        return nil;
    NSString *uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:conversation.contactName
                                                   lowerCase:YES];
    SCAvatar *avatar = [self avatarForUUID:uuid];
    
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,uuid);
    if (!avatar)
    {
        avatar = [[SCAvatar alloc] init];
        avatar.conversation = conversation;
        [self setAvatar:avatar ForUUID:uuid];
        
        NSBlockOperation *avatarOperation = [NSBlockOperation blockOperationWithBlock:^{
            [self findImageForAvatar:avatar];
        }];
        [avatarDownloadQueue addOperation:avatarOperation];
    }
     return avatar;
}

-(UIImage *)avatarImageForChatObject:(ChatObject *)chatObject size:(scsAvatarSize)size
{
    if (!chatObject)
        return nil;
    NSString *uuid = nil;
    if (chatObject.isGroupChatObject == 1)
    {
        uuid = chatObject.senderId;
    } else
    {
        uuid = chatObject.contactName;
    }
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,uuid);
    uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:chatObject.senderId
                                                             lowerCase:YES];
    
    SCAvatar *avatar = [self avatarForChatObject:chatObject];
    if (avatar)
    {
        if (size == eAvatarSizeFull)
        {
            return avatar.avatarImage;
        } else
        {
            return avatar.smallAvatarImage;
        }
    }
    RecentObject *conversation = [Switchboard.userResolver cachedRecentWithUUID:uuid];
    if (!conversation)
    {
        conversation = [[RecentObject alloc] init];
        conversation.contactName = uuid;
        conversation.isPartiallyLoaded = YES;
        avatar = [self avatarForConversation:conversation];
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectShouldResolveNotification object:self userInfo:@{kSCPRecentObjectDictionaryKey:conversation}];
    }
    return nil;
}

-(UIImage *)avatarImageForConversationObject:(RecentObject *)conversation size:(scsAvatarSize)size
{
    if (!conversation)
        return nil;
    NSString *uuid = conversation.contactName;
    uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:uuid
                                                               lowerCase:YES];
    
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,uuid);
    
    SCAvatar *avatar = [self avatarForConversation:conversation];
    if (size == eAvatarSizeFull)
    {
        return avatar.avatarImage;
    } else
    {
        return avatar.smallAvatarImage;
    }
}

-(void)setExplicitAvatar:(UIImage *)image forGroup:(RecentObject *)conversation
{
    if (!conversation || !conversation.isGroupRecent || !image)
        return;
    
    conversation.hasGroupAvatarBeenSetExplicitly = YES;
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,conversation.contactName);
    
    // we need only to save hasGroupAvatarBeenSetExplicitly flag
    // no need to post notification
    [[DBManager dBManagerInstance] saveRecentObject:conversation];
    
    NSString *uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:conversation.contactName
                                                   lowerCase:YES];
    
    SCAvatar *avatar = [self avatarForUUID:uuid];
    if (!avatar)
    {
        avatar = [[SCAvatar alloc] init];
        [self setAvatar:avatar ForUUID:uuid];
    }
    avatar.avatarImage = [SCCImageUtilities roundAvatarImage:image];
    [self saveImage:image forAvatar:avatar];
}

-(void)deleteAvatarForConversation:(RecentObject *)conversation
{
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,conversation.contactName);
    if (!conversation)
        return;
    if (conversation.isGroupRecent)
    {
        // delete group title avatar
        NSString *peerLessGroupUUID = [GroupChatManager normalizeGroupUUID:conversation.contactName];
        [avatars removeObjectForKey:peerLessGroupUUID];
        [self deleteAvatarByName:peerLessGroupUUID];
        
        
        // iterate through this groups member names and find other conversation where each of the contactname is used
        NSArray *members = [GroupChatManager getAllGroupMemberRecentObjects:conversation.contactName];
        for (RecentObject *conversation in members)
        {
            NSString *uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:conversation.contactName lowerCase:YES];
            
            // do not manage our own avatar
            if ([uuid isEqualToString:[[ChatUtilities utilitiesInstance] getOwnUserName]])
                continue;
            
            
            NSArray *otherGroups = [GroupChatManager getGroupsWithUUID:uuid];
            if (otherGroups.count == 0)
            {
                RecentObject *existingRecent = [[DBManager dBManagerInstance] getRecentByName:uuid];
                
                // if 1:1 conversation with this contactname doesn't exist we can delete the avatar
                if (!existingRecent)
                {
                    [self deleteAvatarByName:uuid];
                }
            }
        }
    } else
    {
        [self deleteAvatarByName:conversation.contactName];
    }
}

/*
 Delete avatar by passed name
 For some cases avatar file will not exist e.g if we have just joined a group with many members and we leave that group immediately no avatars will be downloaded for that group except for title avatar
 */
-(void) deleteAvatarByName:(NSString *) name
{
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,name);
    if (!name)
        return;
    NSString *avatarPath = [[SCFileManager chatDirectoryURL].relativePath stringByAppendingPathComponent:[[ChatUtilities utilitiesInstance] removePeerInfo:name lowerCase:YES]];
    
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:avatarPath];
    if (fileExists)
    {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:avatarPath error:&error];
    }
}

-(void)saveImage:(UIImage *)image forAvatar:(SCAvatar *)avatar
{
    if (!avatar || !avatar.conversation || !image)
        return;
    NSString *uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:avatar.conversation.contactName
                                                             lowerCase:YES];
    
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,uuid);
    NSString *avatarPathStored = [[SCFileManager chatDirectoryURL].relativePath stringByAppendingPathComponent:uuid];
    
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:avatarPathStored];
    
    // always rewrite avatar for group chat because it changes when people join or leave the conversation
    if (fileExists == NO || avatar.conversation.isGroupRecent)
    {
        NSData *avatarImageData = [[NSData alloc] init];
        avatarImageData = UIImagePNGRepresentation(image);
        [avatarImageData writeToFile:avatarPathStored atomically:YES];
    }
}


#pragma mark - Notifications

// When Recent object is resolved we begin fetching it's avatar
- (void)recentObjectResolved:(NSNotification *)notification
{
     RecentObject *resolvedConversation = [notification.userInfo objectForKey:kSCPRecentObjectDictionaryKey];
    
    if (!resolvedConversation)
        return;
    
    __block NSString *blockUUID = [[ChatUtilities utilitiesInstance] removePeerInfo:resolvedConversation.contactName lowerCase:YES];
    
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,blockUUID);

        NSBlockOperation *avatarOperation = [NSBlockOperation blockOperationWithBlock:^{
            SCAvatar *avatar = [self avatarForUUID:blockUUID];;
            if (avatar)
                [self findImageForAvatar:avatar];
        }];
        [avatarDownloadQueue addOperation:avatarOperation];
}


@end
