//
//  CleanContactInfoTests.m
//  SPi3
//
//  Created by Stelios Petrakis on 01/02/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SCSContactsManager.h"

@interface CleanContactInfoTests : XCTestCase

@end

@implementation CleanContactInfoTests

- (void)testCleanPhoneNumber {
    
    NSString *cleanedContactInfo = [[SCSContactsManager sharedManager] cleanContactInfo:@"+1(201)200 2011"];
    
    XCTAssertTrue([cleanedContactInfo isEqualToString:@"+12012002011"]);
}

- (void)testCleanEmailAddress {
    
    NSString *cleanedContactInfo = [[SCSContactsManager sharedManager] cleanContactInfo:@" speTRakis@silentcircle.com"];
    
    XCTAssertTrue([cleanedContactInfo isEqualToString:@"spetrakis@silentcircle.com"]);
}

- (void)testCleanSipAddress {
    
    NSString *cleanedContactInfo = [[SCSContactsManager sharedManager] cleanContactInfo:@"sip:steLIos@sip.silentcircle.net"];
    
    XCTAssertTrue([cleanedContactInfo isEqualToString:@"stelios"]);
}


@end
