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
//  SCSContactsManager.m
//  SPi3
//
//  Created by Stelios Petrakis on 05/11/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//
#import <Contacts/Contacts.h>
#import <UIKit/UIKit.h>

#import "SCSContactsManager.h"

#import "ChatUtilities.h"
#import "CTListBase.h"
#import "CTEditBase.h"
#import "CTRecentsItem.h"
#import "RecentObject.h"
#import "SCloudConstants.h" // For the ErrorDomain
#import "SCPNotificationKeys.h"
#import "AddressBookContact.h"
#import "SCSPhoneHelper.h"
#import "SCPCallbackInterface.h"
#import "SCFileManager.h"
#import "Reachability.h"
#import "DBManager.h"
#import "SCSAvatarManager.h"

// Categories
#import "UIImage+ApplicationImages.h"

// For Contact Discovery (update libzina)
#include "storage/NameLookup.h"

#define scsContactsManagerHashLongHexSize       64  // Stored locally
#define scsContactsManagerHashShortHexSize      6   // Sent to server
#define scsContactsManagerMaxNumberOfHashesSent 500

// Used for Favorites
#define _T_WO_GUI

const char* sendEngMsg(void *pEng, const char *p);
int fixNR(const char *in, char *out, int iLenMax);

NSString *toNSFromTB(CTStrBase *b);
NSString *toNSFromTBN(CTStrBase *b, int N);

NSString *translateServManager(CTEditBase *b);
NSString *checkNrPatternsManager(NSString *ns);

NSString *checkNrPatternsManager(NSString *ns){
    
    char buf[64];
    if(fixNR(ns.UTF8String,&buf[0],63)){
        return [NSString stringWithUTF8String:&buf[0]];
    }
    return ns;
}

NSString *translateServManager(CTEditBase *b){
    
    char bufTmp[128];
    bufTmp[0]='.';
    bufTmp[1]='t';
    bufTmp[2]=' ';
    bufTmp[3]=0;
    
    if(b->getLen() == 0)
        return toNSFromTB(b);
    
    getText(&bufTmp[3],125,b);
    const char *p=sendEngMsg(NULL,&bufTmp[0]);
    if(p && p[0]){
        return [NSString stringWithUTF8String:p];
    }
    return toNSFromTB(b);
}

static  NSString *toNS(CTEditBase *b, int N=0){
    if(N)return toNSFromTBN(b,N);
    return toNSFromTB(b);
}

NSString *const SCSContactsManagerErrorLoadingAddressBookNotification   = @"SCSContactsManagerErrorLoadingAddressBookNotification";
NSString *const SCSContactsManagerSilentContactsLoadedNotification      = @"SCSContactsManagerSilentContactsLoadedNotification";
NSString *const SCSContactsManagerFavoriteAddedNotification             = @"SCSContactsManagerFavoriteAddedNotification";
NSString *const SCSContactsManagerFavoriteRemovedNotification           = @"SCSContactsManagerFavoriteRemovedNotification";
NSString *const SCSContactsManagerFavoriteSwappedNotification           = @"SCSContactsManagerFavoriteSwappedNotification";
NSString *const SCSContactsManagerAddressBookRefreshedNotification      = @"SCSContactsManagerAddressBookRefreshedNotification";

NSString *const SCSContactsManagerContactInfoLabelKey                   = @"SCSContactsManagerContactInfoLabelKey";
NSString *const SCSContactsManagerContactInfoValueKey                   = @"SCSContactsManagerContactInfoValueKey";

@interface SCSContactsManager () {
    
    CTRecentsList *_favoritesList;
    NSArray *_favoriteContacts;
    
    // Dictionary of all contacts
    // key: CNContact identifier => value: the AddressBookContact object
    NSDictionary *_allAddressBookContacts;

    // Dictionary of the disk cached SC contacts
    // key: full hash => value: the AddressBookContact object
    NSDictionary *_cachedSilentCircleContacts;
    // key: CNContact identifier => value: the AddressBookContact object
    NSDictionary *_allCachedContacts;
    
    // NSArray with the keys of all address book contacts sorted alphabetically
    NSArray *_sortedAddressBookContacts;

    // Dictionary with all address book contacts, containing contact info hashes used for Contact Discovery
    // key: full hash (length: scsContactsManagerHashHexSize) -> value: CNContact identifier
    NSDictionary *_contactDiscoveryHashes;
    
    // hashes returned from server, used for offline boolean validation (length: 20)
    // (if the hash exists in this set -> this means it matches a SC user)
    NSMutableSet *_matchedDiscoveryHashes;
    
    // Set with the keys of all address book contacts existing in Silent Circle directory
    NSSet *_silentCircleContacts;
    
    NSCharacterSet *_badPhoneCharacters;
    NSMutableCharacterSet *_trimmingCharacters;
    
    NSOperationQueue *_contactsQueue;
    NSOperationQueue *_contactDiscoveryQueue;
    
    BOOL _contactsLoaded;
    
    CNContactSortOrder _lastSortOrder;
    
    BOOL _saving;
    
    BOOL _addressBookChanged;
    NSDate *_previouslyIssuedNotification;
    
    BOOL _contactsAreLoading;
    
    BOOL _hasReceivedContactDiscoveryResponse;
    
    NSURL *_cachedFileURL;
}

@end

@implementation SCSContactsManager

#pragma mark - Class methods

+ (SCSContactsManager *)sharedManager {
    
    static SCSContactsManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    
    return sharedInstance;
}

#pragma mark - Lifecycle

- (id)init {
    
    if(self = [super init]) {

        _favoriteContacts = [NSArray array];
        _silentCircleContacts = [NSSet set];
        _sortedAddressBookContacts = [NSArray array];
        _matchedDiscoveryHashes = [NSMutableSet set];
        
        [SCFileManager setupSilentContactsCache];
        
        _cachedFileURL = [[SCFileManager silentContactsCacheDirectoryURL] URLByAppendingPathComponent:@"cache.json"];

        _badPhoneCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"+*#1234567890"] invertedSet];
        
        _trimmingCharacters = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
        [_trimmingCharacters formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];

        _contactsQueue = [NSOperationQueue new];
        [_contactsQueue setMaxConcurrentOperationCount:1];
        
        _contactDiscoveryQueue = [NSOperationQueue new];
        [_contactDiscoveryQueue setMaxConcurrentOperationCount:1];
        
        _lastSortOrder = [[CNContactsUserDefaults sharedDefaults] sortOrder];

        if([UIApplication sharedApplication].applicationState != UIApplicationStateActive)
            _contactsLoaded = NO;
        else {
            
            _contactsLoaded = YES;
            
            [self loadAll];
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(willUpdateContacts:)
                                                     name:CNContactStoreDidChangeNotification
                                                   object:nil];
        

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];

    }
    
    return self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public Interface

