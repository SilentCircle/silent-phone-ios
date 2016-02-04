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

#import "AudioPlaybackManager.h"
#import "AttachmentManager.h"
#import "Utilities.h"

NSString *AudioPlayerDidFinishPlayingAttachmentNotification = @"AudioPlayerDidFinishPlayingAttachmentNotification";
NSString *AudioPlayerDidPausePlayingAttachmentNotification = @"AudioPlayerDidPausePlayingAttachmentNotification";

static AudioPlaybackManager *_sharedManager;

@implementation AudioPlaybackManager

+ (AudioPlaybackManager *)sharedManager {
	if (!_sharedManager)
		_sharedManager = [[AudioPlaybackManager alloc] init];
	return _sharedManager;
}

- (id)init {
	if ((self = [super init]) != nil) {
		_playbackView = [[AudioPlaybackView alloc] init];
		_playbackView.delegate = self;
	}
	return self;
}

- (void)playAttachment:(ChatObject *)chatObject inView:(UIView *)containerView {
	// check if we're already playing something and stop it
	if ([_playbackView isPlaying])
		[_playbackView stop];

    CGRect oldPlaybackViewFrame = _playbackView.frame;
    oldPlaybackViewFrame.size.width = [Utilities utilitiesInstance].screenWidth;
    [_playbackView setFrame:oldPlaybackViewFrame];
    
	[containerView addSubview:_playbackView];
	
	_chatObject = chatObject;
	
	if (chatObject.attachment.decryptedObject) {
		[self _playAudio];
		return;
	}
	if (_downloadInProgress)
		return;
	
	_downloadInProgress = YES;
	[_spinnerView startAnimating];
	// not downloaded or decrypted, do it now
	[[AttachmentManager sharedManager] downloadAttachmentFull:chatObject.attachment
												withMessageID:chatObject.msgId
											  completionBlock:^(NSError *error, NSDictionary *infoDict) {
                                                  
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                      
                                                      if (error != nil) {
                                                          _downloadInProgress = NO;
                                                          [_spinnerView stopAnimating];
                                                          UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"An error has occurred" message:@"Unable to download attachment." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                                                          [alertView show];
                                                          return;
                                                      }
                                                      
                                                      // If the decryption has already been made in the downloadAttachmentFull:withMessageID:completionBlock: method,
                                                      // then there is no need to decrypt again
                                                      if(chatObject.attachment.decryptedObject) {
                                                          
                                                          [_spinnerView stopAnimating];
                                                          _downloadInProgress = NO;
                                                          
                                                          [self _playAudio];
                                                          
                                                          return;
                                                      }
                                                      
                                                      // we've downloaded it, now decrypt it
                                                      [[AttachmentManager sharedManager] decryptAttachment:chatObject.attachment completionBlock:^(NSError *error, NSDictionary *infoDict) {
                                                          [_spinnerView stopAnimating];
                                                          _downloadInProgress = NO; // finished
                                                          if (error != nil) {
                                                              UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"An error has occurred" message:@"Unable to decrypt attachment." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                                                              [alertView show];
                                                              return;
                                                          }
                                                          if (chatObject.attachment.decryptedObject)
                                                              [self _playAudio];
                                                      }];
                                                  });
											  }];
}

- (void)_playAudio {
	[_playbackView playURL:_chatObject.attachment.decryptedObject.decryptedFileURL];
}

- (BOOL)isPlaying {
	return ( (_playbackView) && ([_playbackView isPlaying]) );
}

- (void)showPlayerInView:(UIView *)containerView {
	[containerView addSubview:_playbackView];
}

#pragma mark - AudioPlaybackViewDelegate
- (void)audioPlaybackViewDidStopPlaying:(AudioPlaybackView *)sender finished:(BOOL)didFinish {
	if (didFinish)
		[[NSNotificationCenter defaultCenter] postNotificationName:AudioPlayerDidFinishPlayingAttachmentNotification object:_playbackView];
	else
		[[NSNotificationCenter defaultCenter] postNotificationName:AudioPlayerDidPausePlayingAttachmentNotification object:_playbackView];
}

- (void)audioPlaybackView:(AudioPlaybackView *)sender needsHidePopoverAnimated:(BOOL)animated {
	// NYI
}

- (void)audioPlaybackView:(AudioPlaybackView *)sender
			   shareAudio:(SCloudObject *)scloud
				 fromRect:(CGRect)inRect
				   inView:(UIView *)inView {
	// NYI
}


@end
