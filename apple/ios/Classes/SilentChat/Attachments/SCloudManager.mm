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

#import "SCloudManager.h"
#import "SCloudConstants.h"
//#import "SCWebAPIManager.h"
#import "SCloudObject.h"
#import "SCFileManager.h"
#import "Utilities.h"
#import "Reachability.h"

// Categories
#import "NSDate+SCDate.h"
#import "NSMutableArray+Shuffling.h"

NSString *const NOTIFICATION_SCLOUD_OPERATION         = @"scloudOperation";

NSString *const NOTIFICATION_SCLOUD_BROKER_REQUEST    = @"scloudOperation:brokerRequestStart";
NSString *const NOTIFICATION_SCLOUD_BROKER_COMPLETE   = @"scloudOperation:brokerRequestComplete";

NSString *const NOTIFICATION_SCLOUD_UPLOAD_PROGRESS   = @"scloudOperation:uploadProgress";
NSString *const NOTIFICATION_SCLOUD_UPLOAD_RETRY      = @"scloudOperation:uploadRetry";
NSString *const NOTIFICATION_SCLOUD_UPLOAD_COMPLETE   = @"scloudOperation:uploadComplete";
NSString *const NOTIFICATION_SCLOUD_UPLOAD_FAILED     = @"scloudOperation:uploadFailed";

NSString *const NOTIFICATION_SCLOUD_VERIFY_PROGRESS = @"scloudOperation:verifyProgress";

NSString *const NOTIFICATION_SCLOUD_DOWNLOAD_START    = @"scloudOperation:downloadStart";
NSString *const NOTIFICATION_SCLOUD_DOWNLOAD_PROGRESS = @"scloudOperation:downloadProgress";
NSString *const NOTIFICATION_SCLOUD_DOWNLOAD_COMPLETE = @"scloudOperation:downloadComplete";

NSString *const NOTIFICATION_SCLOUD_ENCRYPT_START     = @"scloudOperation:encryptStart";
NSString *const NOTIFICATION_SCLOUD_ENCRYPT_PROGRESS  = @"scloudOperation:encryptProgress";
NSString *const NOTIFICATION_SCLOUD_ENCRYPT_COMPLETE  = @"scloudOperation:encryptComplete";

NSString *const NOTIFICATION_SCLOUD_GPS_START         = @"scloudOperation:gpsStart";
NSString *const NOTIFICATION_SCLOUD_GPS_COMPLETE      = @"scloudOperation:gpsComplete";

typedef enum {
    kSCBrokerOperation_Delete,
    kSCBrokerOperation_Upload,
	
} SCBrokerOperation;

const NSString * kInfoKey_identifier = @"identifier";
const NSString * kInfoKey_status = @"status";
#define kInfoKey_error          @"error"
#define kInfoKey_fullDownload   @"fullDownload"
const NSString * kInfoKey_progress = @"progress";
#define kInfoKey_retry          @"retry"
#define kInfoKey_locatorString  @"locatorString"
#define kInfoKey_keyString      @"keyString"
#define kInfoKey_fyeo           @"fyeo"
#define kInfoKey_completion     @"completion"

static NSString *OperationsChangedContext = @"Scloud_OperationsChangedContext";

@implementation SCloudManager
{
	NSMutableDictionary *statusDict;
	dispatch_queue_t statusDictQueue;
	
	NSOperationQueue *opQueue;
}

static SCloudManager *sharedInstance = nil;

+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
//        SCCrypto_Init(); // EA: putting this here as opposed to AppDelegate

		initialized = YES;
		sharedInstance = [[SCloudManager alloc] init];
  	}
}

+ (SCloudManager *)sharedInstance
{
	return sharedInstance;
}

- (instancetype)init
{
	NSAssert(sharedInstance == nil, @"Must use sharedInstance");
	
	if ((self = [super init]))
	{
		statusDict = [[NSMutableDictionary alloc] init];
		statusDictQueue = dispatch_queue_create("statusDict", DISPATCH_QUEUE_SERIAL);
		
		opQueue = [[NSOperationQueue alloc] init];
		[opQueue setMaxConcurrentOperationCount:8];
		[opQueue setSuspended:NO];
	}
	return self;
}

