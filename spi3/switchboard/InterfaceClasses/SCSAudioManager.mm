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
//  SCSAudioManager.m
//  SPi3
//
//  Created by Eric Turner on 11/11/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

#import "SCSRingVibrateHelper.h"
#import "SCSAudioManager.h"
#import "SCPCallManager.h"
#import "SCPCallbackInterface.h"
#import "SCPNotificationKeys.h"
#import "SCSFeatures.h"
#import "AudioPlaybackManager.h"
#import "ProviderDelegate.h"
#import "SCLoggingManager.h"

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelWarning;
//#endif

// Callback methods from CTAudioMacOSX_IOS.h (cross platform interface)

void *t_native_startCB_play(void *ctx, int iRate, int (*cbFnc)(void *, short *, int , int iRestarted), void *cbData){
    
    [SPAudioManager audioUnitStartPlaying:cbData
                         callbackFunction:cbFnc];
    
    return (void*)1;
}

void *t_native_startCB_rec(void *ctx, int iRate, int (*cbFnc)(void *, short *, int ), void *cbData){
    
    [SPAudioManager audioUnitStartRecording:cbData
                           callbackFunction:cbFnc];

    return (void*)1;
}

void t_native_stop(void *ctx, int iPlay){
    
    if(iPlay)
        [SPAudioManager audioUnitStopPlaying];
    else
        [SPAudioManager audioUnitStopRecording];
}

void t_onOverFlow(void *ctx){ }

void t_native_rel(void *ctx){ }

void *getAudioCtx(int iRate, int iRel){ return (void*)1; }

#pragma mark C helper methods

int AudioManager_AudioIsInterrupted() {
    
    return (int)[SPAudioManager audioIsInterrupted];
}

typedef NS_ENUM(NSUInteger, SCSLoudspeakerMode) {
    SCSLoudspeakerModeUnknown,
    SCSLoudspeakerModeEnabled,
    SCSLoudspeakerModeDisabled
};

SCSAudioManager *SPAudioManager = nil;

@interface SCSAudioManager ()
{
    BOOL _remoteControlInstalled;
    BOOL _shouldInstallRemoteControl;
    BOOL _audioIsInterrupted;
    BOOL _audioChainIsBeingReconstructed;
    BOOL _audioUnitIsStarted;
   
   // We do not want to start audio twice in a row without any reason
    BOOL _audioIsStartingNow;
   
    // Audio Unit stuff
    
    AudioStreamBasicDescription _sF_play;
    AudioStreamBasicDescription _sF_rec;
    AudioBufferList *_bufferList;
    
    BOOL _isFirstPacket;
    BOOL _audioUnitIsInitialized;
    BOOL _audioSessionIsInitialized;
    BOOL _hasRecordingStarted;
    BOOL _hasPlaybackStarted;
    
    BOOL _customOverride;
    
    void *_callbackPlaybackData;
    void *_callbackRecordingData;
    
    int (*_callbackPlaybackFunction)(void *, short *, int ,int );
    int (*_callbackRecordingFunction)(void *, short *, int );
}

@property (nonatomic, assign) AudioUnit audioUnit;
@property (nonatomic, strong) SCSRingVibrateHelper *ringVibrateHelper;
@property (nonatomic) SCSLoudspeakerMode currentLoudspeakerMode;

@end

@implementation SCSAudioManager

#pragma mark - Lifecycle

- (instancetype)init {
    
    if(self = [super init]) {
        
        self.ringVibrateHelper = [SCSRingVibrateHelper new];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioNotificationHandler:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioNotificationHandler:)
                                                     name:AVAudioSessionMediaServicesWereResetNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioNotificationHandler:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationStateDidChange:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationStateDidChange:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(callStateDidChange:)
                                                     name:kSCPCallDidEndNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(callStateDidChange:)
                                                     name:kSCPIncomingCallNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(callStateDidChange:)
                                                     name:kSCPCallStateDidChangeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioPlayerWillStartPlaying)
                                                     name:AudioPlayerWillStartPlayingAttachmentNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioPlayerDidFinishPlaying)
                                                     name:AudioPlayerDidFinishPlayingAttachmentNotification
                                                   object:nil];
        
        [[AVAudioSession sharedInstance] addObserver:self
                                          forKeyPath:@"outputVolume"
                                             options:NSKeyValueObservingOptionNew
                                             context:nil];

        _currentLoudspeakerMode = SCSLoudspeakerModeDisabled;
        
        SPAudioManager = self;
    }

    return self;
}

