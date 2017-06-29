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
//  CallScreenVC.m
//  SP3
//
//  Created by Eric Turner on 5/11/15.
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SCPCall.h"
#import "CallScreenVC.h"
#import "ChatUtilities.h"
#import "RecentObject.h"
#import "SCPCallManager.h"
#import "SCPCallbackInterface.h"
#import "SCPNotificationKeys.h"
#import "SCPTranslateDefs.h"
#import "SCSAudioManager.h"
#import "SCSAutoLayout.h"
#import "SCSCallScreenDialPadVC.h"
#import "SCSPhoneHelper.h"
#import "Silent_Suite-Swift.h"
#import "SPUser.h"
#import "UserService.h"

static const CGFloat kViewAnimationDuration = 0.5;

#pragma mark enable/disable Chat Button
//TMP - disable Chat button until implemented
static BOOL ENABLE_CHAT_BUTTON = NO;

// Geek strip
void *findGlobalCfgKey(const char *key);
void t_save_glob();


@interface CallScreenVC ()

//----------------------------------------------------------------------
// Call Screen / Dial Pad Container Views
//----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UIView *callScreenContainer;
@property (weak, nonatomic) IBOutlet UIView *dialPadContainer;
@property (readonly, nonatomic) SCSCallScreenDialPadVC *dialPadVC;
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// Header View
//----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UIView  *headerView;
@property (weak, nonatomic) IBOutlet UILabel *lbDst;     // +1(555)123-4567
@property (weak, nonatomic) IBOutlet UILabel *lbDstName; //John Carter
// For geekStrip relocation
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *dstNameLeadingConstraint;
@property (assign, nonatomic) CGFloat                      origDstNameLeading;

@property (weak, nonatomic) IBOutlet UIView               *geekStripView;
@property (weak, nonatomic) IBOutlet UILabel              *lbGeekStrip;  // 15 0.1s 0.0% loss G722/GSM
@property (weak, nonatomic) IBOutlet UIButton             *btGeekStrip;  // ico_antena_4.png : onAntenaClick
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *geekStripWidthConstraint;
@property (assign, nonatomic) CGFloat                     origGeekStripWidth;

@property (weak, nonatomic) IBOutlet UIImageView *ivFlag;
@property (weak, nonatomic) IBOutlet UIImageView *ivLed;

@property (weak, nonatomic) IBOutlet UILabel     *lbCallDur;   // 01:59
@property (weak, nonatomic) IBOutlet UIImageView *ivCallDurBg; //bg_time.png behind lbCallDur

@property (weak, nonatomic) IBOutlet UILabel *lbServer; // SilentCircle (fs-devel.silentcircle.org)
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// Contact / Avatar views
//----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet SCSContactView *contactView;
@property (weak, nonatomic) IBOutlet UIImageView    *ivBackgroundAvatar;
@property (weak, nonatomic) IBOutlet UIButton       *btAvatarVerify;  //showSASPopupText //Verify - askZRTP_cache_name
//----------------------------------------------------------------------

@property (weak, nonatomic) IBOutlet UIView *viewCSMiddle;

//----------------------------------------------------------------------
// Call Info panel
//----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UIView  *infoPanelView;
@property (weak, nonatomic) IBOutlet UILabel *lbCallInfo;  // Ringing..., End Call, etc.
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// ZRTP panel
//----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UIView   *zrtpPanelView;
@property (weak, nonatomic) IBOutlet UILabel  *lbZRTP_peer;     // John Doe (pinned to contactView)

@property (weak, nonatomic) IBOutlet UIView   *secureSubView;
@property (weak, nonatomic) IBOutlet UILabel  *lbSecure;        // GOING SECURE
@property (weak, nonatomic) IBOutlet UILabel  *lbSecureSmall;   // above verifySAS
@property (weak, nonatomic) IBOutlet UIButton *btVerified;      // green checkmark (showSASPopupText)

@property (weak, nonatomic) IBOutlet UILabel  *lbSAS;           // new SAS phrase label

@property (weak, nonatomic) IBOutlet UIView   *unSecureSubView;
@property (weak, nonatomic) IBOutlet UILabel  *lbUnSecure;      // Compare SAS with partner msg
@property (weak, nonatomic) IBOutlet UIButton *btUnverified;    // new blue (showSASPopupText)
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// Nav Buttons
//----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UIView   *navButtonsView;
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *navButtonsGroup;
@property (weak, nonatomic) IBOutlet UIButton *btMute;           // audio mute
@property (weak, nonatomic) IBOutlet UIButton *btShowKeyPad;     // display inCall dialpad
@property (weak, nonatomic) IBOutlet UIButton *btMessages;       // transition to messages
@property (weak, nonatomic) IBOutlet UIButton *btSpeaker;        // audio speaker
@property (weak, nonatomic) IBOutlet UIButton *btConversations;  // transition to conversations
@property (weak, nonatomic) IBOutlet UIButton *btVideo;          // transition to video screen
@property (weak, nonatomic) IBOutlet UIButton *btConference;     // transition to conference

@property (weak, nonatomic) IBOutlet UILabel  *lblVolumeWarning; //lbVolumeWarning
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// End/Answer/Keyboard buttons
//----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet UIView *endCallButtonsView;
@property (weak, nonatomic) IBOutlet UIButton *btAnswer;
@property (weak, nonatomic) IBOutlet UIButton *btHideKeypad;
@property (weak, nonatomic) IBOutlet UIButton *btEndCall;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *endBTWidthConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *endBTCenterXconstraint;
@property (assign, nonatomic) CGFloat origEndCallBTCenterX;
@property (assign, nonatomic) CGFloat shortEndCallBTWidth;
@property (assign, nonatomic) CGFloat longEndCallBTWidth;
@property (weak, nonatomic) IBOutlet UIView *bottomSpacer;
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// Timers
//----------------------------------------------------------------------
@property (strong, nonatomic) NSTimer *callDurTimer;
@property (strong, nonatomic) NSTimer *ledTimer;
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// Private Methods
//----------------------------------------------------------------------
- (void)shakeProfileView;
//----------------------------------------------------------------------

@end


#define T_TRNS_TODO_FIX(_V) @_V

//must match end/answer/hide button end margins and center space in IB
static CGFloat const kscsButtonsMargin = 16.0;

