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
//  SingleOnboardingViewController.m
//  SPi3
//
//  Created by Gints Osis on 11/04/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "SingleOnboardingViewController.h"
#import "UIColor+ApplicationColors.h"
#import "MaskedView.h"

#define kTriangleHeight 50
@interface SingleOnboardingViewController ()
{
    //Onboarding1
    MaskedView *leftSideView1;
    MaskedView *rightSideView1;
    
    //Onboarding2
    MaskedView *leftSideView2;
    MaskedView *rightSideView2;
    
    //Onboarding3
    MaskedView *rightSideView3;
    
    // bottom offset of labelView, gets animated with shake
    int labelViewStartingBottomOffset;
    
}
@end

@implementation SingleOnboardingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    labelViewStartingBottomOffset = _labelViewBottomOffset.constant;
    
}

-(void)viewWillDisappear:(BOOL)animated
{
    [self resetFrames];
}

-(void) showTriangles
{
    // create triangles depending on Singleviewcontrollers restoration identifier
    if ([self.restorationIdentifier isEqualToString:@"Onboarding1"])
    {
        if (!leftSideView1 || !rightSideView1)
        {
            [self createMaskedViewsForOnboarding1];
        }
        [self showMaskedViewsForOnboarding1];
    } else if([self.restorationIdentifier isEqualToString:@"Onboarding2"])
    {
        if (!leftSideView2 || !rightSideView2)
        {
            [self createMaskedViewsForOnboarding2];
        }
        [self showMaskedViewsForOnboarding2];
    } else if([self.restorationIdentifier isEqualToString:@"Onboarding3"])
    {
        if (!rightSideView3) {
            [self createMaskedViewsForOnboarding3];
        }
        [self showMaskedViewsForOnboarding3];
    }
}
-(void)viewDidAppear:(BOOL)animated
{
    [self showTriangles];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Onboarding animations
-(void) showMaskedViewsForOnboarding1
{
    [self.view.layer removeAllAnimations];
    [UIView animateWithDuration:0.2
                          delay:0.0
                        options:0
                     animations:^{
                         CGRect frame = leftSideView1.frame;
                         frame.origin.y -=kTriangleHeight *2;
                         leftSideView1.frame = frame;
                     }
                     completion:NULL];
    
    [UIView animateWithDuration:0.2
                          delay:0.1
                        options:0
                     animations:^{
                         CGRect frame = rightSideView1.frame;
                         frame.origin.y -=kTriangleHeight;
                         rightSideView1.frame = frame;
                     }
                     completion:^(BOOL finished){
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [self shakeLabels];
                         });
                     }];
    
}

-(void) showMaskedViewsForOnboarding2
{
    [self.view.layer removeAllAnimations];
    [self resetFrames];
    [UIView animateWithDuration:0.2
                          delay:0.0
                        options:0
                     animations:^{
                         CGRect frame = leftSideView2.frame;
                         frame.origin.y -=kTriangleHeight;
                         leftSideView2.frame = frame;
                     }
                     completion:NULL];
    
    [UIView animateWithDuration:0.2
                          delay:0.1
                        options:0
                     animations:^{
                         CGRect frame = rightSideView2.frame;
                         frame.origin.y -=kTriangleHeight;
                         rightSideView2.frame = frame;
                     }
                     completion:^(BOOL finished){
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [self shakeLabels];
                         });
                     }];
    
}

-(void) showMaskedViewsForOnboarding3
{
    [self.view.layer removeAllAnimations];
    [self resetFrames];
    [UIView animateWithDuration:0.2
                          delay:0.0
                        options:0
                     animations:^{
                         CGRect frame = rightSideView3.frame;
                         frame.origin.x -=self.view.frame.size.width/2 - 50;
                         rightSideView3.frame = frame;
                     }
                     completion:^(BOOL finished){
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [self shakeLabels];
                         });
                     }];
    
}

