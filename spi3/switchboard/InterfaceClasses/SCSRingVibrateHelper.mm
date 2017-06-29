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
//  SCSRingVibrateHelper.m
//  SPi3
//
//  Created by Stelios Petrakis on 21/07/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import "SCSRingVibrateHelper.h"
#import "SCSAudioManager.h"
#import "SCPCallManager.h"

const char * getRingtone(const char *p=NULL);
const char * getEmergencyRingtone(void);

@interface SCSRingVibrateHelper ()
{
    SystemSoundID _testRingtoneSSID;
    
    SystemSoundID _incomingRingtoneSSID;
    
    int _ringRepCount;
    int _vibrRepCount;
    
    BOOL _isPlayingIncomingRingtone;
    
    BOOL _isDuplexPlaying;
    BOOL _shouldVibrateOnce;
    NSTimeInterval _storedTimeInterval;
}

@end

@implementation SCSRingVibrateHelper

#pragma mark - Lifecycle

- (instancetype)init {
    
    if(self = [super init]) {
        
        _testRingtoneSSID = 0;
        
        _isPlayingIncomingRingtone = NO;
        _incomingRingtoneSSID = 0;
        _ringRepCount = 0;
        _vibrRepCount = 0;
        
        _isDuplexPlaying = NO;
        _shouldVibrateOnce = NO;
    }
    
    return self;
}

#pragma mark - Public


//afconvert -f caff -d aac  -c 1 telephone-ring.wav ring.caf

- (void)playIncomingRingtone:(BOOL)isEmergency {
    
    BOOL isInBackground = ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground);
    
    if(!isInBackground && _incomingRingtoneSSID)
        return;
    
    if(_isPlayingIncomingRingtone)
        return;

    _ringRepCount = 0;
    _vibrRepCount = 0;
    _isPlayingIncomingRingtone = YES;
    
    // If the app is in foreground, create the ringtone
    // otherwise let the push notification play the ringtone sound
    if(!isInBackground) {

       NSString *ringtoneFilename = [NSString stringWithCString:isEmergency? getEmergencyRingtone(): getRingtone()
                                                        encoding:NSUTF8StringEncoding];

        NSString *ringtonePath = [[NSBundle mainBundle] pathForResource:ringtoneFilename
                                                                 ofType:@"caf"];
        
        NSURL *ringtoneURL = [NSURL fileURLWithPath:ringtonePath];
        
        AudioServicesCreateSystemSoundID((__bridge CFURLRef)ringtoneURL, &_incomingRingtoneSSID);
        
        if(!_incomingRingtoneSSID)
            return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        if(isInBackground) {
            
            // Delay the first vibration cause the first one will be issued
            // by the incoming call notification
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.25 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                               AudioServicesPlayAlertSoundWithCompletion(kSystemSoundID_Vibrate, ^{
                                   [self incomingVibrationCompletion];
                               });
                           });
            
        } else {
            
            // Switch to loudspeaker only if headphones or BT aren't connected
            if(![SPAudioManager loudspeakerIsOn] && [SPCallManager activeCallCount] == 0)
                [SPAudioManager routeAudioToLoudspeaker:YES
                  shouldCheckHeadphonesOrBluetoothFirst:YES];
            
            AudioServicesPlayAlertSoundWithCompletion(kSystemSoundID_Vibrate, ^{
                [self incomingVibrationCompletion];
            });
            
            AudioServicesPlayAlertSoundWithCompletion(_incomingRingtoneSSID, ^{
                [self incomingRingtoneCompletion];
            });
        }
    });
}

- (void)stopIncomingRingtone {
    
    if(!_isPlayingIncomingRingtone)
        return;
    
    _isPlayingIncomingRingtone = NO;
    
    if(!_incomingRingtoneSSID)
        return;
    
    AudioServicesDisposeSystemSoundID(_incomingRingtoneSSID);
    
    _incomingRingtoneSSID = 0;
}

