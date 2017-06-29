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
//  SCSConferenceTVCell.m
//  SPi3
//
//  Created by Eric Turner on 11/14/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import "SCSConferenceTVCell.h"

#import "ChatUtilities.h"
#import "DBManager.h"
#import "RecentObject.h"
#import "SCPCall.h"
#import "SCSCallDurationView.h"
#import "Silent_Phone-Swift.h"
#import "SCSFeatures.h"
#import "SCSAvatarManager.h"
//Categories
#import "UIColor+ApplicationColors.h"


static NSString * const kSCSConferenceTVCell_ID = @"SCSConferenceTVCell_ID";

@interface SCSConferenceTVCell ()
@property (strong, nonatomic) NSCharacterSet *lettersSet;
@end


@implementation SCSConferenceTVCell
{
    UIColor *_onHoldBgColor;
    UIColor *_selectedBgColor;
    UIColor *_unVerifiedBgColor;
    
    UIImageView *_reorderCntrlImgView;
}

+ (NSString *)reuseId {
    return kSCSConferenceTVCell_ID;
}

- (void)awakeFromNib {
    [super awakeFromNib];

    _lettersSet = [NSCharacterSet letterCharacterSet];

    [self clearLabelsText];
    
    _ivVerified.hidden  = YES;
    
    [_callDurView clear];
    _callDurView.hidden = YES;

    
    CALayer *lyr = _sasView.layer;
    lyr.cornerRadius = 8.;
    
    self.backgroundView = [[UIView alloc] init];
    self.selectedBackgroundView = nil;
    
    // We display call states with backgroundView.backgroundColor
    // changes. The bgColor ivars are to avoid the call to the UIColor
    // constructor each time.
    _selectedBgColor   = [UIColor selectedConfBgColor];
    _onHoldBgColor     = [UIColor onHoldConfBgColor];
    _unVerifiedBgColor = [UIColor unverifiedConfBgColor];
    
}

- (void)clearLabelsText {
    _lbDstName.text     = @"";
    _lbDst.text         = @"";
    _lbSecure.text      = @"";
//    _lbSecureSmall.text = @"";
    _lbSAS.text         = @"";
}

- (void)setCall:(SCPCall *)aCall {
    
    _call = aCall;
    
    if (_call.isEnded) {
        [self updateUIForEndingCall];
        return;
    }

    [self fetchPeerAvatarInBackground];
    
    _lbDstName.text = [_call getName];
    // dont repeat if destination name and destination are same
    NSString *displayName = aCall.displayNumber;
    _lbDst.text = [displayName isEqualToString: _lbDstName.text] ? @"" : displayName;
    
    if (_call.isInProgress) {
        _callDurView.hidden = YES;
    }
    else if (_call.isAnswered && _callDurView.isHidden) {
        _callDurView.hidden = NO;
    }
    
    // show unsecure
    if (_call.isAnswered && !_call.isEnded && _call.hasSAS && !_call.isSASVerified) {
        [self showContactUnverified:YES];
    } else {
        [self showContactUnverified:NO];
    }

    if (aCall.isSASVerified) {
        _ivVerified.hidden = NO;
    } else {
        _ivVerified.hidden = YES;
    }
    
    [self updateSecurityLabels];
    _lbSAS.text = (_call.hasSAS) ? _call.bufSAS : @"";
    
    [self updateCallButtons];
    
    [self updateBackgroundView];
}

- (void)updateUIForEndingCall {

    NSString *msg = _call.bufMsg;
    _lbSecure.text = msg;
    
    [self showContactUnverified:NO];
    
    self.backgroundView.backgroundColor = [UIColor clearColor];
    self.contentView.alpha = 0.5; //??
}


- (void)updateSecurityLabels {
    UILabel *tmpLb = [[UILabel alloc] init];
    (void)[_call setSecurityLabel:tmpLb desc:nil withBackgroundView:nil];
    _lbSecure.text = tmpLb.text;
    _lbSecure.textColor = tmpLb.textColor;
}

- (void)updateDuration {
    if (!_call.isEnded && _call.isAnswered) {
        [_callDurView updateDurationWithCall:_call];
    }
}