#pragma - mark SystemPermissionManagerDelegate
- (void)performPermissionCheck {
    AVAudioSessionRecordPermission permission = [[AVAudioSession sharedInstance] recordPermission];
    if (permission == AVAudioSessionRecordPermissionUndetermined) {
        // request microphone access
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            [SystemPermissionManager permissionCheckComplete:self];
        }];
    } else
        [SystemPermissionManager permissionCheckComplete:self];
}

- (BOOL)hasPermission {
    return ([[AVAudioSession sharedInstance] recordPermission] == AVAudioSessionRecordPermissionGranted);
}

#pragma mark - Notifications

- (void)audioNotificationHandler:(NSNotification *)notification {

    if([notification.name isEqualToString:AVAudioSessionMediaServicesWereResetNotification]) {
        
        // We don't care about media reset if the audio unit is not started
        if(!_audioUnitIsStarted)
            return;
        
        //NSLog(@"Media server has reset");
        
        _audioChainIsBeingReconstructed = YES;
        
        usleep(25000); //wait here for some time to ensure that we don't delete these objects while they are being accessed elsewhere

        [self audioUnitStart];
        
        _audioChainIsBeingReconstructed = NO;
    }
    else if([notification.name isEqualToString:AVAudioSessionRouteChangeNotification]) {
        
        UInt8 reasonValue = [[notification.userInfo valueForKey: AVAudioSessionRouteChangeReasonKey] intValue];
        
        if(AVAudioSessionRouteChangeReasonCategoryChange == reasonValue) {
            
            //NSLog(@"AVAudioSessionRouteChangeReasonCategoryChange: %@", notification.userInfo);
                        
            // Fix the issue where CallKit automatically
            // overrides the speaker
            // back to the phone when a call ends
            if([ProviderDelegate isEnabled] &&
               [SPCallManager activeCallKitCallCount] == 0 &&
               !_customOverride &&
               ![self loudspeakerIsOn]) {
                
                [self routeAudioToLoudspeaker:YES
        shouldCheckHeadphonesOrBluetoothFirst:YES];
                
                return;
            }
            
            _customOverride = NO;

        } else if(AVAudioSessionRouteChangeReasonOverride == reasonValue) {
            
            //NSLog(@"AVAudioSessionRouteChangeReasonOverride");
            
        } else if (AVAudioSessionRouteChangeReasonNewDeviceAvailable == reasonValue) {
            
            //NSLog(@"AVAudioSessionRouteChangeReasonNewDeviceAvailable");
            
            if(_shouldInstallRemoteControl && [self registerForRemoteControlEvents])
                _shouldInstallRemoteControl = NO;
        }
        else if(AVAudioSessionRouteChangeReasonOldDeviceUnavailable == reasonValue) {
            
            //NSLog(@"AVAudioSessionRouteChangeReasonOldDeviceUnavailable");
    
            [self removeRemoteControlEventsHandler];
        }
        
        _currentLoudspeakerMode = ([self loudspeakerIsOn] ? SCSLoudspeakerModeEnabled : SCSLoudspeakerModeDisabled);
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSAudioStateDidChange
                                                            object:self];
    }
    else if([notification.name isEqualToString:AVAudioSessionInterruptionNotification]) {
        
        UInt8 interruptionType = [[notification.userInfo objectForKey:AVAudioSessionInterruptionTypeKey] intValue];
        
        if(interruptionType == AVAudioSessionInterruptionTypeBegan) {
            
            AudioLogInfo(@"%s INTERRUPTION BEGAN _audioUnitIsStarted: %d", __PRETTY_FUNCTION__, _audioUnitIsStarted);
            
            if(!_audioUnitIsStarted)
                return;
            
            _audioIsInterrupted = YES;
            
            [self audioUnitStop];
        }
        else if(interruptionType == AVAudioSessionInterruptionTypeEnded) {
        
            AudioLogInfo(@"%s INTERRUPTION ENDED -> _audioIsInterrupted: %d", __PRETTY_FUNCTION__, _audioIsInterrupted);

            if(!_audioIsInterrupted)
                return;
                
            _audioIsInterrupted = NO;

            // (Re)start the audio unit only if there
            // is already a call active
            if([SPCallManager activeCallCount] > 0)
                [self audioUnitStart];
        }
    }
}

