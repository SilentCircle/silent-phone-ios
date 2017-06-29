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
//  SCDataDestroyer.h
//  VoipPhone
//
//  Created by Eric Turner on 2/1/16.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * This class centralizes the implementation of an absolutely destructive
 * "destroy all data" feature.
 */
@interface SCDataDestroyer : NSObject

/**
 * All app-related files and directories in the app's sandboxed file 
 * system will be deleted,
 *
 * NSUserDefaults will be cleared.
 *
 * All keychain items set with either of the two known used
 * account/service identifiers will be deleted.
 * (see STKeychain)
 * ### UPDATE
 * 02/02/16
 * Maintain persistent device ID in keychain; do not remove when deleting
 * PWDKey keychain item.
 *
 * 02/02/16
 * The file system clean operations have been updated to try to preserve
 * a working directory structure so that the app would continue to be
 * functional, with the behavior that after a relaunch (assuming an
 * "exit()" afterward) the provisioning workflow will be presented.
 */
+ (void)wipeAllAppDataImmediatelyWithCompletion:(void (^)())completion;

+ (void)wipeAllAppData;
+ (void)clearFileSystemData;
+ (void)clearUserDefaults;

+ (void)deleteKeychainItems;
+ (void)deletePWDKeychainItem;
+ (void)deleteAPIKeychainItem;
+ (void)deleteDevIdKeychainItem;
+ (BOOL)isWipingData;
+ (void)setIsWipingData:(BOOL)wipe;

@end
