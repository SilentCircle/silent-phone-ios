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
//  ChatManager.m
//  VoipPhone
//
//  Created by Ethan Arutunian on 8/6/15.
//
//
#import <AddressBook/AddressBook.h>
#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "axolotl_glue.h"

#import "ChatManager.h"

#import "AttachmentManager.h"
#import "ChatUtilities.h"
#import "DBManager.h"
#import "DBManager+PreparedMessageData.h"
#import "SCFileManager.h"
#include "SCPCallbackInterface.h"
#import "SPUser.h"
#import "GroupChatManager.h"
#import "SCPNotificationKeys.h"
#include "interfaceApp/AppInterfaceImpl.h"
//Categories
#import "NSNumber+Filesize.h"



static ChatManager *_sharedManager;

const CGFloat kThumbnailMaxWidth = 128 *2;
const CGFloat kThumbnailMaxHeight = 160 *2;

using namespace zina;


@interface ChatManager () {
	NSDictionary *_pendingPickerInfo;
}
@end

@implementation ChatManager

+ (ChatManager *)sharedManager {
	if (!_sharedManager)
		_sharedManager = [[ChatManager alloc] init];
	return _sharedManager;
}

- (void)sendTextMessage:(NSString *)messageText forGroup:(BOOL) isGroupChat
{
	if ([messageText length] > 0)
	{
		ChatObject *thisChatObject = [[ChatObject alloc] initWithText:messageText];
		
		uuid_string_t msgid;
		thisChatObject.msgId = [NSString stringWithFormat:@"%s",CTAxoInterfaceBase::generateMsgID(messageText.UTF8String, msgid, sizeof(msgid))];
		
		RecentObject *openedRecent = [ChatUtilities utilitiesInstance].selectedRecentObject;
		
        thisChatObject.isGroupChatObject = isGroupChat;
        if (isGroupChat)
        {
            thisChatObject.unixReadTimeStamp = time(NULL);
            thisChatObject.isRead = 1;
        } else
        {
            thisChatObject.isRead = 0;
        }
		thisChatObject.isReceived = 0;
		thisChatObject.iSendingNow = 1;
		thisChatObject.contactName = openedRecent.contactName;
		thisChatObject.burnTime = openedRecent.burnDelayDuration;
        thisChatObject.displayName = openedRecent.displayName;
		[thisChatObject takeTimeStamp];
		if(openedRecent.shareLocationTime > time(NULL) && [ChatUtilities utilitiesInstance].userLocation) {
			thisChatObject.location = [ChatUtilities utilitiesInstance].userLocation;
		}
#if HAS_DATA_RETENTION
        thisChatObject.drEnabled = ([Switchboard doesUserRetainDataType:kDRType_Message_Metadata]
                                    || [Switchboard doesUserRetainDataType:kDRType_Message_PlainText]);
#endif // HAS_DATA_RETENTION
        [[DBManager dBManagerInstance] saveMessage:thisChatObject];

        [[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectCreatedNotification object:self userInfo:@{kSCPChatObjectDictionaryKey:thisChatObject}];

		[self sendChatObjectAsync:thisChatObject];
	}
}

- (void)sendMessageWithAttachment:(SCAttachment *)attachment upload:(BOOL)shouldUpload forGroup:(BOOL) isGroupChat {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Create a new ChatObject
        ChatObject *thisChatObject = [[ChatObject alloc] initWithAttachment:attachment];
        
        NSString *assetName = [attachment.referenceURL lastPathComponent];
        if ([assetName length] == 0)
            assetName = [NSString stringWithFormat:@"asset_%ld", thisChatObject.unixTimeStamp];
        else
            assetName = [assetName stringByAppendingFormat:@"_%ld", thisChatObject.unixTimeStamp];
        
        uuid_string_t msgid;
        NSString *messageID = [NSString stringWithFormat:@"%s", CTAxoInterfaceBase::generateMsgID(assetName.UTF8String, msgid, sizeof(msgid))];
        thisChatObject.msgId = messageID;
        [thisChatObject takeTimeStamp];
        
        RecentObject *openedRecent = [ChatUtilities utilitiesInstance].selectedRecentObject;

        thisChatObject.isReceived = 0;
        thisChatObject.iSendingNow = 1;
        thisChatObject.isGroupChatObject = isGroupChat;
        
        if (isGroupChat)
        {
            thisChatObject.unixReadTimeStamp = time(NULL);
            thisChatObject.isRead = 1;
        } else
        {
            thisChatObject.isRead = 0;
        }
        thisChatObject.burnTime = openedRecent.burnDelayDuration;
        thisChatObject.contactName = openedRecent.contactName;
        thisChatObject.displayName = openedRecent.displayName;
        if(openedRecent.shareLocationTime > time(NULL) && [ChatUtilities utilitiesInstance].userLocation) {
            thisChatObject.location = [ChatUtilities utilitiesInstance].userLocation;
        }
#if HAS_DATA_RETENTION
        thisChatObject.drEnabled = ([Switchboard doesUserRetainDataType:kDRType_Message_Metadata]
                                    || [Switchboard doesUserRetainDataType:kDRType_Message_PlainText]
                                    || [Switchboard doesUserRetainDataType:kDRType_Attachment_PlainText]);
#endif // HAS_DATA_RETENTION

        // We're storing the message to the database now,
        // but we can't send it until after the scloud components have been uploaded.
        
        [[DBManager dBManagerInstance] saveMessage:thisChatObject];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectCreatedNotification object:self userInfo:@{kSCPChatObjectDictionaryKey:thisChatObject}];
        
        // dont upload when forwarding, just send and save
        if(shouldUpload)
            [self uploadAttachmentForChatObject:thisChatObject];
        else
            [self saveUploadedChatObject:thisChatObject];
    });
}

