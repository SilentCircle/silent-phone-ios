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

#import "ChatManager.h"
#import "AttachmentManager.h"
#import "DBManager.h"
#import "Utilities.h"
#import "NSNumber+Filesize.h"

#import "axolotl_glue.h"
#import <AddressBook/AddressBook.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import <AVFoundation/AVFoundation.h>

static ChatManager *_sharedManager;

const CGFloat kThumbnailMaxWidth = 128 *2;
const CGFloat kThumbnailMaxHeight = 160 *2;

NSString *ChatObjectCreatedNotification = @"ChatObjectCreatedNotification";
NSString *ChatObjectUpdatedNotification = @"ChatObjectUpdatedNotification";

//enum {
//	,kActionSheet_CompressAttachment
//};

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

- (id)init {
	if ((self = [super init]) != nil) {
		_addressBook = nil;
	}
	return self;
}

- (void)dealloc {
	if (_addressBook)
		CFRelease(_addressBook);
// ARC [super dealloc];
}
- (void)sendTextMessage:(NSString *)messageText
{
	if ([messageText length] > 0)
	{
		ChatObject *thisChatObject = [[ChatObject alloc] initWithText:messageText];
		
		uuid_string_t msgid;
		thisChatObject.msgId = [NSString stringWithFormat:@"%s",CTAxoInterfaceBase::generateMsgID(messageText.UTF8String, msgid, sizeof(msgid))];
		
		RecentObject *openedRecent = [Utilities utilitiesInstance].selectedRecentObject;
		
		thisChatObject.isReceived = 0;
		thisChatObject.isRead = 0;
		thisChatObject.iSendingNow = 1;
		thisChatObject.contactName = openedRecent.contactName;
		thisChatObject.burnTime = openedRecent.burnDelayDuration;
		[thisChatObject takeTimeStamp];
		if(openedRecent.shareLocationTime > time(NULL)) {
			thisChatObject.location = [Utilities utilitiesInstance].userLocation;
		}
		
		NSMutableArray *chatHistory = [[Utilities utilitiesInstance].chatHistory objectForKey:thisChatObject.contactName];
		[chatHistory addObject:thisChatObject];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectCreatedNotification object:thisChatObject];

		[self sendChatObjectAsync:thisChatObject];
	}
}

- (void)sendMessageWithAttachment:(SCAttachment *)attachment upload:(BOOL) shouldUpload {
	// Create a new ChatObject
	ChatObject *thisChatObject = [[ChatObject alloc] initWithAttachment:attachment];
	[thisChatObject takeTimeStamp];
	
	NSString *assetName = [attachment.referenceURL lastPathComponent];
	if ([assetName length] == 0)
		assetName = [NSString stringWithFormat:@"asset_%ld", thisChatObject.unixTimeStamp];
	else
		assetName = [assetName stringByAppendingFormat:@"_%ld", thisChatObject.unixTimeStamp];
	
	uuid_string_t msgid;
	NSString *messageID = [NSString stringWithFormat:@"%s", CTAxoInterfaceBase::generateMsgID(assetName.UTF8String, msgid, sizeof(msgid))];
	thisChatObject.msgId = messageID;
	
	RecentObject *openedRecent = [Utilities utilitiesInstance].selectedRecentObject;

	thisChatObject.isReceived = 0;
	thisChatObject.iSendingNow = 1;
	
	thisChatObject.burnTime = openedRecent.burnDelayDuration;
	thisChatObject.contactName = openedRecent.contactName;
	
	// We're storing the message to the database now,
	// but we can't send it until after the scloud components have been uploaded.
	
	NSMutableArray *chatHistory = [[Utilities utilitiesInstance].chatHistory objectForKey:thisChatObject.contactName];
	[chatHistory addObject:thisChatObject];
	
	[[DBManager dBManagerInstance] saveMessage:thisChatObject];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectCreatedNotification object:thisChatObject];
    
    // dont upload when forwarding, just send and save
	if(shouldUpload)
        [self uploadAttachmentForChatObject:thisChatObject];
    else
        [self saveUploadedChatObject:thisChatObject];
}

