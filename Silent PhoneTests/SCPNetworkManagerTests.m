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
//  SCPNetworkManagerTests.m
//  SPi3
//
//  Created by Stelios Petrakis on 26/12/2016.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "SCPCallbackInterface.h"

@interface SCPNetworkManagerTests : XCTestCase

@end

@implementation SCPNetworkManagerTests

- (void)testAsyncAPIRequest {
    
    [Switchboard.networkManager apiRequestInEndpoint:SCPNetworkManagerEndpointV1Me
                                              method:SCPNetworkManagerMethodGET
                                           arguments:nil
                                          completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {
         
                                              XCTAssert(httpResponse.statusCode == 200);
                                              
                                          }];
}

- (void)testSyncAPIRequest {
    
    NSError *error = nil;
    NSHTTPURLResponse *httpResponse = nil;
    
    [Switchboard.networkManager synchronousApiRequestInEndpoint:SCPNetworkManagerEndpointV1Me
                                                         method:SCPNetworkManagerMethodGET
                                                      arguments:nil
                                                          error:&error
                                                   httpResponse:&httpResponse];
    
    XCTAssert(httpResponse.statusCode == 200);
}

@end