- (NSDictionary *)createBrokerRequest:(NSString *)apiKey
                                         locators:(NSArray *)locators
                                        operation:(SCBrokerOperation)operation
                                        shredDate:(NSDate *)shredDate
                                       totalBytes:(size_t *)totalBytesPtr
{
	NSMutableDictionary *brokerReqDict = [NSMutableDictionary dictionaryWithCapacity:4];
	size_t totalBytes = 0;
	
    [brokerReqDict setObject:apiKey forKey:@"api_key"];
    
	if (operation == kSCBrokerOperation_Upload)	{
		[brokerReqDict setObject:@"upload" forKey:@"operation"];
		[brokerReqDict setObject:@(3600) forKey:@"timeout"];
	}
	else if(operation == kSCBrokerOperation_Delete)	{
		[brokerReqDict setObject:@"delete" forKey:@"operation"];
	}
	
	NSString *shredDateString = shredDate ? [shredDate rfc3339String] : nil;
	
    NSMutableDictionary* fileDict = [NSMutableDictionary dictionaryWithCapacity:locators.count];
    for(NSString* locator in locators){
        NSMutableDictionary* itemDict = [NSMutableDictionary dictionary];
        NSURL* url = [[SCFileManager scloudCacheDirectoryURL] URLByAppendingPathComponent:locator];
        
        NSError*  error = NULL;
        BOOL exists = ([url checkResourceIsReachableAndReturnError:&error]
                       && !error
                       && [url isFileURL]);

        if (exists) {
            NSNumber* fileSize =  0;
            [url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalBytes += [fileSize unsignedLongValue];
            
            [itemDict setObject:fileSize forKey:@"size"];
            
			if (shredDateString)
				[itemDict setObject:shredDateString forKey:@"shred_date"];
            
            [fileDict setObject:itemDict forKey:locator];
        }
    }
	
	if (fileDict.count > 0)
		[brokerReqDict setObject:fileDict forKey:@"files"];
	
	if (totalBytesPtr) *totalBytesPtr = totalBytes;
    return brokerReqDict;
}

#pragma mark Status

/**
 * Public API.
 *
 * This method is thread-safe.
**/
- (NSDictionary *)statusForIdentfier:(id)identifier
{
	__block NSDictionary *result = nil;
	dispatch_sync(statusDictQueue, ^{
		
		result = [statusDict objectForKey:identifier];
	});
	
	return result;
}

- (void)updateStatusDictAndPostSCloudNotificationWithInfo:(NSDictionary *)info
{
//	NSAssert([info objectForKey:kInfoKey_identifier], @"info dict missing required key: %@", kInfoKey_identifier);
//	NSAssert([info objectForKey:kInfoKey_status],     @"info dict missing required key: %@", kInfoKey_status);
	
	id identifier = [info objectForKey:kInfoKey_identifier];
	
	// First update the statusDict
	
	dispatch_async(statusDictQueue, ^{
		
		[statusDict setObject:info forKey:identifier];
	});
	
	// Then post the notification.
	//
	// We ALWAYS do this asynchronously.
	// This is because notifications are not expected to hit the client during an invocation of our method.
	//
	// In other words,
	// - user invokes startDownloadWithSCloud:::
	// - gets a notification BEFORE the startDownloadWithSCloud::: method returns !!! <-- BAD code
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SCLOUD_OPERATION
		                                                    object:nil
		                                                  userInfo:info];
	});
	
	// Todo: Ensure this is the correct procedure for removing items from statusDict.
	//       To properly answer this question, we need state machine info.
	
	NSString *status = [info objectForKey:kInfoKey_status];
	
	BOOL shouldRemoveFromStatusDict =
	  [status isEqualToString:NOTIFICATION_SCLOUD_UPLOAD_COMPLETE]   ||
	  [status isEqualToString:NOTIFICATION_SCLOUD_UPLOAD_FAILED]     ||
	  [status isEqualToString:NOTIFICATION_SCLOUD_DOWNLOAD_COMPLETE]  ;
	
	if (shouldRemoveFromStatusDict)
	{
		NSTimeInterval delayInSeconds = 10.0;
		dispatch_time_t after = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
		
		dispatch_after(after, statusDictQueue, ^{
			
			[statusDict removeObjectForKey:identifier];
		});
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark GPS
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * What does this method do ?
**/
- (void)startGPSwithIdentfier:(id)identifier
{
	NSDictionary *info = @{
	  kInfoKey_identifier : identifier,
	  kInfoKey_status     : NOTIFICATION_SCLOUD_GPS_START
	};
    
	[self updateStatusDictAndPostSCloudNotificationWithInfo:info];
}

/**
 * What does this method do ?
**/
- (void)stopGPSwithIdentfier:(id)identifier
{
	NSDictionary *info = @{
	  kInfoKey_identifier : identifier,
	  kInfoKey_status     : NOTIFICATION_SCLOUD_GPS_COMPLETE
	};
	
	[self updateStatusDictAndPostSCloudNotificationWithInfo:info];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Upload
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
extern const char *getCurrentProvSrv();

- (void)uploadSCloud:(SCloudObject *)scloud
           messageID:(NSString *)messageID
           burnDelay:(NSUInteger)burnDelay
     completionBlock:(SCloudManagerCompletionBlock)completionBlock {
    // TODO: abort this operation if the message has already been deleted or burned by the user
//	dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//	dispatch_async(backgroundQueue, ^{
		// NOTE: this method should run in the background because it uses a synchronous url request
		NSString *apiKey = [[Utilities utilitiesInstance] getAPIKey];
		NSString *identifier = messageID;
		
		NSError *error = nil;
		NSArray *segments = [SCloudObject segmentsFromLocatorString:scloud.locatorString
														  keyString:scloud.keyString
														  withError:&error];
		if (error) {
			NSLog(@"Error getting segments from scloud: %@", error);
			if (completionBlock)
				completionBlock(error, nil);
			return;
		}
		
		NSDate *shredDate = (burnDelay == kShredAfterNever) ? nil : [NSDate.date dateByAddingTimeInterval:burnDelay];
		
		size_t totalBytes = 0;
		NSDictionary *brokerReqDict = [self createBrokerRequest:apiKey
													   locators:segments
													  operation:kSCBrokerOperation_Upload
													  shredDate:shredDate
													 totalBytes:&totalBytes];
		NSData *requestData = (brokerReqDict && [NSJSONSerialization isValidJSONObject:brokerReqDict]) ?
				[NSJSONSerialization dataWithJSONObject:brokerReqDict options:0 error:&error] : nil;
		if (error) {
			NSLog(@"Error converting post data to JSON: %@", error);
			if (completionBlock)
				completionBlock(error, nil);
			return;
		}

		// first, hit the broker server to get the list of segment locators
		// e.g. https://sccps.silentcircle.com/broker/
		const char *baseURL_p = getCurrentProvSrv();
		NSString *brokerS = [[NSString alloc] initWithBytes:baseURL_p length:strlen(baseURL_p) encoding:NSUTF8StringEncoding];
		NSURL *brokerURL = [[NSURL URLWithString:brokerS] URLByAppendingPathComponent:@"broker/"];
		
		NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:brokerURL
															   cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
														   timeoutInterval:5.0];
		
		[request setHTTPMethod:@"POST"];
		[request setHTTPBody:requestData];
		
	//	[request setValue:@"TiVi-Phone" forHTTPHeaderField:@"User-Agent"];
		[request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
		[request setValue:[NSString stringWithFormat:@"%ld", (unsigned long)[requestData length]] forHTTPHeaderField:@"Content-Length"];
		
		NSHTTPURLResponse* response = nil;
		const int kMaxRetries = 3;
		const NSTimeInterval kRetryIncrement = 5;
		int retryCount = 0;
		NSData *responseData = nil;
		while (retryCount++ < kMaxRetries) {
			responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
			// check for timeout and retry
			if ((error) && (error.code == NSURLErrorTimedOut)) {
				if (retryCount < kMaxRetries) {
					request.timeoutInterval = request.timeoutInterval+kRetryIncrement;
					error = nil;
					continue;
				}
			}
			break;
		}

		if (error) {
			NSLog(@"Error sending broker request: %@", error);
			if (completionBlock)
				completionBlock(error, nil);
			return;
		}
		if (response.statusCode != 200) {
			// something went wrong
			error = [NSError errorWithDomain:kSCErrorDomain code:NSURLErrorCannotConnectToHost userInfo:@{NSLocalizedDescriptionKey:@"Access Denied by Broker server"}];
			NSLog(@"Error sending broker request: %@", error);
			if (completionBlock)
				completionBlock(error, nil);
			return;
		}
		
		// TODO: trap special error response "You are not authorized to use that locator\n"
		
		// analyze response
		NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&error];
		if (error) {
			NSLog(@"Can't parse broker server response as JSON: %@", error);
			if (completionBlock)
				completionBlock(error, nil);
			return;
		}

		// check for a server error
		NSString *error_msg = [responseDict objectForKey:@"error_msg"];
		if (error_msg) {
			NSMutableDictionary *details = [NSMutableDictionary dictionaryWithCapacity:1];
			details[NSLocalizedDescriptionKey] = error_msg;
			error = [NSError errorWithDomain:kSCErrorDomain code:NSURLErrorCannotConnectToHost userInfo:details];
			NSLog(@"Broker server Error response: %@", error);
			if (completionBlock)
				completionBlock(error, nil);
			return;
		}

		NSMutableArray *brokerSegments = [[responseDict allKeys] mutableCopy];
		[brokerSegments shuffle];
		
		// since we spawn off so many tasks we use the master op to track when they are done
		NSMutableDictionary *opInfo = [NSMutableDictionary dictionaryWithObject:identifier forKey:kInfoKey_identifier];
		if (completionBlock) {
			// register our completionBlock with masterOp
			[opInfo setObject:completionBlock forKey:kInfoKey_completion];
		}
		AsyncSCloudOp *masterOp = [[AsyncSCloudOp alloc] initWithDelegate:self
								   userObject:opInfo
									   scloud:scloud
						 bytesExpectedToWrite:totalBytes];

		[opQueue setSuspended:YES];
	
		__block BOOL bFirstTime = YES;
		[brokerSegments enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop){
			NSString *locatorString = obj;
			NSDictionary *item = [responseDict objectForKey:locatorString];
			NSString *signedURL = [item objectForKey:@"url"];

            //if (bFirstTime) {
            //    // optimization for wifi. check the network type and for wifi connections you
            //    // can run a few more Concurrent Operations for uploads..
            //    NSString *hostName = [[NSURL URLWithString:signedURL] host];
            //    Reachability *reachability = ([hostName length] > 0) ? [Reachability reachabilityWithHostName:hostName] : [Reachability reachabilityForInternetConnection];
            //    NetworkStatus networkStatus = [reachability currentReachabilityStatus];
            //    if (networkStatus == ReachableViaWiFi)
            //        [opQueue setMaxConcurrentOperationCount:8];
            //    else
            //        [opQueue setMaxConcurrentOperationCount:2]; // WWAN
            //    bFirstTime = NO; // we only need to check reachability once
            //}
			
            // Always set the concurrency to 1 regardless of network status
            [opQueue setMaxConcurrentOperationCount:1];
            
			NSURL *fileURL = [[SCFileManager scloudCacheDirectoryURL] URLByAppendingPathComponent:locatorString];
			
			S3UploadSession *uploaderOp = [[S3UploadSession alloc] initWithDelegate:self
								 userObject:masterOp
							  locatorString:locatorString
									fileURL:fileURL
								  urlString:signedURL];
			[masterOp addDependency:uploaderOp];
			[opQueue addOperation:uploaderOp];
		}];
		
		[opQueue addOperation:masterOp];
		[opQueue setSuspended:NO];
// don't call completion block here, masterOp will do it when it completes
//		if (completionBlock) {
//			completionBlock(error, NULL);
//		}
//	}); // dispatch_async
}