- (NSString *)cleanContactInfo:(NSString *)userInfo {
    
    if(!userInfo)
        return nil;

    // Lowercase
    userInfo = [userInfo lowercaseString];

    // Trim bad characters (newline, whitespace, control characters)
    userInfo = [userInfo stringByTrimmingCharactersInSet:_trimmingCharacters];

    // Remove phone characters if the contact info is a phone number
    if([[ChatUtilities utilitiesInstance] isNumber:userInfo])
        return [[userInfo componentsSeparatedByCharactersInSet:_badPhoneCharacters] componentsJoinedByString:@""];
    
    // Remove any suffixes (@sip.silentcircle.net)
    userInfo = [[ChatUtilities utilitiesInstance] removePeerInfo:userInfo
                                                       lowerCase:NO];
    
    NSString *sipPrefix = @"sip:";
    NSString *silentPhonePrefix = @"silentphone:";
    
    // Remove any prefixes
    if([userInfo hasPrefix:sipPrefix])
        userInfo = [userInfo substringFromIndex:[sipPrefix length]];
    else if([userInfo hasPrefix:silentPhonePrefix])
        userInfo = [userInfo substringFromIndex:[silentPhonePrefix length]];
    
    return userInfo;
}

- (BOOL)contactsAreLoading {
    
    return _contactsAreLoading;
}

- (BOOL)swapFavoriteId:(int)favoriteContactId withOtherFavoriteId:(int)otherFavoriteContactId {
 
    CTRecentsItem *f=_favoritesList->getByIndex(favoriteContactId);
    
    if(!f)
        return NO;
    
    CTRecentsItem *t=_favoritesList->getByIndex(otherFavoriteContactId);
    if(!t || f==t)
        return NO;
    
    CTList *l=_favoritesList->getList();
    _favoritesList->enableAutoSave(0);
    
    if(t && otherFavoriteContactId<favoriteContactId)t=(CTRecentsItem *)l->getPrev(t);
    
    l->remove(f,0);
    
    if(otherFavoriteContactId==0)
        l->addToRoot(f);
    else {
        
        if(!t) {
            
            if(favoriteContactId>otherFavoriteContactId)
                l->addToRoot(f);
            else
                l->addToTail(f);
        }
        else
            l->addAfter(t,f);
    }
    
    _favoritesList->enableAutoSave(1);
    _favoritesList->save();
    
    [self loadFavorites];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SCSContactsManagerFavoriteSwappedNotification
                                                        object:self];
    
    return YES;
}

- (BOOL)isFavoriteContactWithName:(NSString *)contactName phoneNumber:(NSString *)phoneNumber {
    
    CTRecentsItem *n = [self getRecentItemWithName:contactName phoneNumber:phoneNumber];
    
    int addToFavorites(CTRecentsItem *i, void *fav, int iFind);
    
    BOOL isFavorite = (addToFavorites(n,NULL,1) == 1);
    
    delete n;
    
    return isFavorite;
}

- (BOOL)addFavoriteContactWithName:(NSString*)contactName phoneNumber:(NSString*)phoneNumber {
    
    CTRecentsItem *n = [self getRecentItemWithName:contactName phoneNumber:phoneNumber];
    
    int addToFavorites(CTRecentsItem *i, void *fav, int iFind);
    
    BOOL added = (addToFavorites(n,NULL,0) == 1);

    delete n;
    
    if(added) {
    
        [self loadFavorites];
    
        [[NSNotificationCenter defaultCenter] postNotificationName:SCSContactsManagerFavoriteAddedNotification
                                                            object:self];
    }
    
    return added;
}

- (BOOL)removeFavoriteContactWithId:(int)favoriteContactId {

    int removed = _favoritesList->removeByIndex(favoriteContactId);
    
    if(removed < 0)
        return NO;
    
    _favoritesList->activateAll();
    
    [self loadFavorites];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SCSContactsManagerFavoriteRemovedNotification
                                                        object:self];
    
    return YES;
}

- (NSArray*)favoriteContacts {
    return _favoriteContacts;
}

- (NSSet*)silentCircleContacts {
    
    @synchronized (_silentCircleContacts) {
        return _silentCircleContacts ;
    }
}

- (NSArray*)addressBookContacts {
    
    @synchronized(_allAddressBookContacts) {
        return _sortedAddressBookContacts;
    }
}

- (NSDictionary*)addressBook {
    
    @synchronized(_allAddressBookContacts) {
        return _allAddressBookContacts;
    }
}

- (BOOL)doesMatchCachedSilentContactWithInfo:(NSString *)contactInfo {
    
    if(!contactInfo)
        return NO;

    NSString *longHash = [self longHashForContactWithInfo:contactInfo];
    NSString *shortHash = [longHash substringToIndex:scsContactsManagerHashShortHexSize];
    NSPredicate *predicate  = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", shortHash];

    @synchronized (_silentCircleContacts) {

        NSSet *matches = [_matchedDiscoveryHashes filteredSetUsingPredicate:predicate];

        return ([matches count] == 1);
    }
}

- (void)updateSilentCircleHashCacheWithContactInfos:(NSArray<NSString *> *)contactInfos {
    
    if(!contactInfos)
        return;
    
    NSMutableArray *hashes = [NSMutableArray new];
    
    for(NSString *contactInfo in contactInfos) {
        
        NSString *longHash = [self longHashForContactWithInfo:contactInfo];
        NSString *shortHash = [longHash substringToIndex:scsContactsManagerHashShortHexSize];

        if(shortHash)
            [hashes addObject:shortHash];
    }
    
    if([hashes count] == 0)
        return;
    
    NSDictionary *arguments = @{ @"contacts" : hashes };
    
    __weak SCSContactsManager *weakSelf = self;
    
    [Switchboard.networkManager apiRequestInEndpoint:SCPNetworkManagerEndpointV2ContactsValidate
                                              method:SCPNetworkManagerMethodPOST
                                           arguments:arguments
                                          completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {
         
                                              if(error)
                                                  return;
                                              
                                              NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                                              
                                              if(![responseDictionary objectForKey:@"contacts"])
                                                  return;
                                              
                                              NSDictionary *contacts = [responseDictionary objectForKey:@"contacts"];
                                              
                                              @synchronized (_silentCircleContacts) {
                                                  [_matchedDiscoveryHashes addObjectsFromArray:[contacts allKeys]];
                                              }
                                              
                                              __strong SCSContactsManager *strongSelf = weakSelf;
                                              
                                              if(!strongSelf)
                                                  return;
                                              
                                              [[contacts allKeys] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                                                  
                                                  NSString *shortHashFromServer     = (NSString *)obj;
                                                  NSDictionary *userData            = (NSDictionary *)[contacts objectForKey:shortHashFromServer];
                                                  
                                                  // Update UserResolver cache
                                                  RecentObject *validatedRecent = [[RecentObject alloc] initWithJSON:userData];
                                                  
                                                  if(validatedRecent) {
                                                      
                                                      [strongSelf linkConversationWithContact:validatedRecent];
                                                      
                                                      [Switchboard.userResolver donateRecentToCache:validatedRecent];
                                                  }
                                                  
                                                  [strongSelf informZinaWithUserData:userData];
                                              }];
                                          }];
}

