/*
Copyright (C) 2016, Silent Circle, LLC.  All rights reserved.

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

#import "SCContainerVC.h"

@interface SCContainerVC ()
@property (nonatomic, strong) UIViewController *currentVC;
@end

@implementation SCContainerVC


- (instancetype)initWithViewController:(UIViewController*)vc {
    
    self = [super init];
    
    if (!self || !vc) { 
        NSLog(@"%s\nERROR initializing %@ at line %d", 
              __PRETTY_FUNCTION__, NSStringFromClass([self class]), __LINE__);
        return nil; 
    }

    [self addChildViewController:vc];
    vc.view.frame = self.view.bounds;
    vc.view.translatesAutoresizingMaskIntoConstraints = YES;
    [self.view addSubview:vc.view];

    _currentVC = vc;
    
    return self;
}

// implemented just to log deallocation
// This class is ARC-enabled
- (void)dealloc {
    NSLog(@"%s",__PRETTY_FUNCTION__);
//    [super dealloc];
}

- (void)presentVC:(UIViewController *)vc animationOption:(UIViewAnimationOptions)option duration:(NSTimeInterval)duration {

    if (vc == _currentVC) {
        NSLog(@"%s ALERT: Called to present vc which is already active. Ignore/return.",__PRETTY_FUNCTION__);
        return;
    }
    
    UIViewController *outgoingVC = _currentVC;
    __block UIViewController *incomingVC = vc;
    
    incomingVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self addChildViewController:incomingVC];
    
    [self transitionFromViewController:outgoingVC 
                      toViewController:incomingVC 
                              duration:duration
                               options:option
                            animations:^{
                                NSLog(@"%s animations block",__PRETTY_FUNCTION__);
                                [self.view addSubview:incomingVC.view];
                                [self updateViewConstraintsWithVC:incomingVC];
                            }
                            completion:^(BOOL finished) {
                                [incomingVC didMoveToParentViewController:self];                                
                                
                                [outgoingVC willMoveToParentViewController:nil];
                                [outgoingVC.view removeFromSuperview];
                                [outgoingVC removeFromParentViewController];
                                
                                self.currentVC = incomingVC;
                            }];
}

/** 01/31/13 serverTrainingLogin: implement AutoLayout */
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

- (UIViewController *)activeVC {
    return _currentVC;
}

- (NSUInteger)supportedInterfaceOrientations {
    return [self.activeVC supportedInterfaceOrientations];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    NSLog(@"%s\n ------  RECEIVED MEMORY WARNING --------\n\n",__PRETTY_FUNCTION__);

}

@end