- (void)verifySCloudUpload:(SCloudObject *)scloud
				messageID:(NSString *)messageID
		   completionBlock:(SCloudManagerCompletionBlock)completionBlock
{
	dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(backgroundQueue, ^{
		NSMutableArray *segmentsMissing = [NSMutableArray arrayWithCapacity:[scloud.segmentList count]];
		
		[self updateStatusDictAndPostSCloudNotificationWithInfo:@{
						 kInfoKey_identifier: messageID
						 ,kInfoKey_status: NOTIFICATION_SCLOUD_VERIFY_PROGRESS
						 ,kInfoKey_progress: @0.0}];

		NSInteger idx = 0;
		NSInteger totalSegments = [scloud.segmentList count];
		for (NSArray *segmentParts in scloud.segmentList) {
			NSError *error = nil;
			
			if ([segmentParts count] != 3) {
				NSLog(@"Warning: segment does not contain all info!");
				continue;
			}
			NSString *locatorS = [segmentParts objectAtIndex:1];
			BOOL bExists = [scloud verifyS3Synchronous:locatorS error:&error];
			if (!bExists)
				[segmentsMissing addObject:locatorS];

			idx++;
			float progress = (float)idx/(float)totalSegments;
			[self updateStatusDictAndPostSCloudNotificationWithInfo:@{
					  kInfoKey_identifier: messageID
					  ,kInfoKey_status: NOTIFICATION_SCLOUD_VERIFY_PROGRESS
					  ,kInfoKey_progress: [NSNumber numberWithFloat:progress]}];
		}
		
		[self updateStatusDictAndPostSCloudNotificationWithInfo:@{
					  kInfoKey_identifier: messageID
					  ,kInfoKey_status: NOTIFICATION_SCLOUD_VERIFY_PROGRESS
					  ,kInfoKey_progress: @1.0}];

		if ([segmentsMissing count] == 0) {
			// all segments found, nothing left to upload
			if (completionBlock) {
				completionBlock(nil, nil);
			}
			return;
		}
		
		if (completionBlock)
			completionBlock(nil, @{@"missing": segmentsMissing});
	});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Download
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)downloadSCloudTOC:(SCloudObject *)scloud
                     identifier:(id)identifier
                completionBlock:(SCloudManagerCompletionBlock)completionBlock
{
	NSDictionary *downloadInfo = @{
	  kInfoKey_identifier   : identifier,
	  kInfoKey_status       : NOTIFICATION_SCLOUD_DOWNLOAD_START,
	  kInfoKey_fullDownload : @(NO),
	};
	
	[self updateStatusDictAndPostSCloudNotificationWithInfo:downloadInfo];
	
	NSMutableDictionary *opInfo = [NSMutableDictionary dictionaryWithDictionary:@{
		  kInfoKey_identifier    : identifier,
		  kInfoKey_locatorString : scloud.locatorString,
		  kInfoKey_keyString     : scloud.keyString,
		  kInfoKey_fyeo          : @(scloud.fyeo),
		  kInfoKey_fullDownload  : @(NO)
		}];
	if (completionBlock)
		[opInfo setObject:completionBlock forKey:kInfoKey_completion];
	
	NSString *opLocatorString = scloud.locatorString;
	S3DownloadOperation *operation = [[S3DownloadOperation alloc] initWithDelegate:self
	                                                                    userObject:opInfo
	                                                                        scloud:scloud
	                                                                 locatorString:opLocatorString];
#if HAS_DD_LOG
	DDLogRed(@"operations count: %lu", (unsigned long)opQueue.operationCount);
#endif
	[opQueue addOperation:operation];
}