@implementation CallScreenVC
{
    BOOL _isShowingIncomingCallButtons;
}

#pragma mark - Initialization

- (void)awakeFromNib {
    [super awakeFromNib];
}

- (void)dealloc {
    NSLog(@"%s called",__PRETTY_FUNCTION__);

//    [self cleanupAccessibility];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [super viewDidLoad];
    
    if (_call) {
        [self fetchPeerAvatarInBackground];
    }
    
//    [self setupAccessibility];
    
    // Avatar may deserialize with initials "WW" set. Clear.
    [_contactView showInitials:NO];
    
    // Clear potential IB placeholder text in labels
    _lbSAS.text      = @"";
    _lbCallDur.text  = @"";
    _lbCallInfo.text = @"";
    
    // Geek strip
    _origGeekStripWidth = _geekStripWidthConstraint.constant;
    _origDstNameLeading = _dstNameLeadingConstraint.constant;
    
    // Store/calculate btEndCall dimensions
    _origEndCallBTCenterX = _endBTCenterXconstraint.constant;
    // compute endCallBT long width
    CGFloat superwidth = _btEndCall.superview.frame.size.width;
    _longEndCallBTWidth = superwidth - (2 * kscsButtonsMargin);

    [self updateButtonsToEndCallStateWithAnimation:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    NSLog(@"%s self:%@", __PRETTY_FUNCTION__, self);
    [super viewWillAppear:animated];
   
    [UIViewController attemptRotationToDeviceOrientation];
    
    [self becomeFirstResponder];
    
    NSLog(@"%s\n ----- BEGIN RECEIVING REMOTE CONTROL EVENTS ----", __PRETTY_FUNCTION__);
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    
    [self updateVolumeWarning];
    [self updateMuteButtonImage];
    [self updateAudioNotification: nil];
    
    [self registerForNotifications];
    [self startTimer];
    [self startLedTimer];
    
    if (_call) {
        [self updateUIWithCall:_call];
    }
}

- (void)viewDidAppear: (BOOL) animated {
//    NSLog(@"%s", __PRETTY_FUNCTION__);
    [super viewDidAppear: animated];
}

// the call to terminate call will result in the rootVC dismissing the callNavVC
- (void)viewWillDisappear: (BOOL) animated {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [super viewWillDisappear: animated];
    
    [self prepareToBecomeInactive];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSCSRecentObjectUpdatedNotification object:nil];
}


#pragma mark - SCSCallHandler Methods

- (void)prepareToBecomeActive{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [super prepareToBecomeActive];
}

- (void)prepareToBecomeInactive{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [super prepareToBecomeInactive];
    
    [self stopTimer];
    [self stopLedTimer];
   
    NSLog(@"%s\n ----- END RECEIVING REMOTE CONTROL EVENTS ----", __PRETTY_FUNCTION__);
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    
    NSLog(@"%s\n ----- DISABLE PROXIMITY MONTIORING ----", __PRETTY_FUNCTION__);
    [UIDevice currentDevice].proximityMonitoringEnabled = NO;
    
    [self resignFirstResponder];
    
    [self unRegisterForNotifications];
}


#pragma mark - Call Setter

- (void)setCall:(SCPCall *)aCall {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    BOOL viewIsLoaded = self.isViewLoaded;
    
    _call.userDidPressVideoButton = NO;//make sure that we do not have old state here
    _call = aCall;
    
    if (_call && viewIsLoaded) {
        [self fetchPeerAvatarInBackground]; // refresh
        if ([self dialPadIsVisible]) {
            [self dismissDialPad];
        }
        [self updateUIWithCall:_call];
    }
}


#pragma mark - Update UI

- (void)updateCallUIWithNotification:(NSNotification *)notification {
    
    SCPCall *c = (SCPCall*)notification.userInfo[@"call"];
    if(c != _call)return;
    _call = c; // NEW
    [self updateUIWithCall:c];
}

- (void)updateUIWithCall:(SCPCall *)aCall {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    if (NO == self.isViewLoaded) {
        NSLog(@"%s\n-------------- Called before isViewLoaded ---------------",__PRETTY_FUNCTION__);
        return;
    }
    
    if (!aCall.isEnded) {
        [SPCallManager hold:aCall on:NO];
    }
    
    // Profile/Avatar shake
    if (aCall.isInProgress) {
        [self updateContactVerifiedWithCall:aCall];
        [self shakeProfileView];
    } else {
        [self stopProfileViewShake];
    }

    // Incoming buttons
    if ([aCall isIncomingRinging] && !_isShowingIncomingCallButtons) {
        [self updateButtonsForIncomingCall];
    }
    
    // Handle cases:
    // * The app was not active and not backgrounded, and user answered
    //   from notification banner. In this case, the incoming buttons
    //   could be displayed and the call is already answered.
    //
    // * With 2 active calls, end current call. The call property is
    //   reset with the last remaining call, but the end call workflow
    //   will have left the btEndCall hidden.
    BOOL updateButtons = (_isShowingIncomingCallButtons || _btEndCall.hidden);
    if (aCall.isAnswered && updateButtons) {
        [self updateButtonsToEndCallStateWithAnimation:NO];
    }
    
    // incoming/ending avatar, geekstrip, navButtons
    if (!aCall.isAnswered || aCall.isEnded) {
        
        if (aCall.isEnded) {
            [self updateUIForEndingCall:aCall msg:nil];
            return;
        } else {
            // ensure geek strip is hidden for incoming
            [self showGeekStrip:NO animated:NO];
        }
        
        [self enableNavButtonsView:NO];
    }
    else {        
        [self enableNavButtonsView:YES];
    }

    // show/hide zrtp/info panels
    if(!aCall.isEnded && !aCall.isAnswered && aCall.bufSecureMsg.length>0){
        [self showZRTPPanel];
    }
    else if(aCall.isEnded || !aCall.isAnswered){
        [self showInfoPanelAnimated:NO];
    }
    else if(aCall.isAnswered){
        [self showZRTPPanel];
    }

    // Always update label with call info -
    // showInfoPanelAnimated: manages showing/hiding call info
    _lbCallInfo.text = aCall.bufMsg; // "Ringing", "Incoming Call", etc.

    // Update header view elements
    [self updateHeaderViewWithCall:aCall];

    // Update ZRTP
    [self updateZRTPState:aCall];
   
    if(_btVideo.userInteractionEnabled && _call.shouldShowVideoScreen && !_call.isEnded){
       [self showVideoScreen];
    }
}

