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
#import <AVFoundation/AVFoundation.h>

#import "SCPCall.h"
#import "CallScreenVC.h"
#import "DBManager.h"
#import "ChatUtilities.h"
#import "RecentObject.h"
#import "SCPCallManager.h"
#import "SCPCallbackInterface.h"
#import "SCPNotificationKeys.h"
#import "SCPTranslateDefs.h"
#import "SCSAudioManager.h"
#import "SCSAutoLayout.h"
#import "SCSCallScreenDialPadVC.h"
#import "SCSCallGeekStrip.h" //??
#import "SCSCallGeekView.h"
#import "SCSCallDurationView.h"
#import "SCSPhoneHelper.h"
#import "SCDRWarningView.h"
#import "Silent_Phone-Swift.h"
#import "SPUser.h"
#import "UserService.h"
#import "SCSFeatures.h"
#import "SCSAvatarManager.h"

static const CGFloat kViewAnimationDuration = 0.5;

#pragma mark enable/disable Chat Button
//TMP - disable Chat button until implemented
static BOOL ENABLE_CHAT_BUTTON = YES;

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
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *headerViewTopConstraint;

//----------------------------------------------------------------------
// Data Retention warning view
//
@property (weak, nonatomic) IBOutlet SCDRWarningView *dataRetentionWarningView;

//----------------------------------------------------------------------

//----------------------------------------------------------------------
// Geek Strip
//
// geekView encapsulates: geek strip (15 0.1s 0.0% loss G722/GSM),
//                        LED, and antenna (ico_antena_4.png)
@property (weak, nonatomic) IBOutlet SCSCallGeekView      *geekView;
@property (weak, nonatomic) IBOutlet UIButton             *btGeekStrip;  // show/hide geek strip
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *geekViewWidthConstraint;
@property (assign, nonatomic) CGFloat                     origGeekViewWidth;
//----------------------------------------------------------------------

@property (weak, nonatomic) IBOutlet UIImageView *ivFlag;

//----------------------------------------------------------------------
// Call Duration
//
// callDurView encapsulates: label (01:59), and imageView background
@property (weak, nonatomic) IBOutlet SCSCallDurationView *callDurView;
//----------------------------------------------------------------------

//@property (weak, nonatomic) IBOutlet UILabel *lbServer; // SilentCircle (fs-devel.silentcircle.org)

//----------------------------------------------------------------------
// Contact / Avatar views
//----------------------------------------------------------------------
@property (weak, nonatomic) IBOutlet SCSContactView *contactView;
@property (weak, nonatomic) IBOutlet UIImageView    *ivBackgroundAvatar;
@property (weak, nonatomic) IBOutlet UILabel *microphoneAccessLabel;
@property (weak, nonatomic) IBOutlet UIView *microphoneAccessView;
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
    BOOL _viewWillAppearFired;
    BOOL _viewDidAppearHasFired;
    
    BOOL _audioErrorAlertVisible;
}

#pragma mark - Initialization

- (void)dealloc {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {

    [super viewDidLoad];
    
    if (UIAccessibilityIsVoiceOverRunning()) {
        [self setupAccessibility];
    }
        
    // Clear potential IB placeholder text in labels
    _lbDstName.text     = @"";
    _lbDst.text         = @"";
    _lbCallInfo.text    = @"";
   
    _lbCallInfo.lineBreakMode = NSLineBreakByWordWrapping;
    _lbCallInfo.numberOfLines = 0;
   
    [self clearSASLabel];
    [self clearSecureLabels];
    
    _ivFlag.image = nil;
    
    // Hide contactView until needed
    _contactView.image = nil;
    
    // Geek strip
    [_geekView configureStartingState];
    _origGeekViewWidth  = _geekViewWidthConstraint.constant;
    _origDstNameLeading = _dstNameLeadingConstraint.constant;
    // Button should be hidden if "canShow" is false, to
    // hide button from accessibility.
    _btGeekStrip.hidden = ![_geekView geekStripCanShow];

    
    // Call Duration - hide until call is answered
    [_callDurView updateDurationWithCall:nil];
    _callDurView.alpha = 0.;
    
    // Store/calculate btEndCall dimensions
    _origEndCallBTCenterX = _endBTCenterXconstraint.constant;
    // compute endCallBT long width
    CGFloat superwidth = _btEndCall.superview.frame.size.width;
    _longEndCallBTWidth = superwidth - (2 * kscsButtonsMargin);

    [self updateButtonsToEndCallStateWithAnimation:NO];
    
#if HAS_DATA_RETENTION
    _dataRetentionWarningView.infoHolderVC = self;
    [_dataRetentionWarningView positionWarningAboveConstraint:_headerViewTopConstraint offsetY:_headerViewTopConstraint.constant];
#else
    _dataRetentionWarningView.hidden = YES;
    _dataRetentionWarningView.drButton.hidden = YES;
#endif // HAS_DATA_RETENTION
}

- (void)viewWillAppear:(BOOL)animated {

    [super viewWillAppear:animated];
    
    [_microphoneAccessView setHidden:YES];
    
    [UIViewController attemptRotationToDeviceOrientation];
    
    [self becomeFirstResponder];
    
    [self updateVolumeWarning];
    [self updateMuteButtonImage];
    [self updateAudioNotification: nil];
    
    [self registerForNotifications];
    
    _viewWillAppearFired = YES;
    
    if (_call) {
        [self fetchPeerAvatarInBackground];
        [self updateUIWithCall:_call];
    }    
}

- (void)viewDidLayoutSubviews {
    
    [super viewDidLayoutSubviews];

#if HAS_DATA_RETENTION
    // data retention
    NSString *contactName = (_call.bufPeer) ?: _call.bufDialed;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        RecentObject *recipient = [[DBManager dBManagerInstance] getOrCreateRecentObjectWithContactName:contactName];
        dispatch_async(dispatch_get_main_queue(), ^{
            [_dataRetentionWarningView enableWithRecipient:recipient];
        });
    });
