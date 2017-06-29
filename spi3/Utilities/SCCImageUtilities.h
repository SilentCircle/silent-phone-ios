//
//  SCCImageUtilities.h
//  SPi3
//
//  Created by Gints Osis on 24/01/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "RecentObject.h"

@interface SCCImageUtilities : NSObject
/*
 Constructs avatar image for group conversation
 
 @param imageArray - array of images to draw
 
 @return imageBlock - block with new avatar image
 
 */
+(void) constructGroupAvatarFromAvatars:(NSArray *) imageArray totalCount:(long) totalCount completion:(void(^) (UIImage *avatarImage)) imageBlock;

+ (UIImage *)scaleImage:(UIImage*) image ToSize:(CGSize)targetSize;

+(UIImage *) roundAvatarImage:(UIImage *) image;
/*
 Create initials image for member displayname
 Renders uilabel with background color
 */
+(UIImage *)constructMemberAvatarFromDisplayName:(NSString *) displayName;
@end