- (void)presentAlertOnMainThread:(NSDictionary *)infoD {
	NSError *error = [infoD objectForKey:@"error"];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[infoD objectForKey:@"title"]
									message:[error localizedDescription]
						  //[NSString stringWithFormat:@"%@ (%ld)", [error localizedDescription], (long)error.code]
								   delegate:nil
						  cancelButtonTitle:NSLocalizedString(@"OK", nil)
						  otherButtonTitles:nil];
	if ([infoD objectForKey:@"retry"]) {
		alert.delegate = self;
		[alert addButtonWithTitle:NSLocalizedString(@"Try Again", nil)];
	}
	[alert show];
}

- (void)uploadAttachmentForChatObject:(ChatObject *)thisChatObject {
    
    if (!thisChatObject)
        return;
    __block ChatObject *blockChatObject = thisChatObject;
	[[AttachmentManager sharedManager] uploadAttachment:blockChatObject completionBlock:^(NSError *error, NSDictionary *infoDict) {
        
        // if we are burning this chatobject while uploading
        // there is no need to save it again or show error message
        if (blockChatObject.iDidBurnAnimation != 0)
        {
            return ;
        }
		if (error)
        {
			blockChatObject.iSendingNow = 0;
			_failedChatObject = blockChatObject;
			[[DBManager dBManagerInstance] saveMessage:blockChatObject];
            
			[[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectUpdatedNotification
                                                                object:self
                                                              userInfo:@{kSCPErrorDictionaryKey:error, kSCPChatObjectDictionaryKey:blockChatObject}];

			[self performSelectorOnMainThread:@selector(presentAlertOnMainThread:) withObject:@{@"title":NSLocalizedString(@"Unable to send message", nil), @"error":error} waitUntilDone:NO];
		} else
        {
			[[DBManager dBManagerInstance] saveMessage:blockChatObject];
			[self sendChatObjectAsync:blockChatObject];
		}
	}];
}

-(void) saveUploadedChatObject:(ChatObject *) thisChatObject
{
    [self sendChatObjectAsync:thisChatObject];
    //[[DBManager dBManagerInstance] saveMessage:thisChatObject];//sendChatObjectAsync save message
}

- (void)sendChatObjectAsync:(ChatObject *)thisChatObject
{
    if (!thisChatObject)
        return;
	dispatch_queue_t messageSendingQueue = dispatch_queue_create("MessageSendingQueue",NULL);
    
    if (thisChatObject.isGroupChatObject)
    {
        dispatch_async(messageSendingQueue, ^{
            if (!thisChatObject)
                return;
            thisChatObject.contactName = [thisChatObject.contactName uppercaseString];
            [[GroupChatManager sharedInstance] sendGroupMessage:thisChatObject];
            [[DBManager dBManagerInstance] saveMessage:thisChatObject];
            [[DBManager dBManagerInstance] setOffBurnTimerForBurnTime:thisChatObject.burnTime andChatObject:thisChatObject checkForRemoveal:NO];
        });
    } else
    {
        dispatch_async(messageSendingQueue, ^{
            if (!thisChatObject)
                return;
            int64_t msgDeliveryId = [self sendMessageRequest:thisChatObject sendToMyDevices:NO];
            if(msgDeliveryId != 0)
            {
                thisChatObject.messageIdentifier = msgDeliveryId;
                [self sendMessageRequest:thisChatObject sendToMyDevices:YES];
                //if (thisChatObject.drEnabled) // assumes message sent successfully
                   // [Switchboard retainMessage:thisChatObject];
            }
            else
            {
                zina::AppInterfaceImpl *app = (zina::AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
                NSError *error = [NSError errorWithDomain:ChatObjectFailedNotification code:app->getErrorCode() userInfo:nil];
                [[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectFailedNotification object:self userInfo:@{kSCPChatObjectDictionaryKey:thisChatObject,kSCPErrorDictionaryKey:error}];
            }
            
            // check for cached message delivery id, if it exists assign and remove from cache directory
            NSString *messageDeliveryIDString = [NSString stringWithFormat:@"%lli",msgDeliveryId];
            NSString *existingMessageDeliveryStatus = [[DBManager dBManagerInstance].cachedMessageStatuses objectForKey:messageDeliveryIDString];
            
            if(!existingMessageDeliveryStatus)
            {
                thisChatObject.messageStatus = (long)[existingMessageDeliveryStatus longLongValue];
                [[DBManager dBManagerInstance].cachedMessageStatuses removeObjectForKey:messageDeliveryIDString];
            }
            [[DBManager dBManagerInstance] saveMessage:thisChatObject];
            [[DBManager dBManagerInstance] setOffBurnTimerForBurnTime:[ChatUtilities utilitiesInstance].selectedRecentObject.burnDelayDuration andChatObject:thisChatObject checkForRemoveal:NO];

            //refresh cell to chnage state from prepearing to sending
            [[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectUpdatedNotification object:self userInfo:@{kSCPChatObjectDictionaryKey:thisChatObject}];
          
          thisChatObject.iSendingNow = 0;
        });
    }
}


- (void)downloadChatObjectTOC:(ChatObject *)thisChatObject {
   
    int hasIP(void);
   
    if(!hasIP())return;//do not try to download the attachment if have no network.
   
    thisChatObject.didTryDownloadTOC = YES;
    if (!thisChatObject)
        return;
    __block ChatObject *blockChatObject = thisChatObject;
	[[AttachmentManager sharedManager] downloadAttachmentTOC:blockChatObject.attachment withMessageID:blockChatObject.msgId completionBlock:^(NSError *error, NSDictionary *infoDict) {
        if (!blockChatObject)
            return;
        // At this point ChatObject is stored in DB, if it's removed while TOC is downloading we need to skip saving it to db
        BOOL exists = [[DBManager dBManagerInstance] existEvent:blockChatObject.msgId andContactName:blockChatObject.contactName];
        if (!exists)
        {
            return ;
        }
		if (error) {
			// set hasfailedattachment flag to set failed thumbnail
			// saved in db
			blockChatObject.hasFailedAttachment = 1;
			[[DBManager dBManagerInstance] saveMessage:blockChatObject];
			[self performSelectorOnMainThread:@selector(presentAlertOnMainThread:) withObject:@{@"title":NSLocalizedString(@"Unable to receive attachment", nil),@"error":error} waitUntilDone:NO];
			return;
		}
        blockChatObject.hasFailedAttachment = 0;
		blockChatObject.imageThumbnail = [blockChatObject.attachment thumbnailImage];
		// for received
		[blockChatObject checkWaveFormWithColor:[UIColor blackColor]];
		[[DBManager dBManagerInstance] saveMessage:blockChatObject];
      
        [[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectUpdatedNotification object:self userInfo:@{kSCPChatObjectDictionaryKey:blockChatObject}];
	}];
}

-(int64_t) sendMessageRequest:(ChatObject *) thisChatObject sendToMyDevices:(BOOL)sendToMyDevices
{
    
   NSDictionary *messageDict = [ChatManager formatMessageDescriptorsAndAttribsForChatObject:thisChatObject sendToMyDevices:sendToMyDevices];
    NSString *json = [messageDict objectForKey:@"messageDescriptor"];
    NSString *attachmentJSON = [messageDict objectForKey:@"attachmentDescriptor"];
    NSString *attribs = [messageDict objectForKey:@"attribs"];
		
	int64_t msgDeliveryId = CTAxoInterfaceBase::sharedInstance()->sendJSONMessage(json.UTF8String, sendToMyDevices, true, attachmentJSON ? attachmentJSON.UTF8String : nil, attribs.UTF8String);
   
    if (!sendToMyDevices)
    {
        thisChatObject.preparedMessageData = [[DBManager dBManagerInstance] getPreparedMessageData:json attachmentDescriptor:attachmentJSON attribs:[NSString stringWithFormat:@"%s",attribs.UTF8String]];
        [[DBManager dBManagerInstance] saveMessage:thisChatObject];
    }
   
   if(!sendToMyDevices){
      thisChatObject.messageIdentifier = msgDeliveryId;
      //wecan not call this from chatObject bŗecause it will exec it also when we load a msg from DB
      [[DBManager dBManagerInstance] addChatObjectToRecentlySent:thisChatObject msgDeliveryId:msgDeliveryId];
   }
   else{
      //TODO monitor sibling deliveries
   }
   
	return msgDeliveryId;
}

+(NSDictionary *) formatMessageDescriptorsAndAttribsForChatObject:(ChatObject *) chatObject sendToMyDevices:(BOOL) sendToMyDevices
{
    char j[4096];
    int t_encode_json_string(char *out, int iMaxOut, const char *in);
    t_encode_json_string(j, sizeof(j) - 1, chatObject.messageText ? chatObject.messageText.UTF8String : "");
    
    NSString *jns = [NSString stringWithUTF8String: j ];
    
    const char *myUsername = [[ChatUtilities utilitiesInstance] getOwnUserName].UTF8String;
    NSString *json = [NSString stringWithFormat:@
                      "{"
                      "\"version\": 1,"
                      "\"recipient\": \"%s\","
                      //   "\"deviceId\": 1,"
                      "\"msgId\":\"%@\","
                      "\"message\":\"%@\""
                      "}"
                      ,sendToMyDevices ?  myUsername : [[ChatUtilities utilitiesInstance] removePeerInfo:chatObject.contactName lowerCase:NO].UTF8String
                      ,chatObject.msgId
                      ,jns];
    
    
    NSString *attachmentJSON = @"";
    if ( ([chatObject.attachment.cloudLocator length] > 0) && ([chatObject.attachment.cloudKey length] > 0) ) {
        // NOTE: cloudKey is already a JSON-formatted object
        attachmentJSON = [NSString stringWithFormat:@
                          "{"
                          "\"cloud_url\":\"%s\","
                          "\"cloud_key\":%s"
                          "}"
                          , chatObject.attachment.cloudLocator.UTF8String, chatObject.attachment.cloudKey.UTF8String];
    }
    
    NSString *ns = [[ChatManager sharedManager] getMessageAttributesForUserAsJSON:chatObject sendToMyDevices:sendToMyDevices];
    
    NSString *attribs = ns ? ns : @"";
    NSDictionary *messageDict = [NSDictionary dictionaryWithObjectsAndKeys:json,@"messageDescriptor",attachmentJSON,@"attachmentDescriptor",attribs,@"attribs", nil];
    return messageDict;

}


-(NSString *)getMessageAttributesForUserAsJSON:(ChatObject *)thisChatObject sendToMyDevices:(BOOL)sendToMyDevices {
	
	NSMutableDictionary *messageAttributes = [[NSMutableDictionary alloc] init];
	
	RecentObject *openedRecent = [ChatUtilities utilitiesInstance].selectedRecentObject;
	if(openedRecent.burnDelayDuration > 0 || sendToMyDevices) {
		[messageAttributes setObject:[NSNumber numberWithBool:YES] forKey:@"r"];
	}
	
    if(thisChatObject && thisChatObject.burnTime > 0) {
        [messageAttributes setObject:[NSString stringWithFormat:@"%li",thisChatObject.burnTime] forKey:@"s"];
    } else if(openedRecent.burnDelayDuration > 0) {
		[messageAttributes setObject:[NSString stringWithFormat:@"%li",openedRecent.burnDelayDuration] forKey:@"s"];
	} else if(!openedRecent) {
		[messageAttributes setObject:[NSString stringWithFormat:@"%i",[ChatUtilities utilitiesInstance].kDefaultBurnTime] forKey:@"s"];
	}
	
	if(sendToMyDevices) {
		[messageAttributes setObject:@"om" forKey:@"syc"];
		[messageAttributes setObject: [[ChatUtilities utilitiesInstance] removePeerInfo:thisChatObject.contactName lowerCase:NO] forKey:@"or"];
        
        if (thisChatObject.displayName)
            [messageAttributes setObject: thisChatObject.displayName forKey:@"dpn"];

	}
    [self addLocationToMessageAttributes:messageAttributes];

// DR handled by Zina
//    if ([Switchboard dataRetentionIsOn])
//        [messageAttributes setObject:[NSNumber numberWithBool:YES] forKey:@"rt"];
    
	if(messageAttributes.count < 1)
		return nil;
	
	NSError * err;
	NSData * jsonData = [NSJSONSerialization dataWithJSONObject:messageAttributes options:0 error:&err];
	
	if(err)
	{
		return nil;
	}
	
	NSString *attribsString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	
	return attribsString;
	
}

-(void) addLocationToMessageAttributes:(NSMutableDictionary *)messageAttributes
{
    RecentObject *openedRecent = [ChatUtilities utilitiesInstance].selectedRecentObject;
    CLLocation * location = [ChatUtilities utilitiesInstance].userLocation;
    
    if(openedRecent.shareLocationTime > time(NULL) && location.coordinate.latitude != 0  && location.coordinate.longitude != 0)
    {
        [messageAttributes setObject:[NSString stringWithFormat:@"%f",location.coordinate.latitude] forKey:@"la"];
        [messageAttributes setObject:[NSString stringWithFormat:@"%f",location.coordinate.longitude] forKey:@"lo"];
        [messageAttributes setObject:[NSString stringWithFormat:@"%f",location.altitude] forKey:@"a"];
        [messageAttributes setObject:[NSString stringWithFormat:@"%f",location.horizontalAccuracy] forKey:@"h"];
        [messageAttributes setObject:[NSString stringWithFormat:@"%f",location.verticalAccuracy] forKey:@"v"];
    }
}

- (void)sendMessageWithAssetInfo:(NSDictionary *)pickerInfo inView:(UIView *)holderView
{
	// ask user about shrinking message first
	NSString *mediaType = [pickerInfo objectForKey:UIImagePickerControllerMediaType];
	if (UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeImage)) {
		UIImage *image = [pickerInfo objectForKey:UIImagePickerControllerOriginalImage];
        //LOG---
		   NSString *u = [pickerInfo objectForKey:UIImagePickerControllerMediaURL];
		  NSString *o = [pickerInfo objectForKey:UIImagePickerControllerReferenceURL];
		  NSLog(@"%@ %@",u,o);
		//----
		//JN: we should not use more than 80% image quality
		//if it it 100% it compresses image only by about 30%, and it is almost lossless
		NSData *data = UIImageJPEGRepresentation(image, .8);
		float fullSz = [data length];
		NSString *title = [NSString stringWithFormat:NSLocalizedString(@"This message is %@. You can reduce the message size by scaling images.", nil), [[NSNumber numberWithFloat:fullSz] fileSizeString]];
		
		NSString *smallTitle = [NSString stringWithFormat:NSLocalizedString(@"Small (%@)", nil), [[NSNumber numberWithFloat:fullSz*0.25 *.25] fileSizeString]];
		NSString *mediumTitle = [NSString stringWithFormat:NSLocalizedString(@"Medium (%@)", nil), [[NSNumber numberWithFloat:fullSz*0.5 *.5] fileSizeString]];
		NSString *fullSizeTitle = [NSString stringWithFormat:NSLocalizedString(@"Full Size (%@)", nil), [[NSNumber numberWithFloat:fullSz] fileSizeString]];
		
		UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", nil) destructiveButtonTitle:nil otherButtonTitles:smallTitle, mediumTitle, fullSizeTitle, nil];
//		actionSheet.tag = kActionSheet_CompressAttachment;
		[actionSheet showInView:holderView];
		_pendingPickerInfo = [[NSDictionary alloc] initWithDictionary:pickerInfo];
		return;
	}

	
	// not an image, send full size
	// extract asset info from iOS picker info
	SCAttachment *attachment = [SCAttachment attachmentFromImagePickerInfo:pickerInfo
																 withScale:1.0
																 thumbSize:CGSizeMake(kThumbnailMaxWidth, kThumbnailMaxHeight) // fix to max height
																  location:nil];
    
    if (UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeMovie)) {
        //TMP LOG---
        NSString *u = [pickerInfo objectForKey:UIImagePickerControllerMediaURL];
        NSString *o = [pickerInfo objectForKey:UIImagePickerControllerReferenceURL];
        NSLog(@"%@ %@",u,o);
        //----

        // converts quicktime to MP4 and sendsMessageWithAttachment when done
        [self convertToMP4WithpickerInfo:pickerInfo forAttachment:attachment];
        return;
    }
    RecentObject *openedRecent = [ChatUtilities utilitiesInstance].selectedRecentObject;
	[self sendMessageWithAttachment:attachment upload:YES forGroup:openedRecent.isGroupRecent];
}

/*
 converts quickTime video from pickerInfo to MP4
 sets converted data to attachment.originalData
 and sends message even if conversion has failed
 */
-(void) convertToMP4WithpickerInfo:(NSDictionary *) info forAttachment:(SCAttachment *) attachment
{
    NSURL *tmpVideoURL = nil;

    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    
    if (CFStringCompare ((__bridge_retained CFStringRef) mediaType, kUTTypeMovie, 0) == kCFCompareEqualTo) {
        
        tmpVideoURL = [[SCFileManager chatTmpDirectoryURL] URLByAppendingPathComponent:@"tempv.mov"];
        NSData *videoData = [NSData dataWithContentsOfURL:[info objectForKey:UIImagePickerControllerMediaURL]];
        [videoData writeToURL:tmpVideoURL atomically:NO];
        NSURL *tmpURL = info[UIImagePickerControllerMediaURL];
        // Delete UIImagePickerController [guid].MOV file from /tmp
        [SCFileManager deleteFileAtURL:tmpURL];
    }
    
    if(!tmpVideoURL)
        return;
    
    CFRelease((__bridge CFStringRef)(mediaType));
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:tmpVideoURL options:nil];    
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];
    
    if ([compatiblePresets containsObject:AVAssetExportPresetLowQuality]) 
    {        
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc]initWithAsset:avAsset presetName:AVAssetExportPresetPassthrough];
        exportSession.shouldOptimizeForNetworkUse = YES;

        NSDate   *currentDataTime = [NSDate date];
        NSString *fn = [NSString stringWithFormat:@"%@.mp4", currentDataTime];
        NSURL    *storeVideoURL = [[SCFileManager chatDirectoryURL] URLByAppendingPathComponent:fn];

        exportSession.outputURL = storeVideoURL;
        exportSession.outputFileType = AVFileTypeMPEG4;
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            
            // Delete our conversion tmp file at /ApplicationSupport/com.silentcircle.silentphone/Chat/tmp/tempv.mov
            [SCFileManager deleteFileAtURL:tmpVideoURL];
            
            // if completed change SCAttachment data, send with old data in case of error
            if([exportSession status] == AVAssetExportSessionStatusCompleted)
            {
                attachment.originalData = [NSData dataWithContentsOfURL:storeVideoURL];
            }
            RecentObject *openedRecent = [ChatUtilities utilitiesInstance].selectedRecentObject;
            [self sendMessageWithAttachment:attachment upload:YES forGroup:openedRecent.isGroupRecent];
        }];        
    }    
}