#endif // HAS_DATA_RETENTION
}

- (void) viewDidAppear: (BOOL) animated {

    [super viewDidAppear: animated];
    _viewDidAppearHasFired = YES;
    
    [self validateMicrophoneAccess];
}

// the call to terminate call will result in the rootVC dismissing the callNavVC
- (void) viewWillDisappear: (BOOL) animated {
    
    [super viewWillDisappear: animated];
    
    [self prepareToBecomeInactive];
}

#pragma mark - SCSCallHandler Methods

- (void)prepareToBecomeActive{

    [super prepareToBecomeActive];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(remoteControlReceived)
                                                 name:kSCPRemoteControlClickedNotification
                                               object:nil];

}

- (void)prepareToBecomeInactive{

    [super prepareToBecomeInactive];
    
    [self stopTimer];
    
    [self stopLedTimer];
       
    [self disableProximitySensor];
    
    [self resignFirstResponder];
    
    [self unRegisterForNotifications];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSCPRemoteControlClickedNotification
                                                  object:nil];
}

-(void) validateMicrophoneAccess
{
    if ([SystemPermissionManager hasPermission:SystemPermission_Microphone])
        [_microphoneAccessView setHidden:YES];
    else {
        [_microphoneAccessView setHidden:NO];
        _microphoneAccessLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Go to the settings and turn on microphone access so %@ can hear you", nil),[_call getName]];
    }
}


#pragma mark - Call Setter

- (void)setCall:(SCPCall *)aCall {
    
    BOOL viewIsLoaded = self.isViewLoaded;
    
    _call.userDidPressVideoButton = NO;//make sure that we do not have old state here
    _call = aCall;
    
    if(self.dialPadVC)
       [self.dialPadVC setCall:_call];
    
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
    
    SCPCall *c = (SCPCall*)notification.userInfo[kSCPCallDictionaryKey];
    
    if(c != _call)
        return;

    _call = c;

    if(self.dialPadVC)
        [self.dialPadVC setCall:_call];

    [self updateUIWithCall:c];
}

- (void)updateUIWithCall:(SCPCall *)aCall {

    if (NO == self.isViewLoaded)
        return;

    if (aCall.isInProgress) {
        if ([self dialPadIsVisible]) {
            [self dismissDialPadWithAnimation:NO];
        }
        
        [self updateContactVerifiedWithCall:aCall];
        
        [self showGeekStrip:NO animated:NO];
        
        [self shakeProfileView];

        [self enableNavButtonsView:NO];
        
        [self showInfoPanelAnimated:NO];
    }
    else {
        [self stopProfileViewShake];

        if (aCall.isEnded) {
            
            [self enableNavButtonsView:NO];
            
            [self updateUIForEndingCall:aCall];
            
            return;
        }
        else {
            
            [self startTimer];
            
            // Start LED timer
            [_geekView showAntenna:YES];
            [_geekView showLED:YES];
            if (_geekView.ledCanShow && (!_ledTimer || !_ledTimer.isValid)) {
                [self startLedTimer];
            }

            [self enableNavButtonsView:YES];
            
            [self showZRTPPanel];
        }
    }

    // Incoming/End buttons
    // Handle cases:
    // * The app was not active and not backgrounded, and user answered
    //   from notification banner. In this case, the incoming buttons
    //   could be displayed and the call is already answered.
    //
    // * With 2 active calls, end current call. The call property is
    //   reset with the last remaining call, but the end call workflow
    //   will have left the btEndCall hidden.

    if (aCall.isAnswered && (_isShowingIncomingCallButtons || _btEndCall.hidden)) {
        [self updateButtonsToEndCallStateWithAnimation:NO];
    }
    else if ([aCall isIncomingRinging] && !_isShowingIncomingCallButtons) {
        [self updateButtonsForIncomingCall];
    }

    // Always update label with call info -
    // showInfoPanelAnimated: manages showing/hiding call info
    _lbCallInfo.text = aCall.bufMsg; // "Ringing", "Incoming Call", etc.
    _lbCallInfo.numberOfLines = 2;
    _lbCallInfo.frame = CGRectMake(_lbCallInfo.frame.origin.x,_lbCallInfo.frame.origin.x,_lbCallInfo.frame.size.width,100);

    // Update header view elements
    [self updateHeaderViewWithCall:aCall];

    // Update ZRTP
    [self updateZRTPState:aCall];
   
    if(_call.hasSAS && _call.shouldShowVideoScreen && !_call.isEnded){
       [self showVideoScreen];
    }
    
    [self enableProximitySensor];
}

