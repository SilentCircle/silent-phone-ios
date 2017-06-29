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
//  SCSConferenceCVCell.m
//  SPi3
//
//  Created by Eric Turner on 11/5/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import "SCSConferenceCVCell.h"

#import "ChatUtilities.h"
#import "DBManager.h"
#import "RecentObject.h"
#import "SCPCall.h"
#import "SCSCallDurationView.h"
#import "Silent_Phone-Swift.h"
#import "SCSAvatarManager.h"

static NSString * const kSCSConferenceCVCell_ID = @"SCSConferenceCVCell_ID";


@interface SCSConferenceCVCell ()
@property (strong, nonatomic) NSCharacterSet *lettersSet;
@end

@implementation SCSConferenceCVCell
{
    UIColor *_onHoldBgColor;
    UIColor *_selectedBgColor;
}



+ (NSString *)reuseId {
    return kSCSConferenceCVCell_ID;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    _lettersSet = [NSCharacterSet letterCharacterSet];
    
    [self clearLabelsText];
    
    _lbAvatarVerify.hidden    = YES;
    self.contactView.initials = @"";
    
    _ivVerified.hidden  = YES;
    
    [_callDurView clear];
    _callDurView.hidden = YES;
    
    // We display call states with backgroundView.backgroundColor
    // changes. The bgColor ivars are to avoid the call to the UIColor
    // constructor each time, which might not be a big deal.
    
    self.backgroundView = [[UIView alloc] init];
    self.backgroundView.backgroundColor = [UIColor clearColor];
    self.selectedBackgroundView = nil;
    _selectedBgColor = [[UIColor blueColor] colorWithAlphaComponent:0.5];
    _onHoldBgColor   = [[UIColor grayColor] colorWithAlphaComponent:0.5];
}

- (void)clearLabelsText {
    _lbDstName.text     = @"";
    _lbDst.text         = @"";
    _lbSecure.text      = @"";
    _lbSecureSmall.text = @"";
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
    
    if (_call.isAnswered && _callDurView.isHidden) {
        _callDurView.hidden = NO;
    }
    
    // show unsecure
    if (_call.isAnswered && !_call.isEnded && _call.hasSAS && !_call.isSASVerified) {
        _lbAvatarVerify.hidden = NO;
        [self maskContactView];
    } else {
        _lbAvatarVerify.hidden = YES;
        [self unmaskContactView];
    }
    
    [self updateSecurityLabels];
    _lbSAS.text = (_call.hasSAS) ? _call.bufSAS : @"";
    
    [self updateCallButtons];
    
    [self updateBackgroundView];
}

- (void)updateUIForEndingCall {
    NSLog(@"%s\n  --- CALL ENDED: bufMsg: %@ ---", __PRETTY_FUNCTION__, _call.bufMsg);
    
    NSString *msg = _call.bufMsg;
    _lbSecure.text = msg;
    
    _lbAvatarVerify.hidden = YES;
    [self unmaskContactView];
    
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
    if (!_call.isEnded) {
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
//        NSLog(@"%s\n [contact substringToIndex:1]: %@", __PRETTY_FUNCTION__, initials);
    }
    return initials;
}

- (void)fetchPeerAvatarInBackground {
    
    // getOrCreateRecentObjectWithContactName crashed with nil [something]...
    // nil contactName? nil call?
    
    if (!_call || _call.isEnded) { return; }
    
    NSString *contactName = [self contactName];
    int callId = _call.iCallId;
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        RecentObject *ro = [[DBManager dBManagerInstance] getOrCreateRecentObjectWithContactName:contactName];
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        int cId = callId;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"\n    --- fetchPeerAvatarInBackground: returned ---");
            
            // ensure this cell displays the same call as when invoked
            if (!_call || cId != _call.iCallId) {
                
                // call the outer enclosing method again?
                return;
            }
            UIImage *avImg = [AvatarManager avatarImageForConversationObject:ro size:eAvatarSizeFull];
            if (avImg)
            {
                strongSelf.contactImage = avImg;
            } else
            {
                [strongSelf.contactView showDefaultContactColorWithContactName:contactName];
                NSString *initials = [[ChatUtilities utilitiesInstance] getInitialsForUserName:[strongSelf contactName]];
                strongSelf.contactView.initials = initials;
            }
            NSString *name = @"contact";
            if (_lbDstName.text && _lbDstName.text.length) name = _lbDstName.text;
            strongSelf.contactView.accessibilityLabel = [NSString stringWithFormat:@"%@ image", name];
        });
    });
}