- (void)addressBookContactWithInfo:(NSString *)userInfo completion:(void (^)(AddressBookContact *contact))completion {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        AddressBookContact *contact = [self contactWithInfo:userInfo];
        [contact requestContactImageSynchronously];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if(completion)
                completion(contact);
        });
    });
}

- (AddressBookContact *)contactWithInfo:(NSString*)userInfo {
    
    NSString *identifier = [self cnIdentifierForContactWithAlias:userInfo];
    
    if(!identifier)
        return nil;
    
    return [self contactForCNIdentifier:identifier];
}

- (AddressBookContact *)contactForCNIdentifier:(NSString *)identifier {
    
    if(!_contactsAreLoading) {
        
        @synchronized(_allAddressBookContacts) {
            
            AddressBookContact *contact = (AddressBookContact *)[_allAddressBookContacts objectForKey:identifier];
            
            if(contact)
                return contact;
        }
    }
    
    @synchronized (_silentCircleContacts) {
        
        if(_allCachedContacts && [_allCachedContacts objectForKey:identifier])
            return [_allCachedContacts objectForKey:identifier];
    }
    
    return nil;
}

- (CNContact *)updateContact:(CNContact *)contact withRecentObject:(RecentObject *)recentObject {
    
    CNMutableContact *mutableContact = [contact mutableCopy];
    
    NSArray *contactInfo = [self contactInfoForNewContactWithName:recentObject.contactName];
    
    [self fillContact:&mutableContact
             withInfo:contactInfo];
    
    UIImage *contactImage = [AvatarManager avatarImageForConversationObject:recentObject size:eAvatarSizeFull];

    if (!mutableContact.imageData && contactImage)
        mutableContact.imageData = UIImagePNGRepresentation(contactImage);

    return mutableContact;
}

- (CNContact *)addressBookContactWithRecentObject:(RecentObject *)recentObject {

    NSString *firstName = @"";
    NSString *lastName  = @"";
    
    NSArray *displayNameComponents = [recentObject.displayName componentsSeparatedByString:@" "];
    
    if([displayNameComponents count] > 0) {
        
        firstName = displayNameComponents[0];
        
        if([displayNameComponents count] > 1) {
            
            for(NSUInteger i = 1; i < [displayNameComponents count]; i++)
                lastName = [lastName stringByAppendingString:[NSString stringWithFormat:@" %@", [displayNameComponents objectAtIndex:i]]];
        }
    }
    else
        firstName = recentObject.displayName;
    
    CNMutableContact *contact = [CNMutableContact new];
    
    contact.givenName = [firstName stringByTrimmingCharactersInSet:_trimmingCharacters];
    contact.familyName = [lastName stringByTrimmingCharactersInSet:_trimmingCharacters];

    NSArray *contactInfo = [self contactInfoForNewContactWithName:recentObject.displayAlias];
    
    [self fillContact:&contact
             withInfo:contactInfo];
    
    UIImage *contactImage = [AvatarManager avatarImageForConversationObject:recentObject size:eAvatarSizeFull];
    if (contactImage)
        contact.imageData = UIImagePNGRepresentation(contactImage);
    
    return contact;
}

- (SCSContactInfoType)typeForContactInfo:(NSString *)contactInfoValue {
    
    ChatUtilities *sharedInstance = [ChatUtilities utilitiesInstance];
    
    if ([sharedInstance isNumber:contactInfoValue])
        return SCSContactInfoTypePhoneNumber;
    else if([sharedInstance isEmail:contactInfoValue] && ![sharedInstance isSipEmail:contactInfoValue])
        return SCSContactInfoTypeEmailAddress;
    else
        return SCSContactInfoTypeSipAddress;
}


- (NSArray<AddressBookContact *> *)addressBookContactsMatchingText:(NSString *)searchText {
    
    @synchronized (_allAddressBookContacts) {
        
        NSMutableArray *matchedContacts = [NSMutableArray new];
        
        for (NSString *identifier in _sortedAddressBookContacts) {
            
            AddressBookContact *contact = [self contactForCNIdentifier:identifier];
            
            if(!contact)
                continue;
            
            if ([self searchText:searchText
                     matchesName:contact.fullName
                         address:contact.searchString
                     companyName:contact.companyName]) {
                
                [matchedContacts addObject:contact];
            }
        }
        
        return matchedContacts;
    }
}

-(NSArray *) favoriteContactsMatchingText:(NSString *)searchText {
    
    NSMutableArray *matchedFavorites = [NSMutableArray new];
    
    for(NSDictionary *favUser in _favoriteContacts) {
        
        if(![favUser objectForKey:@"name"])
            continue;
        
        if(![favUser objectForKey:@"addresssearchstring"])
            continue;
        
        if ([self searchText:searchText
                 matchesName:[favUser objectForKey:@"name"]
                     address:[favUser objectForKey:@"addresssearchstring"]
                 companyName:nil]) {
            
            [matchedFavorites addObject:favUser];
        }
    }
    
    return matchedFavorites;
}

- (NSArray<AddressBookContact *> *)silentCircleContactsMatchingText:(NSString*)searchText {
    
    NSMutableArray *matchedSilentContacts = [NSMutableArray new];
    
    @synchronized (_silentCircleContacts) {

        BOOL returnAll = NO;
        
        if(!searchText)
            returnAll = YES;
        else if([searchText isEqualToString:@""])
            returnAll = YES;
        
        for (NSString *identifier in _silentCircleContacts) {
            
            AddressBookContact *contact = [self contactForCNIdentifier:identifier];

            if(!contact)
                continue;
            
            if(returnAll || [self searchText:searchText
                                 matchesName:contact.fullName
                                     address:contact.searchString
                                 companyName:contact.companyName]) {
                
                [matchedSilentContacts addObject:contact];
            }
        }
    }
    
    [matchedSilentContacts sortUsingComparator:^NSComparisonResult(AddressBookContact *obj1, AddressBookContact *obj2) {
        return [obj1.sortByName compare:obj2.sortByName
                                options:NSCaseInsensitiveSearch];
    }];
    
    return matchedSilentContacts;
}


#pragma mark - Notifications

- (void)appDidBecomeActive:(NSNotification *)notification {
    
    if(!_contactsLoaded) {
        
        _contactsLoaded = YES;
        
        [self loadAll];
    }
    
    CNContactSortOrder currentSortOrder = [[CNContactsUserDefaults sharedDefaults] sortOrder];
    
    if(currentSortOrder != _lastSortOrder) {
        
        _lastSortOrder = currentSortOrder;
        
        [self loadAll];
    }
}

