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
#import "TabBarWithSeperators.h"
#import "Utilities.h"

#define kSeperatorColor  [UIColor colorWithRed:114/255.0f green:115/255.0f blue:119/255.0f alpha:1.0f]

#define kSelectedColor [UIColor colorWithRed:228/255.0f green:60/255.0f blue:49/255.0f alpha:1.0f]

#define kDeselectedColor [UIColor colorWithRed:54/255.0f green:55/255.0f blue:58/255.0f alpha:1.0f]
@implementation TabBarWithSeperators

-(void) addSeperators
{
    if(!_seperatorBackgrounds)
    {
        _seperatorBackgrounds = [[NSMutableArray alloc] init];
        UIView *backgroundview = [[UIView alloc] initWithFrame:CGRectMake(0, 0
                                                                          , [Utilities utilitiesInstance].screenWidth, 50)];
        [backgroundview setBackgroundColor:[UIColor clearColor]];
        int buttonWidth = [Utilities utilitiesInstance].screenWidth/5;
        int uiTabBarHeight;
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
            uiTabBarHeight = 56;
        } else
        {
            uiTabBarHeight = 49;
        }
        
        for (int i = 0; i < 5; i++) {
            UIView *grayButtonView = [[UIView alloc] initWithFrame:CGRectMake((i * buttonWidth )+ i - 2, uiTabBarHeight - 3, buttonWidth , 3)];
            [grayButtonView setBackgroundColor:[Utilities utilitiesInstance].kChatViewBackgroundColor];
            [backgroundview addSubview:grayButtonView];
            [_seperatorBackgrounds addObject:grayButtonView];
            
        }
        [self addSubview:backgroundview];
        [self sendSubviewToBack:backgroundview];
        [self selectSeperatorWithTag:3];
    }
    
}

-(void) deselectSeperators
{
    for (int i = 0; i < _seperatorBackgrounds.count; i++) {
        UIView *seperatorBackground = (UIView *)_seperatorBackgrounds[i];
        [seperatorBackground setBackgroundColor:[UIColor clearColor]];
    }
}

-(void) selectSeperatorWithTag:(int)tag
{
    [self deselectSeperators];
    if(tag == 0 && tag == 1 && tag == 2)
    {
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    } 
    if(_seperatorBackgrounds.count > tag)
    {
        UIView *seperator = (UIView *) _seperatorBackgrounds[tag];
        [seperator setBackgroundColor:kSelectedColor];
    }
}
@end
