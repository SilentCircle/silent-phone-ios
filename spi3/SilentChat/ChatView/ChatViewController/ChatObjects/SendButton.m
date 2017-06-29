/*
Copyright (C) 2016-2017, Silent Circle, LLC.  All rights reserved.

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


#import "SendButton.h"
#import "UIImage+ApplicationImages.h"

@implementation SendButton
{
    UIImageView * doneBtnBackgroundImage;
    CGRect backgroundImageOriginalFrame;
}
-(instancetype)init
{
    if (self = [super init]) {
        // center frame of the send buttons image
        //backgroundImageOriginalFrame = CGRectMake(self.frame.size.width / 2 - ( 42/2 + 2) /2,self.frame.size.height / 2 - ( 34/2 + 2) / 2, 42/2 + 2, 34/2 + 2);
        doneBtnBackgroundImage = [[UIImageView alloc] initWithImage:[UIImage chatSendIcon]];
        [doneBtnBackgroundImage setUserInteractionEnabled:NO];
        //[doneBtnBackgroundImage setFrame:backgroundImageOriginalFrame];
        [doneBtnBackgroundImage setUserInteractionEnabled:NO];
        doneBtnBackgroundImage.center = CGPointMake(40 / 2, 40/ 2);
        backgroundImageOriginalFrame = doneBtnBackgroundImage.frame;
        [self addSubview:doneBtnBackgroundImage];
    }
    return self;
}
-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        // center frame of the send buttons image
        //backgroundImageOriginalFrame = CGRectMake(self.frame.size.width / 2 - ( 42/2 + 2) /2,self.frame.size.height / 2 - ( 34/2 + 2) / 2, 42/2 + 2, 34/2 + 2);
        doneBtnBackgroundImage = [[UIImageView alloc] initWithImage:[UIImage chatSendIcon]];
        //[doneBtnBackgroundImage setFrame:backgroundImageOriginalFrame];
        [doneBtnBackgroundImage setUserInteractionEnabled:NO];
        doneBtnBackgroundImage.center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);
        backgroundImageOriginalFrame = doneBtnBackgroundImage.frame;
        [self addSubview:doneBtnBackgroundImage];
    }
    return self;
}

-(void) clickAnimation
{
    CGRect doneBtnFrame = doneBtnBackgroundImage.frame;
    [UIView animateWithDuration:0.4 animations:^(void){
        CGRect doneBtnFlyOutFrame = doneBtnFrame;
        doneBtnFlyOutFrame.origin.x += 50;
        doneBtnFlyOutFrame.origin.y -= 50;
        [doneBtnBackgroundImage setFrame:doneBtnFlyOutFrame];
    }  completion:^(BOOL finished){
            [doneBtnBackgroundImage setFrame:doneBtnFrame];
            doneBtnBackgroundImage.transform = CGAffineTransformMakeScale(0.0, 0.0);
            [UIView animateWithDuration:0.2 animations:^(void){
                doneBtnBackgroundImage.transform = CGAffineTransformMakeScale(1.0f, 1.0f);
            } completion:^(BOOL finished){
                [doneBtnBackgroundImage setFrame:backgroundImageOriginalFrame];
            }];
        }];
}
// If done button doesn't register all touch events on ipad enable this 
/*
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self sendActionsForControlEvents:UIControlEventTouchUpInside];
}*/

@end
