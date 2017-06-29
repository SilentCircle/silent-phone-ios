/*
Copyright (C) 2014-2017, Silent Circle, LLC.  All rights reserved.

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
//  UserService.m
//
//  Created by Ethan Arutunian on 8/18/14.
//  Copyright (c) 2014 Arutunian, LLC. All rights reserved.
//

#import "UserService.h"

#import "AppDelegate.h" // for UIAlertController
#import "axolotl_glue.h"
#import "ChatUtilities.h"
#import "EmbeddedIAPProduct.h"
#import "Reachability.h"
#import "RecentObject.h"
#import "SCPNotificationKeys.h"
#import "SCPSettingsManager.h"
#import "SPProduct.h"
#import "SCPCallbackInterface.h"
#import "SCSConstants.h"
#import "StoreManager.h"
#import "NSDictionaryExtras.h"
#import "SCPAccountsManager.h"

#define ENABLE_IN_APP_PURCHASE 0


//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

@implementation UserService {
    
    NSArray *_spProductsList;
    BOOL _shouldReloadUser;
    BOOL _isOnline;
}

static SPUser *_currentUser = nil;

#pragma mark - Class methods

+ (UserService *)sharedService {
    
    static UserService *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    
    return sharedInstance;
}

+ (SPUser *)currentUser {
    
    @synchronized (self) {
        
        if (!_currentUser) {
            
            NSData *userData = [[NSUserDefaults standardUserDefaults] objectForKey:kSPUserKey];
            
            if ( (userData) && ([userData isKindOfClass:[NSData class]]) ) {
                
                NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:userData];
                NSDictionary *userDict = [unarchiver decodeObjectForKey:kSPUserKey];
                NSString *userID = [unarchiver decodeObjectForKey:kSPUserIDKey];
                [unarchiver finishDecoding];
                
                SPUser *user = [[SPUser alloc] initWithDict:userDict];
                user.userID = userID;
                _currentUser = user;
                
            } else {
                DDLogError(@"%s Error retrieving userData from NSUserDefaults", 
__FUNCTION__);
            }
        }
        
        return _currentUser;
    }
}

#pragma mark - Lifecycle

- (instancetype)init {
    
    if(self = [super init]) {
        
        _shouldReloadUser = YES;
        _isOnline = [SPAccountsManager allAccountsOnline];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateUserNotification:)
                                                     name:kSCSUserServiceUpdateUserNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChangedNotification:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleEngineDidUpdateNotification:)
                                                     name:kSCPEngineStateDidChangeNotification
                                                   object:nil];
    }
    
    return self;
}

#if HAS_DATA_RETENTION
+ (BOOL)currentUserBlocksLocalDR {
    uint32_t blockCodes = [self currentUser].drBlockCode;
    if ( (blockCodes & kDRBlock_LocalData) || (blockCodes & kDRBlock_LocalMetadata) )
        return YES;
    
    void *findGlobalCfgKey(const char *key);
    int *blockDataRetentionP = (int*)findGlobalCfgKey("iBlockLocalDataRetention");
    return ( (blockDataRetentionP != nil) && (*blockDataRetentionP == 1) );
}

+ (BOOL)currentUserBlocksRemoteDR {
    uint32_t blockCodes = [self currentUser].drBlockCode;
    if ( (blockCodes & kDRBlock_RemoteData) || (blockCodes & kDRBlock_RemoteMetadata) )
        return YES;

    void *findGlobalCfgKey(const char *key);
    int *blockDataRetentionP = (int*)findGlobalCfgKey("iBlockRemoteDataRetention");
    return ( (blockDataRetentionP != nil) && (*blockDataRetentionP == 1) );
}

+ (BOOL)isDRBlockedForContact:(RecentObject *)contact {
    BOOL localUserBlocked =  ( ([self currentUser].drEnabled) && ([self currentUserBlocksLocalDR]) );
    BOOL contactBlocked = ( (contact.drEnabled) && ([UserService currentUserBlocksRemoteDR]) );
    return ( (localUserBlocked) || (contactBlocked) );
}
#endif // HAS_DATA_RETENTION

extern void *getCurrentDOut();
extern const char* sendEngMsg(void *pEng, const char *p);
extern const char *getAPIKey();

void log_events(const char *tag, const char *buf);
void t_logf(void (*log_fnc)(const char *tag, const char *buf), const char *tag, const char *format, ...);

#pragma mark - Notifications

- (void)handleEngineDidUpdateNotification:(NSNotification *)notification {
    
    BOOL wasOnline = _isOnline;
    
    _isOnline = [SPAccountsManager allAccountsOnline];
    
    if(!wasOnline && _isOnline)
        [self checkUser];    
}

- (void)reachabilityChangedNotification:(NSNotification *)notification {
    
    if([Reachability reachabilityForInternetConnection].currentReachabilityStatus == NotReachable)
        return;

    [self checkUser];
}

- (void)updateUserNotification:(NSNotification *)note {
    
    t_logf(log_events, __FUNCTION__, "Called updateUserNotification");

    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
        
        _shouldReloadUser = YES;
        return;
    }
    
    // refresh the user
    [self requestUserData];
}

#pragma mark - Private

- (BOOL)requestUserData {

    __weak UserService *weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        __strong UserService *strongSelf = weakSelf;
        
        if(!strongSelf)
            return;
        
        [Switchboard rescanLocalUserDevices];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSUserServiceUserDidUpdateDevicesNotification
                                                            object:strongSelf];
    });

    NSString *userID = [[ChatUtilities utilitiesInstance] getOwnUserName];
    
    if(!userID) {
        
        t_logf(log_events, __FUNCTION__, "userID is empty");
        return NO;
    }

    NSURLSessionTask *task = [Switchboard.networkManager apiRequestInEndpoint:SCPNetworkManagerEndpointV1Me
                                                                       method:SCPNetworkManagerMethodGET
                                                                    arguments:nil
                                                                   completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {

                                                                       if(error)
                                                                           return;

                                                                       SPUser *user = nil;

                                                                       if(responseObject)
                                                                           user =  [self updateCurrentUserWithDictionary:responseObject
                                                                                                                  userID:userID];

#if HAS_DATA_RETENTION
                                                                       if(!user)
                                                                           return;

                                                                       // DR-block: force on DR-block if server says so
                                                                       int setGlobalValueByKey(const char *key,  char *sz);

                                                                       BOOL bSave = NO;

                                                                       if ( (user.drBlockCode & kDRBlock_LocalData) || (user.drBlockCode & kDRBlock_LocalMetadata) ) {

                                                                           setGlobalValueByKey("iBlockLocalDataRetention", (char *)"1");
                                                                           bSave = YES;
                                                                       }

                                                                       if ( (user.drBlockCode & kDRBlock_RemoteData) || (user.drBlockCode & kDRBlock_RemoteMetadata) ) {

                                                                           setGlobalValueByKey("iBlockRemoveDataRetention", (char *)"1");
                                                                           bSave = YES;
                                                                       }

                                                                       if (bSave)
                                                                           [SCPSettingsManager saveSettings];
#endif // HAS_DATA_RETENTION
                                                                   }];
    
    return (task != nil);
}

- (SPProduct *)spProductForPermission:(UserPermission)permission {
    
    @synchronized (self) {
        
        if ([_spProductsList count] == 0)
            return nil;
        
        return [_spProductsList objectAtIndex:0]; // only one product for now
    }
}

// Called inside a synchronized self call
-(void)addPrekeysIfNeeded {
    
    DDLogInfo(@"%s _currentUser.prekeyCnt = %d", __PRETTY_FUNCTION__, _currentUser.prekeyCnt);
    
    if(!_currentUser)
        return;
    
    const int minPrekeyCount = 50;
    
    if(_currentUser.prekeyCnt && _currentUser.prekeyCnt < minPrekeyCount){
        
        _currentUser.prekeyCnt = minPrekeyCount + 1; //it would reset anyway, but we have to be sure that we do not call this too often
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            if([Switchboard isZinaReady])
                CTAxoInterfaceBase::addPrekeys(50);
        });
    }
}

- (void)_presentAlert:(UIAlertController *)ac {
    AppDelegate *app = (AppDelegate *)[UIApplication sharedApplication].delegate;
    UIViewController *vc = app.window.rootViewController;
    [vc presentViewController:ac animated:YES completion:nil];
}

#pragma mark - Public

- (SPUser *)updateCurrentUserWithDictionary:(NSDictionary *)userDict userID:(NSString *)userID {

    if(!userDict)
        return nil;
    
    SPUser *user = [[SPUser alloc] initWithDict:(NSDictionary *)userDict];
    user.userID = userID;
    
    @synchronized (self) {
        
        _currentUser = user;
        
        [self addPrekeysIfNeeded];

        // save data
        NSMutableData *userData = [[NSMutableData alloc] init];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:userData];
        [archiver encodeObject:userDict forKey:kSPUserKey];
        [archiver encodeObject:userID forKey:kSPUserIDKey];
        [archiver finishEncoding];
        
        [[NSUserDefaults standardUserDefaults] setObject:userData forKey:kSPUserKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSUserServiceUserDidUpdateNotification
                                                            object:self];
    });
    
    @synchronized (self) {
        return _currentUser;
    }
}

- (void)updateProductListWithDictionary:(NSDictionary *)productDict {
    
    NSArray *productsIn = [productDict objectForKey:@"products"];
    
    if ([productsIn count] == 0)
        return;
    
    NSMutableArray *productList = [NSMutableArray arrayWithCapacity:[productsIn count]];
    
    for (NSDictionary *productD in productsIn) {
        
        SPProduct *spProduct = [[SPProduct alloc] initWithDict:productD];
        [productList addObject:spProduct];
    }
    
    @synchronized (self) {
        _spProductsList = [[NSArray alloc] initWithArray:productList];
    }
}

- (void)checkUser {
    
    BOOL loadUserData = NO;
    
    @synchronized (self) {
        
        if(_shouldReloadUser) {
            
            loadUserData = YES;
            _shouldReloadUser = NO;
            
        }
        else if (!_currentUser)
            loadUserData = YES;
    }
    
    if (loadUserData) {
        
        BOOL requested = [self requestUserData];
        
        t_logf(log_events, __FUNCTION__, "permissions requested = %d", requested);
    }
}

// SP: TODO: Move the UI related logic to the presentation layer (i.e. ActionSheetViewRed, AppDelegate, ChatViewController)
- (void)upsellPermission:(UserPermission)permission {
    
    if ([[UserService currentUser] hasPermission:permission])
        return; // how did we get here? they already have permission

#if !ENABLE_IN_APP_PURCHASE
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Feature Unavailable", nil) message:NSLocalizedString(@"Your account does not include this feature.", nil) preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:nil];
    [ac addAction:cancelAction];
    [self _presentAlert:ac];
	return;
#else
    // EA: using cancel button for "Yes" to have it show in bold
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Feature Unavailable", nil) message:NSLocalizedString(@"You don't have this feature enabled for your account. Would you like to enable it?", nil) preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *enableAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        // check user credits
        [self enablePermission:permission];
    }];
    [ac addAction:enableAction];
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"No thanks", nil) style:UIAlertActionStyleDefault handler:nil];
    [ac addAction:noAction];
    [self _presentAlert:ac];
#endif // ENABLE_IN_APP_PURCHASE
}

// SP: TODO: Move the UI related logic to the presentation layer (i.e. SCSConferenceVM)
- (void)enablePermission:(UserPermission)permission {
    
	SPProduct *spProduct = [self spProductForPermission:permission];
    
	if (!spProduct) {
        
		// where is the product?? should have been loaded from iTunes
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"An error occurred", nil)
                                                                    message:NSLocalizedString(@"Unable to enable feature at this time.", nil)
                                                             preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil];
        [ac addAction:cancelAction];
        
        [self _presentAlert:ac];
		return;
	}
	
	SPUser *user = [UserService currentUser];
    
	// convert to cents before comparison
	if (user.remainingCredit*100 >= spProduct.priceCents) {
        
		// present user with option to use credits to upgrade
        NSString *message = [NSString stringWithFormat:NSLocalizedString(@"You have %@ in SilentPhone credits. The price to upgrade your account is %@/month. The upgrade will automatically renew each month.\n\nDo you want to upgrade your account?", nil), [user localizedRemainingCredits], [spProduct localizedPrice]];//[productVO displayPrice]];

        UIAlertController *ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Upgrade Account?", nil)
                                                                    message:message
                                                             preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *upgradeAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Upgrade", nil)
                                                                style:UIAlertActionStyleCancel
                                                              handler:^(UIAlertAction * _Nonnull action) {

            // user wants to spend their credits and upgrade account
            SPProduct *spProduct = [self spProductForPermission:permission];
            
            NSDictionary *arguments = @{ @"id":spProduct.productID };

            [Switchboard.networkManager apiRequestInEndpoint:SCPNetworkManagerEndpointV1Products
                                                      method:SCPNetworkManagerMethodPOST
                                                   arguments:arguments
                                                  completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {
            
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                          
                                                          if (error) {
                                                              
                                                              UIAlertController *ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"An error occurred", nil)
                                                                                                                          message:error.localizedDescription
                                                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                                                              
                                                              UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                                                                 style:UIAlertActionStyleCancel
                                                                                                               handler:nil];
                                                              [ac addAction:okAction];
                                                              
                                                              [self _presentAlert:ac];
                                                              
                                                              return;
                                                          }
                                                          
                                                          if(!responseObject)
                                                              return;
                                                          
                                                          NSDictionary *responseDict = (NSDictionary *)responseObject;
                                                          
                                                          NSString *resultCode = [responseDict safeStringForKey:@"result"];
                                                          NSDictionary *userDict = [responseDict objectForKey:@"user"];
                                                          
                                                          if ( (![@"success" isEqualToString:resultCode]) || (!userDict) ) {
                                                              
                                                              UIAlertController *ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Something went wrong", nil)
                                                                                                                          message:NSLocalizedString(@"Sorry, we were unable to process the upgrade at this time.", nil)
                                                                                                                   preferredStyle:UIAlertControllerStyleAlert];
                                                              
                                                              UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                                                                     style:UIAlertActionStyleCancel
                                                                                                                   handler:nil];
                                                              [ac addAction:cancelAction];
                                                              
                                                              [self _presentAlert:ac];
                                                              
                                                              return;
                                                          }
                                                          
                                                          [self updateCurrentUserWithDictionary:userDict
                                                                                         userID:user.userID];

                                                          // success
                                                          UIAlertController *ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Credits Applied", nil)
                                                                                                                      message:NSLocalizedString(@"The upgrade was successful.", nil)
                                                                                                               preferredStyle:UIAlertControllerStyleAlert];
                                                          
                                                          UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                                                                             style:UIAlertActionStyleCancel
                                                                                                           handler:nil];
                                                          [ac addAction:okAction];
                                                          
                                                          [self _presentAlert:ac];
                                                      });
                                                  }];
        }];
        [ac addAction:upgradeAction];
        
        UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"No thanks", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil];
        [ac addAction:noAction];
        [self _presentAlert:ac];

		return;
	}
	
#if !ENABLE_IN_APP_PURCHASE
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Feature Unavailable", nil) message:NSLocalizedString(@"Your account does not include this feature.", nil) preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:nil];
    [ac addAction:cancelAction];
    [self _presentAlert:ac];
#else
	// present user with option to buy more Silent Circle credits
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Insufficient Credits", nil) message:NSLocalizedString(@"You don't have enough SilentPhone credits to enable this feature. Do you want to buy more credits?", nil) preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *enableAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Yes", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        NSString *productID = [EmbeddedIAPProduct productIDForPermission:permission];
        [[StoreManager sharedInstance] startPurchaseProductID:productID forUser:_currentUser];
    }];
    [ac addAction:enableAction];
    UIAlertAction *noAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"No thanks", nil) style:UIAlertActionStyleDefault handler:nil];
    [ac addAction:noAction];
    [self _presentAlert:ac];

	return;
#endif // ENABLE_IN_APP_PURCHASE
}

@end
