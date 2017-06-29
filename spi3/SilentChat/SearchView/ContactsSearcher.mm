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
#import "ContactsSearcher.h"
#import "ChatUtilities.h"
#import "RecentObject.h"
#import "SCSContactsManager.h"
#import "AddressBookContact.h"
#import "UserService.h"
#import "SCPCallbackInterface.h"
#import "SCPNotificationKeys.h"

@implementation ContactsSearcher {
    
    NSOperationQueue *_contactSearchQueue;
    
    NSString *_lastSearchText;
    SCSGlobalContactSearchFilter _lastFilter;
    
    BOOL _isCancelled;
}

#pragma mark - Lifecycle

-(instancetype) init {
    
    if(self = [super init]) {
        
        _contactSearchQueue = [NSOperationQueue new];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(contactsUpdated:)
                                                     name:SCSContactsManagerAddressBookRefreshedNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(contactsUpdated:)
                                                     name:SCSContactsManagerSilentContactsLoadedNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self dismissAllOperations];
}

#pragma mark - Notifications

-(void)contactsUpdated:(NSNotification *)notification {
    
    if(_isCancelled)
        return;
    
    if(!_lastSearchText)
        return;
    
    if([notification.name isEqualToString:SCSContactsManagerSilentContactsLoadedNotification]) {
        
        BOOL searchAddressBookSC = (_lastFilter & SCSGlobalContactSearchFilterAddressBookSC);
        
        if(searchAddressBookSC)
            [self searchOperationWithText:_lastSearchText
                                   filter:SCSGlobalContactSearchFilterAddressBookSC];
        
    }
    else if([notification.name isEqualToString:SCSContactsManagerAddressBookRefreshedNotification]) {
        
        [self searchOperationWithText:_lastSearchText
                               filter:_lastFilter];
    }
}

#pragma mark - Private

-(void) searchOperationWithText:(NSString *)searchText filter:(SCSGlobalContactSearchFilter)filter {
    
    _isCancelled = NO;

    NSBlockOperation *blockOperation = [NSBlockOperation new];
    
    __weak NSBlockOperation *weakBlockOperation = blockOperation;
    __weak ContactsSearcher *weakSelf = self;
    
    [blockOperation addExecutionBlock:^{
        
        __strong NSBlockOperation *strongBlockOperation = weakBlockOperation;
        
        if(!strongBlockOperation)
            return;
        
        if([strongBlockOperation isCancelled])
            return;
        
        __strong ContactsSearcher *strongSelf = weakSelf;
        
        if(!strongSelf)
            return;

        SCSContactsManager *contactsManager = [SCSContactsManager sharedManager];
        
        BOOL searchTextIsEmpty      = (searchText == nil ? YES : [searchText isEqualToString:@""]);
        
        BOOL searchAddressBook      = (filter & SCSGlobalContactSearchFilterAddressBook);
        BOOL searchAddressBookSC    = (filter & SCSGlobalContactSearchFilterAddressBookSC);

        if(searchAddressBook) {

            NSMutableArray *matchedContacts = [NSMutableArray new];

            if(searchTextIsEmpty) {
                
                for(NSString *identifier in [contactsManager sortedAddressBookContacts]) {
                    
                    AddressBookContact *contact = [contactsManager contactForCNIdentifier:identifier];
                    
                    if([strongBlockOperation isCancelled])
                        return;
                    
                    [matchedContacts addObjectsFromArray:[strongSelf addRecentsFromContact:contact
                                                                           shouldExcludeSC:searchAddressBookSC
                                                                                searchText:searchText]];
                }
                
            }
            else {
                
                for(AddressBookContact *contact in [contactsManager addressBookContactsMatchingText:searchText]) {
                    
                    if([strongBlockOperation isCancelled])
                        return;
                    
                    [matchedContacts addObjectsFromArray:[strongSelf addRecentsFromContact:contact
                                                                           shouldExcludeSC:searchAddressBookSC
                                                                                searchText:searchText]];
                }
                
            }

            if([strongBlockOperation isCancelled])
                return;
            
            BOOL isLoading = ([matchedContacts count] == 0 && [contactsManager contactsAreLoading]);

            if(!isLoading &&
               strongSelf.delegate &&
               [strongSelf.delegate respondsToSelector:@selector(didReturnAddressBookContacts:forSearchText:)]) {
                
                [strongSelf.delegate didReturnAddressBookContacts:matchedContacts
                                                    forSearchText:searchText];
            }
        }
        
        if([strongBlockOperation isCancelled])
            return;
        
        if(searchAddressBookSC) {
            
            NSMutableArray *matchedSCContacts = [NSMutableArray new];
            
            for(AddressBookContact *contact in [contactsManager silentCircleContactsMatchingText:searchText]) {
                
                if([strongBlockOperation isCancelled])
                    return;
                
                [matchedSCContacts addObjectsFromArray:[strongSelf addRecentsFromContact:contact
                                                                         shouldExcludeSC:NO
                                                                              searchText:searchText]];
            }
            
            if([strongBlockOperation isCancelled])
                return;
            
            if(strongSelf.delegate &&
               [strongSelf.delegate respondsToSelector:@selector(didReturnAddressBookSCContacts:forSearchText:)]) {
                
                [strongSelf.delegate didReturnAddressBookSCContacts:matchedSCContacts
                                                      forSearchText:searchText];
            }
        }
    }];
    
    // cancel previous operations, add this operation
    [_contactSearchQueue cancelAllOperations];
    [_contactSearchQueue addOperation:blockOperation];
}

