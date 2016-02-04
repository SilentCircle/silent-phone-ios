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

#import "AttachmentManager.h"
#import "SCloudManager.h"
#import "SCloudObject.h"
#import "DBManager.h"

#import "SCloudConstants.h"

static AttachmentManager *_sharedManager;

NSString *AttachmentManagerEncryptProgressNotification = @"AttachmentManagerEncryptProgressNotification";
NSString *AttachmentManagerUploadProgressNotification = @"AttachmentManagerUploadProgressNotification";
NSString *AttachmentManagerVerifyProgressNotification = @"AttachmentManagerVerifyProgressNotification";
NSString *AttachmentManagerDownloadProgressNotification = @"AttachmentManagerDownloadProgressNotification";
NSString *AttachmentManagerReceiveAttachmentNotification = @"AttachmentManagerReceiveAttachmentNotification";

const NSTimeInterval DEFAULT_ATTACHMENT_SHRED_DELAY = 31*24*60*60;

@implementation AttachmentProgress
// data-only class defined in .h
@end

@implementation AttachmentManager

+ (AttachmentManager *)sharedManager {
	if (!_sharedManager)
		_sharedManager = [[AttachmentManager alloc] init];
	return _sharedManager;
}

- (NSString *)uploadAttachment:(ChatObject *)chatObject//(SCAttachment *)attachment
//                            withMessageID:(NSString *)messageID
                          completionBlock:(AttachmentManagerCompletionBlock)completionBlock
{
	SCAttachment *attachment = chatObject.attachment;
	NSString *messageID = chatObject.msgId;
	
    ALAsset      * asset          = attachment.decryptedAsset;
    NSDictionary * metadata       = attachment.metadata;
    NSString     * mediaType      = [metadata objectForKey:kSCloudMetaData_MediaType];
    // not currently used here
    //    NSString * filename  = [metadata objectForKey:kSCloudMetaData_FileName];
    //    NSString * mimeType  = [metadata objectForKey:kSCloudMetaData_MimeType];
    //    NSString * duration  = [metadata objectForKey:kSCloudMetaData_Duration];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSCloudProgress:) name:NOTIFICATION_SCLOUD_OPERATION object:nil];
    
    // run the SCloud encryption in a background process
    dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(backgroundQueue, ^{
        if (attachment.originalData) {
            // Items  with mediaData are typically smaller (scaled down photos).
            SCloudObject *scloud = [[SCloudObject alloc] initWithDelegate:[SCloudManager sharedInstance]
									 data:attachment.originalData
								 metaData:metadata
								mediaType:mediaType
							contextString:messageID];
            [[SCloudManager sharedInstance] startEncryptWithSCloud:scloud
                                                         messageID:messageID
                                                   completionBlock:^(NSError *error, NSDictionary *infoDict) {
					   if (error) {
						   [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_SCLOUD_OPERATION object:nil];
						   NSLog(@"AttachmentManager: failed to encrypt for SCloud (%@)", [error localizedDescription]);
						   if (completionBlock)
							   completionBlock(error, infoDict);
					   } else {
						   // at this point we can get rid of originalData
						   // we'll decrypt it again if we need it
						   attachment.originalData = nil;
						   attachment.cloudKey = scloud.keyString;
						   attachment.cloudLocator = scloud.locatorString;
						   attachment.segmentList = scloud.segmentList;
						   chatObject.attachment = attachment; // required to reset chat dictionary values for attachment
						   // save chat object
						   [[DBManager dBManagerInstance] saveMessage:chatObject];

						   [self continueUploadToSCloud:scloud messageID:messageID completionBlock:completionBlock];
					   }
				   }];
		} else if ( ([attachment.cloudKey length] > 0)
				   && ([attachment.cloudLocator length] > 0)
				   && ([attachment.segmentList count] > 0)) {
			SCloudObject *scloud = [[SCloudObject alloc] initWithLocatorString:attachment.cloudLocator keyString:attachment.cloudKey fyeo:NO segmentList:attachment.segmentList];
			[self continueUploadToSCloud:scloud messageID:messageID completionBlock:completionBlock];
        } else if (asset) {
            // Items  with assets are typically larger ?
// NYI: this code has not been tested (ALAsset)
            SCloudObject *scloud = [[SCloudObject alloc] initWithDelegate:[SCloudManager sharedInstance]
                                                                    asset:asset
                                                                 metaData:metadata
                                                                mediaType:mediaType
                                                            contextString:messageID];
            [[SCloudManager sharedInstance] startEncryptWithSCloud:scloud
                                                         messageID:messageID
												   completionBlock:^(NSError *error, NSDictionary *infoDict) {
					   if (error) {
						   [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_SCLOUD_OPERATION object:nil];
						   NSLog(@"AttachmentManager: failed to encrypt for SCloud (%@)", [error localizedDescription]);
						   if (completionBlock)
							   completionBlock(error, infoDict);
					   } else {
						   // at this point we can get rid of originalData
						   // we'll decrypt it again if we need it
						   attachment.decryptedAsset = nil;
						   attachment.cloudKey = scloud.keyString;
						   attachment.cloudLocator = scloud.locatorString;
						   attachment.segmentList = scloud.segmentList;
						   
						   [[DBManager dBManagerInstance] saveMessage:chatObject];

						   [self continueUploadToSCloud:scloud messageID:messageID completionBlock:completionBlock];
					   }
				   }];
        } else {
            NSLog(@"Shouldn't happen: Unable to send item without mediaData or assetURL !?!");
        }
    });
    return messageID;
}

