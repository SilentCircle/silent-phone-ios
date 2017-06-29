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


#import <UIKit/UIKit.h>

@class BurnButton;
@class ChatObject;
@class LocationButton;
@class ChatBubbleTextView;
@class SCSContactView;

@protocol ChatBubbleCellDelegate;

@interface ChatBubbleCell : UITableViewCell<UITextViewDelegate>
@property (nonatomic, strong) BurnButton *burnImageButton;
@property (nonatomic, strong) BurnButton *burnInfoButton;
@property (nonatomic, strong, setter=setthisChatObject:) ChatObject *thisChatObject;
@property (weak, nonatomic) IBOutlet UIImageView *messageBackgroundView;
@property (weak, nonatomic) IBOutlet UILabel *groupSenderLabel;


@property (nonatomic, strong) UIView *callContainerView;

// error message properties
@property (weak, nonatomic) IBOutlet UILabel *errorLabel;


// call properties
@property (weak, nonatomic) IBOutlet UIImageView *callBackgroundImageView;
@property (weak, nonatomic) IBOutlet UILabel *callInfoLabel;
@property (weak, nonatomic) IBOutlet UIImageView *phoneIconImageView;
@property (weak, nonatomic) IBOutlet UILabel *callTimeStampLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *callBackgroundViewLeadingConstraint;

// group chat invite cell
@property (weak, nonatomic) IBOutlet UILabel *inviteLabel;



// text, attachment properties
@property (weak, nonatomic) IBOutlet LocationButton *locationButton;
@property (weak, nonatomic) IBOutlet LocationButton *locationButtonTouchArea;
@property (weak, nonatomic) IBOutlet UILabel *timeStampLabel;
@property (weak, nonatomic) IBOutlet UILabel *burnTimeLabel;
@property (weak, nonatomic) IBOutlet UIImageView *burnIconImageView;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet ChatBubbleTextView *messageTextView;


@property (weak, nonatomic) IBOutlet NSLayoutConstraint *messageTextViewWidthConstant;


@property (weak, nonatomic) IBOutlet UIImageView *messageImageView;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIImageView *playVideoImage;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;


@property (weak, nonatomic) IBOutlet BurnButton *burnButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *burnButtonWidthConstant;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *burnButtonHeightConstant;

// received message properties
@property (weak, nonatomic) IBOutlet SCSContactView *messageContactView;



@property (nonatomic, weak) id<ChatBubbleCellDelegate> bubbleCellDelegate;

@end

@protocol ChatBubbleCellDelegate <NSObject>

- (void)chatBubbleCellWasTapped:(ChatBubbleCell*)chatBubbleCell;
- (BOOL)chatBubbleCellWasDoubleTapped:(ChatBubbleCell*)chatBubbleCell;

// accessibility custom actions
-(void) accessibilityBurnMessage:(ChatBubbleCell*)chatBubbleCell;
-(void) accessibilityShowLocation:(ChatBubbleCell*)chatBubbleCell;
-(void) accessibilityInfo:(ChatBubbleCell*)chatBubbleCell;
-(void) accessibilityResend:(ChatBubbleCell*)chatBubbleCell;
-(void) accessibilityForward:(ChatBubbleCell*)chatBubbleCell;
-(void) accessibilityCopyText:(ChatBubbleCell*)chatBubbleCell;

@end
