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
//  SCContainerVC.m
//  VoipPhone
//
//  Created by Eric Turner on 8/7/15.
//
//

#import "SCSCallNavigationVC.h"
#import "SCSCallNavDelegate.h"
#import "SCSTransitionDelegate.h"
#import "CallScreenVC.h"
#import "SCSConferenceCVC.h"
#import "SCSConferenceTVC.h"
#import "SCVideoVC.h"
#import "SCPNotificationKeys.h"
#import "SCSCallHandlerVC.h"
//#import "SCSConstants.h"
#import "SCSFeatures.h"

static NSString * const kConfGridViewKey      = @"ConfGridView";

static NSTimeInterval         const kDefaultAnimationDuration = 0.5;
static UIViewAnimationOptions const kDefaultAnimationOptions  = UIViewAnimationOptionTransitionCrossDissolve;


@interface SCSCallNavigationVC ()
// At least for now, assume instance of SCSCallHandlerVC
@property (nonatomic, weak) UIViewController *currentVC;
/** Flag is TRUE when transitioning between child VCs. */
@property (nonatomic) BOOL selfWillBeDismissed;
@end


@implementation SCSCallNavigationVC
{
    BOOL _transitionInProgress;
}


- (void)awakeFromNib {
    
    [super awakeFromNib];

    /* burger - DEPRECATE
    [self registerForNotifications];
     */
}

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - SCSCallNavDelegate
- (void)switchToCallScreen:(UIViewController *)vc call:(SCPCall*)aCall {
    CallScreenVC *cvc = (vc) ? (CallScreenVC *)[self theRootViewController:vc] : [self callScreenVC];
    
    cvc.call = aCall;
    vc = (vc) ?: cvc;

    [self presentVCWithAnimation:vc];
}

- (void)switchToConference:(UIViewController *)vc call:(SCPCall*)aCall {
    if (nil == vc) {
        vc = [self conferenceVC];
    }

    [self presentVCWithAnimation:vc];
}

/**
 * Switches from the current conference controller, tableView or
 * collectionView, to the other.
 *
 * Calls the setUseConfGridOrListViewAsync method to store the choice
 * in NSUserDefaults.
 *
 * @param vc The conference tableView or collectionView controller
 *        from which the user tapped the switch-to-grid-or-list button.
 */
- (void)switchFromConfVC:(SCSCallHandlerVC *)vc {
    SCSCallHandlerVC *confVC = nil;
    BOOL gridOrList = NO;
    if ([vc isKindOfClass:[SCSConferenceCVC class]]) {
        confVC = [self confTVC];
    }
    else if ([vc isKindOfClass:[SCSConferenceTVC class]]) {
        confVC = [self confCVC];
        gridOrList = YES;
    } else {
        NSLog(@"%s UNEXPECTED TYPE in test method: %@",__PRETTY_FUNCTION__, vc);
    }

    [self setUseConfGridOrListViewAsync:gridOrList];
    
    [self presentVCWithAnimation:confVC];
}


- (void)switchToVideo:(UIViewController *)vc call:(SCPCall*)aCall {
    SCVideoVC *vvc = (vc) ? (SCVideoVC *)[self theRootViewController:vc] : [self videoVC];
    vvc.call = aCall;
    vc = (vc) ?: vvc;

    [self presentVCWithAnimation:vc];
}

- (void)switchToChatWithCall:(SCPCall*)aCall {
    if ([_transitionDelegate respondsToSelector:@selector(transitionToChatFromVC:withCall:)]) {

        [_transitionDelegate transitionToChatFromVC:_currentVC withCall:aCall];
    }
}

- (void)switchToConversationsWithCall:(SCPCall*)aCall {
    if ([_transitionDelegate respondsToSelector:@selector(transitionToConversationsFromVC:withCall:)]) {
        [_transitionDelegate transitionToConversationsFromVC:_currentVC withCall:aCall];
    }
}

// Is this used?
- (void)handleLocalUserEndedCall:(SCPCall*)aCall {
    if ([_transitionDelegate respondsToSelector:@selector(localUserEndedCall:)]) {
        [_transitionDelegate localUserEndedCall:aCall];
    }
}

#pragma mark - Utilities

- (void)prepareTransitionForIncomingVC:(UIViewController *)inVC outgoingVC:(UIViewController *)outVC {
    SCSCallHandlerVC *ivc = (SCSCallHandlerVC*)[self theRootViewController:inVC];
    ivc.isInTransition = YES;
    SCSCallHandlerVC *ovc = (SCSCallHandlerVC*)[self theRootViewController:outVC];
    ovc.isInTransition = YES;
    [ivc prepareToBecomeActive];
    [ovc prepareToBecomeInactive];
}

- (void)completeTransitionForIncomingVC:(UIViewController *)inVC outgoingVC:(UIViewController *)outVC {
    SCSCallHandlerVC *ivc = (SCSCallHandlerVC*)[self theRootViewController:inVC];
    ivc.isInTransition = NO;
    SCSCallHandlerVC *ovc = (SCSCallHandlerVC*)[self theRootViewController:outVC];
    ovc.isInTransition = NO;
}

