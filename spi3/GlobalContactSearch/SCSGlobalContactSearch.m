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
//  SCSGlobalSearch.m
//  SPi3
//
//  Created by Stelios Petrakis on 17/03/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "SCSGlobalContactSearch.h"
#import "ContactsSearcher.h"
#import "DirectorySearcher.h"
#import "ChatUtilities.h"
#import "DBManager.h"
#import "RecentObject.h"
#import "SCPNotificationKeys.h"
#import "Reachability.h"
#import "UserService.h"
#import "SCSConstants.h"

@interface SCSGlobalContactSearch () <DirectoryResultsSearcher, AddressBookResultsSearcher>
{
    DirectorySearcher *_directorySearcher;
    ContactsSearcher *_contactsSearcher;
    
    int _activeSearches;
    
    BOOL _hasOutboundCallingPermission;
    BOOL _hasInternetConnection;
    
    NSString *_lastSearchText;
    SCSGlobalContactSearchFilter _lastFilter;
    
    BOOL _autocompleteLoaded;
    BOOL _forceShowAutocomplete;
    BOOL _directoryLoaded;
    RecentObject *_lastAutoCompleteRecent;
    NSMutableArray <RecentObject *> *_lastDirectoryRecents;
}

@end

@implementation SCSGlobalContactSearch

#pragma mark - Lifecycle

- (instancetype)init {
    
    if(self = [super init]) {
        
        _directorySearcher = [DirectorySearcher new];
        [_directorySearcher setDelegate:self];
        
        _contactsSearcher = [ContactsSearcher new];
        [_contactsSearcher setDelegate:self];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(userDidUpdate:)
                                                     name:kSCSUserServiceUserDidUpdateNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self dismissAllOperations];
}

#pragma mark - Notifications

- (void)userDidUpdate:(NSNotification *)notification {
    
    BOOL hasOutboundPSTNCallingPermission = ([UserService currentUser] ? [[UserService currentUser] hasPermission:UserPermission_OutboundPSTNCalling] : NO);
    
    if(hasOutboundPSTNCallingPermission == _hasOutboundCallingPermission)
        return;
    
    BOOL searchAddressBook = (_lastFilter & SCSGlobalContactSearchFilterAddressBook);
    
    if(!searchAddressBook)
        return;
    
    [self searchText:_lastSearchText
              filter:SCSGlobalContactSearchFilterAddressBook
         saveFilters:NO];
}

- (void)reachabilityChanged:(NSNotification *)notification {

    if([Reachability reachabilityForInternetConnection].currentReachabilityStatus == NotReachable)
        return;
    
    if(_hasInternetConnection)
        return;

    BOOL searchDirectory        = (_lastFilter & SCSGlobalContactSearchFilterDirectory);
    BOOL searchAutocomplete     = (_lastFilter & SCSGlobalContactSearchFilterAutocomplete);

    if(!searchDirectory && !searchAutocomplete)
        return;
    
    SCSGlobalContactSearchFilter newFilter = 0;
    
    if(searchDirectory)
        newFilter |= SCSGlobalContactSearchFilterDirectory;
    
    if(searchAutocomplete)
        newFilter |= SCSGlobalContactSearchFilterAutocomplete;
    
    [self searchText:_lastSearchText
              filter:newFilter
         saveFilters:NO];
}

#pragma mark - Public Interface

- (void)searchText:(NSString*)text filter:(SCSGlobalContactSearchFilter)filter {

    [self searchText:text filter:filter saveFilters:YES];
}

- (void)stopSearching {
    
    if(_activeSearches == 0)
        return;
    
    _activeSearches = 0;
    
    [self dismissAllOperations];
    
    [self checkForSearchFinished];
}

#pragma mark - Private