- (void)updateUIForEndingCall:(SCPCall *)aCall {

    if ([self dialPadIsVisible]) {
        // Dismiss without animation to avoid setting accessibility
        // focus on callInfo label at completion of animation.
        [self dismissDialPadWithAnimation:NO];
    }

    [self showInfoPanelAnimated:NO];
    
    NSString *msg = aCall.bufMsg;
    
    _lbCallInfo.text = msg;
    
    // Give VoiceOver a little time before announcing the 'Call ended' event
    // due to audio category changing.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,_lbCallInfo);
    });

    [self showGeekStrip:NO];
    
    _btAvatarVerify.hidden = YES;
    [_contactView showUnverified:NO];
    
    [self clearSecureLabels];
    [self clearSASLabel];
    
    [self enableNavButtonsView:NO];
    
    [self updateButtonsToEndCallStateWithAnimation:YES];
}


#pragma mark - Update ZRTP

- (void)updateZRTPUIWithNotification:(NSNotification *)notification {
    
    SCPCall *c = (SCPCall*)notification.userInfo[kSCPCallDictionaryKey];
    if(c != _call)return;
    [self updateZRTPState:c];
}

-(void)updateZRTPState:(SCPCall *)aCall {
    
    if (aCall.isEnded)
        return;

    if (_zrtpPanelView.isHidden)
        return;

    if (!aCall.isSASVerified && aCall.bufSAS.length) {
        [self showUnsecureViewWithCall:aCall];
    }
    else {
        [self showSecureViewWithCall:aCall];
    }
}

- (void)showSecureViewWithCall:(SCPCall *)aCall {
    
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
    }
    else {
        [self clearSecureLabels];
    }
    
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, _lbSecure);
}

- (void)showUnsecureViewWithCall:(SCPCall *)aCall {
    
    _secureSubView.hidden   = YES;
    _unSecureSubView.hidden = NO;

    _lbZRTP_peer.hidden     = YES;
    [self clearSecureLabels];
    
    // Avatar
    [self updateContactVerifiedWithCall:aCall];
    
    // SAS
    [self updateSASandVideoWithCall:aCall];
    
    NSString *words_chars = (aCall.bufSAS.length > 4) ? NSLocalizedString(@"words", nil) : NSLocalizedString(@"characters", nil);
    _lbUnSecure.text = [NSString stringWithFormat:NSLocalizedString(@"Compare the %@ below with partner", nil), words_chars];
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _btAvatarVerify);
//    });
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
       // this did not help, but why? [self enableNavButtonsView:YES];
        _btVideo.enabled = [self canEnableVideo];//videobutton relies on SAS
        [self updateVideoButtonAccessibility];
    }
    else {
        _btVideo.enabled = NO;
        [self updateVideoButtonAccessibility];
    }
    
    // Fade SAS phrase text per verified
    if (_call.isSASVerified) {
        _lbSAS.alpha = 0.35;
    } else {
        _lbSAS.alpha = 1.0;
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
    
    if (!_infoPanelView.isHidden)   _infoPanelView.hidden = YES;
    if (_zrtpPanelView.isHidden)    _zrtpPanelView.hidden = NO;
    if (_zrtpPanelView.alpha != 1.) _zrtpPanelView.alpha  = 1.0;
    
    if (!_call.isSASVerified && _call.bufSAS.length) {
        if (_unSecureSubView.isHidden || !_secureSubView.isHidden)
            [self showUnsecureViewWithCall:_call];
    }
    else {
        if (_secureSubView.isHidden || !_unSecureSubView.isHidden)
            [self showSecureViewWithCall:_call];
    }

}


#pragma mark - SAS Verify Alert

