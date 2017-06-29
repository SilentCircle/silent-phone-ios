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
//  SCPPasscodeManager.m
//
//  Created by Stelios Petrakis on 06/07/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCPPasscodeManager.h"
#import "SCPNotificationKeys.h"

static NSString * const kSCSPasscodeFailedAttemptsCount  = @"kSCSPasscodeFailedAttemptsCount";
static NSString * const kSCSPasscodeLastFailedAttemptDate= @"kSCSPasscodeLastFailedAttemptDate";

NSString * const kSCPPasscodeItemAccountKey = @"kSCPPasscodeItemAccountKey";
NSString * const kSCPPasscodeItemServiceKey = @"kSCPPasscodeItemAccountKey";

NSString * const kSCSPasscodeErrorDomain = @"kSCSPasscodeErrorDomain";

/**
 Passcode related error codes
 */
typedef NS_ENUM(NSInteger, kSCSPasscodeErrorCode) {
    /** Error (reason unknown).*/
    kSCSPasscodeErrorUnknown = -1,
    /** Passcode failed attempt.*/
    kSCSPasscodeFailedAttempt = -100,
    /** Passcode could not be found.*/
    kSCSPasscodeNotFound = -404,
    /** Passcode evaluation not allowed due to locking.*/
    kSCSPasscodeEvaluationNotAllowed = -403,
};

@interface SCPPasscodeManager ()
{
    LAContext *_context;
    NSMutableDictionary *_passcodeQuery;
    
    NSDate *_storedDate;
    
    NSTimer *_failedAttemptsTimer;
    
    BOOL _isUnlocked;
}
@end

@implementation SCPPasscodeManager

#pragma mark - Class methods

+ (SCPPasscodeManager *)sharedManager {
    
    static SCPPasscodeManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    
    return sharedInstance;
}

#pragma mark - Lifecycle

- (instancetype)init {
    
    if(self = [super init]) {

        _context = [LAContext new];
        
        [self setupFailedAttemptsTimer];
        
        // Set up the keychain search dictionary:
        _passcodeQuery = [NSMutableDictionary new];
        
        // This keychain item is a generic password.
        [_passcodeQuery setObject:(__bridge id)kSecClassGenericPassword
                           forKey:(__bridge id)kSecClass];
        
        // Return the attributes of the keychain item (the password is
        //  acquired in the secItemFormatToDictionary: method):
        [_passcodeQuery setObject:(__bridge id)kCFBooleanTrue
                           forKey:(__bridge id)kSecReturnAttributes];
        
        [_passcodeQuery setObject:kSCPPasscodeItemAccountKey
                           forKey:(__bridge id)kSecAttrAccount];
        
        [_passcodeQuery setObject:kSCPPasscodeItemServiceKey
                           forKey:(__bridge id)kSecAttrService];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];

        _isUnlocked = ![self doesPasscodeExist];
    }
    
    return self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self invalidateFailedAttemptsTimer];
}

#pragma mark - Notifications 

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    
    [self setupFailedAttemptsTimer];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    
    [self invalidateFailedAttemptsTimer];
}

#pragma mark - Public API

- (BOOL)supportsTouchID {
        
    return [_context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil];
}

- (BOOL)isWipeEnabled {
    
    int passcodeIsWipeEnable(void);
    
    return (BOOL)passcodeIsWipeEnable();
}

- (BOOL)isTouchIDEnabled {
    
    int passcodeIsTouchIDEnabled(void);

    return (BOOL)passcodeIsTouchIDEnabled();
}

