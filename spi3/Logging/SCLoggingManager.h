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
//  SCLoggingManager.h
//  SPi3
//
//  Created by Eric Turner on 12/30/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//
// Custom logging contexts
// ref: https://github.com/CocoaLumberjack/CocoaLumberjack/blob/master/Documentation/CustomContext.md

#import "SCSPLog.h"

//-----------------------------------------------------------------------------------------------------------------------------
#pragma mark - SPI HTTP
// SPI HTTP LOGGING CONTEXTS
#define HTTP_LOG_CONTEXT    10

#define HTTPLogError(frmt, ...)    LOG_MAYBE(NO,                  LOG_LEVEL_DEF, DDLogFlagError,   HTTP_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define HTTPLogWarn(frmt, ...)  LOG_MAYBE(NO,                     LOG_LEVEL_DEF, DDLogFlagWarning, HTTP_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define HTTPLogInfo(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED,    LOG_LEVEL_DEF, DDLogFlagInfo,    HTTP_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define HTTPLogDebug(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED,   LOG_LEVEL_DEF, DDLogFlagDebug,   HTTP_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define HTTPLogVerbose(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagVerbose, HTTP_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)

//-----------------------------------------------------------------------------------------------------------------------------
#pragma mark - SPI CALLKIT
// SPI CALLKIT LOGGING CONTEXTS
#define CALLKIT_LOG_CONTEXT 20

#define CallKitLogError(frmt, ...) LOG_MAYBE(NO,                     LOG_LEVEL_DEF, DDLogFlagError,   CALLKIT_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define CallKitLogWarn(frmt, ...)  LOG_MAYBE(LOG_ASYNC_ENABLED,      LOG_LEVEL_DEF, DDLogFlagWarning, CALLKIT_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define CallKitLogInfo(frmt, ...)  LOG_MAYBE(LOG_ASYNC_ENABLED,      LOG_LEVEL_DEF, DDLogFlagInfo,    CALLKIT_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define CallKitLogDebug(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED,   LOG_LEVEL_DEF, DDLogFlagDebug,   CALLKIT_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define CallKitLogVerbose(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagVerbose, CALLKIT_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
//-----------------------------------------------------------------------------------------------------------------------------

//-----------------------------------------------------------------------------------------------------------------------------
#pragma mark - SPI AUDIO
// SPI AUDIO LOGGING CONTEXTS
#define AUDIO_LOG_CONTEXT   30

#define AudioLogError(frmt, ...)   LOG_MAYBE(NO,                   LOG_LEVEL_DEF, DDLogFlagError,   AUDIO_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define AudioLogWarn(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED,    LOG_LEVEL_DEF, DDLogFlagWarning, AUDIO_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define AudioLogInfo(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED,    LOG_LEVEL_DEF, DDLogFlagInfo,    AUDIO_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define AudioLogDebug(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED,   LOG_LEVEL_DEF, DDLogFlagDebug,   AUDIO_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
#define AudioLogVerbose(frmt, ...)    LOG_MAYBE(LOG_ASYNC_ENABLED, LOG_LEVEL_DEF, DDLogFlagVerbose, AUDIO_LOG_CONTEXT, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)
//-----------------------------------------------------------------------------------------------------------------------------


#pragma mark -
// The __FILE__ macro returns the whole path; this returns just the file name.
#define __THIS_FILE__ [[NSString stringWithUTF8String:__FILE__] lastPathComponent]


@interface SCLoggingManager : NSObject

- (void)configureLogging;

@end
