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
//  SCVideoVC.m
//  SPi3
//
//  Created by Eric Turner on 11/6/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import "SCVideoVC.h"
#import "SCPTranslateDefs.h"
#import "SCPCall.h"
#import "SquareCamVC.h"
#import "QuartzVO.h"

#import "CTVideoInIOS.h"
#import "CTBase.h"

#import "SCPCallManager.h"
#import "SCSCallNavDelegate.h"
#import "SCSAudioManager.h"

#import "SCPNotificationKeys.h"
#import "ChatUtilities.h"

#import "SCPCallbackInterface.h"

void g_setQWview_vi(void *p);

@interface SCVideoVC()<UITouchDetector,UIActionSheetDelegate>
@end

@implementation SCVideoVC
{
    IBOutlet UIView  *toolBarView;
    IBOutlet UIView  *_incomingCallActionView;
    IBOutlet UILabel *_lbIncomingCallTitle;
    
    IBOutlet UIButton *btAccept;
    IBOutlet UIButton *btDeclineEnd;
    IBOutlet UIButton *btMute;
    IBOutlet UIButton *btSwitch;
    IBOutlet UIButton *btSendStop;
    IBOutlet UIButton *btBackToAudio;
    IBOutlet UILabel *lbVolumeWarning;
    
    IBOutlet UIImageView *muteIco;
    
    IBOutlet SquareCamVC *sqCam;
    CALayer *btMuteLayer;
    
    SCPCall *_newCall;
    
    CGPoint toolBarCenter,toolBarCenterOffScreen;
    CGPoint infoBarCenter,infoBarCenterOffScreen;
    
    int iActionSheetIsVisible;
    
    int iCanStartVideo;
    int isIncomingVideoCall;
    int iAnsweredVideo;
    int iActiveVideo;
    
    int iUserTouched;
    
    unsigned int uiCanHideInfoAt;
    
    int iWasSendingVideoBeforeEnteringBackgr;
    
    int iAnimating;
    int iShowing;
    int iHiding;
    
    int iWillShowCalled;
    
    int iMoving;
    
    int iHideBackToAudioButton;
    int iSimplifyUI;
    int iSwitchingCameras;
    
    BOOL isVideoStarting;
}

NSString *toNSFromTB(CTStrBase *b);

char* z_main(int iResp, int argc, const char* argv[]);;
unsigned int  getTickCount();

#pragma mark - Initialization

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    self->btMuteLayer = nil;
    
    return self;
}

- (void)awakeFromNib {
    
    [super awakeFromNib];
    
    self->btMuteLayer = nil;
}

- (void)dealloc {
    NSLog(@"%s\n  %@ being dealloc-ed",__PRETTY_FUNCTION__, self);
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [btAccept release];
    [btBackToAudio release];    
    [btDeclineEnd release];
    [btMute release];
    [btMuteLayer release];
    [btSendStop release]; 
    [btSwitch release];
    [_incomingCallActionView release];
    [_lbIncomingCallTitle release];
    [lbVolumeWarning release];
    [muteIco release];
    [_newCall release];    
    g_setQWview_vi(NULL);
    [sqCam release];    
    [toolBarView release];

    [super dealloc];
}


#pragma mark - Lifecycle 

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    iWillShowCalled=0;
    iShowing = 0;
    iHiding = 0;
    iSwitchingCameras=0;
    iActionSheetIsVisible=0;
    iWasSendingVideoBeforeEnteringBackgr=-1;
    iAnimating=0;
    iUserTouched=0;
    
    [sqCam setAutostartFlag:NO];
    
    [btAccept setHidden:YES];
    
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

- (void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:animated];
    
    iAnsweredVideo = 0;

    BOOL canAutoStart = _call.userDidPressVideoButton;
    
    [sqCam setAutostartFlag:canAutoStart];
    
    iCanStartVideo = canAutoStart;
    isIncomingVideoCall = canAutoStart;
    iHideBackToAudioButton = 0;
    iSimplifyUI = 0;

    [self resetMovableObjectCenters];
    
    [self setupVO];
    
    if(sqCam)
        g_setQWview_vi(sqCam);
    
    [UIViewController attemptRotationToDeviceOrientation];
}