- (void)downloadSCloudFull:(SCloudObject *)scloud identifier:(id)identifier completionBlock:(SCloudManagerCompletionBlock)completion {
	if ([scloud.segmentList count] == 0)
		return; // nothing to download?
	
	NSURL *baseURL = [SCFileManager scloudCacheDirectoryURL];
	
	// check for already downloaded segments, don't re-download those
	NSMutableArray *segmentsToDownload = [NSMutableArray arrayWithCapacity:[scloud.segmentList count]];
	for (NSArray *segmentParts in scloud.segmentList) {
		NSError *error = nil;
		
		if ([segmentParts count] != 3) {
			NSLog(@"Warning: segment does not contain all info!");
			continue;
		}
//		NSNumber *idxN = [segmentParts objectAtIndex:0];
		NSString *locatorS = [segmentParts objectAtIndex:1];
//		NSString *keyS = [segmentParts objectAtIndex:2];
		
		NSURL *segmentURL = [baseURL URLByAppendingPathComponent:locatorS isDirectory:NO];
		BOOL bExists = ( ([segmentURL checkResourceIsReachableAndReturnError:&error]) && (!error) && ([segmentURL isFileURL]) );
		if (!bExists)
			[segmentsToDownload addObject:locatorS];
	}
	
	if ([segmentsToDownload count] == 0) {
		// all segments found, nothing left to download
		if (completion) {
			completion(nil, nil);
		}
		return;
	}
	[segmentsToDownload shuffle];
	
	NSMutableDictionary *opInfo = [NSMutableDictionary dictionaryWithDictionary:@{
					  kInfoKey_identifier    : identifier,
//					  kInfoKey_locatorString : scloud.locatorString,
//					  kInfoKey_keyString     : scloud.keyString,
//					  kInfoKey_fyeo          : @(scloud.fyeo),
					  kInfoKey_fullDownload  : @(YES)
					  }];
	if (completion)
		[opInfo setObject:completion forKey:kInfoKey_completion];

	AsyncSCloudOp *masterOp = [[AsyncSCloudOp alloc] initWithDelegate:self
														   userObject:opInfo
															   scloud:scloud
											   segmentsExpectedToRead:[segmentsToDownload count]];
	
	[segmentsToDownload enumerateObjectsWithOptions:NSEnumerationConcurrent
							   usingBlock:^(id obj, NSUInteger idx, BOOL *stop)
		{
			__unsafe_unretained NSString *locatorString = obj;
			
			S3DownloadOperation *downloadOp = [[S3DownloadOperation alloc] initWithDelegate:self
											   userObject:masterOp
												   scloud:nil
											locatorString:locatorString];
			
			[masterOp addDependency:downloadOp];
			[opQueue addOperation:downloadOp];
		}];
	
	[opQueue addOperation:masterOp];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark S3UploadSessionDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)S3UploadSession:(S3UploadSession *)sender uploadDidStart:(NSString *)locatorString
{
#if HAS_DD_LOG
	DDLogTrace(@"%@ %@", THIS_METHOD, locatorString);
#endif
}

