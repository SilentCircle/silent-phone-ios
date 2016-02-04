/*
Copyright (C) 2016, Silent Circle, LLC.  All rights reserved.

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
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreLocation/CoreLocation.h>
#import <AddressBook/AddressBook.h>
#import "SCloudObject.h"

//extern NSString *const kAssetInfo_Metadata;      // NSDictionary with kSCloudMetaData_X keys
//extern NSString *const kAssetInfo_ThumbnailData; // NSData (JPEG)
//extern NSString *const kAssetInfo_MediaData;     // NSData (JPEG)
//extern NSString *const kAssetInfo_Asset;         // ALAsset (if no MediaData)
@class UserContact;

@interface SCAttachment : NSObject

// EA: TODO re-think whether we can save these to the local DB
// TODO should only keep encrypted format around on disk
@property (nonatomic, strong) NSURL *referenceURL;

@property (nonatomic, strong) NSDictionary *metadata;
@property (nonatomic, strong) NSData *thumbnailData;

@property (nonatomic, strong) NSString *cloudLocator;
@property (nonatomic, strong) NSString *cloudKey;
@property (nonatomic, strong) NSArray *segmentList;

@property (nonatomic, strong) NSData *originalData;
@property (nonatomic, strong) ALAsset *decryptedAsset;
@property (nonatomic, strong) SCloudObject *decryptedObject;

/**
 * Creates the proper AssetInfo to pass to MessageStream.
**/
//+ (NSDictionary *)assetInfoForAsset:(ALAsset *)asset withScale:(float)scale;

/**
 * Creates the proper AssetInfo to pass to MessageStream.
 *
 * @param imagePickerInfo
 *   The info dictionary returned by UIImagePicker.
**/
+ (SCAttachment *)attachmentFromImagePickerInfo:(NSDictionary *)imagePickerInfo
                   withScale:(float)scale
                   thumbSize:(CGSize)thumbSize
                    location:(CLLocation *)location;

+ (SCAttachment *)attachmentFromAudioURL:(NSURL *)url soundWave:(NSData *)soundWave duration:(NSTimeInterval)duration;

+ (SCAttachment *)attachmentFromText:(NSString *)text;

+ (SCAttachment *)attachmentFromFile:(NSString *)filePath results:(NSDictionary **)resultsDict;

+ (SCAttachment *)attachmentFromContact:(UserContact *)contact addressBook:(ABAddressBookRef)addressBook;

- (UIImage *)thumbnailImage;

- (BOOL)writeToFile:(NSString *)filePath atomically:(BOOL)bAtomically;

+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize;

@end
