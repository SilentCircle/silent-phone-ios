//
//  SCSAvatarManager.h
//  SPi3
//
//  Created by Gints Osis on 17/05/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCSEnums.h"
#import "RecentObject.h"
#import "SCAvatar.h"

/**
 Manages avatars for uuid and for groups
 
 All avatars are returned from SCAvatar objects cached in avatars dictionary.
 When avatar is requested for the first time SCAvatar instance is created, stored in avatars cache and avatar finding is started for the passed conversation
 
 Avatar images are stored square in chat directory once taken out of directory or generated they are rounded with [SCCImageUtilities roundAvatarImage:]
 
 
 */

@class SCSAvatarManager;
extern SCSAvatarManager *AvatarManager;
@interface SCSAvatarManager : NSObject<NSURLSessionDelegate>

+(void) setup;

+(SCSAvatarManager *)sharedManager;

/**
 Full avatar size, displayed in groupInfoView, as chat background when there are no messages and in callscreen 

 @return 512
 */
-(NSUInteger) fullSizeAvatarWidth;

/**
 small avatar size, used in tableview cells

 @return 150
 */
-(NSUInteger) smallSizeAvatarWidth;



/**
 avatar image getter for chatobject
 
 NOTE - not a perfect implementation, we should post chatobjectUpdated instead of recentObject updated when avatar is found with this getter
 
 Looks up SCAvatar in avatars dictionary for passed ChatObject's uuid
 If avatar is not found we try to find Conversation obejct for this uuid and try to fetch avatar for Conversation
 If Conversation is not found it is allocated with ChatObject's uuid and resolved with userResolver
 Can return nil if avatar doesn't exist
 @param chatObject chatobject for which to fetch avatar
 @param size avatar size
 @return avatar image
 */
-(UIImage *) avatarImageForChatObject:(ChatObject *) chatObject size:(scsAvatarSize) size;


/**
 avatar image getter for conversation
 
 Looks up SCAvatar in avatars dictionary for passed Conversation's uuid

 @param conversationObject conversation for which to find avatar
 @param size avatar size
 @return avatar image
 */
-(UIImage *) avatarImageForConversationObject:(RecentObject *) conversationObject size:(scsAvatarSize) size;


/**
 Returns SCAvatar object for conversation with uuid
 If SCAvatar instance ddoesn't exist it is instantiated and avatar fetching is started
 And SCAvatar instance is returned, at that point it may not contain any images

 @param conversation conversation oject
 @return SCAvatar instance for conversation's uuid
 */
-(SCAvatar *) avatarForConversation:(RecentObject *) conversation;


/**
 Sets explicit group avatar image on existing SCAvatar instance or creates a new one, stores it and assigns image

 @param image image to set
 @param recent group conversation for which to set image
 */
-(void) setExplicitAvatar:(UIImage *) image forGroup:(RecentObject *) recent;


/**
 Deletes stored avatar image from chat directory
 For group avatars iterates through all group members and if they are not in any other groups or there are no 1:1 conversations with that member, his avatar is also removed

 @param conversation conversation object for which to delete avatar
 */
-(void) deleteAvatarForConversation:(RecentObject *) conversation;


/**
 Save avatar to chat directory
 
 Image has to passed seperate from SCAvatar instance because SCAvatar scales its image in property setter

 @param image image to save
 @param avatar SCAvatar instance for which to save image
 */
-(void) saveImage:(UIImage *)image forAvatar:(SCAvatar *) avatar;
@end
