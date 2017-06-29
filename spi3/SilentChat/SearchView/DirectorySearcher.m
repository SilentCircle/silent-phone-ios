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
#import "DirectorySearcher.h"
#import "ChatUtilities.h"
#import "SCPCallbackInterface.h"
#import "SCSContactsManager.h"
#import "NSDictionaryExtras.h"
#import "SCPNotificationKeys.h"
#import "SCSPhoneHelper.h"

@implementation DirectorySearcher {

    NSOperationQueue *_autocompleteQueue;

    NSURLSessionTask *_task;
    BOOL _isCancelled;
    
    NSString *_lastSearchText;
    SCSGlobalContactSearchFilter _lastFilter;
}

#pragma mark - Lifecycle

-(instancetype) init {
    
    if(self = [super init]) {
        
        _autocompleteQueue  = [NSOperationQueue new];
        [_autocompleteQueue setMaxConcurrentOperationCount:1];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(contactsUpdated:)
                                                     name:SCSContactsManagerAddressBookRefreshedNotification
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
    
    [self searchOperationWithText:_lastSearchText
                           filter:_lastFilter];
}

#pragma mark - Private

-(void)searchOperationWithText:(NSString *)searchText filter:(SCSGlobalContactSearchFilter)filter {

    NSString *originalSearchText = searchText;
    
    [self dismissAllOperations];
    
    _isCancelled = NO;
    
    BOOL searchAutocomplete = (filter & SCSGlobalContactSearchFilterAutocomplete);
    BOOL searchDirectory    = (filter & SCSGlobalContactSearchFilterDirectory);

    NSDataDetector *phoneNumberDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypePhoneNumber
                                                                          error:nil];
    
    NSTextCheckingResult *phoneNumberResult = [phoneNumberDetector firstMatchInString:searchText
                                                                              options:0
                                                                                range:NSMakeRange(0, searchText.length)];
    
    if(phoneNumberResult.phoneNumber)
        searchText = [[SCSPhoneHelper sharedPhoneHelper] phoneNumberWithDialAssist:phoneNumberResult.phoneNumber];
    
    __weak typeof (self) weakSelf = self;

    if(searchAutocomplete) {
        
        RecentObject *phoneNumberRecent = nil;
        
        if([SCPCallHelper isMagicNumber:searchText] ||
           [SCPCallHelper isStarCall:searchText] ||
           [searchText hasPrefix:@"+"] ||
           phoneNumberResult.phoneNumber) {
            
            phoneNumberRecent = [RecentObject new];
            phoneNumberRecent.isNumber      = YES;
            phoneNumberRecent.contactName   = searchText;
            phoneNumberRecent.displayAlias  = searchText;
            phoneNumberRecent.displayName   = searchText;
            
            [[SCSContactsManager sharedManager] linkConversationWithContact:phoneNumberRecent];

            if(self.delegate &&
               [self.delegate respondsToSelector:@selector(didReturnAutocompleteRecent:isPhoneNumber:forSearchText:)]) {
                
                [self.delegate didReturnAutocompleteRecent:phoneNumberRecent
                                             isPhoneNumber:YES
                                             forSearchText:originalSearchText];
            }
        }

        if (searchText.length < 2) {
            
            if(self.delegate &&
               [self.delegate respondsToSelector:@selector(didReturnAutocompleteRecent:isPhoneNumber:forSearchText:)]) {
                
                [self.delegate didReturnAutocompleteRecent:nil
                                             isPhoneNumber:NO
                                             forSearchText:originalSearchText];
            }
        }
        else {
        
            NSBlockOperation *blockOperation = [NSBlockOperation new];
            
            __weak NSBlockOperation *weakBlockOperation = blockOperation;
            __weak DirectorySearcher *weakSelf = self;
            
            [blockOperation addExecutionBlock:^{
                
                __strong NSBlockOperation *strongBlockOperation = weakBlockOperation;
                
                if(!strongBlockOperation)
                    return;
                
                if([strongBlockOperation isCancelled])
                    return;
                
                __strong typeof(weakSelf) strongSelf = weakSelf;
                
                if(!strongSelf)
                    return;
                
                RecentObject *newRecent = phoneNumberRecent;
                
                NSHTTPURLResponse *httpResponse = nil;
                NSError *error = nil;
                
                NSString *endpoint = [SCPNetworkManager prepareEndpoint:SCPNetworkManagerEndpointV1User
                                                           withUsername:searchText];
                
                id responseObject = [Switchboard.networkManager synchronousApiRequestInEndpoint:endpoint
                                                                                         method:SCPNetworkManagerMethodGET
                                                                                      arguments:nil
                                                                                          error:&error
                                                                                   httpResponse:&httpResponse];
                
                if([strongBlockOperation isCancelled])
                    return;
                
                if(!error &&
                   httpResponse &&
                   httpResponse.statusCode == 200 &&
                   [responseObject isKindOfClass:[NSDictionary class]]) {
                    
                    NSDictionary *json = (NSDictionary *)responseObject;
                    
                    if([json safeStringForKey:@"result"] == nil) {
                        
                        if(!newRecent)
                            newRecent = [RecentObject new];
                        
                        newRecent.isNumber = NO;
                        
                        BOOL updated = [newRecent updateWithJSON:json];
                        
                        if(updated) {
                            
                            [[SCSContactsManager sharedManager] linkConversationWithContact:newRecent];
                            
                            [Switchboard.userResolver donateRecentToCache:newRecent];
                        }
                    }
                }
                
                if(strongSelf.delegate &&
                   [strongSelf.delegate respondsToSelector:@selector(didReturnAutocompleteRecent:isPhoneNumber:forSearchText:)]) {
                    
                    [strongSelf.delegate didReturnAutocompleteRecent:newRecent
                                                       isPhoneNumber:NO
                                                       forSearchText:originalSearchText];
                }
            }];
            
            [_autocompleteQueue cancelAllOperations];
            [_autocompleteQueue addOperation:blockOperation];
        }
    }

    if(searchDirectory) {
    
        if (searchText.length < 2) {
            
            if(self.delegate &&
               [self.delegate respondsToSelector:@selector(didReturnDirectoryRecents:forSearchText:)]) {
                
                [self.delegate didReturnDirectoryRecents:nil
                                           forSearchText:originalSearchText];
            }
        }
        else {
            
            if(_task)
                [_task cancel];
            
            NSString *endpoint = [SCPNetworkManager prepareEndpoint:SCPNetworkManagerEndpointV2People
                                                       withUsername:searchText];
            
            _task = [Switchboard.networkManager apiRequestInEndpoint:endpoint
                                                              method:SCPNetworkManagerMethodGET
                                                           arguments:nil
                                                          completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {
                                                              
                                                              __strong typeof(weakSelf) strongSelf = weakSelf;

                                                              if(!strongSelf)
                                                                  return;
                                                              
                                                              if(_isCancelled)
                                                                  return;
                                                              
                                                              if(error) {
                                                                  
                                                                  if(strongSelf.delegate &&
                                                                     [strongSelf.delegate respondsToSelector:@selector(didReturnDirectoryRecents:forSearchText:)]) {
                                                                      
                                                                      [strongSelf.delegate didReturnDirectoryRecents:nil
                                                                                                       forSearchText:originalSearchText];
                                                                  }
                                                                  
                                                                  return;
                                                              }
                                                                                                                    
                                                              NSMutableArray *recentObjectsArray = [NSMutableArray new];
                                                              NSDictionary *resultJSON = (NSDictionary *)responseObject;
                                                                                                                    
                                                              if([[resultJSON safeStringForKey:@"result"] isEqualToString:@"success"]) {
                                                                  
                                                                  NSArray *people = [resultJSON objectForKey:@"people"];
                                                                  
                                                                  for (NSDictionary *userData in people) {
                                                                      
                                                                      RecentObject *newRecent = [[RecentObject alloc] initWithJSON:userData];
                                                                      
                                                                      if(newRecent) {
                                                                      
                                                                          [[SCSContactsManager sharedManager] linkConversationWithContact:newRecent];
                                                                      
                                                                          [Switchboard.userResolver donateRecentToCache:newRecent];
                                                                      
                                                                          [recentObjectsArray addObject:newRecent];
                                                                      }
                                                                  }
                                                              }
                                                              
                                                              if(_isCancelled)
                                                                  return;
                                                              
                                                              // send found items to delegate
                                                              if(strongSelf.delegate &&
                                                                 [strongSelf.delegate respondsToSelector:@selector(didReturnDirectoryRecents:forSearchText:)]) {
                                                                  
                                                                  [strongSelf.delegate didReturnDirectoryRecents:recentObjectsArray
                                                                                                   forSearchText:originalSearchText];
                                                              }
                                                          }];
        }
    }
}

#pragma mark - Public

-(void)searchForContactsWithText:(NSString *)searchText filter:(SCSGlobalContactSearchFilter)filter {
    
    _isCancelled    = NO;
    _lastSearchText = searchText;
    _lastFilter     = filter;
    
    [self searchOperationWithText:searchText
                           filter:filter];
}

-(void) dismissAllOperations {

    _isCancelled = YES;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    
    if(_task)
        [_task cancel];

    if(_autocompleteQueue)
        [_autocompleteQueue cancelAllOperations];
}

@end