- (NSArray <RecentObject *> *)addRecentsFromContact:(AddressBookContact *)contact shouldExcludeSC:(BOOL)excludeSC searchText:(NSString *)searchText {
    
    if(!contact)
        return @[];
    
    SCSContactsManager *contactsManager = [SCSContactsManager sharedManager];
    BOOL hasOutboundPSTNCallingPermission = ([UserService currentUser] ? [[UserService currentUser] hasPermission:UserPermission_OutboundPSTNCalling] : NO);
    BOOL searchTextIsEmpty      = (searchText == nil ? YES : [searchText isEqualToString:@""]);
    
    // Filter out the SC matched contacts if
    // the SCSGlobalContactSearchFilterAddressBookSC
    // is also provided
    if(contact.uuid) {
        
        if(!excludeSC) {
            
            RecentObject *newRecent = [RecentObject new];
            newRecent.displayName = contact.fullName;
            newRecent.abContact = contact;
            newRecent.contactName = contact.uuid;
            newRecent.displayAlias = contact.displayAlias;
         
            return @[newRecent];
        }
    }
    
    BOOL matchedUsername = NO;
    
    if(searchTextIsEmpty)
        matchedUsername = YES;
    else if([contact.fullName rangeOfString:searchText
                                    options:NSCaseInsensitiveSearch].location != NSNotFound)
        matchedUsername = YES;
    else if(contact.companyName && [contact.companyName rangeOfString:searchText
                                                              options:NSCaseInsensitiveSearch].location != NSNotFound)
        matchedUsername = YES;
    
    NSMutableArray *matchedContacts = [NSMutableArray new];

    for (NSDictionary *contactInfoDict in contact.contactInfo) {
        
        NSString *contactInfo = [contactInfoDict objectForKey:SCSContactsManagerContactInfoValueKey];
        
        if(!contactInfo)
            continue;
        
        NSString *cleanedContactInfo = [contactsManager cleanContactInfo:contactInfo];
        
        if(!cleanedContactInfo)
            continue;
        
        if(!searchTextIsEmpty) {
            
            if([cleanedContactInfo rangeOfString:searchText
                                         options:NSCaseInsensitiveSearch | NSAnchoredSearch].location == NSNotFound && !matchedUsername)
                continue;
        }
        
        BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:cleanedContactInfo];
        
        if(!isNumber) {
            
            if(excludeSC)
                continue;
            else
            {
                BOOL isMatching = [contactsManager doesMatchCachedSilentContactWithInfo:cleanedContactInfo];
                
                if(!isMatching)
                    continue;
            }
        }
        else if(!hasOutboundPSTNCallingPermission)
            continue;
        
        NSString *contactLabel = [contactInfoDict objectForKey:SCSContactsManagerContactInfoLabelKey];
        
        RecentObject *newRecent = [RecentObject new];
        newRecent.displayName = contact.fullName;
        newRecent.abContact = contact;
        newRecent.contactInfoLabel = contactLabel;
        newRecent.contactName = [contactsManager cleanContactInfo:contactInfo];
        
        [matchedContacts addObject:newRecent];
    }

    return matchedContacts;
}

#pragma mark - Public

-(void)searchForContactsWithText:(NSString *)searchText filter:(SCSGlobalContactSearchFilter)filter {
    
    _isCancelled = NO;
    _lastSearchText = searchText;
    _lastFilter = filter;
    
    [self searchOperationWithText:searchText
                           filter:filter];
}

-(void)dismissAllOperations {

    _isCancelled = YES;
    [_contactSearchQueue cancelAllOperations];
}

@end
