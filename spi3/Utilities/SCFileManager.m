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
#import "SCFileManager.h"

#import "ChatUtilities.h"
#import "SCloudConstants.h"
#import "SCDataDestroyer.h"
#import "SCPCallbackInterface.h"
#import "SCSConstants.h"


// Log Levels: off, error, warn, info, verbose
//#if DEBUG
//  static const DDLogLevel ddLogLevel = DDLogLevelDebug;
//#else
//  static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

static BOOL IS_DEBUG_BUILD = false;
static NSDictionary *_debugBuildPlistDict = nil;

@implementation SCFileManager

/* Per Apple 
 The [ -(BOOL)fileExistsAtPath:(NSString *)path ] methods are of limited utility. 
 Attempting to predicate behavior based on the current state of the filesystem or a
 particular file on the filesystem is encouraging odd behavior in the face of 
 filesystem race conditions. It's far better to attempt an operation (like loading 
 a file or creating a directory) and handle the error gracefully than it is to try
 to figure out ahead of time whether the operation will succeed.
 */    

#pragma mark - SilentPhone App Directories

+ (void)setup {

#if DEBUG
    IS_DEBUG_BUILD = true;
    NSMutableDictionary *plistDict = (NSMutableDictionary *)[self objectFromMainBundle:@"BuildInfo" type:@"plist" error:nil];
    plistDict[kApp_version] = [self valueFromInfoPlist:@"CFBundleShortVersionString"];
    _debugBuildPlistDict = [NSDictionary dictionaryWithDictionary:plistDict];
#endif
    
    DDLogInfo(@"\n\n******** %@ Build Info ********\n%@\n******** END Build Info ********\n\n", 
              ([self isDebugBuild]) ? @"DEBUG" : @"RELEASE", 
              [self formattedBuildInfoString]);

    
    // Run file migration once
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kMigrate_or_wipe_key] == nil) {
        DDLogInfo(@"%@\n --SC-- migration flag not found -- RUN FILE MIGRATION --", THIS_METHOD);

                     //--------------------------------------------------------------
        // Create directories (except new tivi dir)
        //--------------------------------------------------------------
        [self newDirAtURL:[self appRootDirectoryURL] error:nil];
        
        // NOTE: tiviDir must be created in the _migrateAppFiles method
        // when moved or it will fail with "directory already exists.
        // DO NOT create new tivi dir here! 
        
        [self newDirAtURL:[self chatDirectoryURL]         error:nil];
        [self newDirAtURL:[self chatTmpDirectoryURL]      error:nil];
        [self newDirAtURL:[self appCachesDirectoryURL]    error:nil];
        [self newDirAtURL:[self appSnapshotsDirectoryURL] error:nil];
        //--------------------------------------------------------------
        
        //--------------------------------------------------------------
        // Migrate Files
        //--------------------------------------------------------------
        NSError *tiviMoveError = nil;
        [self _migrateAppFiles:&tiviMoveError];
        if (tiviMoveError) {
            //----------------------------------------------------------
            // NOTE:
            // The tiviMoveError is an error moving the tivi dir
            // from /Documents to the new tivi dir location. This move
            // operation is done first in _migrateAppFiles.
            //
            // Then all remaining file contents are moved from /Documents
            // to the new Chat dir location in the next operation. Note
            // that there may be an error logged by _migrateAppFiles in
            // this operation if there is a /Documents/Inbox dir.
            // See _migrateAppFiles method for more.

            // Alert user something bad happened? Bail?
            DDLogError(@"%s\n --SC-- FILE MIGRATION ERROR:\n%@", 
                         __FUNCTION__, tiviMoveError.debugDescription);
        }
        
        //--------------------------------------------------------------
        // Purge /Docs/Inbox and /tmp/*.MOV files
        //--------------------------------------------------------------
        [self _migrationFilesPurge];
    
        // Store file migration date as value
        DDLogInfo(@"%@\n --SC-- FILE MIGRATION COMPLETE -- set migration flag in user defaults", THIS_METHOD);
        [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kMigrate_or_wipe_key];
    }
    else {
        DDLogVerbose(@"%@\n --SC-- migration flag found with date: %@", 
                     THIS_METHOD, 
                     [[NSUserDefaults standardUserDefaults] objectForKey:kMigrate_or_wipe_key]
                     );
    }
}