- (void)viewDidAppear:(BOOL)animated{
    
    iWillShowCalled=1;
    [self resetMovableObjectCenters];
    
    QuartzImageView *vo=(QuartzImageView*)[self.view viewWithTag:500];
    [vo screenVisible:1];
    
    [super viewDidAppear:animated];
    
    if(iCanStartVideo) {
        
        iCanStartVideo=0;
        
        [self startVideoPress:nil];
    }
    else
        [self checkButtons];
    
    [self showInfoView];
    
    [[UIApplication sharedApplication] setIdleTimerDisabled: YES ];
    [Switchboard setIsShowingVideoScreen:YES];
    
    [self volumeCheck];
    
    // moved from viewWillAppear at Janis suggestion
    [self registerForNotifications];
}

- (void)viewWillDisappear:(BOOL)animated{

    [super viewWillDisappear:animated];

    [self unregisterForNotifications];
    
    [self stopVideoPress:nil];
    
    QuartzImageView *vo=(QuartzImageView*)[self.view viewWithTag:500];

    if(vo){
        
        [vo screenVisible:0];
        vo->iCanDrawOnScreen=0;
    }
    
    [sqCam setAutostartFlag:NO];
    
    [[UIApplication sharedApplication] setIdleTimerDisabled: NO];
    
    [Switchboard setIsShowingVideoScreen:NO];
}


#pragma mark - SCSCallHandler Methods

- (void)prepareToBecomeActive {
    
    [super prepareToBecomeActive];
}

- (void)prepareToBecomeInactive {

    [super prepareToBecomeInactive];
    
    [sqCam teardownAVCapture];
}

#pragma mark - Setup

-(void) setTranslations{
    
    [lbVolumeWarning setText:NSLocalizedString(@"Volume is too low", nil)];
    [btBackToAudio setTitle:NSLocalizedString(@"Audio only", nil) forState:UIControlStateNormal];
    [btAccept setTitle:NSLocalizedString(@"Accept", nil) forState:UIControlStateNormal];
}

-(void)setupVO {

    QuartzImageView *vo=(QuartzImageView*)[self.view viewWithTag:500];
    
    void g_setQWview(void *p);
    g_setQWview(vo);
    
    if(vo){
        
        vo->iCanDrawOnScreen=1;
        vo->_touchDetector=self;
    }
    
    UIView *v=(UIView*)[self.view viewWithTag:2000];
    
    if(v)
        v.layer.zPosition=1000000;
}


#pragma mark - State Handling

-(void)checkButtons{
    
    int c=sqCam && [sqCam capturing];
    
    if(c){
        [btSendStop setTitle:NSLocalizedString(@"Pause Video", nil) forState:UIControlStateNormal ];
        [btSendStop setTitle:NSLocalizedString(@"Pause Video", nil) forState:UIControlStateHighlighted ];
    }
    else {
        [btSendStop setTitle:NSLocalizedString(@"Send Video", nil) forState:UIControlStateNormal];
        [btSendStop setTitle:NSLocalizedString(@"Send Video", nil) forState:UIControlStateHighlighted ];
    }
    [self checkThumbnailText];
    [btSendStop setEnabled:YES];
    
    [btSwitch setHidden:!c];
    
    [btDeclineEnd setHidden:NO];
    
    float w=self.view.frame.size.width;
    float btw = btDeclineEnd.frame.size.width;
    
    if(iAnsweredVideo){
        
        // Show the 'Hang up' red button for outgoing calls
        [btDeclineEnd setImage:[UIImage imageNamed:@"ico_end_call.png"] forState:UIControlStateNormal];
        [btDeclineEnd setTitle:nil forState:UIControlStateNormal];
        [btDeclineEnd setFrame:btAccept.frame];
        [btAccept setHidden:YES];
    }
    else{
        // Show 'Accept' and 'Decline' buttons for incoming video calls
        [btDeclineEnd setImage:nil forState:UIControlStateNormal];
        
        [btDeclineEnd setFrame:CGRectMake(w-btw*2-14,btDeclineEnd.frame.origin.y,
                                          btw, btDeclineEnd.frame.size.height)];
        
        [btAccept setHidden:NO];

        //we can not use "Decline" because it is already in use for Decline a call
        //it would translate it to "Call Declined"
        [btDeclineEnd setTitle:NSLocalizedString(@"Ignore", nil) forState:UIControlStateNormal];
    }
    
    btDeclineEnd.alpha=1;
    btAccept.alpha=1;
    
    [self checkMute];
    
    //mute decline answer
    //mute rotate end_call
    
    if(iSimplifyUI)
        [btSendStop setHidden:YES];
    
    if(iSimplifyUI || iHideBackToAudioButton)
        [btBackToAudio setHidden:YES];
}