- (void)presentTouchID:(NSString *)localizedReason fallbackTitle:(NSString *)localizedFallbackTitle completion:(void(^)(BOOL success, NSError * error))completion {

    if(![self supportsTouchID]) {
        
        if(completion) {
        
            NSError *error = [NSError errorWithDomain:LAErrorDomain
                                                 code:LAErrorTouchIDNotAvailable
                                             userInfo:nil];
            
            completion(NO, error);
        }
        
        return;
    }
    
    // References
    // https://www.raywenderlich.com/92667/securing-ios-data-keychain-touch-id-1password
    // https://developer.apple.com/library/ios/documentation/LocalAuthentication/Reference/LocalAuthentication_Framework/
    // https://developer.apple.com/library/ios/samplecode/KeychainTouchID/Introduction/Intro.html
    // https://developer.apple.com/videos/play/wwdc2015/706/
    // http://willowtreeapps.com/blog/enhanced-device-security-in-ios-9/

    // We create a new context each time so that we will trigger the Touch ID dialog
    // to appear everytime. Otherwise it remembers that you have recently entered your biometric info and doesn't appear
    LAContext *context = [LAContext new];
    [context setLocalizedFallbackTitle:localizedFallbackTitle];
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics
             localizedReason:localizedReason
                       reply:^(BOOL success, NSError * _Nullable error) {
                           
                           if(success) {
                               
                               _isUnlocked = YES;
                               
                               [self clearFailedAttempts];
                           }
                           
                           if(completion)
                               completion(success, error);
                       }];
}

- (BOOL)setPasscode:(NSString *)passcode {
    
    CFDictionaryRef attributes = nil;
    NSMutableDictionary *updateItem = nil;
    
    NSDictionary *keychainData = @{ (__bridge id)kSecValueData: passcode };
    
    OSStatus errorcode = noErr;
    
    // If the keychain item already exists, modify it:
    if (SecItemCopyMatching((__bridge CFDictionaryRef)_passcodeQuery,
                            (CFTypeRef *)&attributes) == noErr)
    {
        // First, get the attributes returned from the keychain and add them to the
        // dictionary that controls the update:
        updateItem = [NSMutableDictionary dictionaryWithDictionary:(__bridge_transfer NSDictionary *)attributes];
        
        // Second, get the class value from the generic password query dictionary and
        // add it to the updateItem dictionary:
        [updateItem setObject:[_passcodeQuery objectForKey:(__bridge id)kSecClass]
                       forKey:(__bridge id)kSecClass];
        
        // Finally, set up the dictionary that contains new values for the attributes:
        NSMutableDictionary *tempCheck = [self dictionaryToSecItemFormat:keychainData];
        //Remove the class--it's not a keychain attribute:
        [tempCheck removeObjectForKey:(__bridge id)kSecClass];
        
        // You can update only a single keychain item at a time.
        errorcode = SecItemUpdate(
                                  (__bridge CFDictionaryRef)updateItem,
                                  (__bridge CFDictionaryRef)tempCheck);
    }
    else
    {
        // No previous item found; add the new item.
        // The new value was added to the keychainData dictionary in the mySetObject routine,
        // and the other values were added to the keychainData dictionary previously.
        // No pointer to the newly-added items is needed, so pass NULL for the second parameter:
        errorcode = SecItemAdd(
                               (__bridge CFDictionaryRef)[self dictionaryToSecItemFormat:keychainData],
                               NULL);
        
        if (attributes)
            CFRelease(attributes);
    }
    
    return (errorcode == noErr);
}

- (BOOL)evaluatePasscode:(NSString *)passcode error:(NSError **)outError {
    
    return [self evaluatePasscode:passcode calculateFailedAttempts:YES error:outError];
}

