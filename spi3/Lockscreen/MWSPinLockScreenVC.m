/*
Copyright (C) 2014-2017, Silent Circle, LLC.  All rights reserved.

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
//  MWSPinLockScreenVC.m
//  ST2
//
//  Created by Eric Turner on 7/1/14.
//  Copyright (c) 2014 MagicWave Software LLC. All rights reserved.
//

#import "MWSPinLockScreenVC.h"
#import "MWSShapeButton.h"
#import "MWSPinLockKeypad.h"
#import "MWSPinLockScreenConstants.h"

#import "UIImage+ETAdditions.h"
#import "UIImage+ImageEffects.h"

@interface MWSPinLockScreenVC () <MWSPinLockKeypadDelegate>
{
    NSString *_initialLabelTitle;
    NSString *_labelTitle;
    
    NSTimer *_failedAttemptsTimer;
}

@property (copy) void (^completion)(MWSPinLockScreenVC *pinLockScreenVC, NSString *passcode);

//@property (weak, nonatomic) IBOutlet UIImageView *bgImgView;
@property (weak, nonatomic) IBOutlet MWSPinLockKeypad *lockPadView;

@end

@implementation MWSPinLockScreenVC

#pragma mark - Lifecycle

/**
 * Invoke when app resigns active to background.
 *
 * @return A configured MTSLockScreenVC instance.
 */
- (instancetype)initWithLabelTitle:(NSString *)labelTitle completion:(void (^)(MWSPinLockScreenVC *pinLockScreenVC, NSString *passcode))completion {

    UIStoryboard *sbLock = [UIStoryboard storyboardWithName:@"Lockscreen"
                                                     bundle:nil];

    self = [sbLock instantiateInitialViewController];
    
    if (!self)
        return nil;
    
    _completion = completion;
    _labelTitle = labelTitle;
    _initialLabelTitle = labelTitle;
//    _backgroundImage = [[UIImage imageFromScreen] applyDarkEffect];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lockScreenCheckAppDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lockScreenCheckAppDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    return self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self invalidateFailedAttemptsTimer];
}

- (void)viewDidLoad {
    
    [super viewDidLoad];

    [_lockPadView setLabelTitle:_labelTitle clearDots:NO];
//    [_bgImgView setImage:_backgroundImage];
}


#pragma mark - UIViewController

-(UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

-(UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - MTSPinLockPadViewDelegate

- (void)lockPadSelectedButtonTitles:(NSArray *)arrTitles {
    
    NSString *passcode = [arrTitles componentsJoinedByString:@""];
   
    if(_completion)
        _completion(self, passcode);
}

- (void)lockPadSelectedCancel {
    if ([_delegate respondsToSelector: @selector(lockScreenSelectedCancel:)]) {
        [_delegate lockScreenSelectedCancel:self];
    }
}

- (BOOL)shouldShowCancelButton {
    return [_delegate respondsToSelector:@selector(lockScreenSelectedCancel:)];
}

#pragma mark - Public

- (void)enableTouchIDtarget:(id)target action:(SEL)action {

    [_lockPadView enableTouchIDtarget:target action:action];
}

- (void)setLabelTitle:(NSString *)labelTitle clearDots:(BOOL)shouldClearDots {

    _labelTitle = labelTitle;
    
    [_lockPadView setLabelTitle:_labelTitle clearDots:shouldClearDots];
}

- (void)animateInvalidEntryResponse {
    [self animateInvalidEntryResponseWithText:nil completion:nil];
}

- (void)animateInvalidEntryResponseWithText:(NSString *)text completion:(void (^)(void))completion {
    [_lockPadView animateInvalidEntryResponseWithText:text completion:completion];
}

- (void)setBottomText:(NSString *)text {
    [_lockPadView setBottomText:text];
}

- (void)setUserInteractionEnabled:(BOOL)enabled {
    [_lockPadView.mainButtonsView setUserInteractionEnabled:enabled];
}

- (void)updateLockScreenStatus {
    
    if(!_passcodeManager)
        return;
    
    NSInteger numberOfFailedAttempts = [_passcodeManager numberOfFailedAttempts];
    
    if(numberOfFailedAttempts > 0) {
        
        NSString *failedAttempts = [NSString stringWithFormat:@"%ld %@ %@",
                                    (long)numberOfFailedAttempts,
                                    NSLocalizedString(@"Failed Passcode", nil),
                                    (numberOfFailedAttempts == 1 ? NSLocalizedString(@"Attempt", nil) : NSLocalizedString(@"Attempts", nil))];
        
        [self setBottomText:failedAttempts];
    }
    
    BOOL isPasscodeLocked = [_passcodeManager isPasscodeLocked];
    
    if(!isPasscodeLocked) {
        
        [self invalidateFailedAttemptsTimer];
        
        [self setUserInteractionEnabled:YES];
        
        [self setLabelTitle:_initialLabelTitle
                  clearDots:NO];
    }
    else {
        
        [self setupFailedAttemptsTimer];
        
        [self setUserInteractionEnabled:NO];
        
        [self setLabelTitle:[_passcodeManager tryAgainInString]
                  clearDots:YES];
        
    }
}

#pragma mark - Private

- (void)lockScreenCheckAppDidBecomeActive {
    
    [self setupFailedAttemptsTimer];
}

- (void)lockScreenCheckAppDidEnterBackground {
    
    [self invalidateFailedAttemptsTimer];
}

- (void)invalidateFailedAttemptsTimer {
    
    if(!_failedAttemptsTimer)
        return;
    
    [_failedAttemptsTimer invalidate];
    _failedAttemptsTimer = nil;
}

- (void)setupFailedAttemptsTimer {
    
    [self invalidateFailedAttemptsTimer];
    
    if(!_passcodeManager)
        return;
    
    if(![_passcodeManager isPasscodeLocked])
        return;
    
    if([_passcodeManager secondsUntilUnlock] < 60)
        return;
    
    _failedAttemptsTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)60
                                                             target:self
                                                           selector:@selector(failedAttemptsTimerUpdate:)
                                                           userInfo:nil
                                                            repeats:NO];
}

- (void)failedAttemptsTimerUpdate:(NSTimer *)timer {
    
    if(!_passcodeManager)
        return;
    
    [self setLabelTitle:[_passcodeManager tryAgainInString]
              clearDots:YES];
    
    [self setupFailedAttemptsTimer];
}

@end
