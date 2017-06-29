//
//  SCSUserResolver.h
//  SPi3
//
//  Created by Stelios Petrakis on 20/04/2017.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RecentObject.h"

/**
 SCSUserResolver is responsible for enqueuing requests to
 the /v1/user/ endpoint and updating the database conversations
 with the fresh data coming from the server.
 
 The class also provides an in-memory cache of all the resolved
 users for getting the latest data fast.
 
 An instance of this class is always available via the Switchboard
 so there's no need of instantiating more than one objects of
 SCSUserResolver class.
 */
@interface SCSUserResolver : NSObject

/**
 Returns a cached user from the dictionary of the
 already resolved users.
 
 Ideal for the cases where we do not store the users in the db
 (e.g. group chat member list).
 
 @param uuid The uuid in question
 @return The cached recent, nil if no recent was found
 */
- (RecentObject *)cachedRecentWithUUID:(NSString *)uuid;

/**
 Returns an array with the cached recent objects.

 Used by ContactsManager to link any cached recents
 when the addressbook parsing has been completed.
 
 @return The array of the cached recent objects
 */
- (NSArray <RecentObject *> * )cachedRecents;

/**
 Adds the recent to the cache.
 
 Warning: The recent has to be created out of 
 data from a valid authority (e.g. API response).
 
 Recents created out of DBManager or partially loaded
 shouldn't be added to the cache.

 @param recent The recent to be added to cache
 */
- (void)donateRecentToCache:(RecentObject *)recent;

@end