- (void)showSASVerifyDialog{
//    NSString *title = [NSString stringWithFormat:@"%s:\n\"%@\"\n\n%s",
//                       T_TR("Compare with partner"),
//                       _call.bufSAS,
//                       T_TR("Change ZRTP cache name (optional)")];
    
    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Compare with partner:\n\"%@\"\n\nEdit name (optional)", nil),_call.bufSAS];
    
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
    
    [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil)
                                           style:UIAlertActionStyleCancel
                                         handler:^(UIAlertAction *action){
                                             
                                             
                                         }]];
    
    [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Confirm", nil)
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action){
                                             
                                             UITextField *tf = ac.textFields[0];
                                             if(tf.text.length < 1)
                                                 tf.text = [_call getName];
                                             else
                                                 _call.zrtpPEER = tf.text;
                                             
                                             [SPCallManager setCacheName:tf.text call:_call];
                                             [SPCallManager setVerifyFlag:YES call:_call];
                                             [self updateZRTPState:_call]; // needed?? won't there be a zrtpUpdateNotif?
                                         }]];
    
    [self presentViewController:ac animated:YES completion:nil];
}


#pragma mark - Info Panel / Call Info

-(void)showInfoPanelAnimated:(BOOL)anim{
    
    if (!_infoPanelView.isHidden && _zrtpPanelView.isHidden)
        return;
    
    if(!anim){
        _infoPanelView.hidden = NO;
        _infoPanelView.alpha  = 1.0;
        _lbCallInfo.hidden    = NO;
        _lbCallInfo.alpha     = 1.0;
        _zrtpPanelView.hidden = YES;
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
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
//                         dispatch_async(dispatch_get_main_queue(), ^{
                             UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
//                         });
                     }];
}


// Header view contains
// - lbDstName, lbDst
// - server name (removed from IB)
// - geek strip elements
// - flag
// - callDurView, ivDurBg

- (void)updateHeaderViewWithCall:(SCPCall *)aCall {
        
    // Call duration label
    if (!aCall.isAnswered) {
        [self showCallDuration:NO animated:NO];
    }
    else {
        [self showCallDuration:YES animated:YES];
    }

    // destination name and destination number
    _lbDstName.text = [aCall getName];
    // dont repeat if destination name and destination are same
    NSString *displayName = aCall.displayNumber;
    _lbDst.text = [displayName isEqualToString: _lbDstName.text] ? @"" : displayName;

    // server name
    if(aCall.bufServName.length<1){
        // TODO: Set in SCPCallManager?
        aCall.bufServName = [Switchboard titleForAccount:aCall.pEng];
    }
//    _lbServer.text = aCall.bufServName;
    
    // update flag
    if (aCall.displayNumber && aCall.displayNumber.length > 0) {
        [self updateFlagImageWithNumber:aCall.displayNumber];
    }
}


#pragma mark - Call Duration

- (void)updateCallDuration {
    if (_callDurView.alpha == 0)
        return;
    [_callDurView updateDurationWithCall:_call];
}

- (void)showCallDuration:(BOOL)shouldShow animated:(BOOL)animated {
    [self fadeView:_callDurView fadeIn:shouldShow animated:animated];
}


#pragma mark - Geek Strip Methods

// Wired to btGeekStrip in IB
- (IBAction)handleGeekStripTap:(id)sender {
    // toggle
    BOOL shouldShow = ![self geekStripIsShowing];
    [self showGeekStrip:shouldShow];
}


// Default is animated
- (void)showGeekStrip:(BOOL)shouldShow {
    // Button should be hidden if "canShow" is false, to
    // hide button from accessibility.
    _btGeekStrip.hidden = ![_geekView geekStripCanShow];
    [self showGeekStrip:shouldShow animated:YES];
}

- (void)showGeekStrip:(BOOL)shouldShow animated:(BOOL)animated {
    if (!_geekView.geekStripCanShow)
        return;
    
    CGFloat stripW = _origGeekViewWidth;
    if (shouldShow) {
        stripW += _geekView.lbStrip.frame.size.width;
    }
    CGFloat leading = (shouldShow) ? 8.0 : _origDstNameLeading;
    
    if (!animated) {
        _geekView.lbStrip.hidden = !shouldShow;
        _geekViewWidthConstraint.constant = stripW;
        _dstNameLeadingConstraint.constant = leading;
        [_headerView layoutIfNeeded];
        return;
    }

    // Pop the label back 1st with no animation -
    // shortening the label with animation results in choppy resizing
    // of font.
    _dstNameLeadingConstraint.constant = leading;
    [_headerView layoutIfNeeded];

    if (shouldShow) {
        [_geekView updateGeekStripWithCall:_call];
    }
        
    [UIView animateWithDuration:0.35 delay:0
         usingSpringWithDamping:.6 initialSpringVelocity:50
                        options:0
                     animations:^{
                         _geekViewWidthConstraint.constant = stripW;
                         [_headerView layoutIfNeeded];
                         _geekView.lbStrip.hidden = !shouldShow;
                         
                     } completion:^(BOOL finished) {
                         [_geekView updateGeekDisplayState:shouldShow];
                         if ([self geekStripIsShowing]) {
                             UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification,_geekView);
                         }
                     }];
}