#pragma mark - Button Handlers

-(IBAction)endCallPress{
    
    if(iAnsweredVideo)
        [SPCallManager terminateCall:_call];
    else
        [self backToAudio:nil];
}

-(IBAction)sendStopPress:(id)bt{
    int c=sqCam && [sqCam capturing];
    
    void g_setQWview_vi(void *p);
    g_setQWview_vi(sqCam);
    
    if(c){
        [self stopVideoPress:bt];
    }
    else{
        [self startVideoPress:bt];
    }
}

-(IBAction)switchMute:(id)bt{
    
    [SPCallManager onMuteCall:_call
                        muted:![SPAudioManager micIsMuted]];
}

-(void)checkMute{
   
    BOOL muted = [SPAudioManager micIsMuted];
    [muteIco setHidden:!muted ];
    [btMute setHidden:NO];
    btMute.backgroundColor = muted? [UIColor clearColor] : [UIColor clearColor];
    
    if(muted){
        
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
    
    if(isVideoStarting)
        return;
    
    isVideoStarting = YES;

    iAnsweredVideo=1;
    iActiveVideo=1;
    
    [sqCam setupAVCapture];
    
    [self checkButtons];
    
    [SPAudioManager routeAudioToLoudspeaker:YES
      shouldCheckHeadphonesOrBluetoothFirst:YES];

    [SPCallManager switchToVideo:_call
                              on:YES];
    
    isVideoStarting = NO;
}

-(IBAction)stopVideoPress:(id)bt{
    
    [sqCam setAutostartFlag:NO];
    
    if(sqCam)
        [sqCam teardownAVCapture];
    
    [self checkButtons];
}

-(IBAction)switchCameraAnim:(id)sender{
    
    if(iSwitchingCameras)return;
    iSwitchingCameras=1;
    
    [sqCam stopR];
    [sqCam switchCamerasStep:1];
    [UIView transitionWithView:sqCam
                      duration:.5
                       options:UIViewAnimationOptionTransitionFlipFromLeft
                    animations:^{
                        [UIView setAnimationDelay:.2];
                        [sqCam switchCamerasStep:2];
                        [sqCam startR];
                    }
                    completion:^(BOOL finished){
                        iSwitchingCameras=0;
                        
                    }];
    
    
}

-(IBAction)backToAudio:(id)bt{
    
    [sqCam setAutostartFlag:NO];
    _call.userDidPressVideoButton = NO;
    _call.shouldShowVideoScreen = NO;
    
    if(!_call.isEnded)
        [SPCallManager switchToVideo:_call on:NO];
    
    if ([SPCallManager activeConferenceCallCount] > 1) {
        [_navDelegate switchToConference:nil call:nil];
    } else {
        [_navDelegate switchToCallScreen:nil call:_call];
    }
}


#pragma mark - Incoming Call Handlers

// Called by RootVC with incoming call
- (void)handleIncomingCall:(NSNotification *)notif {
    
    if ([notif.name isEqualToString:kSCPIncomingCallNotification]) {
        SCPCall *inCall = notif.userInfo[kSCPCallDictionaryKey];
        if (inCall) {
            _newCall = inCall;
            [self presentActionSheet];
        }
    }
}

- (void)presentActionSheet {

    if (_newCall == _call || !_newCall || iActionSheetIsVisible) { return; }
    
    iActionSheetIsVisible=1;
    
    NSString *displayName = @"";
    
    if(_newCall.bufPeer)
        displayName = [[ChatUtilities utilitiesInstance] removePeerInfo:_newCall.bufPeer lowerCase:YES];
    
    NSString *nsIncom = nil;
    if(_newCall.nameFromAB.length > 1){
        if(_newCall.hasVideo){
            nsIncom=[NSString stringWithFormat:NSLocalizedString(@"Incoming video call %@, %@", nil), _newCall.nameFromAB, displayName];
        }else{
            nsIncom=[NSString stringWithFormat:NSLocalizedString(@"Incoming %@, %@", nil), _newCall.nameFromAB, displayName];
        }
    } else {
        if(_newCall.hasVideo){
            nsIncom=[NSString stringWithFormat:NSLocalizedString(@"Incoming video call %@", nil), displayName];
        }else{
            nsIncom=[NSString stringWithFormat:NSLocalizedString(@"Incoming %@", nil), displayName];
        }
    }

    UIAlertController *ac = [UIAlertController alertControllerWithTitle:nsIncom
                                                                message:nil
                                                         preferredStyle:UIAlertControllerStyleActionSheet];
    [ac retain];
    
    [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Ignore", nil)
                                           style:UIAlertActionStyleCancel
                                         handler:^(UIAlertAction *action){
                                             
                                             iActionSheetIsVisible=0;
                                             [ac release];
                                         }]];
    
    NSString *ea = NSLocalizedString(@"End Call + Answer", nil);
    [ac addAction:[UIAlertAction actionWithTitle:ea
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action){
                                             
                                             if (_newCall) {
                                                 [self performSelector:@selector(endCurrentCallAndAnswer)
                                                            withObject:nil afterDelay:.2];
                                             }
                                             
                                             iActionSheetIsVisible=0;
                                             [ac release];
                                         }]];
    
    [self presentViewController:ac animated:YES completion:nil];
}

