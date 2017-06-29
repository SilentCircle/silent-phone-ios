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
//  SCSConstants.h
//  SPi3
//
//  Created by Eric Turner on 5/2/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString * const kAdd                  = @"Add";
static NSString * const kAudio                = @"Audio";

static NSString * const kCall                 = @"Call";
static NSString * const kContacts             = @"Phone contacts";
static NSString * const kcontacts             = @"contacts";
static NSString * const kAllConversations     = @"Conversations";
static NSString * const kGroupConversations   = @"Silent Circle groups";

static NSString * const kDelete               = @"Delete";
static NSString * const kDirectory            = @"Directory";
static NSString * const kdirectory            = @"directory";

static NSString * const kFailedAttachment     = @"Failed Attachment";
static NSString * const kFound                = @"found";
static NSString * const kFile                 = @"File";

static NSString * const kImage                = @"Image";

static NSString * const kMoreThan20Results    = @"More than 20 results";
static NSString * const kMovie                = @"Movie";

static NSString * const kNoContacts           = @"No contacts";
static NSString * const kNoMessages           = @"No Messages";
static NSString * const kNoResults            = @"No results";

static NSString * const kPDF                  = @"PDF";

static NSString * const kReceived             = @"Received";
static NSString * const kRemove               = @"Remove";
static NSString * const kResult               = @"result";
static NSString * const kResults              = @"results";

static NSString * const kSaveToContacts       = @"Save To Contacts";
static NSString * const kSearching            = @"Searching...";
static NSString * const kSearchNameNumber     = @"Enter name or number";
static NSString * const kSearchName           = @"Enter name";
static NSString * const kSent                 = @"Sent";
static NSString * const kSilentCircle         = @"Silent Circle";

static NSString * const kUnixTimeStampProperty  = @"unixTimeStamp";
static NSString * const kDisplayNameProperty    = @"displayName";

static NSString * const kUnknown              = @"Unknown";
static NSString * const kNewGroupConversation = @"New group conversation";
static NSString * const kParticipant          = @"participant";
static NSString * const kParticipants         = @"participants";

static NSString * const kYou                  = @"You";

static NSString * const kGroupName            = @"Group name";
static NSString * const kCreator              = @"Creator";
static NSString * const kDescription          = @"Description";
static NSString * const kPeople               = @"People";
static NSString * const kActions              = @"Group Actions";
static NSString * const kJoined               = @"Joined";
static NSString * const kYouAdded             = @"You added";
static NSString * const kYouRemoved           = @"You removed";
static NSString * const kYesterday            = @"Yesterday";
static NSString * const kGroupMembers         = @"Group members";

static NSString * const kCancel               = @"Cancel";
static NSString * const kAddToExisting        = @"Add to Existing Contact";
static NSString * const kCreateNewContact        = @"Create new Contact";

static NSString * const kBurnChange              = @"Burn time set to";
static NSString * const kUserBurnChange          = @"You changed burn time to";
static NSString * const kGroupNameChange         = @"Group name changed to";
static NSString * const kUserGroupNameChange     = @"You changed group name to";
static NSString * const kErrorEmptyDisplayName   = @"Group name can't be empty ";
static NSString * const kErrorTooLongDisplayName = @"Group name exceeds 50 characters";
static NSString * const kGroupAvatarWasUpdated   = @"Group avatar updated";
static NSString * const kGroupAvatarWasRemoved   = @"Group avatar removed";
static NSString * const kLeft                    = @"Left";
static NSString * const kNoDevices               = @"has no registered devices";

static NSString * const kGroupMessageRemoved   = @"rmsg";
static NSString * const kGroupCreated          = @"ngrp";
static NSString * const kGroupNameChanged      = @"nnm";
static NSString * const KGroupMembersAdded     = @"addm";
static NSString * const KGroupBurnChanged      = @"nbrn";
static NSString * const kGroupMembersRemoved   = @"rmm";
static NSString * const kGroupAvatarUpdated    = @"navtr";
static NSString * const kResetAvatarCommand    = @"generated";
static NSString * const kGroupReadNotice       = @"rr";
static NSString * const kGroupLeave            = @"lve";

static NSString * const kGroupAddUserFail      = @"Adding group member has failed";
static NSString * const kSetGroupNameFail      = @"Setting group name has failed";
static NSString * const kSetGroupBurnFail      = @"Setting group burn time has failed";
static NSString * const kSetGroupAvatarFail    = @"Setting group avatar has failed";
static NSString * const kGroupApplyChangesFail = @"Applying group changes has failed";

#pragma - SCFileManager
static NSString * const kMediaCacheDirName     = @"MediaCache";
static NSString * const kRecordingCacheDirName = @"RecordingCache";
static NSString * const kSCloudCacheDirName    = @"SCloudCache";
static NSString * const kSCLogsCacheDirName    = @"SCLogsCache";
static NSString * const kSCSilentContactsCacheDirName = @"SCSilentContactsCache";
static NSString * const kMigrate_or_wipe_key   = @"last_files_migratration_or_wipe";
// Build Info in SCFileManager
static NSString * const kApp_version           = @"app_version";
static NSString * const kBuild_count           = @"build_count";
static NSString * const kCurrent_branch        = @"current_branch";
static NSString * const kCurrent_branch_count  = @"current_branch_count";
static NSString * const kCurrent_hash          = @"current_hash";
static NSString * const kCurrent_short_hash    = @"current_short_hash";                             
static NSString * const kSubmodules            = @"submodules";  
static NSString * const kSubmod_hash           = @"submod_hash";
static NSString * const kSubmod_branch         = @"submod_branch";
static NSString * const kSubmod_branch_details = @"submod_branch_details";
static NSString * const kSubmod_short_hash     = @"submod_short_hash";
static NSString * const kSubmod_short_branch   = @"submod_short_branch";

#pragma mark - User/UserService
static NSString * const kSPUserKey      = @"SPUser";
static NSString * const kSPUserIDKey    = @"SPUserID";


static NSString * const kNoNetwork = @"Network not available";

static NSString * const kUnableToSendMessages = @"Unable to send messages";
static NSString * const kUnableToCall = @"Unable to call";

static NSString * const kFailedToWrite = @"Failed to write to user";
static NSString * const kFailedToCall = @"Failed to call";

static NSString * const kEnsureNetwork = @"Ensure your device can connect to the internet and try again";