- (BOOL)evaluatePasscode:(NSString *)passcode calculateFailedAttempts:(BOOL)calculateFailedAttempts error:(NSError **)outError {

    if([self isPasscodeLocked]) {
        
        if(outError)
            *outError = [[NSError alloc] initWithDomain:kSCSPasscodeErrorDomain
                                                   code:kSCSPasscodeEvaluationNotAllowed
                                               userInfo:nil];
            
        return NO;
    }
    
    //Initialize the dictionary used to hold return data from the keychain:
    CFMutableDictionaryRef outDictionary = nil;
    
    // If the keychain item exists, return the attributes of the item:
    OSStatus keychainErr = SecItemCopyMatching((__bridge CFDictionaryRef)_passcodeQuery,
                                      (CFTypeRef *)&outDictionary);
    
    if (keychainErr == noErr) {
        
        // Convert the data dictionary into the format used by the view controller:
        NSMutableDictionary *keychainData = [self secItemFormatToDictionary:(__bridge_transfer NSMutableDictionary *)outDictionary];
        
        if(!keychainData) {
            
            if(outError)
                *outError = [[NSError alloc] initWithDomain:kSCSPasscodeErrorDomain
                                                       code:kSCSPasscodeNotFound
                                                   userInfo:nil];
            
            return NO;
        }
        
        NSString *storedPasscode = (NSString *)[keychainData objectForKey:(__bridge id)kSecValueData];
        
        if(!storedPasscode) {

            if(outError)
                *outError = [[NSError alloc] initWithDomain:kSCSPasscodeErrorDomain
                                                       code:kSCSPasscodeNotFound
                                                   userInfo:nil];

            return NO;
        }
        
        BOOL isCorrectPasscode = [passcode isEqualToString:storedPasscode];
        
        if(isCorrectPasscode) {

            _isUnlocked = YES;
            
            if(calculateFailedAttempts)
                [self clearFailedAttempts];
            
            return YES;
        }
        else {
            
            if(calculateFailedAttempts) {
                
                [self increaseFailedAttempts];
                [self setupFailedAttemptsTimer];
            }

            if(outError)
                *outError = [[NSError alloc] initWithDomain:kSCSPasscodeErrorDomain
                                                       code:kSCSPasscodeFailedAttempt
                                                   userInfo:nil];
            
            return NO;
        }
    }
    
    return NO;
}

- (BOOL)deletePasscode {
    
    NSMutableDictionary *tmpDictionary = [self dictionaryToSecItemFormat:_passcodeQuery];
    [tmpDictionary removeObjectForKey:(__bridge id)kSecMatchLimit];
    
    // Delete the keychain item in preparation for resetting the values:
    OSStatus errorcode = SecItemDelete((__bridge CFDictionaryRef)tmpDictionary);
    
    return (errorcode == noErr);
}

- (BOOL)doesPasscodeExist {
    
    return (SecItemCopyMatching((__bridge CFDictionaryRef)_passcodeQuery, nil) == noErr);
}

- (void)startPasscodeTimeoutTimer {
    
    if(!_isUnlocked)
        return;
    
    _storedDate = [NSDate date];
}

- (BOOL)shouldShowPasscodeBasedOnTimeoutTimer {
    
    // If there is no stored date, we always need to require passcode
    if(!_storedDate) {
        
        _isUnlocked = NO;
        
        return YES;
    }

    NSTimeInterval savedInterval= [self savedPasscodeTimeout];
    
    // If the saved user preference is 0, then require passcode
    if(savedInterval == 0) {
        
        _isUnlocked = NO;
        
        return YES;
    }
    
    NSTimeInterval timeInterval = [[NSDate date] timeIntervalSinceDate:_storedDate];

    // Clear the stored date
    _storedDate = nil;
    
    // Require passcode if the time interval between the stored date and now is more than the user selected one (allowed)
    
    BOOL shouldShow = (timeInterval > savedInterval);
    
    _isUnlocked = !shouldShow;
    
    return shouldShow;
}

- (BOOL)isPasscodeLocked {
    
    return ([self secondsUntilUnlock] > 0);
}

- (NSInteger)numberOfFailedAttempts {
    
    return [self failedAttemptsCount];
}

- (NSTimeInterval)secondsUntilUnlock {
    
    if(![self lastFailedAttemptDate])
        return 0;
    
    NSTimeInterval timeIntervalSinceLastFailedAttempt   = [[NSDate date] timeIntervalSinceDate:[self lastFailedAttemptDate]];
    NSTimeInterval timeIntervalBasedOnFailedAttempts    = [self timeIntervalBasedOnFailedAttempts];

    NSTimeInterval difference = timeIntervalBasedOnFailedAttempts - timeIntervalSinceLastFailedAttempt;
    
    if(difference <= 1)
        return 0;

    return difference;
}

