//
//  SCPCallHelperTests.m
//  SPi3
//
//  Created by Stelios Petrakis on 07/04/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SCPCallHelper.h"

@interface SCPCallHelperTests : XCTestCase

@end

@implementation SCPCallHelperTests

- (void)testIsMagicNumberPhone {

    BOOL isMagicNumber = [SCPCallHelper isMagicNumber:@"+12024996427"];
    
    XCTAssertTrue(!isMagicNumber);
}

- (void)testIsMagicNumberSip {
    
    BOOL isMagicNumber = [SCPCallHelper isMagicNumber:@"frank"];
    
    XCTAssertTrue(!isMagicNumber);
}

- (void)testIsMagicNumberEmail {
    
    BOOL isMagicNumber = [SCPCallHelper isMagicNumber:@"bob@alice.com"];
    
    XCTAssertTrue(!isMagicNumber);
}

- (void)testIsMagicNumberMagic {
    
    BOOL isMagicNumber = [SCPCallHelper isMagicNumber:@"*##*1234*"];
    
    XCTAssertTrue(isMagicNumber);
}

- (void)testIsMagicNumberEcho {
    
    BOOL isMagicNumber = [SCPCallHelper isMagicNumber:@"*3246"];
    
    XCTAssertTrue(!isMagicNumber);
}

@end
