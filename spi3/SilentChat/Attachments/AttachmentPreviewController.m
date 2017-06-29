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
//  AttachmentPreviewController.m
//  VoipPhone
//
//  Created by Ethan Arutunian on 7/23/15.
//
//

#import "AttachmentPreviewController.h"
#import "AttachmentManager.h"

#import "ChatManager.h"
#import "ChatUtilities.h"
#import "SCFileManager.h"
#import "SCPNotificationKeys.h"

#import "SCAttachment+QLPreviewItem.h"
#import "UIColor+ApplicationColors.h"

@implementation AttachmentPreviewController {
	UIProgressView *_progressView;
	BOOL _downloadInProgress;
   NSString * filePathStored;
}

- (id)initWithChatObject:(ChatObject *)chatObject {
	if ( (self = [super init]) != nil) {
		self.chatObject = chatObject;
		self.delegate = self;
		self.dataSource = self;
		_downloadInProgress = NO;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	// add a progress bar
	CGRect progressR = CGRectMake(0, 0, 100, 21); // progress view heights are fixed in iOS
	progressR.origin.x = (self.view.frame.size.width - progressR.size.width)/2;
	progressR.origin.y = (self.view.frame.size.height - progressR.size.height)/2 + 30;
	_progressView = [[UIProgressView alloc] initWithFrame:progressR];
	_progressView.hidden = YES;
	_progressView.progress = 0;
	[self.view addSubview:_progressView];
    
}

#pragma mark - Notification Registration
- (void)registerNotifications {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(willPresentCallScreen:) name:kSCPWillPresentCallScreenNotification object:nil];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    
    return UIStatusBarStyleLightContent;
}

- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];
    
	[self.view bringSubviewToFront:_progressView];

	// register for AttachmentManager notifications
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(attachmentProgressNotification:)
												 name:AttachmentManagerDownloadProgressNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(attachmentReceivedNotification:)
												 name:AttachmentManagerReceiveAttachmentNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(attachmentReceivedTOCNotification:)
                                                 name:ChatObjectUpdatedNotification object:nil];
    
	SCAttachment *attachment = _chatObject.attachment;
	if ( (attachment.decryptedObject) || (_downloadInProgress) )
		return;
	
	
	if ( (attachment.cloudKey) && (attachment.cloudLocator) && (!attachment.segmentList) ) {
		// we don't have the TOC
		[self downloadAttachmentTOC];
		return;
	}
	
	[self downloadAttachmentFull];
    
    [self registerNotifications];
}

- (void)downloadAttachmentTOC {
	// if we've received an attachment but don't yet have the TOC, try downloading it again here (for the thumbnail)
	[[ChatManager sharedManager] downloadChatObjectTOC:_chatObject];
}

- (void)downloadAttachmentFull {
	_downloadInProgress = YES;
	_progressView.hidden = NO;
	// not downloaded or decrypted, do it now
	[[AttachmentManager sharedManager] downloadAttachmentFull:_chatObject.attachment
				withMessageID:_chatObject.msgId
			  completionBlock:^(NSError *error, NSDictionary *infoDict) {
                  
				  if (error != nil) {
					  _downloadInProgress = NO;
					  _progressView.hidden = YES;
                      
                      dispatch_async(dispatch_get_main_queue(), ^{
                          UIAlertController *alertC = [UIAlertController
                                                       alertControllerWithTitle:NSLocalizedString(@"An error has occurred", nil)
                                                       message:NSLocalizedString(@"Unable to download attachment.", nil)
                                                       preferredStyle:UIAlertControllerStyleAlert];
                          UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil];
                          [alertC addAction:ok];
                          [self presentViewController:alertC animated:YES completion:nil];
                      });
                      
					  return;
				  }
				  
				  // we've downloaded it, now decrypt it
				  [[AttachmentManager sharedManager] decryptAttachment:_chatObject.attachment
                                                       completionBlock:^(NSError *error, NSDictionary *infoDict) {
                                                           
					  _downloadInProgress = NO; // finished
					  _progressView.hidden = YES;
                      
                      if (error != nil) {
                          
                          dispatch_async(dispatch_get_main_queue(), ^{
                              UIAlertController *alertC = [UIAlertController
                                                           alertControllerWithTitle:NSLocalizedString(@"An error has occurred", nil)
                                                           message:NSLocalizedString(@"Unable to decrypt attachment.", nil)
                                                           preferredStyle:UIAlertControllerStyleAlert];
                              UIAlertAction *ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil];
                              [alertC addAction:ok];
                              [self presentViewController:alertC animated:YES completion:nil];
                          });
                          
                          return;
					  }
                      
					  SCloudObject *decryptedObject = _chatObject.attachment.decryptedObject;
                                                           
					  if (decryptedObject){
						  
						  [decryptedObject.decryptedFileURL absoluteString];
						  NSString *ext = [decryptedObject.decryptedFileURL pathExtension];
						  
						  if ( ([ext isEqualToString:@"pdf"]) || ([@"txt" isEqualToString:ext]) ) {
							  NSString *fn = [_chatObject.attachment.metadata objectForKey:kSCloudMetaData_FileName];
                              filePathStored = [[SCFileManager cachesDirectoryURL].relativePath stringByAppendingPathComponent:fn];

							  BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filePathStored];
							  if (fileExists == NO) {
								  NSData *fileData = [[NSData alloc] initWithContentsOfURL:decryptedObject.decryptedFileURL];
								  [fileData writeToFile:filePathStored atomically:YES];
								  
							  }
						  }
						  
						  dispatch_async(dispatch_get_main_queue(), ^{
                              [self reloadData];
                          });
					  }
				  }];
			  }];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AttachmentManagerDownloadProgressNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AttachmentManagerReceiveAttachmentNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ChatObjectUpdatedNotification object:nil];
}