- (void)updateUIForEndingCall:(SCPCall *)aCall msg:(NSString *)msg {

    if ([self dialPadIsVisible]) {
        [self dismissDialPad];
    }

    [self showGeekStrip:NO];
    
    _btAvatarVerify.hidden = YES;
    [self unmaskContactView];
    
    [self clearSecureLabels];
    [self clearSASLabel];
    
    [self showInfoPanelAnimated:YES];
    
    [self enableNavButtonsView:NO];
    
    if (!msg) {
        msg = aCall.bufMsg;
        if ([[msg lowercaseString] containsString:@"decline"]) {
            msg = @"Declined...";
        }
    }
    NSLog(@"\n    UPDATE UI:  --- CALL ENDED: bufMsg: %@ ---", aCall.bufMsg);
    
    _lbCallInfo.text = (msg && msg.length) ? msg : @"Call Ended";
    [self updateButtonsToEndCallStateWithAnimation:YES];
}


#pragma mark - Update ZRTP

- (void)updateZRTPUIWithNotification:(NSNotification *)notification {
    
    SCPCall *c = (SCPCall*)notification.userInfo[@"call"];
    if(c != _call)return;
    [self updateZRTPState:c];
}

-(void)updateZRTPState:(SCPCall *)aCall {
    
    NSLog(@"\n    ZRTP:  --- aCall.isSASVerified: %@ ---",
          (aCall.isSASVerified)?@"YES":@"NO");
    
    if (aCall.isEnded) {
        NSLog(@"\n    ZRTP:  --- CALL ENDED - RETURN ---");
        return;
    }
    if (_zrtpPanelView.isHidden) {
        NSLog(@"\n    ZRTP:  --- ZRTP PANEL HIDDEN - RETURN ---");
        return;
    }

    if (!aCall.isSASVerified && aCall.bufSAS.length) {
        [self showUnsecureViewWithCall:aCall];
    }
    else {
        [self showSecureViewWithCall:aCall];
    }
}

- (void)showSecureViewWithCall:(SCPCall *)aCall {
    NSLog(@"\n    ZRTP:  --- SHOW SECURE ---");
    
    _secureSubView.hidden   = NO;
    _unSecureSubView.hidden = YES;
    
    // Verified checkmark button
    if (_btVerified.hidden == aCall.isSASVerified)
        _btVerified.hidden = !aCall.isSASVerified;
    
    // Avatar
    [self updateContactVerifiedWithCall:aCall];
    
    // SAS
    [self updateSASandVideoWithCall:aCall];
    
    // zrtpPeer
    BOOL canShowPeer=(aCall.zrtpPEER.length || (aCall.isSASVerified && aCall.bufSAS.length));
    if(canShowPeer){
        //if cache matches display name
        if ([aCall.nameFromAB isEqualToString:aCall.zrtpPEER]) {
            _lbZRTP_peer.hidden = YES;
        } else {
            _lbZRTP_peer.hidden = NO;
            _lbZRTP_peer.text = aCall.zrtpPEER;
        }
    } else {
        _lbZRTP_peer.hidden = YES;
    }

    // Secure/SecureSmall labels
    if(aCall.isAnswered || (!aCall.isEnded && aCall.bufSecureMsg.length>0)){
        _lbSecure.alpha=1.0;
        [_lbSecure setHidden:NO];
        UILabel *tmpLb = [[UILabel alloc] init];
        UILabel *tmpDesc = [[UILabel alloc] init];
        (void)[aCall setSecurityLabel:tmpLb desc:tmpDesc withBackgroundView:nil];
        _lbSecure.text = tmpLb.text;
        _lbSecure.textColor = tmpLb.textColor;
        _lbSecureSmall.text = tmpDesc.text;
        _lbSecureSmall.textColor = tmpDesc.textColor;
        
        NSLog(@"\n    ZRTP:  --- bufMsg: %@, bufSecureMsg: %@, secColor: %@",
              aCall.bufMsg, aCall.bufSecureMsg, [aCall getSecureColor]);
    }
    else {
        NSLog(@"\n    ZRTP:  --- NIL bufSecureMsg");
        [self clearSecureLabels];
    }
}

- (void)showUnsecureViewWithCall:(SCPCall *)aCall {
    NSLog(@"\n    ZRTP:  --- SHOW UNSECURE ---");
    
    _secureSubView.hidden   = YES;
    _unSecureSubView.hidden = NO;

    _lbZRTP_peer.hidden     = YES;
    [self clearSecureLabels];
    
    // Avatar
    [self updateContactVerifiedWithCall:aCall];
    
    // SAS
    [self updateSASandVideoWithCall:aCall];
    
    NSString *words_chars = (aCall.bufSAS.length > 4) ? @"words" : @"characters";
    _lbUnSecure.text = [NSString stringWithFormat:@"Compare the %@ below with partner", words_chars];
}

- (void)updateSASandVideoWithCall:(SCPCall*)aCall {
    if(aCall.bufSAS.length>0){
        _lbSAS.text = aCall.bufSAS;
        
        if (aCall.bufSAS.length > 4) {
            _lbSAS.font = [UIFont systemFontOfSize:17];
        }
        else {
            _lbSAS.font = [UIFont fontWithName:@"OCRB" size:20];
//            _lbSAS.adjustsFontSizeToFitWidth = YES;
        }
    }
    else {
        _btVideo.enabled = NO;
    }
}

- (void)clearSecureLabels {
    _lbSecure.text      = @"";
    _lbSecureSmall.text = @"";
}

- (void)clearSASLabel {
    _lbSAS.text = @"";
}

// Middle view contains:
// - avatar (contactView), btAvatarVerify
// - lbZRTP_peer
// - info panel: lbCallInfo
// - zrtp panel: lbSecure, lbSecureSmall, lbSAS, lb/btVerified
// - navButtonsView

#pragma mark - ZRTP Panel
-(void)showZRTPPanel {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    _infoPanelView.hidden = YES;
    _zrtpPanelView.hidden = NO;
    _zrtpPanelView.alpha  = 1.0;
}


#pragma mark - SAS Verify Alert

