/*
Copyright (C) 2014-2017, Silent Circle, LLC.  All rights reserved.

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
// ---LICENSE_BEGIN---
/**
 * Copyright © 2014, Silent Circle
 * All rights reserved.
**/
// ---LICENSE_END---

#import "S3DownloadOperation.h"

#import "SCloudConstants.h"
#import "SCFileManager.h"
#import "SCloudObject.h"
#import "SCPinningObject.h"

static const NSTimeInterval kTimeoutInterval = 5.0;
static const NSTimeInterval kTimeoutIncrement = 5.0; // after 1st time
static const NSInteger kMaxRetries  = 3;

@implementation S3DownloadOperation
{
	BOOL isExecuting;
	BOOL isFinished;
	BOOL isCancelled;
	
	size_t  _bytesRead;
	int64_t  _fileSize;
	
	NSURL           *_tempFileURL;
    NSURLSessionDownloadTask *_downloadTask;
	NSOutputStream  *_stream;
	NSMutableURLRequest    *_request;
	
    NSInteger _statusCode;
    NSString *_statusCodeString;
	
	NSUInteger _retryAttempts;
	NSTimeInterval _timeoutSecs;
}

@synthesize delegate = _delegate;
@synthesize userObject = _userObject;

@synthesize scloud = _scloud;
@synthesize locatorString = _locatorString;


#pragma mark - Class Lifecycle

- (instancetype)initWithDelegate:(id <S3DownloadOperationDelegate>)delegate
                      userObject:(id)userObject
                          scloud:(SCloudObject *)scloud
                   locatorString:(NSString *)locatorString
{
	if ((self = [super init]))
	{
		_delegate = delegate;
        _userObject = userObject;
		
		_scloud = scloud;
        _locatorString = locatorString;
        
        // no locator string indicates top locator
        if(!_locatorString)
            _locatorString = _scloud.locatorString;
        
        _request = [self createRequest];
    }
    return self;
}

- (NSMutableURLRequest*)createRequest {
    
    NSString *urlString = [NSString stringWithFormat:@"https://s3.amazonaws.com/%@/%@",
                           kSilentStorageS3Bucket, _locatorString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:_timeoutSecs];
    
    return request;
}

- (void)startDownload {
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    sessionConfig.timeoutIntervalForRequest = _timeoutSecs;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                          delegate:self
                                                     delegateQueue:nil];
    
    _statusCodeString = nil;
    _statusCode = 0;
    
    _downloadTask = [session downloadTaskWithRequest:_request];
    [_downloadTask resume];
    
    [session finishTasksAndInvalidate];
    
#if VERBOSE
    NSLog( @"STARTING SESSION: %@", _locatorString);
#endif
}

#pragma mark - Overriding NSOperation Methods

- (void)start
{
    if ([self isCancelled])
        return;

    [self willChangeValueForKey:@"isExecuting"];
    isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
 
	_retryAttempts = 0;
	_timeoutSecs = kTimeoutInterval;
	
    if(!_request)
        [self finish];
    else
        [self startDownload];
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

-(BOOL)isCancelled
{
    return isCancelled;
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        
        BOOL serverTrustIsValid = [SCPinningObject evaluateServerTrust:challenge.protectionSpace.serverTrust
                                                           forHostname:challenge.protectionSpace.host];
        
        if(serverTrustIsValid) { // SPKI keys match, continue with other checks
            
            if (completionHandler) {
                
                NSURLCredential*  credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
                
                completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
            }
            
        } else {
            
            if (completionHandler) {
                completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, NULL);
            }
        }
        
    } else if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodClientCertificate]) {
        
        if (completionHandler) {
            completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, NULL);
        }
    }
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    
#if VERBOSE
    NSLog( @"bytesWritten: %lld", bytesWritten);
#endif
    
    if(_fileSize == 0)
    {
        _fileSize = totalBytesExpectedToWrite;
        [self didStart];
    }
    
    [self updateProgress:@((float)totalBytesWritten / (float)totalBytesExpectedToWrite)];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    
    if ([self isCancelled])
        return;
    
    _statusCode = [(NSHTTPURLResponse*)downloadTask.response statusCode];
    
    if(_statusCode == 200) {
        
        _tempFileURL = location;
        
        if( _tempFileURL) {
            
            NSError *error;
            
            BOOL exists = ([_tempFileURL checkResourceIsReachableAndReturnError:&error]
                           && !error
                           && [_tempFileURL isFileURL]);
            
            if(exists) {
                
                NSURL* newURL = [[SCFileManager scloudCacheDirectoryURL] URLByAppendingPathComponent:_locatorString];
                
                [NSFileManager.defaultManager removeItemAtURL:newURL error:NULL];
                [NSFileManager.defaultManager moveItemAtURL:_tempFileURL toURL:newURL error:&error];
            }
        }
        
        [self didComplete:nil];
        
    } else {
        
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        
        if(_statusCode == 403)
        {
            [details setValue: NSLocalizedString(@"SCloud file does not exist, please contact the sender ", @"SCloud file does not exist, please contact the sender")
                       forKey: NSLocalizedDescriptionKey];
        }
        else
        {
            [details setValue:[NSHTTPURLResponse localizedStringForStatusCode:(NSInteger)_statusCode] forKey:NSLocalizedDescriptionKey];
        }
        
        NSError * error = [NSError errorWithDomain:kSCErrorDomain code:NSURLErrorFileDoesNotExist userInfo:details];
        
        if(error && _retryAttempts++ < kMaxRetries)
        {
            _timeoutSecs += kTimeoutIncrement;
            _request.timeoutInterval = _timeoutSecs;
    
    #if VERBOSE
            NSLog( @"SESSION RETRY: %@ (%1.0f s)", _locatorString, _timeoutSecs);
    #endif
            [self startDownload];
            return;
        }
    
        [self didComplete:error];
    }
    
    [self finish];
    
    [session finishTasksAndInvalidate];
}

#pragma mark - Helper Methods

-(void) cancel {
    
    if(_downloadTask)
        [_downloadTask cancel];

    if(_stream)
        [_stream close];
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isCancelled"];
    [self willChangeValueForKey:@"isFinished"];
    
    isCancelled = YES;
    isFinished = YES;
    isExecuting = NO;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isCancelled"];
    [self willChangeValueForKey:@"isFinished"];
}

-(void)finish {
    
     NSError* error = NULL;

    if(_statusCode != 200)
        [NSFileManager.defaultManager removeItemAtURL:_tempFileURL error:&error];
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];

    isExecuting = NO;
    isFinished  = YES;

    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (void)didStart {

    // Delegate is responsible of dispatching to the main thread when necessary!
    if(self.delegate)
        [self.delegate S3DownloadOperation:self
                          downloadDidStart:_locatorString
                                  fileSize:@(_fileSize)
                                statusCode:_statusCode];
}

- (void)updateProgress:(NSNumber *)theProgress {
    
    // Delegate is responsible of dispatching to the main thread when necessary!
    if(self.delegate)
        [self.delegate S3DownloadOperation:self downloadProgress:[theProgress floatValue]];
}

- (void)didComplete:(NSError *)error {
    
    // Delegate is responsible of dispatching to the main thread when necessary!
    if(self.delegate)
        [self.delegate S3DownloadOperation:self downloadDidCompleteWithError:error];
}

@end