// reset's frames of all triangles
-(void) resetFrames
{
    CGRect frame = leftSideView1.frame;
    if (leftSideView1 && rightSideView1) {

        frame = leftSideView1.frame;
        frame.origin.y = self.view.frame.size.height;
        leftSideView1.frame = frame;
        
        frame = rightSideView1.frame;
        frame.origin.y = self.view.frame.size.height;
        rightSideView1.frame = frame;
    }
    
    if (leftSideView2 && rightSideView2) {
        frame = leftSideView2.frame;
        frame.origin.y = self.view.frame.size.height;
        leftSideView2.frame = frame;
        
        frame = rightSideView2.frame;
        frame.origin.y = self.view.frame.size.height;
        rightSideView2.frame = frame;
    }
    
    if (rightSideView3) {
        frame = rightSideView3.frame;
        frame.origin.x = self.view.frame.size.width;
        rightSideView3.frame = frame;
    }
    
    _labelViewBottomOffset.constant = labelViewStartingBottomOffset;
}


-(void) createMaskedViewsForOnboarding1
{
    // Animating these with autolayout turned out to be a nightmare, so they are created in code
    
    leftSideView1 = [[MaskedView alloc] initWithFrame:CGRectMake(-self.view.frame.size.width, self.view.frame.size.height, self.view.frame.size.width / 2 + self.view.frame.size.width, kTriangleHeight * 2)];
    [leftSideView1 setTag:1];
    [leftSideView1 setBackgroundColor:[UIColor accentRed]];
    
    rightSideView1 = [[MaskedView alloc] initWithFrame:CGRectMake(self.view.frame.size.width / 2, self.view.frame.size.height , self.view.frame.size.width / 2, kTriangleHeight)];
    [rightSideView1 setBackgroundColor:[UIColor grayOnboardingColor]];
    [rightSideView1 setTag:2];
    
    [self.view addSubview:leftSideView1];
    [self.view addSubview:rightSideView1];
}

-(void) createMaskedViewsForOnboarding2
{
    leftSideView2 = [[MaskedView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width / 2, kTriangleHeight)];
    [leftSideView2 setTag:3];
    [leftSideView2 setBackgroundColor:[UIColor accentRed]];
    
    rightSideView2 = [[MaskedView alloc] initWithFrame:CGRectMake(self.view.frame.size.width / 2, self.view.frame.size.height , self.view.frame.size.width / 2, kTriangleHeight)];
    [rightSideView2 setBackgroundColor:[UIColor redOnboarding2Color]];
    [rightSideView2 setTag:4];
    
    [self.view addSubview:leftSideView2];
    [self.view addSubview:rightSideView2];
}

-(void) createMaskedViewsForOnboarding3
{
    rightSideView3 = [[MaskedView alloc] initWithFrame:CGRectMake(self.view.frame.size.width + 10, self.view.frame.size.height / 2 - kTriangleHeight * 5, self.view.frame.size.width * 2, kTriangleHeight * 10)];
    [rightSideView3 setTag:5];
    [rightSideView3 setBackgroundColor:[UIColor whiteOnboarding3Color]];
    [self.view addSubview:rightSideView3];
}


-(void) shakeLabels
{
    _labelViewBottomOffset.constant +=10;
    
    [UIView animateWithDuration:1.0 delay:0 usingSpringWithDamping:0.2 initialSpringVelocity:5.0 options:UIViewAnimationOptionCurveLinear animations:^{
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        
    }];
}

-(UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
   return UIInterfaceOrientationPortrait;
}
-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [leftSideView1 removeFromSuperview];
    leftSideView1 = nil;
    [leftSideView2 removeFromSuperview];
    leftSideView2 = nil;
    [rightSideView1 removeFromSuperview];
    rightSideView1 = nil;
    [rightSideView2 removeFromSuperview];
    rightSideView2 = nil;
    [rightSideView3 removeFromSuperview];
    rightSideView3 = nil;

}



/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
