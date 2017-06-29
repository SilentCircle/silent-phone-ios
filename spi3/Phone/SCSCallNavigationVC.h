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
//  SCContainerVC.h
//  VoipPhone
//
//  Created by Eric Turner on 8/7/15.
//
//

#import <UIKit/UIKit.h>
#import "SCSCallNavDelegate.h"

@protocol SCSTransitionDelegate;

//TESTING
@class SCSCallHandlerVC;
@class SCSConferenceCVC;
@class SCSConferenceTVC;
@class CallScreenVC;
@class SCVideoVC;

/** OUTDATED: - current VC is transient, removed for each switch/transition.
 *
 * This class manages the transitions between call handling controllers,
 * currently: call screen, conference, and video controllers.
 *
 * The viewControllers array property is implemented as a setter as a
 * convenience for initializing. When initialized with an array of 
 * controllers, this class manages adding them as childViewControllers
 * with the appropriate setup calls to each.
 *
 * Note that childViewControllers are stored in the order given in the
 * setViewControllers property setter and in the
 * setViewControllers:animationOption:duration method. The
 * presentChildVcAtIndex: method makes active the view controller
 * indexed in the initialization order.
 *
 * Also note that the last view controller in the viewControllers array
 * will become active first by default.
 */
@interface SCSCallNavigationVC : UIViewController <SCSCallNavDelegate>

@property (weak, nonatomic) id<SCSTransitionDelegate> transitionDelegate;

/** A pointer to the currently active childViewController. 
 * NOTE: if the current childViewController is a UINavigationController
 * the first/root viewController in its viewControllers array is returned.
 * Currently SCSRootVC queries this property for interfaceOrientation
 * and rotation queries.
 */
@property (readonly, nonatomic) UIViewController *activeVC;

/** Flag is TRUE when transitioning between child VCs. */
@property (readonly, nonatomic) BOOL isTransitioningChildVC;

// CallHandler instance accessors
//- (SCSConferenceCVC *)confCVC;
//- (SCSConferenceTVC *)confTVC;
- (SCSCallHandlerVC *)conferenceVC;
- (CallScreenVC *)callScreenVC;
- (SCVideoVC *)videoVC;
- (UIStoryboard *)phoneSB;

// Helper method returns rootVC if given navigationController
- (UIViewController *)theRootViewController:(UIViewController *)vcORnavcon;

- (void)presentVC:(UIViewController *)vc;
- (void)presentVCWithAnimation:(UIViewController *)vc;
- (void)presentVCWithAnimation:(UIViewController *)vc completion:(void (^)())completion;
- (void)presentVC:(UIViewController *)vc animationOption:(UIViewAnimationOptions)options completion:(void (^)())completion;
- (void)presentVC:(UIViewController *)vc animationOption:(UIViewAnimationOptions)options duration:(NSTimeInterval)dur completion:(void (^)())completion;

/**
 * The property exists for adding an array of viewControllers to the
 * self childViewControllers array.
 *
 * This method first removes all existing childViewControllers from the
 * self childViewControllers array, and the currently active child 
 * viewController's subview from the self view, then adds the given 
 * controllers to the childViewControllers array.
 *
 * Note: this property is set to nil after adding the given
 * viewControllers to the self childViewControllers array. The self
 * view, which may be empty (as this is a container view controller), is
 * the remaining view at the completion of this setter method.
 *
 * After adding controllers to the childViewControllers array via this
 * property setting, use the
 * presentChildVcWithIndex:animationOption:duration: method to swap
 * between them.
 *
 * @param viewControllers An array of UIViewControllers which will
 *        replace any existing viewControllers in the self 
 *        childViewControllers array.
 *
 * @see setViewControllers:animationOption:duration:
 *
 * @see presentChildVcWithIndex:animationOption:duration:
 */
//@property (strong, nonatomic) NSArray *viewControllers;


/**
 * This method adds the given array of view controllers as self
 * childViewControllers. The last viewController instance in the array
 * is presented with given animation arguments.
 *
 * @param options The UIViewAnimationOptions bit mask which to apply to
 *                the transition animation.
 *
 * @param duration The duration of time in seconds over which to animate
 *                 the transition between childViewControllers
 *
- (void)setViewControllers:(NSArray *)VCs
           presentingIndex:(NSUInteger)idx
           animationOption:(UIViewAnimationOptions)options
                  duration:(NSTimeInterval)duration;
*/

/**
 * This method transitions between the current active childViewController
 * to the childViewController at the given index in the self
 * childViewControllers array. The view of the active childViewController
 * is swapped with the view of that at the index, with animation options.
 *
 * The "incoming" childViewController will be made the activeVC, with
 * its view as a full size subview of the self view, at the end of the
 * transition animation, and the "outgoing" childViewController's view
 * will be removed from the self view.
 *
 * @param idx The index into the childViewControllers array of the 
 *            childViewController to present.
 *
 * @param options The UIViewAnimationOptions bit mask which to apply to
 *                the transition animation.
 *
 * @param duration The duration of time in seconds over which to animate
 *                 the transition between childViewControllers
 *
- (void)presentChildVcAtIndex:(NSUInteger)idx
              animationOption:(UIViewAnimationOptions)options
                     duration:(NSTimeInterval)duration;
*/

/**
 * Presents the viewController at given index into the
 * childViewControllers array with optional default animation.
 *
 * This method wraps a call to self 
 * presentChildVcAtIndex:animationOption:duration:.
 *
 * @param idx The index into the childViewControllers array of the
 *            childViewController to present.
 *
 * @param animated If YES, animate with default animation options;
 *                 if NO, animate with "animation none" options.
 */
//- (void)presentChildVcAtIndex:(NSUInteger)idx animated:(BOOL)animated;

/**
 * This method transitions between the current active childViewController
 * to the given viewController. The view of the active childViewController
 * is swapped with the view of the given viewController, with animation options.
 * 
 * The given viewController will be made the active childViewController,
 * and the former active childViewController will be removed from the
 * self childViewControllers array, at the completion of the transition
 * animation.
 *
 * @param idx The index into the childViewControllers array of the
 *            childViewController to present.
 *
 * @param options The UIViewAnimationOptions bit mask which to apply to
 *                the transition animation.
 *
 * @param duration The duration of time in seconds over which to animate
 *                 the transition between childViewControllers
 *
 * REMOVED UNUSED 12/14/15
 *
- (void)presentVC:(UIViewController *)vc
  animationOption:(UIViewAnimationOptions)option
         duration:(NSTimeInterval)duration;
*/

// 12/22/15 PUBLIC
//- (NSUInteger)indexOfFirstFoundChildVCOfClass:(Class)aClass;


#pragma mark - TESTING
//@see SCSCallNavDelegate
//- (void)switchTestingConferenceVC:(SCSCallHandlerVC *)vc call:(SCPCall *)aCall;

@end