- (void)applicationStateDidChange:(NSNotification *)notification {
    
    if([notification.name isEqualToString:UIApplicationDidBecomeActiveNotification]) {
        
        if(_shouldInstallRemoteControl && [self registerForRemoteControlEvents])
            _shouldInstallRemoteControl = NO;
        
    } else if ([notification.name isEqualToString:UIApplicationDidEnterBackgroundNotification]) {
        
        if(_remoteControlInstalled && [self removeRemoteControlEventsHandler])
            _shouldInstallRemoteControl = YES;
    }
}

- (void)callStateDidChange:(NSNotification *)notification {
    
    NSUInteger activeCallCount = [SPCallManager activeCallCount];
    
    if(activeCallCount > 0) {
        
        [self registerForRemoteControlEvents];
    }
    else if(activeCallCount == 0) {
        
        _currentLoudspeakerMode = SCSLoudspeakerModeDisabled;
        
        [self routeAudioToLoudspeaker:NO
shouldCheckHeadphonesOrBluetoothFirst:NO];
        
        [self deregisterForRemoteControlEvents];
    }
}

- (void)audioPlayerWillStartPlaying {
    
    [self registerForRemoteControlEvents];
}

- (void)audioPlayerDidFinishPlaying {
    
    NSUInteger activeCallCount = [SPCallManager activeCallCount];

    if(activeCallCount > 0)
        return;
    
    [self deregisterForRemoteControlEvents];
}

#pragma mark - Public

- (BOOL)audioIsInterrupted {
    
    return _audioIsInterrupted;
}

- (BOOL)loudspeakerIsOn {
    
    AVAudioSessionRouteDescription *currentRoute = [[AVAudioSession sharedInstance] currentRoute];
    
    if(!currentRoute)
        return NO;
    
    NSArray *outputs = [currentRoute outputs];
    
    if([outputs count] == 0)
        return NO;
    
    for(AVAudioSessionPortDescription *portDescr in outputs) {
        
        if([[portDescr portType] isEqualToString:AVAudioSessionPortBuiltInSpeaker])
            return YES;
    }
    
    return NO;
}

- (BOOL)deviceAudioIsConnected {
    
    if([self isHeadphoneOrBluetooth])
        return YES;
    
    AVAudioSessionRouteDescription *currentRoute = [[AVAudioSession sharedInstance] currentRoute];
    
    if(!currentRoute)
        return NO;
    
    NSArray *outputs = [currentRoute outputs];
    
    if([outputs count] == 0)
        return NO;
    
    for(AVAudioSessionPortDescription *portDescr in outputs) {
        
        if([[portDescr portType] isEqualToString:AVAudioSessionPortAirPlay])
            return YES;
    }
    
    return NO;
}

- (BOOL)playbackVolumeIsVeryLow {
    
    float volume = [[AVAudioSession sharedInstance] outputVolume];
    
    return volume < 0.1;
}

- (void)setMuteMic:(BOOL)mute {
    
    _micIsMuted = mute;
    
    [Switchboard doCmd:mute? @":mute 1":@":mute 0"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSAudioMuteMicDidChange
                                                            object:self];
    });
}

- (BOOL)bluetoothIsUsed {
    
    AVAudioSessionRouteDescription *currentRoute = [[AVAudioSession sharedInstance] currentRoute];
    
    if(!currentRoute)
        return NO;
    
    NSArray *outputs = [currentRoute outputs];
    
    if([outputs count] == 0)
        return NO;
    
    for(AVAudioSessionPortDescription *portDescr in outputs) {
        
        if([[portDescr portType] isEqualToString:AVAudioSessionPortBluetoothHFP] ||
           [[portDescr portType] isEqualToString:AVAudioSessionPortBluetoothA2DP] ||
           [[portDescr portType] isEqualToString:AVAudioSessionPortBluetoothLE])
            return YES;
    }
    
    return NO;
}

- (BOOL)areHeadphonesConnected {
    
    AVAudioSessionRouteDescription *currentRoute = [[AVAudioSession sharedInstance] currentRoute];
    
    if(!currentRoute)
        return NO;
    
    NSArray *outputs = [currentRoute outputs];
    
    if([outputs count] == 0)
        return NO;
    
    for(AVAudioSessionPortDescription *portDescr in outputs) {
        
        if([[portDescr portType] isEqualToString:AVAudioSessionPortHeadphones])
            return YES;
    }
    
    return NO;
}

