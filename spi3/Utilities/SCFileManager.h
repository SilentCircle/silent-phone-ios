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
#import <Foundation/Foundation.h>

extern NSString * const migrate_files_date_key;

@interface SCFileManager : NSObject

+ (void)setup;
+ (void)setupLogsCache;
+ (BOOL)setupSilentContactsCache;

#pragma mark SilentPhone App Directories
// These methods return file URLs for file system locations used by
// various app functionality. Please use these accessors and DO NOT
// store anything in the Documents directory, as it may be automatically
// backed up by iCloud.
+ (NSURL *)appRootDirectoryURL;
+ (NSURL *)tiviDirectoryURL;
+ (NSURL *)chatDirectoryURL;
+ (NSURL *)chatTmpDirectoryURL;
+ (NSURL *)chatDbFileURL;
+ (NSURL *)appCachesDirectoryURL;
+ (NSURL *)appSnapshotsDirectoryURL;

+ (NSURL *)mediaCacheDirectoryURL;
+ (NSURL *)scloudCacheDirectoryURL;
+ (NSURL *)recordingCacheDirectoryURL;
+ (NSURL *)logsCacheDirectoryURL;
+ (NSURL *)silentContactsCacheDirectoryURL;

#pragma mark System Directories
+ (NSURL *)documentsDirectoryURL;
+ (NSURL *)tmpDirectoryURL;
+ (NSURL *)libraryDirectoryURL;
+ (NSURL *)ApplicationSupportDirectoryURL;
+ (NSURL *)cachesDirectoryURL;
+ (NSURL *)preferencesDirectoryURL;
+ (NSURL *)cookiesDirectoryURL;
+ (NSURL *)snapshotsCacheDirectoryURL;

#pragma mark Utilities
// This method calls newDirAtURL:withIntermediateDirs:attribs:error: 
// passing withIntermediateDirs:YES - which protects from failure if the
// dir already exists - and passes attribs dict with NSFileProtectionNone.
// Additionally, it then it calls setExcludeBackupAttributeToItemAtURL: 
// to set the NSURLIsExcludedFromBackupKey attrib on the new dir.
+ (BOOL)newDirAtURL:(NSURL *)url error:(NSError *)error;
+ (BOOL)newDirAtURL:(NSURL *)url withIntermediateDirs:(BOOL)interims attribs:(NSDictionary *)dict error:(NSError *)error;
+ (BOOL)deleteFileAtURL:(NSURL *)url;
+ (BOOL)deleteFilesWithExtension:(NSString *)ext atURL:(NSURL *)dirURL;
+ (void)deleteContentsOfDirectoryAtURL:(NSURL *)url;
+ (BOOL)setExcludeBackupAttributeToItemAtURL:(NSURL *)URL;


+ (void)cleanAllCaches;
+ (void)cleanMediaCache;

+ (void)calculateScloudCacheSizeWithCompletionBlock:(void (^)(NSError *error, NSNumber *totalSize))completionBlock;

#pragma mark - Build Info
+ (NSDictionary *)debugBuildDict;
+ (NSDictionary *)releaseBuildDict;
+ (NSString *)formattedBuildInfoString;

#pragma mark - Bundle Plist
// Main bundle plist accessor 
+ (id)objectFromMainBundle:(NSString *)name type:(NSString *)type error:(NSError *)error;
+ (id)valueFromInfoPlist:(NSString *)key;
+ (id)valueFromDebugBuildDict:(NSString *)key;

+ (BOOL)isDebugBuild;
+ (BOOL)isEnterpriseBuild;

@end
