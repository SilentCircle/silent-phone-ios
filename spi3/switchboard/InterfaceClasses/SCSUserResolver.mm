//
//  SCSUserResolver.m
//  SPi3
//
//  Created by Stelios Petrakis on 20/04/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCSUserResolver.h"
#import "SCPCallbackInterface.h"
#import "DBManager.h"
#import "NSDictionaryExtras.h"
#import "ChatUtilities.h"
#import "SCPNotificationKeys.h"
#import "GroupChatManager+Members.h"
#import "GroupChatManager+UI.h"
#import "SCSContactsManager.h"

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

// TODO: Pending file cache implementation

@implementation SCSUserResolver {
    
    NSMutableDictionary <NSString *, RecentObject *> *_cachedUsers;
    NSMutableArray <NSString *> *_pendingResolutions;
}

#pragma mark - Lifecycle

- (instancetype)init {
    
    if(self = [super init]) {
        
        _cachedUsers        = [NSMutableDictionary new];
        _pendingResolutions = [NSMutableArray new];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(shouldResolveRecent:)
                                                     name:kSCSRecentObjectShouldResolveNotification
                                                   object:nil];
    }
    
    return self;
}

#pragma mark - Notifications

// TODO: This will change when we will start saving the group member info
// in the database or in a file cache

- (void)conversationsLoaded:(NSNotification *)notification {
 
    __weak SCSUserResolver *weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        __strong SCSUserResolver *strongSelf = weakSelf;
        
        if(!strongSelf)
            return;
        
        for(RecentObject *recent in [[DBManager dBManagerInstance] getRecents]) {
            
            if(!recent)
                continue;
            if(recent.isGroupRecent)
            {
                
                NSMutableArray *membersList = [GroupChatManager getAllGroupMemberRecentObjects:recent.contactName];
                
                if(!membersList)
                    continue;
                
                for(RecentObject *member in membersList)
                {
                    NSString *uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:member.contactName lowerCase:YES];
                    [strongSelf enqueueResolutionForUUID:uuid
                                              completion:^(RecentObject *updatedRecent) { }];
                }
            }
            else {
                
                // TODO: We are enqueuing even the 1 to 1 conversations now
                // but in the future the UserResolver will have an internal way
                // (TTL per user) to decide when to enqueue a user for resolution
                [strongSelf enqueueResolutionForUUID:recent.contactName
                                          completion:^(RecentObject *updatedRecent) { }];
            }
        }
    });
}

- (void)shouldResolveRecent:(NSNotification *)notification {
    
    RecentObject *recentObject = (RecentObject *)[notification.userInfo objectForKey:kSCPRecentObjectDictionaryKey];
    
    if(!recentObject)
        return;
    
    if(!recentObject.contactName)
        return;
    
    if (recentObject.isGroupRecent)
        return;
    
    if(!recentObject.isPartiallyLoaded)
        return;
    
    RecentObject *cachedRecent = [self cachedRecentWithUUID:recentObject.contactName];
    
    if(cachedRecent) {
        
        [recentObject setIsPartiallyLoaded:NO];
        [recentObject updateWithRecent:cachedRecent];

        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectResolvedNotification
                                                            object:self
                                                          userInfo:@{ kSCPRecentObjectDictionaryKey : recentObject }];

        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification
                                                            object:self
                                                          userInfo:@{ kSCPRecentObjectDictionaryKey : recentObject }];
        
        return;
    }
    
    [self enqueueResolutionForUUID:recentObject.contactName
                        completion:^(RecentObject *updatedRecent) {
                              
                              if(!updatedRecent)
                                  return;

                              [recentObject setIsPartiallyLoaded:NO];
                              [recentObject updateWithRecent:updatedRecent];
                          }];
}

#pragma mark - Public

- (void)donateRecentToCache:(RecentObject *)recent {
    
    if(!recent)
        return;
    
    if(recent.isPartiallyLoaded)
        return;
    
    if(!recent.contactName)
        return;
    
    if(!recent.displayName)
        return;
    
    if(!recent.displayAlias)
        return;
    
    recent.contactName = [[ChatUtilities utilitiesInstance] removePeerInfo:recent.contactName
                                                                 lowerCase:NO];

    @synchronized (self) {
        
        [_cachedUsers setObject:recent
                         forKey:recent.contactName];
    }
}

- (NSArray <RecentObject *> *)cachedRecents {

    @synchronized (self) {
        return [_cachedUsers allValues];
    }
}

- (RecentObject *)cachedRecentWithUUID:(NSString *)uuid {
    
    if(!uuid)
        return nil;
    
    uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:uuid
                                                   lowerCase:NO];

    @synchronized (self) {
        return [_cachedUsers objectForKey:uuid];
    }
}

#pragma mark - Pending resolutions structure

- (BOOL)didAddUUIDtoPendingResolutions:(NSString *)uuid {

    if(!uuid)
        return NO;
    
    @synchronized (self) {
        
        if([_pendingResolutions containsObject:uuid])
            return NO;
        
        [_pendingResolutions addObject:uuid];
        
        return YES;
    }
}

- (void)removeUUIDfromPendingResolutions:(NSString *)uuid {

    if(!uuid)
        return;
    
    @synchronized (self) {
        
        [_pendingResolutions removeObject:uuid];
    }
}

#pragma mark - Private

