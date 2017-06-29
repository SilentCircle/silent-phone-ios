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
//  SCSContactsManager.h
//  SPi3
//
//  Created by Stelios Petrakis on 05/11/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ContactsUI/ContactsUI.h>
#import "SystemPermissionManager.h"

@class AddressBookContact;
@class RecentObject;

typedef NS_ENUM(NSInteger, SCSContactInfoType) {

    SCSContactInfoTypeUnspecified,
    SCSContactInfoTypeEmailAddress,
    SCSContactInfoTypePhoneNumber,
    SCSContactInfoTypeSipAddress
};

/**
 Notification name for error while loading the Address Book (e.g. denial of permission)
 */
extern NSString *const SCSContactsManagerErrorLoadingAddressBookNotification;

/**
 Notification name when the address book has been refreshed (due to a change from a user in another app)
 */
extern NSString *const SCSContactsManagerAddressBookRefreshedNotification;

/**
 Notification name when silent contacts have been loaded from the Contact Discovery list
 */
extern NSString *const SCSContactsManagerSilentContactsLoadedNotification;

/**
 Notification name when a contact has been added in the favorites list
 */
extern NSString *const SCSContactsManagerFavoriteAddedNotification;

/**
 Notification name when a contact has been removed from the favorites list
 */
extern NSString *const SCSContactsManagerFavoriteRemovedNotification;

/**
 Notification name when favorite contacts have been swapped
 */
extern NSString *const SCSContactsManagerFavoriteSwappedNotification;

/**
 Dictionary key for the contact info array regarding the contact info label.
 */
extern NSString *const SCSContactsManagerContactInfoLabelKey;

/**
 Dictionary key for the contact info array regarding the contact info value.
 */
extern NSString *const SCSContactsManagerContactInfoValueKey;

/**
 SCSContactsManager is the manager class that handles contact loading from address book, favorites and silent contacts discovery.
 
 The class can be accessed through the singleton instance sharedManager.
 */
@interface SCSContactsManager : NSObject <CNContactViewControllerDelegate, SystemPermissionManagerDelegate>

/**
 Returns the singleton SCSContactsManager reference to use throughout the app.
 
 Do not initialize the SCSContactsManager class yourself.
 
 @return The SCSContactsManager singleton instance reference.
 */
+ (SCSContactsManager *)sharedManager;

/**
 Swaps a contact with another one based on their IDs from the contact list.
 
 @param favoriteContactId The first favorite contact id that we want to swap.
 @param otherFavoriteContactId The second favorte contact id that we want the first id to be swapped with.
 @return A boolean value indicating whether the swap was successful or not.
 */
- (BOOL)swapFavoriteId:(int)favoriteContactId withOtherFavoriteId:(int)otherFavoriteContactId;

/**
 Returns whether a given name and phone number pair exists in the favorites list.
 
 @param contactName The contact name we want to check.
 @param phoneNumber The contact phone number we want to check.
 @return A boolean value indicating whether the contact name/phone number exists in the favorites list
 */
- (BOOL)isFavoriteContactWithName:(NSString*)contactName phoneNumber:(NSString*)phoneNumber;

/**
 Adds a contact name and phone number pair in the contacts list.
 
 @param contactName The contact name we want to check.
 @param phoneNumber The contact phone number we want to check.
 @return A boolean value indicating whether the addition was successful or not.
 */
- (BOOL)addFavoriteContactWithName:(NSString*)contactName phoneNumber:(NSString*)phoneNumber;

/**
 Removes a favorite entry from the favorites list.
 
 @param favoriteContactId The favorite contact id of the contact we want to remove.
 @return A boolean value indicating whether the deletion was successful or not.
 */
- (BOOL)removeFavoriteContactWithId:(int)favoriteContactId;

/**
 Checks whether the given phone number exists in the cached Silent Circle contact discovery list.

 @param contactInfo The phone number we want to check the contact discovery list.

 @return YES if matches, NO otherwise.
 */
- (BOOL)doesMatchCachedSilentContactWithInfo:(NSString *)contactInfo;

/**
 Updates the internal Silent Circle hash cache and libzina with new contact infos.
 
 The method makes an API request to the server to find out which of the contact infos exist in the directory.

 @param contactInfos An array of strings containing contact infos
 @param completion  The completion block will fire as soon as the request completed.
 */
- (void)updateSilentCircleHashCacheWithContactInfos:(NSArray<NSString *> *)contactInfos;

/**
 Given a user info string it calls the completion block with the associated AddressBookContact from the user's
 address book. If there is no associated contact, the completion block has a nil argument.
 
 This method also requests the user image synchronously from the background thread.
 
 This is an asynchronous call.
 
 NOTE: Do not use this method to loop through contacts, in order to make contact search requests use the ContactSearcher class. 
 
 This method is to be used only when we need info for a particular contact.
 
 @param userInfo The user alias (can be a phone number, an email or a sip address)
 @param completion The completion block that is going to be called asynchronously.
 */
