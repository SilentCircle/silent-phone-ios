/*
Copyright (C) 2016, Silent Circle, LLC.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Any redistribution, use, or modification is done solely for personal
      benefit and not for any commercial purpose or for monetary gain
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name Silent Circle nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SILENT CIRCLE, LLC BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
#define kContactImageOffsetFromvCard 5
#define kContactImageSize 60

#define circleImage [UIImage imageNamed:@"vcardCircle.png"]

#define fontColor  [UIColor colorWithRed:93/255.0f green:95/255.0f blue:102/255.0f alpha:1.0f]
#define kReceivedMessageBackgroundColor [UIColor colorWithRed:246/255.0f green:243/255.0f blue:235/255.0f alpha:1.0f]

#import "UserContact.h"
#import "Utilities.h"

@implementation UserContact
-(UIImage *) setVcardThumbnail:(UIImage *) contactImage
{
    UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320 / 2, 70)];
   // backgroundView.opaque = NO;
    [backgroundView setBackgroundColor:kReceivedMessageBackgroundColor];
    
    
    UILabel *contactName = [[UILabel alloc] initWithFrame:CGRectMake(kContactImageSize + 5, 0, 320 / 2 - 55 -  10, 70)];
    [contactName setTextAlignment:NSTextAlignmentCenter];
    contactName.adjustsFontSizeToFitWidth = YES;
    [contactName setTextColor:fontColor];
    [contactName setFont:[UIFont fontWithName:@"Karbon-italic" size:16]];
    contactName.numberOfLines = 2;
    contactName.text = _contactFullName;
    [backgroundView addSubview:contactName];

    UIImage *backgroundImage = [UserContact imageWithView:backgroundView];
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
        UIGraphicsBeginImageContextWithOptions(backgroundImage.size, NO, [UIScreen mainScreen].scale);
    else
        UIGraphicsBeginImageContext(backgroundImage.size);
    [backgroundImage drawInRect:CGRectMake(0, 0, backgroundImage.size.width, backgroundImage.size.height)];
    [contactImage drawInRect:CGRectMake(kContactImageOffsetFromvCard,kContactImageOffsetFromvCard, kContactImageSize,kContactImageSize)];
    [circleImage drawInRect:CGRectMake(kContactImageOffsetFromvCard,kContactImageOffsetFromvCard, kContactImageSize,kContactImageSize)];
    UIImage *contactImageInVcard = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return contactImageInVcard;
}

+ (UIImage *) imageWithView:(UIView *)view
{
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
        UIGraphicsBeginImageContextWithOptions(view.frame.size, view.opaque, [UIScreen mainScreen].scale);
    else
        UIGraphicsBeginImageContext(view.bounds.size);
     [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}
@end
