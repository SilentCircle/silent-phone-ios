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
//  OnboardingViewController.m
//  SPi3
//
//  Created by Gints Osis on 08/04/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "OnboardingViewController.h"

#import "AppDelegate.h"
#import "Prov.h"
#import "Silent_Phone-Swift.h"
#import "UIColor+ApplicationColors.h"

NSString * const kFirstViewControllerIdentifier = @"Onboarding1";
NSString * const kSecondViewControllerIdentifier = @"Onboarding2";
NSString * const kThirdViewControllerIdentifier = @"Onboarding3";
@interface OnboardingViewController ()
{
    int nextIndex;    
    CAGradientLayer *gradientLayer;
}
@end

@implementation OnboardingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    nextIndex = 0;
    [self setViewControllers:@[[self getFirstViewController]] direction:UIPageViewControllerNavigationDirectionForward animated:YES completion:nil];
    self.dataSource = self;
    self.delegate = self;
    
    [self.view addSubview: self.pageControl];
    [self.view addSubview:self.buttonView];
    
    _loginButton.layer.borderWidth = 2.0f;
    _loginButton.layer.borderColor = [UIColor recentsNoConversationsRedColor].CGColor;
    
    [self.view setBackgroundColor:[UIColor onboardingGradientColor]];
    
    [self.imageView setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    
    [self.view addSubview:self.imageView];
    
    
    gradientLayer = [CAGradientLayer layer];
    gradientLayer.frame = self.view.bounds;
    gradientLayer.colors = [NSArray arrayWithObjects:(id)[[UIColor clearColor] CGColor], (id)[[UIColor onboardingGradientColor] CGColor], nil];
    gradientLayer.locations = @[@0.0,@0.6];
    [self.gradientView.layer insertSublayer:gradientLayer atIndex:0];
    
    [self.view addSubview:self.gradientView];
    
    [self.view sendSubviewToBack:self.gradientView];
    [self.view sendSubviewToBack:self.imageView];
    
    
    // since pagecontroller doesn't have a view in storyboard, we have to add LayoutConstraint's in code    
    _gradientView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[_gradientView]-0-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_gradientView)]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[_gradientView]-0-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_gradientView)]];
    
    
    _buttonView.translatesAutoresizingMaskIntoConstraints = NO;
    // limit the button width to 1/2 view width, mainly for iPads
    CGFloat width = self.view.bounds.size.width / 2;
    NSString *btWidthVisFormat = [NSString stringWithFormat:@"H:|-%1.2f-[_buttonView]-%1.2f-|", width/2, width/2];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:btWidthVisFormat options:0 metrics:nil views:NSDictionaryOfVariableBindings(_buttonView)]];

    // Space from bottom of view to button conditional on device - for iPhone 4s support
    NSString *space = [self buttonSpaceString];
    NSString *btViewVisFormat = [NSString stringWithFormat:@"V:[_buttonView]-%@-|", space];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:btViewVisFormat options:0 metrics:nil views:NSDictionaryOfVariableBindings(_buttonView)]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_buttonView(==40)]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_buttonView)]];
    
    
    _pageControl.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-10-[_pageControl]-10-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_pageControl)]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_pageControl]-30-[_buttonView]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_buttonView,_pageControl)]];
    
    
    // view acting as a statusview's background
    UIView *statusBarView =  [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 22)];
    statusBarView.backgroundColor  =  [UIColor onboardingGradientColor];
    [self.view addSubview:statusBarView];
    
    statusBarView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[statusBarView]-0-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(statusBarView)]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[statusBarView(==22)]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(statusBarView)]];
    
    
}

// helper method to return smaller bottom space to login button 
// for iPhone 4s, and
// more space fro iPads
- (NSString *)buttonSpaceString {
    MWSDeviceType dType = [MWSDevice deviceType];
    NSString *space = @"80";
    switch (dType) {
        case MWSDeviceTypeMwSiPhone_4_or_less:
            space = @"44";
            break;
        case MWSDeviceTypeMwSiPhone_iPad:
        case MWSDeviceTypeMwSiPhone_iPadPro:
            space = @"100";
            break;
        case MWSDeviceTypeMwSiPhone_5:
        case MWSDeviceTypeMwSiPhone_6_7:
        case MWSDeviceTypeMwSiPhone_6_7P:
        case MWSDeviceTypeMwsDeviceUnknown:
            break;
    } 
    return space;
}


-(void)viewWillLayoutSubviews
{
    // we add a big number to width and height, so we wouldn't see Imageview without gradient for a brief moment when we rotate
    CGRect screenRect = [UIScreen mainScreen].bounds;
     gradientLayer.frame = CGRectMake(0, 0, screenRect.size.width + 1000, screenRect.size.height + 1000);
}


#pragma mark UIPageviewControllerDelegate
-(UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    
    if ([viewController.restorationIdentifier isEqualToString:kFirstViewControllerIdentifier]) {
        return [self getSecondViewController];
    } else if ([viewController.restorationIdentifier isEqualToString:kSecondViewControllerIdentifier]) {
        return [self getThirdViewController];
    } else if ([viewController.restorationIdentifier isEqualToString:kThirdViewControllerIdentifier]) {
    }
     return nil;
}
-(UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    if ([viewController.restorationIdentifier isEqualToString:kFirstViewControllerIdentifier]) {
        return nil;
    } else if ([viewController.restorationIdentifier isEqualToString:kSecondViewControllerIdentifier]) {
        return [self getFirstViewController];
    } else if ([viewController.restorationIdentifier isEqualToString:kThirdViewControllerIdentifier]) {
        [self getSecondViewController];
    }
    return nil;
}

-(void)pageViewController:(UIPageViewController *)pageViewController willTransitionToViewControllers:(NSArray<UIViewController *> *)pendingViewControllers
{
    UIViewController *contentViewC = (UIViewController*) pendingViewControllers[0];
    
    if ([contentViewC.restorationIdentifier isEqualToString:kFirstViewControllerIdentifier])
    {
        nextIndex = 0;
    } else if ([contentViewC.restorationIdentifier isEqualToString:kSecondViewControllerIdentifier])
    {
        nextIndex = 1;
    }else if ([contentViewC.restorationIdentifier isEqualToString:kThirdViewControllerIdentifier])
    {
        nextIndex = 2;
    }
}
-(void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed
{
    self.pageControl.currentPage = nextIndex;
    
    // dissolve background image change
    [UIView transitionWithView:self.onboardingImageView
                      duration:0.5f
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        self.onboardingImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"Onboarding%i.jpg",nextIndex]];
                    } completion:NULL];
    
}
-(UIInterfaceOrientationMask)pageViewControllerSupportedInterfaceOrientations:(UIPageViewController *)pageViewController
{
    return UIInterfaceOrientationMaskPortrait;
}


#pragma mark ViewControllers
-(UIViewController *) getFirstViewController
{
    return [self.storyboard instantiateViewControllerWithIdentifier:@"Onboarding1"];
}

-(UIViewController *) getSecondViewController
{
    return [self.storyboard instantiateViewControllerWithIdentifier:@"Onboarding2"];
}

-(UIViewController *) getThirdViewController
{
    return [self.storyboard instantiateViewControllerWithIdentifier:@"Onboarding3"];
}

- (IBAction)loginAction:(id)sender {
    
    [self.provDelegate showProvisioningFromOnboarding];
}

#pragma mark SCProvisioningDelegate
// implemented to silence warning since it is required for SCProvisioningDelegate
-(void)provisioningDidFinish
{
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
