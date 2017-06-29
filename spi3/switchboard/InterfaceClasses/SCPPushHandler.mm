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
//  SCPPushHandler.m
//  SP3
//
//  Created by Eric Turner on 5/25/15.
//  Based on original work by Janis Narbuts SP1
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SCPPushHandler.h"
#import "SCPCallbackInterface.h"
#import "SCPCallbackInterfaceUtilities_Private.h"
#import "SCPCallManager.h"
#import "SCPNetworkManager.h"
#import "SCPNotificationKeys.h"
#import "SCPAccountsManager.h"

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelWarning;
//#endif

@interface SCPPushHandler () {
    
    NSString *_cachedToken;
}

@property (nonatomic, strong) PKPushRegistry *pushRegistry;

@end

@implementation SCPPushHandler

#pragma mark - Lifecycle

- (instancetype)init {

    if (self = [super init]) {
        
        [self setupVoipPush];
        
        // We listen for when the account(s) status is changed
        // so we can send the cached token to the server
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(accountStatusDidChange:)
                                                     name:kSCPEngineStateDidChangeNotification
                                                   object:nil];
    }
    
    return self;
}

#pragma mark - Notifications

- (void)accountStatusDidChange:(NSNotification *)notification {
    
    if([SPAccountsManager allAccountsOnline] && _cachedToken) {
        
        if([Switchboard setPushToken:_cachedToken])
            _cachedToken = nil;
    }
}

#pragma mark - Private

-(void)setupVoipPush {
    
    self.pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    self.pushRegistry.delegate = self;
    self.pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
}

#pragma mark - PKPushRegistryDelegate

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type {
    
    DDLogVerbose(@"%s", __PRETTY_FUNCTION__);
}

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type {

    DDLogVerbose(@"%s", __PRETTY_FUNCTION__);

    if(!credentials)
        return;
    
    if(!credentials.token)
        return;
    
    if([credentials.token length] == 0)
        return;
    
    NSString* newToken = [credentials.token description];
    
    if(!newToken)
        return;
    
    newToken = [newToken stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    newToken = [newToken stringByReplacingOccurrencesOfString:@" " withString:@""];

    if(![Switchboard setPushToken:newToken])
        _cachedToken = newToken;
    else
        _cachedToken = nil;
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type {

    DDLogVerbose(@"%s", __PRETTY_FUNCTION__);

    [Switchboard.networkManager pushNotificationReceived];
}

@end