- (BOOL)geekStripIsShowing {
    return _geekViewWidthConstraint.constant > _origGeekViewWidth;
}

#pragma mark - Flag

- (void)updateFlagImageWithNumber:(NSString *)nr {
    
    [[SCSPhoneHelper sharedPhoneHelper] getCountryFlagName:nr
                                         completitionBlock:^(NSDictionary *countryData){
                                             _ivFlag.hidden = NO;
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

-(void) recentObjectUpdated:(NSNotification *) note
{
    RecentObject *updatedRecent = (RecentObject *) [note.userInfo objectForKey:kSCPRecentObjectDictionaryKey];
    
    if (!updatedRecent)
        return;
    
    NSString *thisUsername = [[ChatUtilities utilitiesInstance] removePeerInfo:_call.bufPeer lowerCase:YES];
    NSString *updatedUsername = [[ChatUtilities utilitiesInstance] removePeerInfo:updatedRecent.contactName lowerCase:YES];
    
    if (![updatedUsername isEqualToString:thisUsername])
        return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self setBackgroundAndAvatarFromRecent:updatedRecent];
        [self requestAddressBookAvatarForRecent:updatedRecent];
        [self updateUIWithCall:_call];
    });
}

- (void)requestAddressBookAvatarForRecent:(RecentObject *)recentObject {
    
    if(!recentObject)
        return;
    
    if(!recentObject.abContact)
        return;
    
    if(recentObject.abContact.contactImageIsCached)
        return;
    
    if(recentObject.abContact.cachedContactImage)
        return;
    
    __weak CallScreenVC *weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [recentObject.abContact requestContactImageSynchronously];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            __strong CallScreenVC *strongSelf = weakSelf;
            
            if(!strongSelf)
                return;

            [strongSelf setBackgroundAndAvatarFromRecent:recentObject];
        });
    });
}

- (void)fetchPeerAvatarInBackground {
    // getOrCreateRecentObjectWithContactName crashed with nil [something]...
    // nil contactName? nil call?

    if (!_call || _call.isEnded) { return; }
    
    NSString *contactName = (_call.bufPeer) ?: _call.bufDialed;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        RecentObject *recentObject = [[DBManager dBManagerInstance] getOrCreateRecentObjectWithContactName:contactName];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setBackgroundAndAvatarFromRecent:recentObject];
        });
    });
}

-(void) setAvatarImage:(UIImage *) avatarImage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [_contactView setImage:avatarImage];
        _ivBackgroundAvatar.image = avatarImage;
        _ivBackgroundAvatar.layer.masksToBounds = YES;
    });
}

-(void)setBackgroundAndAvatarFromRecent:(RecentObject *) thisRecent
{
    UIImage *callImage = [AvatarManager avatarImageForConversationObject:thisRecent size:eAvatarSizeFull];

    if(callImage)
    {
        [self setAvatarImage:callImage];
        [_contactView showWhiteBorder];
    }
    
    
    BOOL shouldShow = [self shouldShowAvatarUnverified];
    [_contactView showUnverified:shouldShow];
    _btAvatarVerify.hidden = !shouldShow;
}

- (void)updateContactVerifiedWithCall:(SCPCall*)aCall {

    if (!_viewDidAppearHasFired)
        return;
    
    if ([self shouldShowAvatarUnverified]) {
        
        if (_btAvatarVerify.hidden)
            _btAvatarVerify.hidden = NO;

        if (!_contactView.lbVerify)
            [_contactView showUnverified:YES];
        
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _contactView.lbVerify);
    }
    else {
        if (!_btAvatarVerify.hidden)
            _btAvatarVerify.hidden = YES;

        if (_contactView.lbVerify)
            [_contactView showUnverified:NO];
    }
}

- (BOOL)shouldShowAvatarUnverified {
    return (_call.hasSAS && !_call.isSASVerified);
}


#pragma mark - Volume Warning

- (void)updateVolumeWarning {
   self.lblVolumeWarning.hidden = ![SPAudioManager playbackVolumeIsVeryLow];
}

#pragma mark - Nav Button Methods

