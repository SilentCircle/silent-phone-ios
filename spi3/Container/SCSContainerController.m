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
//  SCSContainerController.m
//  SPi3
//
//  Created by Stelios Petrakis on 28/03/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "SCSContainerController.h"
#import "SCSReturnToCallButton.h"

#import "AppDelegate.h"
#import "CallScreenVC.h"
#import "ChatObject.h"
#import "ChatViewController.h"
#import "ChatUtilities.h"
#import "SCSMainTVC.h"
#import "MWSPinLockScreenVC.h"
#import "SCDataDestroyer.h"
#import "SCPPasscodeManager.h"
#import "SCPCall.h"
#import "SCPCallHelper.h"
#import "SCPCallbackInterface.h"
#import "SCPCallManager.h"
#import "SCPNotificationKeys.h"
#import "SCSCallNavigationVC.h"
#import "SCSConferenceCVC.h"
#import "SCSConferenceTVC.h"
#import "SCSpinnerView.h"
#import "SCSSearchViewController.h"
#import "SCVideoVC.h"

#import "UIImage+ETAdditions.h"
#import "UIImage+ImageEffects.h"
#import "Silent_Phone-Swift.h"

//#pragma mark Logging
//#if DEBUG && eric_turner
//static const DDLogLevel ddLogLevel = DDLogLevelAll;
//#elif DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelDebug;     
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelWarning; 
//#endif


@interface SCSContainerController () <MWSPinLockScreenDelegate, UIGestureRecognizerDelegate>
{
    BOOL _showBlurScreen;
    SCPPasscodeManager *_passcodeManager;
    BOOL _shouldShowLockScreen;
    NSTimer *_failedAttemptsTimer;
    void (^_passcodeCompletion)(void);
    
    int _wipeSecondsLeft;
    NSTimer *_wipeTimer;
    SCSpinnerView *_wipeSpinnerView;
    MWSPinLockScreenVC *_activeLockScreenVC;
    
    BOOL _isPresentingCallNav;
    BOOL _isDismissingCallNav;
    BOOL _suppressCallNavDismissal;
}

@property (weak, nonatomic) IBOutlet SCSReturnToCallButton *returnToCallButton;
@property (weak, nonatomic) IBOutlet UIImageView *lockedOverlayImageView;
@property (weak, nonatomic) IBOutlet UIView *lockedOverlayContainer;
@property (weak, nonatomic) IBOutlet UILabel *lockedOverlayLabel;
@property (weak, nonatomic) IBOutlet UILabel *lockedOverlaySublabel;

/*
 * The callNavVC is a custom container VC which contains as 
 * childViewControllers, and manages transitions between, callScreen, 
 * videoVC, and conferenceVC. When initialized, it initializes instances
 * of these "call handler VCs" which display and handle user interactions
 * with audio and video calls and conferencing.
 *
 * @see SCSCallNavigationVC
 */
@property (strong, nonatomic) SCSCallNavigationVC *callNavVC;
- (BOOL)callNavIsPresented;

@property(weak, nonatomic) UIPanGestureRecognizer           *grSideMenuPan;
@property(weak, nonatomic) UIScreenEdgePanGestureRecognizer *grSideMenuScreenEdge;

@property (weak, nonatomic) UIViewController   *presentingVC;
@property(strong, nonatomic) UIAlertController *wipeController;

// Convenience accessors
@property(weak, readonly, nonatomic) UINavigationController          *mainNavCon;
@property(weak, readonly, nonatomic) UISideMenuNavigationController  *sideMenuNavCon;
@property(weak, readonly, nonatomic) SideMenuTVC                     *sideMenuTVC;
@property(weak, readonly, nonatomic) SCSMainTVC                      *conversationsVC;
@property(weak, readonly, nonatomic) ChatViewController              *chatVC;
@property(weak, readonly, nonatomic) UIStoryboard                    *mainSB;
@property(weak, readonly, nonatomic) AppDelegate                     *appDelegate;

@end

@implementation SCSContainerController


#pragma mark - Lifecycle

- (void)viewDidLoad {    
    [super viewDidLoad];

    DDLogDebug(@"%s Call SideMenuHelper to setup SideMenu", __FUNCTION__);
    NSArray *grs = [SideMenuHelper setupSideMenu: self.mainNavCon];
    [self setupSideMenu:grs];

    self.conversationsVC.transitionDelegate = self;
    
    [self registerNotifications];
    
    [self setupPasscodeLogic];
    
    if(_showBlurScreen)
        [self showBlurScreen];
    else
        [self hideBlurScreen:NO];
}

- (void)viewDidAppear:(BOOL)animated {    
    [super viewDidAppear:animated];
        
    // When we show the Container Controller again (e.g. 
    // possibly user dismisses an overlay view like a UIImagePicker)
    // then we need to restart the flashing animation
    if([_returnToCallButton isVisible])
        [_returnToCallButton beginFlashingAnimation];
}

- (void)viewWillDisappear:(BOOL)animated {    
    [super viewWillDisappear:animated];
    
    // When we hide the Container Controller (e.g. possibly to present an overlay view like a UIImagePicker)
    // then we need to stop the flashing animation
    if([_returnToCallButton isVisible])
        [_returnToCallButton endFlashingAnimation];
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

#pragma mark - Notification Handlers

- (void)registerNotifications {
    DDLogInfo(@"%s registerNotifications", __FILE__);
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self selector:@selector(sideMenuSelectionNotification:) 
               name:kSCSideMenuSelectionNotification 
             object:nil];

    [nc addObserver:self selector:@selector(sideMenuAppearancesNotification:) 
               name:kSCSPSideMenuDidAppear
             object:nil];
    
    [nc addObserver:self selector:@selector(sideMenuAppearancesNotification:) 
               name:kSCSPSideMenuDidDisappear 
             object:nil];
    
    [nc addObserver:self selector:@selector(incomingVideoRequestNotification:)
               name:kSCPCallIncomingVideoRequestNotification
               object:nil];
    
    [nc addObserver:self selector:@selector(backToCallTappedNotification:)
               name:kSCPHeaderStripTappedNotification
               object:nil];
    
    [nc addObserver:self selector:@selector(incomingCallNotification:)
                         name:kSCPIncomingCallNotification
                         object:nil];
    
    [nc addObserver:self selector:@selector(callDidEndNotification:)
                         name:kSCPCallDidEndNotification
                         object:nil];

    // Posted by SCPNetworkManager for invalid APIKey
    [nc  addObserver:self selector:@selector(handleCurrentDeviceWasRemovedNotification:)
                          name:kSCSUserDeviceWasRemovedNotification
                          object:nil];
    
    [nc  addObserver:self selector:@selector(outgoingCallRequestFulfilledNotification:)
                          name:kSCPOutgoingCallRequestFulfilledNotification
                          object:nil];
    
    [nc  addObserver:self selector:@selector(outgoingCallRequestFailedNotification:)
                          name:kSCPOutgoingCallRequestFailedNotification
                          object:nil];

    [nc  addObserver:self selector:@selector(outgoingCallMagicCodeAppliedNotification:)
                          name:kSCPOutgoingCallRequestMCFulFilledNotification
                          object:nil];

    [nc  addObserver:self selector:@selector(handleTransitionToChatNotification:)
                          name:kSCPNeedsTransitionToChatWithContactNameNotification
                          object:nil];
}

/**
 Show incoming video request invitation from anywhere in the app
 if user is not currently on the call or video screens with that exact call.
 
 @param notif The NSNotification object with kSCPCallIncomingVideoRequestNotification as name
 */
- (void)incomingVideoRequestNotification:(NSNotification *)notif {
    
    if(!notif.userInfo || !notif.userInfo[kSCPCallDictionaryKey])
        return;
    
    
    // Extract the call object from the notification
    SCPCall *call = (SCPCall *)notif.userInfo[kSCPCallDictionaryKey];
    
    if(!call)
        return;
    
    // If call screen is up check if we are on the same call
    if([self callScreenIsActive]) {
        
        CallScreenVC *callScreen = (CallScreenVC *)[_callNavVC theRootViewController:_callNavVC.activeVC];
        
        if([callScreen.call isEqual:call])
            return;
    }
    // If video screen is up check if we are on the same call
    else if([self videoScreenIsActive]) {
        
        SCVideoVC *videoScreen = (SCVideoVC *)[_callNavVC theRootViewController:_callNavVC.activeVC];
        
        if([videoScreen.call isEqual:call])
            return;
    }
    
    UIViewController *activeVC = ([self callNavIsPresented] ? _callNavVC.activeVC : self);
    
    NSString *displayName = [call getName];
    
    if (!displayName)
        displayName = NSLocalizedString(@"Anonymous", nil);
    
    UIAlertController *videoRequestController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Video call request", nil)
                                                                                    message:[NSString stringWithFormat: NSLocalizedString(@"%@ wants to switch to video call", nil), displayName]
                                                                             preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *acceptAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Accept", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
                                                             
                                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                                 
                                                                 [SPCallManager switchToVideo:call
                                                                                           on:YES];
                                                                 
                                                                 [self transitionToVideoScreenFromVC:activeVC
                                                                                            withCall:call];
                                                             });
                                                         }];
    [videoRequestController addAction:acceptAction];
    
    UIAlertAction *ignoreAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Ignore", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {
                                                             
                                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                                 
                                                                 [SPCallManager switchToVideo:call
                                                                                           on:NO];
                                                                 
                                                             });
                                                         }];
    [videoRequestController addAction:ignoreAction];
    
    [activeVC presentViewController:videoRequestController
                           animated:YES
                         completion:nil];
}

