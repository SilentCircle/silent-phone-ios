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
//  SCPNotificationKeys.h
//  SP3
//
//  Created by Eric Turner on 5/9/15.
//  Based on original work by Janis Narbuts SP1
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

#ifndef SCPSwitchboard__SCPNotificationKeys_h
#define SCPSwitchboard__SCPNotificationKeys_h

#import "SCPPrivateKeys.h"

#pragma mark - Calls
static NSString * const kSCPIncomingCallNotification                    = @"SCPIncomingCallNotification";
static NSString * const kSCPOutgoingCallNotification                    = @"SCPOutgoingCallNotification";
static NSString * const kSCPOutgoingCallRequestNotification             = @"SCPOutgoingCallRequestNotification";
static NSString * const kSCPOutgoingCallRequestFulfilledNotification    = @"SCPOutgoingCallRequestFulfilledNotification";
static NSString * const kSCPOutgoingCallRequestFailedNotification       = @"SCPOutgoingCallRequestFailedNotification";
static NSString * const kSCPOutgoingCallRequestMCFulFilledNotification  = @"SCPOutgoingCallRequestMCFulFilledNotification";
static NSString * const kSCPCallStateDidChangeNotification              = @"SCPCallStateDidChangeNotification";
static NSString * const kSCPZRTPDidUpdateNotification                   = @"SCPZRTPDidUpdateNotification";
static NSString * const kSCPCallDidEndNotification                      = @"SCPCallDidEndNotification";
static NSString * const kSCPCallStateCallAnsweredByLocalNotification    = @"kSCPCallStateCallAnsweredByLocalNotification";
static NSString * const kSCPCallIncomingVideoRequestNotification        = @"kSCPCallIncomingVideoRequestNotification";
static NSString * const kSCPCallAcceptedVideoRequestNotification        = @"kSCPCallAcceptedVideoRequestNotification";
static NSString * const kSCPCallDeclinedVideoRequestNotification        = @"kSCPCallDeclinedVideoRequestNotification";

#pragma mark - Remote Control
static NSString * const kSCPRemoteControlClickedNotification    = @"kSCPRemoteControlClickedNotification";

#pragma mark - State
static NSString * const kSCPEngineStateDidChangeNotification    = @"SCPEngineStateDidChangeNotification";
static NSString * const kSCPChatBubbleTextSizeChanged           = @"SCPChatBubbleTextSizeChanged";


#pragma mark - Audio
static NSString * const kSCSAudioStateDidChange                 = @"kSCSAudioStateDidChange";
static NSString * const KSCSAudioOutputVolumeDidChange          = @"KSCSAudioOutputVolumeDidChange";
static NSString * const kSCSAudioMuteMicDidChange               = @"kSCSAudioMuteMicDidChange";

#pragma mark - Favorites
static NSString * const kSCPFavoritesListNeedsUpdateNotification = @"SCPFavoritesListNeedsUpdateNotification";


#pragma mark - Navigation
/* burger DEPRECATE
static NSString * const kSCPWillRemoveCallScreenNavNotification = @"SCPWillRemoveCallScreenNavNotification";
static NSString * const kSCPDidRemoveCallScreenNavNotification  = @"SCPDidRemoveCallScreenNavNotification";
 */
static NSString * const kSCPOutgoingCallNumber                  = @"SCPOutgoingCallNumber";
static NSString * const kSCPQueueVideoRequest                   = @"SCPQueueVideoRequest";

static NSString * const kSCPWillPresentCallScreenNotification   = @"SCPWillPresentCallScreenNotification";
static NSString * const kSCPDidPresentCallScreenNotification    = @"SCPDidPresentCallScreenNotification";
static NSString * const kSCPWillShowHeaderStrip                 = @"SCPWillShowHeaderStrip";
static NSString * const kSCPWillHideHeaderStrip                 = @"SCPWillHideHeaderStrip";


#pragma mark - Device
static NSString * const kSCPDeviceAngleDidChangeNotification = @"SCPDeviceAngleDidChangeNotification";
static NSString * const kSCPStatusBarTappedNotification      = @"SCPStatusBarTappedNotification";


#pragma mark - Transitions
static NSString * const kSCPNeedsTransitionToChatWithContactNameNotification = @"SCPNeedsTransitionToChatWithContactNameNotification";


#pragma mark - UserService

/**
 Called by notifyGeneric zina method in order to trigger 
 an SPi refresh of local user data.
 */
static NSString * const kSCSUserServiceUpdateUserNotification           = @"UserServiceUpdateUserNotification";
/**
 Called by UserService when local user data has been updated.
 */
static NSString * const kSCSUserServiceUserDidUpdateNotification        = @"UserServiceUserDidUpdateNotification";
/**
 Called by stateAxoMsg zina method when we get a 200 or 
 a 202 response in order for the devices view to refresh 
 itself if active.
 */
static NSString * const kSCSUserServiceUserDidUpdateDevicesNotification = @"UserServiceUserDidUpdateDevicesNotification";

#pragma mark - NetworkManager
/**
 Called when the current device was remotely wiped and 
 we have to issue the countdown timer.
 */
static NSString * const kSCSUserDeviceWasRemovedNotification = @"SCSUserDeviceWasRemovedNotification";

#pragma makr - DBManager
static NSString * const kSCSDBManagerLoadedAllConversationsNotification = @"DBManagerLoadedAllConversationsNotification";