- (void)willUpdateContacts:(NSNotification *)notification {
    
    // Check if the Address Book changed notification has been issued the past 10 secs
    // If not, then a significant time has passed since the last issued notification, so
    // we believe there was a change in the Address Book and issue the SCSContactsManagerAddressBookRefreshedNotification
    // Otherwise we make the check inside every AddressBookContact we parse
    BOOL hasSignificantTimePassed = (_previouslyIssuedNotification ? [[NSDate date] timeIntervalSinceDate:_previouslyIssuedNotification] > 10.0f : YES);
    
    _addressBookChanged             = hasSignificantTimePassed;
    _previouslyIssuedNotification   = [NSDate date];
    
    [self loadContacts:^{
        
        if(!_addressBookChanged)
            return;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SCSContactsManagerAddressBookRefreshedNotification
                                                                object:self];
        });
    }];
}

- (void)reachabilityChanged:(NSNotification *)notification {
 
    if(_hasReceivedContactDiscoveryResponse)
        return;
    
    [self requestSilentContactHashes];
}

#pragma mark - Private Interface

- (NSArray *)contactInfoForNewContactWithName:(NSString *)contactName {
    
    contactName = [[ChatUtilities utilitiesInstance] removePeerInfo:contactName
                                                          lowerCase:NO];
    
    SCSContactInfoType type = [self typeForContactInfo:contactName];
    
    NSString *label = @"Silent Phone";
    
    if(type == SCSContactInfoTypePhoneNumber)
        label = @"Phone";
    else if(type == SCSContactInfoTypeEmailAddress)
        label = @"Email";
    
    NSString *address = contactName;
    
    if(type == SCSContactInfoTypeSipAddress)
        address = [NSString stringWithFormat:@"silentphone:%@", address];
    
    return @[@{
                 SCSContactsManagerContactInfoLabelKey : label,
                 SCSContactsManagerContactInfoValueKey : address
                 }];
}

- (void)fillContact:(CNMutableContact **)contact withInfo:(NSArray *)contactInfo {
    
    NSMutableArray *phoneNumbers = [(* contact).phoneNumbers mutableCopy];
    NSMutableArray *urlAddresses = [(* contact).urlAddresses mutableCopy];
    NSMutableArray *emailAddresses = [(* contact).emailAddresses mutableCopy];
    
    for(NSInteger index = 0; index < [contactInfo count]; index++) {
        
        NSDictionary *editedContactInfo = [contactInfo objectAtIndex:index];
        NSString *editedValue           = [editedContactInfo objectForKey:SCSContactsManagerContactInfoValueKey];
        NSString *editedLabel           = [editedContactInfo objectForKey:SCSContactsManagerContactInfoLabelKey];
        
        if([editedValue isEqualToString:@""])
            continue;
        
        SCSContactInfoType type = [self typeForContactInfo:editedValue];
        
        if(type == SCSContactInfoTypeEmailAddress) {
            
            CNLabeledValue *emailAddress = [CNLabeledValue labeledValueWithLabel:editedLabel
                                                                           value:editedValue];
            [emailAddresses addObject:emailAddress];
            
        }else if(type == SCSContactInfoTypePhoneNumber) {
            
            CNLabeledValue *phoneNumber = [CNLabeledValue labeledValueWithLabel:editedLabel
                                                                          value:[CNPhoneNumber phoneNumberWithStringValue:editedValue]];
            [phoneNumbers addObject:phoneNumber];
            
        } else {
            
            CNLabeledValue *urlAddress = [CNLabeledValue labeledValueWithLabel:editedLabel
                                                                         value:editedValue];
            [urlAddresses addObject:urlAddress];
        }
    }
    
    (*contact).phoneNumbers = phoneNumbers;
    (*contact).urlAddresses = urlAddresses;
    (*contact).emailAddresses = emailAddresses;
}

- (NSString*)cnIdentifierForContactWithAlias:(NSString*)userAlias {

    if([userAlias length] == 0)
        return nil;

    NSString *longHash = [self longHashForContactWithInfo:userAlias];

    if(!_contactsAreLoading) {
        
        @synchronized(_allAddressBookContacts) {
            
            NSString *identifier = (NSString *)[_contactDiscoveryHashes objectForKey:longHash];
            
            if(identifier)
                return identifier;
        }
    }

    @synchronized (_silentCircleContacts) {
        
        if(_cachedSilentCircleContacts && [_cachedSilentCircleContacts objectForKey:longHash])
            return [_cachedSilentCircleContacts objectForKey:longHash];
    }
    
    return nil;
}

- (void)loadAll {
    
    [self loadCachedSilentContacts];
    [self loadFavorites];
    [self loadContacts:^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SCSContactsManagerAddressBookRefreshedNotification
                                                                object:self];
        });
    }];
}

- (void)loadCachedSilentContacts {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        if (![SystemPermissionManager hasPermission:SystemPermission_Contacts])
            return;
            
        NSData *cachedJSONData = [NSData dataWithContentsOfURL:_cachedFileURL];
        
        if(!cachedJSONData)
            return;
            
        id responseObject = [NSJSONSerialization JSONObjectWithData:cachedJSONData
                                                            options:kNilOptions
                                                              error:nil];
        
        if(!responseObject)
            return;
        
        if(![responseObject isKindOfClass:[NSArray class]])
            return;
        
        if([(NSArray *)responseObject count] == 0)
            return;
        
        CNContactStore * contactStore = [CNContactStore new];
        NSArray * keysToFetch =@[CNContactFamilyNameKey,
                                 CNContactGivenNameKey,
                                 CNContactMiddleNameKey,
                                 CNContactNicknameKey,
                                 CNContactOrganizationNameKey,
                                 CNContactPhoneNumbersKey,
                                 CNContactUrlAddressesKey,
                                 CNContactInstantMessageAddressesKey,
                                 CNContactEmailAddressesKey];

        NSMutableDictionary *cdDictionary = [NSMutableDictionary new];
        NSMutableDictionary *allCachedContacts = [NSMutableDictionary new];
        
        for(NSDictionary *serializedContact in (NSArray *)responseObject) {
            
            CNContact *contact = [contactStore unifiedContactWithIdentifier:[serializedContact objectForKey:@"cnIdentifier"]
                                                                keysToFetch:keysToFetch error:nil];
            
            if(!contact)
                continue;
            
            NSMutableArray *hashArray = [NSMutableArray new];
            
            AddressBookContact *parsedContact = [self parseContactWithCNContact:contact
                                                                      hashArray:&hashArray];
            [parsedContact setUuid:[serializedContact objectForKey:@"uuid"]];
            [parsedContact setDisplayAlias:[serializedContact objectForKey:@"display_alias"]];
            
            [allCachedContacts setObject:parsedContact
                                  forKey:[serializedContact objectForKey:@"cnIdentifier"]];
            
            for(NSString *hash in hashArray) {
                
                [cdDictionary setObject:[serializedContact objectForKey:@"cnIdentifier"]
                                 forKey:hash];                
            }
            
            // Update UserResolver cache
            RecentObject *validatedRecent = [[RecentObject alloc] initWithJSON:serializedContact];
            
            if(validatedRecent)
                [Switchboard.userResolver donateRecentToCache:validatedRecent];
        }
        
        @synchronized (_silentCircleContacts) {
            
            _allCachedContacts = allCachedContacts;
            _cachedSilentCircleContacts = cdDictionary;
            _silentCircleContacts = [NSSet setWithArray:[allCachedContacts allKeys]];
            _matchedDiscoveryHashes = [NSMutableSet setWithArray:[cdDictionary allKeys]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:SCSContactsManagerSilentContactsLoadedNotification
                                                                object:self];
        });
    });
}