-(IBAction)endCurrentCallAndAnswer {
    NSLog(@"%s called", __PRETTY_FUNCTION__);
    
    if (!_newCall) { return; }
    
    // Swap _call with inCall here, before terminating current call
    SCPCall *currentCall = _call;
    _call = _newCall;
    
    // When VideoVC (self) is active, the RootVC callDidEnd  will test the self call with the currently selected call
    //
    [SPCallManager terminateCall:currentCall];
    
    if ([_navDelegate respondsToSelector:@selector(switchToCallScreen:call:)]) {
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            if (_call) {
                [SPCallManager answerCall:_call];
                [_navDelegate switchToCallScreen:nil call:_call];
            }
        });
    }
}

- (IBAction)ignoreIncomingCall:(id)sender {
    NSLog(@"%s called", __PRETTY_FUNCTION__);
    iActionSheetIsVisible=0;
}


#pragma mark - SquareCam Methods

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

-(void)alignObjects:(CGPoint)p lb:(UILabel*)lb{
    if(!lb)lb=(UILabel*)[self.view viewWithTag:20010];
    sqCam.center=p;
    muteIco.center=p;
    CGFloat h = sqCam.frame.size.height/2-10;
    if(lb)lb.center=CGPointMake(p.x,p.y-h);
    
}