- (void)presentAlertOnMainThread:(NSDictionary *)infoD {
	NSError *error = [infoD objectForKey:@"error"];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[infoD objectForKey:@"title"]
									message:[error localizedDescription]
						  //[NSString stringWithFormat:@"%@ (%ld)", [error localizedDescription], (long)error.code]
								   delegate:nil
						  cancelButtonTitle:@"OK"
						  otherButtonTitles:nil];
	if ([infoD objectForKey:@"retry"]) {
		alert.delegate = self;
		[alert addButtonWithTitle:@"Try Again"];
	}
	[alert show];
}

- (void)uploadAttachmentForChatObject:(ChatObject *)thisChatObject {
	[[AttachmentManager sharedManager] uploadAttachment:thisChatObject completionBlock:^(NSError *error, NSDictionary *infoDict) {
		if (error) {
			thisChatObject.iSendingNow = 0;
			_failedChatObject = thisChatObject;
			[[DBManager dBManagerInstance] saveMessage:thisChatObject];
			[[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectUpdatedNotification object:thisChatObject];

			[self performSelectorOnMainThread:@selector(presentAlertOnMainThread:) withObject:@{@"title":@"Unable to send message", @"error":error} waitUntilDone:NO];
		} else {
			[[DBManager dBManagerInstance] saveMessage:thisChatObject];
			[self sendChatObjectAsync:thisChatObject];
		}
	}];
}

-(void) saveUploadedChatObject:(ChatObject *) thisChatObject
{
    [self sendChatObjectAsync:thisChatObject];
    [[DBManager dBManagerInstance] saveMessage:thisChatObject];
}

- (void)sendChatObjectAsync:(ChatObject *)thisChatObject {
	dispatch_queue_t messageSendingQueue = dispatch_queue_create("MessageSendingQueue",NULL);
	dispatch_async(messageSendingQueue, ^{
		
		char j[4096];
		int t_encode_json_string(char *out, int iMaxOut, const char *in);
		t_encode_json_string(j, sizeof(j) - 1, thisChatObject.messageText ? thisChatObject.messageText.UTF8String : "");
		
		int64_t msgDeliveryId = [self sendMessageRequest:thisChatObject sendToMyDevices:NO escapedJSONMessage:j];
		if(msgDeliveryId != 0){
			[self sendMessageRequest:thisChatObject sendToMyDevices:YES escapedJSONMessage:j];
		}
		else{
			//int code = CTAxoInterfaceBase::sharedInstance()->getErrorCode();
			//const char *errMsg =  CTAxoInterfaceBase::sharedInstance()->getErrorInfo();
			
		}
		thisChatObject.messageIdentifier = msgDeliveryId;
		thisChatObject.iSendingNow = 0;
		
		// check for cached message delivery id, if it exists assign and remove from cache directory
		NSString *messageDeliveryIDString = [NSString stringWithFormat:@"%lli",msgDeliveryId];
		NSString *existingMessageDeliveryStatus = [[DBManager dBManagerInstance].cachedMessageStatuses objectForKey:messageDeliveryIDString];
		
		if(existingMessageDeliveryStatus)
		{
			thisChatObject.messageStatus = [existingMessageDeliveryStatus longLongValue];
			[[DBManager dBManagerInstance].cachedMessageStatuses removeObjectForKey:messageDeliveryIDString];
		}
		[[DBManager dBManagerInstance] saveMessage:thisChatObject];
		[[DBManager dBManagerInstance] setOffBurnTimerForBurnTime:[Utilities utilitiesInstance].selectedRecentObject.burnDelayDuration andChatObject:thisChatObject checkForRemoveal:NO];

		//refresh cell to chnage state from prepearing to sending
		[[NSNotificationCenter defaultCenter] postNotificationName:ChatObjectUpdatedNotification object:thisChatObject];
	});
}

- (void)downloadChatObjectTOC:(ChatObject *)thisChatObject {
   
   thisChatObject.didTryDownloadTOC = YES;
   
	[[AttachmentManager sharedManager] downloadAttachmentTOC:thisChatObject.attachment withMessageID:thisChatObject.msgId completionBlock:^(NSError *error, NSDictionary *infoDict) {
		if (error) {
			// set hasfailedattachment flag to set failed thumbnail
			// saved in db
			thisChatObject.hasFailedAttachment = 1;
			[[DBManager dBManagerInstance] saveMessage:thisChatObject];
			[self performSelectorOnMainThread:@selector(presentAlertOnMainThread:) withObject:@{@"title":@"Unable to receive attachment",@"error":error} waitUntilDone:NO];
			return;
		}
		
		thisChatObject.imageThumbnail = [thisChatObject.attachment thumbnailImage];
		// for received
		[thisChatObject checkWaveFormWithColor:[UIColor blackColor]];
		[[DBManager dBManagerInstance] saveMessage:thisChatObject];
      
      [[NSNotificationCenter defaultCenter] postNotificationName:@"receiveMessageState" object:thisChatObject];
	}];
}

-(int64_t) sendMessageRequest:(ChatObject *) thisChatObject sendToMyDevices:(BOOL)sendToMyDevices escapedJSONMessage:(const char*)escapedJSONMessage
{
	NSString *jns = [NSString stringWithUTF8String: escapedJSONMessage ];
	
	void *getCurrentDOut(void);
	const char* sendEngMsg(void *pEng, const char *p);
	const char *myUsername = sendEngMsg(getCurrentDOut(),"cfg.un");
	
	NSString *json = [NSString stringWithFormat:@
					  "{"
					  "\"version\": 1,"
					  "\"recipient\": \"%s\","
					  //   "\"deviceId\": 1,"
					  "\"msgId\":\"%@\","
					  "\"message\":\"%@\""
					  "}"
					  ,sendToMyDevices ?  myUsername : [[Utilities utilitiesInstance] removePeerInfo:thisChatObject.contactName lowerCase:NO].UTF8String
					  ,thisChatObject.msgId
					  ,jns];
	/*
	 message attributes: {"r":true,"la":56.9507556,"lo":24.1336798,"t":1434622788819,"a":0,"h":34.5,"v":34.5}
	 
	 r - request_receipt
	 la - lattitude
	 lo - longitude
	 t - time
	 a - altitude
	 h - horizontal accuracy
	 v - vertical accuracy
	 s - burn delay
	 */
	//NSString *attribs = [Utilities getMessageAttributesForUserAsJSON: user];
	
	/*
	 ]{"version": 1,"recipient": "gosis2","msgId":"39BFE12E-2572-11E5-ADB8-69430DA308E3","message":"Frtt"}
	 {"r":true,"s":"43200"}
	 [{"version": 1,"recipient": "gosis","msgId":"39BFE12E-2572-11E5-ADB8-69430DA308E3","message":"Frtt"}
	 {"r":true,"s":"43200","or":"gosis","syc":"om"}
	 */
	
	NSString *attachmentJSON = NULL;
	if ( ([thisChatObject.attachment.cloudLocator length] > 0) && ([thisChatObject.attachment.cloudKey length] > 0) ) {
		// NOTE: cloudKey is already a JSON-formatted object
		attachmentJSON = [NSString stringWithFormat:@
					  "{"
					  "\"cloud_url\":\"%s\","
					  "\"cloud_key\":%s"
					  "}"
					  , thisChatObject.attachment.cloudLocator.UTF8String, thisChatObject.attachment.cloudKey.UTF8String];
	}
	
	NSString *ns = [self getMessageAttributesForUserAsJSON:thisChatObject sendToMyDevices:sendToMyDevices ];
	const char *attribs = ns ? ns.UTF8String : NULL;
	
	int64_t msgDeliveryId = CTAxoInterfaceBase::sharedInstance()->sendJSONMessage(json.UTF8String, attachmentJSON ? attachmentJSON.UTF8String : nil, attribs);
	thisChatObject.messageIdentifier = msgDeliveryId;
	puts(json.UTF8String);
	puts(attribs);
	
	return msgDeliveryId;
}


-(NSString *)getMessageAttributesForUserAsJSON:(ChatObject *)thisChatObject sendToMyDevices:(BOOL)sendToMyDevices {
	
	NSMutableDictionary *messageAttributes = [[NSMutableDictionary alloc] init];
	
	RecentObject *openedRecent = [Utilities utilitiesInstance].selectedRecentObject;
	if(openedRecent.burnDelayDuration > 0 || sendToMyDevices) {
		[messageAttributes setObject:[NSNumber numberWithBool:YES] forKey:@"r"];
	}
	
	if(openedRecent.burnDelayDuration > 0) {
		[messageAttributes setValue:[NSString stringWithFormat:@"%li",openedRecent.burnDelayDuration] forKey:@"s"];
	} else if(!openedRecent) {
		[messageAttributes setValue:[NSString stringWithFormat:@"%i",[Utilities utilitiesInstance].kDefaultBurnTime] forKey:@"s"];
	}
	
	if(sendToMyDevices) {
		[messageAttributes setValue:@"om" forKey:@"syc"];
		[messageAttributes setValue: [[Utilities utilitiesInstance] removePeerInfo:thisChatObject.contactName lowerCase:NO] forKey:@"or"];
	}
	
	CLLocation * location = [Utilities utilitiesInstance].userLocation;
	
	if(openedRecent.shareLocationTime > time(NULL) && location.coordinate.latitude != 0  && location.coordinate.longitude != 0){
		[messageAttributes setValue:[NSString stringWithFormat:@"%f",location.coordinate.latitude] forKey:@"la"];
		[messageAttributes setValue:[NSString stringWithFormat:@"%f",location.coordinate.longitude] forKey:@"lo"];
		[messageAttributes setValue:[NSString stringWithFormat:@"%f",location.altitude] forKey:@"a"];
		[messageAttributes setValue:[NSString stringWithFormat:@"%f",location.horizontalAccuracy] forKey:@"h"];
		[messageAttributes setValue:[NSString stringWithFormat:@"%f",location.verticalAccuracy] forKey:@"v"];
	}
	
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

- (void)sendMessageWithAssetInfo:(NSDictionary *)pickerInfo inView:(UIView *)holderView
{
	// ask user about shrinking message first
	NSString *mediaType = [pickerInfo objectForKey:UIImagePickerControllerMediaType];
	if (UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeImage)) {
		UIImage *image = [pickerInfo objectForKey:UIImagePickerControllerOriginalImage];
		//   NSString *u = [pickerInfo objectForKey:UIImagePickerControllerMediaURL];
		//  NSString *o = [pickerInfo objectForKey:UIImagePickerControllerReferenceURL];
		//  NSLog(@"%@ %@",u,o);
		
		//JN: we should not use more than 80% image quality
		//if it it 100% it compresses image only by about 30%, and it is almost lossless
		NSData *data = UIImageJPEGRepresentation(image, .8);
		float fullSz = [data length];
		NSString *title = [NSString stringWithFormat:@"This message is %@. You can reduce the message size by scaling images.", [[NSNumber numberWithFloat:fullSz] fileSizeString]];
		
		NSString *smallTitle = [NSString stringWithFormat:@"Small (%@)", [[NSNumber numberWithFloat:fullSz*0.25 *.25] fileSizeString]];
		NSString *mediumTitle = [NSString stringWithFormat:@"Medium (%@)", [[NSNumber numberWithFloat:fullSz*0.5 *.5] fileSizeString]];
		NSString *fullSizeTitle = [NSString stringWithFormat:@"Full Size (%@)", [[NSNumber numberWithFloat:fullSz] fileSizeString]];
		
		UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:smallTitle, mediumTitle, fullSizeTitle, nil];
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
        // converts quicktime to MP4 and sendsMessageWithAttachment when done
        [self convertToMP4WithpickerInfo:pickerInfo forAttachment:attachment];
        return;
    }
	[self sendMessageWithAttachment:attachment upload:YES];
}