- (void)showSASVerifyDialog{
    NSString *title = [NSString stringWithFormat:@"%s:\n\"%@\"\n\n%s",
                       T_TR("Compare with partner"),
                       _call.bufSAS,
                       T_TR("Change partner device label (optional)")];
    
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil
                                                                message:title
                                                         preferredStyle:UIAlertControllerStyleAlert];
    
    
    [ac addTextFieldWithConfigurationHandler:^(UITextField *textField){
        [textField setBackgroundColor:[UIColor clearColor]];
        [textField setTextAlignment:NSTextAlignmentLeft];
        NSString *txt = (_call.zrtpPEER && _call.zrtpPEER.length) ? _call.zrtpPEER : [_call getName];
        [textField setText: txt];
        [textField setKeyboardAppearance:UIKeyboardAppearanceDark];
    }];
    
    [ac addAction:[UIAlertAction actionWithTitle:T_TRNS("Dismiss")
                                           style:UIAlertActionStyleCancel
                                         handler:^(UIAlertAction *action){
                                             
                                             
                                         }]];
    
    [ac addAction:[UIAlertAction actionWithTitle:T_TRNS("Confirm")
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action){
                                             
                                             UITextField *tf = ac.textFields[0];
                                             if(tf.text.length < 1)
                                                 tf.text = [_call getName];
                                             else
                                                 _call.zrtpPEER = tf.text;
                                             
                                             [SPCallManager setCacheName:tf.text call:_call];
                                             [SPCallManager setVerifyFlag:YES call:_call];
                                             
                                             
//                                             [self updateZRTPState:_call]; // needed?? won't there be a zrtpUpdateNotif?
                                         }]];
    
    [self presentViewController:ac animated:YES completion:nil];
}


#pragma mark - Info Panel / Call Info

-(void)showInfoPanelAnimated:(BOOL)anim{
    
    NSLog(@"%s\n    --- SHOW INFO PANEL ---", __PRETTY_FUNCTION__);
    
    if(!anim){
        _infoPanelView.hidden = NO;
        _infoPanelView.alpha  = 1.0;
        _lbCallInfo.hidden    = NO;
        _lbCallInfo.alpha     = 1.0;
        _zrtpPanelView.hidden = YES;
        return;
    }
    
    _infoPanelView.alpha  = 0.0;
    _infoPanelView.hidden = NO;
    _lbCallInfo.hidden    = NO;
    [UIView animateWithDuration:0.5
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^ {
                         _infoPanelView.alpha = 1.0;
                         _zrtpPanelView.alpha = 0.0;
                     }
                     completion:^(BOOL finished) {
                         _zrtpPanelView.hidden = YES;
                     }];
}


// Header view contains
// - lbDstName, lbDst
// - server name
// - geek strip elements
// - flag
// - lbDur, ivDurBg

- (void)updateHeaderViewWithCall:(SCPCall *)aCall {

    // Call duration label
    if (!aCall.isAnswered) {
        [self showCallDuration:NO animated:NO];
    }
    else {
        [self showCallDuration:YES animated:YES];
    }

    // destination name and destination number
    _lbDstName.text = aCall.getName;
    // dont repeat if destination name and destination are same
    _lbDst.text = [aCall.displayNumber isEqualToString: [aCall getName]] ? @"" : aCall.displayNumber;

    // server name
    if(aCall.bufServName.length<1){
        // TODO: Set in SCPCallManager?
        aCall.bufServName = [Switchboard titleForAccount:aCall.pEng];
    }
    _lbServer.text = aCall.bufServName;
    
    // update flag
    if (aCall.displayNumber && aCall.displayNumber.length > 0) {
        [self updateFlagImageWithNumber:aCall.displayNumber];
    }
}


#pragma mark - Call Duration

- (void)updateCallDuration {
    if (_lbCallDur.alpha == 0) { return; }
    _lbCallDur.text = _call.durationString;
}

- (void)showCallDuration:(BOOL)shouldShow animated:(BOOL)animated {
    [self fadeView:_lbCallDur fadeIn:shouldShow animated:animated];
    [self fadeView:_ivCallDurBg fadeIn:shouldShow animated:animated];
}


#pragma mark - Geek Strip Methods

- (void)updateGeekStrip {
//    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    static int *piShowGeekStrip = (int *)findGlobalCfgKey("iShowGeekStrip");
    if((piShowGeekStrip && *piShowGeekStrip)){
        char buf[64];
        
        int getMediaInfo(int iCallID, const char *key, char *p, int iMax);
        int r=getMediaInfo(_call.iCallId,"codecs",&buf[0],63);
        if(r<0)r=0;
#ifdef T_TEST_MAX_JIT_BUF_SIZE
        if(iAudioBufSizeMS){
            //10 = 1000 msec,25 = 2500 msec,
            r+=snprintf(&buf[r],63-r," d%02d",iAudioBufSizeMS/100);
        }
#endif
        if(r>0) _lbGeekStrip.text = [NSString stringWithUTF8String:&buf[0]];
    }
}

// Wired to btGeekStrip in IB
- (IBAction)handleGeekStripTap:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    static int *piShowGeekStrip = (int *)findGlobalCfgKey("iShowGeekStrip");
    if(piShowGeekStrip) {
        piShowGeekStrip[0]=!piShowGeekStrip[0];
        t_save_glob();
    }

    // toggle
    BOOL shouldShow = ![self geekStripIsShowing];
    [self showGeekStrip:shouldShow];
}

// Default is animated
- (void)showGeekStrip:(BOOL)shouldShow {
    [self showGeekStrip:shouldShow animated:YES];
}

- (void)showGeekStrip:(BOOL)shouldShow animated:(BOOL)animated {
    
    CGFloat stripW = _origGeekStripWidth;
    if (shouldShow) {
        stripW += _lbGeekStrip.frame.size.width;
    }
    CGFloat leading = (shouldShow) ? 8.0 : _origDstNameLeading;
    
    if (!animated) {
        _lbGeekStrip.hidden = !shouldShow;
        _geekStripWidthConstraint.constant = stripW;
        _dstNameLeadingConstraint.constant = leading;
        [_headerView layoutIfNeeded];
        return;
    }

    // Pop the label back 1st with no animation -
    // shortening the label with animation results in choppy resizing
    // of font.
    _dstNameLeadingConstraint.constant = leading;
    [_headerView layoutIfNeeded];

    [UIView animateWithDuration:0.35 delay:0
         usingSpringWithDamping:.5 initialSpringVelocity:100.//.58 initialSpringVelocity:0
                        options:0
                     animations:^{
                         _geekStripWidthConstraint.constant = stripW;
                         [_headerView layoutIfNeeded];
                         _lbGeekStrip.hidden = !shouldShow;
                     } completion:nil];
}

