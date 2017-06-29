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
//  UIColor+ApplicationColors.h
//  SPi3
//
//  Created by Gints Osis on 11/26/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (ApplicationColors)

#pragma mark - General
+(UIColor *) lightBgColor;
+(UIColor *) darkBgColor;
+(UIColor *) darkIosKeyboardBgColor;
+(UIColor *) navBarTitleColor;
+(UIColor *) accentRed;
+(UIColor *) selectedCellBackgroundColor;

#pragma mark - ActionSheetView
+(UIColor *) actionSheetViewRedBackgroundColor;


#pragma mark - ChatBubbleCell
+(UIColor *) chatbubbleCellFontColor;


#pragma mark - ChatView
+(UIColor *) initialsLabelBackgroundColor;
+(UIColor *) sentMessageFontColor;
+(UIColor *) receivedMessageFontColor;
+(UIColor *) messageInputFieldBackgroundColor;
+(UIColor *) actionSheetBackgroundColor;
+(UIColor *) chatBubbleStatusFontColor;
+(UIColor *) navigationTitleColor;
+(UIColor *) chatViewBackgroundColor;
+(UIColor *) addedMemberBackgroundColor;


#pragma mark - Conference TVC
+(UIColor *) onHoldConfBgColor;
+(UIColor *) selectedConfBgColor;
+(UIColor *) unverifiedConfBgColor;
+(UIColor *) verifiedConfBgColor:(BOOL)isSelected;


#pragma mark - Onboarding
+(UIColor *) grayOnboardingColor;
+(UIColor *) redOnboarding2Color;
+(UIColor *) whiteOnboarding3Color;
+(UIColor *) onboardingGradientColor;


#pragma mark - Profile View
+(UIColor *)connectivityOnlineColor;
+(UIColor *)connectivityOfflineColor;
+(UIColor *)connectivityConnectingColor;
+(UIColor *)profileHeaderBgColor;


#pragma mark - RecentsCell
+(UIColor *) recentsOutgoingCallColor;
+(UIColor *) recentsIncomingCallColor;
+(UIColor *) recentsMissedCallColor;
+(UIColor *) recentsIncomingCallFontColor;
+(UIColor *) recentsMissedCallFontColor;
+(UIColor *) recentsOriginalLastMessageFontColor;
+(UIColor *) swipeCellDeleteButtonTintColor;


#pragma mark - RecentsView
+(UIColor *) recentsSectionFontColor;
+(UIColor *) recentsSectionBackgroundColor;
+(UIColor *) recentsLastMessageFontColor;
+(UIColor *) recentsHeaderTextColor;
+(UIColor *) recentsHeaderBackgroundColor;
+(UIColor *) recentsNoConversationsRedColor;


#pragma mark - TabBar Colors
// TabBarItem selected/unselected icon tint colors
+(UIColor *) tabBarSelectedTintColor;
+(UIColor *) tabBarUnSelectedTintColor;
// TabBarItem background view selected/unselected colors
+(UIColor *) tabBarSelectedBgColor;
+(UIColor *) tabBarUnSelectedBgColor;

#pragma makr - SearchVM
+(UIColor *) callIconViewTintColor;
+(UIColor *) contactCellMsgAlertViewHighlightColor;

@end