- (NSString *)contactName {
    return (_call.bufPeer) ?: _call.bufDialed;
}

//TODO: masked contactView
- (void)maskContactView {
    if (self.contactView.alpha > 0.25)
        self.contactView.alpha = 0.25;
}

- (void)unmaskContactView {
    if (self.contactView.alpha != 1.0)
        self.contactView.alpha = 1.0;
}


#pragma mark - Call Button Methods

/**
 * Updates show/hide status of answer/end call buttons, based on
 * call state.
 *
 * Note that this implementation for the conference collectionView cell
 * differs from the tableView cell because the layouts differ. In this
 * case we do not have the extra "bt/ivIncomingEndCall" properties,
 * because the collectionView layout supports showing both buttons
 * simultaneously.
 */
- (void)updateCallButtons {
    if (_call.isEnded) {
        _btAnswerCall.hidden      = YES;
        _ivAnswerCall.hidden      = YES;
        _btEndCall.hidden         = YES;
        _ivEndCall.hidden         = YES;
    }
    else if (_call.isIncomingRinging) {
        _btAnswerCall.hidden      = NO;
        _ivAnswerCall.hidden      = NO;
        _btEndCall.hidden         = NO;
        _ivEndCall.hidden         = NO;
    }
    // outgoing unanswered
    else if (!_call.isAnswered) {
        _btAnswerCall.hidden      = YES;
        _ivAnswerCall.hidden      = YES;
        _btEndCall.hidden         = NO;
        _ivEndCall.hidden         = NO;
    }
    else {
        _btAnswerCall.hidden      = YES;
        _ivAnswerCall.hidden      = YES;
        _btEndCall.hidden         = NO;
        _ivEndCall.hidden         = NO;
    }
    
    NSString *txt = _lbDstName.text;
    NSString *peer = (txt && txt.length) ? txt : _lbDst.text;
    _btAnswerCall.accessibilityLabel  = [NSString stringWithFormat:NSLocalizedString(@"answer call from %@", nil), peer];
    if (!_call.isAnswered) {
        _btEndCall.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"decline call from %@", nil), peer];
    } else if (!_call.isEnded) {
        _btEndCall.accessibilityLabel = [NSString stringWithFormat:NSLocalizedString(@"end call with %@", nil), peer];
    } else {
        _btEndCall.accessibilityLabel = nil;
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


#pragma mark - Background Views

// Note that with this implementation, the value of the selected
// argument doesn't really matter. The tableView invokes this method
// under the hood with "false" often. We evaluate the call state of the
// call property and set the backgroundView.bgColor accordingly.
// No animation.
- (void)setSelected:(BOOL)selected {
//    NSLog(@"%s CALLED WITH SELECTED %@ -- NOT CALL SUPER",
//          __PRETTY_FUNCTION__, (selected)?@"YES":@"NO");
    
    // Avoid calling super
    
    if (_call.isEnded) {
        return;
    }
    
    if (_call.isOnHold && !_isReordering) {
//        NSLog(@"%s - CALL IS on hold -- bgColor = GRAY", __PRETTY_FUNCTION__);
        self.backgroundView.backgroundColor = _onHoldBgColor;
    }
    else {
//        NSLog(@"%s - CALL IS NOT on hold -- bgColor = BLUE", __PRETTY_FUNCTION__);
        self.backgroundView.backgroundColor = _selectedBgColor;
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
//    NSLog(@"%s -- NOT CALLING SUPER", __PRETTY_FUNCTION__);
    // Avoid calling super
}

- (UITableViewCellSelectionStyle)selectionStyle {
//    NSLog(@"%s - return NONE", __PRETTY_FUNCTION__);
    return UITableViewCellSelectionStyleNone;
}

- (void)setHighlighted:(BOOL)highlighted {
//    NSLog(@"%s", __PRETTY_FUNCTION__);
    // Avoid calling super
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
//    NSLog(@"%s", __PRETTY_FUNCTION__);
    // Avoid calling super
}

- (void)updateBackgroundView {
    
    if (_call.isOnHold || _call.isEnded) {
//        NSLog(@"%s - CALL IS on hold -- SET SELECTED NO", __PRETTY_FUNCTION__);
        self.selected = NO;
    }
    else {
//        NSLog(@"%s - CALL IS NOT on hold -- SET SELECTED YES", __PRETTY_FUNCTION__);
        self.selected = YES;
    }
}

@end
