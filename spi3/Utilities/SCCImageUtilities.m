//
//  SCSImageUtilities.m
//  SPi3
//
//  Created by Gints Osis on 24/01/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCCImageUtilities.h"
#import <CoreGraphics/CoreGraphics.h>

#import "Silent_Phone-Swift.h"
#import "ChatUtilities.h"
#import "DBManager.h"
#import "SCSAvatarManager.h"
@implementation SCCImageUtilities

#pragma mark Group Chat Avatar's

// Size of group avatar image
static const CGSize kGroupAvatarSize = {256, 256};

static const float eTurnersMeaningOfLife = 0.42;



+(NSArray *) avatarBackgroundColors
{
    static NSArray *backgroundColors;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        backgroundColors = @[[UIColor colorWithRed:248/255.0 green:90/255.0 blue:72/255.0 alpha:1.0],
                             [UIColor colorWithRed:145/255.0 green:136/255.0 blue:243/255.0 alpha:1.0],
                             [UIColor colorWithRed:62/255.0 green:173/255.0 blue:111/255.0 alpha:1.0],
                             [UIColor colorWithRed:164/255.0 green:192/255.0 blue:88/255.0 alpha:1.0],
                             [UIColor colorWithRed:91/255.0 green:186/255.0 blue:177/255.0 alpha:1.0],
                             ];
    });
    return backgroundColors;
}

+(void) constructGroupAvatarFromAvatars:(NSArray *) imageArray totalCount:(long) totalCount completion:(void(^) (UIImage *avatarImage)) imageBlock
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        /*
         Draw the avatar depending on participant count
         */
        UIGraphicsBeginImageContext(kGroupAvatarSize);
        
        if (imageArray.count == 1)
        {
            // draw one image covering entire avatarimage
            UIImage *image = (UIImage *)imageArray[0];
            [image drawInRect:CGRectMake(0, 0, kGroupAvatarSize.width, kGroupAvatarSize.height)];
        } else if(imageArray.count == 2)
        {
            // draw two images centered vertically in avatarimage
            UIImage *image1 = (UIImage *)imageArray[0];
            UIImage *image2 = (UIImage *)imageArray[1];
            [image1 drawInRect:CGRectMake(0, kGroupAvatarSize.height / 2 - kGroupAvatarSize.height / 4, kGroupAvatarSize.width /2 , kGroupAvatarSize.height / 2)];
            [image2 drawInRect:CGRectMake(kGroupAvatarSize.width / 2, kGroupAvatarSize.height / 2 - kGroupAvatarSize.height / 4, kGroupAvatarSize.width /2 , kGroupAvatarSize.height / 2)];
        } else if(imageArray.count == 3 && totalCount == 3)
        {
            // draw three images and center horizontally the bottom image
            UIImage *image1 = (UIImage *)imageArray[0];
            UIImage *image2 = (UIImage *)imageArray[1];
            UIImage *image3 = (UIImage *)imageArray[2];
            
            [image1 drawInRect:CGRectMake(0, 0, kGroupAvatarSize.width /2 , kGroupAvatarSize.height / 2)];
            
            [image2 drawInRect:CGRectMake(kGroupAvatarSize.width / 2, 0, kGroupAvatarSize.width /2 , kGroupAvatarSize.height / 2)];
            
            [image3 drawInRect:CGRectMake(kGroupAvatarSize.width / 2 - kGroupAvatarSize.height / 4, kGroupAvatarSize.height / 2, kGroupAvatarSize.width /2 , kGroupAvatarSize.height / 2)];
        } else if(imageArray.count == 4)
        {
            // draw four images
            UIImage *image1 = (UIImage *)imageArray[0];
            UIImage *image2 = (UIImage *)imageArray[1];
            UIImage *image3 = (UIImage *)imageArray[2];
            UIImage *image4 = (UIImage *)imageArray[3];
            
            [image1 drawInRect:CGRectMake(0, 0, kGroupAvatarSize.width /2 , kGroupAvatarSize.height / 2)];
            
            [image2 drawInRect:CGRectMake(kGroupAvatarSize.width / 2, 0, kGroupAvatarSize.width /2 , kGroupAvatarSize.height / 2)];
            
            [image3 drawInRect:CGRectMake(0, kGroupAvatarSize.height / 2, kGroupAvatarSize.width /2 , kGroupAvatarSize.height / 2)];
            
            [image4 drawInRect:CGRectMake(kGroupAvatarSize.width / 2, kGroupAvatarSize.height / 2, kGroupAvatarSize.width /2 , kGroupAvatarSize.height / 2)];
        } else if(imageArray.count == 3 && totalCount > 0)
        {
            // draw three images and set the fourth image to contain empty contact image with extra member count
            UIImage *image1 = (UIImage *)imageArray[0];
            UIImage *image2 = (UIImage *)imageArray[1];
            UIImage *image3 = (UIImage *)imageArray[2];
            long extraMemberCount = totalCount - 3;
            UIImage *image4 = [self constructPlusUserImageWithCount:extraMemberCount];
            
            [image1 drawInRect:CGRectMake(0, 0, kGroupAvatarSize.width /2 , kGroupAvatarSize.height / 2)];
            
            [image2 drawInRect:CGRectMake(kGroupAvatarSize.width / 2, 0, kGroupAvatarSize.width /2 , kGroupAvatarSize.height / 2)];
            
            [image3 drawInRect:CGRectMake(0, kGroupAvatarSize.height / 2, kGroupAvatarSize.width /2 , kGroupAvatarSize.height / 2)];
            
            [image4 drawInRect:CGRectMake(kGroupAvatarSize.width / 2, kGroupAvatarSize.height / 2, kGroupAvatarSize.width /2 , kGroupAvatarSize.height / 2)];
        }
        
        UIImage *avatarImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        imageBlock(avatarImage);
        
    });
}

