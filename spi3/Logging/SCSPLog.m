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
//  SCSPLog.m
//  SPi3
//
//  Created by Eric Turner on 7/22/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "SCSPLog.h"
#import "NSString+SCUtilities.h"

// Debug levels: off, error, warn, info, debug, verbose, all
static DDLogLevel logLevel = DDLogLevelOff;


@implementation SCSPLog

#pragma mark - Initialization

- (instancetype)initWithLogLevel:(DDLogLevel)lvl {
    self = [super init];
    if (!self) return nil;    
    logLevel = lvl;
    return self;
}


#pragma mark - Logging Methods

// Debug levels: off, error, warn, info, debug, verbose
- (void)logConfig {
    
    DDLogInfo(@"%@\n%@",[self defaultHeader],[self configString]);
    
    [self logEnabledFunctions];
    
    if (!_noLogFooter) {
        DDLogInfo(@"%@", [self defaultFooter]);
    }
}

- (NSString *)configString {
    NSString *str = [NSString stringWithFormat:@"LOG_ASYNC_ENABLED:%d%@",
                     LOG_ASYNC_ENABLED,
                     [NSString stringWithFormat:@"\nddLogLevel           %@", [NSString intToBinary:(int)ddLogLevel delimited:YES]]
                     ];
    return str;
}

- (void)logEnabledFunctions {
    DDLogVerbose(@" DDLogVerbose ");
    DDLogDebug(@" DDLogDebug ");
    DDLogInfo(@" DDLogInfo ");
    DDLogWarn(@" DDLogWarn ");
    DDLogError(@" DDLogError ");    
}


#pragma mark - Header/Footer Methods

- (NSString *)headerFooterStringWithTitle:(NSString *)title {
    NSString *hdr = [NSString stringWithFormat:@"\n%@\n%@\n%@\n",
                     [self logLine],
                     (title)?:@"",
                     [self logLine]
                     ];
    return hdr;
}

- (NSString *)defaultHeader {
    NSString *hdrStr = @""; 
    if (!_noLogHeader) {
        hdrStr = [NSString stringWithFormat:@"%@",[self headerFooterStringWithTitle:@"\t\t\t\t Lumberjack Logging Config"]];
    }
    return hdrStr;
}

- (NSString *)defaultFooter {
    NSString *ftrStr = [self headerFooterStringWithTitle:@"\t\t\t\t END Lumberjack Logging Config"];
    return ftrStr;
}

- (NSString *)logLine {
    return @"------------------------------------------------------------------------";
}

@end
