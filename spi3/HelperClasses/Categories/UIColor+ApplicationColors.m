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
//  UIColor+ApplicationColors.m
//  SPi3
//
//  Created by Gints Osis on 11/26/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import "UIColor+ApplicationColors.h"

@implementation UIColor (ApplicationColors)


#pragma mark - General

+(UIColor *) lightBgColor
{
    return [UIColor colorWithRed:0.93 green:0.91 blue:0.87 alpha:1.0];
}

+(UIColor *) darkBgColor
{
    return [UIColor colorWithRed:52/255.0f green:51/255.0f blue:59/255.0f alpha:1.0f];
}

+(UIColor *) darkIosKeyboardBgColor
{
    return [UIColor colorWithRed:66/255.0f green:66/255.0f blue:64/255.0f alpha:1.0f];
}

+(UIColor *) navBarTitleColor
{
    return [UIColor whiteColor];
}

+(UIColor *) accentRed
{
    return [UIColor colorWithRed:247./256. green:61./256. blue:14./256. alpha:1.];
}

+(UIColor *)selectedCellBackgroundColor
{
    return [UIColor colorWithRed:217./256. green:217./256. blue:217./256. alpha:1.];
}

#pragma mark - ActionSheetView

+(UIColor *) actionSheetViewRedBackgroundColor
{
    return [UIColor colorWithRed:235/255.0f green:235/255.0f blue:235/255.0f alpha:1.0f];
}


#pragma mark - ChatBubbleCell

+(UIColor *) chatbubbleCellFontColor
{
    return [UIColor colorWithRed:14/255.0f green:19/255.0f blue:35/255.0f alpha:1.0f];
}


#pragma mark - ChatView

+(UIColor *) initialsLabelBackgroundColor
{
    return [UIColor colorWithRed:215/255.0f green:215/255.0f blue:215/255.0f alpha:1.0f];
}

+(UIColor *) sentMessageFontColor
{
    return [UIColor colorWithRed:45/255.0f green:46/255.0f blue:50/255.0f alpha:1.0f];
}

+(UIColor *) receivedMessageFontColor
{
    return [UIColor colorWithRed:45/255.0f green:46/255.0f blue:50/255.0f alpha:1.0f];
}

+(UIColor *) messageInputFieldBackgroundColor
{
    return [UIColor colorWithRed:238/255.0f green:233/255.0f blue:222/255.0f alpha:1.0f];
}

+(UIColor *) actionSheetBackgroundColor
{
    return [UIColor colorWithRed:254/255.0f green:253/255.0f blue:249/255.0f alpha:1.0f];
}

+(UIColor *) chatBubbleStatusFontColor
{
    return [UIColor colorWithRed:158/255.0f green:158/255.0f blue:158/255.0f alpha:1.0f];
}

+(UIColor *) navigationTitleColor
{
    return [UIColor colorWithRed:226/255.0f green:226/255.0f blue:226/255.0f alpha:1.0f];
}

+(UIColor *) chatViewBackgroundColor
{
    return [UIColor colorWithRed:254/255.0f green:253/255.0f blue:249/255.0f alpha:1.0f];
}

+(UIColor *) addedMemberBackgroundColor
{
    return [UIColor colorWithRed:251/255.0f green:100/255.0f blue:100/255.0f alpha:1.0f];
}


#pragma mark - Conference TVC

+(UIColor *) onHoldConfBgColor {
    return [UIColor colorWithRed: 54./255. green: 55./255. blue: 59./255. alpha:1];
}

+(UIColor *) selectedConfBgColor {
    return [UIColor colorWithRed:230./255. green:230./255. blue:230./255. alpha:0.75];
}

+(UIColor *) unverifiedConfBgColor {
    return [UIColor colorWithRed:  94./255. green:  94./255. blue:  94./255. alpha:1];
}

+(UIColor *) verifiedConfBgColor:(BOOL)isSelected {
    return [UIColor colorWithRed: 180./255. green: 179./255. blue: 179./255.
                           alpha: (isSelected) ? 1. : 0.4];
}


#pragma mark - Onboarding

+(UIColor *) grayOnboardingColor
{
    return [UIColor colorWithRed:231./255. green:222./255. blue:203./255. alpha:1.];
}

+(UIColor *) redOnboarding2Color
{
    return [UIColor colorWithRed:197./255. green:60./255. blue:53./255. alpha:1.];
}