- (void)searchText:(NSString*)text filter:(SCSGlobalContactSearchFilter)filter saveFilters:(BOOL)saveFilters {
    
    _hasOutboundCallingPermission = ([UserService currentUser] ? [[UserService currentUser] hasPermission:UserPermission_OutboundPSTNCalling] : NO);
    _hasInternetConnection = ([Reachability reachabilityForInternetConnection].currentReachabilityStatus != NotReachable);
    
    if(saveFilters) {
        
        _lastSearchText = text;
        _lastFilter = filter;
    }
    
    _activeSearches = 0;
    
    [self dismissAllOperations];
    
    BOOL searchAddressBook          = (filter & SCSGlobalContactSearchFilterAddressBook);
    BOOL searchAddressBookSC        = (filter & SCSGlobalContactSearchFilterAddressBookSC);
    BOOL searchDirectory            = (filter & SCSGlobalContactSearchFilterDirectory);
    BOOL searchAllConversations     = (filter & SCSGlobalContactSearchFilterAllConversations);
    BOOL searchGroupConversations   = (filter & SCSGlobalContactSearchFilterGroupConversations);
    BOOL searchAutocomplete         = (filter & SCSGlobalContactSearchFilterAutocomplete);

    if(!searchAllConversations && !searchGroupConversations && !searchDirectory && !searchAddressBook && !searchAddressBookSC && !searchAutocomplete)
        return;
    
    if(self.delegate)
        [self.delegate scsGlobalContactSearchWillBeginSearching:self];
    
    if(searchAllConversations || searchGroupConversations)
        _activeSearches++;

    if(searchAddressBook)
        _activeSearches++;
    
    if(searchAddressBookSC)
        _activeSearches++;

    if(searchAutocomplete)
        _activeSearches++;
    
    if(searchDirectory)
        _activeSearches++;
    
    if(searchAllConversations || searchGroupConversations)
        [self searchInConversationsWithContactName:text
                                            filter:filter];
    
    if(searchAddressBook || searchAddressBookSC)
        [_contactsSearcher searchForContactsWithText:text
                                              filter:filter];
    
    if(searchDirectory || searchAutocomplete)
        [_directorySearcher searchForContactsWithText:text
                                               filter:filter];
}

- (void)dismissAllOperations {
    
    _forceShowAutocomplete = NO;
    _autocompleteLoaded = NO;
    _directoryLoaded = NO;
    
    @synchronized (self) {
        _lastAutoCompleteRecent = nil;
        _lastDirectoryRecents = nil;
    }
    
    [_directorySearcher dismissAllOperations];
    [_contactsSearcher dismissAllOperations];
}