- (void)backToCallTappedNotification:(NSNotification *)notif {
    
    [self dismissHeaderStrip];
    
    NSUInteger activeCallCount = [SPCallManager activeCallCount];
    
    if (activeCallCount > 1) {
        
        [self transitionToConferenceFromVC:nil
                                  withCall:nil];
    }
    else if(activeCallCount == 1) {
        
        // this should always return non-nil call object when only
        // 1 active call remains.
        SCPCall *call = (SCPCall *)[[SPCallManager activeCalls] firstObject];
        
        if (! call) {            
            NSLog(@"%s -> Unexpected nil selected call", __PRETTY_FUNCTION__);
            return;
        }
        
        [self transitionToCallScreenFromVC:[self.callNavVC callScreenVC]
                                  withCall:call];
    }
}

- (void)incomingCallNotification:(NSNotification *)notif {
    
    SCPCall *aCall = (SCPCall*)notif.userInfo[kSCPCallDictionaryKey];
    NSUInteger activeCallCount = [SPCallManager activeCallCount];
    
    if (aCall) {
        // First check for active video call, which handles answer/ignore
        // for incoming call. Simply return in that case.
        if ([self videoScreenIsActive]) {
            NSLog(@"%s\n   seems like: VIDEO is active -- return making no transition",
                  __PRETTY_FUNCTION__);
            
            return;
        }
        
        // Delay presentation call if currently in a transition
        BOOL shouldDelay = (_isPresentingCallNav || _isDismissingCallNav); 
        if (shouldDelay) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (activeCallCount == 1) {
                    [self presentCallScreenWithIncomingCall:aCall];
                }
                else {
                    [self transitionToConferenceFromVC:nil withCall:aCall];
                }
            });
        }
        
        // No delay
        if (activeCallCount == 1) {
            [self presentCallScreenWithIncomingCall:aCall];
        }
        else {
            [self transitionToConferenceFromVC:nil withCall:aCall];
        }
    } else {
        NSLog(@"%s\nCall object not initialized from notification at line %d",__PRETTY_FUNCTION__, __LINE__);
    }
}

// The callDidEnd notification will be posted for both incoming and
// outgoing calls.
//
// If there are zero calls, we are being notified of the last
// or only call ending. Dismiss callNavVC after delay - so user can see
// state change on callScreenVC.
//
// If there is one call left, switch to callScreen
//
// If there is > 1 call, switch to confVC
- (void)callDidEndNotification:(NSNotification *)notif {
    
    if (! [notif.name isEqualToString:kSCPCallDidEndNotification]) { return; }
    
    BOOL callNavIsPresented = [self callNavIsPresented];
    
    NSInteger activeCallCount = [SPCallManager activeCallCount];
    NSInteger confCallCount = [SPCallManager activeConferenceCallCount];
    BOOL confIsActive = confCallCount > 0;
    
    
    SCPCall *endCall = notif.userInfo[kSCPCallDictionaryKey];    
    // We get the selCall instance to handle the end video call to
    // answer incoming, next.
    SCPCall *selCall = (activeCallCount == 1 ? (SCPCall *)[SPCallManager activeCalls][0] : nil);
    
    
    // Default to call screen end-call delay value
    NSTimeInterval delay = 1.5;
    
    // Handle dismiss video screen
    if ([self videoScreenIsActive]) {
        
        // Is this the definitive check for the logged condition??
        //
        // Handle the case in videoVC that the user chose to
        // end current call and answer incoming call. In this
        // case the the videoVC.call has already swapped its call property
        // with the incoming call, and the notification calling this method
        // is the result of videoVC terminating its previous call.
        // Therefore, return here without transitioning.        
        if (selCall && selCall == [(SCVideoVC*)_callNavVC.activeVC call]) {
            NSLog(@"%s\n   seems like: VIDEO call ended - switched to incoming call\n    return making no transition",
                  __PRETTY_FUNCTION__);
            return;
        }
        // If there is even a single conference call or more than 1 private
        // call - transition to conference screen
        if (confIsActive || activeCallCount > 1) {
            SCSCallHandlerVC *vc = [_callNavVC conferenceVC];
            [_callNavVC presentVC:vc];
            return;
        }       
        else if (activeCallCount == 1) {
            // CallManager sets selectedCall to last remaining
            // activeCall. It should not be nil here.
            if (selCall) {
                // Transition to call screen
                [self transitionToCallScreenFromVC:nil withCall:selCall];
                return;
            }
            // Not sure why selCall would be nil here, but try to switch
            // to callscreen with the remaining call
            else {
                [self transitionToCallScreenFromVC:nil withCall:[SPCallManager activeCalls][0]];
                return;
            }
        }
    }
    
    switch (activeCallCount) {
        case 0: {
            
            [self dismissHeaderStrip];
            
            // shorten delay for locally ended last call
            delay = (endCall.iEnded == eCallUserPeer) ?: 0.5;
            
            if (endCall && [self callScreenIsActive]) {
                [(CallScreenVC*)_callNavVC.activeVC setCall:endCall];
            }
            
            // Give VoiceOver some time in order to be able to read out the next title
            // (e.g. 'Conversations' in case we are returning to the Conversations tab)
            // due to audio category changing.
            if(UIAccessibilityIsVoiceOverRunning())
                delay = 2.0;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self dismissCallNavigationVCWithPresentingVC:_presentingVC
                                                   completion:nil];
            });
        }
            return;
            
        case 1: {
            
            if (callNavIsPresented) {
                
                BOOL callScreenActive = [self callScreenIsActive];
                if (callScreenActive) {
                    
                    CallScreenVC *cvc = (CallScreenVC*)_callNavVC.activeVC;
                    // Reset with endingCall to reflect end call state
                    cvc.call = endCall;
                    
                    // Then reset with remaining call
                    // Note that if the delay is not long enough, the
                    // animation hiding/revealing "end call" message view
                    // on call screen will not be finished and the message
                    // will not appear.
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        cvc.call = selCall;
                    });
                }
                // If Conf, do nothing (previously switch to call screen)
                else if ([self conferenceVCIsActive]) {
                    return;
                }
                
                // CallManager sets selectedCall to last remaining
                // activeCall. It should not be nil here.
                if (! selCall) {
                    // WARNING: setting call screen with nil call here... now what?
                    NSLog(@"%s\n   --- ERROR: switch CALL SCREEN TO NIL CALL ---, line %d",__PRETTY_FUNCTION__, __LINE__);
                    NSAssert(selCall != nil, @"Unexpected nil selected call in didEnd handler with 1 call remaining");
                }
            } else {
                [self presentCallNavWithVC:_presentingVC call:selCall];
            }
        }
            break;
            // More than 1 remaining calls
        default:
            
            if (!callNavIsPresented)
                [self transitionToConferenceFromVC:_presentingVC withCall:nil];
            else if ([self callScreenIsActive]) {
                delay = (endCall.isIncoming) ? 2.5 : 1.5;
                
                CallScreenVC *cvc = (CallScreenVC*)_callNavVC.activeVC;
                // Reset with endingCall to relfect end call state
                cvc.call = endCall;
                
                // Transition to conference
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self transitionToConferenceFromVC:cvc withCall:nil];
                });
            }
            
            break;
    }
}

- (void)placeCallFromVC:(UIViewController *)vc withNumber:(NSString *)nr {
    
    _presentingVC = vc;
    
    [Switchboard.callHelper placeCallFromVC:vc
                                 withNumber:nr];
}

- (void)outgoingCallMagicCodeAppliedNotification:(NSNotification *)notification {

    if(![UINotificationFeedbackGenerator class])
        return;
    
    UINotificationFeedbackGenerator *generator = [UINotificationFeedbackGenerator new];
    [generator prepare];
    [generator notificationOccurred:UINotificationFeedbackTypeSuccess];
}

- (void)outgoingCallRequestFulfilledNotification:(NSNotification *)notification {
    
    NSDictionary *userInfo = notification.userInfo;
    
    UIViewController *viewController = [userInfo objectForKey:kSCPViewControllerDictionaryKey];
    SCPCall *call = [userInfo objectForKey:kSCPCallDictionaryKey];
    
    if(!call)
        return;
    
    if(!viewController)
        viewController = self;
    
    [self transitionToCallScreenFromVC:viewController
                              withCall:call];
}

