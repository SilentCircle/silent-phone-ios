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

#import "VideoViewController.h"
#import "CallCell.h"
#include "CTVideoInIOS.h"
#import "AppDelegate.h"

const char *tg_translate(const char *key, int iKeyLen);
#define T_TR(_T_KEY) tg_translate(_T_KEY, sizeof(_T_KEY)-1)
#define T_TRL(_T_KEY, _T_KL) tg_translate(_T_KEY, _T_KL)
#define T_TRNS(_T_KEY) [NSString stringWithUTF8String:tg_translate(_T_KEY, sizeof(_T_KEY)-1)]

NSString *toNSFromTB(CTStrBase *b);

char* z_main(int iResp, int argc, const char* argv[]);;
unsigned int  getTickCount();
int isPlaybackVolumeMuted();

@implementation VideoViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
   self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

   self->btMuteLayer = nil;
   
   return self;
}

#define _T_AUTO_ROT_DEV
#ifndef _T_AUTO_ROT_DEV
-(void)deviceRotated:(NSNotification *)note{
   UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
   CGFloat rotationAngle = 0;
   if (orientation == UIDeviceOrientationPortraitUpsideDown) rotationAngle = M_PI;
   else if (orientation == UIDeviceOrientationLandscapeLeft) rotationAngle = M_PI_2;
   else if (orientation == UIDeviceOrientationLandscapeRight) rotationAngle = -M_PI_2;
  // int iResize = UIInterfaceOrientationIsLandscape(self.interfaceOrientation)!=UIInterfaceOrientationIsLandscape(orientation);
   
   CGSize r = [[UIScreen mainScreen]applicationFrame].size;
   int iLand=!!UIInterfaceOrientationIsLandscape(orientation);

   UIView *v=(UIView*)[self.view viewWithTag:500];
   //v.frame=iLand?CGRectMake(0,0,r.height,r.width):r;
 //  printf("[r.x=%f r.y=%f]",r.size.width, r.size.height);
   
   [UIView animateWithDuration:0.5 animations:^{
      v.transform = CGAffineTransformMakeRotation(rotationAngle);
      v.frame=iLand?CGRectMake(0,0,r.width,r.width):CGRectMake(0,0,r.width,r.height);
   } completion:^(BOOL finished) {
      
      
   }];
   
   [cvc setOrientation:orientation];
   [self alignObjects:[self getNearest:cvc.frame.origin.x y:cvc.frame.origin.y] lb:nil];
}
#endif
- (void)viewDidLoad
{
   iWillShowCalled=0;
   iShowing = 0;
   iHiding = 0;
   iSwitchingCameras=0;
#ifndef _T_AUTO_ROT_DEV
   [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceRotated:) name:UIDeviceOrientationDidChangeNotification object:nil];
#endif
   app=(AppDelegate*)[[UIApplication sharedApplication] delegate];
   [super viewDidLoad];
   iActionSheetIsVisible=0;
   cvc->iCanAutoStart=0;

   
   iWasSendingVideoBeforeEnteringBackgr=-1;
   [btAccept setHidden:YES];
   iAnimating=0;
   iUserTouched=0;
   
   toolBarView.backgroundColor=[[UIColor blackColor] colorWithAlphaComponent:.4];
   
   
   CALayer *l;
   
   [lbVolumeWarning setHidden:YES];
   l=lbVolumeWarning.layer;
   l.borderColor = [UIColor whiteColor].CGColor;
   l.cornerRadius = 5;
   l.borderWidth=1;
   
   [self resetMovableObjectCenters];
   
   [self hideInfoNonAnim];
   
   [self setTranslations];
}

-(void) setTranslations{
   [lbVolumeWarning setText:T_TRNS("Volume is too low")];
  // UILabel *l=(UILabel*)[self.view viewWithTag:20010];
  // [l setText:T_TRNS("SECURE")];
   [btBack setTitle:T_TRNS("Audio only") forState:UIControlStateNormal];
   [btAccept setTitle:T_TRNS("Accept") forState:UIControlStateNormal];
   
}

