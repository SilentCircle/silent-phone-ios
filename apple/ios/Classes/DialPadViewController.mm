/*
Copyright (C) 2012, Tivi LTD, www.tiviphone.com. All rights reserved.
Copyright (C) 2012-2015, Silent Circle, LLC.  All rights reserved.

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

#import "DialPadViewController.h"
#import "Utilities.h"
@interface DialPadViewController ()

@end

@implementation DialPadViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    [[Utilities utilitiesInstance] setTabBarHidden:NO];
    [[Utilities utilitiesInstance].appDelegateTabBar selectSeperatorWithTag:3];
    
    // FIX last row of dialpad buttons goes under tab bar
    // set yoffset to last row buttons to be right under dialpadView
    // Indexes in dialPadLastRowButtons array
    // 0 - dialpadView
    // 1 - actionbuttonsview
    [self repositionLastRow];
}
-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:YES];
    [self repositionLastRow];
}

-(void) repositionLastRow
{
    UIView *actionButtonView = [Utilities utilitiesInstance].dialPadActionButtonView;
    if(actionButtonView)
    {
        
        // reposition actionbuttons view right above the tabbar
        [actionButtonView setFrame:CGRectMake(0, [Utilities utilitiesInstance].screenHeight-[Utilities utilitiesInstance].appDelegateTabBar.frame.size.height - actionButtonView.frame.size.height, actionButtonView.frame.size.width, actionButtonView.frame.size.height)];
        
        
		// center in window (iOS6)
		// EA: do we need to hardcode these sizes?
         // GO - this would not work anyway
//		const CGFloat kHorizSpace = 18;
//		CGRect bounds = callButton.superview.bounds;
//		[callButton setFrame:CGRectMake((bounds.size.width-callButton.frame.size.width)/2, yOffset, 74, 74)];
//		[addContactButton setFrame:CGRectMake(callButton.frame.origin.x-kHorizSpace-78, yOffset, 78, 78)];
//		[backSpaceButton setFrame:CGRectMake(callButton.frame.origin.x+callButton.frame.size.width+kHorizSpace, yOffset, 78, 78)];
   //     [addContactButton setFrame:CGRectMake(28, yOffset, 78, 78)];
    //    [callButton setFrame:CGRectMake(123, yOffset, 74, 74)];
     //   [backSpaceButton setFrame:CGRectMake(216, yOffset, 78, 78)];
    }
 
}
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
   return UIStatusBarStyleLightContent;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSUInteger)supportedInterfaceOrientations{
   // self.shouldAutorotate=YES;
   return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation{
   return UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
   //return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft);//UIInterfaceOrientationPortrait
   return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (BOOL)shouldAutorotate{
   return YES;
}

@end
