//
//  SCSAvatarManager+Fetching.m
//  SPi3
//
//  Created by Gints Osis on 18/05/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCSAvatarManager+Fetching.h"
#import "SCSAvatarManager+Updating.h"
#import "UIImage+ApplicationImages.h"
#import "SCAvatar.h"
#import "AddressBookContact.h"
#import "ChatUtilities.h"
#import "SCPNotificationKeys.h"
#import "SCCImageUtilities.h"
#import "SCFileManager.h"
#import "SCPCallbackInterface.h"


@implementation SCSAvatarManager (Fetching)

-(void) findImageForAvatar:(SCAvatar *) avatar
{
    if (!avatar || !avatar.conversation)
        return;
    
    RecentObject *conversation = avatar.conversation;
    NSString *uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:conversation.contactName lowerCase:YES];
    if (!uuid)
        return;
    DDLogDebug(@"%s uuid = %@",__FUNCTION__,uuid);
    
    if (!conversation.isGroupRecent)
    {
        UIImage *addressBookImage = [self avatarFromAddressBook:avatar];
        if (addressBookImage)
        {
            avatar.avatarImage = [SCCImageUtilities roundAvatarImage:addressBookImage];
            [[NSNotificationCenter defaultCenter] postNotificationName:kSCSAvatarAssigned object:self userInfo:@{kSCPRecentObjectDictionaryKey:conversation}];
            return;
        }
        if ([[ChatUtilities utilitiesInstance] isNumber:uuid] && !avatar.conversation.abContact)
        {
            avatar.avatarImage = [UIImage numberAvatarImage];
            [[NSNotificationCenter defaultCenter] postNotificationName:kSCSAvatarAssigned object:self userInfo:@{kSCPRecentObjectDictionaryKey:conversation}];
            return;
        }
    }
    
    UIImage *storedImage = [self imageFromChatFolderForAvatar:avatar];
    if (storedImage)
    {
        DDLogDebug(@"%s avatar from chat directory for = %@",__FUNCTION__,uuid);
        if (conversation.hasGroupAvatarBeenSetExplicitly == 1)
        {
            avatar.avatarImage = [SCCImageUtilities roundAvatarImage:storedImage];
        } else
        {
            avatar.avatarImage = storedImage;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSAvatarAssigned object:self userInfo:@{kSCPRecentObjectDictionaryKey:conversation}];
    } else
    {
        if (conversation.isGroupRecent)
        {
            avatar.avatarImage = [UIImage imageNamed:@"oneMemberGroupChat"];
            DDLogDebug(@"%s default group avatar for = %@",__FUNCTION__,uuid);
        } else
        {
           RecentObject *resolvedConversation = [Switchboard.userResolver cachedRecentWithUUID:uuid];
            
            // if we have to generate initials image we need displayname assigned on conversation
            // skip resolving of addressbook contacts
            if ((!resolvedConversation && !conversation.displayName) && !conversation.abContact)
            {
                DDLogDebug(@"%s should resolve RecentObject to get avatar for = %@",__FUNCTION__,uuid);
                [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectShouldResolveNotification object:self userInfo:@{kSCPRecentObjectDictionaryKey:conversation}];
                return;
            }
            if (resolvedConversation)
                conversation = resolvedConversation;
            DDLogDebug(@"%s constructing initials avatar for = %@",__FUNCTION__,uuid);
            avatar.avatarImage = [SCCImageUtilities constructMemberAvatarFromDisplayName:conversation.displayName];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSAvatarAssigned object:self userInfo:@{kSCPRecentObjectDictionaryKey:conversation}];
        
        if (!conversation.isGroupRecent)
        {
            DDLogDebug(@"%s attempt to download avatar for = %@",__FUNCTION__,uuid);
            [self imageFromNetworkForAvatar:avatar];
        }
    }
}


-(UIImage *) avatarFromAddressBook:(SCAvatar *) avatar
{
    if (!avatar.conversation)
        return nil;
    
    AddressBookContact *contact = avatar.conversation.abContact;
    
    if (contact)
    {
        if (contact.cachedContactImage)
        {
            return contact.cachedContactImage;
        } else
        {
            UIImage *contactImage = contact.requestContactImageSynchronously;
            if (contactImage)
                return contactImage;
        }
    }
    return nil;
}

-(UIImage *) imageFromChatFolderForAvatar:(SCAvatar *) avatar
{
    if (!avatar.conversation)
        return nil;
    
    NSData *imageData = nil;
    NSString *uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:avatar.conversation.contactName lowerCase:YES];
    
    NSString *avatarPathStored = [[SCFileManager chatDirectoryURL].relativePath stringByAppendingPathComponent:uuid];
    NSError *error;
    imageData = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:avatarPathStored] options:0 error:&error];
    
    if (error)
        DDLogError(@"%s %@",__FUNCTION__,error.description);
    
    if (!imageData)
        return nil;
    UIImage *tempImage = [UIImage imageWithData:imageData];

    UIImageOrientation imageOrientation = UIImageOrientationUp;

    UIImage *storedImage = [UIImage imageWithCGImage:tempImage.CGImage
                                                   scale:[[UIScreen mainScreen] scale]
                                             orientation:imageOrientation];
    if (!avatar.conversation.isGroupRecent)
    {
        storedImage = [SCCImageUtilities roundAvatarImage:storedImage];
    }
    return storedImage;
}

-(void) imageFromNetworkForAvatar:(SCAvatar *) avatar
{
    __block SCAvatar *blockAvatar = avatar;
    if (!blockAvatar.conversation || !blockAvatar.conversation.avatarUrl || blockAvatar.conversation.avatarUrl.length == 0)
        return;
    
    NSURL *avatarUrl = [ChatUtilities buildApiURLForPath:blockAvatar.conversation.avatarUrl];
    
    NSURLRequest * urlRequest = [NSURLRequest requestWithURL:avatarUrl];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session dataTaskWithRequest:urlRequest
                completionHandler:^(NSData *data,NSURLResponse *response, NSError *error){
                    
                    UIImage *image = [UIImage imageWithData:data];
                    if (error)
                        DDLogError(@"%s %@",__FUNCTION__,error.description);
                    if (error == nil && blockAvatar.conversation)
                    {
                        blockAvatar.avatarImage = [SCCImageUtilities roundAvatarImage:image];
                        [AvatarManager saveImage:image forAvatar:blockAvatar];
                        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSAvatarAssigned
                                                                            object:AvatarManager
                                                                          userInfo:@{ kSCPRecentObjectDictionaryKey : blockAvatar.conversation }];
                    }
                    
                }] resume];
    
    [session finishTasksAndInvalidate];
}


@end
