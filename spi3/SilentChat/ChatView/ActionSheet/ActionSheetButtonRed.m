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
#define kTitleImageViewSize 40


#define kTitleFontColor [UIColor colorWithRed:79/255.0f green:79/255.0f blue:79/255.0f alpha:1.0f]
#import "ActionSheetButtonRed.h"
#import "ChatUtilities.h"
#import "LocationManager.h"
#import "RecentObject.h"
#import "UIImage+ApplicationImages.h"

@implementation ActionSheetButtonRed

-(instancetype)initWithFrame:(CGRect)frame{
    
    if (self = [super initWithFrame:frame]) {
        //self.alpha = 0.5f;
        self.titleEdgeInsets = UIEdgeInsetsMake(self.frame.size.height / 2  - kTitleImageViewSize/2 + kTitleImageViewSize, 0, 0, 0);
        _titleImageView = [[UIImageView alloc] init];
        
        [_titleImageView setContentMode:UIViewContentModeScaleAspectFit];
        [_titleImageView setFrame:CGRectMake(self.frame.size.width / 2  - kTitleImageViewSize/2, self.frame.size.height / 2  - kTitleImageViewSize/2, kTitleImageViewSize, kTitleImageViewSize)];
        [self.titleLabel setFont:[[Utilities utilitiesInstance] getFontWithSize:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline].pointSize]];
        [self setTitleColor:kTitleFontColor forState:0];
        self.titleLabel.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_titleImageView];
    }
    return self;
}
-(void)setButtonTag:(int)buttonTag
{
    switch (buttonTag) {
        case 0:
        {
            [self setTitle:NSLocalizedString(@"Take Photo", nil) forState:0];
            [_titleImageView setImage:[UIImage actionSheetTakePicture]];
        }
            break;
        case 1:
        {
            [self setTitle:NSLocalizedString(@"Gallery", nil) forState:0];
            [_titleImageView setImage:[UIImage actionSheetSendPicture]];
        }
            break;
        case 2:
        {
            [self setTitle:NSLocalizedString(@"Take Video", nil) forState:0];
            [_titleImageView setImage:[UIImage actionSheetSendVideoPicture]];
        }
            break;
        case 3:
        {
            [self setTitle:NSLocalizedString(@"Share Location", nil) forState:0];
            
            if([Utilities utilitiesInstance].selectedRecentObject.shareLocationTime > time(NULL))
                [self setLocation:YES];
            else
            {
                [[LocationManager sharedManager] stopUpdatingLocation];
                [self setLocation:NO];
            }
        }
            break;
        case 4:
        {
            [self setTitle:NSLocalizedString(@"Share Contact", nil) forState:0];
            [_titleImageView setImage:[UIImage actionSheetShareContactPicture]];
        }
            break;
        case 5:
        {
            [self setTitle:NSLocalizedString(@"Record Audio", nil) forState:0];
            [_titleImageView setImage:[UIImage actionSheetRecordAudioIcon]];
        }
            break;
            
        default:
            break;
    }
    _buttonTag = buttonTag;
}

-(void) setLocation:(BOOL) state
{
    if(state)
    {
        _locationStatus = 1;
        [_titleImageView setImage:[UIImage actionSheetShareLocationOn]];
    } else
    {
        _locationStatus = -1;
        [_titleImageView setImage:[UIImage actionSheetShareLocationOff]];
    }
    if(_locationStatus == 1)
    {
        // reset the frame before animating
        [_titleImageView setFrame:CGRectMake(self.frame.size.width / 2  - kTitleImageViewSize/2, self.frame.size.height / 2  - kTitleImageViewSize/2, kTitleImageViewSize, kTitleImageViewSize)];
        [_titleImageView.layer removeAllAnimations];
        [UIView animateWithDuration:0.2f
                              delay:0.0f
                            options:UIViewAnimationCurveEaseOut |
         UIViewAnimationOptionRepeat |
         UIViewAnimationOptionAutoreverse
                         animations:^{
                             [_titleImageView setFrame:CGRectMake(_titleImageView.frame.origin.x - 3, _titleImageView.frame.origin.y - 3, _titleImageView.frame.size.width + 6, _titleImageView.frame.size.height + 6)];
                         }
                         completion:^(BOOL finished) {
                             // You could do something here
                         }];
    } else
    {
        [UIView animateWithDuration:0.2f animations:^(void)
         {
             [_titleImageView setFrame:CGRectMake(self.frame.size.width / 2  - kTitleImageViewSize/2, self.frame.size.height / 2  - kTitleImageViewSize/2, kTitleImageViewSize, kTitleImageViewSize)];
         }completion:^(BOOL finished) {
             [_titleImageView.layer removeAllAnimations];
         }];
    }
}

@end