- (void)loadFavorites {
    
    _favoritesList = CTRecentsList::sharedFavorites();
    _favoritesList->load();

    int favoritesCount = _favoritesList->countVisItems();

    NSMutableArray *favoritesData = [NSMutableArray array];

    for(int i = 0; i < favoritesCount; i++) {
        
        CTRecentsItem *favItem = _favoritesList->getByIndex(i);
        
        NSString *address = checkNrPatternsManager(toNS(&favItem->peerAddr, 0));
        
        if([[ChatUtilities utilitiesInstance] isSipEmail:address]) {

            // Find if there is an '@' symbol in the address
            favItem->findAT_char();
            
            // Keep the position of the @ symbol in
            // order to cut up to that symbol when displaying
            // the address. If the @ symbol is not found the
            // value equals to the length of the address
            int peerAddressLength = favItem->iAtFoundInPeer;
            
            address = checkNrPatternsManager(toNS(&favItem->peerAddr, peerAddressLength));
        }
        
        NSString *name;
        
        if(favItem->name.getLen() > 0) {
            
            char utf8Name[64];
            int utf8NameLength = 63;
            
            favItem->name.getTextUtf8(&utf8Name[0], &utf8NameLength);
            
            name = [NSString stringWithUTF8String:utf8Name];
            
        } else {
            
            name = address;
        }
        
        [favoritesData addObject:@{
                                   @"fav_id" : @(i),
                                   @"name": name,
                                   @"address": address,
                                   @"addresssearchstring": [self cleanContactInfo:address]
                                   }];
    }
    
    _favoriteContacts = [NSArray arrayWithArray:favoritesData];
}

#pragma mark - SystemPermissionManagerDelegate
- (void)performPermissionCheck {
    CNEntityType entityType = CNEntityTypeContacts;
    if ([CNContactStore authorizationStatusForEntityType:entityType] == CNAuthorizationStatusNotDetermined) {
        CNContactStore * contactStore = [CNContactStore new];
        [contactStore requestAccessForEntityType:entityType completionHandler:^(BOOL granted, NSError * _Nullable error) {
            [SystemPermissionManager permissionCheckComplete:self];
            if (granted)
                [self loadAll]; // reload contacts (both cached and non-cached)
        }];
    } else
        [SystemPermissionManager permissionCheckComplete:self];
}

- (BOOL)hasPermission {
    return ([CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts] == CNAuthorizationStatusAuthorized);
}

- (void)loadContacts:(void (^)())addressBookContactsLoadedCompletionBlock {
    if ([self hasPermission])
        [self fetchContactsFromContactsFramework:addressBookContactsLoadedCompletionBlock];
    else
        [[NSNotificationCenter defaultCenter] postNotificationName:SCSContactsManagerErrorLoadingAddressBookNotification object:self];
}

- (void)fetchContactsFromContactsFramework:(void (^)())addressBookContactsLoadedCompletionBlock {
    
    _contactsAreLoading = YES;
    
    NSBlockOperation *blockOperation = [NSBlockOperation new];
    
    __weak NSBlockOperation *weakBlockOperation = blockOperation;
    __weak SCSContactsManager *weakSelf = self;
    
    [blockOperation addExecutionBlock:^{
        
        __strong NSBlockOperation *strongBlockOperation = weakBlockOperation;
        __strong SCSContactsManager *strongSelf = weakSelf;
        
        if(!strongSelf)
            return;
        
        if(!strongBlockOperation)
            return;
        
        if([strongBlockOperation isCancelled])
            return;
        
        NSError* contactError;
        CNContactStore* addressBook = [CNContactStore new];
        
        [addressBook containersMatchingPredicate:[CNContainer predicateForContainersWithIdentifiers: @[addressBook.defaultContainerIdentifier]]
                                           error:&contactError];
        
        NSArray * keysToFetch =@[CNContactFamilyNameKey,
                                 CNContactGivenNameKey,
                                 CNContactMiddleNameKey,
                                 CNContactNicknameKey,
                                 CNContactOrganizationNameKey,
                                 CNContactPhoneNumbersKey,
                                 CNContactUrlAddressesKey,
                                 CNContactInstantMessageAddressesKey,
                                 CNContactEmailAddressesKey];
        
        CNContactFetchRequest * request = [[CNContactFetchRequest alloc] initWithKeysToFetch:keysToFetch];
        [request setSortOrder:[[CNContactsUserDefaults sharedDefaults] sortOrder]];
        
        NSMutableDictionary *contacts = [NSMutableDictionary new];
        NSMutableDictionary *cdDictionary = [NSMutableDictionary new];
        
        [addressBook enumerateContactsWithFetchRequest:request
                                                 error:&contactError
                                            usingBlock:^(CNContact * __nonnull contact, BOOL * __nonnull stop){
        
                                                if([strongBlockOperation isCancelled]) {
                                                    
                                                    *stop = YES;
                                                    return;
                                                }
                                                
                                                NSMutableArray *hashArray = [NSMutableArray new];
                                                
                                                AddressBookContact *parsedContact = [strongSelf parseContactWithCNContact:contact
                                                                                                                hashArray:&hashArray];
                                                if (parsedContact)
                                                    [contacts setObject:parsedContact
                                                                 forKey:contact.identifier];
                                                
                                                for(NSString *hash in hashArray) {
                                                    
                                                    if (contact.identifier)
                                                        [cdDictionary setObject:contact.identifier
                                                                         forKey:hash];
                                                }
                                            }];
        
        @synchronized(_allAddressBookContacts) {
            
            _contactDiscoveryHashes = cdDictionary;
            
            _allAddressBookContacts = contacts;
            
            _sortedAddressBookContacts = [_allAddressBookContacts keysSortedByValueUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
                
                AddressBookContact *c1 = (AddressBookContact *)obj1;
                AddressBookContact *c2 = (AddressBookContact *)obj2;
                return [c1.sortByName compare:c2.sortByName options:NSCaseInsensitiveSearch];
            }];
        }
        
        if([strongBlockOperation isCancelled])
            return;
        
        _contactsAreLoading = NO;
        
        if(addressBookContactsLoadedCompletionBlock)
            addressBookContactsLoadedCompletionBlock();

        [strongSelf linkConversationsWithContacts];
        
        [strongSelf requestSilentContactHashes];
    }];
    
    [_contactsQueue cancelAllOperations];
    [_contactsQueue addOperation:blockOperation];
}

