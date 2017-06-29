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
//  MWSPinLockKeypad.h
//
//  Created by Eric Turner on 7/1/14.
//  Copyright (c) 2014 MagicWave Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "MWSPinLockKeypadDelegate.h"

@class MWSShapeButtonsView;

@interface MWSPinLockKeypad : UIView

/** Delegate for MWSPinLockKeypad callbacks */
@property (weak, nonatomic) IBOutlet id<MWSPinLockKeypadDelegate> delegate;

//TEST make public
@property (weak, nonatomic) IBOutlet UIView *mainButtonsView;


// Resets self to a PIN sequence start state and updates the display.
//
// When the `arrEntries` collection of user button title entries is passed to `MWSPinLockScreenVC`, it
// notifies its MWSPinLockScreenDelegate with the entries and is returned a BOOL pass/fail. If the
// PIN/entries fails authentication, `MWSPinLockScreenVC` calls this method to restart the PIN sequence.
//
// This method invokes `reset` to reset self state, and "shakes" the `shapeButtonsView` 
// to indicate the PIN failure.
- (void)animateInvalidEntryResponseWithText:(NSString *)text completion:(void (^)(void))completion;

- (void)configureButtons;

- (void)setLabelTitle:(NSString *)labelTitle clearDots:(BOOL)shouldClearDots;

- (void)setBottomText:(NSString *)text;

- (void)enableTouchIDtarget:(id)target action:(SEL)action;

@end
