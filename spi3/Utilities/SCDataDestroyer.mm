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
//  SCDataDestroyer.m
//  VoipPhone
//
//  Created by Eric Turner on 2/1/16.
//
//

#import "SCDataDestroyer.h"
#import "SCDataDestroyer+DeviceDataWipe.h"

#import "SCPCallbackInterface.h"
#import "SCPCallbackInterface+Utilities.h"
#import "SCFileManager.h"
#import "STKeychain.h"


//#pragma mark Logging
//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;     
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelWarning; 
//#endif


static BOOL _isWipingData = NO;

@implementation SCDataDestroyer : NSObject

+ (void)wipeAllAppData {
    [self deleteKeychainItems];
    [self clearUserDefaults];
    [self clearFileSystemData];
}

+ (BOOL)isWipingData
{
    return _isWipingData;
}

+ (void)setIsWipingData:(BOOL)wipe {
    _isWipingData = wipe;
}


#pragma - File System
+ (void)clearFileSystemData {
    
    // Documents dir - remove all files/dirs
    // Previous to file migration, this dir contained scloud segment 
    // files named similar to:
    // C60EEB6A-5DA8-11E6-81BF-4987E8A35F43-1470689048.sc
    NSURL *docURL = [SCFileManager documentsDirectoryURL];
    if (docURL) [SCFileManager deleteContentsOfDirectoryAtURL:docURL];
    
    // tmp dir - remove all files/dirs
    NSURL *tmpURL = [SCFileManager tmpDirectoryURL];
    if (tmpURL) [SCFileManager deleteContentsOfDirectoryAtURL:tmpURL];

    // Removes all files/dirs in /Libarary/Application Support/com.silentcircle.SilentPhone
    // which includes the tivi dir.
    NSURL *appRootURL = [SCFileManager appRootDirectoryURL];
    NSError *removeError = nil;
    NSFileManager *fm = [[NSFileManager alloc] init];
    [fm removeItemAtURL:appRootURL error:&removeError];    
    if (removeError) {
        NSLog(@"%s\n  ERROR removing dir: %@ \n%@", __PRETTY_FUNCTION__, 
              appRootURL, removeError.localizedDescription);
    }

    // Library/Caches/Snapshots/com.silentcircle.SilentPhone -
    // contains scaled images and "downscaled" dir
    // KNOWN ISSUE: the system owns, and prevents deletion of, these 
    // images which it uses at app launch.
    NSURL *snapsURL = [SCFileManager appSnapshotsDirectoryURL];
    [SCFileManager deleteContentsOfDirectoryAtURL:snapsURL];

    
    // Library/Caches/MediaCache
    // Library/Caches/RecordingCache
    // Library/Caches/SCloudCache
    // Additionally, now cleans the /Library/Caches/com.silentcircle.SilentPhone 
    // cache dir which contains Safari cache db and related files.
    [SCFileManager cleanAllCaches];  
    
    // NOT deleting Library/Preferences:
    // contains app plist Library/Preferences/com.silentcircle.SilentPhone.plist

    // Library/Cookies - remove all files/dirs
    NSURL *cookiesURL = [SCFileManager cookiesDirectoryURL];
    [SCFileManager deleteContentsOfDirectoryAtURL:cookiesURL];    
}


#pragma mark - NSUserDefaults
+ (void)clearUserDefaults {
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    
    // Write the pending remove request immediately to the permanent storage
    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
}

#pragma mark - Keychain
+ (void)deleteKeychainItems {
    [self deletePWDKeychainItem];
    [self deleteAPIKeychainItem];
    
    // Per Frank 02/02/16 - MAINTAIN persistent device ID in keychain
    // Uncomment to DESTROY persistent device ID
//    [self deleteDevIdKeychainItem];
}

