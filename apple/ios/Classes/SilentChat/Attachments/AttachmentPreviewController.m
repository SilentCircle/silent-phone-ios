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

#import "AttachmentPreviewController.h"
#import "AttachmentManager.h"
#import "SCAttachment+QLPreviewItem.h"
#import "ChatManager.h"
#import "Utilities.h"

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

//- (void)_recursiveBackgroundColor:(UIView *)view {
//	for (UIView *subview in view.subviews) {
//		if (CGSizeEqualToSize(subview.frame.size, [UIScreen mainScreen].bounds.size)) {
//			subview.backgroundColor = [UIColor blackColor];
//			[self _recursiveBackgroundColor:subview];
//		}
//	}
//}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	// EA: NOT WORKING!!! I cannot set the background color of this screen!
	//	[self _recursiveBackgroundColor:self.view];

	// because I can't set background color, I do this:
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
	
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
                                                 name:@"receiveMessageState" object:nil];
    
	SCAttachment *attachment = _chatObject.attachment;
	if ( (attachment.decryptedObject) || (_downloadInProgress) )
		return;
	
	
	if ( (attachment.cloudKey) && (attachment.cloudLocator) && (!attachment.segmentList) ) {
		// we don't have the TOC
		[self downloadAttachmentTOC];
		return;
	}
	
	[self downloadAttachmentFull];
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
                          
                          [[[UIAlertView alloc] initWithTitle:@"An error has occurred"
                                                      message:@"Unable to download attachment."
                                                     delegate:nil
                                            cancelButtonTitle:nil
                                            otherButtonTitles:@"OK", nil] show];
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
                              
                              [[[UIAlertView alloc] initWithTitle:@"An error has occurred"
                                                          message:@"Unable to decrypt attachment."
                                                         delegate:nil
                                                cancelButtonTitle:nil
                                                otherButtonTitles:@"OK", nil] show];
                          });
                          
                          return;
					  }
                      
					  SCloudObject *decryptedObject = _chatObject.attachment.decryptedObject;
                                                           
					  if (decryptedObject){
						  
						  [decryptedObject.decryptedFileURL absoluteString];
						  NSString *ext = [decryptedObject.decryptedFileURL pathExtension];
						  
						  if ( ([ext isEqualToString:@"pdf"]) || ([@"txt" isEqualToString:ext]) ) {
							  NSString *fn = [_chatObject.attachment.metadata objectForKey:kSCloudMetaData_FileName];//
							  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
							  NSString *cachePath = [paths objectAtIndex:0];
							  
							  filePathStored = [cachePath stringByAppendingPathComponent:fn];
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
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"receiveMessageState" object:nil];
}

- (void)dealloc {
	// important: remove the decrypted cache file as soon as we're done with this view controller
	// note: attempting to place this in viewWillDisappear: or viewDidDisappear: causes crashing when playing videos
	_chatObject.attachment.decryptedObject = nil; // automatically deletes decrypted cache file
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
   NSError *e;
   if(filePathStored){
      [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:filePathStored] error:&e];
	   filePathStored = nil;
   }
}

#pragma mark - AttachmentManager notification
- (void)attachmentProgressNotification:(NSNotification *)note {
	AttachmentProgress *progressObj = [note object];
	if (![progressObj.messageID isEqualToString:_chatObject.msgId])
		return; // not for us
	
	_progressView.progress = progressObj.progress;
	_progressView.hidden = ( (progressObj.progress <= 0) || (progressObj.progress >= 1.0) );
}

- (void)attachmentReceivedNotification:(NSNotification *)note {
	NSString *receivedMessageID = (NSString *)[note object];
	if (![_chatObject.msgId isEqualToString:receivedMessageID])
		return; // not for us
	
	[self reloadData];
}

- (void)attachmentReceivedTOCNotification:(NSNotification *)note {
    
    ChatObject *chatObjectFromNotification = (ChatObject*) note.object;

    if(chatObjectFromNotification != _chatObject)
        return;
    
    [self downloadAttachmentFull];
}
@end
