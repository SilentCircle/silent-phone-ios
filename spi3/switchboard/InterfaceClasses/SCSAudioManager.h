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
//  SCSAudioManager.h
//  SPi3
//
//  Created by Eric Turner on 11/11/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>
#import "SystemPermissionManager.h"

@class SCSAudioManager;

extern SCSAudioManager *SPAudioManager;

@interface SCSAudioManager : NSObject <SystemPermissionManagerDelegate>

/**
 Mutes the microphone and reports the muted status.
 */
@property (nonatomic, assign, setter=setMuteMic:) BOOL micIsMuted;

- (BOOL)audioIsInterrupted;

/**
 Reports whether a headset, a bluetooth or an AirPlay device is currenty connected in the device.
 
 @return YES if headset or a bluetooth device, or AirPlay is connected, NO otherwise
 */
- (BOOL)deviceAudioIsConnected;

/**
 Reports whether the output volume is set really low in the device (less than 0.1).
 
 @return YES if the output volume is low, NO otherwise
 */
- (BOOL)playbackVolumeIsVeryLow;

/**
 Reports whether the loudspeaker is currently active on the device.
 
 @return YES if the loudspeaker is active, NO otherwise
 */
- (BOOL)loudspeakerIsOn;

/**
 Reports whether a bluetooth device is currenty connected in the device.
 
 @return YES if a bluetooth device is connected, NO otherwise
 */
- (BOOL)bluetoothIsUsed;

/**
 Reports whether a headset or a bluetooth device is currenty connected in the device.
 
 @return YES if headset or a bluetooth device is connected, NO otherwise
 */
- (BOOL)isHeadphoneOrBluetooth;

/**
 Routes audio to the loudspeaker or the internal headset.
 
 @param toLoudspeaker YES to switch to the loudspeaker, NO to switch to internal headset
 @param checkFirst Use this parameter to first check if there is a headset or a BT device connected. If there is and the toLoudSpeaker is set to YES, then the routing is cancelled.
 
 @return YES if the audio has been routed successfully, NO otherwise
 */
- (BOOL)routeAudioToLoudspeaker:(BOOL)toLoudSpeaker shouldCheckHeadphonesOrBluetoothFirst:(BOOL)checkFirst;

#pragma mark - Remote Control Events

/**
 Listens for remote control events when there's a call (called by CallManager).
 
 @returns YES if the registration has occured, NO otherwise
 */
- (BOOL)registerForRemoteControlEvents;

/**
 Stops listening for remote control events (called by CallManager).

 @returns YES if the deregistration has occured, NO otherwise
 */
- (BOOL)deregisterForRemoteControlEvents;

#pragma mark - Ringtones and Vibrations

/**
 Plays the ringtone along with a vibration for an incoming call.
 
 Depending on whether the app is in the foreground or not it generates the sound or it leaves the sound generation to the push notification
 */
- (void)playIncomingRingtone:(BOOL)isEmergency;

/**
 Stops playing the incoming ringtone.
 */
- (void)stopIncomingRingtone;

/**
 Plays the ringtone for testing purposes (used in settings).
 
 @param ringtoneFilename The filename of the ringtone that exists in the main app bundle (without the file extension)
 */
- (void)playTestRingtone:(NSString *)ringtoneFilename;

/**
 Stops playing the test ringtone
 */
- (void)stopTestRingtone;

/**
 Plays a sound that exists in the main app bundle

 @param name The sound name
 @param ext The sound extension
 @param vibrate YES in order to vibrate the device, NO otherwise
 */
- (void)playSound:(NSString *)name ofType:(NSString *)ext vibrate:(BOOL)vibrate;

/**
 Returns the user selected text tone

 @return The user selected text tone array ( [0] => filename [1] => extension )
 */
- (NSArray *)userSelectedTextTone;

/**
 Plays back the user selected text tone using System Services API
 */
- (void)playUserSelectedTextTone;

/**
 Creates a single vibration when the remote user hangs up the call,
 after making sure that the audio has stopped.
 */
- (void)vibrateOnce;

#pragma mark - Audio Units

- (void)audioUnitInitialize;

- (void)audioUnitStartByProvider;
- (void)audioUnitStopByProvider;

- (void)audioUnitStartPlaying:(void *)playData callbackFunction:(int (*)(void *, short *, int, int))callback;
- (void)audioUnitStartRecording:(void *)recordingData callbackFunction:(int (*)(void *, short *, int))callback;

- (void)audioUnitStopPlaying;
- (void)audioUnitStopRecording;

- (OSStatus)audioUnitOnAudio:(AudioBufferList *)ioData
                       flags:(AudioUnitRenderActionFlags *)ioActionFlags
                   timestamp:(const AudioTimeStamp *)inTimeStamp
                   busNumber:(UInt32)inOutputBusNumber
                numberFrames:(UInt32)inNumberFrames
                 isRecording:(BOOL)isRecording;

@end