+ (void)deletePWDKeychainItem {
    
    NSError *err = nil;    
    NSString *pwd = [STKeychain getPasswordForUsername:kSIP_PWD_UsernameKey
                                        andServiceName:kSIP_PWD_ServiceNameKey error:&err];
    if (err) {
        DDLogError(@"%s\n Error retrieving keychain PWD (should NOT be nil) item: %@ \nerror: %@",
              __PRETTY_FUNCTION__, pwd, err.localizedDescription);
    }
    
    err = nil;
    [STKeychain deleteItemForUsername:kSIP_PWD_UsernameKey
                       andServiceName:kSIP_PWD_ServiceNameKey error:&err];
    if (err) {
        DDLogError(@"%s\n ERROR deleting keychain PWD item: %@", 
                   __PRETTY_FUNCTION__, err.localizedDescription);
    }
    

    err = nil;
    pwd = [STKeychain getPasswordForUsername:kSIP_PWD_UsernameKey
                                        andServiceName:kSIP_PWD_ServiceNameKey error:&err];

    if (err || pwd) {
        DDLogError(@"%s\n DELETED keychain PWD (SHOULD be nil) item: %@ \nerror: %@",
              __PRETTY_FUNCTION__, pwd, err.localizedDescription);
    }
}

+ (void)deleteAPIKeychainItem {

    NSError *err = nil;
    NSString *api = [STKeychain getPasswordForUsername:kSIP_API_UsernameKey
                                        andServiceName:kSIP_API_ServiceNameKey error:&err];

    if (err) {
        DDLogError(@"%s\n RETRIEVED keychain APIKey (should NOT be nil) item: %@ \nerror: %@",
              __PRETTY_FUNCTION__, api, err.localizedDescription);        
    }
    
    err = nil;
    [STKeychain deleteItemForUsername:kSIP_API_UsernameKey
                       andServiceName:kSIP_API_ServiceNameKey error:&err];

    if (err) {
        DDLogError(@"%s\n ERROR deleting keychain APIKey item: %@", 
                   __PRETTY_FUNCTION__, err.localizedDescription);
    }

    err = nil;
    api = [STKeychain getPasswordForUsername:kSIP_API_UsernameKey
                              andServiceName:kSIP_API_ServiceNameKey error:&err];
    
    if (err) {
        DDLogError(@"%s\n DELETED keychain APIKey (SHOULD be nil) item: %@ \nerror: %@",
              __PRETTY_FUNCTION__, api, err.localizedDescription);
    }
}

+ (void)deleteDevIdKeychainItem {
    
    NSError *err = nil;
    NSString *devID = [STKeychain getPasswordForUsername:kSIP_API_UsernameKey
                                          andServiceName:kSIP_API_ServiceNameKey error:&err];
    
    if (err) {
        DDLogError(@"%s\n RETRIEVED keychain deviceID (should NOT be nil) item: %@ \nerror: %@",
              __PRETTY_FUNCTION__, devID, err.localizedDescription);
    }
    
    err = nil;
    [STKeychain deleteItemForUsername:kSPDeviceIdServiceKey
                       andServiceName:kSPDeviceIdAccountKey error:&err];
    if (err) {
        DDLogError(@"%s\n ERROR deleting keychain deviceID item: %@", 
                   __PRETTY_FUNCTION__, err.localizedDescription);
    }

    err = nil;
    devID = [STKeychain getPasswordForUsername:kSIP_API_UsernameKey
                                andServiceName:kSIP_API_ServiceNameKey error:&err];

    if (err) {
        DDLogError(@"%s\n DELETED keychain deviceID (SHOULD be nil) item: %@ \nerror: %@",
              __PRETTY_FUNCTION__, devID, err.localizedDescription);
    }
}


+ (void)wipeAllAppDataImmediatelyWithCompletion:(void (^)())completion {
    
    [Switchboard.notificationsManager cancelAllNotifications];
    [Switchboard setCfgForDataDestroy];
    [self setIsWipingData: YES];
    [self  removeUserDeviceFromWebWithCompletion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self wipeAllAppData];
            if (completion) {
                completion();
            }
        });
    }];
}

@end