- (void)viewDidUnload
{
   [super viewDidUnload];
   cvc->iCanAutoStart=0;
   [cvc teardownAVCapture];
   [cvc release];
   [btSendStop release];
   [btSwitch release];
}
//- (BOOL)prefersStatusBarHidden TODOtest

- (UIStatusBarStyle)preferredStatusBarStyle
{
   return UIStatusBarStyleLightContent;
}


-(void)onGotoBackground{
   
   iWasSendingVideoBeforeEnteringBackgr=cvc && [cvc capturing];
   if(iWasSendingVideoBeforeEnteringBackgr) [self sendStopPress:nil];
   
}
-(void)onGotoForeground{
   if(iWasSendingVideoBeforeEnteringBackgr>0) [self startVideoPress:nil];
   iWasSendingVideoBeforeEnteringBackgr=-1;
}

#ifdef _T_AUTO_ROT_DEV

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
   [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
   
   float rotation = [SquareCamViewController getRotation:(int)toInterfaceOrientation];
   
   int iResize = UIInterfaceOrientationIsLandscape(self.interfaceOrientation)!=UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
   
   [UIView animateWithDuration:duration animations:^{
      cvc.transform = CGAffineTransformMakeRotation(rotation);
      if(iResize){
         cvc.frame.size = CGSizeMake(cvc.frame.size.height, cvc.frame.size.width);
      }
      [self alignObjects:[self getNearest:cvc.frame.origin.x y:cvc.frame.origin.y] lb:nil];
     // [self alignObjects:[self getNearest:0 y:0] lb:nil];
   }];
}
#endif

-(void)resetMovableObjectCenters{

   float w = self.view.frame.size.width;
   float h = self.view.frame.size.height;

   toolBarCenter = CGPointMake(w/2, h-toolBarView.frame.size.height/2);
   toolBarCenterOffScreen.x = toolBarCenter.x;
   toolBarCenterOffScreen.y = toolBarCenter.y+toolBarView.frame.size.height;
   
   UIView *info=(UIView*)[self.view viewWithTag:2000];
   infoBarCenter = CGPointMake(w/2, info.frame.size.height/2);
   infoBarCenterOffScreen.x = infoBarCenter.x;
   infoBarCenterOffScreen.y = -info.frame.size.height/2 - 1;
   
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{

   if(cvc ){
      [cvc setOrientation:(int)self.interfaceOrientation];
      [self alignObjects:[self getNearest:cvc.frame.origin.x y:cvc.frame.origin.y] lb:nil];
      //[self alignObjects:[self getNearest:0 y:0] lb:nil];
   }
   
   [self resetMovableObjectCenters];

   
//   [UIView setAnimationsEnabled:YES];
}
- (NSUInteger)supportedInterfaceOrientations{

   return UIInterfaceOrientationMaskAll;//UIInterfaceOrientationMaskLandscape;// UIInterfaceOrientationMaskAll;
}
- (BOOL)shouldAutorotate{

   return YES;
}

//depricated
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
   return TRUE;//(interfaceOrientation == UIInterfaceOrientationPortrait);
}

-(void)setupVO{
   QuartzImageView *vo=(QuartzImageView*)[self.view viewWithTag:500];
   
   void g_setQWview(void *p);
   g_setQWview(vo);
   if(vo){
      vo->iCanDrawOnScreen=1;
      vo->_touchDetector=self;
   }
   UIView *v=(UIView*)[self.view viewWithTag:2000];
   if(v)v.layer.zPosition=1000000;
   
}


