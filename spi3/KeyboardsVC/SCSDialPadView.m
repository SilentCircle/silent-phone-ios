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
//  SCSDialPadView.m
//  SPi3
//
//  Created by Eric Turner on 12/16/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import "SCSDialPadView.h"
#import "SCSDialPadButton.h"
#import "SCPCallManager.h"

@interface SCSDialPadView ()
@property (weak, nonatomic) IBOutlet SCSDialPadButton *btnZero; // DialPad Zero button
@property (weak, nonatomic) IBOutlet UIButton *btnBackspace;    // DialPad Backspace button
@end

@implementation SCSDialPadView
{
    BOOL    _btnBackspaceIsDown;
    NSDate *_timeOfLastBackspace;
}


#pragma mark - Initialization

- (void)dealloc {
    
    [SPCallManager stopDTMF];
}

#pragma mark - SCSDialPadDelegate Methods

- (IBAction)buttonDown:(SCSDialPadButton *)btn {
    
    [SPCallManager playDTMFTone:btn.dialPadStringValue
                           call:_call];
        
    [self notifyDelegateWithAction:@selector(dialButtonDown:) object:btn];
}

- (IBAction)buttonUp:(SCSDialPadButton *)btn {
    
    [SPCallManager pauseDTMFTone];

    [self notifyDelegateWithAction:@selector(dialButtonUp:) object:btn];
}

- (IBAction)zeroButtonLongPress:(UILongPressGestureRecognizer *)gr {
    SCSDialPadButton *btn0 = (SCSDialPadButton*)gr.view;

    if ([gr isKindOfClass:[UILongPressGestureRecognizer class]] && btn0 == _btnZero) {
    
        [self buttonUp:(SCSDialPadButton*)_btnZero];

        switch (gr.state) {
            case UIGestureRecognizerStatePossible:
                break;
            case UIGestureRecognizerStateBegan:
                [self notifyDelegateWithAction:@selector(zeroButtonWasLongPressed:) object:_btnZero];
//                if ([_delegate respondsToSelector:@selector(zeroButtonWasLongPressed:)]) {
//                    [_delegate zeroButtonWasLongPressed:_btnZero];
//                }
                break;
            case UIGestureRecognizerStateChanged:
            case UIGestureRecognizerStateCancelled:
            case UIGestureRecognizerStateFailed:
            case UIGestureRecognizerStateEnded:
            default: {
                break;
            }
        }
    }
}


- (IBAction)callButtonPressed:(UIButton *)btn {
    [self notifyDelegateWithAction:@selector(callButtonWasPressed) object:nil];
}


#pragma mark - Backspace

- (IBAction)btnBackspaceDown:(UIButton *)btn {
    _btnBackspaceIsDown = YES;
    [self notifyDelegateWithAction:@selector(backspaceDown) object:nil];
}

- (IBAction)btnBackspaceUp:(UIButton *)btn {
    _btnBackspaceIsDown = NO;
    [self notifyDelegateWithAction:@selector(backspaceUp) object:nil];
}

- (BOOL)backspaceButtonIsDown {
    return _btnBackspaceIsDown;
}

- (void)setBackspaceButtonIsDown:(BOOL)yesno {
    _btnBackspaceIsDown = yesno;
}

- (NSDate *)lastBackspaceTime {
    return _timeOfLastBackspace;
}

- (void)setLastBackspaceTime:(NSDate *)ltime {
    _timeOfLastBackspace = ltime;
}

/**
 * For long press on Zero dialPad button, call method to change last
 * input character, "0", to "+".
 *
 * @param lPress Long press gesture recognizer added to "0" dial pad
 * button and configured in IB.
 */
- (IBAction)handleBackspaceLongPress:(UILongPressGestureRecognizer *)lPress {
    switch (lPress.state) {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStatePossible:
        case UIGestureRecognizerStateChanged:
            _btnBackspaceIsDown = YES;
            [self notifyDelegateWithAction:@selector(backspaceLongPressDown:) object:_btnBackspace];
            break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        case UIGestureRecognizerStateEnded:
        default: {
            _btnBackspaceIsDown = NO;
            break;
        }
    }
}


#pragma mark - Utilities 

- (void)notifyDelegateWithAction:(SEL)action object:(id)obj {
    // Suppress compiler warning for delegate callback helper methods
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if ([_delegate respondsToSelector:action]) {
        [_delegate performSelector:action withObject:obj];
    }
#pragma clang diagnostic pop
}

@end