- (BOOL)geekStripIsShowing {
    return _geekStripWidthConstraint.constant > _origGeekStripWidth;
}

- (void)updateLed {
    
    //TODO: Move this to CallManager API
    int g_getCap(int &iIsCN, int &iIsVoice, int &iPrevAuthFail);
    int iIsCn,iIsVoice,iPrevAuthFail;
    int v=g_getCap(iIsCn,iIsVoice,iPrevAuthFail);
    static int pv=-1;
    static int previPrevAuthFail=-1;
    float fv=(float)v*0.005f+.35f;
    
    if(previPrevAuthFail!=iPrevAuthFail || pv!=v){
        if(iPrevAuthFail){
            [_ivLed setBackgroundColor:[UIColor colorWithRed:fv green:0 blue:0 alpha:1.0]];
        }
        else{
            [_ivLed setBackgroundColor:[UIColor colorWithRed:0 green:fv blue:0 alpha:1.0] ];
        }
        pv=v;
        previPrevAuthFail=iPrevAuthFail;
    }
}

#pragma mark - Flag

- (void)updateFlagImageWithNumber:(NSString *)nr {
//    NSLog(@"%s\n    --- UPDATE FLAG CALLED ----", __PRETTY_FUNCTION__);
    
    [[SCSPhoneHelper sharedPhoneHelper] getCountryFlagName:nr
                                         completitionBlock:^(NSDictionary *countryData){
                                             if(countryData)
                                             {
                                                 NSString *prefix = [countryData objectForKey:@"prefix"];
                                                 NSString *imgName = [NSString stringWithFormat:@"%@.png", prefix];
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     _ivFlag.image = [UIImage imageNamed:imgName];
                                                 });
                                             }
                                             else{
                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                     _ivFlag.image = nil;
                                                 });
                                             }
                                         }];
}


#pragma mark - RecentObject / Avatar

-(void)recentObjectUpdated:(NSNotification *) note
{
    NSLog(@"%s called", __PRETTY_FUNCTION__);
    
    RecentObject *updatedRecent = (RecentObject *) note.object;
    NSString *updatedUsername = [[Utilities utilitiesInstance] removePeerInfo:updatedRecent.contactName lowerCase:YES];
    NSString *thisUsername = [[Utilities utilitiesInstance] removePeerInfo:_call.bufPeer lowerCase:YES];
    if ([updatedUsername isEqualToString:thisUsername]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setBackgroundAndAvatarFromRecent:updatedRecent];
        });
    }
    [self updateUIWithCall:_call];
}


- (void)fetchPeerAvatarInBackground {
    if (!_call) { return; }
    
    NSString *contactName = (_call.bufPeer) ?: _call.bufDialed;
    
    // getOrCreateRecentObjectWithContactName crashes with nil [something],
    // so if we have a nil contactName, we should
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        RecentObject *recentObject = [[Utilities utilitiesInstance] getOrCreateRecentObjectWithContactName:contactName];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"\n    --- viewDidLoad: call setBackgroundAndAvatarFromRecent ---");
            [self setBackgroundAndAvatarFromRecent:recentObject];
        });
    });
}

-(void)setBackgroundAndAvatarFromRecent:(RecentObject *) thisRecent
{
    NSLog(@"%s called", __PRETTY_FUNCTION__);
    
    UIImage *callImage = thisRecent.avatarImage;
    _ivBackgroundAvatar.image = callImage;
    
    if(callImage)
    {
        [_contactView setImage:callImage];
    }
    else
    {
        [_contactView showDefaultContactImage];
        [_contactView setInitials:[[Utilities utilitiesInstance] getInitialsForUserName:[_call getName]]];
    }
    [_contactView showWhiteBorder];
}

- (void)updateContactVerifiedWithCall:(SCPCall*)aCall {

    if (aCall.bufSAS.length>0 && !aCall.isSASVerified) {
        if (_btAvatarVerify.hidden) {
            _btAvatarVerify.hidden = NO;
            [self maskContactView];
        }
        UIColor *color = (!_contactView.image) ? [UIColor darkTextColor] : [UIColor whiteColor];
        [_btAvatarVerify setTitleColor:color forState:UIControlStateNormal];
    }
    else {
        if (!_btAvatarVerify.hidden) {
            _btAvatarVerify.hidden = YES;
            [self unmaskContactView];
        }
    }
}

//TODO: masked contactView
- (void)maskContactView {
    if (_contactView.alpha == 1)
        _contactView.alpha = 0.25;
}

- (void)unmaskContactView {
    if (_contactView.alpha != 1.0)
        _contactView.alpha = 1.0;
}


#pragma mark - Volume Warning

- (void)updateVolumeWarning {
    // 1st pass: hide
    self.lblVolumeWarning.hidden = YES;
}


#pragma mark - Nav Button Methods

// For incoming call to prevent navigation before answering/declining
- (void)enableNavButtonsView:(BOOL)shouldEnable {
    _navButtonsView.alpha = (shouldEnable) ? 1 : 0.5;
    [_navButtonsGroup enumerateObjectsUsingBlock:^(UIButton *btn, NSUInteger idx, BOOL *stop) {
        if (btn == _btSpeaker) {
            btn.enabled = YES;
        }
        else if (btn == _btVideo) {
            btn.enabled = (shouldEnable) ? [self canEnableVideo] : NO;
        }
        //TMP - disable Chat button until implemented
        else if (btn == _btMessages) {
            btn.enabled = (shouldEnable) ? ENABLE_CHAT_BUTTON : NO;
        }
        else {
            btn.enabled = shouldEnable;
        }
    }];
}

// buttons layout: left to right, top to bottom
- (IBAction)handleVerifyTap:(id)sender {
   NSLog(@"%s", __PRETTY_FUNCTION__);
   [self showSASVerifyDialog];

}

