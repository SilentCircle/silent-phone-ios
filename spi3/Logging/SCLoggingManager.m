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
//  SCLoggingManager.m
//  SPi3
//
//  Created by Eric Turner on 12/30/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "SCLoggingManager.h"
#import "SCLogFileManager.h"
#import "SCLogFormatter.h"
#import "SCFileManager.h"

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif


void setZinaLogLevel(int32_t level);


@implementation SCLoggingManager
{
    DDFileLogger *_fileLogger;
}

/*
 * This method is the first call by AppDelegate didFinishLaunching, to
 * configure lumberjack logging singletons and set up this class with
 * the file logger instance.
 *
 * Note that we call the special SCFileManager setupLogsCache method
 * everytime, to ensure that the logs cache directory exists. Of course,
 * it will only create the directory the first time it is found not to
 * exist, but the file system harmlessly ignores the request if it is
 * found to already exist. 
 *
 * The special setup method for the logs cache is so that the 
 * SCFileManager operations themselves can be logged with these loggers. 
 */
- (void)configureLogging {
    
    [SCFileManager setupLogsCache];
    
    // From CocoaLumberjack compressingLogFileManager demo project
    NSString *logsCachePath = [SCFileManager logsCacheDirectoryURL].relativePath;
    SCLogFileManager *mgr = [[SCLogFileManager alloc] initWithLogsDirectory:logsCachePath];
    
    _fileLogger = [[DDFileLogger alloc] initWithLogFileManager:mgr];
    /* Use these defaults in DDFileLogger:
    kDDDefaultLogMaxFileSize      = 1024 * 1024;      // 1 MB
    kDDDefaultLogRollingFrequency = 60 * 60 * 24;     // 24 Hours
    kDDDefaultLogMaxNumLogFiles   = 5;                // 5 Files
    kDDDefaultLogFilesDiskQuota   = 20 * 1024 * 1024; // 20 MB
     *
     * Increase maxLogFiles from default 5 to 10
     */
    _fileLogger.logFileManager.maximumNumberOfLogFiles = 10; // 10240000 := 10MB total storage
    SCLogFormatter *logfrm = [[SCLogFormatter alloc] initUsingTimestamp];
    _fileLogger.logFormatter = logfrm;
    [DDLog addLogger:_fileLogger withLevel:ddLogLevel];
    
//    [DDLog addLogger:[DDASLLogger sharedInstance] withLevel:DDLogLevelVerbose];
    
    [DDLog addLogger:[DDTTYLogger sharedInstance] withLevel:ddLogLevel];
    [DDTTYLogger sharedInstance].logFormatter = [SCLogFormatter new];
    
    
    setZinaLogLevel(ddLogLevel);
    
    DDLogDebug(@"%s logging initialized", __FUNCTION__);
}

@end