- (void)outgoingCallRequestFailedNotification:(NSNotification *)notification {
    
    NSDictionary *userInfo = notification.userInfo;
    
    NSError *dialError = (NSError *)[userInfo objectForKey:kSCPErrorDictionaryKey];
    
    if(!dialError)
        return;
    
    NSString *errorTitle    = nil;
    NSString *errorMessage  = nil;
    
    switch ((SCSCallManagerErrorCode)dialError.code) {
            
        case SCSCallManagerErrorOutgoingCallPermissionDisabled:
            
            errorTitle = NSLocalizedString(@"No outbound calling", nil);
            errorMessage = NSLocalizedString(@"This call cannot be placed because your account is restricted from making outbound calls.", nil);
            break;
            
        case SCSCallManagerErrorOutgoingCallPSTNPermissionDisabled:
            
            errorTitle = NSLocalizedString(@"No Silent World service", nil);
            errorMessage = NSLocalizedString(@"This call cannot be placed because your account is restricted from making PSTN outbound calls.", nil);
            break;
            
        case SCSCallManagerErrorCallAlreadyExists:
        {
            if(!dialError.userInfo)
                break;
            
            // If call already exists, do not show error but take action
            SCPCall *call = (SCPCall *)[dialError.userInfo objectForKey:kSCPCallDictionaryKey];
            
            if(call) {
                
                BOOL hasSwitchedToVideo = NO;
                
                // If there is a queued video request...
                if(call.hasQueuedVideoRequest) {
                    
                    // ...and user hasn't already switched to video...
                    if(![call.callType isEqualToString:@"audio video"]) {
                        
                        // ...switch to video
                        [SPCallManager switchToVideo:call
                                                  on:YES];
                        
                        hasSwitchedToVideo = YES;
                    }
                    
                    [call setHasQueuedVideoRequest:NO];
                }
                
                // Transition to the appropriate VC
                if(hasSwitchedToVideo)
                    [self transitionToVideoScreenFromVC:nil
                                               withCall:call];
                else
                    [self transitionToCallScreenFromVC:nil
                                              withCall:call];
            }
            
        }
            break;
            
        case SCSCallManagerErrorUserNotFound:
            
            errorTitle = NSLocalizedString(@"User not found", nil);
            errorMessage = NSLocalizedString(@"This user could not be found.", nil);
            break;
            
        default:
            break;
    }
    
    if(!errorTitle || !errorMessage)
        return;
    
    UIViewController *viewController = userInfo[kSCPViewControllerDictionaryKey];
    
    if(!viewController)
        viewController = self;
    
    [self displayAlertInVC:viewController
                  withText:errorTitle
                   message:errorMessage];
    
}

- (void)handleTransitionToChatNotification:(NSNotification *)notif {
    
    if (notif.userInfo[kSCPContactNameDictionaryKey]) {
        
        if (notif.userInfo[kSCPMessageContentDictionaryKey]) {
            
            [[ChatUtilities utilitiesInstance] setSavedMessageText:notif.userInfo[kSCPMessageContentDictionaryKey]
                                                    forContactName:notif.userInfo[kSCPContactNameDictionaryKey]];
        }
    
        [self transitionToChatWithContactName:notif.userInfo[kSCPContactNameDictionaryKey]];
    }
}

#pragma mark - Side Menu
- (void)setupSideMenu:(NSArray *)grs {
    [self configureSideMenuGestureRecognizers:grs];
}

- (void)configureSideMenuGestureRecognizers:(NSArray *)grs {
    // An array containing the UIScreenEdgePanGestureRecognizer assigned
    // to the SideMenuManager.leftSideNavigationController and the 
    // SideMenuManager.menuAddPanGestureToPrsent (for mainNavCon.navbar).
    // Expect this ordering in array
    _grSideMenuPan        = grs[0];
    _grSideMenuScreenEdge = grs[1];
    _grSideMenuPan.delegate        = self;    
    _grSideMenuScreenEdge.delegate = self;
}

/**
 * Allow left screen edge swipe to pop view controller by preventing
 * SideMenu presentation when mainNavCon.viewController.count > 1.
 *
 * The grSideMenuScreenEdge and grSideMenuPan properties are used to 
 * determine when to disallow presentation of the SideMenu.
 */
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    UIGestureRecognizer *gr = gestureRecognizer;
    
    if ((gr == _grSideMenuScreenEdge || gr == _grSideMenuPan) && self.mainNavCon.viewControllers.count > 1) {
        
        return NO;
    }
    
    return YES;
}

/**
 * Support VoiceOver 3-finger swipe right to open side menu.
 *
 * Note: the left direction does not fire to close side menu because
 * the side menu will intercept the VoiceOver swipe event when open.
 * SCUISideMenuNavigationControllerExtensions implements swipe left to
 * close.
 */
- (BOOL)accessibilityScroll:(UIAccessibilityScrollDirection)direction {

    if (direction == UIAccessibilityScrollDirectionRight) {
        // swipe to pop VC off nav stack (back operation)
        if (self.mainNavCon.viewControllers.count > 1) {
            NSLog(@"Container controller - Accessibility swipe right\n\tPOP BACK OFF NAV STACK");
            [self.mainNavCon popViewControllerAnimated:YES];
        }
        // swipe to present side menu
        else if (! [self sideMenuIsShowing]) {
            NSLog(@"Container controller - Accessibility swipe right\n\tPRESENT SIDE MENU");
            [self.conversationsVC performSegueWithIdentifier:@"showSideMenu" sender:nil];
            
            return YES;
        } else {
            return NO;
        }
    }
     
    return [super accessibilityScroll:direction];
}

- (BOOL)sideMenuIsShowing {
    return [self.mainNavCon.topViewController isKindOfClass:[UISideMenuNavigationController class]];
}

/**
 * Push a view controller onto mainNavCon with data from notification.
 *
 * The SideMenuTVC posts a notification in which the userInfo dictionary
 * contains a key/value pair describing the view controller identifier
 * to instantiate from the main storyboard.
 * @see SideMenuTVC
 */
- (void)sideMenuSelectionNotification:(NSNotification *)notif {
    
    if (notif.userInfo[@"vc_id"]) {
        UIViewController *vc = [self.mainSB instantiateViewControllerWithIdentifier: notif.userInfo[@"vc_id"]];
        if (vc) {
            vc.title = notif.userInfo[@"title"];
            [self.sideMenuNavCon pushViewController:vc animated:YES];
        }
    } else if (notif.userInfo[@"url"]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString: notif.userInfo[@"url"]]];
    } else if (notif.userInfo[@"*wipe"]) {
        [self handleWipeDataUserRequest];
        [self.sideMenuNavCon dismissViewControllerAnimated:YES completion:^{
//            [self handleWipeDataUserRequest];
        }];
    }
}

/**
 * Prevent/enable accessibility visibility of view controller under 
 * side menu when presented/dismissed.
 */
- (void)sideMenuAppearancesNotification:(NSNotification *)notif {
    NSString *notifName = notif.name;
    if ([notifName isEqualToString:kSCSPSideMenuDidAppear]) {
        self.mainNavCon.view.accessibilityElementsHidden = YES;
    }
    else if ([notifName isEqualToString:kSCSPSideMenuDidDisappear]) {
        self.mainNavCon.view.accessibilityElementsHidden = NO;
    }
}

#pragma mark - TransitionDelegate Methods

/**
 * Handles transitioning to a call screen from given vc.
 *
 * This method may be called from Contacts or Main. All tabBar view
 * controllers have this RootVC as transitionDelegate except ProfileVC.
 *
 * Also, this method may be called by the self notification handler
 * for an incoming audio call.
 *
 * @param vc The view controller which should present the callScreen
 *
 * @param aCall The call with which to set the callScreen call property
 */
- (void)transitionToCallScreenFromVC:(UIViewController *)vc withCall:(SCPCall *)aCall {
    
    if (!aCall) return;
    
    if (vc) { _presentingVC = vc; }
    
    if ([SPCallManager activeCallCount] > 1) {
        [self transitionToConferenceFromVC:nil withCall:aCall];
    }
    else if ([self callNavIsPresented]) {
        CallScreenVC *vc = [_callNavVC callScreenVC];
        [_callNavVC presentVC:vc];
        vc.call = aCall;
    }
    else {
        [self presentCallNavWithVC:[self.callNavVC callScreenVC] call:aCall];
    }
}

- (void)transitionToVideoScreenFromVC:(UIViewController *)vc withCall:(SCPCall *)aCall {
    
    if (!aCall) return;
    
    if (vc) { _presentingVC = vc; }
    
    SCVideoVC *vvc = [self.callNavVC videoVC];
    vvc.call = aCall;
    
    if ([self callNavIsPresented]) {
        [_callNavVC presentVC:vvc];
    }
    else {
        [self presentCallNavWithVC:vvc call:nil];
    }
}


// This method will be called with nil VC for an incoming call. (Why ??)
//
// Note that a transition from the callScreenVC to the conferenceVC is
// handled by the callNavVC internally.
- (void)transitionToConferenceFromVC:(UIViewController *)vc withCall:(SCPCall *)aCall {
    
    if (vc) { _presentingVC = vc; }
    
    if ([SPCallManager activeCallCount] > 1) {
        SCSCallHandlerVC *cvc = [self.callNavVC conferenceVC];
        [self presentCallNavWithVC:cvc call:aCall];
    }
    else {
        [self presentCallNavWithVC:[self.callNavVC callScreenVC] call:aCall];
    }
}