- (AddressBookContact *)parseContactWithCNContact:(CNContact *)contact hashArray:(NSMutableArray **)hashArray {
    
    AddressBookContact *addressBookContact = [AddressBookContact new];
    
    addressBookContact.cnIdentifier = contact.identifier;
    addressBookContact.firstName    = contact.givenName;
    addressBookContact.middleName   = contact.middleName;
    addressBookContact.lastName     = contact.familyName;
    addressBookContact.companyName  = contact.organizationName;

    NSString *displayName = nil;
    NSString *sortByName = nil;
    
    if([contact.givenName length] > 0 && [contact.middleName length] && [contact.familyName length] > 0)
        displayName = [NSString stringWithFormat:@"%@ %@ %@", contact.givenName, contact.middleName, contact.familyName];
    else if([contact.givenName length] > 0 && [contact.familyName length] > 0)
        displayName = [NSString stringWithFormat:@"%@ %@", contact.givenName, contact.familyName];
    else if([contact.givenName length] > 0)
        displayName = contact.givenName;
    else if([contact.familyName length] > 0)
        displayName = contact.familyName;
    else if([contact.nickname length] > 0)
        displayName = contact.nickname;
    else if([contact.organizationName length] > 0)
        displayName = contact.organizationName;
    else
        displayName = NSLocalizedString(@"No name", nil);

    NSMutableArray *nameComponents = [NSMutableArray new];

    if(addressBookContact.firstName && [addressBookContact.firstName length] > 0)
        [nameComponents addObject:addressBookContact.firstName];

    if(addressBookContact.middleName && [addressBookContact.middleName length] > 0)
        [nameComponents addObject:addressBookContact.middleName];

    if(addressBookContact.lastName && [addressBookContact.lastName length] > 0)
        [nameComponents addObject:addressBookContact.lastName];

    CNContactSortOrder sortOrder = [[CNContactsUserDefaults sharedDefaults] sortOrder];
    
    if([nameComponents count] > 0) {
        
        // Sort by fist name
        if(sortOrder == CNContactSortOrderGivenName)
            sortByName = [nameComponents componentsJoinedByString:@" "];
        // Sort by last name
        else if(sortOrder == CNContactSortOrderFamilyName)
            sortByName = [[[nameComponents reverseObjectEnumerator] allObjects] componentsJoinedByString:@" "];
    }
    
    if(!sortByName)
        sortByName = displayName;
    
    addressBookContact.fullName = displayName;
    addressBookContact.sortByName = sortByName;
    
    NSMutableArray *contactInfo         = [NSMutableArray new];
    NSMutableArray *addedContactInfo    = [NSMutableArray new];

    for (CNLabeledValue *phoneNumber in contact.phoneNumbers) {
        
        CNPhoneNumber *contactPhoneNumber = (CNPhoneNumber *)phoneNumber.value;
        
        NSString *cleanedPhoneNumber = [self cleanContactInfo:contactPhoneNumber.stringValue];

        // Don't add the same value twice
        if (![addedContactInfo containsObject:cleanedPhoneNumber] && ![cleanedPhoneNumber isEqualToString:@""]) {
        
            NSString *phoneLabel = NSLocalizedString(@"Phone", nil);
            
            if(phoneNumber.label) {
                
                NSString *tempPhoneLabel = [NSString stringWithFormat:@"%@", [CNLabeledValue localizedStringForLabel:phoneNumber.label]];
                
                if(tempPhoneLabel && ![tempPhoneLabel isEqualToString:@""])
                    phoneLabel = tempPhoneLabel;
            }
            
            NSDictionary *phoneNumberDict = @{
                                               SCSContactsManagerContactInfoLabelKey         : phoneLabel,
                                               SCSContactsManagerContactInfoValueKey         : contactPhoneNumber.stringValue
                                               };
            
            [contactInfo addObject:phoneNumberDict];
            
            NSString *hash = [self longHashForContactWithInfo:cleanedPhoneNumber];

            [(*hashArray) addObject:hash];
            
            [addedContactInfo addObject:cleanedPhoneNumber];
        }
    }
    
    for (CNLabeledValue *imAddressLabeledValue in contact.instantMessageAddresses) {
        
        CNInstantMessageAddress *imAddress = (CNInstantMessageAddress *)imAddressLabeledValue.value;
        
        NSString *cleanedIMAddress = imAddress.username;
        
        if(![imAddress.service isEqualToString:@"Silent Phone"] && ![imAddress.service isEqualToString:@"Silent Circle"])
            continue;
        
        if (cleanedIMAddress && ![addedContactInfo containsObject:cleanedIMAddress] && ![cleanedIMAddress isEqualToString:@""]) {
            
            NSString *imLabel = NSLocalizedString(@"IM", nil);
            
            if(imAddress.service && ![imAddress.service isEqualToString:@""])
                imLabel = imAddress.service;
            
            NSDictionary *imAddressDict = @{
                                            SCSContactsManagerContactInfoLabelKey         : imLabel,
                                            SCSContactsManagerContactInfoValueKey         : imAddress.username
                                             };
            
            [contactInfo addObject:imAddressDict];
            
            NSString *hash = [self longHashForContactWithInfo:cleanedIMAddress];
            
            [(*hashArray) addObject:hash];
            
            [addedContactInfo addObject:cleanedIMAddress];
        }
    }
    
    for (CNLabeledValue *urlAddress in contact.urlAddresses) {
        
        NSString *urlValueString = [NSString stringWithFormat:@"%@",urlAddress.value];
        
        if ([urlValueString rangeOfString:@"sip:"].location == NSNotFound &&
            [urlValueString rangeOfString:@"silentphone:"].location == NSNotFound)
            continue;
        
        NSString *cleanedURLAddress = [self cleanContactInfo:urlValueString];
        
        // Don't add the same value twice
        if (![addedContactInfo containsObject:cleanedURLAddress] && ![cleanedURLAddress isEqualToString:@""]) {
            
            NSString *urlLabel = NSLocalizedString(@"URL", nil);
            
            if(urlAddress.label) {
                
                NSString *tempUrlLabel = [NSString stringWithFormat:@"%@", [CNLabeledValue localizedStringForLabel:urlAddress.label]];
                
                if(tempUrlLabel && ![tempUrlLabel isEqualToString:@""])
                    urlLabel = tempUrlLabel;
            }
            
            NSDictionary *urlAddressDict = @{
                                             SCSContactsManagerContactInfoLabelKey         : urlLabel,
                                             SCSContactsManagerContactInfoValueKey         : urlValueString
                                               };
            
            [contactInfo addObject:urlAddressDict];
            
            NSString *hash = [self longHashForContactWithInfo:cleanedURLAddress];
            
            [(*hashArray) addObject:hash];

            [addedContactInfo addObject:cleanedURLAddress];
        }
    }

    for (CNLabeledValue *emailAddress in contact.emailAddresses) {
        
        NSString *emailValueString = [NSString stringWithFormat:@"%@",emailAddress.value];

        NSString *cleanedEmailAddress = [self cleanContactInfo:emailValueString];
        
        // Don't add the same value twice
        if (![addedContactInfo containsObject:cleanedEmailAddress] && ![cleanedEmailAddress isEqualToString:@""]) {

            NSString *emailLabel = NSLocalizedString(@"Email", nil);
            
            if(emailAddress.label) {
                
                NSString *tempEmailLabel = [NSString stringWithFormat:@"%@", [CNLabeledValue localizedStringForLabel:emailAddress.label]];
                
                if(tempEmailLabel && ![tempEmailLabel isEqualToString:@""])
                    emailLabel = tempEmailLabel;
            }
        
            NSDictionary *urlAddressDict = @{
                                             SCSContactsManagerContactInfoLabelKey         : emailLabel,
                                             SCSContactsManagerContactInfoValueKey         : emailValueString
                                             };
            [contactInfo addObject:urlAddressDict];
            
            NSString *hash = [self longHashForContactWithInfo:cleanedEmailAddress];
            
            [(*hashArray) addObject:hash];
            
            [addedContactInfo addObject:cleanedEmailAddress];
        }
    }
    
    if([addedContactInfo count] > 0)
        addressBookContact.searchString = [addedContactInfo componentsJoinedByString:@"|"];
    
    if([contactInfo count] > 0)
        addressBookContact.contactInfo = contactInfo;

    // Check if address book has really changed
    // in order to issue the notification
    // (Sometimes the CN Notification concerning Address Book changes gets fired more than once for a single change)
    if(!_addressBookChanged) {
        
        AddressBookContact *previousContact = [self contactForCNIdentifier:addressBookContact.cnIdentifier];
        
        if(previousContact)
            _addressBookChanged = ![previousContact isEqualToAddressBookContact:addressBookContact];
    }
    
    return addressBookContact;
}

