//
//  SCAvatar.m
//  SPi3
//
//  Created by Gints Osis on 18/05/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCAvatar.h"
#import "SCCImageUtilities.h"
#import "SCSAvatarManager.h"
@implementation SCAvatar

-(void)setAvatarImage:(UIImage *)avatarImage
{
    if (avatarImage.size.width > [AvatarManager fullSizeAvatarWidth])
    {
        CGSize maxImageSize = CGSizeMake([AvatarManager fullSizeAvatarWidth],avatarImage.size.height * [AvatarManager fullSizeAvatarWidth] / avatarImage.size.width);
        
       _avatarImage = [SCCImageUtilities scaleImage:avatarImage ToSize:maxImageSize];
    } else
    {
        _avatarImage = avatarImage;
    }
    
    CGSize smallAvatarSize = CGSizeMake([AvatarManager smallSizeAvatarWidth],avatarImage.size.height * [AvatarManager smallSizeAvatarWidth] / avatarImage.size.width);
    UIImage *scaledImage = [SCCImageUtilities scaleImage:avatarImage ToSize:smallAvatarSize];
    _smallAvatarImage = scaledImage;
}
@end