// For incoming call to prevent navigation before answering/declining
- (void)enableNavButtonsView:(BOOL)shouldEnable {
    
    _navButtonsView.alpha = (shouldEnable) ? 1 : 0.5;
    [_navButtonsGroup enumerateObjectsUsingBlock:^(UIButton *btn, NSUInteger idx, BOOL *stop) {
        // We need to have the speaker and mute buttons enabled for outgoing calls in ringing state
        if (btn == _btSpeaker || btn == _btMute) {
            btn.enabled = (!_call.isAnswered ? !_call.isIncoming : YES);
        }
        else if (btn == _btVideo) {
            btn.enabled = (shouldEnable) ? [self canEnableVideo] : NO;
            [self updateVideoButtonAccessibility];
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
   [self showSASVerifyDialog];

}

- (IBAction)handleMuteTap:(id)sender {
    
    [SPCallManager onMuteCall:_call
                        muted:![SPAudioManager micIsMuted]];
}

- (IBAction)handleInCallDialPadTap:(id)sender {
    [self presentDialPad];
}

- (IBAction)handleChatTap:(id)sender {
    if ([_navDelegate respondsToSelector:@selector(switchToChatWithCall:)])
        [_navDelegate switchToChatWithCall:self.call];
}

- (IBAction)handleAudioTap:(id)sender {
   
    [SPAudioManager routeAudioToLoudspeaker:!SPAudioManager.loudspeakerIsOn
      shouldCheckHeadphonesOrBluetoothFirst:NO];
}

- (IBAction)handleConversationsTap:(id)sender {
    if ([_navDelegate respondsToSelector:@selector(switchToConversationsWithCall:)])
        [_navDelegate switchToConversationsWithCall:self.call];
}

-(void)showVideoScreen{
    if ([_navDelegate respondsToSelector:@selector(switchToVideo:call:)])
        [_navDelegate switchToVideo:nil call:self.call];
}

- (IBAction)handleVideoTap:(id)sender {
    
    if([_call.callType isEqualToString:@"audio video"])
        return;
    
   [SPCallManager switchToVideo:_call on:YES];
   [self showVideoScreen];
}

- (IBAction)handleCallManagerTap:(id)sender {
    if ([_navDelegate respondsToSelector:@selector(switchToConference:call:)])
        [_navDelegate switchToConference:nil call:self.call];
}

- (void)updateMuteButtonImage {
    BOOL isMuted =[SPAudioManager micIsMuted];
    // selected state image/bgImage set in IB > Attribs > ConfigState
    self.btMute.selected = isMuted;
    [self updateMuteButtonAccessibility];
}

- (BOOL)canEnableVideo {
    BOOL hasPermission = [[UserService currentUser] hasPermission:UserPermission_InitiateVideo];
    return (_call.bufSAS.length>0 && hasPermission);
}


#pragma mark - Answer Call

- (IBAction)handleAnswerCallTap:(id)sender {

    [SPCallManager answerCall:_call];
    
    [self handleAnswerCallAction:nil];
}

- (void)handleAnswerCallAction:(NSNotification *)notification {
    
    dispatch_async(dispatch_get_main_queue(), ^{

        if(notification)
            [self updateCallUIWithNotification:notification];
        
        [self stopProfileViewShake];
        
        if ([SPCallManager activeCallCount] > 0)
            [self updateButtonsToEndCallStateWithAnimation:YES];
    });
}

-(void) shakeProfileView
{
    
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
    _contactView.transform = CGAffineTransformIdentity;
    [_contactView.layer removeAllAnimations];
}

- (BOOL)profileIsShaking {
    return (_contactView.layer.animationKeys.count > 0);
}

#pragma mark - End Call

/**
 * Terminates the call.
 *
 * Note that we must update the call info label manually here because
 * we will not get a callStateDidUpdate notification after this
 * terminating event.
 */
- (IBAction)handleEndOrDeclineCallTap:(id)sender {

    [SPCallManager terminateCall:_call];
    [SPAudioManager playSound:@"Telephone_hangup"
                       ofType:@"mp3"
                      vibrate:NO];

    [self updateButtonsToEndCallStateWithAnimation:YES];
}


#pragma mark - Call Buttons Animations

- (void)updateButtonsToEndCallStateWithAnimation:(BOOL)animated {
    [self updateButtonsToEndCallStateWithAnimation:animated delay:0];
}
- (void)updateButtonsToEndCallStateWithAnimation:(BOOL)animated delay:(NSTimeInterval)delay {

    if ([self dialPadIsVisible]) {
        [self dismissDialPadWithAnimation:NO];
    }

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
    
    if (_isShowingIncomingCallButtons)
        return;

    _isShowingIncomingCallButtons=YES;

    UIImage *img = (_call.hasVideo) ? [UIImage imageNamed:@"ico_camera.png"] : nil;
    [_btAnswer setImage:img forState:UIControlStateNormal];

    self.view.userInteractionEnabled = NO;
    [self adjustButtonsExpand:NO animated:YES];
    [UIView animateWithDuration:kViewAnimationDuration animations:^{
        _btAnswer.hidden       = NO;
        _btEndCall.hidden      = NO;
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

    if (animated) {
            [UIView animateWithDuration:0.1f delay:0
                                options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                                 
                                 _endBTCenterXconstraint.constant = (expand) ? 0 : _origEndCallBTCenterX;
                                 [_btEndCall.superview layoutIfNeeded];
                                 
                             }
                             completion:nil];
        }
        else {
            
            _endBTCenterXconstraint.constant = (expand) ? 0 : _origEndCallBTCenterX;
            [_btEndCall.superview layoutIfNeeded];
        }
}


#pragma mark - DialPad Methods

- (void)presentDialPad {
    
    [SPCallManager initDTMF];
    
    _btHideKeypad.hidden = NO;
    _endBTCenterXconstraint.constant = _origEndCallBTCenterX;
    [_btEndCall.superview layoutIfNeeded];
    
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Phone" bundle:nil];
    SCSCallScreenDialPadVC *dpvc = [sb instantiateViewControllerWithIdentifier:@"SCSCallScreenDialPadVC"];
    [self addChildViewController:dpvc];
    
    if(_call)
        [dpvc setCall:_call];
    
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
                        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, dpvc.textfield);
                    }];
}

- (IBAction)dismissDialPad {
    [self dismissDialPadWithAnimation:YES];
}
- (void)dismissDialPadWithAnimation:(BOOL)animated {
    _endBTCenterXconstraint.constant = 0;
    [_btEndCall.superview layoutIfNeeded];
    
    self.dialPadVC.textfield.text = nil;
    
    _callScreenContainer.accessibilityElementsHidden = NO;
    
    if (!animated) {
        _btHideKeypad.hidden = YES;
        SCSCallScreenDialPadVC *dpvc = [self dialPadVC];
        [dpvc willMoveToParentViewController:nil];
        [dpvc.view removeFromSuperview];
        [dpvc removeFromParentViewController];
        return;
    }
    
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
                        if (_call.isEnded) {
                            UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, _lbCallInfo);
                        } else {
                            UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _lbDstName);
                        }
                    }];
}