+ (void)setupLogsCache {
    [self newDirAtURL:[self logsCacheDirectoryURL] error:nil];
}

+ (BOOL)setupSilentContactsCache {
    return [self newDirAtURL:[self silentContactsCacheDirectoryURL] error:nil];
}

// /Library/Application Support/com.silentcircle.SilentPhone
+ (NSURL *)appRootDirectoryURL {
    NSURL *url = [[self ApplicationSupportDirectoryURL] URLByAppendingPathComponent:[self bundleID]];
    return url;
}

// /Library/Application Support/com.silentcircle.SilentPhone/tivi
+ (NSURL *)tiviDirectoryURL {
    NSURL *url = [[self appRootDirectoryURL] URLByAppendingPathComponent:@"tivi"];
    return url;
}

// /Library/Caches/Application Support/com.silentcircle.SilentPhone/Chat
// For scloud segment files named similar to C60EEB6A-5DA8-11E6-81BF-4987E8A35F43-1470689048.sc
+ (NSURL *)chatDirectoryURL {
    NSURL *url = [[self appRootDirectoryURL] URLByAppendingPathComponent:@"Chat"];
    return url;
}

// /Library/Caches/Application Support/com.silentcircle.SilentPhone/Chat/ChatMessages_cipher.db
+ (NSURL *)chatDbFileURL {
    return [[self chatDirectoryURL] URLByAppendingPathComponent:@"ChatMessages_cipher.db"];
}

// /Library/Caches/Application Support/com.silentcircle.SilentPhone/Chat/tmp
// For scloud segment files named similar to C60EEB6A-5DA8-11E6-81BF-4987E8A35F43-1470689048.sc
+ (NSURL *)chatTmpDirectoryURL {
    NSURL *url = [[self chatDirectoryURL] URLByAppendingPathComponent:@"tmp"];
    return url;    
}

// /Library/Caches/com.silentcircle.SilentPhone
// contains Cache.db/related files and fsCachedData dir
+ (NSURL *)appCachesDirectoryURL {
    NSURL *url = [[self cachesDirectoryURL] URLByAppendingPathComponent:[self bundleID]];
    return url;    
}

// /Library/Caches/Snapshots/com.silentcircle.SilentPhone
// contains scaled images and "downscaled" dir
+ (NSURL *)appSnapshotsDirectoryURL {
    NSURL *url = [[self snapshotsCacheDirectoryURL] URLByAppendingPathComponent:[self bundleID]];
    return url;
}


#pragma mark - Cache Directories

+ (NSURL *)cacheDirectoryURL
{
	NSError *error = nil;
	NSURL *caches = [[NSFileManager defaultManager] URLForDirectory: NSCachesDirectory
	                                                       inDomain: NSUserDomainMask
	                                              appropriateForURL: nil
	                                                         create: YES
	                                                          error: &error];
	if (error) {
		DDLogError(@"-(%@) Error creating directory: %@", __THIS_FILE__, error.debugDescription);
	}
	
	return caches;
}

+ (NSURL *)mediaCacheDirectoryURL
{
	NSURL *cacheDirectory = [self cacheDirectoryURL];
	NSURL *mediaCacheDirectory = [NSURL URLWithString:kMediaCacheDirName relativeToURL:cacheDirectory];
	
	NSError *error = nil;
	[[NSFileManager defaultManager] createDirectoryAtURL: mediaCacheDirectory
	                         withIntermediateDirectories: YES
	                                          attributes: nil
	                                               error: &error];
	if (error) {
		DDLogError(@"-(%@) Error creating directory (%@): %@", 
                   __THIS_FILE__, mediaCacheDirectory, error.debugDescription);
	}
	
    return error ? nil : mediaCacheDirectory;
}

+ (NSURL *)scloudCacheDirectoryURL
{
	NSURL *cacheDirectory = [self cacheDirectoryURL];
    NSURL *scloudCacheDirectory = [NSURL URLWithString:kSCloudCacheDirName relativeToURL:cacheDirectory];
	
	NSError *error = nil;
	[[NSFileManager defaultManager] createDirectoryAtURL: scloudCacheDirectory
	                         withIntermediateDirectories: YES
	                                          attributes: nil
	                                               error: &error];
	if (error) {
		DDLogError(@"-(%@) Error creating directory (%@): %@", 
                   __THIS_FILE__, scloudCacheDirectory, error.debugDescription);
	}
	
	return error ? nil : scloudCacheDirectory;
}