// not used in favor of utilities.getInitialsForUserName:
- (NSString*)initialsFromName:(NSString*)aName {
    NSString *initials = @"?";
    aName = [aName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if (aName.length >= 2 && [_lettersSet characterIsMember:[aName characterAtIndex:0]]) {
        NSArray *names = [aName componentsSeparatedByString:@" "];
        if (names.count > 1) {
            NSString *first = [NSString stringWithFormat:@"%c", [names[0] characterAtIndex:0]];
            NSString *last  = [NSString stringWithFormat:@"%c", [names[1] characterAtIndex:0]];
            initials = [NSString stringWithFormat:@"%@%@", first.uppercaseString, last.uppercaseString];
        } else {
            initials = [aName substringToIndex:2].uppercaseString;
        }
    }
    return initials;
}

- (void)fetchPeerAvatarInBackground {

    if (!_call || _call.isEnded) { return; }
    
    NSString *contactName = [self contactName];
    int callId = _call.iCallId;
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        RecentObject *ro = [[DBManager dBManagerInstance] getOrCreateRecentObjectWithContactName:contactName];
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        int cId = callId;
        
        dispatch_async(dispatch_get_main_queue(), ^{

            // ensure this cell displays the same call as when invoked
            if (!strongSelf.call || cId != strongSelf.call.iCallId) {

                // call the outer enclosing block again?
                return;
            }

            if ([[ChatUtilities utilitiesInstance] isNumber:ro.contactName])
            {
                [strongSelf.contactView showNumberContactImage];
                return;
            }
            
            UIImage *avImg = [AvatarManager avatarImageForConversationObject:ro size:eAvatarSizeFull];
            if (avImg)
            {
                strongSelf.contactImage = avImg;
            } else {
                [strongSelf.contactView showDefaultContactColorWithContactName:contactName];
                NSString *initials = [[ChatUtilities utilitiesInstance] getInitialsForUserName:[strongSelf contactName]];
                strongSelf.contactView.initials = initials;
            }
            
            [strongSelf.contactView showUnverified: [strongSelf shouldShowAvatarUnverified] ];
            
            NSString *name = @"contact";
            if (strongSelf.lbDstName.text && strongSelf.lbDstName.text.length) name = strongSelf.lbDstName.text;
            strongSelf.contactView.accessibilityLabel = [NSString stringWithFormat:@"%@ image", name];
            
#if HAS_DATA_RETENTION
            strongSelf.dataRetentionImageView.hidden = (!ro.drEnabled);
#else
            strongSelf.dataRetentionImageView.hidden = YES;
#endif // HAS_DATA_RETENTION
        });
    });
}

- (BOOL)shouldShowAvatarUnverified {
    return (_call.hasSAS && !_call.isSASVerified);
}

- (NSString *)contactName {
    return (_call.bufPeer) ?: _call.bufDialed;
}


#pragma mark - Call Button Methods

/**
 * Show and hide the end call, answer call, and incoming call buttons -
 * both end and answer call buttons - as appropriate for the self call 
 * instance state.
 *
 * The callButtonsView is a subview containing the btAnswerCall,
 * ivAnswerCall, btEndCall, and ivEndCall buttons and imageViews. This
 * subview is configured to be not hidden in the cell xib. The end call
 * and answer buttons are positioned in the exact same location in the
 * cell xib, with the end call button/image on top of the answer call 
 * button/image. Except for an incoming call, only
 *
 * The incomingCallButtonsView is a subview containing answer/end call
 * buttons and imageViews. It is hidden by default and unhidden f
 */
- (void)updateCallButtons {
    BOOL showIncomingButtons = (_call.isIncomingRinging);
    if (showIncomingButtons) {
        _incomingCallButtonsView.hidden = NO;
        _callButtonsView.hidden = YES;
    } else {
        _incomingCallButtonsView.hidden = YES;
        _callButtonsView.hidden = NO;
    }
    
    NSString *txt = _lbDstName.text;
    NSString *peer = (txt && txt.length) ? txt : _lbDst.text;
    NSString *ansTxt = [NSString stringWithFormat:NSLocalizedString(@"answer call from %@", nil), peer];
    _btAnswerCall.accessibilityLabel   = ansTxt;

    if (!_call.isAnswered) {
        NSString *declineTxt = [NSString stringWithFormat:NSLocalizedString(@"decline call from %@", nil), peer];
        _btDeclineCall.accessibilityLabel = declineTxt;
    } else if (!_call.isEnded) {
        _btEndCall.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"end call with %@", nil), peer];
    } else {
        _btEndCall.accessibilityLabel = nil;
        _btDeclineCall.accessibilityLabel = nil;
    }
}

- (IBAction)handleEndCall:(UIButton*)btn {
    if ([_delegate respondsToSelector:@selector(endCallButtonTappedInCell:)]) {
        [_delegate endCallButtonTappedInCell:self];
    }
}

- (IBAction)handleAnswerCall:(UIButton*)btn {
    if ([_delegate respondsToSelector:@selector(answerCallButtonTappedInCell:)]) {
        [_delegate answerCallButtonTappedInCell:self];
    }
}


#pragma mark - Label Text Colors

