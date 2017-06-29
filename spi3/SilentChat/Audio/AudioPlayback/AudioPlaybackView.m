/*
Copyright (C) 2013-2017, Silent Circle, LLC.  All rights reserved.

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
//  AudioPlaybackView.m
//  ST2
//
//  Created by mahboud on 11/19/13.
//  Copyright (c) 2013-2014 Silent Circle LLC. All rights reserved.
//

#import "AudioPlaybackView.h"
#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>
#import "ChatUtilities.h"
#import "SCPNotificationKeys.h"

#define kButtonTintColor [UIColor colorWithRed:238/255.0f green:233/255.0f blue:222/255.0f alpha:1.0f]
#define kBackgroundColor [UIColor colorWithRed:50/255.0f green:52/255.0f blue:56/255.0f alpha:1.0f]
@implementation AudioPlaybackView {
    
 	__weak IBOutlet UILabel *audioLabel;
	__weak IBOutlet UIView *levelBar;
  
    IBOutlet UIToolbar *toolBar; // So... this one's not weak because ???
    
    UIBarButtonItem *saveItem;
    UIBarButtonItem *playItem;
    UIBarButtonItem *pauseItem;

	CADisplayLink *_updateTimer;
	AVAudioSession *audioSession;
    
    BOOL _proximitySensorEnabled;
    
    BOOL _removeProximitySensor;
}

static SCloudObject *savedScloud;
static CGRect savedRect;
static UIView *savedView;

AVAudioPlayer *player;

#pragma mark - Lifecycle

- (id)init {
    if(self = [super init]) {
        
        NSArray *nibArray = [[NSBundle mainBundle] loadNibNamed:NSStringFromClass([self class]) owner:self options:nil];
        self = [nibArray firstObject];
        
        _proximitySensorEnabled = NO;
        
        // Used in order to detect when user plugs / unplugs his headphones
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(routeChanged:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(remoteControlReceived)
                                                     name:kSCPRemoteControlClickedNotification
                                                   object:nil];

        saveItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                 target:self
                                                                 action:@selector(shareItemHit)];
        
        playItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                                 target:self
                                                                 action:@selector(playItemHit)];
        [playItem setTintColor:[UIColor whiteColor]];
        
        pauseItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause
                                                                  target:self
                                                                  action:@selector(pauseItemHit)];
        [pauseItem setTintColor:[UIColor whiteColor]];
        
        [self setTintColor:kButtonTintColor];
        [self setBackgroundColor:kBackgroundColor];
    }
    
	return self;
}

- (void)dealloc {
    
	[player stop];
	[self stopTimer];
	
    [self disableProximitySensor];
	
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
	savedScloud = nil;
	savedView = nil;
}

#pragma mark - Notifications

- (void)remoteControlReceived {
    
    if(!self.superview)
        return;
    
    if([self.superview isHidden])
        return;
    
    if([self isPlaying])
        [self pauseItemHit];
    else
        [self playItemHit];
}

- (void)onNewProximityState {
    
    if(_removeProximitySensor) {
        
        [self disableProximitySensor];
        _removeProximitySensor = NO;
        
        return;
    }
    
    if(![self isPlaying])
        return;
    
    [self setSpeakerMode:[UIDevice currentDevice].proximityState];
}

- (void)routeChanged:(NSNotification*)notification {
    
    AVAudioSessionRouteDescription* oldRoute = [notification.userInfo objectForKey:AVAudioSessionRouteChangePreviousRouteKey];
    AVAudioSessionRouteDescription* newRoute = [[AVAudioSession sharedInstance] currentRoute];
    
    // Exclude changes from the setSpeakerMode: method
    if(newRoute && oldRoute) {
        
        NSArray *oldOutputs = oldRoute.outputs;
        NSArray *newOutputs = newRoute.outputs;
        
        if([oldOutputs count] > 0 && [newOutputs count] > 0) {
            
            AVAudioSessionPortDescription *oldOutput = [oldOutputs objectAtIndex:0];
            AVAudioSessionPortDescription *newOutput = [newOutputs objectAtIndex:0];
            
            if(([oldOutput.portType isEqualToString:AVAudioSessionPortBuiltInReceiver] && [newOutput.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker]) ||
               ([newOutput.portType isEqualToString:AVAudioSessionPortBuiltInReceiver] && [oldOutput.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker]))
            {
                return;
            }
        }
    }
    
    [self onNewProximityState];
}

#pragma mark - Public

- (void)playURL:(NSURL *)audioURL {
    
	if (player.isPlaying)
		[player stop];
	
    // Check if file exists (just in case)
    NSError *error = nil;
    BOOL check = [audioURL checkResourceIsReachableAndReturnError:&error];
    
    if(!check) {
        
        NSLog(@"%s %@", __PRETTY_FUNCTION__, error);
        return;
    }
    
	player = [[AVAudioPlayer alloc] initWithContentsOfURL:audioURL error:&error];
	player.delegate = self;
	[self updateSoundStatus];
	[self play];
}

- (void)play {
    
    audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];

    player.meteringEnabled = YES;
    [self startTimer];
    
    [player play];
    [self syncPlayPauseButtons];

    [self onNewProximityState];
}

- (void)stop {
    
	[player stop];
	[self syncPlayPauseButtons];
}

- (BOOL)isPlaying {
    
	return player.isPlaying;
}

#pragma mark UI Utilities

/**
 * If the media is playing, show the stop button; otherwise, show the play button.
**/
- (void)syncPlayPauseButtons {
    
    if ([self isPlaying]) {
        
        [self enableProximitySensor];
		[self showPauseButton];
        
    } else {
        
        if(!_removeProximitySensor)
            [self disableProximitySensor];
        
		[self showPlayButton];
    }
}