- (SCSCallScreenDialPadVC *)dialPadVC {
    return [self.childViewControllers firstObject];
}

- (BOOL)dialPadIsVisible {
    return [self.childViewControllers containsObject:self.dialPadVC];
}


#pragma mark - Timers

-(void)startTimer{

    if (_callDurTimer)
        [_callDurTimer invalidate];
    
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
    [_geekView updateGeekStripWithCall:_call];
    [_geekView updateAntennaWithCall:_call];
}

-(void)startLedTimer{
    
    if (_ledTimer)
        [_ledTimer invalidate];
    
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
    [_geekView updateLED];
}


#pragma mark - Remote Control

- (void)remoteControlReceived {
    
    if (_call.isIncomingRinging)
        [self handleAnswerCallTap:nil];
    else if (!_call.isEnded)
        [self handleEndOrDeclineCallTap:nil];
}


#pragma mark - Audio Notification Handler

- (void)updateAudioNotification:(NSNotification *)notification {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if([SPAudioManager isHeadphoneOrBluetooth])
            [self disableProximitySensor];
        else
            [self enableProximitySensor];
        
        UIImage *backgroundImage = [UIImage imageNamed:([SPAudioManager loudspeakerIsOn] ? @"bt_dial_down.png" : @"bt_dial_up.png")];
        UIImage *buttonImage = [UIImage imageNamed:([SPAudioManager bluetoothIsUsed] ? @"ico_speaker_bt.png" : @"ico_speaker.png")];
        
        [_btSpeaker setImage:buttonImage
                    forState:UIControlStateNormal];
        
        [_btSpeaker setBackgroundImage:backgroundImage
                              forState:UIControlStateNormal];
        
        [self updateSpeakerButtonAccessibility];        
    });
}

- (void)volumeChanged:(NSNotification *)notification {

    [self updateVolumeWarning];
}

- (void)muteChanged:(NSNotification *)notification {
    
    [self updateMuteButtonImage];
}

#pragma mark - Notification Registration

- (void)registerForNotifications {
    NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
    
    [notifCenter addObserver:self selector:@selector(handleAnswerCallAction:)
                        name:kSCPCallStateCallAnsweredByLocalNotification object:nil];
    
    [notifCenter addObserver:self selector:@selector(updateCallUIWithNotification:)
                        name:kSCPCallStateDidChangeNotification object:nil];
    
    [notifCenter addObserver:self selector:@selector(updateZRTPUIWithNotification:)
                        name:kSCPZRTPDidUpdateNotification object:nil];
    
    [notifCenter addObserver:self selector:@selector(updateAudioNotification:)
                        name:kSCSAudioStateDidChange object:nil];
    
    [notifCenter addObserver:self selector:@selector(recentObjectUpdated:)
                        name:kSCSRecentObjectUpdatedNotification object:nil];
    
    [notifCenter addObserver:self selector:@selector(volumeChanged:)
                        name:KSCSAudioOutputVolumeDidChange object:nil];
    
    [notifCenter addObserver:self selector:@selector(muteChanged:)
                        name:kSCSAudioMuteMicDidChange object:nil];
}

