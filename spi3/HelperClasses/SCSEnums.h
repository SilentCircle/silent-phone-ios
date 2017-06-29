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
//  SCSEnums.h
//  SPi3
//
//  Created by Eric Turner on 3/16/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#ifndef SCSEnums_h
#define SCSEnums_h


// conversation filter enum
// ChatUtilities, SCSMainTVC
typedef NS_ENUM(NSUInteger, scsActionType) {
    eCall = 0,
    eWrite
};

typedef NS_ENUM(NSUInteger, scsRightBarButtonType) {
    eRightBarButtonNone = 0,
    eRightBarButtonCall = 1,
    eRightBarButtonAddGroupMember = 2
};


typedef NS_ENUM(NSUInteger, scsMessageStatus) {
    Sent = 0,
    Delivered = 1,
    Received,
    Read,
    Burned = 3,
    Unused,
    Sync,
    Failed = 6
};

typedef NS_ENUM(NSUInteger, scsAvatarSize) {
    eAvatarSizeFull = 0,
    eAvatarSizeSmall = 1
};

typedef NS_ENUM(NSUInteger, scsCallState) {
    eDialedEnded = 0,
    eIncomingMissed = 1,
    eIncomingAnswered,
    eDialedNoAnswer,
    eSipError,
    eIncomingDeclined
};

typedef NS_ENUM(NSUInteger, scsEndCallUser) {
    eCallUserNone = 0,
    eCallUserLocal,
    eCallUserPeer
};

typedef NS_ENUM(NSUInteger, scsPasscodeScreenState) {
    ePasscodeScreenStateNotDetermined,
    ePasscodeScreenStateEditing,
    ePasscodeScreenNewPasscode,
    ePasscodeScreenVerifyPasscode
};

/**
 Describes contact type displayed in cell's or passed from SCSGlobalContactSearch
 */
typedef NS_OPTIONS(NSInteger, scsContactType) {
    
    /** 
     All Address Book contacts type
     */
    scsContactTypeAddressBook = (1 << 0),
    
    /**
     Silent circle Address Book contacts type
     */
    scsContactTypeAddressBookSilentCircle = (1 << 1),
    
    /**
     All conversations type 
     */
    scsContactTypeAllConversations = (1 << 2),
    
    /**
     Group conversations type
     */
    scsContactTypeGroupConversations = (1 << 3),
    
    /**
     Silent Circle directory type
     */
    scsContactTypeDirectory = (1 << 4),
    
    /**
     Autocomplete (exact match) type
     */
    scsContactTypeSearch = (1 << 5)
};

typedef NS_ENUM(NSUInteger, scsGroupInfoSectionType) {
    eGroupName = 0,
    eGroupCreator = 1,
    eGroupMembers = 2,
    eGroupActions = 3,
};


#endif /* SCSEnums_h */