-(void)setCall:(CTCall*)c canAutoStart:(int)canAutoStart iVideoScrIsVisible:(int*)iVideoScrIsVisible  a:(AppDelegate*)a{
   app=a;
   *iVideoScrIsVisible=1;
   pIsVisible=iVideoScrIsVisible;
   call=c;
   if(cvc)cvc->iCanAutoStart=canAutoStart;
   iCanStartVideo=canAutoStart;
   iIsIncomingVideoCall=canAutoStart;
   
   int findIntByServKey(void *pEng, const char *key, int *ret);
   
   iHideBackToAudioButton=0;
   
   iSimplifyUI=-1;
   findIntByServKey(c->pEng,"iDontSimplifyVideoUI",&iSimplifyUI);if(iSimplifyUI!=-1)iSimplifyUI=!iSimplifyUI;
   
   int iCanAttachDetachVideo=-1;
   //  if(!iSimplifyUI){
   if(0>=findIntByServKey(c->pEng,"iCanAttachDetachVideo",&iCanAttachDetachVideo)){
      
      if(!iCanAttachDetachVideo)iHideBackToAudioButton=1;
   }
   if(iSimplifyUI)iHideBackToAudioButton=1;
   
}

-(void)checkButtons{
   
   int c=cvc && [cvc capturing];

   if(c){
      [btSendStop setTitle:T_TRNS("Pause Video") forState:UIControlStateNormal ];
      [btSendStop setTitle:T_TRNS("Pause Video") forState:UIControlStateHighlighted ];
   }
   else {
      [btSendStop setTitle:T_TRNS("Send Video") forState:UIControlStateNormal];
      [btSendStop setTitle:T_TRNS("Send Video") forState:UIControlStateHighlighted ];
   }
   [self checkThumbnailText];
   [btSendStop setEnabled:YES];
   
   [btSwitch setHidden:!c];
   
   [btDeclineEnd setHidden:NO];
   
   float w=self.view.frame.size.width;
   float btw = btDeclineEnd.frame.size.width;

   if(iAnsweredVideo){
      
      [btDeclineEnd setImage:[UIImage imageNamed:@"ico_end_call.png"] forState:UIControlStateNormal];
     // [btDeclineEnd setTitle:T_TRNS("End Call") forState:UIControlStateNormal];
      [btDeclineEnd setTitle:nil forState:UIControlStateNormal];
      [btDeclineEnd setFrame:btAccept.frame];
      
      [btAccept setHidden:YES];
    //  [btDeclineEnd setTintColor:[UIColor blackColor]];
   }
   else{
      [btDeclineEnd setImage:nil forState:UIControlStateNormal];
      
      [btDeclineEnd setFrame:CGRectMake(w-btw*2-14,btDeclineEnd.frame.origin.y,btw, btDeclineEnd.frame.size.height)];
      
      [btAccept setHidden:NO];
      [btDeclineEnd setTitle:T_TRNS("Decline") forState:UIControlStateNormal];

      //[btDeclineEnd setTintColor:[UIColor redColor]];
   }
   
   btDeclineEnd.alpha=1;
   btAccept.alpha=1;
   
   [self checkMute];

   
   //mute decline answer
   //mute rotate end_call
   
   if(iSimplifyUI)[btSendStop setHidden:YES];
   if(iSimplifyUI|| iHideBackToAudioButton)[btBack setHidden:YES];
   // btSwitch
}


-(IBAction)endCallPress{
   
   if(iAnsweredVideo){
      [app endCallBt];
   }
   [self backPress:nil];
}

-(IBAction)sendStopPress:(id)bt{
   int c=cvc && [cvc capturing];
   
   void g_setQWview_vi(void *p);
   g_setQWview_vi(cvc);
   
   if(c){
      [self stopVideoPress:bt];
   }
   else{
      [self startVideoPress:bt];
   }
}
-(IBAction)switchMute:(id)bt{
   [app switchMute:bt];
   [self checkMute];
}