#pragma mark - UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (buttonIndex == actionSheet.cancelButtonIndex) {
		// don't follow through sending the message
//		if (actionSheet.tag == kActionSheet_CompressAttachment)
			_pendingPickerInfo = nil;
		return;
	}
	
//	if (actionSheet.tag == kActionSheet_CompressAttachment) {
		float scale = 1.0;
		switch (buttonIndex) {
			case 0:
				// small size
				scale = 0.25;//if we want picture 4 times smaller scale must be .25
			 
				break;
			case 1:
				// medium size
				scale = 0.5;
				break;
			case 2:
				// large size
				break;
		}
		
		// extract asset info from iOS picker info
		SCAttachment *attachment = [SCAttachment attachmentFromImagePickerInfo:_pendingPickerInfo
																	 withScale:scale
																	 thumbSize:CGSizeMake(kThumbnailMaxWidth, kThumbnailMaxHeight) // fix to max height
																	  location:nil];
		
		_pendingPickerInfo = nil;
    
        RecentObject *openedRecent = [ChatUtilities utilitiesInstance].selectedRecentObject;
		[self sendMessageWithAttachment:attachment upload:YES forGroup:openedRecent.isGroupRecent];
		return;
//	}
}

- (void)sendMessageWithContact:(AddressBookContact *)contact {
    
	SCAttachment *attachment = [SCAttachment attachmentFromContact:contact];
    
    RecentObject *openedRecent = [ChatUtilities utilitiesInstance].selectedRecentObject;
    [self sendMessageWithAttachment:attachment upload:YES forGroup:openedRecent.isGroupRecent];
}

#pragma mark UIAlertViewDelegate
static ChatObject *_failedChatObject = nil;

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	// set to retry failed attachment if user desires
	ChatObject *failedChat = _failedChatObject;
	_failedChatObject = nil;
	if (buttonIndex != alertView.cancelButtonIndex) {
		// Try Again
		failedChat.iSendingNow = 1;
		failedChat.messageStatus = 0;
		[self uploadAttachmentForChatObject:failedChat];
	}
}


@end