- (void)continueUploadToSCloud:(SCloudObject *)scloud
                     messageID:(NSString *)messageID
               completionBlock:(AttachmentManagerCompletionBlock)completionBlock
{
//	dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//	dispatch_async(backgroundQueue, ^{
		// TODO: save segments and state to local database
		[[SCloudManager sharedInstance] uploadSCloud:scloud
				   messageID:messageID
				   burnDelay:DEFAULT_ATTACHMENT_SHRED_DELAY
			 completionBlock:^(NSError *error, NSDictionary *infoDict) {
				 if (error) {
					 [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_SCLOUD_OPERATION object:nil];
					 NSLog(@"AttachmentManager: failed to upload to SCloud (%@)", [error localizedDescription]);
					 if (completionBlock)
						completionBlock(error, nil);
					 return;
				 }
				 [[SCloudManager sharedInstance] verifySCloudUpload:scloud messageID:messageID completionBlock:^(NSError *error, NSDictionary *missingDict) {
					 [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_SCLOUD_OPERATION object:nil];
					 if (error != nil) {
						 if (completionBlock)
							 completionBlock(error, infoDict);
						 return;
					 }
					 
					 if ([missingDict count] == 0) {
						 // all done
						 if (completionBlock)
							 completionBlock(nil, infoDict);
						 return;
					 }
					 
					 // missing chunks, try again?
					 error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotCreateFile userInfo:missingDict];
					 if (completionBlock)
						 completionBlock(error, infoDict);
				 }];
			 }];
//	});
}

/**
 * The first time this method is invoked (internally, when a message with scloud is received),
 * this method downloads the first few segments.
 *
 * Upon later invocations, all the rest of the segments are downloaded.
 **/