- (IBAction)handleMuteTap:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [SPAudioManager setMuteMic: ![SPAudioManager micIsMuted] ];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateMuteButtonImage];
    });
}
- (void)updateMuteButtonImage {
    BOOL isMuted =[SPAudioManager micIsMuted];
    self.btMute.accessibilityLabel = (isMuted) ? NSLocalizedString(@"Unmute", nil) : NSLocalizedString(@"Mute", nil);
    self.btMute.highlighted = isMuted;
}


- (IBAction)handleInCallDialPadTap:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self presentDialPad];
}

- (IBAction)handleChatTap:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if ([_navDelegate respondsToSelector:@selector(switchToChatWithCall:)]) {
        [_navDelegate switchToChatWithCall:self.call];
    }
}

- (IBAction)handleAudioTap:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
   
   [SPAudioManager switchRouteToLoudspeakerOrPrivate: !SPAudioManager.loudspeakerIsOn];
}

- (IBAction)handleConversationsTap:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if ([_navDelegate respondsToSelector:@selector(switchToConversationsWithCall:)]) {
        [_navDelegate switchToConversationsWithCall:self.call];
    }
}

-(void)showVideoScreen{
    if ([_navDelegate respondsToSelector:@selector(switchToVideo:call:)]) {
        [_navDelegate switchToVideo:nil call:self.call];
    }
}

- (IBAction)handleVideoTap:(id)sender {
    NSLog(@"%s self:%@", __PRETTY_FUNCTION__,self);
   [SPCallManager switchToVideo:_call on:YES];
   [self showVideoScreen];
   //we could show verify dialog if sas is not verifed instead of disabling the video button

}

- (IBAction)handleCallManagerTap:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if ([_navDelegate respondsToSelector:@selector(switchToConference:call:)]) {
        [_navDelegate switchToConference:nil call:self.call];
    }
}

- (BOOL)canEnableVideo {
    BOOL hasPermission = [[UserService currentUser] hasPermission:UserPermission_InitiateVideo];
    return (_call.bufSAS.length>0 && hasPermission);
}


#pragma mark - Answer Methods

- (IBAction)handleAnswerCallTap:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [SPCallManager answerCall:_call];
    [self stopProfileViewShake];
    
    // Why do we need this check if the user just chose to answer call?
    if ([SPCallManager getCallCount] > 0) {
        [self updateButtonsToEndCallStateWithAnimation:YES];
    }
}

-(void) shakeProfileView
{
    NSLog(@"\n   --- START SHAKING AVATAR ---");
    
    _contactView.transform = CGAffineTransformMakeTranslation(5, 0);
    
    [UIView animateWithDuration:0.1f
                          delay:0.0
                        options:UIViewAnimationOptionAutoreverse
                     animations:^ {
                         [UIView setAnimationRepeatCount:NSUIntegerMax];
                         _contactView.transform = CGAffineTransformIdentity;
                     }
                     completion:nil
     ];
    
}

-(void) stopProfileViewShake
{
    NSLog(@"\n   --- STOP SHAKING AVATAR ---");
    
    _contactView.transform = CGAffineTransformIdentity;
    [_contactView.layer removeAllAnimations];
}

- (BOOL)profileIsShaking {
    return (_contactView.layer.animationKeys.count > 0);
}

#pragma mark - End Methods

/**
 * Terminates the call.
 *
 * Note that we must update the call info label manually here because
 * we will not get a callStateDidUpdate notification after this
 * terminating event.
 */
- (IBAction)handleEndOrDeclineCallTap:(id)sender {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [self updateUIForEndingCall:_call msg:@"Call Ended"];
    
    NSLog(@"%s terminate call async", __PRETTY_FUNCTION__);
    
    __weak SCPCall *weakCall = _call;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [SPCallManager terminateCall:weakCall];
    });

    [self updateButtonsToEndCallStateWithAnimation:YES];
}


#pragma mark - Call Buttons Animations

- (void)updateButtonsToEndCallStateWithAnimation:(BOOL)animated {
    [self updateButtonsToEndCallStateWithAnimation:animated delay:0];
}
- (void)updateButtonsToEndCallStateWithAnimation:(BOOL)animated delay:(NSTimeInterval)delay {

    _isShowingIncomingCallButtons = NO;
    if (animated) {
        self.view.userInteractionEnabled = NO;
        [self adjustButtonsExpand:YES animated:YES];
        [UIView animateWithDuration:kViewAnimationDuration delay:delay
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             //[_btEndCall setTitle:T_TRNS_TODO_FIX("End Call") forState:UIControlStateNormal];
                             _btAnswer.hidden = YES;
                             _btHideKeypad.hidden = YES;
                            // Hide if call is ended
                            _btEndCall.hidden = (_call.isEnded);
                         } completion:^(BOOL finished) {
                             self.view.userInteractionEnabled = YES;
                         }];
    }
    else {
        _btAnswer.hidden = YES;
        _btHideKeypad.hidden = YES;
        [self adjustButtonsExpand:YES animated:NO];
        // Hide if call is ended
        _btEndCall.hidden = (_call.isEnded);
    }
}

- (void)updateButtonsForIncomingCall {
    if (_isShowingIncomingCallButtons) {
        NSLog(@"%s\n----------------Already showing incoming call buttons---------------",__PRETTY_FUNCTION__);
        return;
    }
    _isShowingIncomingCallButtons=YES;

    UIImage *img = (_call.hasVideo) ? [UIImage imageNamed:@"ico_camera.png"] : nil;
    [_btAnswer setImage:img forState:UIControlStateNormal];

    self.view.userInteractionEnabled = NO;
    [self adjustButtonsExpand:NO animated:YES];
    [UIView animateWithDuration:kViewAnimationDuration animations:^{
        _btAnswer.hidden       = NO;
        _btHideKeypad.hidden   = YES;

// [_btEndCall setTitle:T_TRNS_TODO_FIX("Decline") forState:UIControlStateNormal];
    } completion:^(BOOL finished){
        self.view.userInteractionEnabled = YES;
    }];
}

