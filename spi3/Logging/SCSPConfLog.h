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
//  SCSPConfLog.h
//  SPi3
//
//  Created by Eric Turner on 7/21/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#define LOG_FLAG_CONF_NONE            0        // 0000000000000000
#define LOG_FLAG_CONF_MOVE_DIRECTION (1 << 0)  // 0000000000000001
#define LOG_FLAG_CONF_MOVE_COUNT     (1 << 1)  // 0000000000000010
#define LOG_FLAG_CONF_MOVE_PATHS     (1 << 2)  // 0000000000000100
#define LOG_FLAG_CONF_HEADER_FOOTER  (1 << 3)  // 0000000000001000
#define LOG_FLAG_CONF_NOTIFICATIONS  (1 << 4)  // 0000000000010000
#define LOG_FLAG_CONF_DEFERRED_OP    (1 << 5)  // 0000000000100000
#define LOG_FLAG_CONF_ACCESSIBILITY  (1 << 6)  // 0000000001000000
#define LOG_FLAG_CONF_CELL           (1 << 7)  // 0000000010000000
#define LOG_FLAG_CONF_EVENT          (1 << 8)  // 0000000100000000
// define more here...               (1 << ..)
#define LOG_FLAG_CONF_ALL            DDLogLevelAll

#define DDLogConfMoveDirection(frmt, ...) LOG_MAYBE(LOG_ASYNC_ENABLED, ddLogLevelConf, LOG_FLAG_CONF_MOVE_DIRECTION, 0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define DDLogConfMoveCount(frmt, ...)     LOG_MAYBE(LOG_ASYNC_ENABLED, ddLogLevelConf, LOG_FLAG_CONF_MOVE_COUNT,     0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define DDLogConfMovePaths(frmt, ...)     LOG_MAYBE(LOG_ASYNC_ENABLED, ddLogLevelConf, LOG_FLAG_CONF_MOVE_PATHS,     0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define DDLogConfHeaderFooter(frmt, ...)  LOG_MAYBE(LOG_ASYNC_ENABLED, ddLogLevelConf, LOG_FLAG_CONF_HEADER_FOOTER,  0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define DDLogConfNotifications(frmt, ...) LOG_MAYBE(LOG_ASYNC_ENABLED, ddLogLevelConf, LOG_FLAG_CONF_NOTIFICATIONS,  0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define DDLogConfDeferredOp(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED, ddLogLevelConf, LOG_FLAG_CONF_DEFERRED_OP,    0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define DDLogConfAccessibility(frmt, ...) LOG_MAYBE(LOG_ASYNC_ENABLED, ddLogLevelConf, LOG_FLAG_CONF_ACCESSIBILITY,  0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define DDLogConfCell(frmt, ...)          LOG_MAYBE(LOG_ASYNC_ENABLED, ddLogLevelConf, LOG_FLAG_CONF_CELL,           0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define DDLogConfEvent(frmt, ...)         LOG_MAYBE(LOG_ASYNC_ENABLED, ddLogLevelConf, LOG_FLAG_CONF_EVENT,          0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)


#import "SCSPLog.h"

@interface SCSPConfLog : SCSPLog

@property (nonatomic, assign) DDLogLevel ddLogLevelConf;
@property (nonatomic, assign) DDLogLevel logFlagConf;

@end