+(UIColor *) onboardingGradientColor
{
    return [UIColor colorWithRed:53./255. green:55/255. blue:59./255. alpha:1.];
}

+(UIColor *) whiteOnboarding3Color
{
    return [UIColor colorWithRed:244./255. green:239./255. blue:228./255. alpha:1.];
}


#pragma mark - Profile View

// Connectivity colors
+(UIColor *)connectivityOnlineColor
{
    return [UIColor colorWithRed:67./256. green:164./256. blue:54./256. alpha:1.];
}

+(UIColor *)connectivityOfflineColor
{
    return [UIColor colorWithRed:232./256. green:58./256. blue:39./256. alpha:1.];
}

+(UIColor *)connectivityConnectingColor
{
    return [UIColor colorWithRed:89./256. green:198./256. blue:255./256. alpha:1.];
}

// Profile header BG color
+(UIColor *)profileHeaderBgColor
{
    return [UIColor colorWithRed:54./256. green:55./256. blue:59./256. alpha:1.];
}


#pragma mark - RecentsCell

+ (UIColor *) recentsOutgoingCallColor {
    // Green
    return [UIColor colorWithRed:0.0 green:165/255.0 blue:35/255.0 alpha:1.];
}

+ (UIColor *) recentsIncomingCallColor {
    // Blue
    return [UIColor colorWithRed:0.259 green:0.565 blue:0.812 alpha:1.];
}

+ (UIColor *) recentsMissedCallColor {
    // Red
    return [UIColor colorWithRed:0.906 green:0.227 blue:0.153 alpha:1.];
}


+(UIColor *) recentsIncomingCallFontColor
{
    return [UIColor colorWithRed:93./256. green:188./256. blue:67./256. alpha:1.];
}

+(UIColor *) recentsMissedCallFontColor
{
    return [UIColor colorWithRed:235/255.0f green:91/255.0f blue:75/255.0f alpha:1.0f];
}

+(UIColor *) recentsOriginalLastMessageFontColor
{
    return [UIColor colorWithRed:100/255.0f green:101/255.0f blue:103/255.0f alpha:1.0f];
}

+(UIColor *) swipeCellDeleteButtonTintColor {
    return [UIColor colorWithRed:0.906 green:0.227 blue:0.153 alpha:1.];
}

#pragma mark - RecentsView

+(UIColor *) recentsNoConversationsRedColor
{
    return [UIColor colorWithRed:231/255.0 green:58/255.0 blue:39/255.0 alpha:1.0];
}

+(UIColor *) recentsSectionFontColor
{
    return [UIColor colorWithRed:83/255.0 green:83/255.0 blue:83/255.0 alpha:1.0];
}
+(UIColor *) recentsSectionBackgroundColor
{
    return [UIColor colorWithRed:240/255.0 green:240/255.0 blue:240/255.0 alpha:1.0];
}

+(UIColor *) recentsLastMessageFontColor
{
    return [UIColor colorWithRed:231/255.0 green:58/255.0 blue:39/255.0 alpha:1.0f];
}

+(UIColor *) recentsHeaderBackgroundColor
{
    return [UIColor colorWithRed:246/255.0f green:246/255.0f blue:246/255.0f alpha:1.0f];
}

+(UIColor *) recentsHeaderTextColor
{
    return [UIColor colorWithRed:235/255.0f green:91/255.0f blue:75/255.0f alpha:1.0f];
}


#pragma mark - TabBar Colors

// TabBarItem selected/unselected icon tint colors
+(UIColor *) tabBarSelectedTintColor
{
    return [UIColor whiteColor];
}
+(UIColor *) tabBarUnSelectedTintColor
{
    return [UIColor whiteColor];
}

// TabBarItem background view selected/unselected colors
+(UIColor *) tabBarSelectedBgColor
{
    return [UIColor colorWithRed:54./256. green:55./256. blue:59./256. alpha:1.];
}
+(UIColor *) tabBarUnSelectedBgColor
{
    return [UIColor colorWithRed:54./256. green:55./256. blue:59./256. alpha:1.];
}

#pragma makr - SearchVM
+(UIColor *) callIconViewTintColor {
    return [UIColor lightGrayColor];
}

+(UIColor *) contactCellMsgAlertViewHighlightColor {
    return [UIColor colorWithRed:244./256. green:63./256. blue:34./256. alpha:1.];
}

@end
