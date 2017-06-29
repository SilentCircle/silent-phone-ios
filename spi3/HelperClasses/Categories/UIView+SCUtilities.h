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
//  UIView+SCUtilities.h
//  SPi3
//
//  Created by Eric Turner on 5/4/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (SCUtilities)

/** 
 * Fades out the given view over the duration interval, then sets it to
 * hidden. If the duration argument is zero, the view is hidden without
 * fade animation.
 * Animates the given view alpha property from 1.0 to 0.0 over the 
 * duration interval. If the duration argument is zero, the view is
 * made visible without animation. 
 *
 * Example: [self fadeOutView:lbVersion duration:0.0 completion:nil];
 * This hides the version label (a UIView subclass) immediately, no animation.
 *
 * @param aView The view to fade out, then set hidden.
 * 
 * @param duration The time invterval over which to animate the fade out.
 *
 * @param completion A block to be executed in the completion block of
 *        the animation. May be nil.
 */
+ (void)fadeOutView:(UIView *)aView duration:(NSTimeInterval)dur completion:(void (^)())completion;

/**
 * Fades out the given view over the duration interval, then sets it to
 * hidden. If the duration argument is zero, the view is hidden without
 * fade animation. 
 *
 * Example:     
 * [self fadeInView:passwordFieldView duration:0.35 completion:^{
 *     // Ensure password text is obscured -
 *     // wait until the animation is complete so that unchecking
 *     // the checkbox will be visible.
 *     [self securePasswordField];
 *  }];
 *
 * This hides the version label immediately, no animation.
 *
 * @param aView The view to fade in. May be passed in hidden state.
 * 
 * @param duration The time invterval over which to animate the fade in.
 *
 * @param completion A block to be executed in the completion block of
 *        the animation. May be nil.
 */
+ (void)fadeInView:(UIView *)aView duration:(NSTimeInterval)dur completion:(void (^)())completion;


+ (void)crossFadeViewIn:(UIView *)viewIn viewOut:(UIView *)viewOut 
               duration:(NSTimeInterval)dur completion:(void (^)(BOOL finished))completion;

@end
