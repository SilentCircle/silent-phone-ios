/*
Copyright (C) 2016, Silent Circle, LLC.  All rights reserved.

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

#import "S3UploadSession.h"
#import "SCloudConstants.h"
//#import "AppConstants.h"
//#import "AppDelegate.h"
//#import "STLogging.h"

#define VERBOSE 0

#include "../../../../../xml/parse_xml.h"

//#import "NSXMLElement+XMPP.h"



// Log levels: off, error, warn, info, verbose
//#if DEBUG && vinnie_moscaritolo
//  static const int ddLogLevel = LOG_LEVEL_INFO; // | LOG_FLAG_TRACE;
//#elif DEBUG && robbie_hanson
//  static const int ddLogLevel = LOG_LEVEL_WARN; // | LOG_FLAG_TRACE;
//#elif DEBUG
//  static const int ddLogLevel = LOG_LEVEL_WARN;
//#else
//  static const int ddLogLevel = LOG_LEVEL_WARN;
//#endif
//#pragma unused(ddLogLevel)

static const NSTimeInterval kTimeoutInterval = 5.0;
static const NSTimeInterval kTimeoutIncrement = 5.0; // after 1st time
static const NSInteger kMaxRetries = 3;

@implementation S3UploadSession
{
    BOOL isExecuting;
    BOOL isFinished;
    
	NSURL                  * _fileURL;
	NSMutableURLRequest    * _urlRequest;
	NSURLSessionUploadTask * _uploadTask;
	
	NSUInteger _retryAttempts;
	NSTimeInterval _timeoutSecs;
	
	NSInteger statusCode;
	NSString *statusCodeString;
}

@synthesize delegate = _delegate;
@synthesize userObject = _userObject;

@synthesize locatorString = _locatorString;

#pragma mark - Class Lifecycle

- (instancetype)initWithDelegate:(id)delegate
                      userObject:(id)userObject
                   locatorString:(NSString *)locatorString
                         fileURL:(NSURL *)fileURL
                       urlString:(NSString *)urlString
{
	if ((self = [super init]))
	{
		_delegate = delegate;
		_userObject = userObject;
		
		_locatorString = locatorString;
		_fileURL       = fileURL;
		_urlRequest    = [self createRequestWithString:urlString fileURL:fileURL];
	}
	return self;
}

- (NSMutableURLRequest *)createRequestWithString:(NSString *)URLString fileURL:(NSURL*)fileURLIn
{
    NSMutableURLRequest*    request = NULL;
    NSError*                error = NULL;
    
    
    BOOL exists = ([fileURLIn checkResourceIsReachableAndReturnError:&error]
                   && !error
                   && [fileURLIn isFileURL]);
    
    if(exists)
    {
        NSNumber *number = nil;
        NSInteger fileSize = 0;
        
        [fileURLIn getResourceValue:&number forKey:NSURLFileSizeKey error:NULL];
        fileSize = number.integerValue;
        
        request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
        [request setHTTPMethod:@"PUT"];
        [request setValue:kSilentStorageS3Mime forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"public-read" forHTTPHeaderField:@"x-amz-acl"];
        
		NSString *contentLength = [NSString stringWithFormat: @"%lu", (unsigned long)fileSize];
        [request setValue:contentLength forHTTPHeaderField: @"Content-Length"];
        [request setTimeoutInterval: _timeoutSecs];
	}
	
	return request;
}

#pragma mark - Overriding NSOperation Methods

- (void)start
{
    // Makes sure that start method always runs on the main thread.
//    if (![NSThread isMainThread])
//    {
//        [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
//        return;
//    }
    
    [self willChangeValueForKey:@"isExecuting"];
    isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];

	_retryAttempts = 0;
	_timeoutSecs = kTimeoutInterval;
	
	if (!_urlRequest)
	{
		[self finish];
	}
    else
	{
		[self startUpload];
	}
}


- (void)startUpload
{
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	sessionConfig.timeoutIntervalForRequest = _timeoutSecs;
//	sessionConfig.timeoutIntervalForResource = _timeoutSecs;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                          delegate:self
                                                     delegateQueue:nil];
    
    statusCodeString = NULL;
    statusCode = 0;
    
    /* Completion handler blocks are not supported in background sessions. Use a delegate instead */
    
    _uploadTask = [session uploadTaskWithRequest:_urlRequest fromFile:_fileURL];
    
    [_uploadTask resume];