-(void)checkMute{
  // [btMute setTintColor:app->iOnMute?[UIColor blueColor]:[UIColor blackColor]];
   
   [muteIco setHidden:!app->iOnMute ];
   [btMute setHidden:NO];
   btMute.backgroundColor = app->iOnMute ? [UIColor clearColor] : [UIColor clearColor];
   
   if(app->iOnMute){
      
      if(!btMuteLayer){
         CGRect rr = [btMute.layer bounds];
         btMuteLayer =  [[CALayer alloc] init];//#SP-815, #SP-821
         //[CALayer layer];
         btMuteLayer.borderWidth = rr.size.width/2;
        // btMuteLayer.backgroundColor  = [UIColor blueColor].CGColor;
         btMuteLayer.borderColor = [UIColor blueColor].CGColor;
       //  btMuteLayer.contents = [UIImage imageNamed:@"ico_mute_small.png"].CIImage;
         [btMuteLayer setFrame:rr];
         btMuteLayer.cornerRadius = rr.size.width/4;
         btMuteLayer.masksToBounds = YES;
         btMuteLayer.zPosition = -99;
         
         [btMute.layer addSublayer:btMuteLayer];
      }
   }
   else{
      if(btMuteLayer){
         [btMuteLayer removeFromSuperlayer];
         [btMuteLayer release];//#SP-815, #SP-821, must not be used with the "[CALayer layer];"
         btMuteLayer=nil;
      }
      
   }
   
}

-(IBAction)startVideoPress:(id)bt{
   
   static int iStarting=0;
   iAnsweredVideo=1;
   iActiveVideo=1;
   if(iStarting)return;
   iStarting=1;
   cvc->cVI->stop(NULL);
   cvc->cVI->start(NULL);
   [cvc setupAVCapture];
   
   [self checkButtons];
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      
      char buf[64];
      sprintf(&buf[0],"*C%u",call->iCallId);
      const char *x[2]={"",&buf[0]};
      z_main(0,2,x);
   });
   
   iStarting=0;
}
-(void)alignObjects:(CGPoint)p lb:(UILabel*)lb{
   if(!lb)lb=(UILabel*)[self.view viewWithTag:20010];
   cvc.center=p;
   muteIco.center=p;
   CGFloat h = cvc.frame.size.height/2-10;
   if(lb)lb.center=CGPointMake(p.x,p.y-h);
   
}

-(CGPoint)getNearest:(int)x y:(int)y{
   CGPoint nearest;
   float ofs=cvc.frame.size.width/8;
   
   UIView *info=(UIView*)[self.view viewWithTag:2000];
   
   float ih = info.frame.size.height;
   
   float topOfs = iShowing ? ih :((iHiding || info.hidden)? 0: ih);
   
   nearest.x=cvc.frame.size.width/2 + ofs;
   nearest.y=cvc.frame.size.height/2 + ofs + topOfs;
   
   // self.t
   float th = toolBarView.frame.size.height;
   
   float bbh=iShowing ? th : (iHiding  || info.hidden? 0 :  th);
   
   float w=self.view.frame.size.width;
   float h=self.view.frame.size.height-bbh;
   
   if(x>w/2) nearest.x=w-cvc.frame.size.width/2-ofs;
   if(y>h/2) nearest.y=h-cvc.frame.size.height/2-ofs;

   if(nearest.y<20+cvc.frame.size.height/2)nearest.y+=20;//status bar height
   return nearest;
}

- (void)onTouch:(UIView *)v updown:(int)updown x:(int)x y:(int)y{
   //NSLog(@"x=%d y=%d",x,y);
   iUserTouched=1;
   
   [self volumeCheck:nil];
   
   CGPoint p=CGPointMake((float)x,(float)y);
   
   UILabel *l=(UILabel*)[self.view viewWithTag:20010];
   
   if((updown!=1 && CGRectContainsPoint(cvc.frame,p)) || (iMoving && updown==0)){
      
      [self alignObjects:p lb:l];
      iMoving=1;
      return;
   }
   if(updown==1 && iMoving){
      iMoving=0;
      
      CGPoint nearest = [self getNearest:x y:y];
      
      [UIView animateWithDuration:.5
                            delay:0.0
                          options:UIViewAnimationCurveEaseInOut
                       animations:^ {
                          
                          [self alignObjects:nearest lb:l];
                       }
                       completion:nil];
   }
   
   
   if(updown==-1)[self showInfoView];
}
/*
 - (void)verticalFlip{
 [UIView animateWithDuration:someDuration delay:someDelay animations:^{
 yourView.transform = CATransform3DMakeRotation(M_PI_2,1.0,0.0,0.0); //flip halfway
 } completion:^{
 while ([yourView.subviews count] > 0)
 [[yourView.subviews lastObject] removeFromSuperview]; // remove all subviews
 // Add your new views here
 [UIView animateWithDuration:someDuration delay:someDelay animations:^{
 yourView.transform = CATransform3DMakeRotation(M_PI,1.0,0.0,0.0); //finish the flip
 } completion:^{
 // Flip completion code here
 }];
 }];
 }
 */