- (void)dealloc {
    
    //ET: how does setting the property to nil "automatically delete decrypted cache file"?
    //
	// important: remove the decrypted cache file as soon as we're done with this view controller
	// note: attempting to place this in viewWillDisappear: or viewDidDisappear: causes crashing when playing videos
	_chatObject.attachment.decryptedObject = nil; // automatically deletes decrypted cache file
}

-(void) willPresentCallScreen:(NSNotification *) notification
{
    [self dismissViewControllerAnimated:NO completion:nil];
}

#pragma mark - Accessibility

-(BOOL) accessibilityPerformEscape
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    return YES;
}

#pragma mark - QLPreviewControllerDataSource


- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller {
	return 1;
}

- (id <QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
	SCAttachment *attachment = _chatObject.attachment;
   if(attachment.decryptedObject && ![QLPreviewController canPreviewItem:attachment]){
      NSLog(@"[QLPreviewController canPreviewItem] = NO,%@",attachment.decryptedObject.decryptedFileURL);
      return nil;
   }
   
	if ( (attachment.decryptedObject) || (_downloadInProgress) )//!!!JN -> EA: why do we have _downloadInProgress?
      return filePathStored ? [NSURL fileURLWithPath:filePathStored] : attachment;
	
	// should we provide a placeholder image while we wait?
	return nil;
}

#pragma mark - QLPreviewControllerDelegate
//- (void)previewControllerWillDismiss:(QLPreviewController *)controller;
- (void)previewControllerDidDismiss:(QLPreviewController *)controller{
   if(filePathStored){
       [SCFileManager deleteFileAtURL:[NSURL fileURLWithPath:filePathStored]];
	   filePathStored = nil;
   }
}

#pragma mark - AttachmentManager notification
- (void)attachmentProgressNotification:(NSNotification *)note {
	AttachmentProgress *progressObj = [note.userInfo objectForKey:kSCPProgressObjDictionaryKey];
	if (progressObj && ![progressObj.messageID isEqualToString:_chatObject.msgId])
		return; // not for us
	
	_progressView.progress = progressObj.progress;
	_progressView.hidden = ( (progressObj.progress <= 0) || (progressObj.progress >= 1.0) );
}

- (void)attachmentReceivedNotification:(NSNotification *)note {
	NSString *receivedMessageID = (NSString *)[note.userInfo objectForKey:kSCPMsgIdDictionaryKey];
	if (receivedMessageID && ![_chatObject.msgId isEqualToString:receivedMessageID])
		return; // not for us
	
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadData];
    });
}

- (void)attachmentReceivedTOCNotification:(NSNotification *)note {
    
    ChatObject *chatObjectFromNotification = [note.userInfo objectForKey:kSCPChatObjectDictionaryKey];

    if(!chatObjectFromNotification && chatObjectFromNotification != _chatObject)
        return;
    
    [self downloadAttachmentFull];
}
@end