- (void)S3UploadSession:(S3UploadSession *)sender uploadProgress:(NSNumber *)bytesWritten
{
#if HAS_DD_LOG
    DDLogAutoTrace();
#endif
	
	if ([sender.userObject respondsToSelector:@selector(updateProgress:)])
	{
		[sender.userObject updateProgress:bytesWritten];
	}
}

- (void)S3UploadSession:(S3UploadSession *)sender uploadDidCompleteWithError:(NSError *)error
{
#if HAS_DD_LOG
	DDLogTrace(@"%@ %@", THIS_METHOD, sender.locatorString);
#endif
	if ([sender.userObject respondsToSelector:@selector(didCompleteWithError:locatorString:)])
	{
		[sender.userObject didCompleteWithError:error locatorString:sender.locatorString];
	}
}

- (void)S3UploadSession:(S3UploadSession *)sender uploadRetry:(NSNumber*) attempt
{
#if HAS_DD_LOG
	DDLogTrace(@"%@ %@", THIS_METHOD, sender.locatorString);
#endif
	if ([sender.userObject respondsToSelector:@selector(reportRetry:)])
	{
		[sender.userObject reportRetry:attempt];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AsyncSCloudOp
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)AsyncSCloudOp:(AsyncSCloudOp *)sender opDidCompleteWithError:(NSError *)error
{
#if HAS_DD_LOG
	DDLogTrace(@"%@ - message= %@", THIS_METHOD, sender.userObject);
#endif
	NSDictionary *opInfo = sender.userObject;
	id identifier = [opInfo objectForKey:kInfoKey_identifier];
	
	void (^completionBlock)(NSError *error, NSDictionary *infoDict) = [opInfo objectForKey:kInfoKey_completion];
    
	NSDictionary *info = nil;
	if (sender.uploading)
	{
		info = @{
		  kInfoKey_identifier : identifier,
		  kInfoKey_status     : NOTIFICATION_SCLOUD_UPLOAD_COMPLETE
		};
	}
	else
	{
		info = @{
		  kInfoKey_identifier : identifier,
		  kInfoKey_status     : NOTIFICATION_SCLOUD_DOWNLOAD_COMPLETE
		};
	}
	
	[self updateStatusDictAndPostSCloudNotificationWithInfo:info];
	
	if (completionBlock) {
		completionBlock(error, info);
	}
}

- (void)AsyncSCloudOp:(AsyncSCloudOp *)sender uploadProgress:(float)progress
{
#if HAS_DD_LOG
	DDLogTrace(@"%@ %f for message %@", THIS_METHOD, progress, sender.userObject);
#endif
	NSDictionary *opInfo = sender.userObject;
	id identifier = [opInfo objectForKey:kInfoKey_identifier];
	
	NSDictionary *uploadInfo = @{
	  kInfoKey_identifier : identifier,
	  kInfoKey_status     : NOTIFICATION_SCLOUD_UPLOAD_PROGRESS,
	  kInfoKey_progress   : @(progress)
	};
	
	[self updateStatusDictAndPostSCloudNotificationWithInfo:uploadInfo];
}


- (void)AsyncSCloudOp:(AsyncSCloudOp *)sender uploadRetry:(NSNumber*) attempt
{
#if HAS_DD_LOG
	DDLogTrace(@"%@ %@ for message %@", THIS_METHOD, attempt, sender.userObject);
#endif
	NSDictionary *opInfo = sender.userObject;
	id identifier = [opInfo objectForKey:kInfoKey_identifier];
	
	NSDictionary *uploadInfo = @{
	  kInfoKey_identifier : identifier,
	  kInfoKey_status     : NOTIFICATION_SCLOUD_UPLOAD_RETRY,
	  kInfoKey_retry      : attempt
	};
	
	[self updateStatusDictAndPostSCloudNotificationWithInfo:uploadInfo];
}


- (void)AsyncSCloudOp:(AsyncSCloudOp *)sender downloadProgress:(float) progress
{
#if HAS_DD_LOG
	DDLogTrace(@"%@ %f for message %@", THIS_METHOD, progress, sender.userObject);
#endif
	// EA: note this implies caller *must* provide a userObject with kInfoKey_identifier or CRASH
	NSDictionary *opInfo = sender.userObject;
	id identifier = [opInfo objectForKey:kInfoKey_identifier];
	
	NSDictionary *downloadInfo = @{
	  kInfoKey_identifier : identifier,
	  kInfoKey_status     : NOTIFICATION_SCLOUD_DOWNLOAD_PROGRESS,
	  kInfoKey_progress   : @(progress)
	};
	
	[self updateStatusDictAndPostSCloudNotificationWithInfo:downloadInfo];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark S3DownloadOperationDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)S3DownloadOperation:(S3DownloadOperation *)sender
           downloadDidStart:(NSString *)locator
                   fileSize:(NSNumber *)fileSize
                 statusCode:(NSInteger)statusCode
{
#if HAS_DD_LOG
	DDLogTrace(@"%@ - locator= %@", THIS_METHOD, locator);
#endif
}

- (void)S3DownloadOperation:(S3DownloadOperation *)sender downloadProgress:(float)progress
{
#if HAS_DD_LOG
    DDLogAutoTrace();
#endif
}

- (void)S3DownloadOperation:(S3DownloadOperation *)sender downloadDidCompleteWithError:(NSError *)error
{
	if (sender.scloud == nil)
	{
		if ([sender.userObject respondsToSelector:@selector(segmentDownloadWithError:)])
		{
			[sender.userObject segmentDownloadWithError:error];
		}
		
		return;
	}
	
	NSDictionary *opInfo = sender.userObject;
	id identifier = [opInfo objectForKey:kInfoKey_identifier];
	
	BOOL fullDownload = [[opInfo objectForKey:kInfoKey_fullDownload] boolValue];
	
	void (^completionBlock)(NSError *error, NSDictionary *infoDict) = [opInfo objectForKey:kInfoKey_completion];
	
	if (error)
	{
		NSDictionary *downloadInfo = @{
		  kInfoKey_identifier   : identifier,
		  kInfoKey_status       : NOTIFICATION_SCLOUD_DOWNLOAD_COMPLETE,
		  kInfoKey_fullDownload : @(fullDownload)
		};
		
		[self updateStatusDictAndPostSCloudNotificationWithInfo:downloadInfo];
		
        if (completionBlock) {
			completionBlock(error, downloadInfo);
		}
		
    }
    else if(!fullDownload)
    {
		NSDictionary *downloadInfo = @{
		  kInfoKey_identifier   : identifier,
		  kInfoKey_status       : NOTIFICATION_SCLOUD_DOWNLOAD_COMPLETE,
		  kInfoKey_fullDownload : @(fullDownload)
		};
		
		[self updateStatusDictAndPostSCloudNotificationWithInfo:downloadInfo];
        
        if (completionBlock) {
			completionBlock(error, downloadInfo);
		}
		
	}
	else
	{
// EA: moved to downloadSCloudSegments:
/*
		NSString * locatorString = [opInfo objectForKey:kInfoKey_locatorString];
		NSString * keyString = [opInfo objectForKey:kInfoKey_keyString];
		BOOL fyeo = [[opInfo objectForKey:kInfoKey_fyeo] boolValue];
		
		NSError *segmentsError = nil;
		NSArray *segments = [SCloudObject segmentsFromLocatorString:locatorString
		                                                  keyString:keyString
		                                                  withError:&segmentsError];
		
		NSMutableArray *segmentsToDownload = [NSMutableArray arrayWithCapacity:[segments count]];
		
		NSURL *baseURL = [SCFileManager scloudCacheDirectoryURL];
        
		for (NSString *segment in segments)
		{
			NSURL *url = [baseURL URLByAppendingPathComponent:segment isDirectory:NO];
            
			NSError *err = nil;
            BOOL exists = ([url checkResourceIsReachableAndReturnError:&err] && !err && [url isFileURL]);
            
			if (!exists) {
				[segmentsToDownload addObject:segment];
			}
		}
 		
		[segmentsToDownload shuffle];
		
		SCloudObject *scloud = [[SCloudObject alloc] initWithLocatorString:locatorString
		                                                         keyString:keyString
		                                                              fyeo:fyeo];

		AsyncSCloudOp *masterOp = [[AsyncSCloudOp alloc] initWithDelegate:self
		                                                       userObject:opInfo
		                                                           scloud:scloud
		                                           segmentsExpectedToRead:[segmentsToDownload count]];
		
		[segments enumerateObjectsWithOptions:NSEnumerationConcurrent
		                           usingBlock:^(id obj, NSUInteger idx, BOOL *stop)
		{
			__unsafe_unretained NSString *locatorString = obj;
			
			S3DownloadOperation *downloadOp =
			  [[S3DownloadOperation alloc] initWithDelegate:self
			                                     userObject:masterOp
			                                         scloud:nil
			                                  locatorString:locatorString];
			
			[masterOp addDependency:downloadOp];
			[opQueue addOperation:downloadOp];
		}];
		
		[opQueue addOperation:masterOp];
 */
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Encrypt
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)startEncryptWithSCloud:(SCloudObject*)scloud
//                     withSiren:(Siren *)siren
//                    fromUserID:(NSString *)userID
//                conversationID:(NSString *)conversationID
                     messageID:(NSString *)messageID
               completionBlock:(SCloudManagerCompletionBlock)completionBlock
{
//	YapCollectionKey *identifier = [[YapCollectionKey alloc] initWithCollection:conversationID key:messageID];
    NSString *identifier = messageID;// [[conversationID stringByAppendingString:@"-"] stringByAppendingString:messageID];
    scloud.userValue = identifier;
    
	NSError *saveError = nil;
	[scloud saveToCacheWithError:&saveError];
	
//	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
//	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
//        
//        STMessage *message = [transaction objectForKey:messageID inCollection:conversationID];
// 		if (message)
//		{
//			// TODO: What are we supposed to be doing here?
//			
//		//	[transaction removeObjectForKey:message.uuid inCollection:message.conversationId];
//		//
//		//	[transaction touchObjectForKey:message.conversationId inCollection:userID];
//            
//        //#warning  VINNIE just delete the placeholder for now, better code here soon.
//            //			message = [message copy];
//            
//            //			message.errorInfo = error.copy;
//            //
//            //			[transaction setObject:message
//            //			                forKey:message.uuid
//            //			          inCollection:message.conversationId];
//			
//		}
//		
//	} completionBlock:^{
    
        NSDictionary *info = @{
		  kInfoKey_identifier : identifier,
		  kInfoKey_status     : NOTIFICATION_SCLOUD_ENCRYPT_COMPLETE
		};
		
		[self updateStatusDictAndPostSCloudNotificationWithInfo:info];
		
		if (completionBlock) {
			completionBlock(saveError, info);
		}
//	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark SCloudObjectDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)scloudObject:(SCloudObject *)sender savingDidStart:(NSString *)mediaType totalSegments:(NSInteger)totalSegments
{
#if HAS_DD_LOG
    DDLogAutoTrace();
#endif
	
	id identifier = sender.userValue;
	
	NSDictionary *info = @{
	  kInfoKey_identifier : identifier,
	  kInfoKey_status     : NOTIFICATION_SCLOUD_ENCRYPT_START
	};
	
	[self updateStatusDictAndPostSCloudNotificationWithInfo:info];
}

- (void)scloudObject:(SCloudObject *)sender savingProgress:(float)progress
{
#if HAS_DD_LOG
    DDLogAutoTrace();
#endif
	
	id identifier = sender.userValue;
    
	NSDictionary *info = @{
	  kInfoKey_identifier : identifier,
	  kInfoKey_status     :  NOTIFICATION_SCLOUD_ENCRYPT_PROGRESS,
	  kInfoKey_progress   : @(progress)
	};
	
	[self updateStatusDictAndPostSCloudNotificationWithInfo:info];
}

- (void)scloudObject:(SCloudObject *)sender savingDidCompleteWithError:(NSError *)error
{
#if HAS_DD_LOG
    DDLogAutoTrace();
#endif
	
	id identifier = sender.userValue;
    
	NSDictionary *info = @{
	  kInfoKey_identifier : identifier,
	  kInfoKey_status     : NOTIFICATION_SCLOUD_ENCRYPT_COMPLETE
	};
	
	[self updateStatusDictAndPostSCloudNotificationWithInfo:info];
}

@end