-(IBAction)switchCameraAnim:(id)sender{
   
   if(iSwitchingCameras)return;
   iSwitchingCameras=1;
   
   [cvc stopR];
   [cvc switchCamerasStep:1];
   [UIView transitionWithView:cvc
                     duration:.5
                      options:UIViewAnimationOptionTransitionFlipFromLeft
                   animations:^{
                      [UIView setAnimationDelay:.2];
                      [cvc switchCamerasStep:2];
                      [cvc startR];
                   }
                   completion:^(BOOL finished){
                      iSwitchingCameras=0;
                      
                   }];
   
   
}

-(void)checkThumbnailText{
   UILabel *l=(UILabel*)[self.view viewWithTag:20010];
   if(l){
      int c=cvc && [cvc capturing];
      if(c && strncmp(&call->bufSecureMsgV[0],"SECURE",6)==0){
         int  isSilentCircleSecure(int cid, void *pEng);
         int iSecureInGreen=isSilentCircleSecure(call->iCallId, call->pEng);
         [l setTextColor:iSecureInGreen?[UIColor greenColor]:[UIColor whiteColor]];
         [l setHidden:NO];
      }
      else{
         [l setHidden:YES];
      }
      
   }
}

-(void)showInfoView{
   
   if(!iWillShowCalled)return;
   
   UIView *info=(UIView*)[self.view viewWithTag:2000];
   if(info){
      if(iUserTouched){
         if(!iSimplifyUI && !iHideBackToAudioButton)[btBack setHidden:NO];
         if(!iSimplifyUI)[btSendStop setHidden:NO];
         
      }
      UILabel *l=(UILabel*)[self.view viewWithTag:2001];
      if(l){
         UILabel *l2=(UILabel*)[self.view viewWithTag:20001];
         call->setSecurityLines(l, l2, 1);
      }
      l=(UILabel*)[self.view viewWithTag:2002];
      if(l){
         [l setText:toNSFromTB(&call->zrtpPEER)];
      }
      [self checkThumbnailText];
      
      [muteIco setHidden:!app->iOnMute];
      
      if(info.isHidden){
         
         if(iAnimating)return;
         iAnimating=1;
         info.alpha=0;
         toolBarView.hidden = NO;
         info.hidden=NO;

         if(toolBarCenterOffScreen.x>0)
            toolBarView.center = toolBarCenterOffScreen;
         if(infoBarCenterOffScreen.x>0)
            info.center = infoBarCenterOffScreen;
         iShowing=1;
         
         
         [UIView animateWithDuration:.5
                               delay:0.0
                             options:UIViewAnimationCurveEaseInOut
                          animations:^ {
                             info.alpha=0.6;
                             toolBarView.center = toolBarCenter;
                             info.center = infoBarCenter;
                             [self alignObjects:[self getNearest:cvc.frame.origin.x y:cvc.frame.origin.y] lb:nil];
                          }
                          completion:^(BOOL finished) {
                             iShowing=0;
                             [self alignObjects:[self getNearest:cvc.frame.origin.x y:cvc.frame.origin.y] lb:nil];
                             [info setHidden:NO];
                             toolBarView.center = toolBarCenter;
                             info.center = infoBarCenter;
                             
                             info.alpha=.6;
                             iAnimating=0;
                             uiCanHideInfoAt=getTickCount()+2000;
                             [self performSelector:@selector(hideInfoView:) withObject:info afterDelay:3];
                          }];
      }
      else{
         uiCanHideInfoAt=getTickCount()+2000;
         [self performSelector:@selector(hideInfoView:) withObject:info afterDelay:3];
      }
   }
}