/**
 * Show the stop button in the movie player controller.
**/
- (void)showPauseButton {
    
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolBar items]];
    [toolbarItems replaceObjectAtIndex:2 withObject:pauseItem];
    toolBar.items = toolbarItems;
}

/**
 * Show the play button in the movie player controller.
**/
- (void)showPlayButton {
    
	NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[toolBar items]];
	[toolbarItems replaceObjectAtIndex:2 withObject:playItem];
	toolBar.items = toolbarItems;
}

#pragma mark Helper

- (BOOL)isHeadsetPluggedIn {
    
    AVAudioSessionRouteDescription* route = [[AVAudioSession sharedInstance] currentRoute];

    for (AVAudioSessionPortDescription* desc in [route outputs]) {
        
        if ([[desc portType] isEqualToString:AVAudioSessionPortHeadphones])
            return YES;
    }
    
    return NO;
}

- (BOOL)isBTPluggedIn {
    
    BOOL bHas = NO;
    NSArray *arrayInputs = [[AVAudioSession sharedInstance] availableInputs];
    
    for (AVAudioSessionPortDescription *port in arrayInputs) {
        
        if ([port.portType isEqualToString:AVAudioSessionPortBluetoothHFP]) {
            
            bHas = YES;
            break;
        }
    }
    
    return bHas;
}

- (BOOL) setSpeakerMode:(BOOL) speaker {
   
    // If user has his earbuds or BT headset connected, send audio there
    if([self isHeadsetPluggedIn] || [self isBTPluggedIn])
        speaker = YES;
	
    // If we are on a call then don't play over the speakerphone
    if([ChatUtilities utilitiesInstance].callCnt > 0)
        speaker = YES;
    
	BOOL ok;
    NSError *err = nil;
	
    ok = [audioSession overrideOutputAudioPort:(speaker ? AVAudioSessionPortOverrideNone : AVAudioSessionPortOverrideSpeaker)
                                         error:&err];
    
    
    if(!ok)
        NSLog(@"Error while trying to override output audio port: %@", err);
    
	return ok;
}

#pragma mark Proximity Sensor

- (void)enableProximitySensor {
    
    if(_proximitySensorEnabled)
        return;
    
    UIDevice *device = [UIDevice currentDevice];
    device.proximityMonitoringEnabled = YES;
    
    // Used in order to switch from earpiece to speakerphone and back when user is holding the
    // device near his ear
    if(device.proximityMonitoringEnabled) {
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onNewProximityState)
                                                     name:UIDeviceProximityStateDidChangeNotification
                                                   object:nil];
        
        _proximitySensorEnabled = YES;
    }
}

- (void)disableProximitySensor {
    
    if(!_proximitySensorEnabled)
        return;
    
    UIDevice *device = [UIDevice currentDevice];
    device.proximityMonitoringEnabled = NO;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceProximityStateDidChangeNotification object:nil];
    
    _proximitySensorEnabled = NO;
}