+ (NSURL *)recordingCacheDirectoryURL
{
	NSURL *cacheDirectory = [self cacheDirectoryURL];
	NSURL *recordingCacheDirectory = [NSURL URLWithString:kRecordingCacheDirName relativeToURL:cacheDirectory];
	
	NSError *error = nil;
	[[NSFileManager defaultManager] createDirectoryAtURL: recordingCacheDirectory
	                         withIntermediateDirectories: YES
	                                          attributes: nil
	                                               error: &error];
	if (error) {
		DDLogError(@"-(%@) Error creating directory (%@): %@", 
                   __THIS_FILE__, recordingCacheDirectory, error.debugDescription);
	}
	
	return error ? nil : recordingCacheDirectory;
}

// /Library/Caches/SCLogsCache
// contains lumberjack log files
+ (NSURL *)logsCacheDirectoryURL {
    NSURL *url = [[self cacheDirectoryURL] URLByAppendingPathComponent:kSCLogsCacheDirName];
    return url;
}


// This method MUST be updated when adding any new cache directories, 
// in support of the "destroy data" feature.
// see SCDataDestroyer
+ (void)cleanAllCaches {
    
    // Remove the cache profile image
    [[ChatUtilities utilitiesInstance] clearCachedProfileImage];
    
    [self deleteContentsOfDirectoryAtURL:[self mediaCacheDirectoryURL]];
    [self deleteContentsOfDirectoryAtURL:[self recordingCacheDirectoryURL]];
    [self deleteContentsOfDirectoryAtURL:[self scloudCacheDirectoryURL]];
    [self deleteContentsOfDirectoryAtURL:[self appCachesDirectoryURL]];
    [self deleteContentsOfDirectoryAtURL:[self logsCacheDirectoryURL]];
    [self deleteContentsOfDirectoryAtURL:[self silentContactsCacheDirectoryURL]];
}

+ (void)cleanMediaCache
{
    [self deleteContentsOfDirectoryAtURL:[self mediaCacheDirectoryURL]];
}

//08/05/16 - is this used anywhere??
+ (void)calculateScloudCacheSizeWithCompletionBlock:(void (^)(NSError *error, NSNumber *totalSize))completionBlock
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ @autoreleasepool {
        
        size_t totalSize = 0;
        NSError *error     = nil;
        
        NSURL *scloudDirURL = [self scloudCacheDirectoryURL];
        NSString *dirPath = scloudDirURL.filePathURL.path;
        
        NSArray *fileNames = [NSFileManager.defaultManager contentsOfDirectoryAtPath:dirPath error:&error];
        if (!error)
        {
            
            for (NSString *filePath in fileNames)
            {
                NSString *fullPath = [dirPath stringByAppendingPathComponent: filePath];
                
                NSDictionary *attr = [NSFileManager.defaultManager attributesOfItemAtPath: fullPath error: &error];
                if(error) break;
                
                NSNumber* fileSize = [attr objectForKey:NSFileSize];
                totalSize += [fileSize unsignedLongValue];
            }
        }
        
        
        if (completionBlock)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(error, [NSNumber numberWithLongLong:totalSize] );
            });
        };
        
    }});
}


#pragma mark - System Directories

// /Documents
+ (NSURL *)documentsDirectoryURL {
    NSString *docsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) firstObject];
    NSURL    *docURL  = [NSURL fileURLWithPath:docsDir isDirectory:YES];
    return docURL;
}

// /tmp
+ (NSURL *)tmpDirectoryURL {
    NSURL *tmpURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    return tmpURL;
}

// /Library
+ (NSURL *)libraryDirectoryURL {
    NSString *libDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES) firstObject];
    NSURL    *libURL = [NSURL fileURLWithPath:libDir isDirectory:YES];
    return libURL;
}

// /Library/Application Support
+ (NSURL *)ApplicationSupportDirectoryURL {
    NSString *appSupDir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES) firstObject];
    NSURL    *appSupURL = [NSURL fileURLWithPath:appSupDir isDirectory:YES];
    return appSupURL;
}


// /Library/Caches
+ (NSURL *)cachesDirectoryURL {
    NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSURL    *cachesURL  = [NSURL fileURLWithPath:cachesPath isDirectory:YES];
    return cachesURL;
}