- (void)transitionToChatFromVC:(UIViewController *)vc withCall:(SCPCall*)aCall {

    NSString *contactName = (aCall.bufPeer) ?: aCall.bufDialed;
    SCSMainTVC *conversationsVC = self.conversationsVC;

    // For now, always pop to conversationsVC, assignSelectedRecent and present chatVC,
    // without checking current nav stack
    [self presentLockScreenIfNeededWithCompletion:^{
        [self popToConversationsAnimated:NO];
        [[ChatUtilities utilitiesInstance] assignSelectedRecent:contactName withProps:nil];
        [conversationsVC openChatViewWithSelectedUserAndFileURL:nil title:nil animated:YES];
        [self presentHeaderStrip];
        
        [self dismissCallNavigationVCWithPresentingVC:self.chatVC completion:nil];
    }];
}

- (void)transitionToConversationsFromVC:(UIViewController *)vc withCall:(SCPCall*)aCall {
    if ([SPCallManager activeCallCount] == 0) {
        [self dismissHeaderStrip];
    }
    
    [self popToConversationsAnimated:NO];
    
    [self presentLockScreenIfNeededWithCompletion:^{
        [self presentHeaderStrip];
        [self dismissCallNavigationVCWithPresentingVC:nil
                                           completion:nil];
    }];
}

- (void)transitionToConversationsFromVC:(UIViewController *)vc {
    [self popToConversationsAnimated:YES];
}


#pragma mark - Present Methods (RootVC)

// This method may be called by the notification handler for an incoming
// call when there is already an active call.
//
// If callNavVC is not already presented, present callNavVC with callSreen
// otherwise, call it to present the conf VC.
- (void)presentCallScreenWithIncomingCall:(SCPCall*)aCall {
    NSAssert(aCall != nil, @"UNEXPECTED NIL CALL at line %d", __LINE__);
    if (!aCall) return;
    
    if ([SPCallManager activeCallCount] > 1) {
        [self transitionToConferenceFromVC:nil withCall:aCall];
    }
    else {
        [self transitionToCallScreenFromVC:nil withCall:aCall];
    }
}


// @param searchStr Forward looking param for displaying searchVC with
// an existing search string. May be nil.
// Not Yet Implemented
- (void)presentSearchController:(NSString *)searchStr {
    
    SCSSearchViewController *searchViewController = [self newSearchController];
    [searchViewController setTransitionDelegate:self];

    [self.conversationsVC.navigationController pushViewController:searchViewController animated:YES];
}


#pragma mark - Present callNavVC

- (void)presentCallNavWithVC:(UIViewController*)vc call:(SCPCall*)aCall {
    
    // NOTE: currentDeviceWasRemoved: and presentShareSheetWithFileURL:
    // both present a view controller. This should dismiss an existing
    // presentedVC and call back to this method to present call screen.
    if (self.presentedViewController && ! [self callNavIsPresented]) {
        
        // If we are receiving a call and the wipe controller is active
        // then do not allow the incoming call to present a call screen
        if(self.presentedViewController == self.wipeController) {
            
            [SPCallManager terminateCall:aCall];
            return;
        }
        
        [self dismissViewControllerAnimated:YES completion:^{
            [self presentCallNavWithVC:vc
                                  call:aCall];
        }];
        
        return;
    }
    
    // This can happen when there are a simultaneous incoming, or
    // outgoing and incoming, calls.
    else if (self.presentedViewController && [self callNavIsPresented]) {
        
        NSUInteger activeCallCount = [SPCallManager activeCallCount];
        
        // This seems unlikely
        if (activeCallCount == 0) {
            [self dismissCallNavigationVCWithPresentingVC:nil completion:nil];
            return;
        }
        
        if ([self callScreenIsActive]) {
            if (activeCallCount > 1) {
                [_callNavVC switchToConference:nil call:nil];
                return;
            }
            
            CallScreenVC *cs = (CallScreenVC *)_callNavVC.activeVC;
            if (cs.call == aCall) {
                NSLog(@"%s\n   -- WARNING: called with call already in callscreen: %@",
                      __PRETTY_FUNCTION__, [aCall getName]);
                cs.call = aCall;
                return;
            }
        }
        
        // Otherwise the conference controller could be active, in
        // which case it should handle an incoming call event.
        // So, return.
        return;
    }
    
    // not sure this is useful if all invocations are on main thread
    _isPresentingCallNav = YES;
    
    // Initialize callNavVC if uninitialized
    (void)[self callNavVC];
    
    // Check for duplicate notification workflow
    if ([self callScreenIsActive]) {
        CallScreenVC *cs = (CallScreenVC *)_callNavVC.activeVC;
        if (cs.call == aCall) {
            NSLog(@"%s\n   -- WARNING: called with call already in callscreen: %@",
                  __PRETTY_FUNCTION__, [aCall getName]);
            cs.call = aCall;
            return;
        }
    }
    
    
    BOOL presentConf = ([SPCallManager activeCallCount] > 1);
    
    if (presentConf && [self conferenceVCIsActive]) {
        NSLog(@"%s\n   -- WARNING: Called with call: %@. > 1 calls and CONF IS ACTIVE - IGNORE/RETURN",
              __PRETTY_FUNCTION__, [aCall getName]);
        return;
    }
    
    // Assume if callNavIsPresented there are two or more calls
    // UPDATE: assertion crash in transitionToConferenceFromVC: suggests
    // this assumption might not be correct.
    // Add checks above. Refactor logic here to switch to confVC.
    if (presentConf && [self callNavIsPresented]) {
        [_callNavVC switchToConference:nil call:nil];
        return;
    }
    else {
        
        [self dismissHeaderStrip];
        
        [self postNotification:kSCPWillPresentCallScreenNotification
                           obj:self
                      userInfo:(aCall) ? @{kSCPCallDictionaryKey:aCall} : nil];
        
        self.callNavVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve; //UIModalTransitionStyleFlipHorizontal;
        
        if (nil == vc) {
            if (presentConf) {
                vc = [self.callNavVC conferenceVC];
            } else {
                CallScreenVC *cvc = [_callNavVC callScreenVC];
                cvc.call = aCall;
                vc = cvc;
            }
        }
        // quick hack after changing transitionToCallScreen/Conference methods
        else if ([vc isKindOfClass:[CallScreenVC class]]) {
            [(CallScreenVC*)vc setCall:aCall];
        }
        
        //present without animation
        [_callNavVC presentVC:vc];
        
        // Detects whether the callNavVC is already presented 
        // (if we receive a new call right before the call screen animates back to the tab interface)
        // The _suppressCallNavDismissal prevents the newly presented callNavVC to be dismissed 
        // (ref: dismissCallNavigationVCWithPresentingVC:completion:)
        if([self callNavIsPresented]) {
            _suppressCallNavDismissal = YES;
            [self dismissViewControllerAnimated:NO completion:nil];
        }
        
        [self presentViewController:_callNavVC animated:YES completion:^{
            [self postNotification:kSCPDidPresentCallScreenNotification
                               obj:self
                          userInfo:(aCall) ? @{kSCPCallDictionaryKey:aCall} : nil];
            _isPresentingCallNav = NO;
        }];
    }
}

#pragma mark - Dismiss CallNavVC
// Note: pvc arg should never be navVC
- (void)dismissCallNavigationVCWithPresentingVC:(UIViewController *)pvc completion:(void (^)())completion
{
    if(_suppressCallNavDismissal) {
        
        _suppressCallNavDismissal = NO;
        return;
    }
    
    _isDismissingCallNav = YES;
    
    // When a video call ends in landscape orientation, we need to
    // try to ensure that the selected tabBar vc will be in portrait
    // orientation when the callNav is dismissed
    [UIViewController attemptRotationToDeviceOrientation];
        
    [self dismissViewControllerAnimated:YES completion:^{
        
        [UIViewController attemptRotationToDeviceOrientation];
        
        if (completion) {
            completion();
        }
        
        _presentingVC = nil;
        _callNavVC = nil;
        _isDismissingCallNav = NO;
    }];
}

#pragma mark - CallNavVC Initialization

// Initialized when presenting and set nil when dismissed
- (SCSCallNavigationVC *)callNavVC {
    
    if (nil == _callNavVC) {        
        _callNavVC = [[UIStoryboard storyboardWithName:@"Phone" bundle:nil] instantiateInitialViewController];
        _callNavVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;        
        _callNavVC.transitionDelegate = self;
    }
    return _callNavVC;
}


#pragma mark - Navigation Helpers

- (BOOL)callNavIsPresented {
    return (_callNavVC && _callNavVC == self.presentedViewController);
}

- (BOOL)callScreenIsActive {
    if (NO == [self callNavIsPresented]) return NO;
    UIViewController *vc = [_callNavVC theRootViewController:_callNavVC.activeVC];
    return [vc isKindOfClass:[CallScreenVC class]];
}