- (BOOL)isHeadphoneOrBluetooth {
    
    return ([self bluetoothIsUsed] || [self areHeadphonesConnected]);
}

#pragma mark - Private

- (void)initAudioSession {
    
    if(_audioSessionIsInitialized)
        return;
    
    _audioSessionIsInitialized = YES;
    
    NSError *error = nil;
    
    // Normally we would also add the AVAudioSessionCategoryOptionMixWithOthers option in setCategory:
    // in order for the incoming message sound to be heard when we are on a call,
    // but by adding this option the remote control events feature gets disabled.
    //
    // Ref: https://developer.apple.com/library/ios/qa/qa1566/_index.html
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                                     withOptions:AVAudioSessionCategoryOptionAllowBluetooth
                                           error:&error];
    
    if(error)
        NSLog(@"%s Couldn't set session's audio category. Error: %@", __PRETTY_FUNCTION__, error);
    
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.005
                                                            error:&error];
    
    if(error)
        NSLog(@"%s Couldn't set session's I/O buffer duration. Error: %@", __PRETTY_FUNCTION__, error);
    
    // Check if user has the Airplay mode enabled in Settings
    const char* sendEngMsg(void *pEng, const char *p);
    const char *airplayAvailable = sendEngMsg(NULL,"cfg.iEnableAirplay");
    
    [[AVAudioSession sharedInstance] setMode:(airplayAvailable && airplayAvailable[0] == '1' ? AVAudioSessionModeVideoChat : AVAudioSessionModeVoiceChat)
                                       error:&error];

    if(error)
        NSLog(@"%s Couldn't set session's audio mode. Error: %@", __PRETTY_FUNCTION__, error);
}

- (void)resetAudioSession {
   
    AudioLogInfo(@"%s", __PRETTY_FUNCTION__);
    
    // Stop the audio unit but do not reset the session
    // if there are still active calls
    // (If we do, CallKit is not working properly)
    if([SPCallManager activeCallCount] > 0)
        return;
    
    if(!_audioSessionIsInitialized)
        return;
    
    _audioSessionIsInitialized = NO;
    
    AudioLogInfo(@"Resetting audio session...");
    
    NSError *error = nil;
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient
                                           error:&error];
    
    if(error)
        NSLog(@"%s Couldn't set session's audio category. Error: %@", __PRETTY_FUNCTION__, error);
}

- (void)reportAudioError:(int)errorCode message:(NSString *)errorMessage {
    
    AudioLogError(@"\n%s: %d %@\n", __PRETTY_FUNCTION__, errorCode, errorMessage);
}

#pragma mark - Ringtones and Vibrations

- (BOOL)routeAudioToLoudspeaker:(BOOL)toLoudSpeaker shouldCheckHeadphonesOrBluetoothFirst:(BOOL)checkFirst {
    
    if(!_audioSessionIsInitialized)
        return NO;
    
    if(checkFirst) {
        
        // Do not switch to loudspeaker if the headphones or a BT device are connected
        if([self isHeadphoneOrBluetooth] && toLoudSpeaker)
            return NO;
    }
    
    AVAudioSessionPortOverride port = (toLoudSpeaker ? AVAudioSessionPortOverrideSpeaker : AVAudioSessionPortOverrideNone);
    
    NSError *error = nil;
    
    BOOL ok = [[AVAudioSession sharedInstance] overrideOutputAudioPort:port
                                                                 error:&error];
    
    if(!ok)
        NSLog(@"%s -> Override. Error: %@ -> %@", __PRETTY_FUNCTION__, error, (error.code == AVAudioSessionErrorCodeBadParam ? @"AVAudioSessionErrorCodeBadParam" : @""));
    else
        _customOverride = YES;
    
    return ok;
}

- (void)playIncomingRingtone:(BOOL)isEmergency {

    [self.ringVibrateHelper playIncomingRingtone:isEmergency];
}

- (void)stopIncomingRingtone {
    
    [self.ringVibrateHelper stopIncomingRingtone];
}

- (void)playTestRingtone:(NSString *)ringtoneFilename {
    
    [self.ringVibrateHelper playTestRingtone:ringtoneFilename];
}