#pragma mark Actions

- (void)playItemHit {
    
	NSAssert([NSThread isMainThread], @"Delegate callback isn't thread-safe!");
	
    player.meteringEnabled = YES;
	[self startTimer];
	[player play];
    [self syncPlayPauseButtons];

}
- (void)pauseItemHit {
    
	NSAssert([NSThread isMainThread], @"Delegate callback isn't thread-safe!");
	
    [player pause];
    [self syncPlayPauseButtons];
	
	if ([self.delegate respondsToSelector:@selector(audioPlaybackViewDidStopPlaying:finished:)])
		[self.delegate audioPlaybackViewDidStopPlaying:self finished:NO];
}

- (void)shareItemHit {
    
    [self stop];
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        if ([self.delegate respondsToSelector:@selector(audioPlaybackView:needsHidePopoverAnimated:)])
            [self.delegate audioPlaybackView:self needsHidePopoverAnimated:NO];
    }

	if ([self.delegate respondsToSelector:@selector(audioPlaybackView:shareAudio:fromRect:inView:)])
		[self.delegate audioPlaybackView:self shareAudio:savedScloud fromRect:savedRect inView:savedView];

	savedView = NULL;
}

- (IBAction)rewindAction:(id)sender {
    
	float decrement = player.duration * 0.05;
	
	if (player){
        
		player.currentTime -= decrement;
		if (player.currentTime < 0)
			player.currentTime = 0;
		if (!player.isPlaying)
			[self updateCurrentTime];
	}
}

- (IBAction)forwardAction:(id)sender {
    
	float increment = player.duration * 0.05;
	
	if (player) {
        
		NSTimeInterval currTime = player.currentTime;
		currTime += increment;
		if (currTime > player.duration)
			currTime = 0;
		player.currentTime = currTime;
		if (!player.isPlaying)
			[self updateCurrentTime];
	}
}

- (IBAction)speakerAction:(id)sender {
	
	MPVolumeSettingsAlertShow();
}

#pragma mark Level Meter and Duration Updater

- (void)updateCurrentTime {
    
    int minutes = player.currentTime / 60;
    int seconds = ((int)player.currentTime) % 60;
	
  	audioLabel.text = [NSString stringWithFormat: @"%02d:%02d", minutes, seconds];
}

- (void)updateSoundStatus {
    
	BOOL isPlaying = player.isPlaying;
	
	[player updateMeters];
    
    const float min_interesting = -70; // decibels
	
	float curLevel;
	if (isPlaying)
		curLevel = [player averagePowerForChannel:0];
	else
		curLevel = min_interesting;
	
	if (curLevel < min_interesting)
		curLevel = min_interesting;
	
	curLevel += -min_interesting;
	curLevel /= -min_interesting;
  
	CGRect frame = audioLabel.frame;
    frame.origin.y += audioLabel.frame.size.height + 1;
    frame.size.height = 3;
    frame.size.width = (audioLabel.frame.size.width * curLevel);
    frame.origin.x = audioLabel.frame.origin.x
            + audioLabel.frame.size.width/2 -(audioLabel.frame.size.width * curLevel/2);
    
	levelBar.frame =  frame;
	
	[self updateCurrentTime];

	if (!isPlaying) {
		[self stopTimer];
	}
}

#pragma mark Timer

- (void)stopTimer {
    
	[_updateTimer invalidate];
	_updateTimer = nil;
}

- (void)startTimer {
    
	if (_updateTimer)
		[self stopTimer];
	
	_updateTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateSoundStatus)];
	[_updateTimer addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    
    // If player finishes but user has the proximity state enabled then
    // remove the proximity detection only when he switches back to a disabled proximity sensor.
    // This keeps the logic consistent when he will play another audio attachment
    if([UIDevice currentDevice].proximityState)
        _removeProximitySensor = YES;
    
    //g ad[self setSpeakerMode:NO];
    
    [self syncPlayPauseButtons];
    player.currentTime = 0;
    
    NSAssert([NSThread isMainThread], @"Delegate callback isn't thread-safe!");
    
    if ([self.delegate respondsToSelector:@selector(audioPlaybackViewDidStopPlaying:finished:)])
        [self.delegate audioPlaybackViewDidStopPlaying:self finished:YES];
}

@end