- (void)downloadAttachmentTOC:(SCAttachment *)attachment
             withMessageID:(NSString *)messageID
                 completionBlock:(AttachmentManagerCompletionBlock)completionBlock
{

    SCloudObject *scloud = [[SCloudObject alloc] initWithLocatorString:attachment.cloudLocator
											 keyString:attachment.cloudKey
												  fyeo:NO];// EA: fyeo NYI
	NSError *decryptError = nil;
	if (scloud.isCached) {
		[self _decryptAttachmentTOC:attachment withMessageID:messageID scloud:scloud error:&decryptError];
		if (completionBlock)
			completionBlock(decryptError, nil);
		return;
    }

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSCloudProgress:) name:NOTIFICATION_SCLOUD_OPERATION object:nil];

    [[SCloudManager sharedInstance] downloadSCloudTOC:scloud
				 identifier:messageID
			completionBlock:^(NSError *error, NSDictionary *infoDict) {
				if (error) {
					[[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_SCLOUD_OPERATION object:nil];
					[[NSNotificationCenter defaultCenter] postNotificationName:AttachmentManagerReceiveAttachmentNotification object:messageID];
					if (completionBlock)
						completionBlock(error, infoDict);
					return;
				}
				
				NSError *decryptError = nil;
				[self _decryptAttachmentTOC:attachment withMessageID:messageID scloud:scloud error:&decryptError];
				if (completionBlock)
					completionBlock(decryptError, infoDict);
	 }];
}

- (void)_decryptAttachmentTOC:(SCAttachment *)attachment
				withMessageID:(NSString *)messageID
					   scloud:(SCloudObject *)scloud
						error:(NSError **)errorP
{
	*errorP = nil;
	BOOL decryptResult = [scloud decryptMetaDataUsingKeyString:attachment.cloudKey withError:errorP];
	if (!decryptResult || *errorP) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_SCLOUD_OPERATION object:nil];
		[[NSNotificationCenter defaultCenter] postNotificationName:AttachmentManagerReceiveAttachmentNotification object:messageID];
		return;
	}
	
	attachment.metadata = scloud.metaData;
	attachment.segmentList = scloud.segmentList;
	[[NSNotificationCenter defaultCenter] postNotificationName:AttachmentManagerReceiveAttachmentNotification object:messageID];
}

static BOOL _retriedTOC = NO;

- (void)downloadAttachmentFull:(SCAttachment *)attachment
				withMessageID:(NSString *)messageID
			  completionBlock:(AttachmentManagerCompletionBlock)completionBlock
{
    // If the segment list is missing from the saved attachment
    if(attachment.metadata && [attachment.cloudKey length] > 0 && [attachment.cloudLocator length] > 0 && [attachment.segmentList count] == 0) {
        
        SCloudObject *scloud = [[SCloudObject alloc] initWithLocatorString:attachment.cloudLocator keyString:attachment.cloudKey fyeo:NO];
        
        NSError *error = nil;
        
        // Decrypt the local attachment to try and fetch the segment list
        [scloud decryptCachedFileUsingKeyString:attachment.cloudKey withError:&error];
        
        // If the segmented chunks are on device's cache, use them
        if(!error) {
            
            //NSLog(@"Segmented chunks found locally and decrypted. Using them...");

            attachment.decryptedObject = scloud;
            
            if(completionBlock)
                completionBlock(nil, nil);
            
            _retriedTOC = NO;
            return;
            
        } else if(error.code == kSCLError_ResourceUnavailable) {

            //NSLog(@"Segmented chunks are being downloaded...");

            // If the segmented chunks are not on the cache of the device, assign the segment list to the attachment
            // and proceed in downloading them
            attachment.segmentList = scloud.segmentList;
            
        } else {
            
            //NSLog(@"Error %@ occured while retrieving cached file, getting the TOC", error);
            
            [self downloadAttachmentTOC:attachment withMessageID:messageID completionBlock:^(NSError *error, NSDictionary *infoDict) {
                
                _retriedTOC = YES;
                
                if (error)
                    completionBlock(error, infoDict);
                else {
                    // try again
                    [self downloadAttachmentFull:attachment withMessageID:messageID completionBlock:completionBlock];
                }
            }];
            
            return;
        }
    }
    
	if ( (!attachment.metadata) || ([attachment.segmentList count] == 0)
			|| ([attachment.cloudKey length] == 0) || ([attachment.cloudLocator length] == 0) ) {
		// something's wrong
		//TODO: handle error
		NSLog(@"Error: attempting to download full attachment without cloud info");
		if (completionBlock)
			completionBlock(nil, nil);
		_retriedTOC = NO;
		return;
	}
	
	SCloudObject *scloud = [[SCloudObject alloc] initWithLocatorString:attachment.cloudLocator keyString:attachment.cloudKey fyeo:NO segmentList:attachment.segmentList]; // EA: no fyeo
	if (!scloud.isCached) {
		// something else has gone wrong, TOC was previously processed but file is gone!
		if (_retriedTOC) {
			NSLog(@"Error: unable to download TOC");
			if (completionBlock)
				completionBlock(nil, nil);
			_retriedTOC = NO;
			return;
		}
		[self downloadAttachmentTOC:attachment withMessageID:messageID completionBlock:^(NSError *error, NSDictionary *infoDict) {
			_retriedTOC = YES;
			if (error)
				completionBlock(error, infoDict);
			else {
				// try again
				[self downloadAttachmentFull:attachment withMessageID:messageID completionBlock:completionBlock];
			}
			return;
		}];
		return;
	}
	_retriedTOC = NO;

	[[SCloudManager sharedInstance] downloadSCloudFull:scloud
					identifier:messageID
			   completionBlock:^(NSError *error, NSDictionary *infoDict) {
				   if (error == nil) {
					   // TODO: save attachment in DB
					   
				   }
				   if (completionBlock)
					   completionBlock(error, infoDict);
	 }];
}