- (void)playTestRingtone:(NSString *)ringtoneFilename {

    NSString *ringtonePath = [[NSBundle mainBundle] pathForResource:ringtoneFilename
                                                             ofType:@"caf"];
    
    NSURL *ringtoneURL = [NSURL fileURLWithPath:ringtonePath];
    
    SystemSoundID ssid = 0;

    AudioServicesCreateSystemSoundID((__bridge CFURLRef)ringtoneURL, &ssid);
        
    if(!ssid)
        return;

    if(![SPAudioManager loudspeakerIsOn] && [SPCallManager activeCallCount] == 0)
        [SPAudioManager routeAudioToLoudspeaker:YES
          shouldCheckHeadphonesOrBluetoothFirst:YES];
    
    [self stopTestRingtone];

    _testRingtoneSSID = ssid;
    
    AudioServicesPlayAlertSoundWithCompletion(ssid, ^{
        [self stopTestRingtone:ssid];
    });
}

- (void)stopTestRingtone {
    
    [self stopTestRingtone:_testRingtoneSSID];
}

- (void)vibrateOnce {
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        if(_isDuplexPlaying) {
            
            _storedTimeInterval = [[NSDate date] timeIntervalSince1970];
            _shouldVibrateOnce = YES;
            
        } else {
            
            _shouldVibrateOnce = NO;
            
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
        }
    });
}

- (void)playSound:(NSString *)name ofType:(NSString *)ext vibrate:(BOOL)vibrate {
    
    NSString *ringtonePath = [[NSBundle mainBundle] pathForResource:name
                                                             ofType:ext];
    
    NSURL *ringtoneURL = [NSURL fileURLWithPath:ringtonePath];
    
    SystemSoundID ssid = 0;
    
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)ringtoneURL, &ssid);
    
    if(!ssid)
        return;
    
    if(![SPAudioManager loudspeakerIsOn] && [SPCallManager activeCallCount] == 0)
        [SPAudioManager routeAudioToLoudspeaker:YES
          shouldCheckHeadphonesOrBluetoothFirst:YES];
    
    if(vibrate)
        AudioServicesPlayAlertSound(ssid);
    else
        AudioServicesPlaySystemSound(ssid);
}

#pragma mark - Private

- (void)stopTestRingtone:(SystemSoundID)ssid {
    
    if(!ssid)
        return;
    
    if(ssid != _testRingtoneSSID)
        return;
    
    SystemSoundID tempSSid = ssid;
    ssid = 0;
    AudioServicesDisposeSystemSoundID(tempSSid);
}

- (void)vibrateOnceDuplexStart {
    
    _isDuplexPlaying = YES;
}

- (void)vibrateOnceDuplexStop {
    
    _isDuplexPlaying = NO;
    
    if(_shouldVibrateOnce) {
        
        _shouldVibrateOnce = NO;
        
        NSTimeInterval seconds = [[NSDate date] timeIntervalSince1970] - _storedTimeInterval;
        
        if(seconds < 5)
            [self vibrateOnce];
    }
}

- (void)incomingVibrationCompletion {
    
    if(!_isPlayingIncomingRingtone)
        return;
    
    BOOL isInBackground = ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground);

    _vibrRepCount++;
    
    if(_vibrRepCount >= 32) {
        
        if(isInBackground)
            [self stopIncomingRingtone];
        
        return;
    }
    
    if(!_isPlayingIncomingRingtone)
        return;
    
    AudioServicesPlayAlertSoundWithCompletion(kSystemSoundID_Vibrate, ^{
        [self incomingVibrationCompletion];
    });
}

- (void)incomingRingtoneCompletion {

    if(!_isPlayingIncomingRingtone)
        return;
    
    _ringRepCount++;
    
    if(_ringRepCount >= 60) {
        
        [self stopIncomingRingtone];
        return;
    }
    
    if(!_isPlayingIncomingRingtone)
        return;
    
    AudioServicesPlayAlertSoundWithCompletion(_incomingRingtoneSSID, ^{
        [self incomingRingtoneCompletion];
    });
}

@end
