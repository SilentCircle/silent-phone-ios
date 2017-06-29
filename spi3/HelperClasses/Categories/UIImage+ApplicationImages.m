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
//  UIImage+ApplicationImages.m
//  SPi3
//
//  Created by Gints Osis on 11/27/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import "UIImage+ApplicationImages.h"

@implementation UIImage (ApplicationImages)


+(UIImage*) emptyCallImage
{
    return [UIImage imageNamed:@"NumberContactPicture.png"];
}

#pragma mark - navigationBar

+(UIImage *) navigationBarBackButton
{
    return [UIImage imageNamed:@"backArrow"];
}

+(UIImage *) navigationBarCallButton
{
    return [UIImage imageNamed:@"ProfileNumberIcon"];
}

+(UIImage *) navigationBarSettings
{
    return [UIImage imageNamed:@"gearIcon.png"];
}

+(UIImage *)navigationBarCreateGroupButton
{
    return [UIImage imageNamed:@"AddPeopleFromChatIcon"];
}


// GO - What kind of buttons? ET - different kinds.
#pragma mark - Buttons Icons

+(UIImage *) dialPadIcon {
    return [UIImage imageNamed:@"dialpad"];
}

+(UIImage *) qwertyKeyboardIcon {
    return [UIImage imageNamed:@"keyboard"];
}

+(UIImage *) leftBackArrowIcon {
    return [UIImage imageNamed:@"ios_backbutton_left-arrow"];
}

+(UIImage *) backspaceIcon {
    return [UIImage imageNamed:@"bbtn_dial_backspace_bgClear"];
}

// Used in TabBar, CallScreen, Conference back button
+(UIImage *) conversationsIcon {
    return [UIImage imageNamed:@"TabBarIcon-Recent"];
}
+(UIImage *) removeMemberIcon;
{
    return [UIImage imageNamed:@"removeGroupMember"];
}

+(UIImage *) groupCreateDisabledIcon;
{
    return [UIImage imageNamed:@"groupCreateDisabled"];
}

+(UIImage *) groupCreateEnabledIcon;
{
    return [UIImage imageNamed:@"groupCreateEnabled"];
}

+(UIImage *)selectedCheckmark
{
    return [UIImage imageNamed:@"SelectedCheckmark"];
}

+(UIImage *)unselectedCheckmark
{
    return [UIImage imageNamed:@"UnselectedCheckmark"];
}



#pragma mark - ChatBubble
+(UIImage *) chatSendIcon
{
    return [UIImage imageNamed:@"sendIcon.png"];
}


#pragma mark - chatActionSheet
+(UIImage *) actionSheetShareLocationOn
{
    return [UIImage imageNamed:@"ShareLocationIconOn.png"];
}

+(UIImage *) actionSheetShareLocationOff
{
    return [UIImage imageNamed:@"ShareLocationIconOff.png"];
}


#pragma mark CellSwiping Icons
+(UIImage *) swipeCallIcon {
    return [UIImage imageNamed:@"CellCallIcon.png"];
}

+(UIImage *) swipeSaveContactsIcon {
    return [UIImage imageNamed:@"ContactSave.png"];
}

+(UIImage *) swipeTrashIcon {
    return [UIImage imageNamed:@"CellTrashIcon.png"];
}

+(UIImage *) contactEditButton
{
    return [UIImage imageNamed:@"contactEditButton.png"];
}

#pragma mark - Other
+(UIImage *) incomingCallEventArrow {
    return [UIImage imageNamed:@"CallEventArrowIncoming"];
}

+(UIImage *) outgoingCallEventArrow {
    return [UIImage imageNamed:@"CallEventArrowOutgoing"];
}

+(UIImage *)numberAvatarImage
{
    return [UIImage imageNamed:@"NumberContactPicture"];
}

+(UIImage *)defaultGroupAvatarImage
{
    return [UIImage imageNamed:@"oneMemberGroupChat"];
}

#pragma mark - SearchVC
+(UIImage *) kbModeClear_white {
    return [UIImage imageNamed:@"clear_white"];
}
+(UIImage *) kbModeDialpad_white {
    return [UIImage imageNamed:@"dialpad_white"];
}
+(UIImage *) kbModeKeyboard_white {
    return [UIImage imageNamed:@"keyboard_white"];
}

@end