- (void)stopTestRingtone {
    
    [self.ringVibrateHelper stopTestRingtone];
}

- (void)playSound:(NSString *)name ofType:(NSString *)ext vibrate:(BOOL)vibrate {

    [self.ringVibrateHelper playSound:name
                               ofType:ext
                              vibrate:vibrate];
}

- (NSArray *)userSelectedTextTone {
    
    const char *getTexttone(const char *p=NULL);
    
    const char *textTone = getTexttone();
    
    if(!textTone)
        return nil;
    
    if(strcmp(textTone, "default") == 0)
        return @[@"received",
                 @"wav"];
    else
        return @[[NSString stringWithCString:textTone
                                    encoding:NSUTF8StringEncoding],
                 @"caf"];
}

- (void)playUserSelectedTextTone {

    NSArray *userSelectedTextTone = [self userSelectedTextTone];
    
    if(userSelectedTextTone && [userSelectedTextTone count] > 1)
        [self playSound:userSelectedTextTone[0]
                 ofType:userSelectedTextTone[1]
                vibrate:YES];
}

- (void)vibrateOnce {
    
    [self.ringVibrateHelper vibrateOnce];
}

- (void)vibrateOnceDuplexStart {
    
    [self.ringVibrateHelper vibrateOnceDuplexStart];
}

- (void)vibrateOnceDuplexStop {

    [self.ringVibrateHelper vibrateOnceDuplexStop];
}

#pragma mark - Remote Control

- (BOOL)registerForRemoteControlEvents {
    
    // Known issue:
    //
    // If user goes back to his music app, tap play and then receives a call,
    // if he goes back to SPi, he won't be able to use the remote control
    // although it is being registered here. Go figure.
    
    if([UIApplication sharedApplication].applicationState == UIApplicationStateBackground || ![self areHeadphonesConnected]) {
        
        _shouldInstallRemoteControl = YES;
        return NO;
    }
    
    if(_remoteControlInstalled)
        return NO;
    
    NSError *error = nil;
    BOOL categoryChanged = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                                                                  error:&error];

    if(!categoryChanged)
        NSLog(@"%s Category not changed. Error: %@", __PRETTY_FUNCTION__, error);

    return [self addRemoteControlEventsHandler];
}

- (BOOL)deregisterForRemoteControlEvents {
    
    
    _shouldInstallRemoteControl = NO;

    return [self removeRemoteControlEventsHandler];
}

- (BOOL)addRemoteControlEventsHandler {
    
    if(_remoteControlInstalled)
        return NO;
    
    [[MPRemoteCommandCenter sharedCommandCenter].togglePlayPauseCommand addTarget:self
                                                                           action:@selector(headsetControlClicked)];

    _remoteControlInstalled = YES;
    
    return YES;
}

- (BOOL)removeRemoteControlEventsHandler {
    
    if(!_remoteControlInstalled)
        return NO;
    
    [[MPRemoteCommandCenter sharedCommandCenter].togglePlayPauseCommand removeTarget:self];

    _remoteControlInstalled = NO;

    return YES;
}

- (MPRemoteCommandHandlerStatus)headsetControlClicked {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCPRemoteControlClickedNotification
                                                            object:self];
    });
    
    return MPRemoteCommandHandlerStatusSuccess;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if([keyPath isEqualToString:@"outputVolume"]) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:KSCSAudioOutputVolumeDidChange
                                                                object:self];
        });
    }
}

#pragma mark - AudioUnits

// Render playback callback function
static OSStatus	renderPlayback (void                         *inRefCon,
                               AudioUnitRenderActionFlags 	*ioActionFlags,
                               const AudioTimeStamp 		*inTimeStamp,
                               UInt32 						inBusNumber,
                               UInt32 						inNumberFrames,
                               AudioBufferList              *ioData)
{
    return [SPAudioManager audioUnitOnAudio:ioData
                                      flags:ioActionFlags
                                  timestamp:inTimeStamp
                                  busNumber:inBusNumber
                               numberFrames:inNumberFrames
                                isRecording:NO];
}

// Render recorder callback function
static OSStatus	renderRecord (void                         *inRefCon,
                                AudioUnitRenderActionFlags 	*ioActionFlags,
                                const AudioTimeStamp 		*inTimeStamp,
                                UInt32 						inBusNumber,
                                UInt32 						inNumberFrames,
                                AudioBufferList              *ioData)
{
    return [SPAudioManager audioUnitOnAudio:ioData
                                      flags:ioActionFlags
                                  timestamp:inTimeStamp
                                  busNumber:inBusNumber
                               numberFrames:inNumberFrames
                                isRecording:YES];
}