/**
 * A utility method to expand or contract the "End Call" button,
 * optionally, with animation.
 *
 * When the expand argument is YES, the button is elongated to the width
 * of the containing view minus inset margins on leading and trailing
 * edges.
 *
 * When called with animation YES, the animation is performed on the 
 * button width and center x layout constraints' constant values, in a
 * UIView animation block, and otherwise without animation.
 *
 * This method is called when animating the change from the call screen
 * buttons (in the navButtonsView container view) to the dial pad buttons
 * (in the dialPadView container). 
 *
 * When contracting (expand argument NO), the "End Call" button is 
 * positioned left of center and its width is reduced to create space 
 * for a "Hide Keypad" button when switching to the dial pad view.
 *
 * When elongating the button when switching back the from dial pad view 
 * (expand argument YES), the button is centered and its width expanded
 * to fill most of the width of the containing view. The "Hide Keypad"
 * button is hidden in this animation, not handled in this method.
 *
 * @param expand YES to elongate and center the "End Call" button, NO to
 * contract and position left of center.
 * 
 * @param animated YES to animate button layout changes, NO otherwise.
 */
- (void)adjustButtonsExpand:(BOOL)expand animated:(BOOL)animated {
    NSLog(@"%s called to %@",__PRETTY_FUNCTION__, (expand) ? @"EXPAND":@"SHOW TWO BUTTONS");

    if (animated) {
            [UIView animateWithDuration:0.1f delay:0
                                options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                                 
                                 _endBTCenterXconstraint.constant = (expand) ? 0 : _origEndCallBTCenterX;
                                 [_btEndCall.superview layoutIfNeeded];
                                 
                             } completion:^(BOOL finished) {
                                 
                                 // Logging
                                 dispatch_async(dispatch_get_main_queue(),^{
                                     NSLog(@"\nbuttonssuperview:%@\nButtons AFTER animation block:\nendBTwidth: %1.2f\nendBTcenter: %1.2f",
                                           NSStringFromCGSize(_btEndCall.superview.frame.size),
                                           _endBTWidthConstraint.constant,
                                           _endBTCenterXconstraint.constant);
                                 });
                             }];
        }
        else {
            
            _endBTCenterXconstraint.constant = (expand) ? 0 : _origEndCallBTCenterX;
            [_btEndCall.superview layoutIfNeeded];

            // Logging
            NSLog(@"\nbuttonssuperview:%@\nButtons NO animation:\nendBTwidth: %1.2f\nendBTcenter: %1.2f",
                  NSStringFromCGSize(_btEndCall.superview.frame.size),
                  _endBTWidthConstraint.constant,
                  _endBTCenterXconstraint.constant);
        }
}


#pragma mark - DialPad Methods

- (void)presentDialPad {
    _btHideKeypad.hidden = NO;
    _endBTCenterXconstraint.constant = _origEndCallBTCenterX;
    [_btEndCall.superview layoutIfNeeded];
    
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Phone" bundle:nil];
    SCSCallScreenDialPadVC *dpvc = [sb instantiateViewControllerWithIdentifier:@"SCSCallScreenDialPadVC"];
    [self addChildViewController:dpvc];
    
    dpvc.view.frame = _dialPadContainer.bounds;
    dpvc.view.translatesAutoresizingMaskIntoConstraints = YES;
    [_dialPadContainer addSubview:dpvc.view];
    
    _callScreenContainer.accessibilityElementsHidden = YES;
    
    [UIView transitionWithView:self.view duration:0.35
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        
                        [self.view insertSubview:_dialPadContainer
                                    belowSubview:_endCallButtonsView];
                        
                    } completion:^(BOOL finished) {
                        [dpvc didMoveToParentViewController:self];
                        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
                    }];
}

- (IBAction)dismissDialPad {
    _endBTCenterXconstraint.constant = 0;
    [_btEndCall.superview layoutIfNeeded];
 
    self.dialPadVC.textfield.text = nil;
    
    _callScreenContainer.accessibilityElementsHidden = NO;
    [UIView transitionWithView:self.view duration:0.35
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        
                        [self.view sendSubviewToBack:_dialPadContainer];
                        _btHideKeypad.hidden = YES;
                        
                    } completion:^(BOOL finished) {
                        SCSCallScreenDialPadVC *dpvc = [self dialPadVC];
                        [dpvc willMoveToParentViewController:nil];
                        [dpvc.view removeFromSuperview];
                        [dpvc removeFromParentViewController];
                        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
                    }];
}

- (SCSCallScreenDialPadVC *)dialPadVC {
    return [self.childViewControllers firstObject];
}

- (BOOL)dialPadIsVisible {
    return (self.dialPadVC.view != self.view.subviews[0]);
}


#pragma mark - Timers

-(void)startTimer{
    
    if (_callDurTimer) [_callDurTimer invalidate];
    
    NSTimeInterval hz = 1./3.;
    
    _callDurTimer = [NSTimer
                     scheduledTimerWithTimeInterval:hz
                     target:self
                     selector:@selector(tick)
                     userInfo:nil
                     repeats:YES
                     ];
}

-(void)stopTimer{
    if (_callDurTimer) {
        [_callDurTimer invalidate];
        _callDurTimer = nil;
    }
}

-(void)tick{
    [self updateCallDuration];
    [self updateGeekStrip];
}

-(void)startLedTimer{
    
    if (_ledTimer) [_ledTimer invalidate];
    
    NSTimeInterval hz = 1./40.;
    
    _ledTimer = [NSTimer
                 scheduledTimerWithTimeInterval:hz
                 target:self
                 selector:@selector(tickLed)
                 userInfo:nil
                 repeats:YES
                 ];
    
}

-(void)stopLedTimer{
    if (_ledTimer) {
        [_ledTimer invalidate];
        _ledTimer = nil;
    }
}

-(void)tickLed{
    [self updateLed];
}


#pragma mark - Remote Control
/*
 *TODO:
 * NOTE: from iOS 7.1 it is possible to register for these events:
 * https://developer.apple.com/library/ios/documentation/EventHandling/Conceptual/EventHandlingiPhoneOS/Remote-ControlEvents/Remote-ControlEvents.html
 */
- (void) remoteControlReceivedWithEvent: (UIEvent *) receivedEvent {
    
    NSLog(@"ev t=%ld st=%ld",(long)receivedEvent.type,(long)receivedEvent.subtype);
    
    if (receivedEvent.type == UIEventTypeRemoteControl) {
        
        switch (receivedEvent.subtype) {
                
            case UIEventSubtypeRemoteControlTogglePlayPause:
            {
                SCPCall *call = [SPCallManager getSelectedCall];
                
                if(call.isAnswered || !call.iIsIncoming){
                    [self handleEndOrDeclineCallTap:nil];
                }
                else{
                    [self handleAnswerCallTap:nil];
                }
                break;
            }
            default:
                break;
        }
    }
}