// /Library/Preferences
+ (NSURL *)preferencesDirectoryURL {
    NSURL *prefsURL = [[self libraryDirectoryURL] URLByAppendingPathComponent:@"Preferences"];
    return prefsURL;
}

// /Library/Cookies
+ (NSURL *)cookiesDirectoryURL {
    NSURL *cookiesURL = [[self libraryDirectoryURL] URLByAppendingPathComponent:@"Cookies"];
    return cookiesURL;
}

// /Library/Caches/Snapshots
+ (NSURL *)snapshotsCacheDirectoryURL {
    NSURL *snapsURL = [[self cachesDirectoryURL] URLByAppendingPathComponent:@"Snapshots"];
    return snapsURL;
}


// /Library/Caches/SCSilentContactsCache
// contains the txt file that has the JSON response of v2/contacts/validate API request
+ (NSURL *)silentContactsCacheDirectoryURL {
    NSURL *url = [[self cacheDirectoryURL] URLByAppendingPathComponent:kSCSilentContactsCacheDirName];
    return url;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - File Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Create directory with intermediate dirs, setting NSFileProtectionNone.
 *
 * @param aPath Path string of the file system directory to create
 * @return A wrapper for the return value of newDirAtPath:withIntermediateDirs:, passing YES as the intermediates flag
 */
+ (BOOL)newDirAtURL:(NSURL *)url error:(NSError *)error {
    
    NSDictionary *dict = @{NSFileProtectionKey: NSFileProtectionNone};
    
    BOOL result = YES;
    
    // Note that we must pass YES for intermediate dirs in case the dir
    // already exists.    
    if ([self newDirAtURL:url withIntermediateDirs:YES attribs:dict error:error]) {
        result = [self setExcludeBackupAttributeToItemAtURL:url];
    }
    return result;
}

/**
 * @param aPath Path string of the file system directory to create
 * @param intermediates Indicates whether to create non-existent directories specified in the given aPath
 * @return Boolean value indicating the success or failure to create the given file system path, respecting the BOOL intermediates flag
 */
+ (BOOL)newDirAtURL:(NSURL *)url withIntermediateDirs:(BOOL)interims attribs:(NSDictionary *)dict error:(NSError *)error {
    [[self fileManager] createDirectoryAtURL:url 
                 withIntermediateDirectories:interims 
                                  attributes:dict 
                                       error:&error];
    if (error != nil) {
        DDLogError(@"%s Error:\n%@\n creating dir at URL: \n%@",__PRETTY_FUNCTION__,
              [error localizedFailureReason], url.absoluteString);
        
        return NO;
    }
    //    NSLog(@"%s successfully created dir:%@",__PRETTY_FUNCTION__, [url.absoluteString lastPathComponent]);
    return YES;
}

+ (BOOL)moveDirContentsAtURL:(NSURL *)fromURL to:(NSURL *)toURL error:(NSError **)error {
    NSFileManager *fm = [[NSFileManager alloc] init];
    BOOL result = YES;
    
    NSError *fetchError = nil;
    NSArray *urls = [fm contentsOfDirectoryAtURL:fromURL includingPropertiesForKeys:nil options:0 error:&fetchError];
    if (!fetchError) {
        BOOL thisResult = YES;
        for (NSURL *fileURL in urls) {
            NSString *fn = [fileURL lastPathComponent];            
            NSURL *newURL = [toURL URLByAppendingPathComponent:fn];
            thisResult = [fm moveItemAtURL:fileURL toURL:newURL error:error];
            
            if (!thisResult) result = NO;
        }
    } else {
        DDLogError(@"%s\nFETCH ERROR getting contents of directory %@: \n%@",
              __FUNCTION__, toURL.relativePath, fetchError.debugDescription);        
    }
    return result;
}


#pragma mark - Delete Methods

+ (void)deleteContentsOfDirectoryAtURL:(NSURL *)url
{
    if (url == nil) return;
    
    NSFileManager *fm  = [[NSFileManager alloc] init];
    
    NSError *err = nil;
    NSDictionary *attribs = [fm attributesOfItemAtPath:url.relativePath error:&err];
    DDLogDebug(@"%s %@ (folder) attributes %@ error=[%@]",
               __FUNCTION__, url.relativePath, attribs, err.debugDescription);
    
    if (err) DDLogError(@"%s\nERROR: %@", __PRETTY_FUNCTION__, err.debugDescription);
    
    NSError *fetchError = nil;
    NSArray *urls = [fm contentsOfDirectoryAtURL:url includingPropertiesForKeys:nil options:0 error:&fetchError];
    
    if (fetchError) {
        DDLogError(@"%s\nFETCH ERROR getting contents of directory %@: \n%@",
              __FUNCTION__, url.relativePath, fetchError.debugDescription);
    }
    
    for (NSURL *fileURL in urls)
    {
        NSError *removeError = nil;
        
        [fm removeItemAtURL:fileURL error:&removeError];
        
        if (removeError) {
            DDLogError(@"%s\n  ERROR removing file (%@): %@", __FUNCTION__, fileURL, removeError.debugDescription);
        }
        
    }
}

+ (BOOL)deleteFilesWithExtension:(NSString *)ext atURL:(NSURL *)dirURL {
    if (!ext) {
        DDLogError(@"%s\nError: called with nil ext param",__FUNCTION__);
        return NO;
    }
    
    NSError *err = nil;
    NSArray *contents = [[self fileManager] contentsOfDirectoryAtURL:dirURL 
                                          includingPropertiesForKeys:@[] 
                                                             options:NSDirectoryEnumerationSkipsHiddenFiles 
                                                               error:&err];
    if (err) {
        DDLogError(@"%s\nError: contentsOfDirAtURL:%@\n%@",__FUNCTION__, dirURL, err.debugDescription);
        return NO;
    }
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension matches[c] %@", ext];
    NSArray *fileURLs = [contents filteredArrayUsingPredicate:predicate];
    
    __block BOOL result = YES;
    __block BOOL loopResult = YES;
    // Enumerate each .[ext] file in directory
    [fileURLs enumerateObjectsUsingBlock:^(NSURL *furl, NSUInteger idx, BOOL * _Nonnull stop) {
        loopResult = [self deleteFileAtURL:furl];
        if (!loopResult) { 
            result = NO;
        }
    }];
    return result;
}

/**
 * This method deletes a file or directory at the (file) URL constructed with the given string.
 * @param strURL The string path with which to construct an NSURL instance.
 * @return Boolean success value for delete operation of the file system resource at the given path string. Caution: deletes path subdirectories.
 */
+ (BOOL)deleteFileAtURL:(NSURL *)url {    
    NSError *err = nil;
    BOOL result = [[self fileManager] removeItemAtURL:url error:&err];
    if (err) {
        DDLogError(@"%s Error: %@\n encountered deleting item at URL:%@",
                   __FUNCTION__, err.debugDescription, url.absoluteString);
    }
    //    NSLog(@"%s successfully deleted item: %@",__PRETTY_FUNCTION__, [url.absoluteString lastPathComponent]);
    return result;
}

/**
 * Set no-backup flag for iCloud backup
 *
 * Setting “do not back up” attribute ( NSURLIsExcludedFromBackupKey ). If you want to copy data to the documents 
 * folder for offline use and don’t want it to be backed-up by iCloud you should set the “do not back up” attribute.
 * For NSURL objects, add the NSURLIsExcludedFromBackupKey attribute to prevent the corresponding file from being
 * backed up. For CFURLRef objects, use the corresponding kCFURLIsExcludedFromBackupKey attribute.
 * http://peoplecloudlabs.com/setting-do-not-back-up-attribute-nsurlisexcludedfrombackupkey/
 *
 * @param URL The NSURL of the file system resource attribute for which to set the NSURLIsExcludedFromBackupKey attribute
 * @return A boolean desribing the success or failure of the operation
 */
+ (BOOL)setExcludeBackupAttributeToItemAtURL:(NSURL *)url {
    NSError *error = nil;
    BOOL success = [url setResourceValue: @(YES) forKey: NSURLIsExcludedFromBackupKey error: &error];
    if (!success) {
        DDLogError(@"%sError excluding %@ from backup: %@", 
                   __FUNCTION__, [url lastPathComponent], error.debugDescription);
    }
    else {
        DDLogDebug(@"%s %@ successfully excluded from backup", 
                        __FUNCTION__, [url lastPathComponent]);
    }
    return success;
}


#pragma mark - Convenience Accessors

/**
 * @return A convenience accessor for the NSFileManager defaultManager
 */
+ (NSFileManager *)fileManager {
    return [NSFileManager defaultManager];
}

+ (NSString *)bundleID {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    return bundleId;
}


#pragma mark - File Migration

+ (BOOL)_migrateAppFiles:(NSError **)error {
    NSFileManager *fm = [[NSFileManager alloc] init];
    BOOL tiviResult = YES;
    
    // Move tivi folder with files to /Library/Application Support/com.silentcircle.SilentPhone/tivi
    NSURL *oldTiviURL = [[SCFileManager documentsDirectoryURL] URLByAppendingPathComponent:@"tivi"];        
    NSURL *newTiviURL = [self tiviDirectoryURL];
    
    NSError *tiviErr = nil;
    tiviResult = [fm moveItemAtURL:oldTiviURL toURL:newTiviURL error:&tiviErr];
    
    // Error.code == 4 means the tivi dir did not exist and the move has
    // failed. In this case, the tivi folder must be created here so that
    // the db path will be valid later.
    if (tiviErr && tiviErr.code == 4) {        
        [self newDirAtURL:[self tiviDirectoryURL] error:*error];
    }
    // Move all Documents dir files to /Library/Application Support/com.silentcircle.SilentPhone/Chat
    NSURL *chatURL = [self chatDirectoryURL];
    NSURL *docsURL = [self documentsDirectoryURL];
    NSError *chatErr = nil;
    BOOL chatResult = [self moveDirContentsAtURL:docsURL
                                              to:chatURL
                                           error:&chatErr];
    
    //------------------------------------------------------------------
    // NOTE:
    // If there are files in the /Documents/Inbox dir, they were created
    // by the system at "Open-In" operations. In this case, the bool
    // result returned by moveDirContentsAtURL:to:error:, stored in the
    // chatResult var, will be false and the chatErr will be logged.
    // The error description will be something like "you don't have 
    // permission to access the Chat dir", but it really means, "The
    // system owns the Inbox dir and it can't be moved to Chat".
    // This is not a migration failure. Also, any files in the Inbox dir
    // will be purged in a separate method call.
    //------------------------------------------------------------------
    if (chatErr) {
        DDLogError(@"%s --- moveDirContentsAtURL: %@ to: %@ returned error: %@",
              __FUNCTION__, docsURL, chatURL, chatErr.localizedDescription);
    }
    
    return (tiviResult && chatResult);
}

// Purge the /tmp dir of .MOV files, created by the Apple UIImagePickerController
// when creating a video to send as attachment.
// The [ChatManager convertToMP4WithpickerInfo:forAttachment:]
// method now removes the tmp .MOV file after converting to .mp4.
+ (void)_migrationFilesPurge {
    // Purge .MOV files from /tmp        
    [SCFileManager deleteFilesWithExtension:@"MOV" atURL:[SCFileManager tmpDirectoryURL]];
    
    // Purge "Open-In" shared files, e.g. from Dropbox
    // in /Documents/Inbox (created by system at open-in)
    NSURL *inboxURL = [[self documentsDirectoryURL] URLByAppendingPathComponent:@"Inbox"];
    [SCFileManager deleteContentsOfDirectoryAtURL:inboxURL];
}


#pragma mark - Build Info
/**
 * Debug build info dictionary retrieved from bundle BuildInfo.plist,
 * updated with conditional runtime modifications.
 *
 * BuildInfo.plist is generated by a Build Phase script and copied to
 * the bundle.
 *
 * The dictionary from plist contains:
 * top-level key/vals:
 *  current_branch:         fix/enterprise_buildInfo 
 *  current_branch_count:   3226
 *  current_hash:          86972af9d87d378ecc38ccf55bec02058f5199a6
 *  current_short_hash:     86972af9
 *  submodules_info (array of dictionaries):
 *    submods_branch:       libs/libzina
 *    submods_short_branch: libzina
 *    submods_hash:         1a856111addabdbd2831c3fa34d3c5dba884edeb
 *    submods_short_hash:   1a856111
 *    submods_details:      (spi/v3.3.6-91-g1a85611)
 *
 * Additionally, to the dictionary from list is added top level
 * app_version and build_count key/vals, as well as values for 
 * current_branch and current_branch_count keys which conditionally 
 * handle Enterprise builds.
 *
 * @return dictionary deserialized from BuildInfo.plist, with conditional
 *         value updates.
 */
+ (NSDictionary *)debugBuildDict {
    NSMutableDictionary *info = [_debugBuildPlistDict mutableCopy];
    NSString *version = [NSString stringWithFormat:@"v%@", info[kApp_version]];    
    info[kApp_version] = version;
    info[kCurrent_branch] = [self currentBranchName];
    info[kCurrent_branch_count] = [self currentVersionCount];
    
    return [NSDictionary dictionaryWithDictionary:info];
}

/**
 * Returns build information as a single formatted string.
 *
 * The build info returned is conditional on build type, i.e., DEBUG
 * or RELEASE. AppDelegate uses this string for logging at launch.
 */
+ (NSString *)formattedBuildInfoString {
    
    NSString *retStr = @"[ Build Info N/A ]";
    
#if DEBUG
    NSDictionary *dict = [self debugBuildDict];
    NSMutableString *mStr = [NSMutableString new];
    
    if (dict[kApp_version]) {
        [mStr appendFormat:@"%@ (%@)", 
         dict[kApp_version], dict[kCurrent_branch_count]];
    }
    
    if(dict[kCurrent_branch])     { [mStr appendFormat:@"\n%@", dict[kCurrent_branch]];     }    
    if(dict[kCurrent_short_hash]) { [mStr appendFormat:@" %@",  dict[kCurrent_short_hash]]; }
    
    if (dict[kSubmodules]) {
        NSArray *subsArr = dict[kSubmodules];
        [subsArr enumerateObjectsUsingBlock:^(id  _Nonnull subDict, NSUInteger idx, BOOL * _Nonnull stop) {
            if(subDict[kSubmod_short_branch])   { [mStr appendFormat:@"\n%@",   subDict[kSubmod_short_branch]]; }
            if(subDict[kSubmod_short_hash])     { [mStr appendFormat:@" %@",    subDict[kSubmod_short_hash]];   }
            if(subDict[kSubmod_branch_details]) { [mStr appendFormat:@"\n\t%@", subDict[kSubmod_short_hash]];   }
            if (idx != subsArr.count -1)        { [mStr appendString:@"\n"]; }
        }];
    }
    
    if (mStr.length) { retStr = [NSString stringWithString:mStr]; }
    
#else
    
    NSDictionary *dict = [self releaseBuildDict];
    retStr = [NSString stringWithFormat:@"v%@ (%@)", 
              dict[kApp_version], 
              (dict[kBuild_count]) ?: @"N/A"];
#endif 
    
    return retStr;
}

/**
 * Returns a "branch" string for use in debug build info, conditional on
 * Xcode or automated build system Enterprise build.
 *
 * @return "enterprise" for Enterprise build, and otherwise the value
 *         for key "current_branch" from the BuildInfo.plist.
 */
+ (NSString *)currentBranchName {
#if DEBUG    
    // The branch string returned by Git for enterprise automated builds,
    // stored in DebugBuildInfo.plist, is "(HEAD detached at [hash])".
    // Check Info.plist CFBundleIdentifier to see if it contains
    // "enterprise", which we'll use as the branch name.
    if ([self isEnterpriseBuild]) {
        return @"enterprise";
    }
    return ([self valueFromDebugBuildPlist:kCurrent_branch]) ?: @"(branch N/A)";
#endif
    // branch name is not used in release build info
    return @"";
}

/**
 * Returns a "version count", conditional on Xcode or automated build
 * system Enterprise build.
 *
 * The automated build system updates the Info.plist of Enterprise builds
 * with the build number seen on the downloads web page. This value is
 * returned for Enterprise builds.
 *
 * For other DEBUG builds, the value for key "current_branch_count" is
 * returned, stored in the BuildInfo.plist, which is the count of all
 * commits on the currently built branch. This is (hopefully) more 
 * useful for developers.
 *
 * For release builds, the Info.plist value for key "CFBundleVersion" 
 * is returned.
 *
 * @return version number conditional on Enterprise, DEBUG, or RELEASE
 *         build configuration.
 */
+ (NSString *)currentVersionCount {
#if DEBUG
    // If built by the automated build system, return Info.plist CFBuildVersion.
    // Useful for correlating build system builds with the number set by
    // the automated build system.
    if ([self isAutomatedBuild]) {
        return ([self valueFromInfoPlist:@"CFBundleVersion"]) ?: @"N/A";
    }
    // Use the git count of commits on the current branch, useful for 
    // developers building topic branch, rather than the static
    // Info.plist CFBundleVersion.
    return ([self valueFromDebugBuildPlist:kCurrent_branch_count]) ?: @"N/A"; 
#endif
    return [self releaseBuildDict][kBuild_count];
}

/**
 * @return dictionary constructed with basic Info.plist version values.
 */
+ (NSDictionary *)releaseBuildDict {
    NSString *app_version = [self valueFromInfoPlist:@"CFBundleShortVersionString"];
    NSString *build_count = [self valueFromInfoPlist:@"CFBundleVersion"];
    if (app_version) {
        if (build_count) {
            return @{kApp_version:app_version, kBuild_count:build_count}; 
        }
        return @{kApp_version:app_version};
    }
    
    return [NSDictionary new];
}

/**
 * @return True if DEBUG build, false otherwise.
 *
 * Static variable set in +setup method.
 *
 * This API is implemented in this class for the SideMenuTVC instance
 * written in Swift. The C #if DEBUG statement did not work in the Swift
 * code and, for some reason, its local isDebugBuild variable would 
 * change value somehow when VoiceOver became active.
 */
+ (BOOL)isDebugBuild {
    return IS_DEBUG_BUILD;
}

/**
 * @return True if CFBundleIdentifier contains "enterprise" substring.
 */
+ (BOOL)isEnterpriseBuild {
    NSString *bId = [self valueFromInfoPlist:@"CFBundleIdentifier"];
    return (bId && [bId containsString:@"enterprise"]);
}

/**
 * @return True if SCAutomatedBuild is set in Info.plist by automated
 *         build system.
 */
+ (BOOL)isAutomatedBuild {
    // This key is set by the automated build system in Info.plist at
    // compile time.
    return (BOOL)[self valueFromInfoPlist:@"SCAutomatedBuild"];
}


#pragma mark - Bundle Plist Utilities
/**
 * @param key The key with which to access an Info.plist value.
 *
 * @return The value accessed from Info.plist with the given key.
 *         May be nil.
 */
+ (id)valueFromInfoPlist:(NSString *)key {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: key];
}

