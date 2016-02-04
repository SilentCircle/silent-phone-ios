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

#import "AppDelegate.h"
#import "CallScrViewController.h"
/*
 @interface CallScrViewController ()
 
 @end
 */


@implementation CallScrViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
   self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
   if (self) {
      // Custom initialization
   }
   return self;
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
//TODO move here thread

- (void)didReceiveMemoryWarning
{
   [super didReceiveMemoryWarning];
   // Dispose of any resources that can be recreated.
}

- (NSUInteger)supportedInterfaceOrientations{
   // self.shouldAutorotate=YES;
   return UIInterfaceOrientationMaskPortrait;//|UIInterfaceOrientationMaskPortraitUpsideDown;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation{
   return UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotate{
   return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
   //return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft);//UIInterfaceOrientationPortrait
   return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void) viewDidAppear: (BOOL) animated {
   
   [super viewDidAppear: animated];
   [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
   [self becomeFirstResponder];
}

- (BOOL) canBecomeFirstResponder {
   
   return YES;
}

- (void) viewWillDisappear: (BOOL) animated {
   
   [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
   [self resignFirstResponder];
   
   [super viewWillDisappear: animated];
}

- (void) remoteControlReceivedWithEvent: (UIEvent *) receivedEvent {
   
   NSLog(@"ev t=%ld st=%ld",(long)receivedEvent.type,(long)receivedEvent.subtype);
   
   if (receivedEvent.type == UIEventTypeRemoteControl) {
      
      switch (receivedEvent.subtype) {
            
         case UIEventSubtypeRemoteControlTogglePlayPause:
         {
            AppDelegate *app=(AppDelegate*)[[UIApplication sharedApplication] delegate];
            [app remoteEventClick];
            break;
         }
         default:
            break;
      }
   }
}


@end