- (BOOL)conferenceVCIsActive {
    if (NO == [self callNavIsPresented]) return NO;
    UIViewController *vc = [_callNavVC theRootViewController:_callNavVC.activeVC];
    return ([vc isKindOfClass:[SCSConferenceCVC class]] || [vc isKindOfClass:[SCSConferenceTVC class]]);
}

- (BOOL)videoScreenIsActive {
    if (NO == [self callNavIsPresented]) return NO;
    UIViewController *vc = [_callNavVC theRootViewController:_callNavVC.activeVC];
    return [vc isKindOfClass:[SCVideoVC class]];
}



// This helper is used to ensure the notification will be called immediately
// and will block until it returns. This fixes a bug which occurred when
// the Switchboard postNotification: wrapper method was used, in which
// the wrapper method posted the notification as an async call to the
// main thread. This is fine for the engine-side notifications because
// they need to be posted to the main thread. However, in the case of
// the kSCPWill/DidRemoveCallScreenNavNotification notifications, we
// are already on the main thread and we need the notification call to
// block until all listeners are notified before continuing. This allows
// the callNavVC to prepare for a teardown and handle rotation orientation
// callback correctly.
- (void)postNotification:(NSString *)key obj:(id)obj userInfo:(NSDictionary *)uInfo {
    [[NSNotificationCenter defaultCenter] postNotificationName:key object:obj userInfo:uInfo];
}


#pragma mark - View Transitioning

- (SCSSearchViewController *)newSearchController
{
    UIStoryboard *searchStoryboard = [UIStoryboard storyboardWithName:@"SearchViewController"
                                                               bundle:nil];
    return (SCSSearchViewController *)[searchStoryboard instantiateInitialViewController];
}

- (BOOL)shouldOpenShareSheetWithFileURL:(NSURL*)fileURL {
    
    NSString* extension = [fileURL.pathExtension lowercaseString];
    NSArray* importableExtensions = @[@"pdf", @"png", @"jpg", @"jpeg", @"mp4", @"mov", @"doc", @"docx", @"ppt", @"pptx", @"xls", @"xlsx", @"rtf", @"txt"];
    
    return [importableExtensions containsObject:extension];
}

- (void)presentShareSheetWithFileURL:(NSURL *)fileURL {
    
    // A file url is required
    if(!fileURL)
        return;

    [self presentLockScreenIfNeededWithCompletion:^{
        
        // If already presenting another VC
        if(self.presentedViewController) {
            
            // If the wipe controller is active, do not show the share sheet
            if(self.presentedViewController == _wipeController)
                return;
            // If the call screen is presented, dismiss it and present the share sheet
            else if([self callNavIsPresented]) {
                
                [self dismissViewControllerAnimated:YES
                                         completion:^{
                                             
                                             // Show the return to call strip
                                             [self presentHeaderStrip];
                                             
                                             [self presentShareSheetWithFileURL:fileURL];
                                         }];
            }
            // In any other case, dismiss the controller which is being displayed and
            // present the share sheet
            else
                [self dismissViewControllerAnimated:NO
                                         completion:^{
                                             [self presentShareSheetWithFileURL:fileURL];
                                         }];            
            return;
        }
        
        // Check if file extension is supported
        if (![self shouldOpenShareSheetWithFileURL:fileURL]) {
            
            [self displayAlertWithText:NSLocalizedString(@"Not supported", nil)
                               message:NSLocalizedString(@"This file type is not supported.", nil)];            
            return;
        }
        
        [self.conversationsVC.navigationController popToRootViewControllerAnimated:NO];
        
        SCSMainTVC *mainTVC = self.conversationsVC;
        
        
        SCSSearchViewController *searchViewController = [self newSearchController];
        __weak typeof(searchViewController) weakSearchVC = searchViewController;
        [searchViewController setTitle:NSLocalizedString(@"Send file to...", nil)];
        [searchViewController setEnableGroupConversations:YES];
        [searchViewController setDisableSwipe:YES];
        [searchViewController setDisableNewGroupChatButton:YES];
        [searchViewController setDisableAddressBook:YES];
        [searchViewController setDisablePhoneNumberResults:YES];
        [searchViewController setDoneBlock:^(RecentObject *recentObject) {
            
            __strong typeof(weakSearchVC) strongSearchVC = weakSearchVC;
            [[ChatUtilities utilitiesInstance] assignSelectedRecent:recentObject.contactName
                                                          withProps:nil];
            
            [[ChatUtilities utilitiesInstance] donateInteractionWithRecent:recentObject
                                                      doesExistInDirectory:YES];
            
            ChatViewController *chatVC = [self.conversationsVC chatViewControllerWithTitle:nil
                                                                                   fileURL:fileURL];
            // Explicitly set frame: can be too tall if app is opened from file share.
            chatVC.view.frame = self.conversationsVC.view.frame;
            chatVC.view.autoresizingMask = YES;
            
            [self.mainNavCon setViewControllers:@[self.conversationsVC,chatVC,strongSearchVC]];
            [self.mainNavCon popViewControllerAnimated:YES];
        }];
        
        [mainTVC.navigationController pushViewController:searchViewController animated:YES];
    }];
}

- (void)presentContactSelectionScreenInController:(UIViewController *)vc completion:(void (^)(AddressBookContact *))completion {
    
    if(!vc)
        return;
    SCSSearchViewController *searchViewController = [self newSearchController];
    [searchViewController setTitle:NSLocalizedString(@"Share Contact", nil)];
    [searchViewController setDisableSwipe:YES];
    [searchViewController setDisableNewGroupChatButton:YES];
    [searchViewController setDisableAutocompleteSearch:YES];
    [searchViewController setDisableDirectorySearch:YES];
    [searchViewController setDisablePhoneNumberResults:YES];
    [searchViewController setDoneBlock:^(RecentObject *recentObject) {
        
        if(completion)
            completion(recentObject.abContact);
        
        [vc.navigationController popViewControllerAnimated:YES];
    }];
    
    [vc.navigationController pushViewController:searchViewController animated:YES];
}

- (void)presentForwardScreenInController:(UIViewController *)vc withChatObject:(ChatObject*)chatObject {
    
    if(!vc)
        return;
    
    if(!chatObject)
        return;
    SCSSearchViewController *searchViewController = [self newSearchController];
    [searchViewController setTitle:NSLocalizedString(@"Forward to...", nil)];
    [searchViewController setEnableGroupConversations:YES];
    [searchViewController setDisableSwipe:YES];
    [searchViewController setDisableNewGroupChatButton:YES];
    [searchViewController setDisableAddressBook:YES];
    [searchViewController setDisablePhoneNumberResults:YES];
    [searchViewController setDoneBlock:^(RecentObject *recentObject) {
        
        if(!recentObject || !chatObject) {
         
             [self dismissViewControllerAnimated:YES
                                      completion:nil];
             return;
        }

        NSString *contactName       = recentObject.contactName;
        NSString *openedContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:[ChatUtilities utilitiesInstance].selectedRecentObject.contactName
                                                                              lowerCase:NO];

        [[ChatUtilities utilitiesInstance] assignSelectedRecent:contactName
                                                      withProps:nil];

        [[ChatUtilities utilitiesInstance].forwardedMessageData setObject:chatObject
                                                                   forKey:@"forwardedChatObject"];

        [[ChatUtilities utilitiesInstance] donateInteractionWithRecent:recentObject
                                                  doesExistInDirectory:YES];
        
        // Replace the ChatVC if we are going to forward the chat object
        // to someone else
        if(![openedContactName isEqualToString:contactName]) {
            
            SCSMainTVC *conversationsController = self.conversationsVC.navigationController.viewControllers[0];
            ChatViewController *chatController = [self.conversationsVC chatViewControllerWithTitle:nil
                                                                                           fileURL:nil];
            
            [self.conversationsVC.navigationController setViewControllers:@[conversationsController, chatController]];
        }

        [self dismissViewControllerAnimated:YES
                                 completion:nil];
    }];
    
    [vc.navigationController pushViewController:searchViewController animated:YES];
}