- (void)searchInConversationsWithContactName:(NSString*)text filter:(SCSGlobalContactSearchFilter)filter {
    
    BOOL searchGroupConversations   = (filter & SCSGlobalContactSearchFilterGroupConversations);

    NSArray *fullRecentsArray = [[DBManager dBManagerInstance] getRecents];
    
    NSMutableArray *thisRecentsArray = [NSMutableArray new];
    
    BOOL doAnyGroupsExist = NO;
    
    for (RecentObject *recentObject in fullRecentsArray) {
    
        if(recentObject.isGroupRecent)
            doAnyGroupsExist = YES;
        
        if(searchGroupConversations && !recentObject.isGroupRecent)
            continue;
        
        BOOL shouldAdd = NO;
        
        if(text.length == 0) {
            
            shouldAdd = YES;
        }
        else if(recentObject.isGroupRecent) {

            if ([recentObject.displayName rangeOfString:text options:NSCaseInsensitiveSearch | NSAnchoredSearch].location != NSNotFound)
                shouldAdd = YES;
        }
        else {

            NSString *strippedName = [[ChatUtilities utilitiesInstance] removePeerInfo:recentObject.displayAlias lowerCase:YES];
            BOOL contactNameContainsText = ([strippedName rangeOfString:text options:NSCaseInsensitiveSearch].location != NSNotFound);
            
            if (contactNameContainsText)
                shouldAdd = YES;
            else if(recentObject.displayName) {
                
                BOOL contactDisplayNameContainsText = NO;
                NSArray *seperatedNames = [recentObject.displayName componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                
                NSMutableArray *allNames = [[NSMutableArray alloc ]init];
                [allNames addObjectsFromArray:seperatedNames];
                [allNames addObject:recentObject.displayName];
                
                for (NSString *name in allNames) {
                    
                    if ([name rangeOfString:text options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        
                        contactDisplayNameContainsText = YES;
                        break;
                    }
                }
                
                if(contactDisplayNameContainsText)
                    shouldAdd = YES;
            }
        }
        
        if(shouldAdd) {
            
            // Load the last conversation in order
            // to update the unixTimestamp properly
            // so that sorting is made correctly.
            [recentObject loadLastConversation];
            
            [thisRecentsArray addObject:recentObject];
        }
    }
    
    if(_activeSearches > 0)
        _activeSearches--;
    
    [self checkForSearchFinished];

    // Do not show the group conversations section
    // if there are no group conversations yet in general.
    if(searchGroupConversations && !doAnyGroupsExist)
        return;
    
    // For all conversations filter, sort by timestamp (unixTimestamp) DESC
    // For group only conversations, sort by group name (displayName) ASC
    [thisRecentsArray sortUsingComparator:^NSComparisonResult(RecentObject *firstRecent, RecentObject *secondRecent) {
        if(searchGroupConversations)
        {
            if(!firstRecent.displayName && !secondRecent.displayName)
                return (NSComparisonResult)NSOrderedSame;
            else if(!firstRecent.displayName)
                return (NSComparisonResult)NSOrderedAscending;
            else if(!secondRecent.displayName)
                return (NSComparisonResult)NSOrderedDescending;
            else
                return [firstRecent.displayName compare:secondRecent.displayName
                                                options:NSCaseInsensitiveSearch];
        } else
            return firstRecent.unixTimeStamp < secondRecent.unixTimeStamp;
    }];
    
    if(self.delegate)
        [self.delegate scsGlobalContactSearch:self
                            didReturnContacts:thisRecentsArray
                                     ofFilter:(searchGroupConversations ? SCSGlobalContactSearchFilterGroupConversations : SCSGlobalContactSearchFilterAllConversations)
                                forSearchText:text];
}

- (void)checkForSearchFinished {
    
    if(_activeSearches == 0 && self.delegate)
        [self.delegate scsGlobalContactSearchDidStopSearching:self];
}

- (BOOL)isRecentFoundInDirectory:(RecentObject *)recent {
    
    if(!recent)
        return NO;
    
    @synchronized (self) {
        
        BOOL foundInDirectory = NO;
        
        if(_lastDirectoryRecents && [_lastDirectoryRecents count] > 0) {
            
            for (RecentObject *directoryRecent in _lastDirectoryRecents) {
                
                if([directoryRecent isEqual:recent]) {
                    
                    foundInDirectory = YES;
                    break;
                }
            }
        }
        
        return foundInDirectory;
    }
}

- (void)postAutoCompleteRecentBasedOnDirectoryForSearchText:(NSString *)searchText {

    NSMutableArray *recents = [@[] mutableCopy];
    
    @synchronized (self) {
        
        if(_lastAutoCompleteRecent) {

            BOOL foundInDirectory = [self isRecentFoundInDirectory:_lastAutoCompleteRecent];
            
            [self markRecentAsExternal:_lastAutoCompleteRecent];
            
            if(_forceShowAutocomplete || !foundInDirectory)
                recents = [@[ _lastAutoCompleteRecent ] mutableCopy];
        }
    }
    
    if(self.delegate) {
        
        [self.delegate scsGlobalContactSearch:self
                            didReturnContacts:recents
                                     ofFilter:SCSGlobalContactSearchFilterAutocomplete
                                forSearchText:searchText];
    }
}

#pragma mark - DirectoryResultsSearcher

- (void)didReturnAutocompleteRecent:(RecentObject *)recent isPhoneNumber:(BOOL)isPhoneNumber forSearchText:(NSString *)searchText {
    
    if(![searchText isEqualToString:_lastSearchText])
        return;
    
    if(_activeSearches > 0)
        _activeSearches--;
    
    [self checkForSearchFinished];

    _autocompleteLoaded = YES;
    
    NSMutableArray *recents = nil;
    
    if(!recent)
        recents = [@[] mutableCopy];
    else
        recents = [@[ recent ] mutableCopy];

    @synchronized (self) {
        _lastAutoCompleteRecent = recent;
    }
    
    if(recent.isNumber)
        _forceShowAutocomplete = YES;
    
    if(isPhoneNumber) {

        if(self.delegate) {
            
            [self.delegate scsGlobalContactSearch:self
                                didReturnContacts:recents
                                         ofFilter:SCSGlobalContactSearchFilterAutocomplete
                                    forSearchText:searchText];
        }
    }
    else {

        if(_directoryLoaded) {
    
            [self markRecentAsExternal:recent];
            
            [self postAutoCompleteRecentBasedOnDirectoryForSearchText:searchText];
        }
    }
}

- (void)markRecentAsExternal:(RecentObject *)recent {
    
    if(!recent)
        return;
    
    if(recent.isNumber || [self isRecentFoundInDirectory:recent])
        return;
    
    // Check whether the user is in the same
    // organization as the provisioned user.
    NSString *userOrganization = [UserService currentUser].displayOrganization;
    
    // If they both do not have a organization or they are
    // part of the same organization then don't mark this
    // recent as an external one.
    if((!recent.displayOrganization && !userOrganization) ||
       (recent.displayOrganization && userOrganization && [recent.displayOrganization isEqualToString:userOrganization]))
        return;
    
    recent.isExternal = YES;
}

- (void)didReturnDirectoryRecents:(NSMutableArray<RecentObject *> *)recents forSearchText:(NSString *)searchText {

    if(![searchText isEqualToString:_lastSearchText])
        return;

    if(_activeSearches > 0)
        _activeSearches--;
    
    [self checkForSearchFinished];

    _directoryLoaded = YES;
    
    if(!recents)
        recents = [@[] mutableCopy];
    
    @synchronized (self) {
        _lastDirectoryRecents = recents;
    }
    
    if(_autocompleteLoaded)
        [self postAutoCompleteRecentBasedOnDirectoryForSearchText:searchText];
    
    if(self.delegate)
        [self.delegate scsGlobalContactSearch:self
                            didReturnContacts:recents
                                     ofFilter:SCSGlobalContactSearchFilterDirectory
                                forSearchText:searchText];
}

#pragma mark - AddressBookResultsSearcher

- (void) didReturnAddressBookContacts:(NSMutableArray<RecentObject *> *)recents forSearchText:(NSString *)searchText {
    
    if(![searchText isEqualToString:_lastSearchText])
        return;
    
    if(_activeSearches > 0)
        _activeSearches--;
    
    [self checkForSearchFinished];

    if(!recents)
        recents = [@[] mutableCopy];
    
    if(self.delegate)
        [self.delegate scsGlobalContactSearch:self
                            didReturnContacts:recents
                                     ofFilter:SCSGlobalContactSearchFilterAddressBook
                                forSearchText:searchText];
}

- (void)didReturnAddressBookSCContacts:(NSMutableArray<RecentObject *> *)recents forSearchText:(NSString *)searchText {
    
    if(![searchText isEqualToString:_lastSearchText])
        return;
    
    if(_activeSearches > 0)
        _activeSearches--;
    
    [self checkForSearchFinished];

    if(!recents)
        recents = [@[] mutableCopy];
    
    if(self.delegate)
        [self.delegate scsGlobalContactSearch:self
                            didReturnContacts:recents
                                     ofFilter:SCSGlobalContactSearchFilterAddressBookSC
                                forSearchText:searchText];
}

@end
