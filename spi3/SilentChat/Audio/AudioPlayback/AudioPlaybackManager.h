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
//  AudioPlaybackManager.h
//  VoipPhone
//
//  Created by Ethan Arutunian on 7/28/15.
//
//

#import <Foundation/Foundation.h>
#import "AudioPlaybackView.h"
#import "ChatObject.h"

extern NSString *AudioPlayerDidFinishPlayingAttachmentNotification;
extern NSString *AudioPlayerDidPausePlayingAttachmentNotification;
extern NSString *AudioPlayerWillStartPlayingAttachmentNotification;

@interface AudioPlaybackManager : NSObject <AudioPlayBackViewDelegate> {
	BOOL _downloadInProgress;
	UIActivityIndicatorView *_spinnerView;
}

@property (nonatomic, strong, readonly) ChatObject *chatObject;
@property (nonatomic, strong) AudioPlaybackView *playbackView;
-(void) resizePlayerInContainerView:(UIView *) view;
//@property (nonatomic, strong, readonly) NSString *messageID;

+ (AudioPlaybackManager *)sharedManager;

- (void)playAttachment:(ChatObject *)chatObject inView:(UIView *)containerView;

- (BOOL)isPlaying;

- (void)showPlayerInView:(UIView *)containerView;

@end
