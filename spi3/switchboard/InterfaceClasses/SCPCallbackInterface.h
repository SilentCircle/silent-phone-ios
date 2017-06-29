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
//  SCPCallbackInterface.h
//  SP3
//
//  Created by Eric Turner on 5/13/15.
//  Based on original work by Janis Narbuts SP1
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCPNotificationsManager.h"
#import "SCPCallHelper.h"
#import "SCPNetworkManager.h"
#import "SCSUserResolver.h"

//void cbFnc(void *p, int ok, const char *pMsg)
typedef void (^progressBlock)(int ok, const char *msg);

// Forward declarations
@protocol SCPAppDelegateInterface;
@class SCPCallbackInterface;
@class SCPCallManager;
@class SCPAccountsManager;
@class SCSAudioManager;
@class SCPCall;

// Static instance 
extern SCPCallbackInterface *Switchboard;

#if HAS_DATA_RETENTION
extern NSDictionary *kDR_Policy_Errors;

@class ChatObject; // data retention
#endif // HAS_DATA_RETENTION


@interface SCPCallbackInterface : NSObject

+ (SCPCallbackInterface *)sharedInstance;

@property (strong, nonatomic) SCPCallHelper *callHelper;

@property (strong, nonatomic) SCPNetworkManager *networkManager;

@property (strong, nonatomic) SCPNotificationsManager *notificationsManager;

@property (strong, nonatomic) SCSUserResolver *userResolver;

+ (void)setup;


#pragma mark - Accounts Wrapper Methods

- (void *)activeAccounts;
- (NSInteger)countOfActiveAccounts;
- (BOOL)allAccountsOnline;
- (BOOL)accountIsOn:(void *)acct;
- (NSInteger)accountsCountForIsActive:(BOOL)isActive;
- (void *)accountAtIndex:(NSInteger)idx;
- (void *)accountAtIndex:(NSInteger)idx isActive:(BOOL)isActive;
//- (NSString *)infoForAccountAtIndex:(NSInteger)idx forKey:(NSString *)aKey;
//- (NSString *)infoForAccountAtIndex:(NSInteger)idx isActive:(BOOL)isActive forKey:(NSString *)aKey;
- (NSArray *)indexesOfUniqueAccounts;
- (BOOL)hasNonSilentCircleAccounts;

- (NSString *)titleForAccount:(void *)acct;
- (NSString *)numberForAccount:(void *)acct;
- (NSString *)usernameForAccount:(void *)acct;
- (NSString *)regErrorForAccount:(void *)acct;
- (void *)emptyAccount;

- (void *)getCurrentDOut;
- (int)setCurrentDOut:(void*)acct;
- (NSString *)currentDOutState:(void*)acct; // "yes", "no", "connecting"
- (BOOL)currentDOutIsNULL;
- (BOOL)isCurrentDOut:(id)sipAccount;
- (BOOL)accountAtIndexIsCurrentDOut:(NSInteger)idx;

// This is the installation device id, not to be confused with the persisent stored in the Keychain.
// The peristent device id is being accessed with [SPKeychain getDecodedDeviceId] method.
- (NSString *)getCurrentDeviceId;

#pragma mark - Motion Manager API
- (void)startMotionDetect;
- (void)stopMotionDetect;
- (BOOL)motionDetectIsOn;

#if HAS_DATA_RETENTION
#pragma mark - Data Retention
- (void)configureDataRetention:(BOOL)bBlockLocalDR blockRemote:(BOOL)bBlockRemoteDR;
- (BOOL)doesUserRetainDataType:(uint32_t)typeCode;
- (void)retainCallMetadata:(SCPCall *)call;
#endif // HAS_DATA_RETENTION

#pragma mark - Provisioning

- (BOOL)isProvisioned;
- (void)startEngineWithProvisioningSuccess;

#pragma mark - Push Token API

- (BOOL)setPushToken:(NSString *)ptoken;

#pragma mark - wipeData
-(void)setCfgForDataDestroy;

#pragma mark - Utilities
// MainDialPad
- (NSInteger)secondsSinceAppStarted;

- (void)setIsShowingVideoScreen:(BOOL)isShowingVideoScreen;

// Called from SCPNetworkManager
-(void)startListenEngineCallbacks;

/**
 Returns whether the Zina instance has been initialized properly or not.
 
 @return YES if zina shared instance is up, NO otherwise
 */
- (BOOL)isZinaReady;

#pragma mark - Notifications
- (void)postNotification:(NSString *)key;
- (void)postNotification:(NSString *)key obj:(id)obj userInfo:(NSDictionary *)uInfo delay:(NSTimeInterval)delay;

#pragma mark TMP?
-(void)alert:(NSString *)str;
- (int32_t)doCmd:(NSString *)aCmd;
- (int32_t)doCmd:(NSString *)aCmd callId:(int32_t)cid;
- (NSString *)sendEngMsg:(void *)eng msg:(NSString *)msg;

#pragma mark - Rescanning

/**
 Rescan local user's devices
 by calling zina `rescanUserDevices(string)` method
 */
- (void)rescanLocalUserDevices;

/**
 Rescans the devices of a given user
 by calling zina `rescanUserDevices(string)` method
 
 @param uuid The user's uuid
 */
- (void)rescanDevicesForUserWithUUID:(NSString *)uuid;

@end
