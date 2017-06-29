//
//  GroupChatManager+AvatarUpdate.h
//  SPi3
//
//  Created by Gints Osis on 27/02/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "GroupChatManager.h"
/*
 Category that manages group avatar setting, storing and resetting
 
 To set Explicit avatar image on group use setExplicitAvatar:forGroup:
 uses same dictionary as passed from UIImagePickerController in didFinishPickingMediaWithInfo:
 From avatar image SCAttachment is created, and uploaded to cloud,
 
 when upload is done setExplicitAvatarWithAttachmentDict:inGroup: on GroupChatManager is called passing cloud_url and cloud_key. These parameters are passed to zina call setGroupAvatar() which will send them to other group participants
 
 
 When avatar update is received parseReceivedAvatar:forGroup: is called
 It creates SCAttachment from received cloud_url and cloud_key parameters, downloads attachments TOC, downloads full attachment and decrypt's it.
 Then asigns decrypted image to RecentObject and display's alertView that avatar was updated.
 SCAttachment is not saved at any point image is stored when added to REcentObject, SCLoud cache is cleared from attachment's segments
 
 
 
 When explicitly set avatar is removed resetGeneratedAvatarForGroup:showAlert: is called 
 It reset's hasGroupAvatarBeenSetExplicitly flag on RecentObject, generates avatar from current member's in group and save's it over the old avatar in chat directory.
 Group status message is created saying that group avatar was removed.
 
 
 When member count in group changes because someone was added or removed updateGroupAvatarWithCommandDict: is called
 It calculates correct member list depending on whether user was added or removed and generates new avatar from memberlist

 */
@interface GroupChatManager (AvatarUpdate)


/*
 Updates avatar with passed command dictionary
 
 Dictionary keys
 grpId - group uuid
 grp - group command in this case we process rmm member removal and addm member addition
 mbrs - array of member contactnames
 */
-(void) updateGroupAvatarWithCommandDict:(NSDictionary *) dict;



/*
 Set explicit avatar image from Camera or photos library picked image
 And send it to other group participants
 */
-(void) setExplicitAvatar:(NSDictionary *) info forGroup:(NSString *) uuid;



/*
 Parse received avatar update group command
 @param dict - dictionary of cloud info about avatar attachment required keys cloud_url and cloud_key
 @param commandDict - received group command
 */
-(void) parseReceivedAvatar:(NSDictionary *) dict forGroupCommand:(NSDictionary *)commandDict;


/*
 Removes explicitly set avatar and generate new avatar image from group member avatars
 @param uuid - uuid of group conversation
 @param showAlert - should show LocalAlertView saying that explicitly set group avatar was removed meaning it was reset
 @param showMessage - should create status messages saying avatar was removed
 */
-(void) resetGeneratedAvatarForGroup:(NSString *) uuid showAlert:(BOOL) showAlert showMessage:(BOOL) showMessage;
@end