#pragma mark - CD (Contact Discovery)

- (NSString *)longHashForContactWithInfo:(NSString *)contactInfo {
    
    if(!contactInfo)
        return nil;
    
    contactInfo = [self cleanContactInfo:contactInfo];
    
    SCSContactInfoType type = [self typeForContactInfo:contactInfo];

    // Add dial assist for phone numbers if needed
    if(type == SCSContactInfoTypePhoneNumber)
        contactInfo = [[SCSPhoneHelper sharedPhoneHelper] phoneNumberWithDialAssist:contactInfo];
    
    const char *_Nullable contactInfoString = contactInfo.UTF8String;
    
    void sha256(unsigned char *data, unsigned int data_length, unsigned char *digest);
    void bin2Hex(unsigned char *Bin, char * Hex ,int iBinLen);
    
    char hashhex[scsContactsManagerHashLongHexSize + 4];
    unsigned char hashbin[scsContactsManagerHashLongHexSize / 2 +1];
    
    sha256((unsigned char *)&contactInfoString[0], (int)strlen(contactInfoString), hashbin);
    
    bin2Hex(hashbin, hashhex, scsContactsManagerHashLongHexSize/2);
        
    return [NSString stringWithUTF8String:hashhex];
}

- (BOOL)informZinaWithUserData:(NSDictionary *)userData {
    
    NSString *uuid                  = (NSString *)[userData objectForKey:@"uuid"];
    NSString *displayAlias          = (NSString *)[userData objectForKey:@"display_alias"];
    
    if(![Switchboard isZinaReady])
        return NO;
    
    if(uuid && displayAlias && [uuid length] > 0 && [displayAlias length] > 0) {
        
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userData
                                                           options:0
                                                             error:nil];
        
        if(jsonData) {
            
            NSString *jsonString = [[NSString alloc] initWithData:jsonData
                                                         encoding:NSUTF8StringEncoding];
            
            // Inform libzina
            zina::NameLookup* nameCache = zina::NameLookup::getInstance();
            
            zina::NameLookup::AliasAdd ret = nameCache->addAliasToUuid(displayAlias.UTF8String,
                                                                       uuid.UTF8String,
                                                                       jsonString.UTF8String);
            
            return (ret > 0);
        }
        
        return NO;
    }
    
    return NO;
}

- (BOOL)linkConversationWithContact:(RecentObject *)recent {
    
    if(_contactsAreLoading)
        return NO;
    
    if(!recent.displayAlias)
        return NO;
    
    AddressBookContact *previousContact = recent.abContact;
    
    // We always want to update this property
    // as user might have removed the contact
    // that was previously on his Address Book.
    recent.abContact = [self contactWithInfo:recent.displayAlias];

    BOOL updated = (previousContact != recent.abContact);
    
    if(updated) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification
                                                                object:self userInfo:@{kSCPRecentObjectDictionaryKey:recent}];
        });
    }
    
    return updated;
}

- (void)linkConversationsWithContacts {

    // Link cached recents
    NSArray <RecentObject *>* cachedRecents = [Switchboard.userResolver cachedRecents];

    if(cachedRecents) {
        
        for(RecentObject *recent in cachedRecents)
            [self linkConversationWithContact:recent];
    }
    
    // Link conversations
    NSArray <RecentObject *>* conversations = [[DBManager dBManagerInstance] getRecents];
    
    if(conversations) {
        
        for(RecentObject *recent in conversations)
            [self linkConversationWithContact:recent];
    }
}