- (void)enqueueResolutionForUUID:(NSString *)uuid completion:(void (^)(RecentObject *updatedRecent))completion {

    if(!uuid)
        return;
    
    uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:uuid
                                                   lowerCase:NO];
    
    BOOL didAddToPending = [self didAddUUIDtoPendingResolutions:uuid];
    
    if(!didAddToPending)
        return;
    
    DDLogInfo(@"Resolving user with UUID = %@", uuid);

    __weak SCSUserResolver *weakSelf = self;
    
    [self resolveUserWithUUID:uuid
                   completion:completion
                apiCompletion:^(NSDictionary *apiResponse) {
            
        __strong SCSUserResolver *strongSelf = weakSelf;
        
        if(!strongSelf)
            return;
        
        if(!apiResponse)
            return;
        
        // Update the database (if needed)
        DBManager *sharedDBManager = [DBManager dBManagerInstance];
        
        RecentObject *databaseRecent = [sharedDBManager getRecentByName:uuid];
        
        if(!databaseRecent)
            return;
        
        BOOL isDirty = NO;
        
        if(![strongSelf isString:databaseRecent.displayName safeEqualToString:[apiResponse safeStringForKey:@"display_name"]]) {
            
            [databaseRecent setDisplayName:[apiResponse safeStringForKey:@"display_name"]];
            isDirty = YES;
        }
        
        if(![strongSelf isString:databaseRecent.displayAlias safeEqualToString:[apiResponse safeStringForKey:@"display_alias"]]) {
            
            [databaseRecent setDisplayAlias:[apiResponse safeStringForKey:@"display_alias"]];
            isDirty = YES;
        }
            
        if(![strongSelf isString:databaseRecent.displayOrganization safeEqualToString:[apiResponse safeStringForKey:@"display_organization"]]) {
            
            [databaseRecent setDisplayOrganization:[apiResponse safeStringForKey:@"display_organization"]];
            isDirty = YES;
        }

        if(![strongSelf isString:databaseRecent.avatarUrl safeEqualToString:[apiResponse safeStringForKey:@"avatar_url"]]) {
            
            [databaseRecent setAvatarUrl:[apiResponse safeStringForKey:@"avatar_url"]];
            isDirty = YES;
        }
        
        if(isDirty) {
            
            DDLogInfo(@"Saving the updated recent to the database: %@", databaseRecent);
            
            [sharedDBManager saveRecentObject:databaseRecent];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification
                                                                object:strongSelf
                                                              userInfo:@{ kSCPRecentObjectDictionaryKey : databaseRecent }];
        }
    }];
}

- (BOOL)isString:(NSString *)string safeEqualToString:(NSString *)aString {
    
    if(string) {
    
        if([string isKindOfClass:[NSString class]])
            return [string isEqualToString:aString];
    }
    else if(!aString)
        return YES;
    
    return NO;
}

- (void)resolveUserWithUUID:(NSString *)uuid
                 completion:(void (^)(RecentObject *updatedRecent))completion
              apiCompletion:(void (^)(NSDictionary *apiResponse))apiCompletion {
    
    if(!uuid) {
        
        if(completion)
            completion(nil);
        
        return;
    }

    __weak SCSUserResolver *weakSelf = self;
    
    NSString *endpoint = [SCPNetworkManager prepareEndpoint:SCPNetworkManagerEndpointV1User
                                               withUsername:uuid];
    
    // TODO: Deal with offline states
    
    [Switchboard.networkManager apiRequestInEndpoint:endpoint
                                              method:SCPNetworkManagerMethodGET
                                           arguments:nil
                                          completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {
                                              
                                              __strong SCSUserResolver *strongSelf = weakSelf;
                                              
                                              if(!strongSelf)
                                                  return;
                                              
                                              [strongSelf removeUUIDfromPendingResolutions:uuid];
                                              
                                              if(error) {
            
                                                  if(completion)
                                                      completion(nil);
            
                                                  return;
                                              }
        
                                              if(!httpResponse) {
            
                                                  if(completion)
                                                      completion(nil);
            
                                                  return;
                                              }

                                              if(httpResponse.statusCode != 200) {
            
                                                  if(completion)
                                                      completion(nil);
            
                                                  return;
                                              }
        
                                              if(![responseObject isKindOfClass:[NSDictionary class]]) {
            
                                                  if(completion)
                                                      completion(nil);
            
                                                  return;
                                              }
        
                                              // Update the cache
                                              [strongSelf updateCacheWithAPIResponse:responseObject
                                                                          completion:completion];

                                              if(apiCompletion)
                                                  apiCompletion(responseObject);
                                          }];
}

- (void)updateCacheWithAPIResponse:(NSDictionary *)apiResponse completion:(void (^)(RecentObject *))completion {
    
    DDLogInfo(@"%s -> %@ (isMainThread: %d)", __PRETTY_FUNCTION__, apiResponse, [NSThread currentThread].isMainThread);
    
    RecentObject *cachedRecent = [[RecentObject alloc] initWithJSON:apiResponse];
    
    if(!cachedRecent) {
        
        if(completion)
            completion(nil);
        
        return;
    }
    [self donateRecentToCache:cachedRecent];
    
    [[SCSContactsManager sharedManager] informZinaWithUserData:apiResponse];

    [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectResolvedNotification
                                                        object:self
                                                      userInfo:@{ kSCPRecentObjectDictionaryKey : cachedRecent }];

    [[NSNotificationCenter defaultCenter] postNotificationName:kSCSRecentObjectUpdatedNotification
                                                        object:self
                                                      userInfo:@{ kSCPRecentObjectDictionaryKey : cachedRecent }];

    if(completion)
        completion(cachedRecent);

    [[SCSContactsManager sharedManager] linkConversationWithContact:cachedRecent];
}

@end
