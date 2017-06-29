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
//  SCPCallHelper.m
//  SPi3
//
//  Created by Stelios Petrakis on 20/12/2016.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "SCPCallHelper.h"
#import "SCPNotificationKeys.h"
#import "SCPCallbackInterface.h"
#import "SCSConstants.h"
#import "SCSPhoneHelper.h"
#import "ChatUtilities.h"
#import "SCPCallManager.h"
#import "UserService.h"
#import "SCSContactsManager.h"

#define T_MIN_NR_LEN_CAN_APPLY_DIAL_HELPER 7

@interface SCPCallHelper ()

// Only allow 1 outgoing request at a time.
@property (nonatomic) BOOL isLoadingOutgoingCallRequest;
// Check if UserService has finished loading in order to be able to check user's permissions.
@property (nonatomic) BOOL userServiceLoaded;
// Pending number to call in cause UserService hasn't loaded yet
@property (nonatomic) NSString *pendingNumber;
// Pending view controller that will be used for dial helper and for pushing the call screen or any error messages
@property (nonatomic, weak) UIViewController *pendingViewController;
// Queued video call request for that outgoing call
@property (nonatomic) BOOL hasQueuedVideoRequest;

@end

@implementation SCPCallHelper

- (instancetype)init {
    
    if(self = [super init]) {
        
        _userServiceLoaded = ([UserService currentUser] != nil);
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(userServiceDidUpdate:)
                                                     name:kSCSUserServiceUserDidUpdateNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(outgoingCallRequest:)
                                                     name:kSCPOutgoingCallRequestNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications

/* burger - replaces placeCall:withNumber: */
- (void)outgoingCallRequest:(NSNotification *)notif {
    UIViewController *vc = notif.object; //notif.userInfo[kSCPOutgoingCallVC];
    NSString *nr = notif.userInfo[kSCPOutgoingCallNumber];    
    BOOL vidreq = NO;
    if (notif.userInfo[kSCPQueueVideoRequest]) {
        vidreq = [notif.userInfo[kSCPQueueVideoRequest] boolValue];
    }    
    
    [Switchboard.callHelper requestOutgoingCallFromViewController:vc
                                                       withNumber:nr
                                                queueVideoRequest:vidreq];
}

- (void)userServiceDidUpdate:(NSNotification *)notification {
    
    _userServiceLoaded = YES;
    
    if(_pendingNumber)
        [self requestUUIDForNumber:_pendingNumber];
}

#pragma mark - Public

+ (BOOL)isStarCall:(NSString *)number {
    
    return [number hasPrefix:@"*"];
}

+ (BOOL)isMagicNumber:(NSString *)number {
    
    return [number hasPrefix:@"*##*"];
}

- (void)placeCallFromVC:(UIViewController *)vc withNumber:(NSString *)nr {
    
    [Switchboard.callHelper requestOutgoingCallFromViewController:vc
                                                       withNumber:nr
                                                queueVideoRequest:NO];
}

- (void)requestOutgoingCallFromViewController:(UIViewController *)viewController withNumber:(NSString *)number queueVideoRequest:(BOOL)queueVideoRequest {

    _pendingViewController = viewController;
    _hasQueuedVideoRequest = queueVideoRequest;
    
    void *eng = [Switchboard getCurrentDOut];
    
    NSString *number2 = nil;
    
    //we can not create a function for this because we have to return number2 and sometimes modify the number.
    
    if(![number hasPrefix:@"*"] && [[SCSPhoneHelper sharedPhoneHelper]canModifyNumber:eng] && [[ChatUtilities utilitiesInstance]isNumber:number]){
        
        NSString *n0 = [[ChatUtilities utilitiesInstance] cleanPhoneNumber:number];
        
        if(![number hasPrefix:@"+"])
            number = [NSString stringWithFormat:@"+%@",number];
        
        NSString *n1 = [NSString stringWithString:number];
        
        number2 = [[SCSPhoneHelper sharedPhoneHelper] getModifiedNumber:n0 reset:1 eng:eng];
        
        int n1n2 = [[[ChatUtilities utilitiesInstance]cleanPhoneNumber:n1] isEqualToString:number2];
        
        if([number hasPrefix:@"+"] && [number2 isEqualToString:n0] && number.length < T_MIN_NR_LEN_CAN_APPLY_DIAL_HELPER) {
            
            n1n2 = 1;
            number = [number substringFromIndex:1];
        }
        
        NSString *number_clean = [[ChatUtilities utilitiesInstance] removePeerInfo:number lowerCase:YES];
        
        if(n1n2 || number_clean.length < T_MIN_NR_LEN_CAN_APPLY_DIAL_HELPER)
            number2 = nil;
        else
            number2 = [[SCSContactsManager sharedManager] cleanContactInfo:number2];
    }
    
    if(number2)
        [self presentDialHelperChoicesForFirstNumber:number
                                        secondNumber:number2];
    else
        [self requestUUIDForNumber:number];
}

#pragma mark - Private

- (void)presentDialHelperChoicesForFirstNumber:(NSString *)firstNumber secondNumber:(NSString *)secondNumber {

    if(!_pendingViewController)
        return;
    
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Call to", nil)
                                                                message:nil
                                                         preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *firstPhoneNumberAction = [UIAlertAction actionWithTitle:NSLocalizedString(firstNumber, nil)
                                                                     style:UIAlertActionStyleDefault
                                                                   handler:^(UIAlertAction *action){ [self requestUUIDForNumber:firstNumber]; }];
    
    NSString *cleanedFirstNumber = [[firstNumber componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
    
    [[SCSPhoneHelper sharedPhoneHelper] getCountryFlagName:cleanedFirstNumber
                                         completitionBlock:^(NSDictionary *countryData){
                                             
                                             if(countryData == nil)
                                                 return;
                                             
                                             NSString *prefix = [countryData objectForKey:@"prefix"];
                                             UIImage *accessoryImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@.png", prefix]];
                                             
                                             [firstPhoneNumberAction setValue:accessoryImage forKey:@"image"];
                                         }];
    
    [ac addAction:firstPhoneNumberAction];
    
    UIAlertAction *secondPhoneNumberAction = [UIAlertAction actionWithTitle:NSLocalizedString(secondNumber, nil)
                                                                      style:UIAlertActionStyleDefault
                                                                    handler:^(UIAlertAction *action){ [self requestUUIDForNumber:secondNumber]; }];

    NSString *cleanedSecondNumber = [[secondNumber componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];

    [[SCSPhoneHelper sharedPhoneHelper] getCountryFlagName:cleanedSecondNumber
                                         completitionBlock:^(NSDictionary *countryData){
                                             
                                             if(countryData == nil)
                                                 return;
                                             
                                             NSString *prefix = [countryData objectForKey:@"prefix"];
                                             UIImage *accessoryImage = [UIImage imageNamed:[NSString stringWithFormat:@"%@.png", prefix]];
                                             
                                             [secondPhoneNumberAction setValue:accessoryImage forKey:@"image"];
                                         }];
    
    [ac addAction:secondPhoneNumberAction];
    
    [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil)
                                           style:UIAlertActionStyleCancel
                                         handler:nil]];
    
    [_pendingViewController presentViewController:ac
                                         animated:YES
                                       completion:nil];
}

- (void)requestUUIDForNumber:(NSString *)number {
    
    // Fullfiled the magic code requests immediately
    if([[self class] isMagicNumber:number]) {
        
        [self requestDialForNumber:number
                              uuid:nil
                            isPSTN:NO
                       displayName:nil];

        return;
    }
        
    if(!_userServiceLoaded) {
        
        _pendingNumber = number;
        return;
    }
    
    if(![[UserService currentUser] hasPermission:UserPermission_OutboundCalling]) {
        
        NSError *error = [[NSError alloc] initWithDomain:SCSCallManagerErrorDomain
                                                    code:SCSCallManagerErrorOutgoingCallPermissionDisabled
                                                userInfo:nil];

        [self postOutgoingFailureNotificationWithError:error];

        return;
    }

    // If we are trying to call a specific user device,
    // then ignore the uuid extraction
    if ([number rangeOfString:@"xscdevid"].location != NSNotFound) {
        
        [self requestDialForNumber:number
                              uuid:nil
                            isPSTN:NO
                       displayName:nil];
        
        return;
    }

    if(_isLoadingOutgoingCallRequest)
        return;
    
    _isLoadingOutgoingCallRequest = YES;
    
    // Clean the number
    number = [[SCSContactsManager sharedManager] cleanContactInfo:number];

    BOOL isNumber = [[ChatUtilities utilitiesInstance] isNumber:number];
    
    __weak typeof (self) weakSelf = self;
    
    // Look up the number (which can be a phone number, email address or sip url)
    // on the API
    NSString *endpoint = [SCPNetworkManager prepareEndpoint:SCPNetworkManagerEndpointV1User
                                               withUsername:number];

    [Switchboard.networkManager apiRequestInEndpoint:endpoint
                                              method:SCPNetworkManagerMethodGET
                                           arguments:nil
                                    useSharedSession:NO
                                          completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {

                                              _isLoadingOutgoingCallRequest = NO;
                                              
                                              __strong typeof (self) strongSelf = weakSelf;
                                              
                                              if(!strongSelf)
                                                  return;
                                              
                                              RecentObject *recent = nil;

                                              if(error || !httpResponse || httpResponse.statusCode != 200)
                                                  recent = nil;
                                              else
                                                  recent = [[RecentObject alloc] initWithJSON:responseObject];

                                              if(recent) {
                                                  
                                                  [strongSelf requestDialForNumber:number
                                                                              uuid:recent.contactName
                                                                            isPSTN:NO
                                                                       displayName:recent.displayName];
                                                  
                                                  [[SCSContactsManager sharedManager] linkConversationWithContact:recent];
                                                  
                                                  [Switchboard.userResolver donateRecentToCache:recent];
                                              }
                                              else {
                                                  
                                                  if(isNumber) {
                                                      
                                                      [strongSelf requestDialForNumber:number
                                                                                  uuid:nil
                                                                                isPSTN:YES
                                                                           displayName:nil];
                                                      
                                                      return;
                                                  }
                                                  
                                                  NSError *error = [NSError errorWithDomain:SCSCallManagerErrorDomain
                                                                                       code:SCSCallManagerErrorUserNotFound
                                                                                   userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"User not found", nil) }];
                                                  
                                                  [strongSelf postOutgoingFailureNotificationWithError:error];
                                              }
                                          }];
}

- (void)requestDialForNumber:(NSString *)number uuid:(NSString *)uuid isPSTN:(BOOL)isPSTN displayName:(NSString *)displayName {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if(isPSTN && ![[UserService currentUser] hasPermission:UserPermission_OutboundPSTNCalling]) {
            
            // Allow calling any star-code call even if user has no outbound PSTN permission
            if(![[self class] isStarCall:number]) {
                
                NSError *error = [[NSError alloc] initWithDomain:SCSCallManagerErrorDomain
                                                            code:SCSCallManagerErrorOutgoingCallPSTNPermissionDisabled
                                                        userInfo:nil];
                
                [self postOutgoingFailureNotificationWithError:error];
                
                return;
            }
        }
        
        NSError *dialError = nil;
        SCPCall *call = [SPCallManager dial:number
                                       uuid:uuid
                                     isPSTN:isPSTN
                                displayName:displayName
                        queuedVideoRequest:_hasQueuedVideoRequest
                                      error:&dialError];
        
        if([[self class] isMagicNumber:number]) {
        
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [[NSNotificationCenter defaultCenter] postNotificationName:kSCPOutgoingCallRequestMCFulFilledNotification
                                                                    object:self];
            });
        }
        else if(dialError)
            [self postOutgoingFailureNotificationWithError:dialError];
        else
            [self postOutgoingSuccessNotificationWithCall:call];
    });
}

- (void)postOutgoingFailureNotificationWithError:(NSError *)error {
    
    dispatch_async(dispatch_get_main_queue(), ^{

        NSMutableDictionary *userInfo = [NSMutableDictionary new];
        
        if(_pendingViewController)
            [userInfo setObject:_pendingViewController
                         forKey:kSCPViewControllerDictionaryKey];
        
        if(error)
            [userInfo setObject:error
                         forKey:kSCPErrorDictionaryKey];
    
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCPOutgoingCallRequestFailedNotification
                                                            object:self
                                                          userInfo:userInfo];
    });
}

- (void)postOutgoingSuccessNotificationWithCall:(SCPCall *)call {

    if(!call) {
    
        [self postOutgoingFailureNotificationWithError:nil];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSMutableDictionary *userInfo = [NSMutableDictionary new];
        
        if(_pendingViewController)
            [userInfo setObject:_pendingViewController
                         forKey:kSCPViewControllerDictionaryKey];
        
        [userInfo setObject:call
                     forKey:kSCPCallDictionaryKey];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCPOutgoingCallRequestFulfilledNotification
                                                            object:self
                                                          userInfo:userInfo];
    });
}

@end