- (void)updateTextColorsWithSelected:(BOOL)isSelected {
    UIColor *contrast = (isSelected) ?  _onHoldBgColor : _selectedBgColor;
    _lbDst.textColor             = contrast;
    _lbDstName.textColor         = contrast;
    _callDurView.label.textColor = contrast;

    //------------------------------------------------------------------
    // SAS phrase/background
    //
    BOOL isVerified = (_call.hasSAS && _call.isSASVerified);
    if (isVerified) {
        _lbSAS.textColor         = _onHoldBgColor;
        _sasView.backgroundColor = [UIColor verifiedConfBgColor:isSelected];
    } else {
        _lbSAS.textColor         = _selectedBgColor;
        _sasView.backgroundColor = (_call.hasSAS) ? _unVerifiedBgColor : [UIColor clearColor];
    }
    // Fade SAS phrase text if selected and verified
    _lbSAS.alpha = (isSelected && isVerified) ? 0.5 : 1.;
    //------------------------------------------------------------------
}


#pragma mark - ReorderControl Hack Methods

- (void)configureReorderControl {
    UIImageView *imgView = [self reorderControlImageView];
    UIImage *image = imgView.image;
    imgView.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _reorderCntrlImgView = imgView;
}

- (void)updateReorderControlWithSelected:(BOOL)isSelected {
    UIColor *contrast = (isSelected) ?  _onHoldBgColor : _selectedBgColor;
    if (nil == _reorderCntrlImgView) {
        [self configureReorderControl];
    }
    _reorderCntrlImgView.tintColor = contrast;
}

// Hack: spelunk the view hierarchy to find the reorder control imageView
// NOTE: this is not an exposed control, so if Apple changes the class
// name or type, this hack will stop working.
// (Refactored from Rong Li's implementation)
- (UIImageView *)reorderControlImageView {    
    for (UIView *view in self.subviews){
        if([view isKindOfClass:NSClassFromString(@"UITableViewCellReorderControl")]){
            for (UIView *subView in view.subviews){
                if ([subView isKindOfClass:[UIImageView class]]){
                    return (UIImageView *)subView;
                }
            }
        }
    }
    return nil;
}


#pragma mark - Background Views

/**
 * Override the setter to handle cell display state relative to call state.
 *
 * This method will set a "highlighted" appearance with the backgroundView when
 * audio is being routed between the local user and the cell's call. So cells in
 * conference will all be highlighted when the local user is in the conference, 
 * but if the local user switches to (taps) a private call, only the private 
 * call cell will be highlighted, and audio for the local user will only be with
 * the private call, even though audio continues between conference users.
 *
 * Note that the value of the selected argument doesn't really matter in terms
 * of the background view appearance which reflects "selected/active" and 
 * "on hold" call states. The call state of the call property is evaluated in
 * this method and the backgroundView.bgColor is updated accordingly. 
 *
 * Note that the tableView invokes this method itself under the hood often. 
 * Therefore, we do not call super which does its own thing with the cell 
 * highlighted state.
 */
- (void)setSelected:(BOOL)selected {

    // Avoid calling super

    if (_call.isEnded) {
        DDLogVerbose(@"%s call:%@ ENDED. Return", __FUNCTION__, [_call getName]);
        return;
    }

    if ((_call.isOnHold && !_isReordering) || _call.isInProgress){
        DDLogVerbose(@"%s call:%@ SET ON HOLD BGCOLOR", __FUNCTION__, [_call getName]);
        self.backgroundView.backgroundColor = _onHoldBgColor;
        [self updateTextColorsWithSelected:NO];
        [self updateReorderControlWithSelected:NO];
    }
    else {
        DDLogVerbose(@"%s call:%@ SET SELECTED BGCOLOR", __FUNCTION__, [_call getName]);
        self.backgroundView.backgroundColor = _selectedBgColor;
        [self updateTextColorsWithSelected:YES];
        [self updateReorderControlWithSelected:YES];
    }
}

// Override to let setSelected handle display state
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:NO animated:NO];
}

// Override to let setSelected handle display state
- (UITableViewCellSelectionStyle)selectionStyle {
    return UITableViewCellSelectionStyleNone;
}

// Override to let setSelected handle display state
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:NO];
}

// Override to let setSelected handle display state
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:NO animated:NO];
}

/**
 * The normal cell "selected" state is overridden in this class to display as
 * "highlighted" if the call audio is routing to the user 
 *
 * The overridden cell selected property setter handles setting the background
 * view, which displays "highlighted/non-highlighted" background view relative
 * to the call state.
 */
- (void)updateBackgroundView {
    self.selected = NO;
}

@end
