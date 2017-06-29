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
//  UtilitiesTests.m
//  SPi3
//
//  Created by Stelios Petrakis on 25/08/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ChatUtilities.h"

@interface UtilitiesTests : XCTestCase

@end

@implementation UtilitiesTests

- (void)testIsNumberNumeric {

    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:@"1"];
    
    XCTAssertTrue(isNumber);
}

- (void)testIsNumberWithPlus {
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:@"+12024996427"];
    
    XCTAssertTrue(isNumber);
}

- (void)testIsNumberWithoutPlus {
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:@"12024996427"];
    
    XCTAssertTrue(isNumber);
}

- (void)testIsNumberUsernameWithoutSip {
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:@"frank"];
    
    XCTAssertTrue(!isNumber);
}

- (void)testIsNumberUsernameWithSip {
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:@"sip:stelios"];
    
    XCTAssertTrue(!isNumber);
}

- (void)testIsNumberUsernameWithFullSipAddress {
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:@"sip:eturner@sip.silentcircle.net"];
    
    XCTAssertTrue(!isNumber);
}

- (void)testIsNumberUsernameWithFullSPAddress {
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:@"silentphone:prz@sip.silentcircle.net"];
    
    XCTAssertTrue(!isNumber);
}

- (void)testIsNumberOneEmptyCharacter {
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:@" 12024996427"];
    
    XCTAssertTrue(isNumber);
}

- (void)testIsNumberParenthesis {
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:@"(0030)6987103404"];
    
    XCTAssertTrue(isNumber);
}

- (void)testIsNumberMinus {
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:@"0030-12345678"];
    
    XCTAssertTrue(isNumber);
}

- (void)testIsNumberStar {
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:@"*3783*"];
    
    XCTAssertTrue(isNumber);
}

- (void)testIsNumberSipPrefix {
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:@"sip:12024996427"];
    
    XCTAssertTrue(isNumber);
}

- (void)testIsNumberSPPrefix {
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:@"silentphone:12024996427"];
    
    XCTAssertTrue(isNumber);
}

- (void)testIsTestSilentUserANumber {
    
    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:@"silentcircle234@sip.silentcircle.net"];
    
    XCTAssertTrue(!isNumber);
}

@end
