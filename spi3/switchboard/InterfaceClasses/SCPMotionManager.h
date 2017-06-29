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
//  SCPMotionManager.h
//  SP3
//
//  Created by Eric Turner on 5/25/15.
//  Based on original work by Janis Narbuts SP1
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

#import <CoreMotion/CoreMotion.h>

/**
 * An iPod-specific feature.  
 *
 * Used by UI to enable/disable call screen buttons when user puts
 * device to ear.
 *
 * History:  
 * In SP1 AppDelegate, the startMotionDetect method would  
 *
 * Question:
 * Could DeviceOrientation be used for "proximity sensing"?  
 *
 * Answer:
 * User may turn off rotation off in Settings or Control Center screen  
 * - will this prevent detection of updside down orientation detection?   
 * UpsideDown orientation would disable touch on dialPad, similar to  
 * how the accelerometer detects updside down state by gravity.  
 *
 * (Maybe UIDeviceOrientation is a convenience wrapper for system 
 * accelerometer methods)
 *
 * @see tryShowCallScrMT for iPhone proximity handling
 */
@interface SCPMotionManager : CMMotionManager

@property (assign, nonatomic, readonly) BOOL isOn;
@property (copy, nonatomic) NSString *currentDataLog;

- (void)start;
- (void)stop;

@end
