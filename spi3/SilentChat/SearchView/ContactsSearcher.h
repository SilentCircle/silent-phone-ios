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
#import "SCSGlobalContactSearch.h"
#import "RecentObject.h"

@protocol AddressBookResultsSearcher <NSObject>

/**
 Returns the array of found contacts
 in the local Address Book.

 @param recents The array of found contacts in the Address Book
 @param searchText The search text related to that result
 */
- (void)didReturnAddressBookContacts:(NSMutableArray <RecentObject *> *)recents forSearchText:(NSString *)searchText;

/**
 Returns the array of found Silent Circle contacts
 in the local Address Book.

 @param recents The array of found Silent Circle contacts in the Address Book
 @param searchText The search text related to that result
 */
- (void)didReturnAddressBookSCContacts:(NSMutableArray <RecentObject *> *)recents forSearchText:(NSString *)searchText;

@end

@interface ContactsSearcher : NSObject

/**
 Address Book search (local contacts and matched Silent Circle contacts)
 for users that match the search text.

 @param searchText The provided search query
 @param filter The filter to use. Valid values are SCSGlobalContactSearchFilterAddressBook and SCSGlobalContactSearchFilterAddressBookSC
 */
-(void)searchForContactsWithText:(NSString *)searchText filter:(SCSGlobalContactSearchFilter)filter;

/**
 Cancels any pending search operation.
 */
-(void)dismissAllOperations;

/**
 The delegate object that implements the AddressBookResultsSearcher protocol.
 
 In our case this is the SCSGlobalContactSearch instance method.
 */
@property (nonatomic, assign) id <AddressBookResultsSearcher> delegate;

@end