#pragma mark - RecentObject
static NSString * const kSCSRecentObjectUpdatedNotification       = @"RecentObjectUpdatedNotification";
static NSString * const kSCSRecentObjectRemovedNotification       = @"RecentObjectRemovedNotification";
static NSString * const kSCSRecentObjectCreatedNotification       = @"RecentObjectCreatedNotification";
static NSString * const kSCSAvatarAssigned                        = @"AvatarAssigned";
static NSString * const kSCSContactTypeSearchTableUpdated         = @"SearchTableUpdated";

static NSString * const kSCSRecentObjectShouldResolveNotification = @"RecentObjectShouldResolveNotification";
static NSString * const kSCSRecentObjectResolvedNotification      = @"RecentObjectResolvedNotification";

#pragma mark - Contacts
static NSString * const kSCSContactSaveFailedNotification  = @"ContactSaveFailedNotification";
static NSString * const kSCSContactSavedNotification       = @"ContactSavedNotification";

#pragma mark - Config
static NSString * const kSCSDidSaveConfigNotification     = @"SCSDidSaveConfigNotification";
static NSString * const kSCSRingtoneDidChangeNotification = @"kSCSRingtoneDidChangeNotification";

#pragma mark - Chat
static NSString * const kdidChangeLocationStatus            = @"SCSDidChangeLocationStatus";
static NSString * const kActionSheetWillDismissItsSuperView = @"SCSActionSheetWillDismissItsView";
static NSString * const kSCPReceiveMessageNotification      = @"receiveMessage";
static NSString * const kSCPRemoveMessageNotification       = @"removeMessage";
static NSString * const kSCSResetBadgeNumberNotification    = @"SCSResetBadgeNumberNotification";
static NSString * const kSCSResetAppBadgeNumberNotification = @"SCSResetAppBadgeNumberNotification";

#pragma mark ChatManager 
static NSString * const ChatObjectCreatedNotification = @"ChatObjectCreatedNotification";
static NSString * const ChatObjectUpdatedNotification = @"ChatObjectUpdatedNotification";
static NSString * const ChatObjectFailedNotification  = @"ChatObjectFailedNotification";

#pragma mark Attachments
static NSString * const AttachmentManagerEncryptProgressNotification = @"AttachmentManagerEncryptProgressNotification";
static NSString * const AttachmentManagerUploadProgressNotification = @"AttachmentManagerUploadProgressNotification";
static NSString * const AttachmentManagerVerifyProgressNotification = @"AttachmentManagerVerifyProgressNotification";
static NSString * const AttachmentManagerDownloadProgressNotification = @"AttachmentManagerDownloadProgressNotification";
static NSString * const AttachmentManagerReceiveAttachmentNotification = @"AttachmentManagerReceiveAttachmentNotification";


#pragma mark - Keyboard
static NSString * const UIInputAccessoryFrameDidChange = @"InputAccessoryFrameDidChange";

#pragma mark - Passcode
static NSString * const kSCSPasscodeShouldShowNewPasscode  = @"SCSPasscodeShouldShowNewPasscode";
static NSString * const kSCSPasscodeShouldShowEditPasscode = @"SCSPasscodeShouldShowEditPasscode";
static NSString * const kSCSPasscodeShouldRemovePasscode   = @"SCSPasscodeShouldRemovePasscode";
static NSString * const kSCSPasscodeDidUnlock              = @"SCSPasscodeDidUnlock";
static NSString * const kSCSPasscodeShouldEnableWipe       = @"SCSPasscodeShouldEnableWipe";
static NSString * const kSCSPasscodeShouldDisableWipe      = @"SCSPasscodeShouldDisableWipe";

#pragma mark - Dictionary Keys
static NSString * const kSCPConstraintDictionaryKey     = @"SCPConstraintDictionaryKey ";
static NSString * const kSCPChatObjectDictionaryKey     = @"SCPChatObjectDictionaryKey";
static NSString * const kSCPRecentObjectDictionaryKey   = @"SCPRecentObjectDictionaryKey";
static NSString * const kSCPErrorDictionaryKey          = @"SCPErrorDictionaryKey";
static NSString * const kSCPCallDictionaryKey           = @"SCPCallDictionaryKey";
static NSString * const kSCPViewControllerDictionaryKey = @"SCPViewControllerDictionaryKey";
static NSString * const kSCPReloadCellDictionaryKey     = @"SCPReloadCellDictionaryKey";
static NSString * const kSCPProgressObjDictionaryKey    = @"SCPProgressObjDictionaryKey";
static NSString * const kSCPMsgIdDictionaryKey          = @"SCPMsgIdDictionaryKey";
static NSString * const kSCPViewDictionaryKey           = @"SCPViewDictionaryKey";
static NSString * const kSCPContactNameDictionaryKey    = @"SCPContactNameDictionaryKey";
static NSString * const kSCPMessageContentDictionaryKey = @"SCPMessageContentDictionaryKey";
static NSString * const kSCPTimerCallbackTypeKey        = @"SCPTimerCallbackTypeKey";

#pragma mark - SideMenu
static NSString * const kSCSPSideMenuWillAppear          = @"SCSPSideMenuWillAppear";
static NSString * const kSCSPSideMenuWillDisappear       = @"SCSPSideMenuWillDisappear";
static NSString * const kSCSPSideMenuDidAppear           = @"SCSPSideMenuDidAppear";
static NSString * const kSCSPSideMenuDidDisappear        = @"SCSPSideMenuDidDisappear";
static NSString * const kSCSideMenuSelectionNotification = @"SCSideMenuSelectionNotification";

#pragma mark - Permissions
static NSString * const PermissionChangedNotification    = @"PermissionChangedNotification";

#endif