-(CGPoint)getNearest:(int)x y:(int)y{
    CGPoint nearest;
    float ofs=sqCam.frame.size.width/8;
    
    UIView *info=(UIView*)[self.view viewWithTag:2000];
    
    float ih = info.frame.size.height;
    
    float topOfs = iShowing ? ih :((iHiding || info.hidden)? 0: ih);
    
    nearest.x=sqCam.frame.size.width/2 + ofs;
    nearest.y=sqCam.frame.size.height/2 + ofs + topOfs;
    
    // self.t
    float th = toolBarView.frame.size.height;
    
    float bbh=iShowing ? th : (iHiding  || info.hidden? 0 :  th);
    
    float w=self.view.frame.size.width;
    float h=self.view.frame.size.height-bbh;
    
    if(x>w/2) nearest.x=w-sqCam.frame.size.width/2-ofs;
    if(y>h/2) nearest.y=h-sqCam.frame.size.height/2-ofs;
    
    if(nearest.y<20+sqCam.frame.size.height/2)nearest.y+=20;//status bar height
    return nearest;
}

- (void)onTouch:(UIView *)v updown:(int)updown x:(int)x y:(int)y{
    //NSLog(@"x=%d y=%d",x,y);
    iUserTouched=1;
        
    CGPoint p=CGPointMake((float)x,(float)y);
    
    UILabel *l=(UILabel*)[self.view viewWithTag:20010];
    
    if((updown!=1 && CGRectContainsPoint(sqCam.frame,p)) || (iMoving && updown==0)){
        
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

-(void)checkThumbnailText{
    UILabel *l=(UILabel*)[self.view viewWithTag:20010];
    if(l){
        
        int c=sqCam && [sqCam capturing];
        if(c && [_call.bufSecureMsgV isEqualToString:@"SECURE"]){

            int iSecureInGreen= _call.isSCGreenSecure;
            [l setTextColor:iSecureInGreen?[UIColor greenColor]:[UIColor whiteColor]];
            [l setHidden:NO];
        }
        else{
            [l setHidden:YES];
        }

        
    }
}


#pragma mark - Security

-(void)showInfoView{
    
    if(!iWillShowCalled)return;
    
    UIView *info=(UIView*)[self.view viewWithTag:2000];
    if(info){
        UILabel *l2 = (UILabel*)[self.view viewWithTag:20001];
        l2.text = @"";
        if(iUserTouched){
            if(!iSimplifyUI && !iHideBackToAudioButton)[btBackToAudio setHidden:NO];
            if(!iSimplifyUI)[btSendStop setHidden:NO];
        }

        UILabel *l=(UILabel*)[self.view viewWithTag:2001];
        if(l){
            [_call setSecurityLabel:l desc:l2 withBackgroundView:nil];
        }
        l=(UILabel*)[self.view viewWithTag:2002];
        if(l){
            [l setText:_call.zrtpPEER];
//           if(l2 && _call.bufSAS.length > 0 && [_call.bufSecureMsgV isEqualToString:@"SECURE"] && _call.iShowVerifySas){
            if(l2 && _call.bufSAS.length > 0 && [_call.bufSecureMsgV isEqualToString:@"SECURE"] && !_call.isSASVerified){
              if(_call.bufSAS.length != 4){
                 [l2 setFont:[UIFont systemFontOfSize:16]];
              }else{
                 [l2 setFont:[UIFont fontWithName:@"OCRB" size:17]];
              }
              
              l2.minimumScaleFactor = .6f;
              l2.text = _call.bufSAS;
           }
        }
        [self checkThumbnailText];
        
        [muteIco setHidden:!SPAudioManager.micIsMuted];
       
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
                                 [self alignObjects:[self getNearest:sqCam.frame.origin.x y:sqCam.frame.origin.y] lb:nil];
                             }
                             completion:^(BOOL finished) {
                                 iShowing=0;
                                 [self alignObjects:[self getNearest:sqCam.frame.origin.x y:sqCam.frame.origin.y] lb:nil];
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
    [self alignObjects:[self getNearest:sqCam.frame.origin.x y:sqCam.frame.origin.y] lb:nil];
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
                             [self alignObjects:[self getNearest:sqCam.frame.origin.x y:sqCam.frame.origin.y] lb:nil];
                         }
                         completion:^(BOOL finished) {
                             iHiding=0;
                             // [toolBarView setHidden:YES];
                             toolBarView.center = toolBarCenterOffScreen;
                             info.center = infoBarCenterOffScreen;
                             [info setHidden:YES];
                             info.alpha=.6;
                             iAnimating=0;
                             [self alignObjects:[self getNearest:sqCam.frame.origin.x y:sqCam.frame.origin.y] lb:nil];
                             
                         }];
    }
    
}