- (void)decryptAttachment:(SCAttachment *)attachment
		  completionBlock:(AttachmentManagerCompletionBlock)completionBlock
{
	// TODO: if attachment TOC is already decrypted, set those properties and only decrypt segments
	
	SCloudObject *scloud = [[SCloudObject alloc] initWithLocatorString:attachment.cloudLocator keyString:attachment.cloudKey fyeo:NO];// EA: fyeo NYI
	
	NSError *error = nil;
	[scloud decryptCachedFileUsingKeyString:attachment.cloudKey withError:&error];
	if (!error) {
		attachment.decryptedObject = scloud; // hold onto scloud until we don't need it
		// no need to save chatObject in DB (we don't save decryptedObject)
	}
		
	if (completionBlock)
		completionBlock(error, nil);
}

#pragma mark Notifications
- (void)onSCloudProgress:(NSNotification *)note {
    NSDictionary *info = note.userInfo;
	AttachmentProgress *progressObj = [[AttachmentProgress alloc] init];
    NSString *noteStatus = [info objectForKey:kInfoKey_status];
    progressObj.messageID = [info objectForKey:kInfoKey_identifier];
	NSNumber *progressN = [info objectForKey:kInfoKey_progress];
	if (progressN) {
		progressObj.progress = [progressN floatValue];
		//NSLog(@"Upload Progress (%@): %@%%", progressObj.messageID, progressN);
	}
	if ([NOTIFICATION_SCLOUD_ENCRYPT_PROGRESS isEqualToString:noteStatus]) {
		progressObj.progressType = kProgressType_Encrypt;
		[[NSNotificationCenter defaultCenter] postNotificationName:AttachmentManagerEncryptProgressNotification object:progressObj];
	} else if ([NOTIFICATION_SCLOUD_UPLOAD_PROGRESS isEqualToString:noteStatus]) {
		progressObj.progressType = kProgressType_Upload;
		[[NSNotificationCenter defaultCenter] postNotificationName:AttachmentManagerUploadProgressNotification object:progressObj];
	} else if ([NOTIFICATION_SCLOUD_DOWNLOAD_PROGRESS isEqualToString:noteStatus]) {
		progressObj.progressType = kProgressType_Download;
			 [[NSNotificationCenter defaultCenter] postNotificationName:AttachmentManagerDownloadProgressNotification object:progressObj];
	} else if ([NOTIFICATION_SCLOUD_VERIFY_PROGRESS isEqualToString:noteStatus]) {
		progressObj.progressType = kProgressType_Verify;
		[[NSNotificationCenter defaultCenter] postNotificationName:AttachmentManagerVerifyProgressNotification object:progressObj];
	}
}

@end