/*
 converts quickTime video from pickerInfo to MP4
 sets converted data to attachment.originalData
 and sends message even if conversion has failed
 */
-(void) convertToMP4WithpickerInfo:(NSDictionary *) info forAttachment:(SCAttachment *) attachment
{
    NSString *tempVideoDir = @"";
    
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    
    if (CFStringCompare ((__bridge_retained CFStringRef) mediaType, kUTTypeMovie, 0) == kCFCompareEqualTo)
        
    {
        NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        tempVideoDir =[NSString stringWithFormat:@"%@/tempv.mov",docDir];
        NSData *videoData = [NSData dataWithContentsOfURL:[info objectForKey:UIImagePickerControllerMediaURL]];
        
        [videoData writeToFile:tempVideoDir atomically:NO];
        
    }
    
    CFRelease((__bridge CFStringRef)(mediaType));
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:tempVideoDir] options:nil];
    
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];
    
    if ([compatiblePresets containsObject:AVAssetExportPresetLowQuality])
        
    {
        
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc]initWithAsset:avAsset presetName:AVAssetExportPresetPassthrough];
        exportSession.shouldOptimizeForNetworkUse = YES;
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSDate *currentDataTime = [NSDate date];
        NSString* videoPath = [NSString stringWithFormat:@"%@/%@.mp4", [paths objectAtIndex:0],currentDataTime];
        
        
        exportSession.outputURL = [NSURL fileURLWithPath:videoPath];
        exportSession.outputFileType = AVFileTypeMPEG4;

        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            
            [[NSFileManager defaultManager]removeItemAtPath:tempVideoDir error:nil];
            
            // if completed change SCAttachment data, send with old data in case of error
            if([exportSession status] == AVAssetExportSessionStatusCompleted)
            {
               attachment.originalData = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:videoPath]];
            }
            [self sendMessageWithAttachment:attachment upload:YES];
            
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
		[self sendMessageWithAttachment:attachment upload:YES];
		return;
