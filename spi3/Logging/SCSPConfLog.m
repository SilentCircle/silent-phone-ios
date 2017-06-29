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
//  SCSPConfLog.m
//  SPi3
//
//  Created by Eric Turner on 7/22/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "SCSPConfLog.h"
#import "NSString+SCUtilities.h"

static DDLogLevel logLevelConf = DDLogLevelOff;
static DDLogLevel ddLogLevelConf = LOG_FLAG_CONF_NONE;


@implementation SCSPConfLog 


#pragma mark - Initialization

- (instancetype)initWithLogLevel:(DDLogLevel)lvl {
    self = [super initWithLogLevel:lvl];
    if (!self) return nil;    
    logLevelConf = lvl;
    _logFlagConf = -1;
    return self;
}


#pragma mark - Setters 

- (void)setDdLogLevelConf:(DDLogLevel)lvlConf {
    _ddLogLevelConf = lvlConf;
    ddLogLevelConf  = lvlConf;
}

- (void)setLogFlagConf:(DDLogLevel)flConf {
    _logFlagConf = flConf;
}


#pragma mark - Logging Methods

- (void)logConfig {

    DDLogInfo(@"%@\n%@",[self defaultHeader],[super configString]);
    [super logEnabledFunctions];
    
    DDLogInfo(@"%@",[self configString]);
    [self logEnabledFunctions];    
    
    if (!self.noLogFooter) {
        DDLogInfo(@"%@", [self defaultFooter]);
    }
}

- (void)logEnabledFunctions {
    DDLogConfMoveDirection(@" DDLogConfMoveDirection ");
    DDLogConfMoveCount(@" DDLogConfMoveCount ");
    DDLogConfMovePaths(@" DDLogConfMovePaths ");
    DDLogConfHeaderFooter(@" DDLogConfHeaderFooter ");
    DDLogConfNotifications(@" DDLogConfNotifications ");
    DDLogConfDeferredOp(@" DDLogConfDeferredOp ");
    DDLogConfAccessibility(@" DDLogConfAccessibility ");
    DDLogConfCell(@" DDLogConfCell ");
    DDLogConfEvent(@" DDLogConfEvent %@", @"\n");
}

- (NSString *)configString {
    NSString *flConf = @""; 
    flConf = [NSString stringWithFormat:@"\nLOG_FLAG_CONF               %@",   [NSString intToBinary:(int)_logFlagConf delimited:YES]];
    return [NSString stringWithFormat:@"%@%@%@%@%@%@%@%@%@%@%@%@%@",
            [NSString stringWithFormat:@"\nLOG_FLAG_CONF_NONE           %@",   [NSString intToBinary:(int)LOG_FLAG_CONF_NONE           delimited:YES]],
            [NSString stringWithFormat:@"\nLOG_FLAG_CONF_MOVE_DIRECTION %@",   [NSString intToBinary:(int)LOG_FLAG_CONF_MOVE_DIRECTION delimited:YES]],
            [NSString stringWithFormat:@"\nLOG_FLAG_CONF_MOVE_COUNT     %@",   [NSString intToBinary:(int)LOG_FLAG_CONF_MOVE_COUNT     delimited:YES]],
            [NSString stringWithFormat:@"\nLOG_FLAG_CONF_MOVE_PATHS     %@",   [NSString intToBinary:(int)LOG_FLAG_CONF_MOVE_PATHS     delimited:YES]],
            [NSString stringWithFormat:@"\nLOG_FLAG_CONF_HEADER_FOOTER  %@",   [NSString intToBinary:(int)LOG_FLAG_CONF_HEADER_FOOTER  delimited:YES]],
            [NSString stringWithFormat:@"\nLOG_FLAG_CONF_NOTIFICATIONS  %@",   [NSString intToBinary:(int)LOG_FLAG_CONF_NOTIFICATIONS  delimited:YES]],
            [NSString stringWithFormat:@"\nLOG_FLAG_CONF_DEFERRED_OP    %@",   [NSString intToBinary:(int)LOG_FLAG_CONF_DEFERRED_OP    delimited:YES]],
            [NSString stringWithFormat:@"\nLOG_FLAG_CONF_ACCESSIBILITY  %@",   [NSString intToBinary:(int)LOG_FLAG_CONF_ACCESSIBILITY  delimited:YES]],
            [NSString stringWithFormat:@"\nLOG_FLAG_CONF_CELL           %@",   [NSString intToBinary:(int)LOG_FLAG_CONF_CELL           delimited:YES]],
            [NSString stringWithFormat:@"\nLOG_FLAG_CONF_EVENT          %@",   [NSString intToBinary:(int)LOG_FLAG_CONF_EVENT          delimited:YES]],
            flConf,
            [NSString stringWithFormat:@"\nddLogLevelConf               %@",   [NSString intToBinary:(int)ddLogLevelConf               delimited:YES]],
            @"\nEnabled logging functions:"
            ];
}


#pragma mark - Header/Footer Methods

- (NSString *)defaultHeader {
    NSString *hdrStr = @""; 
    if (!self.noLogHeader) {
        hdrStr = [NSString stringWithFormat:@"%@",[self headerFooterStringWithTitle:@"\t\t\t\t Conference Logging Config"]];
    }
    return hdrStr;
}

- (NSString *)defaultFooter {
    NSString *ftrStr = [self headerFooterStringWithTitle:@"\t\t\t\t END Conference Logging Config"];
    return ftrStr;
}

@end