- (NSString *)tryAgainInString {

    NSInteger seconds = [self secondsUntilUnlock];

    if(seconds == 0)
        return NSLocalizedString(@"Try again now", nil);
    
    NSString *tryAgainSubString = NSLocalizedString(@"Try again in", nil);
    
    NSInteger minutes = (seconds < 60 ? 1 : (NSInteger)round((double)seconds / (double)60.0f));
    
    NSString *tryAgain = [NSString stringWithFormat:@"%@ 1 %@", tryAgainSubString, NSLocalizedString(@"hour", nil)];
    
    if(minutes < 60)
        tryAgain = [NSString stringWithFormat:@"%@ %ld %@",
                    tryAgainSubString,
                    (long)minutes,
                    (minutes == 1 ? NSLocalizedString(@"minute", nil) : NSLocalizedString(@"minutes", nil))];
    
    return tryAgain;
}

#pragma mark - Private

// Load failed attempts variables from User Defaults
- (NSInteger) failedAttemptsCount { return [[NSUserDefaults standardUserDefaults] integerForKey:kSCSPasscodeFailedAttemptsCount]; }
- (NSDate *) lastFailedAttemptDate { return (NSDate*)[[NSUserDefaults standardUserDefaults] objectForKey:kSCSPasscodeLastFailedAttemptDate]; }

- (void)invalidateFailedAttemptsTimer {
    
    if(!_failedAttemptsTimer)
        return;
    
    [_failedAttemptsTimer invalidate];
    _failedAttemptsTimer = nil;
}

- (void)setupFailedAttemptsTimer {
    
    if(![self isPasscodeLocked])
        return;
    
    [self invalidateFailedAttemptsTimer];
    
    _failedAttemptsTimer = [NSTimer scheduledTimerWithTimeInterval:[self secondsUntilUnlock]
                                                            target:self
                                                          selector:@selector(passcodeDidUnlock:)
                                                          userInfo:nil
                                                           repeats:NO];
}

- (void)passcodeDidUnlock:(NSTimer *)timer {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSPasscodeDidUnlock
                                                            object:self];
    });
}

- (NSTimeInterval)timeIntervalBasedOnFailedAttempts {
    
    NSInteger failedAttemptsCount = [self failedAttemptsCount];
    
    if(failedAttemptsCount < 5)
        return 0;
    else if(failedAttemptsCount == 5)
        return (NSTimeInterval)60;          // 1 minute
    else if(failedAttemptsCount == 6)
        return (NSTimeInterval)(5 * 60);    // 5 minutes
    else if(failedAttemptsCount == 7)
        return (NSTimeInterval)(15 * 60);   // 15 minutes
    else
        return (NSTimeInterval)(60 * 60);   // 1 hour
}

- (void)clearFailedAttempts {
    
    [self storeFailedAttemptsCount:0
                              date:nil];
}

- (void)increaseFailedAttempts {
    
    [self storeFailedAttemptsCount:([self failedAttemptsCount] + 1)
                              date:[NSDate date]];
}

- (void)storeFailedAttemptsCount:(NSInteger)failedAttemptsCount date:(NSDate *)lastFailedAttemptDate {
    
    [[NSUserDefaults standardUserDefaults] setInteger:failedAttemptsCount
                                               forKey:kSCSPasscodeFailedAttemptsCount];
    [[NSUserDefaults standardUserDefaults] setObject:lastFailedAttemptDate
                                              forKey:kSCSPasscodeLastFailedAttemptDate];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSTimeInterval)savedPasscodeTimeout {

    char * getPasscodeTimeout(void);
    
    char *passcodeTimeout = getPasscodeTimeout();
    NSString *timeoutString = [[NSString alloc] initWithUTF8String:passcodeTimeout];
    
    if([timeoutString isEqualToString:@"Immediately"])
        return (NSTimeInterval)0;
    else if([timeoutString isEqualToString:@"10 seconds"])
        return (NSTimeInterval)10;
    else if([timeoutString isEqualToString:@"30 seconds"])
        return (NSTimeInterval)30;
    else if([timeoutString isEqualToString:@"1 minute"])
        return (NSTimeInterval)60;
    else if([timeoutString isEqualToString:@"2 minutes"])
        return (NSTimeInterval)120;
    else if([timeoutString isEqualToString:@"5 minutes"])
        return (NSTimeInterval)300;
    else if([timeoutString isEqualToString:@"15 minutes"])
        return (NSTimeInterval)900;
    else if([timeoutString isEqualToString:@"30 minutes"])
        return (NSTimeInterval)1800;
    else
        return (NSTimeInterval)60; // Defaults to 1 minute if no saved passcode timeout can be found
}

