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
//  SCPPasscodeManager.h
//
//  Created by Stelios Petrakis on 06/07/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <LocalAuthentication/LocalAuthentication.h>

#define SCP_PASSCODE_MAX_WIPE_ATTEMPTS 10

/**
 SCPPasscodeManager deals with the passcode / TouchID authentication that the user can enable within the app
 
 It offers helper methods for TouchID detection and presentation and also ways to save/update/delete and evaluate a passcode that is saved in the keychain
 
 This class can be instantiated when needed.
 
 Also note that this passcode implementation is not cryptographically enforced but merely procedurally enforced.
 
 Upon user's activation, the app hides the messaging functionality behind a view that requires passcode / TouchID to disappear.
 */
@interface SCPPasscodeManager : NSObject

/**
 Returns the singleton SCPPasscodeManager reference to use throughout the app.
 
 Do not initialize the SCPPasscodeManager class yourself.
 
 @return The SCPPasscodeManager singleton instance reference.
 */
+ (SCPPasscodeManager *)sharedManager;

/**
 Returns whether TouchID is enabled for the current device
 
 @return A boolean value indicating whether the TouchID functionality is enabled for the current device (YES) or not (NO).
 */
- (BOOL)supportsTouchID;

/**
 Returns whether user has enabled TouchID from settings
 
 @return A boolean value indicating whether the user has enabled TouchID from SPi settings (YES) or not (NO).
 */
- (BOOL)isTouchIDEnabled;

/**
 Returns whether user has enabled the 'Wipe after SCP_PASSCODE_MAX_WIPE_ATTEMPTS failed passcode attempts' option
 
 @return A boolean value indicating whether the user has enabled Wipe (YES) or not (NO).
 */
- (BOOL)isWipeEnabled;

/**
 Presents the Apple-provided UI that prompts the user to touch his finger in the fingerprint sensor.
 
 @param localizedReason Application reason for authentication. This string must be provided in correct
                        localization and should be short and clear. It will be eventually displayed in
                        the authentication dialog subtitle. A name of the calling application will be
                        already displayed in title, so it should not be duplicated here.

 @param localizedFallbackTitle  Allows fallback button title customization. A default title "Enter Password" is used when
                                this property is left nil. If set to empty string, the button will be hidden.

 @param completion Reply block that is executed when policy evaluation finishes.
 
 @param success Reply parameter that is YES if the policy has been evaluated successfully or NO if
                the evaluation failed.

 @param error   Reply parameter that is nil if the policy has been evaluated successfully, or it contains
                error information about the evaluation failure.

 @warning   localizedReason parameter is mandatory and the call will throw NSInvalidArgumentException if
            nil or empty string is specified.

 @see LAError

 Typical error codes returned by this call are:
 @li          LAErrorUserFallback if user tapped the fallback button
 @li          LAErrorUserCancel if user has tapped the Cancel button
 @li          LAErrorSystemCancel if some system event interrupted the evaluation (e.g. Home button pressed).
 */
- (void)presentTouchID:(NSString *)localizedReason fallbackTitle:(NSString *)localizedFallbackTitle completion:(void(^)(BOOL success, NSError * error))completion;

/**
 Saves the given passcode in the keychain, replacing any existing one.
 
 @param passcode The given passcode we want to save.
 @return YES if the passcode has been set, NO otherwise (Keychain issue)
 */
- (BOOL)setPasscode:(NSString *)passcode;

/**
 Evaluates whether the given passcode is the same with the one already set in the keychain.
 
 @param passcode The given passcode we want to evaluate.
 @param outError The output error (useful for responding to continuous failed attempts).
 @return YES if the passcode is the same as the one already saved in the keychain, NO otherwise (or if there is no passcode already saved).
 */
- (BOOL)evaluatePasscode:(NSString *)passcode error:(NSError **)outError;

/**
 Evaluates whether the given passcode is the same with the one already set in the keychain.
 
 Use this method **only** when trying to just test if the entered passcode is the same with the previously provided one. For any other case
 (e.g. testing if user has entered the correct passcode) use only the above method!
 
 @param passcode The given passcode we want to evaluate.
 @param calculateFailedAttempts Controls whether the failed attempts count should reset or increase depending on the result of the evaluation
 @param outError The output error (useful for responding to continuous failed attempts).
 @return YES if the passcode is the same as the one already saved in the keychain, NO otherwise (or if there is no passcode already saved).
 */
- (BOOL)evaluatePasscode:(NSString *)passcode calculateFailedAttempts:(BOOL)calculateFailedAttempts error:(NSError **)outError;

/**
 Removes the passcode if already set.
 
 Use it when wiping all data from the device.
 
 @return YES if the passcode is deleted successfully, NO otherwise (not found, other Keychain issue)
 */
- (BOOL)deletePasscode;

/**
 Checks whether a passcode has been already set.
 
 @return YES if passcode exists, NO otherwise
 */
- (BOOL)doesPasscodeExist;

/**
 Saves the current timestamp in order to check it afterwards using the the - (BOOL)shouldShowPasscodeBasedOnTimeoutTimer
 method and the stored timeout user preference.
 */
- (void)startPasscodeTimeoutTimer;

/**
 Checks whether the difference of the current timestamp - the stored one from the - (void)startPasscodeTimeoutTimer 
 is greater than the stored timeout user preference. 
 
 @return YES if the difference is greater than the stored timeout user preference (so we have exceeded the allowed time and we should present a passcode screen), NO otherwise
 */
- (BOOL)shouldShowPasscodeBasedOnTimeoutTimer;

/**
 Returns whether the passcode manager is locked due to multiple failed attempts.
 
 @return YES if the passcode manager is locked, NO otherwise
 */
- (BOOL)isPasscodeLocked;

/**
 Returns the overall number of failed attempts for presentation purposes.
 
 @return The overall number of failed attempts, zero if there is no failed attempt stored.
 */
- (NSInteger)numberOfFailedAttempts;

/**
 Returns the seconds until the passcode manager is unlocked, based on the timestamp of the last failed attemt and
 the overall number of failed attempts. Returns 0 if the passcode manager is ready to be unlocked.
 
 @return The seconds left till the passcode manager is ready to accept new passcode attempts.
 */
- (NSTimeInterval)secondsUntilUnlock;

/**
 Provides the string 'Try again in X minutes (or hours) depending on the - (NSTimeInterval)secondsUntilUnlock value.
 
 This is convenience method for showing the text in UI labels
 */
- (NSString *)tryAgainInString;

@end
