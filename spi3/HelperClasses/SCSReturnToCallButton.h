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
//  SCSReturnToCallButton.h
//  
//
//  Created by Stelios Petrakis on 13/01/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString *kSCPHeaderStripTappedNotification;

/**
 The SCSReturnToCall button creates a red ribbon in the status bar (40 pixels height)
 that displays a flashing indication with the message 'Touch to return to call' alongside the duration of the call. 
 */
@interface SCSReturnToCallButton : UIButton

/**
 Presents the header strip with animation.
 */
- (void)present;

/**
 Dismisses the header strip with animation.
 */
- (void)dismiss;

/**
 Returns whether the header strip is visible.
 */
- (BOOL)isVisible;

/**
 Initiates the flashing animation on the text of the header strip.
 */
- (void)beginFlashingAnimation;

/**
 Stops the flashing animation on the text of the header strip.
 */
- (void)endFlashingAnimation;

/**
 Returns the height of the header strip.
 */
- (float)height;

@end