- (NSMutableDictionary *)dictionaryToSecItemFormat:(NSDictionary *)dictionaryToConvert
{
    // This method must be called with a properly populated dictionary
    // containing all the right key/value pairs for a keychain item search.
    
    // Create the return dictionary:
    NSMutableDictionary *returnDictionary =
    [NSMutableDictionary dictionaryWithDictionary:dictionaryToConvert];
    
    [returnDictionary setObject:kSCPPasscodeItemAccountKey
                         forKey:(__bridge id)kSecAttrAccount];
    
    [returnDictionary setObject:kSCPPasscodeItemServiceKey
                         forKey:(__bridge id)kSecAttrService];

    [returnDictionary setObject:(__bridge id)kSecClassGenericPassword
                         forKey:(__bridge id)kSecClass];
    
    // We want to make the passcode keychain item available even if the app launches
    // in background mode
    [returnDictionary setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                         forKey:(__bridge id)kSecAttrAccessible];
    
    // Convert the password NSString to NSData to fit the API paradigm:
    NSString *passwordString = [dictionaryToConvert objectForKey:(__bridge id)kSecValueData];
    
    if(passwordString)
        [returnDictionary setObject:[passwordString dataUsingEncoding:NSUTF8StringEncoding]
                             forKey:(__bridge id)kSecValueData];
    
    return returnDictionary;
}

// Implement the secItemFormatToDictionary: method, which takes the attribute dictionary
//  obtained from the keychain item, acquires the password from the keychain, and
//  adds it to the attribute dictionary:
- (NSMutableDictionary *)secItemFormatToDictionary:(NSDictionary *)dictionaryToConvert
{
    // This method must be called with a properly populated dictionary
    // containing all the right key/value pairs for the keychain item.
    
    // Create a return dictionary populated with the attributes:
    NSMutableDictionary *returnDictionary = [NSMutableDictionary
                                             dictionaryWithDictionary:dictionaryToConvert];
    
    // To acquire the password data from the keychain item,
    // first add the search key and class attribute required to obtain the password:
    [returnDictionary setObject:(__bridge id)kCFBooleanTrue
                         forKey:(__bridge id)kSecReturnData];
    
    [returnDictionary setObject:(__bridge id)kSecClassGenericPassword
                         forKey:(__bridge id)kSecClass];
    
    // Then call Keychain Services to get the password:
    CFDataRef passwordData = NULL;
    OSStatus keychainError = noErr; //
    keychainError = SecItemCopyMatching((__bridge CFDictionaryRef)returnDictionary,
                                        (CFTypeRef *)&passwordData);
    if (keychainError == noErr)
    {
        // Remove the kSecReturnData key; we don't need it anymore:
        [returnDictionary removeObjectForKey:(__bridge id)kSecReturnData];
        
        // Convert the password to an NSString and add it to the return dictionary:
        NSString *password = [[NSString alloc] initWithBytes:[(__bridge_transfer NSData *)passwordData bytes]
                                                      length:[(__bridge NSData *)passwordData length]
                                                    encoding:NSUTF8StringEncoding];
        
        [returnDictionary setObject:password
                             forKey:(__bridge id)kSecValueData];
    }
    // Don't do anything if nothing is found.
    else if (keychainError == errSecItemNotFound) {

        if (passwordData) CFRelease(passwordData);
    }
    // Any other error is unexpected.
    else
    {
        if (passwordData) CFRelease(passwordData);
        
        return nil;
    }
    
    return returnDictionary;
}
    
@end