// Convenience function to allocate our audio buffers
AudioBufferList *AllocateAudioBL(UInt32 numChannels, UInt32 size) {
    
    AudioBufferList*            list;
    UInt32                      i;
    
    list = (AudioBufferList*)calloc(1, sizeof(AudioBufferList) + numChannels * sizeof(AudioBuffer));
    
    if(list == NULL)
        return NULL;
    
    list->mNumberBuffers = numChannels;
    for(i = 0; i < numChannels; ++i) {
        list->mBuffers[i].mNumberChannels = 1;
        list->mBuffers[i].mDataByteSize = size;
        list->mBuffers[i].mData = NULL;
    }
    return list;
}

- (void)audioUnitStartByProvider {

    [self audioUnitStart];
}

- (void)audioUnitStopByProvider {
    
    AudioLogInfo(@"%s", __PRETTY_FUNCTION__);
    
    [self audioUnitStop];
}

- (void)audioUnitStart {
   
    AudioLogInfo(@"%s", __PRETTY_FUNCTION__);
    
    if(_audioIsStartingNow)
        return;
   
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
       
        if(_audioIsStartingNow)
            return;

        @synchronized (self) {
           
           _audioIsStartingNow = YES;

            [self audioUnitInitialize];
            
            // If AudioUnit has already started, restart it.
            if(_audioUnitIsStarted) {
                
                if(_audioUnit) {
                    
                    OSStatus err = AudioOutputUnitStop(_audioUnit);
                    
                    if (err) {
                        
                        [self reportAudioError:err
                                       message:@"Couldn't stop Apple Voice Processing IO (restart)"];
                        
                        _audioUnitIsStarted = YES;
                    }
                }
            }

            _audioUnitIsStarted = YES;
            
            if(!_audioUnit) {
                
                _audioUnitIsStarted = NO;
                _audioIsStartingNow = NO;
                
                return;
            }
            
            [self allocateBufferList];
            
            __block OSStatus err = AudioOutputUnitStart(_audioUnit);
            
            if (err)
                [self reportAudioError:err
                               message:@"Couldn't start Apple Voice Processing IO"];
            
            if(_audioUnitIsStarted) {
                
                [self vibrateOnceDuplexStart];
                
                if(_currentLoudspeakerMode == SCSLoudspeakerModeDisabled)
                    [self routeAudioToLoudspeaker:NO
            shouldCheckHeadphonesOrBluetoothFirst:NO];
            }
            
            _audioIsStartingNow = NO;
        }
    });
}

- (void)audioUnitStop {

    AudioLogInfo(@"1 %s %d", __PRETTY_FUNCTION__, _audioUnitIsStarted);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        AudioLogInfo(@"2 %s %d", __PRETTY_FUNCTION__, _audioUnitIsStarted);
        
        @synchronized (self) {
            
            if(!_audioUnitIsStarted) {

                // Check if now need to reset the AudioSession
                [self resetAudioSession];
                [self audioUnitDestroy];
                
                return;
            }

            AudioLogInfo(@"3 %s %d", __PRETTY_FUNCTION__, _audioUnitIsStarted);

            _audioUnitIsStarted = NO;
            
            if(!_audioUnit)
                return;
            
            
            OSStatus err = AudioOutputUnitStop(_audioUnit);
            
            AudioLogInfo(@"4 %s %d", __PRETTY_FUNCTION__, _audioUnitIsStarted);

            if (err) {
                
                [self reportAudioError:err message:@"Couldn't stop Apple Voice Processing IO"];
                _audioUnitIsStarted = YES;
            }
            
            if(!_audioUnitIsStarted) {
                
                [self vibrateOnceDuplexStop];
                
                [self resetAudioSession];
                [self audioUnitDestroy];
            }
        }
    });
}

- (void)audioUnitStartPlaying:(void *)playbackData callbackFunction:(int (*)(void *, short *, int, int))callback {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        _isFirstPacket = YES;
        _hasPlaybackStarted = YES;
        _callbackPlaybackFunction = callback;
        _callbackPlaybackData = playbackData;

        if([SPCallManager activeCallKitCallCount] == 0 && _hasRecordingStarted)
            [self audioUnitStart];
    });
}