-(void)transitionToChatWithContactName:(NSString *) contactName {
    
    [self presentLockScreenIfNeededWithCompletion:^{
        
        NSString *openedContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:[ChatUtilities utilitiesInstance].selectedRecentObject.contactName lowerCase:NO];
        NSString *receivedContactName = [[ChatUtilities utilitiesInstance] removePeerInfo:contactName lowerCase:NO];
        
        // If chat is not open already or currently displaying a different chat
        if (!self.chatVC || ![openedContactName isEqualToString:receivedContactName]) {

            // TODO: This needs to be replaced with a property at the ChatVC instance
            [[ChatUtilities utilitiesInstance] assignSelectedRecent:contactName
                                                          withProps:nil];

            // If there is already a navigation VC controller presented in conversation VC
            // (showing for example the new group chat vc, search vc etc)
            // then replace that with the chat vc, in order for its back button to navigate
            // to the conversations view
            if(self.conversationsVC.presentedViewController &&
               [self.conversationsVC.presentedViewController isKindOfClass:[UINavigationController class]]) {
 
                UINavigationController *navigationController = (UINavigationController *)self.conversationsVC.presentedViewController;
                
                if([navigationController isKindOfClass:[UISideMenuNavigationController class]]) {
                    
                    [navigationController dismissViewControllerAnimated:YES
                                                             completion:^{ [self transitionToChatWithContactName:contactName]; }];
                }
                else {
                    
                    ChatViewController *chatController = [self.conversationsVC chatViewControllerWithTitle:nil
                                                                                                   fileURL:nil];
                    
                    [navigationController setViewControllers:@[chatController]];
                }
            }
            // Else if we are already on chat, then replace
            // the current chat with the new one
            else if([self.conversationsVC.navigationController.viewControllers count] > 1) {

                SCSMainTVC *conversationsController = self.conversationsVC.navigationController.viewControllers[0];                
                ChatViewController *chatController = [self.conversationsVC chatViewControllerWithTitle:nil
                                                                                               fileURL:nil];

                [self.conversationsVC.navigationController setViewControllers:@[conversationsController, chatController]];
            }
            else {
                
                BOOL animate = ![self callNavIsPresented];
                
                [self popToConversationsAnimated: animate];
                [self.conversationsVC openChatViewWithSelectedUserAndFileURL:nil
                                                                       title:nil
                                                                    animated:animate];
            }
            
            if([self callNavIsPresented])
                [self dismissCallNavigationVCWithPresentingVC:nil
                                                   completion:^{ [self presentHeaderStrip]; }];
        }
    }];
}

- (void)presentCallScreenForContactName:(NSString *)contactName queueVideoRequest:(BOOL)queueVideoRequest {
    
    [self presentLockScreenIfNeededWithCompletion:^{
        
        [Switchboard.callHelper requestOutgoingCallFromViewController:self
                                                           withNumber:contactName 
                                                    queueVideoRequest:queueVideoRequest];
    }];
}


- (void)displayAlertWithText:(NSString *)text message:(NSString *)message {
    
    [self displayAlertInVC:self
                  withText:text
                   message:message];
}


#pragma mark - Private

- (void)displayAlertInVC:(UIViewController *)vc withText:(NSString *)text message:(NSString *)message {
    
    if(!vc)
        return;
    
    if([self callScreenIsActive] || [self videoScreenIsActive])
        vc = (CallScreenVC*)_callNavVC.activeVC;
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:text
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [alertController addAction:cancelAction];
    
    [vc presentViewController:alertController
                     animated:YES
                   completion:nil];
}
#pragma mark -------------------------------


- (void)presentHeaderStrip {
    
    [_returnToCallButton present];
}

- (void)dismissHeaderStrip {
    
    [_returnToCallButton dismiss];
}

- (float)headerStripHeight {
    
    return [_returnToCallButton height];
}

- (void)presentLockScreenIfNeededWithCompletion:(void (^)(void))completion {
    
    BOOL isPasscodeLocked   = [_passcodeManager isPasscodeLocked];
    BOOL isCallNavPresented = [self callNavIsPresented];
    
    if(!isPasscodeLocked && !_shouldShowLockScreen) {
        
        if(completion)
            completion();
        
        return;
    }
    
    if(isPasscodeLocked) {

        if(isCallNavPresented)
            [self displayAlertWithText:NSLocalizedString(@"Silent Phone is disabled", nil)
                               message:[_passcodeManager tryAgainInString]];
        else
            [self showBlurScreen];

        return;
    }
    
    [self presentLockScreenCancellable:isCallNavPresented
                            completion:completion];
}

- (BOOL)shouldShowLockScreen {
    
    return _shouldShowLockScreen;
}

#pragma mark - Private

- (void)invalidateFailedAttemptsTimer {
    
    if(!_failedAttemptsTimer)
        return;
    
    [_failedAttemptsTimer invalidate];
    _failedAttemptsTimer = nil;
}

- (void)setupFailedAttemptsTimer {
    
    [self invalidateFailedAttemptsTimer];

    if(![_passcodeManager isPasscodeLocked])
        return;
    
    _failedAttemptsTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)60
                                                            target:self
                                                          selector:@selector(failedAttemptsTimerUpdate:)
                                                          userInfo:nil
                                                           repeats:NO];
}

- (void)failedAttemptsTimerUpdate:(NSTimer *)timer {
    
    [self updateLabels:NO];
}

- (void)showBlurScreen {
    
    _showBlurScreen = YES;
    
    if(_lockedOverlayImageView) {

        if(!_lockedOverlayImageView.image) {
            
            UIImage *screenImage = [UIImage imageFromScreen];
            
            [_lockedOverlayImageView setImage:[screenImage applyDarkEffect]];
        }
        
        [_lockedOverlayContainer setHidden:NO];
    }

    [self updateLabels:NO];
}

- (void)hideBlurScreen:(BOOL)checkForLockScreen {
    
    if(checkForLockScreen && [self isLockScreenActive])
        return;
    
    _showBlurScreen = NO;
    
    if(_lockedOverlayImageView) {
        
        [_lockedOverlayImageView setImage:nil];
        [_lockedOverlayContainer setHidden:YES];
    }
    
    [self updateLabels:NO];
}

- (void)updateLabels:(BOOL)showWipe {
    
    if(showWipe) {
        
        [self.lockedOverlayLabel setText:NSLocalizedString(@"Wiping data...", nil)];
        [self.lockedOverlayLabel setHidden:NO];
        [self.lockedOverlaySublabel setHidden:YES];
    }
    else if([_passcodeManager isPasscodeLocked]) {
        
        [self setupFailedAttemptsTimer];
        
        [self.lockedOverlayLabel setText:NSLocalizedString(@"Silent Phone is disabled", nil)];
        [self.lockedOverlaySublabel setText:[[_passcodeManager tryAgainInString] lowercaseString]];
        [self.lockedOverlaySublabel setHidden:NO];
        [self.lockedOverlayLabel setHidden:NO];
    }
    else {
        
        [self invalidateFailedAttemptsTimer];
         
        [self.lockedOverlayLabel setHidden:YES];
        [self.lockedOverlaySublabel setHidden:YES];
    }
}

#pragma mark - LockScreen

- (void)setupPasscodeLogic {
    
    _passcodeManager = [SCPPasscodeManager sharedManager];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(supressLockScreenDueToIncomingCall:)
                                                 name:kSCPDidPresentCallScreenNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(presentLockScreenAfterIncomingCallEnds)
                                                 name:kSCPCallDidEndNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lockScreenCheckAppDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lockScreenCheckAppWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lockScreenCheckAppDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(lockScreenCheckAppDidFinishLaunching)
                                                 name:UIApplicationDidFinishLaunchingNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(passcodeManagerDidUnlock)
                                                 name:kSCSPasscodeDidUnlock
                                               object:nil];
}

- (BOOL)shouldShowPasscodeAndCheckActiveVC:(BOOL)checkActiveVC {
    
    // If user is not yet provisioned do not show the passcode screen
    if(![Switchboard isProvisioned])
        return NO;
    
    // Check if passcode option is enabled
    if(![_passcodeManager doesPasscodeExist])
        return NO;
    
    // Do not show passcode if the passcode screen is already visible
    if([self isLockScreenActive])
        return NO;
    
    if(checkActiveVC) {
        if([self callNavIsPresented]) {            
            _shouldShowLockScreen = YES;
            return NO;
        }
    }
    
    return YES;
}

- (void)checkForPasscodeAndBlurScreenAndCheckActiveVC:(BOOL)checkActiveVC {
    
    if(![self shouldShowPasscodeAndCheckActiveVC:checkActiveVC])
        return;
    
    if(self.conversationsVC.presentedViewController) {
        
        [self.conversationsVC.presentedViewController 
         dismissViewControllerAnimated:NO
         completion:^{
             
             _shouldShowLockScreen = YES;
             
             [self showBlurScreen];
         }];
        return;
    }
    
    _shouldShowLockScreen = YES;
    
    [self showBlurScreen];
}

- (void)lockScreenCheckAppDidBecomeActive {
    
    if([SCDataDestroyer isWipingData])
        return;
    
    // If wipe controller is on
    if(_wipeController)
        return;
    
    if(![Switchboard isProvisioned])
        return;
    
    [self setupFailedAttemptsTimer];
    
    if(!_shouldShowLockScreen)
        return;
    
    if([_passcodeManager isPasscodeLocked])
        return;
    
    [self hideBlurScreen:YES];
    
    if(![_passcodeManager shouldShowPasscodeBasedOnTimeoutTimer]) {
        
        _shouldShowLockScreen = NO;
        return;
    }
    
    if(![self shouldShowPasscodeAndCheckActiveVC:YES])
        return;
    
    [self presentLockScreenCancellable:NO
                            completion:nil];
}

