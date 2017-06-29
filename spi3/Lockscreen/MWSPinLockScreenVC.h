/*
Copyright (C) 2014-2017, Silent Circle, LLC.  All rights reserved.

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
//  MWSPinLockScreenVC.h
//
//  Created by Eric Turner on 7/1/14.
//  Copyright (c) 2014 MagicWave Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SCPPasscodeManager.h"

@protocol MWSPinLockScreenDelegate;

@interface MWSPinLockScreenVC : UIViewController

@property (nonatomic, weak) SCPPasscodeManager *passcodeManager;
@property (nonatomic, weak) id<MWSPinLockScreenDelegate> delegate;
@property (nonatomic, getter=shouldUseLightBlur) BOOL useLightBlur;
@property (strong, nonatomic) UIImage *backgroundImage;

- (instancetype)initWithLabelTitle:(NSString *)labelTitle completion:(void (^)(MWSPinLockScreenVC *pinLockScreenVC, NSString *passcode))completion;

- (void)enableTouchIDtarget:(id)target action:(SEL)action;

- (void)setLabelTitle:(NSString *)labelTitle clearDots:(BOOL)shouldClearDots;

- (void)animateInvalidEntryResponse;

- (void)animateInvalidEntryResponseWithText:(NSString *)text completion:(void (^)(void))completion;

- (void)setBottomText:(NSString *)text;

- (void)setUserInteractionEnabled:(BOOL)enabled;

- (void)updateLockScreenStatus;

@end

@protocol MWSPinLockScreenDelegate <NSObject>
@optional
    - (void)lockScreenSelectedCancel:(MWSPinLockScreenVC *)pinLockScreenVC;
@end