// Helper method returns rootVC if given navigationController
- (UIViewController *)theRootViewController:(UIViewController *)vcORnavcon {
    UIViewController *vc = vcORnavcon;
    if ([vcORnavcon isKindOfClass:[UINavigationController class]]){
        NSAssert([(UINavigationController*)vcORnavcon viewControllers].count == 1,
                 @"NavigationController passed here should have only a rootViewController child");
        
        UINavigationController *navcon = (UINavigationController*)vcORnavcon;
        vc = navcon.viewControllers[0];
    }
    return vc;
}

/**
 * The last "view collection", list (tableView) or grid (collectionView)
 * chosen by the user is stored in NSUserDefaults.
 *
 * This method is called by the method called to switch to the 
 * conference controller. It compares the boolean value passed with the
 * current stored value and updates the store value if different. This
 * is wrapped in an asynchronous block.
 *
 * @param userGridView YES to use conference collectionView for next use
 *        or NO to use listView on next use.
 */
- (void)setUseConfGridOrListViewAsync:(BOOL)useGridView {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:useGridView] forKey:kConfGridViewKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
}

- (BOOL)shouldUseConferenceGridView {
    return [[[NSUserDefaults standardUserDefaults] objectForKey:kConfGridViewKey] boolValue];
}


#pragma mark - Presentation Methods

- (void)presentVC:(UIViewController *)vc {
    [self presentVC:vc animationOption:UIViewAnimationOptionTransitionNone duration:0 completion:nil];
}
- (void)presentVCWithAnimation:(UIViewController *)vc {
    [self presentVC:vc animationOption:kDefaultAnimationOptions duration:kDefaultAnimationDuration completion:nil];
}
- (void)presentVCWithAnimation:(UIViewController *)vc completion:(void (^)())completion {
    [self presentVC:vc animationOption:kDefaultAnimationOptions duration:kDefaultAnimationDuration completion:completion];
}
- (void)presentVC:(UIViewController *)vc animationOption:(UIViewAnimationOptions)options completion:(void (^)())completion
{
    [self presentVC:vc animationOption:options duration:kDefaultAnimationDuration completion:completion];
}

- (void)presentVC:(UIViewController *)vc animationOption:(UIViewAnimationOptions)options duration:(NSTimeInterval)dur completion:(void (^)())completion
{
    // This may be called by the viewControllers setter methods, so we
    // check for a nil _currentVC. If outgoingVC local var is nil, the
    // transitionFromViewController: method below will throw an exception.
    if (nil == _currentVC) {
        vc.view.frame = self.view.bounds;
        vc.view.translatesAutoresizingMaskIntoConstraints = YES;
        [self.view addSubview:vc.view];
        [self addChildViewController:vc];
        _currentVC = vc;
//        [vc beginAppearanceTransition:YES animated:YES];
        [self prepareTransitionForIncomingVC:vc outgoingVC:nil];
        [self completeTransitionForIncomingVC:vc outgoingVC:nil];
//        [vc endAppearanceTransition];
        [vc didMoveToParentViewController:self];
        return;
    }

    
    // Disallow re-presenting current vc
    if (vc == _currentVC) {
        NSLog(@"%s ALERT: Called to present vc which is already active. Ignore/return.",__PRETTY_FUNCTION__);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        _transitionInProgress = YES;
    });
    
    if ([vc respondsToSelector:@selector(navDelegate)]) {
        [vc setValue:self forKey:@"navDelegate"];
    }
    //------------------------------------------------------------------
    // Set transitioning flags and immediately update _currentVC
    // NOTE: this is new behavior since SCSCallHandlerVC subclassing -
    // previously the _currentVC was updated in the completion block.
    // (At least for now, assume SCSCallHandlerVC instances)
    UIViewController *incomingVC = vc;
    __block UIViewController *outgoingVC = _currentVC;
    
    [self addChildViewController:incomingVC];
    
    _currentVC = incomingVC;
    //------------------------------------------------------------------
    
    incomingVC.view.translatesAutoresizingMaskIntoConstraints = NO;

    /* NOTE:
     * These lines have been implemented when looking for issues related
     * to viewWill/DidAppear/Disappear in childVCs. However, the UIVC
     * shouldAutomaticallyForwardAppearanceMethods method returns YES by
     * default and this seems to work as expected, making the following
     * lines unnecessary before the transitionFromVC call, and the
     * balancing endTransition calls in the completion block:
     *
     * [incomingVC beginAppearanceTransition:YES animated:YES];
     * [outgoingVC beginAppearanceTransition:NO animated:YES];
     */
    
    [self transitionFromViewController:outgoingVC
                      toViewController:incomingVC
                              duration:dur
                               options:options
                            animations:^{
                                [incomingVC didMoveToParentViewController:self];
                                [self updateViewConstraintsWithVC:incomingVC];
                            }
                            completion:^(BOOL finished) {
//                                [self completeTransitionForIncomingVC:incomingVC outgoingVC:outgoingVC];
                                _transitionInProgress = NO;

                                [outgoingVC willMoveToParentViewController:nil];
                                [outgoingVC removeFromParentViewController];
                                
                                if (completion) {
                                    completion();
                                }
                                
                                outgoingVC = nil;
                            }];
}