/**
 * @param key The key with which to access the dictionary constructed
 *        by the debugBuildDict method, containing runtime updates to
 *        the in-memory _debugBuildPlistDict dictionary.
 *
 * @return The value accessed from debugBuildDict dictionary with the 
 *         given key. May be nil.
 */
+ (id)valueFromDebugBuildDict:(NSString *)key {
    return [self debugBuildDict][key];
}

/**
 * Public accessor to return a BuildInfo.plist value for given key.
 *
 * In the +setup method, the _debugBuildPlistDict private static variable
 * is initialized from the deserialized BuildInfo.plist.
 *
 * Note that the debugBuildDict method returns a dictionary which starts
 * with the _debugBuildPlistDict and makes runtime modifications to
 * some values. This method access the values set in the BuildInfo.plist
 * by the BuildInfo.swift Build Phase script.
 *
 * @param The key with which to access the private _debugBuildPlistDict
 *        dictionary, deserialized from BuildInfo.plist.
 *
 * @return The value accessed from the in-memory _debugBuildPlistDict for
 *         the given key. May be nil.
 */
+ (id)valueFromDebugBuildPlist:(NSString *)key {
    return _debugBuildPlistDict[key];
}

/**
 * Main bundle plist accessor. 
 */
+ (id)objectFromMainBundle:(NSString *)name type:(NSString *)type error:(NSError *)error {

    id retObj = nil;
    NSURL  *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:name ofType:type]];
    
    if (url) {
        NSError *local_err = nil;
        
        NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&local_err];
        if (local_err) {
            DDLogError(@"%s Data from file at url %@ error: %@", __FUNCTION__, url.path, local_err.debugDescription);
            error = local_err;
            return nil;
        }
        retObj = [NSPropertyListSerialization propertyListWithData:data 
                                                           options:NSPropertyListMutableContainersAndLeaves 
                                                            format:0 
                                                             error:&local_err];
        if (local_err) {
            DDLogError(@"%s Plist %@ deserialization error: %@", __FUNCTION__, name, local_err.debugDescription);
            error = local_err;
            return nil;
        }
    }
    return retObj;
}

@end