-(void)hideInfoNonAnim{
   iHiding=0;
   UIView *info=(UIView*)[self.view viewWithTag:2000];
   if(!info)return;
   // [toolBarView setHidden:YES];
   if(toolBarCenterOffScreen.x)
      toolBarView.center = toolBarCenterOffScreen;
   if(infoBarCenterOffScreen.x)
      info.center = infoBarCenterOffScreen;
   [info setHidden:YES];
   info.alpha=.6;
   iAnimating=0;
   [self alignObjects:[self getNearest:cvc.frame.origin.x y:cvc.frame.origin.y] lb:nil];
}
-(void)hideInfoView:(UIView *)v{
   if(uiCanHideInfoAt>getTickCount() || !iAnsweredVideo){
      [self performSelector:@selector(hideInfoView:) withObject:v afterDelay:1];
      return;
   }
   if(iAnimating)return;
   
   UIView *info=(UIView*)[self.view viewWithTag:2000];
   if(info && !info.isHidden){
      iAnimating=1;
      info.alpha=0.6;
      iHiding = 1;

      [UIView animateWithDuration:.5
                            delay:0.0
                          options:UIViewAnimationCurveEaseInOut
                       animations:^ {
                          info.alpha=0.0;
                          toolBarView.center = toolBarCenterOffScreen;
                          info.center = infoBarCenterOffScreen;
                          [self alignObjects:[self getNearest:cvc.frame.origin.x y:cvc.frame.origin.y] lb:nil];
                       }
                       completion:^(BOOL finished) {
                          iHiding=0;
                         // [toolBarView setHidden:YES];
                          toolBarView.center = toolBarCenterOffScreen;
                          info.center = infoBarCenterOffScreen;
                          [info setHidden:YES];
                          info.alpha=.6;
                          iAnimating=0;
                          [self alignObjects:[self getNearest:cvc.frame.origin.x y:cvc.frame.origin.y] lb:nil];
                          
                       }];
   }
   
}


-(IBAction)stopVideoPress:(id)bt{
   if(cvc && cvc->cVI)cvc->cVI->stop(NULL);
   if(cvc) cvc->iCanAutoStart=0;
   [self checkButtons];
   if(cvc)[cvc teardownAVCapture];
   
}

- (void)viewWillAppear:(BOOL)animated{
   
   [super viewWillAppear:animated];
   
   [self resetMovableObjectCenters];

   [self setupVO];
   
   void g_setQWview_vi(void *p);
   if(cvc)g_setQWview_vi(cvc);
   
   [UIViewController attemptRotationToDeviceOrientation];
   
  
}

- (void)viewDidAppear:(BOOL)animated{
   
   iWillShowCalled=1;
   [self resetMovableObjectCenters];
   
   QuartzImageView *vo=(QuartzImageView*)[self.view viewWithTag:500];
   [vo screenVisible:1];
   
   [super viewDidAppear:animated];
   
   if(iCanStartVideo){
      iCanStartVideo=0;
      dispatch_async(dispatch_get_main_queue(), ^{
         [self startVideoPress:nil];
      });
   }
   else [self checkButtons];
   
   [self showInfoView];
   
   [[ UIApplication sharedApplication ] setIdleTimerDisabled: YES ];
   
   [self performSelector:@selector(volumeCheck:) withObject:nil afterDelay:3];
   
}
-(void)volumeCheck:(id)v{
   
   if(isPlaybackVolumeMuted()){
      [lbVolumeWarning setHidden:NO];
      [self performSelector:@selector(volumeCheckLoop:) withObject:nil afterDelay:1];
   }
   else{
      [lbVolumeWarning setHidden:YES];
   }
}