- (void)requestSilentContactHashes {
    
    if([Reachability reachabilityForInternetConnection].currentReachabilityStatus == NotReachable)
        return;
    
    if(!_contactDiscoveryHashes)
        return;
    
    if([[_contactDiscoveryHashes allKeys] count] == 0)
        return;
    
    NSBlockOperation *blockOperation = [NSBlockOperation new];
    
    __weak NSBlockOperation *weakBlockOperation = blockOperation;
    __weak SCSContactsManager *weakSelf = self;
    
    [blockOperation addExecutionBlock:^{
        
        __strong NSBlockOperation *strongBlockOperation = weakBlockOperation;
        __strong SCSContactsManager *strongSelf = weakSelf;

        if(!strongSelf)
            return;
        
        if(!strongBlockOperation)
            return;
        
        if([strongBlockOperation isCancelled])
            return;
        
        NSMutableArray *shortHashes = [NSMutableArray new];
        [shortHashes addObject:[NSMutableArray new]];
        
        __block NSMutableArray *shortHashesChunk = [shortHashes lastObject];
        
        [[_contactDiscoveryHashes allKeys] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            NSString *longHash = (NSString *)obj;
            
            [shortHashesChunk addObject:[longHash substringToIndex:scsContactsManagerHashShortHexSize]];
            
            if([shortHashesChunk count] >= scsContactsManagerMaxNumberOfHashesSent) {
                
                [shortHashes addObject:[NSMutableArray new]];
                shortHashesChunk = [shortHashes lastObject];
            }
        }];
        
        NSSet *silentContactsSet = [NSSet new];
        
        for(NSArray *shortHashChunk in shortHashes) {
            
            if([strongBlockOperation isCancelled])
                return;
            
            if(!shortHashChunk)
                continue;
            
            if([shortHashChunk count] == 0)
                continue;
            
            NSDictionary *arguments = @{ @"contacts" : shortHashChunk };
            
            NSError *error = nil;
            NSHTTPURLResponse *httpResponse = nil;
            
            id responseObject = [Switchboard.networkManager synchronousApiRequestInEndpoint:SCPNetworkManagerEndpointV2ContactsValidate
                                                                                     method:SCPNetworkManagerMethodPOST
                                                                                  arguments:arguments
                                                                                      error:&error
                                                                               httpResponse:&httpResponse];
            
            if([strongBlockOperation isCancelled])
                return;
            
            if(error)
                continue;
            
            if(!responseObject)
                continue;
                
            if(![responseObject isKindOfClass:[NSDictionary class]])
                continue;
            
            NSDictionary *contacts = [(NSDictionary *)responseObject objectForKey:@"contacts"];
            
            if(!contacts)
                continue;
            
            _hasReceivedContactDiscoveryResponse = YES;
            
            silentContactsSet = [silentContactsSet setByAddingObjectsFromSet:[strongSelf processContactDiscoveryResponse:contacts]];
        }

        if(!_hasReceivedContactDiscoveryResponse)
            return;
        
        @synchronized (_silentCircleContacts) {
            
            _cachedSilentCircleContacts = nil;
            _allCachedContacts = nil;
            _silentCircleContacts = silentContactsSet;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:SCSContactsManagerSilentContactsLoadedNotification
                                                                    object:self];
            });
        
            NSMutableArray *matchedSerializedContacts = [NSMutableArray new];
            
            for (NSString *identifier in _silentCircleContacts) {
                
                AddressBookContact *contact = [self contactForCNIdentifier:identifier];
                
                if(!contact)
                    continue;
                
                if(!contact.uuid)
                    continue;
                
                if(!contact.displayAlias)
                    continue;
                
                [matchedSerializedContacts addObject:@{
                                                       @"cnIdentifier"  : contact.cnIdentifier,
                                                       @"display_alias" : contact.displayAlias,
                                                       @"uuid"          : contact.uuid
                                                       }];
            }
            
            if([matchedSerializedContacts count] > 0) {
                
                NSData* jsonData = [NSJSONSerialization dataWithJSONObject:matchedSerializedContacts
                                                                   options:kNilOptions
                                                                     error:nil];
                
                if(jsonData)
                    [jsonData writeToURL:_cachedFileURL
                              atomically:YES];
            }
        }
    }];
    
    [_contactDiscoveryQueue cancelAllOperations];
    [_contactDiscoveryQueue addOperation:blockOperation];
}

- (NSSet *)processContactDiscoveryResponse:(NSDictionary *)contacts {

    NSArray *longHashes = nil;
    NSMutableSet *silentContactsSet = [NSMutableSet set];
    
    @synchronized (_allAddressBookContacts) {
        
        longHashes = [_contactDiscoveryHashes allKeys];
    }
    
    @synchronized (_silentCircleContacts) {
        
        [_matchedDiscoveryHashes addObjectsFromArray:[contacts allKeys]];
    }
    
    [[contacts allKeys] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {

        NSString *shortHash = (NSString *)obj;
        
        // Find the full hash in the _contactDiscoveryHashes to get the contact
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", shortHash];

        if(!longHashes)
            return;
        
        NSArray *matches = [longHashes filteredArrayUsingPredicate:predicate];
        
        if([matches count] > 0) {
            
            NSString *contactIdentifier = nil;
            
            @synchronized (_silentCircleContacts) {
                contactIdentifier = [_contactDiscoveryHashes objectForKey:[matches objectAtIndex:0]];
            }
            
            if(contactIdentifier) {
                
                // Update the Address Book contact
                @synchronized(_allAddressBookContacts) {
                    
                    AddressBookContact *contact = [_allAddressBookContacts objectForKey:contactIdentifier];
                
                    if(contact) {
                        
                        NSDictionary *userData  = (NSDictionary *)[contacts objectForKey:shortHash];

                        NSString *uuid          = (NSString *)[userData objectForKey:@"uuid"];
                        NSString *displayAlias  = (NSString *)[userData objectForKey:@"display_alias"];
                        
                        [contact setUuid:uuid];
                        [contact setDisplayAlias:displayAlias];
                        
                        [[ChatUtilities utilitiesInstance] donateInteractionWithAddressBookContact:contact];
                        
                        // Update UserResolver cache
                        RecentObject *validatedRecent = [[RecentObject alloc] initWithJSON:userData];
                        
                        if(validatedRecent)
                            [Switchboard.userResolver donateRecentToCache:validatedRecent];
                    }
                }
            
                [silentContactsSet addObject:contactIdentifier];
            }
        }
    }];
    
    return silentContactsSet;
}

#pragma mark - Helper methods

- (CTRecentsItem*)getRecentItemWithName:(NSString*)contactName phoneNumber:(NSString *)phoneNumber {
    
    CTRecentsItem *n = new CTRecentsItem();
    
    if(!n)
        return NULL;
    
    n->name.setText(contactName.UTF8String);
    n->peerAddr.setText(phoneNumber.UTF8String);
    
    return n;
}


- (BOOL) searchText:(NSString*)searchText matchesName:(NSString*)contactName address:(NSString*)contactAddress companyName:(NSString *)companyName {
    
    BOOL matched = NO;
    
    if(searchText.length == 0)
        matched = YES;
    else if(contactName && [contactName rangeOfString:searchText
                                              options:NSCaseInsensitiveSearch].location != NSNotFound)
        matched = YES;
    else if(contactAddress && [contactAddress rangeOfString:searchText
                                                    options:NSCaseInsensitiveSearch].location != NSNotFound)
        matched = YES;
    else if(companyName && [companyName rangeOfString:searchText
                                              options:NSCaseInsensitiveSearch].location != NSNotFound)
        matched = YES;
    
    return matched;
}

@end