/* burger DEPRECATE
#pragma mark - Notifications

- (void)notificationHandler:(NSNotification *)notif {
    if ([notif.name isEqualToString:kSCPWillRemoveCallScreenNavNotification]) {
        _selfWillBeDismissed = YES;
    }
}

- (void)registerForNotifications {
    
    NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
    [notifCenter addObserver:self
                    selector:@selector(notificationHandler:)
                        name:kSCPWillRemoveCallScreenNavNotification
                      object:nil];
}

- (void)unRegisterForNotifications {
    
    NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
    [notifCenter removeObserver:self name:kSCPWillRemoveCallScreenNavNotification object:nil];
}
*/

#pragma mark - AutoLayout

- (void)updateViewConstraintsWithVC:(UIViewController *)vc {
    
    UIView *childView = vc.view;
    childView.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Pin top/bottom
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[childView]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:NSDictionaryOfVariableBindings(childView)]];
    // Pin left/right
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[childView]|"
                                                                      options:0
                                                                      metrics:nil
                                                                        views:NSDictionaryOfVariableBindings(childView)]];
    [self updateViewConstraints];
}



#pragma mark - UIViewController Methods

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    
    UIInterfaceOrientationMask mask = UIInterfaceOrientationMaskPortrait;
    
    if ([self.activeVC isKindOfClass:[SCVideoVC class]] && NO == _selfWillBeDismissed)
        mask = UIInterfaceOrientationMaskAll;
    
    // Detect when we have to be on portrait mode (e.g. we are on the Call Screen), but the UI is in landscape (e.g. we dismissed the VideoVC
    // while in landscape mode)
    if(mask == UIInterfaceOrientationMaskPortrait && [UIApplication sharedApplication].statusBarOrientation != UIInterfaceOrientationPortrait) {

        // References:
        // http://stackoverflow.com/a/20987296
        // http://stackoverflow.com/a/24259601
        // http://stackoverflow.com/a/26358192
        //
        // While this is not actually a documented solution, I couldn't find a better way to do it.
        // Please note that this is a 'hidden' use of the API, and the only reason we do it is so that
        // the app has to be in line with the supportedInterfaceOrientation (UIInterfaceOrientationMaskPortrait),
        // when the videoVC gets dismissed, while we are on landscape mode.
        //
        // Feel free to change this solution to a more elegant one!
        [[UIDevice currentDevice] setValue:@(UIInterfaceOrientationPortrait)
                                    forKey:@"orientation"];
    }
    
    return mask;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


#pragma mark - Accessors

- (UIStoryboard *)phoneSB {
    return [UIStoryboard storyboardWithName:@"Phone" bundle:nil];
}

- (SCSCallHandlerVC *)conferenceVC {
    
    if (! [SCSFeatures conferenceGridView]) {
        return [self confTVC];
    }
    
    SCSCallHandlerVC *vc = nil;
    BOOL gridOrList = [self shouldUseConferenceGridView];
    vc = (gridOrList) ? [self confCVC] : [self confTVC];
    return vc;
}

- (SCSConferenceCVC *)confCVC {
    if ([_currentVC isKindOfClass:[SCSConferenceCVC class]]) {
        return (SCSConferenceCVC *)_currentVC;
    }
    SCSConferenceCVC *cvc = [[self phoneSB] instantiateViewControllerWithIdentifier:@"SCSConferenceCVC"];
    cvc.navDelegate = self;
    return cvc;
}

- (SCSConferenceTVC *)confTVC {
    if ([_currentVC isKindOfClass:[SCSConferenceTVC class]]) {
        return (SCSConferenceTVC *)_currentVC;
    }
    SCSConferenceTVC *cvc = [[self phoneSB] instantiateViewControllerWithIdentifier:@"SCSConferenceTVC"];
    cvc.navDelegate = self;
    return cvc;
}

- (CallScreenVC *)callScreenVC {
    if ([_currentVC isKindOfClass:[CallScreenVC class]]) {
        return (CallScreenVC *)_currentVC;
    }
    CallScreenVC *cs = [[self phoneSB] instantiateViewControllerWithIdentifier:@"CallScreenVC"];
    cs.navDelegate = self;
    return cs;
}

- (SCVideoVC *)videoVC {
    if ([_currentVC isKindOfClass:[SCVideoVC class]]) {
        return (SCVideoVC *)_currentVC;
    }
    SCVideoVC *vvc = [[self phoneSB] instantiateViewControllerWithIdentifier:@"SCVideoVC"];
    vvc.navDelegate = self;
    return vvc;
}

// returns private ivar
- (UIViewController *)activeVC {
    return [self theRootViewController:_currentVC];
}

// returns private ivar
- (BOOL)isTransitioningChildVC {
    return _transitionInProgress;
}

@end
