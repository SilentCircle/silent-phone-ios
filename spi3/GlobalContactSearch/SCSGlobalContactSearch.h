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
//  SCSGlobalSearch.h
//  SPi3
//
//  Created by Stelios Petrakis on 17/03/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Filters regarding global search that can be used as bitmask
 */
typedef NS_OPTIONS(NSInteger, SCSGlobalContactSearchFilter) {
    /** 
     Address Book filter.
     
     Returns the contacts of the Address Book that match
     the search query and include contact info that is found
     in the SC directory or phone numbers that can be called
     from the current user, if he has the proper permission
     (UserPermission_OutboundPSTNCalling).
 
     Look @SCSGlobalContactSearchFilterAddressBookSC
     */
    SCSGlobalContactSearchFilterAddressBook         = (1 << 0),
    /** 
     Directory search filter.
     */
    SCSGlobalContactSearchFilterDirectory           = (1 << 1),
    /** 
     Conversation search filter for all conversation.
     */
    SCSGlobalContactSearchFilterAllConversations    = (1 << 2),
    /** 
     Conversation search filter for group conversations.
     */
    SCSGlobalContactSearchFilterGroupConversations  = (1 << 3),
    /**
     Address Book filter for matched Silent Circle users.
     
     If both SCSGlobalContactSearchFilterAddressBook and
     SCSGlobalContactSearchFilterAddressBookSC are provided
     as filters then the results of
     SCSGlobalContactSearchFilterConversations filter will
     only include the non SC contacts of the Address Book
     that match the query and can be called
     (if user has the Outbound PSTN Calling permission enabled).
     */
    SCSGlobalContactSearchFilterAddressBookSC       = (1 << 4),
    /** 
     Autocomplete (exact match) filter.
     */
    SCSGlobalContactSearchFilterAutocomplete        = (1 << 5)
};

@protocol SCSGlobalContactSearchDelegate;

/**
 SCSGlobalContactSearch is the class responsible of conducting the search for contacts
 given a search token and a filter.
 
 
 This class can search through the Address Book, the Remote Directory and the existing Conversations.
 
 
 SCSGlobalContactSearch provides convenient delegate methods via the SCSGlobalContactSearchDelegate protocol
 that notify the delegate when the search has begun, has ended and when the results for each of the filters
 are returned.
 */
@interface SCSGlobalContactSearch : NSObject

/** The delegate object.
 
 Set a delegate object, in order to get updates on the search status.
 
 The delegate is not retained.
 
 @see SCSGlobalContactSearchDelegate
 */
@property (nonatomic, weak) id<SCSGlobalContactSearchDelegate> delegate;

/**
 Begins a search given a text and a bitwise mask of filters.
 
 @param text The search token
 @param filter The bitwise mask of filters (e.g. SCSGlobalContactSearchFilterDirectory | SCSGlobalContactSearchFilterAllConversations etc)
 */
- (void)searchText:(NSString*)text filter:(SCSGlobalContactSearchFilter)filter;

/**
 Stops the current search and calls the scsGlobalContactSearchDidStopSearching: method.
*/
- (void)stopSearching;

@end

/**
 The SCSGlobalContactSearchDelegate protocol defines the delegate methods to be implemented in order
 to receive updates for the current status of the search.
 
 The delegate methods are not invoked by the main thread so you are resposible of dispatching
 to the main thread if you want to perform a UI change.
 */
@protocol SCSGlobalContactSearchDelegate <NSObject>

@required

/**
 Called when the search is about to begin.
 
 @param globalSearch The SCSGlobalContactSearch object calling the delegate method.
 */
- (void)scsGlobalContactSearchWillBeginSearching:(SCSGlobalContactSearch*)globalSearch;

/**
 Called when the search was finished.
 
 @param globalSearch The SCSGlobalContactSearch object calling the delegate method.
 */
- (void)scsGlobalContactSearchDidStopSearching:(SCSGlobalContactSearch*)globalSearch;

/**
 Called when the global search receives results for one of the filters provided in the searchText:filter: method.
 
 @param globalSearch The SCSGlobalContactSearch object calling the delegate method.
 @param contacts The array of either AddressBookContact objects in the case of SCSGlobalContactSearchFilterAddressBook and SCSGlobalContactSearchFilterDirectory filters or RecentObject objects in the case of SCSGlobalContactSearchFilterAllConversations and SCSGlobalContactSearchFilterGroupConversations filter.
 @param filter The filter associated with the contacts parameter.
 @param searchText The search text related to that result
 */
- (void)scsGlobalContactSearch:(SCSGlobalContactSearch*)globalSearch didReturnContacts:(NSMutableArray*)contacts ofFilter:(SCSGlobalContactSearchFilter)filter forSearchText:(NSString *)searchText;

@end