- (void)unRegisterForNotifications {
    NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
    [notifCenter removeObserver:self name:kSCPCallStateCallAnsweredByLocalNotification object:nil];
    [notifCenter removeObserver:self name:kSCPCallStateDidChangeNotification object:nil];
    [notifCenter removeObserver:self name:kSCPZRTPDidUpdateNotification object:nil];
    [notifCenter removeObserver:self name:kSCSAudioStateDidChange object:nil];
    [notifCenter removeObserver:self name:kSCSRecentObjectUpdatedNotification object:nil];
    [notifCenter removeObserver:self name:KSCSAudioOutputVolumeDidChange object:nil];
    [notifCenter removeObserver:self name:kSCSAudioMuteMicDidChange object:nil];
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


#pragma mark - Accessibility

- (void)setupAccessibility {
    _headerView.accessibilityElements = @[_lbDstName,_lbDst,_geekView,_btGeekStrip,_ivFlag,_callDurView];
//    _geekView.isAccessibilityElement = [self geekStripIsShowing];
    
    if (![SPAudioManager loudspeakerIsOn] && ![SPAudioManager isHeadphoneOrBluetooth]) {
        
        [SPAudioManager routeAudioToLoudspeaker:YES
          shouldCheckHeadphonesOrBluetoothFirst:NO];

        _btSpeaker.highlighted = ([SPAudioManager loudspeakerIsOn] && ![SPAudioManager isHeadphoneOrBluetooth]);
    }
    [self updateMuteButtonAccessibility];
    [self updateSpeakerButtonAccessibility];
    [self updateVideoButtonAccessibility];
}

// Magic Tap
- (BOOL)accessibilityPerformMagicTap {
    
    if (_call.isIncomingRinging) {
        [self handleAnswerCallTap:nil];
        return YES;
    }
    else if (!_call.isEnded) {
        [self handleEndOrDeclineCallTap:nil];
        return YES;
    }

    return YES;
}

- (void)updateMuteButtonAccessibility {
    BOOL isMuted = [SPAudioManager micIsMuted];
    self.btMute.accessibilityLabel = (isMuted) ? NSLocalizedString(@"Unmute", nil) : NSLocalizedString(@"Mute", nil);
}

- (void)updateSpeakerButtonAccessibility {
    NSString *on  = NSLocalizedString(@"speaker selected", @"speaker selected");
    NSString *off = NSLocalizedString(@"speaker", @"speaker");
    _btSpeaker.accessibilityLabel = [SPAudioManager loudspeakerIsOn] ? on : off;
}

- (void)updateVideoButtonAccessibility {
    NSString *lbHint = @"";
    BOOL hasPermission = [[UserService currentUser] hasPermission:UserPermission_InitiateVideo];
    if (!hasPermission) {
        lbHint = NSLocalizedString(@"Video for this account is disabled", nil);
    } else if (_call.bufSAS.length < 1) {
        lbHint = NSLocalizedString(@"Secure connection required", nil);
    }
    _btVideo.accessibilityHint  = lbHint;
    
    if(_btVideo.enabled && _call.hasQueuedVideoRequest) {
        
        [_call setHasQueuedVideoRequest:NO];
        
        [self handleVideoTap:nil];
    }
}


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

-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [_contactView invalidateWhiteCircle];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [_contactView setNeedsDisplay];
    });
}

#pragma mark - Proximity sensor

- (void)enableProximitySensor {
    
    if([[UIDevice currentDevice] isProximityMonitoringEnabled])
        return;
    
    if(!_call)
        return;
    
    // Do not enable proximity sensor for incoming calls
    // that haven't been answered yet
    if(_call.isIncoming && !_call.isAnswered)
        return;
        
    if([SPAudioManager isHeadphoneOrBluetooth])
        return;
    
    UIDevice *device = [UIDevice currentDevice];
    device.proximityMonitoringEnabled = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(proximityStateChanged)
                                                 name:UIDeviceProximityStateDidChangeNotification
                                               object:nil];
}

- (void)disableProximitySensor {
    
    if(![[UIDevice currentDevice] isProximityMonitoringEnabled])
        return;
    
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceProximityStateDidChangeNotification
                                                  object:nil];
}
                                        
- (void)proximityStateChanged {
    
    if([SPAudioManager isHeadphoneOrBluetooth])
        return;
    
    if(!UIAccessibilityIsVoiceOverRunning())
        return;
    
    // If device is not close to the user, focus on the caller name
    if(![UIDevice currentDevice].proximityState)
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.lbDstName);

    // Switch the loudspeaker depending on the proximity status
    [SPAudioManager routeAudioToLoudspeaker:![UIDevice currentDevice].proximityState
      shouldCheckHeadphonesOrBluetoothFirst:NO];
}

@end