+(UIImage *)roundAvatarImage:(UIImage *)image
{
    return [self constructRoundedAvatarWithImage:image andSize:CGSizeMake(image.size.width, image.size.height)];
}

+(UIImage*) constructRoundedAvatarWithImage:(UIImage *) image andSize:(CGSize) size
{
    UIImage *roundedCornerImage = nil;
    
    // for non square images take biggest dimension and draw withing bounds of that
    CGFloat biggestDimension = size.width;
    if (size.height > biggestDimension)
        biggestDimension = size.height;
    // passing 0.0 to scale equals scale factor to this devices screen scale
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(biggestDimension, biggestDimension), NO, 0.0);
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, biggestDimension, biggestDimension)
                                cornerRadius:biggestDimension / 2] addClip];
    [image drawInRect:CGRectMake(0, 0, biggestDimension, biggestDimension)];
    roundedCornerImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return roundedCornerImage;
}

+(UIImage *) constructPlusUserImageWithCount:(long) number
{
    NSString *plusDisplayName = [NSString stringWithFormat:@"+%li",number];
    long colorIndex = (plusDisplayName.hash % [[self class] avatarBackgroundColors].count);
    return [self imageWIthInitials:plusDisplayName colorIndex:colorIndex];
}

+(UIImage *)constructMemberAvatarFromDisplayName:(NSString *) displayName
{
    long colorIndex = (displayName.hash % [[self class] avatarBackgroundColors].count);
    NSString *initials = [[ChatUtilities utilitiesInstance] getInitialsForUserName:displayName];
    return [self imageWIthInitials:initials colorIndex:colorIndex];
}

+(UIImage *) imageWIthInitials:(NSString *) initials colorIndex:(long) colorIndex
{
    UIImage *memberImage = nil;
    
    CALayer *solidBackgroundColorLayer = [[CALayer alloc] init];
    UIColor *backgroundColor = [self avatarBackgroundColors][colorIndex];
    solidBackgroundColorLayer.backgroundColor = backgroundColor.CGColor;
    [solidBackgroundColorLayer setFrame:CGRectMake(0, 0, kGroupAvatarSize.width, kGroupAvatarSize.height)];
    solidBackgroundColorLayer.masksToBounds = YES;
    solidBackgroundColorLayer.cornerRadius = kGroupAvatarSize.width / 2;
    
    float fontSize = kGroupAvatarSize.width * eTurnersMeaningOfLife;
    CATextLayer *label = [[CATextLayer alloc] init];
    [label setFont:(__bridge CFTypeRef _Nullable)([[ChatUtilities utilitiesInstance] getFontWithSize:fontSize])];
    [label setFontSize:fontSize];
    label.foregroundColor = [UIColor whiteColor].CGColor;
    [label setFrame:CGRectMake(0, kGroupAvatarSize.width / 4, kGroupAvatarSize.width, kGroupAvatarSize.height)];
    [label setString:initials];
    [label setAlignmentMode:kCAAlignmentCenter];
    [solidBackgroundColorLayer addSublayer:label];
    
    // passing 0.0 to scale equals scale factor to this devices screen scale
    UIGraphicsBeginImageContextWithOptions(kGroupAvatarSize, NO, 0.0);
    [solidBackgroundColorLayer renderInContext:UIGraphicsGetCurrentContext()];
    memberImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return memberImage;
}

/**
 Scale image to Size
 @param image - image to resize
 @param targetSie - Size to resize to
 **/
+ (UIImage *)scaleImage:(UIImage*) image ToSize:(CGSize)targetSize
{
    UIImage *sourceImage = image;
    UIImage *newImage = nil;
    
    CGSize imageSize = sourceImage.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    
    CGFloat targetWidth = targetSize.width;
    CGFloat targetHeight = targetSize.height;
    
    CGFloat scaleFactor = 0.0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;
    
    CGPoint thumbnailPoint = CGPointMake(0.0,0.0);
    
    if (CGSizeEqualToSize(imageSize, targetSize) == NO) {
        
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;
        
        if (widthFactor < heightFactor)
            scaleFactor = widthFactor;
        else
            scaleFactor = heightFactor;
        
        scaledWidth  = width * scaleFactor;
        scaledHeight = height * scaleFactor;
        
        if (widthFactor < heightFactor) {
            thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
        } else if (widthFactor > heightFactor) {
            thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
        }
    }
    UIGraphicsBeginImageContext(targetSize);
    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width  = scaledWidth;
    thumbnailRect.size.height = scaledHeight;
    [sourceImage drawInRect:thumbnailRect];
    newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}



@end
