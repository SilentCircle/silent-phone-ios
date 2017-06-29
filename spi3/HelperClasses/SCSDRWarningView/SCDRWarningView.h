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
//  SCDRWarningView.h
//  Silent Phone
//
//  Created by Ethan Arutunian on 9/27/16.
//  Copyright (c) 2016 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RecentObject.h"

@interface SCDRWarningView : UIView {
    NSLayoutConstraint *_topOfViewBelow;
    CGFloat _offsetY;
}

@property (assign, nonatomic) BOOL enabled;
@property (assign, nonatomic) UIViewController *infoHolderVC;
@property (strong, nonatomic, readonly) RecentObject *recipient;

@property (weak, nonatomic) IBOutlet UIButton *drButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *warningViewTopConstant;


// public methods
// call this first, then set enabled
- (void)positionWarningAboveConstraint:(NSLayoutConstraint *)topOfViewBelow;
- (void)positionWarningAboveConstraint:(NSLayoutConstraint *)topOfViewBelow offsetY:(CGFloat)offsetY;

#if HAS_DATA_RETENTION
- (void)enableWithRecipient:(RecentObject *)recipient;

// info popup
+ (void)presentInfoInVC:(UIViewController *)holderVC recipient:(RecentObject *)recipient;
#endif // HAS_DATA_RETENTION

@end
