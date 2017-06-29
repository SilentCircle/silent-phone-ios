//
//  SCSAvatarManager+Fetching.h
//  SPi3
//
//  Created by Gints Osis on 18/05/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCSAvatarManager.h"
#import "SCAvatar.h"

/**
 Avatar finding and downloading category
 */
@interface SCSAvatarManager (Fetching)

/**
 Finds avatar for passed SCAvatar instance
 
 For avatar fetching to happen SCAvatar need conversation property assigned
 
 
 Whenever some image is assigned to be avatar kSCSAvatarAssigned is posted

 First for non group conversations we look to find avatar in address book
 Second we look in chat directory for stored avatar
 
 If no avatar is found in chat directory or address book for group avatars we then assign default image.
 For1:1 conversations we check if they are resolved first because we need conversations displayname to construct avatar with initials. If they are not resolved we post kSCSRecentObjectShouldResolveNotification and return.
 Once RecentObject is resolved this function will be called again from GroupChatManager
 Then initials avatar image will be created and network fetch for avatar will begin
 
 @param avatar SCAvatar instance 
 */
-(void) findImageForAvatar:(SCAvatar *) avatar;
@end
