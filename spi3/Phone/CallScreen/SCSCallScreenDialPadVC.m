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
//  SCSCallScreenDialPadVC.m
//  SPi3
//
//  Created by Eric Turner on 3/12/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "SCSCallScreenDialPadVC.h"
#import "SCSDialPadButton.h"
#import "SCPCallManager.h"

@implementation SCSCallScreenDialPadVC

#pragma mark - Lifecycle

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    if(_call && _dialPad)
        [_dialPad setCall:_call];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(proximityStateChanged)
                                                 name:UIDeviceProximityStateDidChangeNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    _textfield.text = nil;
}

#pragma mark - Public

- (void)setCall:(SCPCall *)call {
    
    _call = call;
    
    if(_dialPad)
        [_dialPad setCall:call];
}

#pragma mark - SCSDialPadDelegate

// DialPadView handles DTMF
- (void)dialButtonDown:(SCSDialPadButton*)btn {
    [self appendDialInputWithText:btn.dialPadStringValue];
}

- (void)appendDialInputWithText:(NSString *)str {
    NSString *newStr = _textfield.text;
    if (newStr.length > 0) {
        newStr = [NSString stringWithFormat:@"%@%@", newStr, str];
    } else {
        newStr = str;
    }
    _textfield.text = newStr;
}

#pragma mark - UITextFieldDelegate

// return NO to disallow editing.
- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField{
    return NO;
}

// called when 'return' key pressed. return NO to ignore.
- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    return YES;
}

#pragma mark - Private

- (void)proximityStateChanged {
    
    // Pauses DTMF tone if user enabled the proximity sensor
    // while another finger is still tapping a number
    [SPCallManager pauseDTMFTone];
}

@end
