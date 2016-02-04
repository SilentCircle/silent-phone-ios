/*
Copyright (C) 2016, Silent Circle, LLC.  All rights reserved.

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
#define kReceivedMessageSpacingFromLeft 10
#define kCellTopOffset 5
#define kTextFontColor [UIColor colorWithRed:14/255.0f green:19/255.0f blue:35/255.0f alpha:1.0f]
#define kSentMessageBackgroundColor [UIColor colorWithRed:226/255.0f green:226/255.0f blue:226/255.0f alpha:1.0f]
#define kReceivedMessageBackgroundColor [UIColor colorWithRed:192/255.0f green:189/255.0f blue:184/255.0f alpha:1.0f]
#define kTimeStampLabelFontSize 9.0f
#define kReceivedMessageTextSpacingFromLeft 63
#define kChatBubbleBottomIconHeight 15

#define kSentMessageBullet [UIImage imageNamed:@"sentArrow.png"]
#define kReceivedMessageBullet [UIImage imageNamed:@"recivedArrow.png"]
#define kReadStatusImage [UIImage imageNamed:@"MessageReadImage.png"]
#define kClockIcon [UIImage imageNamed:@"ClockIcon.png"]
//#define kBurnImage [UIImage imageNamed:@"burnIcon.png"]

#define kSentMessageSpacingFromRight 15

#import "ChatBubbleCell.h"
#import "BurnButton.h"
#import "ChatObject.h"
#import "ChatBubbleTextView.h"
#import "LocationButton.h"
#import "Utilities.h"

@implementation ChatBubbleCell
-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if(self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier]){
        [self setSelectionStyle:UITableViewCellSelectionStyleNone];
        [self.contentView setBackgroundColor:[UIColor clearColor]];
        [self setBackgroundColor:[UIColor clearColor]];
        
        _containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, self.frame.size.height)];
        [_containerView setBackgroundColor:[UIColor clearColor]];
        [_containerView setTag:-1];
        [self.contentView addSubview:_containerView];
        
        _errorContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [Utilities utilitiesInstance].screenWidth, self.frame.size.height)];
        [_errorContainerView setBackgroundColor:[UIColor clearColor]];
        [_errorContainerView setTag:-2];
        [self.contentView addSubview:_errorContainerView];
        
        
        UIFont *prefferedFont;
        
        
        _errorLabel = [[UILabel alloc] init];
        [_errorLabel setTextAlignment:NSTextAlignmentCenter];
        [_errorLabel setTextColor:[UIColor whiteColor]];
        [_errorLabel setNumberOfLines:0];
        _errorLabel.font = [[Utilities utilitiesInstance] getFontWithSize:14];
        [_errorContainerView addSubview:_errorLabel];
        
        _errorImageView = [[UIImageView alloc] init];
        [_errorImageView setImage:[UIImage imageNamed:@"errorInfomationIcon.png"]];
        [_errorContainerView addSubview:_errorImageView];
        
        /*
        // contact imageView
        _messageContactImageView = [[UIImageView alloc] initWithFrame:CGRectMake(kReceivedMessageSpacingFromLeft + 3, kCellTopOffset + 2, 46, 46)];
        _messageContactImageView.tag = 4;
        [_containerView addSubview:_messageContactImageView];
         */
		
		_sentBulletImageView = [[UIImageView alloc] init];
		_sentBulletImageView.image = kSentMessageBullet;
		_sentBulletImageView.tag = 7;
		[_containerView addSubview:_sentBulletImageView];
		
		_receivedBulletImageView = [[UIImageView alloc] init];
		_receivedBulletImageView.image = kReceivedMessageBullet;
        [_receivedBulletImageView setContentMode:UIViewContentModeScaleAspectFit];
		_receivedBulletImageView.tag = 8;
		[_containerView addSubview:_receivedBulletImageView];
		
        // chatMessageTextLabel
        _messageTextLabel = [[ChatBubbleTextView alloc] init];
        //_messageTextLabel.selectable = NO;
       // _messageTextLabel.dataDetectorTypes = UIDataDetectorTypeLink;
        _messageTextLabel.selectable = YES;
        _messageTextLabel.scrollEnabled = NO;
        _messageTextLabel.editable = NO;
        _messageTextLabel.tag = 1;
        //[_messageTextLabel setContentOffset:CGPointMake(0, -10)];
        _messageTextLabel.textContainerInset = UIEdgeInsetsMake(2, 0, 0, 0);
		
        _messageTextLabel.textAlignment = NSTextAlignmentLeft;
       
        _messageTextLabel.accessibilityTraits = UIAccessibilityTraitStaticText;//
        // disable text selection on chat message
        [_messageTextLabel setUserInteractionEnabled:NO];
        
        
        prefferedFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        _messageTextLabel.font = [[Utilities utilitiesInstance] getFontWithSize:prefferedFont.pointSize];
        [_messageTextLabel setTextColor:kTextFontColor];
        [_containerView addSubview:_messageTextLabel];

		_messageImageView = [[UIImageView alloc] init];
		//_messageImageView.layer.cornerRadius = 3;
		_messageImageView.clipsToBounds = YES;
		_messageImageView.hidden = YES;
		[_messageImageView setContentMode:UIViewContentModeScaleAspectFill];
		//        [_containerView addSubview:_messageImageView];
		[_messageTextLabel addSubview:_messageImageView];
		
		_progressView = [[UIProgressView alloc] init];
		_progressView.hidden = YES;
		_progressView.progress = 0;
		[_containerView addSubview:_progressView];

        _timeStampLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
        [_timeStampLabel setTextColor:[UIColor whiteColor]];
        _timeStampLabel.tag = 5;
        _timeStampLabel.numberOfLines = 1;
        _timeStampLabel.adjustsFontSizeToFitWidth = YES;
        
        prefferedFont = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        _timeStampLabel.font = [[Utilities utilitiesInstance] getFontWithSize:prefferedFont.pointSize];
        _timeStampLabel.textAlignment = NSTextAlignmentRight;
        [_containerView addSubview:_timeStampLabel];
        
        _locationButton = [[LocationButton alloc] init];
        //[_locationButton setImage:[UIImage imageNamed:@"LocationOnWithCircle.png"] forState:UIControlStateNormal];
        [_locationButton setContentMode:UIViewContentModeScaleAspectFit];
        _locationButton.tag = 6;
        [_containerView addSubview:_locationButton];
        
        /*
        _readStatusImageView = [[UIImageView alloc] init];
        _readStatusImageView.image = kReadStatusImage;
        [_readStatusImageView setContentMode:UIViewContentModeScaleAspectFit];
        _readStatusImageView.tag = 9;
        [_messageTextLabel addSubview:_readStatusImageView];
        */
        /*
        _clockIconImageView = [[UIImageView alloc] init];
        _clockIconImageView.image = kClockIcon;
        [_clockIconImageView setContentMode:UIViewContentModeScaleAspectFit];
        _clockIconImageView.tag = 10;
        [_messageTextLabel addSubview:_clockIconImageView];
        */
        _burnImageButton = [[BurnButton alloc] init];
        _burnImageButton.accessibilityLabel = @"Burn button";
        //[_burnImageButton setImage:kBurnImage forState:UIControlStateNormal];
        [_burnImageButton.imageView setContentMode:UIViewContentModeScaleAspectFit];
        _burnImageButton.tag = 11;
       _burnImageButton.accessibilityElementsHidden = YES;
       
        [_containerView addSubview:_burnImageButton];
        
        _burnTimeLabel = [[UILabel alloc] init];
        [_burnTimeLabel setFont:[[Utilities utilitiesInstance] getFontWithSize:prefferedFont.pointSize]];
        [_burnTimeLabel setTextColor:[UIColor whiteColor]];
        [_burnTimeLabel setTextAlignment:NSTextAlignmentCenter];
        _burnTimeLabel.tag = 12;
        _burnTimeLabel.numberOfLines = 1;
        //_burnTimeLabel.minimumScaleFactor = 0.5f;
        _burnTimeLabel.adjustsFontSizeToFitWidth = YES;
        [_containerView addSubview:_burnTimeLabel];
       
    }
    return self;
}



@end