- (void)lockScreenCheckAppWillResignActive {
    
    if([SCDataDestroyer isWipingData])
        return;

    // If wipe controller is on
    if(_wipeController)
        return;

    if(![self callNavIsPresented] && ![self isLockScreenActive])
        [_passcodeManager startPasscodeTimeoutTimer];

    if(self.conversationsVC.presentedViewController &&
       [self.conversationsVC.presentedViewController isKindOfClass:[UISideMenuNavigationController class]]) {
        
        [self.conversationsVC.presentedViewController 
         dismissViewControllerAnimated:YES
         completion:^{
             
             [self checkForPasscodeAndBlurScreenAndCheckActiveVC:YES];
         }];
    }
    else
        [self checkForPasscodeAndBlurScreenAndCheckActiveVC:YES];
}

- (void)lockScreenCheckAppDidEnterBackground {
    
    if([SCDataDestroyer isWipingData])
        return;
    
    [self invalidateFailedAttemptsTimer];
    
    [self dismissLockScreen];
}

- (void)lockScreenCheckAppDidFinishLaunching {
    
    if([Switchboard isProvisioned])
        [self checkForPasscodeAndBlurScreenAndCheckActiveVC:NO];
}

- (void)presentLockScreenCancellable:(BOOL)isCancellable completion:(void (^)(void))completion {
    
    // Replace completion block with the latest one
    _passcodeCompletion = completion;

    if([self isLockScreenActive])
        return;
    
    [self showBlurScreen];

    MWSPinLockScreenVC *lockScreen = [[MWSPinLockScreenVC alloc] 
                                      initWithLabelTitle:NSLocalizedString(@"Enter Passcode", nil)
                                      completion:^(MWSPinLockScreenVC *pinLockScreenVC, NSString *passcode) {
                                          
                                          if([_passcodeManager evaluatePasscode:passcode error:nil]) {
                                              
                                              _shouldShowLockScreen = NO;
                                              
                                              [self hideBlurScreen:NO];
                                              [self dismissLockScreen];
                                              
                                              if(_passcodeCompletion)
                                                  _passcodeCompletion();
                                          }
                                          else {
                                              
                                              if([_passcodeManager isWipeEnabled] &&
                                                 [_passcodeManager numberOfFailedAttempts] >= SCP_PASSCODE_MAX_WIPE_ATTEMPTS) {
                                                  
                                                  [SCDataDestroyer setIsWipingData:YES];
                                                  
                                                  [self dismissLockScreen];
                                                  [self updateLabels:YES];
                                                  
                                                  [SCDataDestroyer wipeAllAppDataImmediatelyWithCompletion:^{ exit(0); }];
                                                  
                                                  return;
                                              }
                                              
                                              if([_passcodeManager isPasscodeLocked])
                                              {
                                                  [self showBlurScreen];
                                                  [self dismissLockScreen];
                                              }
                                              else
                                                  [pinLockScreenVC animateInvalidEntryResponse];
                                          }
                                      }];
    
    if(isCancellable)
        [lockScreen setDelegate:self];
    
    UIWindow *lockWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    lockWindow.rootViewController = lockScreen;
    
    [self.appDelegate replaceCurrentWindowWithWindow:lockWindow];
    
    if([_passcodeManager supportsTouchID] && // If device supports Touch ID
       [_passcodeManager isTouchIDEnabled] && // and user has it enabled (enabled by default)
       [_passcodeManager numberOfFailedAttempts] == 0) { // and he hasn't already tried to enter the passcode incorrectly (that's how Apple implements it)
        
        [lockScreen enableTouchIDtarget:self action:@selector(showTouchIDpopup)];
        
        [self showTouchIDpopup];
    }
}

- (void)showTouchIDpopup {
    
    [_passcodeManager presentTouchID:NSLocalizedString(@"Unlock Silent Phone", nil)
                       fallbackTitle:NSLocalizedString(@"Enter Passcode", nil)
                          completion:^(BOOL success, NSError *error) {
                              
                              if(!success)
                                  return;
                              
                              _shouldShowLockScreen = NO;
                              
                              dispatch_async(dispatch_get_main_queue(), ^{
                                  
                                  [self hideBlurScreen:NO];
                                  [self dismissLockScreen];
                                  
                                  if(_passcodeCompletion)
                                      _passcodeCompletion();
                              });
                          }];
}

- (BOOL)isLockScreenActive {
    return _activeLockScreenVC || [self.appDelegate.window.rootViewController isKindOfClass:[MWSPinLockScreenVC class]];
}

- (BOOL)dismissLockScreen {
    
    if(![self isLockScreenActive])
        return NO;

    if(_activeLockScreenVC) {
        
        [_activeLockScreenVC dismissViewControllerAnimated:NO
                                                completion:^{
                                                    
                                                    [self cancelWipeData];
                                                    _activeLockScreenVC = nil;
                                                }];
        
        return YES;
    }
    
    AppDelegate *delegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    
    return [delegate restoreWindow];
}

- (void)supressLockScreenDueToIncomingCall:(NSNotification *)notification {
    
    NSDictionary *callInfo = notification.userInfo;
    
    if([callInfo objectForKey:kSCPCallDictionaryKey]) {
        
        SCPCall *call = (SCPCall *)[callInfo objectForKey:kSCPCallDictionaryKey];
        
        // Only allow incoming calls to supress the lock screen
        if(!call.isIncoming)
            return;
    }
    
    if([self dismissLockScreen])
        [self checkForPasscodeAndBlurScreenAndCheckActiveVC:NO];
}

- (void)presentLockScreenAfterIncomingCallEnds {
    
    if(!_shouldShowLockScreen)
        return;
    
    if([_passcodeManager isPasscodeLocked]) {
        
        [self showBlurScreen];
        return;
    }
    
    [self presentLockScreenCancellable:NO
                            completion:nil];
}

- (void)passcodeManagerDidUnlock {
    
    if(!_failedAttemptsTimer)
        return;

    [self invalidateFailedAttemptsTimer];
    
    [self presentLockScreenCancellable:NO
                            completion:nil];
}

#pragma mark - MWSPinLockScreenDelegate

- (void)lockScreenSelectedCancel:(MWSPinLockScreenVC *)pinLockScreenVC {
    
    [self dismissLockScreen];
}


#pragma mark - Wipe Data

/**
 * This function handles the notification that local device was removed.  
 *
 * With this notification, any view controller currently presented is
 * dismissed and the presentDeviceRemoveDataWipeAlert is called to
 * present an alert to the user, informing them that all data will be
 * wiped from the device.
 */
- (void)handleCurrentDeviceWasRemovedNotification:(NSNotification *)notification {
    
    // If user is already wiping data there is no need to display warning
    // alert. This can happen in case when user has pressed Wipe Data in
    // settings and this device is removed before removing local device data.
    if ([SCDataDestroyer isWipingData])
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        
        if(_wipeSecondsLeft > 0)
            return;
        
        // If there is already an active presented controller (share sheet, active call, alert)
        // then just dismiss it.
        if(self.presentedViewController) {
            
            [self dismissViewControllerAnimated:YES
                                     completion:^{
                                         [self presentDeviceRemovedDataWipeAlert];
                                     }];
        }
        else {
            [self presentDeviceRemovedDataWipeAlert];
        }
    });
}

/**
 * This method begins the automatic data wipe process for an account
 * device removal notification.
 *
 * This method presents an alert informing the user that the device has
 * been deleted, all the data will be removed, and the app will exit.
 *
 * A countdown timer is started which counts down 30 seconds to data
 * wipe execution. The wipeTimer ivar is configured to call back to the
 * alert every second to update the display to show the remaining seconds
 * of the countdown.
 *
 * A "Wipe Now" button is also presented with the alert which gives the
 * option to wipe immediately rather than waiting for the countdown to
 * finish.
 */
- (void)presentDeviceRemovedDataWipeAlert {

    [self overlaySpinnerView];
    
    _wipeSecondsLeft = 30;
    
    _wipeController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"This device has been deleted", nil)
                                                          message:[NSString stringWithFormat:NSLocalizedString(@"This device has been removed from the list of authorized devices so it will close in %d seconds and all of the application data will be cleared.", nil), _wipeSecondsLeft]
                                                   preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *wipeNowAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Wipe Now", nil)
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction *action) {
                                                              
                                                              [SCDataDestroyer setIsWipingData:YES];
                                                              
                                                              [_wipeTimer invalidate];
                                                              _wipeTimer = nil;
                                                              
                                                              [self updateWipeDataOverlayViewForFinish];
                                                              [self executeWipeData];                                                              
                                                          }];
    [_wipeController addAction:wipeNowAction];
    
    [self presentViewController:_wipeController
                       animated:YES
                     completion:nil];
    
    _wipeTimer = [NSTimer scheduledTimerWithTimeInterval:1.
                                                  target:self
                                                selector:@selector(updateWipeAlert:)
                                                userInfo:nil
                                                 repeats:YES];
}

/**
 * 
 *
 */