-(void)volumeCheckLoop:(id)v{
   
   if(!isPlaybackVolumeMuted()){
      [lbVolumeWarning setHidden:YES];
   }
   else{
      [self performSelector:@selector(volumeCheckLoop:) withObject:nil afterDelay:1];
   }
}

-(void)onHideVideoView{
   
   if(*pIsVisible==1)*pIsVisible=2;
   [self stopVideoPress:nil];
   
   QuartzImageView *vo=(QuartzImageView*)[self.view viewWithTag:500];
   if(vo){
      vo->iCanDrawOnScreen=0;
   }
   if(cvc)cvc->iCanAutoStart=0;
   
   
   [[ UIApplication sharedApplication ] setIdleTimerDisabled: NO];
#ifndef _T_AUTO_ROT_DEV
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
#endif
}

- (void)viewWillDisappear:(BOOL)animated{
   
   QuartzImageView *vo=(QuartzImageView*)[self.view viewWithTag:500];
   [vo screenVisible:0];
   
   [self onHideVideoView];
   [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated{
   [super viewDidDisappear:animated];
   *pIsVisible=0;
}

-(IBAction)backPress:(id)bt{
   *pIsVisible=2;
   [self.navigationController popViewControllerAnimated:YES];
   *pIsVisible=0;
   cvc->iCanAutoStart=0;
   
   
   if(!call->iEnded){
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
         char buf[64];
         sprintf(&buf[0],"*c%u",call->iCallId);//TODO reinvite all calls
         const char *x[2]={"",&buf[0]};
         z_main(0,2,x);
      });
   }
}

- (void)willPresentActionSheet:(UIActionSheet *)actionSheet {
   
   
}

- (void)actionSheetCancel:(UIActionSheet *)actionSheet{
   iActionSheetIsVisible=0;
   newCall=NULL;
}

-(void)answerEndCall:(id)v{
   [app endCallN:call];
   usleep(100*1000);
   [self backPress:nil];
   [app answerCallFromVidScr:newCall];
   [app setCurCallMT: newCall];
   newCall=NULL;
   
}


-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
   if(!newCall || actionSheet.tag !=newCall->iCallId)return;
   
   if(actionSheet.cancelButtonIndex==buttonIndex || !newCall){
      iActionSheetIsVisible=0;
      newCall=NULL;
      
      return;
   }
   
   [self performSelector:@selector(answerEndCall:) withObject:nil afterDelay:.2];

   iActionSheetIsVisible=0;
   
   
}
-(void)showIncomingCallMT{
   
   //http://stackoverflow.com/questions/6130475/adding-images-to-uiactionsheet-buttons-as-in-uidocumentinteractioncontroller

   if(!toolBarView)return;
   
   CTCall *c=app->calls.getCall(app->calls.eStartupCall,0);
   if(!c || (c && c==newCall) || iActionSheetIsVisible)return;

   iActionSheetIsVisible=1;
   
   NSString *p2= [app loadUserData:c];
   
   int isVideoCall(int iCallID);
   const char *vc=isVideoCall(c->iCallId)?T_TR("Incoming video call"):T_TR("Incoming");
   NSString *nsIncom;

   if(c->nameFromAB.getLen()){
      nsIncom=[NSString stringWithFormat:@"%s %@, %@",vc,toNSFromTB(&c->nameFromAB),p2];
   }
   else nsIncom=[NSString stringWithFormat:@"%s %@",vc,p2];
   
   UIActionSheet *as = [[UIActionSheet alloc]initWithTitle:nsIncom delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
   
   as.cancelButtonIndex=[as addButtonWithTitle:T_TRNS("Ignore")];
   
   NSString *ea = [NSString stringWithFormat:@"%s + %s",T_TR("End Call"),T_TR("Answer") ];

   as.destructiveButtonIndex=[as addButtonWithTitle:ea];
   
   newCall=c;
   
   as.tag=c->iCallId;
   
   [as showFromRect:toolBarView.frame inView:cvc animated:YES];
   [as release];
}


@end