//	}
}

- (void)sendMessageWithContact:(UserContact *)contact {
	if (!_addressBook) {
		CFErrorRef error = nil;
		_addressBook = ABAddressBookCreateWithOptions(NULL, &error);
		__block BOOL accessGranted = NO;
		if (&ABAddressBookRequestAccessWithCompletion != NULL) {
			dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
			
			ABAddressBookRequestAccessWithCompletion(_addressBook, ^(bool granted, CFErrorRef error) {
				accessGranted = granted;
				dispatch_semaphore_signal(semaphore);
			});
		}
	}
	
	SCAttachment *attachment = [SCAttachment attachmentFromContact:contact addressBook:_addressBook];
	[self sendMessageWithAttachment:attachment upload:YES];
/*
	ChatObject *thisChatObject = [[ChatObject alloc] initWithContact:contact];
	[thisChatObject takeTimeStamp];
	
	uuid_string_t msgid;
	NSString *messageID = [NSString stringWithFormat:@"%s", CTAxoInterfaceBase::generateMsgID(contact.contactUserName.UTF8String, msgid, sizeof(msgid))];
	
	thisChatObject.msgId = messageID;
	thisChatObject.isReceived = 0;
	thisChatObject.iSendingNow = 1;
	
	RecentObject *openedRecent = [Utilities utilitiesInstance].selectedRecentObject;
	thisChatObject.burnTime = openedRecent.burnDelayDuration;
	thisChatObject.contactName = openedRecent.contactName;
	
	// We're storing the message to the database now,
	// but we can't send it until after the scloud components have been uploaded.
	
	NSMutableArray *chatHistory = [[Utilities utilitiesInstance].chatHistory objectForKey:thisChatObject.contactName];
	[chatHistory addObject:thisChatObject];
	
	[self sendChatObjectAsync:thisChatObject];
 */
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
