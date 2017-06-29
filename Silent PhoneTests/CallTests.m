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
//  CallTests.m
//  SPi3
//
//  Created by Stelios Petrakis on 08/04/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SCPCall.h"

@interface CallTests : XCTestCase

@end

@implementation CallTests

- (void)testCallDurationOneSecond {
    
    NSString *callDuration = [SCPCall durationStringForCallDuration:1];
    NSString *expectedResult = @"00:01";
    
    XCTAssertTrue([callDuration isEqualToString:expectedResult],
                  @"Strings are not equal %@ %@", expectedResult, callDuration);
}

- (void)testCallDurationHalfAnHour {
    
    NSString *callDuration = [SCPCall durationStringForCallDuration:1800];
    NSString *expectedResult = @"30:00";
    
    XCTAssertTrue([callDuration isEqualToString:expectedResult],
                  @"Strings are not equal %@ %@", expectedResult, callDuration);
}

- (void)testCallDurationOneHour {
    
    NSString *callDuration = [SCPCall durationStringForCallDuration:3600];
    NSString *expectedResult = @"01:00:00";
    
    XCTAssertTrue([callDuration isEqualToString:expectedResult],
                  @"Strings are not equal %@ %@", expectedResult, callDuration);
}

- (void)testCallDurationTwoHours {
    
    NSString *callDuration = [SCPCall durationStringForCallDuration:7200];
    NSString *expectedResult = @"02:00:00";
    
    XCTAssertTrue([callDuration isEqualToString:expectedResult],
                  @"Strings are not equal %@ %@", expectedResult, callDuration);
}

- (void)testCallDurationThreeHoursAndFiftyMinutes {
    
    NSString *callDuration = [SCPCall durationStringForCallDuration:13800];
    NSString *expectedResult = @"03:50:00";
    
    XCTAssertTrue([callDuration isEqualToString:expectedResult],
                  @"Strings are not equal %@ %@", expectedResult, callDuration);
}


@end
