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
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SCPinningObject.h"
#import "SCSEnums.h"
#import "AddressBookContact.h"

@class ChatObject;

@interface RecentObject : NSObject

/**
 Creates a new RecentObject with the contents
 of a JSON dictionary (originating from an API response)

 @param jsonDict The provided JSON dictionary
 @return The newly created RecentObject, nil if there is an error
 */
- (instancetype)initWithJSON:(NSDictionary *)jsonDict;

/**
 Updates the RecentObject properties using a JSON dictionary
 (originating from an API response).
 
 @discussion Do not use the return value to deduce if
 any of the values have changed or not. Only if there
 was an error (e.g. the jsonDict argument was not a
 NSDictionary type).

 @param jsonDict The JSON dictionary
 @return YES if the properties have been updated, NO otherwise
 */
- (BOOL)updateWithJSON:(NSDictionary *)jsonDict;

@property (nonatomic, strong, setter = setContactName:) NSString *contactName;
@property (nonatomic, strong, setter = setDisplayName:) NSString *displayName;
@property (nonatomic, strong, setter = setDisplayAlias:) NSString *displayAlias;
@property (nonatomic, strong, setter = setDisplayOrganization:) NSString *displayOrganization;
@property (nonatomic, strong, setter = setAvatarUrl:) NSString *avatarUrl;

/**
 Note: 
 
 To be used only by the GlobalContactSearcher for the
 autocomplete results.
 
 FIXME: This property will be removed after the RecentObject refactor
 
 After the refactor, instead of checking this property
 we will check for the uuid property
 (that is going to be added in the class).
 
 The isNumber is currently used to differeniate the autocomplete
 results between the resolved /v1/user and the phone numbers in
 order to add a "Call: " prefix for the phone numbers case.
 */
@property (nonatomic) BOOL isNumber;

/**
 Note:
 
 To be used when a RecentObject has been partially loaded
 and the user resolution is pending. Typically this happens
 (or must only happen) at the GroupInfoViewController where
 we list the members of a group chat and when this VC is 
 presented before the UserResolver class finishes with the 
 resolutions of all the members.
 
 It also happens when we receive a new incoming message, or 
 a call ends and we have to create a new RecentObject.
 
 FIXME: This shouldn't be the case for any other case after the
 RecentObject refactor (e.g. single chat threads).
 */
@property (nonatomic) BOOL isPartiallyLoaded;

/**
 UI-related flag that is used to differentiate the 
 exact-match (autocomplete) entries that do not exist
 in the Directory search section results.
 */
@property (nonatomic) BOOL isExternal;

@property (nonatomic, weak) AddressBookContact *abContact;

@property (nonatomic, strong) NSString *contactInfoLabel;

// timestamp of last interaction
@property (nonatomic, setter = setUnixTimeStamp:)long unixTimeStamp;

@property (nonatomic, setter = setBurnDelayTimeOut:) long burnDelayDuration;
@property (nonatomic, setter = setShareLocationTime:)long shareLocationTime; // time to share location

// if burn hasnt been set - 0, set it to 24hrs - 1
@property (nonatomic, setter = sethasBurnBeenSet:) long hasBurnBeenSet;

/**
 The dictionary representation of the RecentObject
 containing all the necessary properties that
 need to be serialized in order to be saved in the
 database.
 
 @see DBManager saveRecentObject: method.

 @return The dictionary representation of the RecentObject
 */
- (NSDictionary *)dictionaryRepresentation;

// lastMsgNumber in AppRepository
// stores number of last message fetched from DB
@property (nonatomic) int lastMsgNumber;

#if HAS_DATA_RETENTION
// data retention enabled
@property (nonatomic, setter = setDREnabled:) BOOL drEnabled;
// data retention organization
@property (nonatomic, strong, setter = setDROrganization:) NSString *drOrganization;
@property (nonatomic, assign, setter = setDRTypeCode:) uint32_t drTypeCode; // bitfield of enabled DR types
@property (nonatomic, assign, setter = setDRBlockCode:) uint32_t drBlockCode; // bitfield of DR block types
#endif // HAS_DATA_RETENTION

@property (nonatomic, strong) NSMutableDictionary *conversationImages;
/*
 For 1:1 conversations deletes stored avatar from chat directory
 
 For groups deletes generated title avatar and iterates through all member avatars and checks if they are used anywhere else e.g. we have 1:1 conversation with this groups member or he's in other group with us. If avatar is not used anywhere else it's deleted
 */
-(void) deleteAvatars;

/*
 temporary last conversations object to display in conversations view
 
 */
@property (nonatomic, strong) ChatObject *lastConversationObject;//TODOGO fix, getFirst

/**
 Loads the last conversation (aka ChatObject) for the specific RecentObject.
 */
- (void)loadLastConversation;

@property (nonatomic, setter = setIsGroupRecent:) int isGroupRecent;
@property (nonatomic, setter=setHasGroupAvatarBeenSetExplicitly:)BOOL hasGroupAvatarBeenSetExplicitly;
@property (nonatomic, setter=setHasGroupNameBeenSetExplicitly:)BOOL hasGroupNameBeenSetExplicitly;

/**
 Check two RecentObjects for equality.
 
 If their uuid match, then they are equal.

 @param object The RecentObject to be compared
 @return YES if the two RecentObject instances are equal, NO otherwise
 */
- (BOOL)isEqual:(id)object;

/**
 Updates the current recent object with the values of
 another recent object with the same uuid.
 
 The values that get updated are:
 
 * displayAlias
 * displayName
 * displayOrganization
 * abContact

 @param recentObject The RecentObject that contains the new values
 */
- (void)updateWithRecent:(RecentObject *)recentObject;

@end