#pragma mark - Audio Notification Handler

- (void)updateAudioNotification:(NSNotification *)notification {
    
    if([SPAudioManager loudspeakerIsOn]){
        
        UIImage *bti=[UIImage imageNamed:@"bt_dial_down.png"];
        [_btSpeaker setBackgroundImage:bti forState:UIControlStateNormal];
        _btSpeaker.accessibilityLabel = @"speaker selected";
        
        if(1){
//          NSLog(@"%s\n ----- ENABLE PROXIMITY MONTIORING ----", __PRETTY_FUNCTION__);
            [UIDevice currentDevice].proximityMonitoringEnabled = YES;
        }
    }
    else{
        UIImage *bti=[UIImage imageNamed:@"bt_dial_up.png"];
        [_btSpeaker setBackgroundImage:bti forState:UIControlStateNormal];
        _btSpeaker.accessibilityLabel = @"speaker";
        
        if([SPAudioManager isHeadphoneOrBluetooth]){
//          NSLog(@"%s\n ----- DISABLE PROXIMITY MONTIORING ----", __PRETTY_FUNCTION__);
            [UIDevice currentDevice].proximityMonitoringEnabled = NO;
        }
        else {
//          NSLog(@"%s\n ----- ENABLE PROXIMITY MONTIORING ----", __PRETTY_FUNCTION__);
            [UIDevice currentDevice].proximityMonitoringEnabled = YES;
        }
    }
}


#pragma mark - Notification Registration

- (void)registerForNotifications {
    NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
    
    [notifCenter addObserver:self selector:@selector(updateCallUIWithNotification:)
                        name:kSCPCallStateDidChangeNotification object:nil];
    
    [notifCenter addObserver:self selector:@selector(updateZRTPUIWithNotification:)
                        name:kSCPZRTPDidUpdateNotification object:nil];
    
    [notifCenter addObserver:self selector:@selector(updateAudioNotification:)
                        name:kSCSAudioStateDidChange object:nil];
    
    [notifCenter addObserver:self selector:@selector(recentObjectUpdated:)
                        name:kSCSRecentObjectUpdatedNotification object:nil];
}

- (void)unRegisterForNotifications {
    NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
    [notifCenter removeObserver:self name:kSCPCallStateDidChangeNotification object:nil];
    [notifCenter removeObserver:self name:kSCPZRTPDidUpdateNotification object:nil];
    [notifCenter removeObserver:self name:kSCSAudioStateDidChange object:nil];
}


#pragma mark - Utilities

// With animation
- (void)fadeInView:(UIView *)aView {
    [self fadeView:aView fadeIn:YES animated:YES];
}
- (void)fadeOutView:(UIView *)aView {
    [self fadeView:aView fadeIn:NO animated:YES];
}

/**
 * Shows or hides the given view.
 *
 * This utility method is invoked by the fadeInView: and fadeOutView:
 * convenience methods, and is also invoked directly.
 *
 * "Show" and "hide", in the context of this method, means alpha set to
 * one or to zero, respectively. This method first checks the alpha 
 * value of the given view; if the view's alpha value is already set
 * appropriately, the method returns, taking no action.
 *
 * @param aView The view or view subclass to show or hide.
 *
 * @param fadeIn YES if fading in; NO if fading out.
 *
 * @param animated YES to fade with animation; NO to hide immediately.
 */
- (void)fadeView:(UIView *)aView fadeIn:(BOOL)fadeIn animated:(BOOL)animated {

    CGFloat alpha = aView.alpha = (fadeIn) ? 1 : 0;
    if (aView.alpha == alpha) { return; }
    
    if (!animated) {
        aView.alpha = alpha;
        return;
    }

    [UIView transitionWithView:aView duration:0.35
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        aView.alpha = alpha;
                    } completion:nil];
}


// Experimental accessibility:
// try to make VoiceOver speak call info and security updates
#if 0

#pragma mark KVO Context
// Context for KVO isReloding listener
static void * SCConfContext = &SCConfContext;

#pragma mark - Accessibility

- (void)setupAccessibility {
    [self registerPropertyObservers];
    [self updateDialPadAccessibility];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context
{
    if (SCConfContext != context) { return; }
    
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(lbCallInfo))])
    {
        [self updateCallInfoAccessibility];
    }
    else if ([keyPath isEqualToString:NSStringFromSelector(@selector(lbSecure))] ||
             [keyPath isEqualToString:NSStringFromSelector(@selector(lbSecureSmall))])
    {
        [self updateSecurityStateAccessibility];
    }
}


- (void)cleanupAccessibility {
    [self deregisterPropertyObservers];
}

- (void)updateDialPadAccessibility {
    [self dialPadVC].view.accessibilityElementsHidden = ![self dialPadIsVisible];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

- (void)updateSecurityStateAccessibility {
    if (!_zrtpPanelView.isHidden) {
        NSString *txtSecurity = [NSString stringWithFormat:@"%@, %@", _lbSecure, _lbSecureSmall];
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, txtSecurity);
    }
}

- (void)updateCallInfoAccessibility {
    if (!_infoPanelView.isHidden) {
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, _lbCallInfo.text);
    }
}

- (void)registerPropertyObservers {
    NSLog(@"%s called",__PRETTY_FUNCTION__);
    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(lbCallInfo))
              options:NSKeyValueObservingOptionNew context:SCConfContext];
    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(lbSecure))
              options:NSKeyValueObservingOptionNew context:SCConfContext];
    [self addObserver:self forKeyPath:NSStringFromSelector(@selector(lbSecureSmall))
              options:NSKeyValueObservingOptionNew context:SCConfContext];
    
}

- (void)deregisterPropertyObservers {
    NSLog(@"%s called",__PRETTY_FUNCTION__);
    // Unsubscribe KVO
    @try {
        [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(lbCallInfo))];
    }
    @catch (NSException * __unused exception) {}
    @try {
        [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(lbSecure))];
    }
    @catch (NSException * __unused exception) {}
    @try {
        [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(lbSecureSmall))];
    }
    @catch (NSException * __unused exception) {}
}
#endif


#pragma mark - UIViewController Methods

- (BOOL) canBecomeFirstResponder {
    
    return YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation{
    return UIInterfaceOrientationPortrait;
}


@end