#pragma mark - Audio Methods

-(void)volumeCheck {
    
    [lbVolumeWarning setHidden:![SPAudioManager playbackVolumeIsVeryLow]];
    [lbVolumeWarning.superview bringSubviewToFront:lbVolumeWarning];
}

#pragma mark - Notifications

- (void)notificationHandler:(NSNotification *)notif {
    
    SCPCall *aCall = (SCPCall*)notif.userInfo[kSCPCallDictionaryKey];
    
    if(aCall != _call)
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        
        if ([notif.name isEqualToString:kSCPCallStateDidChangeNotification]) {
            
            if (NO == _call.shouldShowVideoScreen) {
                
                _call.userDidPressVideoButton = NO;
                _call.shouldShowVideoScreen = NO;
                
                if ([_navDelegate respondsToSelector:@selector(switchToCallScreen:call:)]) {
                    [_navDelegate switchToCallScreen:nil call:_call];
                }
            }
        }
        else if ([notif.name isEqualToString:kSCPZRTPDidUpdateNotification]) {
            
            [self showInfoView];
        }
        else if([notif.name isEqualToString:kSCPCallAcceptedVideoRequestNotification]) {
            
            [self startVideoPress:nil];
        }
        else if([notif.name isEqualToString:kSCPCallDeclinedVideoRequestNotification]) {
            
            [self backToAudio:nil];
        }
    });
}

- (void)volumeChanged:(NSNotification *)notification {
    
    [self volumeCheck];
}

- (void)muteChanged:(NSNotification *)notification {
    
    [self checkMute];
}

-(void)registerForNotifications {

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notificationHandler:)
                                                 name:kSCPCallAcceptedVideoRequestNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notificationHandler:)
                                                 name:kSCPCallDeclinedVideoRequestNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleIncomingCall:)
                                                 name:kSCPIncomingCallNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notificationHandler:)
                                                 name:kSCPCallStateDidChangeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notificationHandler:)
                                                 name:kSCPZRTPDidUpdateNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(volumeChanged:)
                                                 name:KSCSAudioOutputVolumeDidChange object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(muteChanged:)
                                                 name:kSCSAudioMuteMicDidChange object:nil];
}

- (void)unregisterForNotifications {

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSCPCallAcceptedVideoRequestNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSCPCallDeclinedVideoRequestNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSCPIncomingCallNotification
                                                  object:nil];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSCPCallStateDidChangeNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSCPZRTPDidUpdateNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:KSCSAudioOutputVolumeDidChange
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSCSAudioMuteMicDidChange
                                                  object:nil];
}

#pragma mark - UIViewController Methods

- (UIStatusBarStyle)preferredStatusBarStyle {
    
    return UIStatusBarStyleLightContent;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
    
    return UIInterfaceOrientationMaskAll;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    
    if(sqCam){
        
        [sqCam setOrientation:self.interfaceOrientation];
        [self alignObjects:[self getNearest:sqCam.frame.origin.x y:sqCam.frame.origin.y] lb:nil];
    }
    
    [self resetMovableObjectCenters];
}


- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
 
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    float rotation = [SquareCamVC getRotation:(int)toInterfaceOrientation];
    
    int iResize = UIInterfaceOrientationIsLandscape(self.interfaceOrientation)!=UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
    
    [UIView animateWithDuration:duration animations:^{
        sqCam.transform = CGAffineTransformMakeRotation(rotation);
        if(iResize){
            sqCam.frame.size = CGSizeMake(sqCam.frame.size.height, sqCam.frame.size.width);
        }
        [self alignObjects:[self getNearest:sqCam.frame.origin.x y:sqCam.frame.origin.y] lb:nil];
    }];
}

@end
