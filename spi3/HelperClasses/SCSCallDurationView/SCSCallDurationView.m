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
//  SCSCallDurationView.m
//  SPi3
//
//  Created by Eric Turner on 3/19/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "SCSCallDurationView.h"

#import "SCPCall.h"

@implementation SCSCallDurationView



- (void)updateDurationWithCall:(SCPCall *)aCall {
    if (!aCall)
        [self clear];
    else
        _label.text = aCall.durationString;
}

- (void)clear {
    _label.text = @"";
}

#pragma Accessibility

// Expected label format: "[min]:[sec]"
- (NSString *)accessibilityLabel {
    return [self accessibilityString];
}

- (NSString *)accessibilityString {
    NSString *txt = _label.text;
    if (!txt || txt.length < 1)
        return NSLocalizedString(@"call duration", nil);
    
    NSArray *parts = [_label.text componentsSeparatedByString:@":"];

    NSString *hr  = @"";
    NSString *min = @"";
    NSString *sec = @"";
    if (parts.count > 2) {
        hr =  [self intStringFromString:parts[0] timeUnit:@"hour"];
        hr = (hr.length) ? [hr stringByAppendingString:@","] : @"";
        min = [self intStringFromString:parts[1] timeUnit:@"minute"];
        sec = [self intStringFromString:parts[2] timeUnit:@"second"];
    }
    else if (parts.count > 1) {
        min = [self intStringFromString:parts[0] timeUnit:@"minute"];
        sec = [self intStringFromString:parts[1] timeUnit:@"second"];
    }
    else if (parts.count > 0) {
        sec = [self intStringFromString:parts[0] timeUnit:@"second"];
    }
    
    txt = [NSString stringWithFormat:@"%@ %@, %@", hr, min, sec];
    
    return txt;
}

- (NSString *)intStringFromString:(NSString *)valStr timeUnit:(NSString *)uStr {
    NSString *str = @"";
    int val = [valStr intValue];
    if (val > 0) {  // don't speak zero min/sec
        // format for singular/plural value
        // e.g. "1 minute, 2 seconds"
        str = [NSString stringWithFormat:@"%i %@%@",
               val, uStr, (val==1) ? @"" : @"s"];
    }
    return str;
}

@end