- (void)addressBookContactWithInfo:(NSString *)userInfo completion:(void (^)(AddressBookContact *contact))completion;

/**
 Searches through the Address Book contacts and returns an array containing AddressBookContact objects that
 contain the provided search text in their name or contact info array.

 Warning: This method blocks while searching, so be sure not to use it in the main thread.
 
 @param searchText The string to be used to search the address book.
 @return An array of AddressBookContact objects matching the search text.
 */
- (NSArray<AddressBookContact *> *)addressBookContactsMatchingText:(NSString *)searchText;

/**
 Searches through the favorite contacts of your address book and returns an array containing NSDictionary objects that
 contain the provided search text in their name or address fields.
 
 @param searchText The string to be used to search the address book.
 @return An array favorites matching the search text.
 */
- (NSArray *)favoriteContactsMatchingText:(NSString *)searchText;

/**
 Searches through the Silent Circle contacts of your address book and returns an array containing AddressBookContact objects that
 contain the provided search text in their name or contact info array.
 
 @param searchText The string to be used to search the address book.
 @return An array of AddressBookContact objects matching the search text.
 */
- (NSArray<AddressBookContact *> *) silentCircleContactsMatchingText:(NSString*)searchText;

/**
 Given a user info string it returns the associated AddressBookContact from the user's
 address book. If there is no associated contact it returns nil.
 
 This method is synchronous and may block the running thread.
 
 @param userInfo The user alias (can be a phone number, an email or a sip address)
 @return The associated AddressBookContact object.
 */
- (AddressBookContact*)contactWithInfo:(NSString*)userInfo;

/**
 Returns the contact identifier for an address book that matches the requested
 user alias.

 This method is synchronous and may block the running thread.
 
 @param userAlias The user alias (can be a phone number, an email or a sip address)

 @return The contact identifier for the found contact, or nil otherwise
 */
- (NSString*)cnIdentifierForContactWithAlias:(NSString*)userAlias;

/**
 Given a CN identifier, returns the associated AddressBookContact object.
 If there is no associated contact it returns nil.
 
 This method is synchronous and may block the running thread.
 
 @param identifier The CN identifier
 @return The associated AddressBookContact object.
 */
- (AddressBookContact *)contactForCNIdentifier:(NSString *)identifier;

/**
 Returns a new CNContact object containing the information found in the provided RecentObject.

 @param recentObject The provided RecentObject.

 @return The new CNContact object.
 */
- (CNContact *)addressBookContactWithRecentObject:(RecentObject *)recentObject;

/**
 Returns an updated CNContact object which contains the information given in the provided
 RecentObject, which have been filled in the appropriate fields of the existing contact object.

 @param contact      The existing contact object.
 @param recentObject The extra information to be used to update the existing contact object.

 @return The updated contact object.
 */
- (CNContact *)updateContact:(CNContact *)contact withRecentObject:(RecentObject *)recentObject;

/**
 Returns the type of contact info (email, phone or sip address depending
 on the contact info value given.

 @param contactInfoValue The string representing the contact info value.

 @return The contact info type
 
 @see SCSContactInfoType
 */
- (SCSContactInfoType)typeForContactInfo:(NSString *)contactInfoValue;

/**
 Cleans the contact info given by removing any malformed characters (in case of a phone number)
 or stripping any suffixes and prefixes in case of a username / sip email

 @param userInfo The user info that needs a clean up.
 @return The cleaned user info
 */
- (NSString *)cleanContactInfo:(NSString *)userInfo;

/**
 Updates the abContact property of the RecentObject if it matches
 an Address Book contact in user's local Address Book.

 @param recent The local conversation object.
 @return YES if the abContact property has changed, NO otherwise.
 */
- (BOOL)linkConversationWithContact:(RecentObject *)recent;

/**
 Updates internal Zina cache with the information
 returned by v1/user API call.

 @param userData The NSDictionary of the JSON response of /v1/user call
 @return YES if Zina cache has been updated, NO otherwise
 */
- (BOOL)informZinaWithUserData:(NSDictionary *)userData;

/**
 Provides an array of Favorite contacts as NSDictionary entries.
 */
@property (nonatomic, strong, readonly) NSArray *favoriteContacts;

/**
 Provides an array of Silent Circle contacts as NSString identifiers
 */
@property (nonatomic, strong, readonly) NSSet *silentCircleContacts;

/**
 Provides a alphabetic sorted array of address book contacts as NSString identifiers
 */
@property (nonatomic, strong, readonly) NSArray *sortedAddressBookContacts;

/**
 Provides dictionary of address book contacts: 
 
 key-> identifier
 value -> AddressBookContact object
 */
@property (nonatomic, strong, readonly) NSDictionary *addressBook;

/**
 Contacts are getting populated from the address book
 */
@property (nonatomic, readonly) BOOL contactsAreLoading;

@end
