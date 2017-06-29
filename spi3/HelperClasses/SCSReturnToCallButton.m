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
//  SCSReturnToCallButton.m
//
//
//  Created by Stelios Petrakis on 13/01/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "SCSReturnToCallButton.h"
#import "../AppDelegate.h"
#import "SCPNotificationKeys.h"
#import "ChatUtilities.h"
#import "SCPCallManager.h"
#import "SCPCall.h"

NSString *kSCPHeaderStripTappedNotification = @"SCPHeaderStripTappedNotification";

@interface SCSReturnToCallButton () {
    
    NSTimer *_durationTimer;
    BOOL _isVisible;
}

@property (nonatomic, strong) IBOutlet NSLayoutConstraint *heightConstraint;
@property (nonatomic, strong) IBOutlet UILabel *label;

@end

@implementation SCSReturnToCallButton

#pragma mark - Lifecycle

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    
    if(self = [super initWithCoder:aDecoder]) {
        
        [self setup];
    }
    
    return self;
}

- (void)dealloc {
    
    [_durationTimer invalidate];
}

#pragma mark - Public

- (void)present {

    if(_isVisible)
        return;
    
    [self setIsAccessibilityElement:YES];
    
    _isVisible = YES;
    
    [self setText:[self backToCallText]];

    [self beginFlashingAnimation];
    
    _heightConstraint.constant = 40.;
    [[NSNotificationCenter defaultCenter] postNotificationName:kSCPWillShowHeaderStrip object:self userInfo:@{kSCPConstraintDictionaryKey:_heightConstraint}];
    [UIView animateWithDuration:.25
                     animations:^{
                         [self setBackgroundColor:[UIColor colorWithRed:235./255. green:77./256. blue:61./256. alpha:1.]];
                         [self.superview layoutIfNeeded];
                     }
                     completion:^(BOOL finished) {
                         UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self);
                     }];
}

- (void)dismiss {
    
    if(!_isVisible)
        return;
    
    [self setIsAccessibilityElement:NO];
    
    _isVisible = NO;
    
    [self endFlashingAnimation];

    _heightConstraint.constant = 20;
    [[NSNotificationCenter defaultCenter] postNotificationName:kSCPWillHideHeaderStrip object:self userInfo:@{kSCPConstraintDictionaryKey:_heightConstraint}];
    [UIView animateWithDuration:.25
                     animations:^{
                         [self setBackgroundColor:[ChatUtilities utilitiesInstance].kNavigationBarColor];
                         [_label setAlpha:0];
                         [self.superview layoutIfNeeded];
                     }];
}

- (BOOL)isVisible {
    
    return _isVisible;
}

- (float)height {
    return _heightConstraint.constant;
}

- (void)setText:(NSString*)text {
    
    NSString *touchToReturnString = NSLocalizedString(@"Touch to return to call", nil);
    
    if(text && [text length] > 0)
        [_label setText:[NSString stringWithFormat:@"%@ • %@", touchToReturnString, text]];
    else
        [_label setText:touchToReturnString];
}

- (void)beginFlashingAnimation {
    
    if(!_isVisible)
        return;
    
    [_label setAlpha:1.];
    
    // Flashing animation
    [UIView animateWithDuration:1.
                          delay:0
                        options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat
                     animations:^{ [_label setAlpha:0]; }
                     completion:nil];
}

- (void)endFlashingAnimation {
    
    if(!_isVisible)
        return;
        
    [self.layer removeAllAnimations];
    [_label setAlpha:1.];
}

#pragma mark - Private

//- (void)initialize {
- (void)setup {
    
    [self setBackgroundColor:[ChatUtilities utilitiesInstance].kNavigationBarColor];
    
    [self setIsAccessibilityElement:NO];
    [self setAccessibilityLabel:NSLocalizedString(@"Return to call", nil)];
    
    [self setText:[self backToCallText]];
    
    // Timer that calls the delegate method
    _durationTimer = [NSTimer scheduledTimerWithTimeInterval:1. target:self selector:@selector(updateTimer) userInfo:nil repeats:YES];
    
    // Get notified when the status bar is tapped (from the AppDelegate notification)
    // and send the button actions for the ReturnToCallButton object
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(statusBarTapped)
                                                 name:kSCPStatusBarTappedNotification
                                               object:nil];
    
    // Get notified when the app is backgrounded and foregrounded in order
    // to stop/start the flashing animation
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appBackgrounded)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appForegrounded)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [self addTarget:self action:@selector(stripTapped) forControlEvents:UIControlEventTouchDown];
}

- (void)appForegrounded {

    [self beginFlashingAnimation];
}

- (void)appBackgrounded {

    [self endFlashingAnimation];
}

- (void)statusBarTapped {
    
    if(!_isVisible)
        return;

    AppDelegate *appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    
    // If we are already showing a VC (like the UIImagePicker) then do not fire the
    // status bar tapped event
    if(appDelegate.window.rootViewController.presentedViewController)
        return;
    
    [self sendActionsForControlEvents:UIControlEventTouchDown];
}

- (void)stripTapped {
    
    if(!_isVisible)
        return;

    [[NSNotificationCenter defaultCenter] postNotificationName:kSCPHeaderStripTappedNotification
                                                        object:self];
}

- (void)updateTimer {
    
    if(!_isVisible)
        return;
    
    [self setText:[self backToCallText]];
}

- (NSString *)backToCallText {
    
    NSUInteger cntCalls = [SPCallManager activeCallCount];
    
    if(cntCalls > 1)
        return [NSString stringWithFormat:@"%d %@", (int)cntCalls, NSLocalizedString(@"calls", nil)];
    
    if(cntCalls <= 0)
        return nil;
    
    SCPCall *selectedCall = (SCPCall *)[[SPCallManager activeCalls] objectAtIndex:0];
    
    if(!selectedCall)
        return nil;
    
    if(!selectedCall.isAnswered)
        return nil;
    
    return [selectedCall durationString];
}

@end
