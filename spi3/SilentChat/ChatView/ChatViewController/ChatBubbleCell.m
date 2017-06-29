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
#define kReceivedMessageSpacingFromLeft 10
#define kCellTopOffset 5
#define kTimeStampLabelFontSize 9.0f
#define kReceivedMessageTextSpacingFromLeft 63
#define kChatBubbleBottomIconHeight 15
#define kSentMessageSpacingFromRight 15



#import "ChatBubbleCell.h"
#import "BurnButton.h"
#import "ChatObject.h"
#import "LocationButton.h"
#import "ChatUtilities.h"
#import "UIColor+ApplicationColors.h"
#import "UIImage+ApplicationImages.h"
#import "Silent_Phone-Swift.h"

@implementation ChatBubbleCell
-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if(self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier]){
    }
    return self;
}




-(void)setthisChatObject:(ChatObject *)thisChatObject
{
    /*self.messageTextLabel.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
    self.messageTextLabel.textContainerInset = UIEdgeInsetsMake(5, 0, 0, 0);*/
    _thisChatObject = thisChatObject;
    NSMutableArray *accessibilityActions = [[NSMutableArray alloc] init];
    
    [accessibilityActions addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"Burn" target:self selector:@selector(burnMessage)]];
    [accessibilityActions addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"Info" target:self selector:@selector(info)]];
    
    if (!thisChatObject.attachment)
    {
        [accessibilityActions addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"Copy" target:self selector:@selector(copyText)]];
    }
    
    if (!thisChatObject.isCall) {
        
        if (thisChatObject.location) {
            [accessibilityActions addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"Show Location" target:self selector:@selector(showLocation)]];
        }
        
        
        // add resend for sent messages
        if (thisChatObject.isReceived == 0) {
            [accessibilityActions addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"Resend" target:self selector:@selector(resend)]];
        }
        
        [accessibilityActions addObject:[[UIAccessibilityCustomAction alloc] initWithName:@"Forward" target:self selector:@selector(forward)]];
    }
    
    self.accessibilityCustomActions = accessibilityActions;
}


// TODO -
-(CGRect)accessibilityFrame
{
    // if toview is nil, convert it to window coordinates
    if(self.thisChatObject.attachment)
        return [self convertRect:self.messageImageView.frame toView:nil];
    else if(!self.thisChatObject.isCall && self.thisChatObject.isInvitationChatObject != 1)
        return [self convertRect:self.messageBackgroundView.frame toView:nil];
    else
        return [self convertRect:self.contentView.frame toView:nil];
}

// returns NO if touch is outside the accessibilityFrame, which is the messagetextLabel for text, attachment messages or entire cell for call messages
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGPoint newPoint = [self convertPoint:point toView:nil];
    
    if(CGRectContainsPoint([self convertRect:self.locationButton.frame toView:nil], newPoint))
        return YES;
    
    if(CGRectContainsPoint([self convertRect:self.burnButton.frame toView:nil], newPoint) && !UIAccessibilityIsVoiceOverRunning())
        return YES;
    
    return CGRectContainsPoint(self.accessibilityFrame, newPoint);
}

-(BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)tapped {
    
    if(self.bubbleCellDelegate)
        [self.bubbleCellDelegate chatBubbleCellWasTapped:self];
}

- (BOOL)doubleTapped {
    
    if(self.bubbleCellDelegate)
        return [self.bubbleCellDelegate chatBubbleCellWasDoubleTapped:self];
    else
        return NO;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {

    UITouch *touch = [touches anyObject];
    
    UIView *touchviewToTest;
    if (_thisChatObject.attachment) {
        touchviewToTest = self.messageImageView;
    } else
    {
        touchviewToTest = self.messageBackgroundView;
    }
    
    CGPoint location = [touch locationInView:touchviewToTest];
    BOOL bubbleHit = CGRectContainsPoint(CGRectMake(0, 0, CGRectGetWidth(touchviewToTest.frame), CGRectGetHeight(touchviewToTest.frame)), location);
    
    // In case of enabled VoiceOver, we assume that the bubble was touched
    if(UIAccessibilityIsVoiceOverRunning())
        bubbleHit = YES;
    
    if(bubbleHit)
        [self tapped];

    [super touchesEnded:touches withEvent:event];
}

#pragma mark - Accessibility

- (BOOL)accessibilityPerformMagicTap
{
    return [self doubleTapped];
}

-(BOOL) burnMessage
{
    if ([self.bubbleCellDelegate respondsToSelector:@selector(accessibilityBurnMessage:)]) {
        [self.bubbleCellDelegate accessibilityBurnMessage:self];
    }
    return YES;
}

-(BOOL) showLocation
{
    if ([self.bubbleCellDelegate respondsToSelector:@selector(accessibilityShowLocation:)]) {
        [self.bubbleCellDelegate accessibilityShowLocation:self];
    }
    return YES;
}

-(BOOL) info
{
    if ([self.bubbleCellDelegate respondsToSelector:@selector(accessibilityInfo:)]) {
        [self.bubbleCellDelegate accessibilityInfo:self];
    }
    return YES;
}

-(BOOL) forward
{
    if ([self.bubbleCellDelegate respondsToSelector:@selector(accessibilityForward:)]) {
        [self.bubbleCellDelegate accessibilityForward:self];
    }
    return YES;
}
-(BOOL) copyText
{
    if ([self.bubbleCellDelegate respondsToSelector:@selector(accessibilityCopyText:)]) {
        [self.bubbleCellDelegate accessibilityCopyText:self];
    }
    return YES;
}

-(BOOL) resend
{
    if ([self.bubbleCellDelegate respondsToSelector:@selector(accessibilityResend:)]) {
        [self.bubbleCellDelegate accessibilityResend:self];
    }
    return YES;
}

@end