- (void)updateWipeAlert:(NSTimer*)timer
{
    _wipeSecondsLeft--;
    
    if(_wipeSecondsLeft <= 0) {
        
        [timer invalidate];
        
        [_wipeController setMessage:NSLocalizedString(@"Clearing application data...", nil)];
        
        [SCDataDestroyer wipeAllAppDataImmediatelyWithCompletion:^{ exit(0); }];
        
        return;
    }
    
    [_wipeController setMessage:[NSString stringWithFormat:NSLocalizedString(@"This device has been removed from the list of authorized devices so it will close in %d seconds and all of the application data will be cleared.", nil), _wipeSecondsLeft]];
}

/**
 * Handles the check for lockscreen requirement in the user-requested
 * data wipe process.  
 *
 * A user-requested data wipe process (from side-menu) begins by 
 * presenting a confirmation alert. If the user confirms, this method
 * is called to check for whether the lockscreen feature is enabled,
 * requiring a valid PIN code to proceed with the data wipe. 
 *
 * If the lockscreen feature is disabled, the wipe data process is 
 * initiated immediately.
 *
 * If the lockscreen feature is enabled, the PIN code entry is presented.
 * If the PIN code is entered correctly, the process continues, and 
 * otherwise the data wipe process is canceled.
 */
- (void)checkLockscreenInDataWipeProcess {
    
    // First check if passcode is enabled. If yes, require passcode to be entered first
    BOOL passcodeExists = [_passcodeManager doesPasscodeExist];
    
    if(passcodeExists) {
        
        MWSPinLockScreenVC *lockScreen = [[MWSPinLockScreenVC alloc] 
                                          initWithLabelTitle:NSLocalizedString(@"Enter passcode", nil)
                                          completion:^(MWSPinLockScreenVC *pinLockScreenVC, NSString *passcode) {
                                              
                                              if([_passcodeManager evaluatePasscode:passcode error:nil]) {
                                                  
                                                  [pinLockScreenVC dismissViewControllerAnimated:NO completion:^{
                                                      
                                                      _activeLockScreenVC = nil;
                                                      
                                                      [self updateWipeDataOverlayViewForFinish];
                                                      [self executeWipeData];
                                                  }];
                                              }
                                              else {
                                                  [self cancelWipeData];
                                                  [pinLockScreenVC setUserInteractionEnabled:![_passcodeManager isPasscodeLocked]];
                                                  [pinLockScreenVC animateInvalidEntryResponseWithText:nil
                                                                                            completion:^{ 
                                                                                                [pinLockScreenVC updateLockScreenStatus]; 
                                                                                            }];
                                              }
                                          }];
        lockScreen.delegate                 = self;
        lockScreen.passcodeManager          = _passcodeManager;
        lockScreen.modalPresentationStyle   = UIModalPresentationOverFullScreen;
        lockScreen.modalTransitionStyle     = UIModalTransitionStyleCrossDissolve;
        
        _activeLockScreenVC = lockScreen;
        
        [self presentViewController:lockScreen
                           animated:YES
                         completion:^{ [lockScreen updateLockScreenStatus]; }];
        
    }
    else {
        [self updateWipeDataOverlayViewForFinish];
        [self executeWipeData];
    }
}

/**
 * Handles the first step of a user-requested data wipe action.  
 *
 * A user-requested data wipe process (from side-menu) begins by
 * calling this method, which starts by displaying the dark overlay view
 * (_wipeDataView), and then presents an alert with "Wipe" and "Cancel"
 * buttons.
 * 
 * If the user confirms, the action block calls the 
 * checkLockscreenInDataWipeProcess method for the next step in the 
 * process. That method handles lockscreen requirement to continue the
 * process, which ends with the process canceling or executing.
 */
- (void)handleWipeDataUserRequest {

    if ([SCDataDestroyer isWipingData])
        return;
    
    // If there is already an active presented controller (share sheet, active call, alert)
    // then just dismiss it.
    if(self.presentedViewController) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
    [self overlaySpinnerView];
    
    UIAlertController *ac = [UIAlertController
                             alertControllerWithTitle:NSLocalizedString(@"Are you sure?", nil)
                             message:NSLocalizedString(@"This will clear conversations, call history, and other Silent Phone data.  The application will exit.  You will need to log back in when you restart Silent Phone.", nil)
                             preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action) {
                                       DDLogInfo(@"User Canceled destroy data action.");
                                       [self cancelWipeData];
                                   }];
    
    UIAlertAction *destroyAction = [UIAlertAction
                                    actionWithTitle:NSLocalizedString(@"Wipe", nil)
                                    style:UIAlertActionStyleDestructive
                                    handler:^(UIAlertAction *action) {                                                                                
                                        // Next: Lockscreen enabled check
                                        [self checkLockscreenInDataWipeProcess];
                                    }];
    
    [ac addAction:cancelAction];
    [ac addAction:destroyAction];
    
    [self presentViewController:ac animated:YES completion:nil];
}


- (void)executeWipeData {

    if (UIAccessibilityIsVoiceOverRunning()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self executeWipeActionForVoiceOver];
            return ;
        });
    }
    
    [SCDataDestroyer wipeAllAppDataImmediatelyWithCompletion:^{
        exit(0);
    }];
}

/**
 * Removes the overlay spinner view.
 *
 * This can be called in the user-requested wipe data process in 2 cases:  
 * - User taps Cancel in confirmation alert,  
 * - Lockscreen is required to proceed with data wipe and user input  
 *   pin code fails to validate.
 */
- (void)cancelWipeData {
    [SCDataDestroyer setIsWipingData:NO];
    [self removeOverlayView];
}

- (void)executeWipeActionForVoiceOver {
    self.mainNavCon.view.accessibilityElementsHidden = YES;
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,_wipeSpinnerView.lbMessage);
    dispatch_async(dispatch_get_main_queue(), ^{
        [SCDataDestroyer wipeAllAppDataImmediatelyWithCompletion:^{ 
            exit(0); 
        }];                                                                          
    });
}

/**
 * Updates the wipeSpinnerView to wipe data action final visible state. 
 */
- (void)updateWipeDataOverlayViewForFinish {
    _wipeSpinnerView.spinner.hidden = NO;
    [_wipeSpinnerView.spinner startAnimating];
    _wipeSpinnerView.lbMessage.text = NSLocalizedString(@"Clearing application data...", nil);
}

/**
 * Removes SCSpinnerView from subviews; set ivar to nil.
 */
- (void)removeOverlayView {
    [_wipeSpinnerView removeFromSuperview];
    _wipeSpinnerView = nil;
}

/**
 * Instantiate SCSpinnerView and add as top subview.
 *
 * Activity indicator (spinner) is initially set to hidden.
 */
- (void)overlaySpinnerView {
    SCSpinnerView *spView = [[NSBundle mainBundle] loadNibNamed:@"SCSpinnerView" owner:self options:nil][0];
    spView.frame = self.view.bounds;
    spView.spinner.hidden = YES;
    [self.view addSubview:spView];
    spView.translatesAutoresizingMaskIntoConstraints = YES;
    _wipeSpinnerView = spView;
}


#pragma mark - UIViewController Methods

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if ([self callNavIsPresented]) {
        return [_callNavVC supportedInterfaceOrientations];
    }

    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - Navigation Utilities

- (void)popToConversationsAnimated:(BOOL)animated {
    if (self.mainNavCon.viewControllers.count == 1) {
        // If presenting a vc, dismiss first without animation
        if (self.conversationsVC.presentedViewController) {
            [self.conversationsVC dismissViewControllerAnimated:NO completion:nil];
        }
        return; 
    }
    [self.mainNavCon popToRootViewControllerAnimated:animated];
}

#pragma mark - Convenience Accessors

- (UINavigationController *)mainNavCon {
    return self.childViewControllers[0];
}

- (SCSMainTVC *)conversationsVC {
    return self.mainNavCon.viewControllers[0];
}

- (ChatViewController *)chatVC {
    UINavigationController *navCon = self.mainNavCon;
    if ([navCon.topViewController isKindOfClass:[ChatViewController class]]) {
        return (ChatViewController*)navCon.topViewController;
    }
    
    return nil;
}

- (UISideMenuNavigationController *)sideMenuNavCon {
    return [SideMenuHelper sideMenuNavCon];
}

- (SideMenuTVC *)sideMenuTVC {
    return (SideMenuTVC *)self.sideMenuNavCon.viewControllers[0];
}

- (UIStoryboard *)mainSB {
    return [UIStoryboard storyboardWithName:@"Main" bundle:nil];
}

- (AppDelegate *)appDelegate {
    return (AppDelegate *)[UIApplication sharedApplication].delegate;
}


#if HAS_DATA_RETENTION
-(void) displayDRProhibitionAlert
{
    NSString *title = @"Communication Prohibited";
    NSString *org = ([UserService currentUser].drEnabled) ? @"Your " : @"Recipient's ";
    NSString *msg = [org stringByAppendingString:kDRPolicy];
    
    UIAlertController *errorController = [UIAlertController alertControllerWithTitle:NSLocalizedString(title, nil) message:NSLocalizedString(msg, @"Data retention settings conflict") preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [errorController addAction:okAction];
    [self presentViewController:errorController animated:YES completion:nil];
}
#endif // HAS_DATA_RETENTION


@end
