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
//
//  UIButton+SCButtons.m
//  SPi3
//
//  Created by Eric Turner on 12/13/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import "UIButton+SCButtons.h"
#import "UIColor+ApplicationColors.h"
#import "UIImage+ApplicationImages.h"

@implementation UIButton (SCButtons)

// Consumer will add target/action pair

+ (UIButton *)dialPadIcon {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setBackgroundImage:[UIImage dialPadIcon] forState:UIControlStateNormal];
    btn.frame = [self defaultFrame];
    return btn;
}

+ (UIButton *)qwertyKeyboardIcon {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setBackgroundImage:[UIImage qwertyKeyboardIcon] forState:UIControlStateNormal];
    btn.frame = [self defaultFrame];
    return btn;
}

+ (UIButton *)leftBackArrow {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *img = [[UIImage leftBackArrowIcon] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [btn setBackgroundImage:img forState:UIControlStateNormal];
    btn.frame = [self defaultFrame];
    return btn;
}

+ (UIButton *)backspaceIcon {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setBackgroundImage:[UIImage backspaceIcon] forState:UIControlStateNormal];
    btn.frame = [self defaultFrame];
    return btn;
}

+ (UIButton *)blankNoOp {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setBackgroundImage:[UIImage new] forState:UIControlStateNormal];
    btn.frame = [self defaultFrame];
    return btn;
}

static NSString * const kKbDismissButtonFontName = @"Arial Rounded MT Bold";
static CGFloat const kKbDismissButtonFontSize = 18.;
+ (UIButton *)keyboardDismiss {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = [self defaultFrame];
    
    CALayer *layer = btn.layer;
    layer.cornerRadius = 4.;
    layer.borderWidth  = 1.;
    layer.borderColor  = [UIColor lightBgColor].CGColor; //[UIColor darkBgColor].CGColor;
    
    // X title attribs
    UIFont *font = [UIFont fontWithName:kKbDismissButtonFontName size:kKbDismissButtonFontSize];
    NSDictionary *attribs = @{
                              NSFontAttributeName:font,
                              NSForegroundColorAttributeName:[UIColor lightBgColor]//[UIColor darkBgColor]
                              };
    NSAttributedString *x = [[NSAttributedString alloc] initWithString:@"X" attributes:attribs];
    [btn setAttributedTitle:x forState:UIControlStateNormal];
    
    return btn;
}

+ (UIButton *)settingsIcon {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = [self defaultFrame];
    UIImage *img = [[UIImage navigationBarSettings] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [btn setBackgroundImage:img forState:UIControlStateNormal];
    return btn;
}

#pragma mark - SCSTabBarAccessoryView 
// @see SCSTabBar class which includes the SCSTabBarAccessoryView class

+ (UIButton *)tabBarAccessoryLeft {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setBackgroundImage:[UIImage new] forState:UIControlStateNormal];
    btn.frame = [self defaultFrame];
    return btn;
}

+ (UIButton *)tabBarAccessoryRight {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setBackgroundImage:[UIImage new] forState:UIControlStateNormal];
    btn.frame = [self defaultFrame];
    return btn;
}


#pragma mark - Utilities

+ (CGRect)defaultFrame {
    return (CGRect){ .origin = CGPointZero, .size = [self defaultSize] };
}

+ (CGSize)defaultSize {
    return CGSizeMake(44., 44.);
}

@end