- (void)audioUnitStartRecording:(void *)recordingData callbackFunction:(int (*)(void *, short *, int))callback {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        _hasRecordingStarted = YES;
        _callbackRecordingFunction = callback;
        _callbackRecordingData = recordingData;
        
        if([SPCallManager activeCallKitCallCount] == 0 && _hasPlaybackStarted)
            [self audioUnitStart];
    });
}

- (void)audioUnitStopPlaying {
 
    _hasPlaybackStarted = NO;
    
    if([SPCallManager activeCallKitCallCount] == 0 && !_hasRecordingStarted)
        [self audioUnitStop];
}

- (void)audioUnitStopRecording {
    
    _hasRecordingStarted = NO;
    
    if([SPCallManager activeCallKitCallCount] == 0 && !_hasPlaybackStarted)
        [self audioUnitStop];
}

- (OSStatus)audioUnitOnAudio:(AudioBufferList *)ioData
                       flags:(AudioUnitRenderActionFlags *)ioActionFlags
                   timestamp:(const AudioTimeStamp *)inTimeStamp
                   busNumber:(UInt32)inOutputBusNumber
                numberFrames:(UInt32)inNumberFrames
                 isRecording:(BOOL)isRecording {
    
    if(!ioData) {
        
        if(isRecording) {
            
            ioData = _bufferList;
            ioData->mBuffers[0].mData = NULL;
        }
    
        OSStatus err = AudioUnitRender(_audioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
        
        if(err)
            return err;
        
        if(!isRecording)
            ioData = _bufferList;
    }
    
    AudioStreamBasicDescription *sf= (isRecording ? &_sF_rec : &_sF_play);
    
    if(inNumberFrames*(sf->mBitsPerChannel>>3)!=ioData->mBuffers[0].mDataByteSize)
        return kAudio_UnimplementedError;

    if(isRecording){
        
        if(_hasRecordingStarted && _callbackRecordingFunction)
            _callbackRecordingFunction(_callbackRecordingData,(short  *)ioData->mBuffers[0].mData, (int)inNumberFrames);
    }
    else {
        
        if(!_hasPlaybackStarted){
            
            memset(ioData->mBuffers[0].mData,0,ioData->mBuffers[0].mDataByteSize);
            return noErr; // ??
        }
        
        if(_hasPlaybackStarted && _callbackRecordingFunction){

            _callbackPlaybackFunction(_callbackPlaybackData,(short  *)ioData->mBuffers[0].mData, (int)inNumberFrames, _isFirstPacket);
            _isFirstPacket = NO;
        }
    }
    
    return noErr;
}

// Note: It should be called under @synchronized(self)
// (Look at callers)
- (void)audioUnitDestroy {

    AudioLogInfo(@"0 %s", __PRETTY_FUNCTION__);

    // Dispose the audio unit only if
    // there are no active calls
    if([SPCallManager activeCallCount] > 0)
        return;
    
    AudioLogInfo(@"1 %s", __PRETTY_FUNCTION__);

    if(!_audioUnitIsInitialized)
        return;
    
    AudioLogInfo(@"2 %s", __PRETTY_FUNCTION__);
    
    if(_audioUnit == NULL)
        return;
    
    AudioLogInfo(@"3 %s", __PRETTY_FUNCTION__);
    
    OSStatus err = AudioComponentInstanceDispose(_audioUnit);
    
    if (err) {
        
        [self reportAudioError:(int)err message:@"AudioComponentInstanceDispose"];
        return;
    }
    
    _audioUnit = NULL;
    _audioUnitIsInitialized = NO;
}

- (void)audioUnitInitialize {
    
    @synchronized (self) {

       [self initAudioSession];
       
       if(_audioUnitIsInitialized)
          return;
       
       _audioUnitIsInitialized = YES;

        AudioComponentDescription desc;
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;
        
        AudioComponent comp = AudioComponentFindNext(NULL, &desc);
        
        if (comp == NULL) {
            
            [self reportAudioError:-1 message:@"AudioComponentFindNext"];
            return;
        }
        
        OSStatus err = noErr;
        
        // Get the AudioUnit
        err = AudioComponentInstanceNew(comp, &_audioUnit);
        
        if (_audioUnit == NULL || err) {
            
            [self reportAudioError:(int)err message:@"AudioComponentInstanceNew"];
            return;
        }
        
        UInt32 one = 1;
        
        // Enable input
        err = AudioUnitSetProperty(_audioUnit,
                                   kAudioOutputUnitProperty_EnableIO,
                                   kAudioUnitScope_Input,
                                   1,
                                   &one,
                                   sizeof(one));
        if (err != noErr) {
            
            [self reportAudioError:(int)err message:@"AudioUnitSetProperty kAudioOutputUnitProperty_EnableIO Input"];
            return;
        }
        
        // Enable output
        err = AudioUnitSetProperty(_audioUnit,
                                   kAudioOutputUnitProperty_EnableIO,
                                   kAudioUnitScope_Output,
                                   0,
                                   &one,
                                   sizeof(one));
        
        if (err != noErr) {
            
            [self reportAudioError:(int)err message:@"AudioUnitSetProperty kAudioOutputUnitProperty_EnableIO Output"];
            return;
        }
        
        memset(&_sF_play,0,sizeof(AudioStreamBasicDescription));
        memset(&_sF_rec,0,sizeof(AudioStreamBasicDescription));
        
        _sF_play.mSampleRate = 16000;
        _sF_play.mFormatID = kAudioFormatLinearPCM;
        _sF_play.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger
        | kAudioFormatFlagsNativeEndian
        | kLinearPCMFormatFlagIsPacked
        | kAudioFormatFlagIsNonInterleaved;
        _sF_play.mBytesPerPacket = 2;
        _sF_play.mFramesPerPacket = 1;
        _sF_play.mBytesPerFrame = 2;
        _sF_play.mChannelsPerFrame = 1;
        _sF_play.mBitsPerChannel = 16;
        
        err = AudioUnitSetProperty (_audioUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output,
                                    1,
                                    &_sF_play,
                                    sizeof(_sF_play));
        
        if(err) {
            
            [self reportAudioError:(int)err message:@"AudioUnitSetProperty StreamFormat Output"];
            return;
        }
        
        err = AudioUnitSetProperty (_audioUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input,
                                    0,
                                    &_sF_play,
                                    sizeof(_sF_play));
        
        if(err) {
            
            [self reportAudioError:(int)err message:@"AudioUnitSetProperty StreamFormat Input"];
            return;
        }
        
        memcpy(&_sF_rec,&_sF_play,sizeof(AudioStreamBasicDescription));
        
        // Set up callback functions
        
        // Playback
        AURenderCallbackStruct inputP;
        inputP.inputProc = renderPlayback;
        inputP.inputProcRefCon = NULL;
        
        err = AudioUnitSetProperty (_audioUnit,
                                    kAudioUnitProperty_SetRenderCallback,
                                    kAudioUnitScope_Input,
                                    0,
                                    &inputP,
                                    sizeof(inputP));
        
        if(err) {
            
            [self reportAudioError:(int)err message:@"AudioUnitSetProperty SetRenderCallback"];
            return;
        }
        
        // Record
        AURenderCallbackStruct inputR;
        inputR.inputProc = renderRecord;
        inputR.inputProcRefCon = NULL;
        
        err = AudioUnitSetProperty(_audioUnit,
                                   kAudioOutputUnitProperty_SetInputCallback,
                                   kAudioUnitScope_Global,
                                   1,
                                   &inputR,
                                   sizeof(inputR));
        
        if (err) {
            
            [self reportAudioError:(int)err message:@"AudioUnitSetProperty SetInputCallback"];
            return;
        }

        [self allocateBufferList];
        
        // Initialize AudioUnit
        err = AudioUnitInitialize(_audioUnit);
        
        if (err) {
            
            [self reportAudioError:(int)err message:@"AudioUnitInitialize"];
            
            if(_audioUnit) {
                
                err = AudioUnitReset (_audioUnit, kAudioUnitScope_Global, 1);
                
                if (err)
                    [self reportAudioError:(int)err message:@"AudioUnitReset kAudioUnitScope_Global"];
            }
        }
    }
}

- (void)allocateBufferList {
    
    if(_bufferList)
        free(_bufferList);
    
    unsigned int as = 256;
    
    _bufferList = AllocateAudioBL(_sF_rec.mChannelsPerFrame,as*_sF_rec.mBitsPerChannel>>3);
}

@end