#if VERBOSE
     NSLog( @"STARTING SESSION: %@", _locatorString);
#endif
}

-(BOOL)isConcurrent
{
    return YES;
}

-(BOOL)isExecuting
{
    return isExecuting;
}

-(BOOL)isFinished
{
    return isFinished;
}

#pragma mark - NSURLSession delegate

/* Sent periodically to notify the delegate of upload progress.  This
 * information is also available as properties of the task.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                        didSendBodyData:(int64_t)bytesSent
                        totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
#if VERBOSE
     NSLog( @"totalBytesSent: %lld", bytesSent);
#endif
    [self updateProgress:@(bytesSent)];
//    [self performSelectorOnMainThread:@selector(updateProgress:)
//                           withObject:[NSNumber numberWithUnsignedLongLong:bytesSent ]
//                        waitUntilDone:NO];
    

}

/* AWS uploads can return error status */
// EA: I have not yet seen this called
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
// TODO: test this
    CParseXml xml;
    NODE *rootNode = xml.parseXml((char *)[data bytes], (int)[data length]);
    NODE *statusNode = findNode(rootNode, (char *)"Code", true);
    if (statusNode)
        statusCodeString = [NSString stringWithCString:statusNode->content.s encoding:NSUTF8StringEncoding];
}

- (void)URLSession:(NSURLSession *)session  task:(NSURLSessionTask *)task
                            didCompleteWithError:(NSError *)error
{
    NSError* currentError = nil;
    
    if (error == nil)
    {
        if ([task.response isKindOfClass: [NSHTTPURLResponse class]])
        {
            statusCode = [(NSHTTPURLResponse*) task.response statusCode];
            
            if(statusCode == 200)
            {
#if VERBOSE
                NSLog( @"SESSION COMPLETE: %@", _locatorString);
#endif
            }
            else
            {
#if VERBOSE
                NSLog( @"SESSION ERROR: %@ - %d %@", _locatorString, (int)statusCode, statusCodeString);
#endif
                if( [statusCodeString isEqualToString:@"RequestTimeout"])
                {
                    currentError = [NSError errorWithDomain:@"com.silentcircle.error" code:kSCLError_OtherError userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Upload timeout", @"Upload timeout")}];
//                    currentError = [STAppDelegate otherError: NSLocalizedString(@"Upload timeout", @"Upload timeout")];
                }
             }
        }
    }
    else
    {
        currentError = error;
    }
    
    if(currentError && _retryAttempts++ < kMaxRetries)
    {
		_timeoutSecs += kTimeoutIncrement;
		_urlRequest.timeoutInterval = _timeoutSecs;
		
#if VERBOSE
		NSLog( @"SESSION RETRY: %@ (%1.0f s)", _locatorString, _timeoutSecs);
#endif
        [self uploadRetry:@(_retryAttempts)];
//		[self performSelectorOnMainThread:@selector(uploadRetry:)
//                               withObject:[NSNumber numberWithInteger:_retryAttempts]
//                            waitUntilDone:NO];

        [self startUpload];
        return;
    }

    [self didComplete:currentError];
//    [self performSelectorOnMainThread:@selector(didComplete:) withObject:currentError  waitUntilDone:NO];
    
    [self finish];
    
    [session finishTasksAndInvalidate];
}


- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
#if VERBOSE
    NSLog(@"URLSessionDidFinishEventsForBackgroundURLSession");
#endif
}

#pragma mark - Helper Methods

- (void)finish
{
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    isExecuting = NO;
    isFinished  = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (void)didStart
{
	if (self.delegate)
	{
		[self.delegate S3UploadSession:self uploadDidStart:_locatorString ];
	}
}

-(void)updateProgress:(NSNumber *)bytesWritten
{
    
    if(self.delegate)
    {
        [self.delegate S3UploadSession:self uploadProgress:bytesWritten];
    }
    
    
}

-(void)didComplete:(NSError *)error
{
    
    if(self.delegate)
    {
        [self.delegate S3UploadSession:self uploadDidCompleteWithError:error];
    }
    
}

-(void)uploadRetry:(NSNumber *)numberofTries
{
    
    if(self.delegate)
    {
        [self.delegate S3UploadSession:self uploadRetry:numberofTries];
    }
    
    
}

@end
