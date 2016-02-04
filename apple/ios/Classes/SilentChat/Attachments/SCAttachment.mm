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
/**
 * Copyright © 2014, Silent Circle
 * All rights reserved.
**/
// ---LICENSE_END---

#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <ImageIO/ImageIO.h>

#import "SCAttachment.h"
//#import "AppConstants.h"
#import "SCloudObject.h"
//#import "SCDateFormatter.h"
//#import "Siren.h"
//Categories
//#import "ALAsset+SCUtilities.h"
#import "NSDate+SCDate.h"
//#import "NSDictionary+SCDictionary.h"
//#import "UIImage+Thumbnail.h"
//#include "util/b64helper.h"
#import "UserContact.h"

NSString *const kAssetInfo_Metadata      = @"thumbnail";  // NSDictionary with kSCloudMetaData_X keys
//NSString *const kAssetInfo_ThumbnailData = @"metadata";   // NSData (JPEG)
NSString *const kAssetInfo_MediaData     = @"mediaData";  // NSData (JPEG)
NSString *const kAssetInfo_Asset         = @"asset";      // ALAsset (if no MediaData)

// Second parameter for UIImageJPEGRepresentation.
// From the docs:
//   The value 0.0 represents the maximum compression (or lowest quality)
//   while the value 1.0 represents the least compression (or best quality).
//
// Changes:
// - 2014-11-4 : Bumped from 0.1 to 0.2 (for better looking thumbnails, while still keeping size down)
const float kThumbnailCompressionQuality = 0.6;
const float kCompressionQuality = 0.8;


@implementation SCAttachment

/**
 * Parses iOS asset info into our own dictionary
 *
 * @param imagePickerInfo
 *   The info dictionary returned by UIImagePicker.
**/
+ (SCAttachment *)attachmentFromImagePickerInfo:(NSDictionary *)imagePickerInfo
                    withScale:(float)scale
                thumbSize:(CGSize)thumbSize
                     location:(CLLocation *)location
{
    NSDictionary *metadata = [imagePickerInfo valueForKey:UIImagePickerControllerMediaMetadata];
	
	NSString     * mediaType     = nil;
	NSString     * mimeType      = nil;
	NSDate       * date          = nil;
	NSString     * filename      = nil;
	NSNumber     * fileSize      = nil;
	NSData       * thumbnailData = nil;
	NSData       * mediaData     = nil;
	NSString     * duration      = nil;
	NSDictionary * gpsDict       = nil;
    
    mediaType = [imagePickerInfo objectForKey:UIImagePickerControllerMediaType];
	
	mimeType = (__bridge_transfer NSString *)
	  UTTypeCopyPreferredTagWithClass((__bridge CFStringRef) mediaType, kUTTagClassMIMEType);
    
	if (metadata)
	{
		NSString *dateTime = [[metadata objectForKey:@"{Exif}"] objectForKey:@"DateTimeOriginal"];
		if (dateTime) {
			date = [NSDate dateFromEXIF:dateTime];
		}
	}
	if (date == nil) {
		date = [NSDate date];
	}
	
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
	filename = [formatter stringFromDate:date];
 
	if (UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeImage))
	{
		UIImage *image = [imagePickerInfo objectForKey:UIImagePickerControllerOriginalImage];
		CGFloat width = image.size.width;
		CGFloat height = image.size.height;
        CGFloat thumbScale;
        
        if (width > height)
            thumbScale = (thumbSize.width > 0) ? thumbSize.width/width : thumbSize.height/height;
        else
            thumbScale = (thumbSize.height > 0) ? thumbSize.height/height : thumbSize.width/width;
		
		// EA: what if the original image contains transparency? Compressing to JPG loses that.
        CGSize actualThumbSz = CGSizeMake(width*thumbScale, height*thumbScale);
        UIImage *thumbnail = [self imageWithImage:image scaledToSize:actualThumbSz];
        thumbnailData = UIImageJPEGRepresentation(thumbnail, kThumbnailCompressionQuality);
        
		if (scale < 1.0)
		{
            CGSize scaledSz = CGSizeMake(image.size.width*scale, image.size.height*scale);
            UIImage *scaledImage = [self imageWithImage:image scaledToSize:scaledSz];
			mediaData = UIImageJPEGRepresentation(scaledImage, kCompressionQuality);
			fileSize = @(mediaData.length);
		}
        else
		{
			mediaData = UIImageJPEGRepresentation(image, kCompressionQuality);
			fileSize = @(mediaData.length);
		}
        mimeType = @"image/jpeg";
		filename = [[NSMutableString stringWithString:filename] stringByAppendingPathExtension:@"jpg"];
	}
	else if (UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeMovie))
	{
		NSURL *url = [imagePickerInfo objectForKey:UIImagePickerControllerMediaURL];
		
		// TODO: This is very wasteful.
		// Can't we just pass the URL directly into SCloud ?
		mediaData = [NSData dataWithContentsOfURL:url options:NSDataReadingUncached error:nil];
		UIImage *thumbnail = [self getMovieURLThumbnail:url thumbSize:thumbSize duration:&duration];
		if (thumbnail)
			thumbnailData = UIImageJPEGRepresentation(thumbnail, kThumbnailCompressionQuality);
		if (!mimeType)
			mimeType = @"video/mp4";
		filename = [[NSMutableString stringWithString:filename] stringByAppendingPathExtension:@"mp4"];
    }
	
	if (location)
	{
		CLLocationDegrees exifLatitude  = location.coordinate.latitude;
		CLLocationDegrees exifLongitude = location.coordinate.longitude;
		
		NSString *latRef;
		NSString *lngRef;
		if (exifLatitude < 0.0) {
			exifLatitude = exifLatitude * -1.0f;
			latRef = NSLocalizedString(@"S", "S as in the identifier for South");
		} else {
			latRef = NSLocalizedString(@"N", "N as in the identifier for North");
		}
		
		if (exifLongitude < 0.0) {
			exifLongitude = exifLongitude * -1.0f;
			lngRef = NSLocalizedString(@"W", "W as in the identifier for West");
		} else {
			lngRef = NSLocalizedString(@"E", "E as in the identifier for East");
		}
		
		NSMutableDictionary *locDict = [[NSMutableDictionary alloc] initWithCapacity:7];
		
		NSDictionary *imageLocDict = [imagePickerInfo objectForKey:(__bridge NSString *)kCGImagePropertyGPSDictionary];
		if (imageLocDict) {
			[locDict addEntriesFromDictionary:imageLocDict];
		}
		
		locDict[(__bridge NSString *)kCGImagePropertyGPSTimeStamp]    = [location.timestamp ExifString];
		locDict[(__bridge NSString *)kCGImagePropertyGPSLatitudeRef]  = latRef;
		locDict[(__bridge NSString *)kCGImagePropertyGPSLatitude]     = @(exifLatitude);
		locDict[(__bridge NSString *)kCGImagePropertyGPSLongitudeRef] = lngRef;
		locDict[(__bridge NSString *)kCGImagePropertyGPSLongitude]    = @(exifLongitude);
		locDict[(__bridge NSString *)kCGImagePropertyGPSDOP]          = @(location.horizontalAccuracy);
		locDict[(__bridge NSString *)kCGImagePropertyGPSAltitude]     = @(location.altitude);
		
		gpsDict = [locDict copy];
	}
	
	// Create the metadata dictionary.
	
	NSMutableDictionary *metaDict = [[NSMutableDictionary alloc] initWithCapacity:10];
    //[metadata filterEntriesFromMetaDataTo:metaDict];
	
	if (mediaType)
		[metaDict setObject:mediaType forKey: kSCloudMetaData_MediaType];
	
	if (mimeType)
		[metaDict setObject: mimeType forKey:kSCloudMetaData_MimeType];
	
	if (date)
		[metaDict setObject:[date rfc3339String] forKey:kSCloudMetaData_Date];
    
	if (filename)
		[metaDict setObject: filename forKey:kSCloudMetaData_FileName];
   
	if (mimeType)
		[metaDict setObject: mimeType forKey:kSCloudMetaData_MimeType];
    
	if (fileSize)
		[metaDict setObject:fileSize forKey:kSCloudMetaData_FileSize];
    
	if (duration)
		[metaDict setObject:duration forKey:kSCloudMetaData_Duration];
	
	if (gpsDict)
		[metaDict setObject:gpsDict forKey:(__bridge NSString *)kCGImagePropertyGPSDictionary];

	if (thumbnailData)
		[metaDict setObject:[thumbnailData base64EncodedStringWithOptions:0] forKey:kSCloudMetaData_Thumbnail];
		
//		// base64 encode this for sending over the wire
//		// estimate buffer size and malloc
//		// TODO: check memory overage?
//		NSUInteger maxBufSz = 1.5*[thumbnailData length]; // guessing
//		char *b64Buffer = new char[maxBufSz];
//		int32_t b64Len = b64Encode((const uint8_t *)[thumbnailData bytes], (int32_t)[thumbnailData length], b64Buffer, maxBufSz);
//		
//		NSString *b64bytes = [[NSString alloc] initWithBytes:b64Buffer length:b64Len encoding:NSUTF8StringEncoding];
//		[metaDict setObject:b64bytes forKey:kSCloudMetaData_Thumbnail];
//		delete b64Buffer;
//	}
	// And create the SCAttachment
    SCAttachment *attachment = [[SCAttachment alloc] init];    
    attachment.metadata = metaDict;
    attachment.thumbnailData = thumbnailData;
    attachment.originalData = mediaData;
	attachment.referenceURL = (NSURL *)[imagePickerInfo objectForKey:UIImagePickerControllerReferenceURL];
    return attachment;
}


+ (SCAttachment *)attachmentFromAudioURL:(NSURL *)url soundWave:(NSData *)soundWave duration:(NSTimeInterval)duration {
	NSString *theUTI = (__bridge_transfer NSString *) UTTypeCreatePreferredIdentifierForTag( kUTTagClassFilenameExtension,  (__bridge CFStringRef) url.pathExtension, NULL);
	NSString *mimeType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef) theUTI, kUTTagClassMIMEType);
	NSString *durationString = [NSString stringWithFormat:@"%0.3f", duration];
	
	NSData *theData = [NSData dataWithContentsOfURL:url];
	
	NSMutableDictionary *metaDict = [NSMutableDictionary dictionaryWithDictionary:@{
				  kSCloudMetaData_MediaType:  (__bridge NSString *)kUTTypeAudio,
				  kSCloudMetaData_FileName: [url lastPathComponent] ,
				  kSCloudMetaData_MimeType: mimeType,
				  kSCloudMetaData_Duration: durationString,
				  kSCloudMetaData_FileSize: [NSNumber numberWithUnsignedInteger:theData.length],
				  kSCloudMetaData_Date:     [[NSDate date] rfc3339String],
				  kSCloudMetaData_MediaWaveform: [soundWave base64EncodedStringWithOptions:0]
				  }];
	
	NSDateFormatter* durationFormatter = [[NSDateFormatter alloc] init] ;
	[durationFormatter setDateFormat:@"mm:ss"];
	NSString* overlayText = [durationFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970: duration]];
	UIImage *thumbnail = [self imageWithOverlay:[UIImage imageNamed: @"vmemo70.png"] watermarkImage:NULL text:overlayText textColor:[UIColor whiteColor]];
	NSData * thumbnailData = UIImageJPEGRepresentation(thumbnail, kThumbnailCompressionQuality);
	[metaDict setObject:[thumbnailData base64EncodedStringWithOptions:0] forKey:kSCloudMetaData_Thumbnail];

	// And create the SCAttachment
	SCAttachment *attachment = [[SCAttachment alloc] init];
	attachment.metadata = metaDict;
	attachment.thumbnailData = thumbnailData;
	attachment.originalData = theData;
	attachment.referenceURL = url;
	
	return attachment;
}

+ (SCAttachment *)attachmentFromText:(NSString *)text {
	NSData *theData = [text dataUsingEncoding:NSUTF8StringEncoding];
	NSDate *now = [NSDate date];
	NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier: @"en_US_POSIX"];
	NSTimeZone *gmtTimeZone = [NSTimeZone timeZoneForSecondsFromGMT: 0];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	formatter.locale = enUSPOSIXLocale;
	formatter.timeZone = gmtTimeZone;
	formatter.dateFormat = @"yyyyMMdd_HHmmss";
	NSString *fileName = [[@"TEXT_" stringByAppendingString:[formatter stringFromDate:now]] stringByAppendingPathExtension:@"txt"];
	
	NSMutableDictionary *metaDict = [NSMutableDictionary dictionaryWithDictionary:@{
				kSCloudMetaData_MediaType: @"public.plain-text",
				kSCloudMetaData_FileName: fileName,
				kSCloudMetaData_MimeType: @"text/plain",
				kSCloudMetaData_FileSize: [NSNumber numberWithUnsignedInteger:theData.length],
				kSCloudMetaData_Date:     [now rfc3339String],
				}];

	UIImage *thumbnail = [UIImage imageNamed: @"attachment_thumbnail_txt"];
	NSData * thumbnailData = UIImagePNGRepresentation(thumbnail);
	[metaDict setObject:[thumbnailData base64EncodedStringWithOptions:0] forKey:kSCloudMetaData_Thumbnail];

	SCAttachment *attachment = [[SCAttachment alloc] init];
	attachment.metadata = metaDict;
	attachment.thumbnailData = thumbnailData;
	attachment.originalData = theData;
	attachment.referenceURL = nil;//url;
	return attachment;
}

+ (SCAttachment *)attachmentFromContact:(UserContact *)contact addressBook:(ABAddressBookRef)addressBook {
	NSData *vcardData = [self vCardDataForABRecordID:(ABRecordID)contact.abRecordID addressBook:addressBook];
	if ([vcardData length] == 0)
		return nil;
	
	UIImage *contactImage = [self imageForABRecordID:(ABRecordID)contact.abRecordID addressBook:addressBook];
	if (!contactImage)
		contactImage = [UIImage imageNamed:@"defaultVCard.png"];
    
    UIImage *thumbnail = [contact setVcardThumbnail:contactImage];
	NSString *fileName = ([contact.contactUserName length] > 0) ? contact.contactUserName : [NSString stringWithFormat:@"_user%ld", (long)contact.abRecordID];
	NSString *displayName = ([contact.contactFullName length] > 0) ? contact.contactFullName : fileName;
	NSMutableDictionary *metaDict = [NSMutableDictionary dictionaryWithDictionary:@{
						kSCloudMetaData_MediaType   : (__bridge NSString *)kUTTypeVCard,
                  kSCloudMetaData_MimeType    : @"text/vcard",
						kSCloudMetaData_FileName    : fileName,
						kSCloudMetaData_DisplayName : displayName,
						kSCloudMetaData_FileSize    : [NSNumber numberWithUnsignedInteger:vcardData.length],
					}];
 
	NSData * thumbnailData = (thumbnail) ? UIImagePNGRepresentation(thumbnail) : nil;
	if (thumbnailData)
		[metaDict setObject:[thumbnailData base64EncodedStringWithOptions:0] forKey:kSCloudMetaData_Thumbnail];
	
	// And create the SCAttachment
	SCAttachment *attachment = [[SCAttachment alloc] init];
	attachment.metadata = metaDict;
	attachment.thumbnailData = thumbnailData;
	attachment.originalData = vcardData;

	//	attachment.referenceURL = url;
	
	return attachment;
}

+ (NSData *)vCardDataForABRecordID:(ABRecordID)abRecordID addressBook:(ABAddressBookRef)addressBook
{
	if ((abRecordID == kABRecordInvalidID) || (addressBook == nil))
		return nil;
	
	NSData *data = nil;
	ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, abRecordID);
	if (person) {
		NSArray *people = [NSArray arrayWithObject:(__bridge id)(person)];
		data = (__bridge_transfer NSData *)
		ABPersonCreateVCardRepresentationWithPeople((__bridge CFArrayRef)people);
	}
	return data;
}

+ (UIImage *)imageForABRecordID:(ABRecordID)abRecordID addressBook:(ABAddressBookRef)addressBook
{
	if ((abRecordID == kABRecordInvalidID) || (addressBook == nil))
		return nil;
	
	UIImage *image = nil;
	ABRecordRef person = ABAddressBookGetPersonWithRecordID(addressBook, abRecordID);
	if (person)	{
		NSData *imageData = (__bridge_transfer NSData *)
		ABPersonCopyImageDataWithFormat(person, kABPersonImageFormatThumbnail);
		
		if (imageData)
			image = [UIImage imageWithData:imageData];
	}
	
	return image;
}

- (UIImage *)thumbnailImage {
	if (self.thumbnailData)
		return [UIImage imageWithData:self.thumbnailData scale:1.0]; //[[UIScreen mainScreen] scale]];
 
	if (!self.metadata)
		return nil;
	
	// check if we have a thumbnail, just not thumbnailData
	NSString *b64bytes = [self.metadata objectForKey:kSCloudMetaData_Thumbnail];
	if (!b64bytes)
		return nil; // no thumb available
	
	NSData *b64data = [b64bytes dataUsingEncoding:NSUTF8StringEncoding];
	self.thumbnailData = [[NSData alloc] initWithBase64EncodedData:b64data options:0];
	return [UIImage imageWithData:self.thumbnailData scale:1.0];//[[UIScreen mainScreen] scale]];
}

- (BOOL)writeToFile:(NSString *)filePath atomically:(BOOL)bAtomically {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:4];
    if (_metadata)
        [dict setObject:_metadata forKey:@"metadata"];
    if (_thumbnailData)
        [dict setObject:_thumbnailData forKey:@"thumbdata"];
// TODO: revisit this
    if (_originalData)
        [dict setObject:_originalData forKey:@"mediadata"];
// TODO: implement this:
	// if (_asset)
	//   [dict setObject:asset forKey:@"asset"];
	
	
	// for now we need to store these if we need to decrypt the segments later for viewing
//	if (_cloudLocator)
//		[dict setObject:_cloudLocator forKey:@"cloudLocator"];
//	if (_cloudKey)
//		[dict setObject:_cloudKey forKey:@"cloudKey"];
//	if (_segmentList)
//		[dict setObject:_segmentList forKey:@"segmentList"];
	
    return [dict writeToFile:filePath atomically:bAtomically];
}

+ (SCAttachment *)attachmentFromFile:(NSString *)filePath results:(NSDictionary **)resultsDict {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:filePath];
    if (!dict)
        return nil;
    
    SCAttachment *attachment = [[SCAttachment alloc] init];
    attachment.metadata = [dict objectForKey:@"metadata"];
    attachment.thumbnailData = [dict objectForKey:@"thumbdata"];
// TODO: revisit this
	attachment.originalData = [dict objectForKey:@"mediadata"];
	// TODO: implement this:
    //attachment.asset = [dict objectForKey:@"asset"];
	
//	attachment.cloudLocator = [dict objectForKey:@"cloudLocator"];
//	attachment.cloudKey = [dict objectForKey:@"cloudKey"];
//	attachment.segmentList = [dict objectForKey:@"segmentList"];
	if (resultsDict)
		*resultsDict = dict;
	
    return attachment;
}

/* TODO: implement something closer to this with SCloud
 - (IBAction)sendButtonAction:(id)sender
 {
	DDLogAutoTrace();
	
	NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
	if (indexPath == nil)
	{
 [self cancelButtonAction:sender];
 return;
	}
	
	if ([delegate respondsToSelector:@selector(scAddressBookPicker:didFinishPickingWithSiren:error:)])
	{
 
 __block NSData* vcardData = NULL;
 NSString* displayName = NULL;
 NSString* fileName = NULL;
 UIImage *image = NULL;
 
 
 if(selectedSegment == segment_stuser)
 {
 __block STUser *user = nil;
 
 NSString *userID = [self userIdForIndexPath:indexPath];
 if (userID)
 {
 [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
 
 user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
 
 if(user)
 {
 NSString* vcard =  [[STUserManager sharedInstance] vcardForUser:user withTransaction:transaction];
 vcardData = [vcard dataUsingEncoding:NSUTF8StringEncoding];
 }
 }];
 
 image = [[AvatarManager sharedInstance] imageForUser:user];
 
 fileName = user.jid.user;
 displayName = user.displayName;
 }
 }
 else
 {
 ABEntry *abEntry =  NULL;
 
 if(useSectionsForAB)
 abEntry =  [[partitionedData objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
 else
 abEntry = [addressBookData objectAtIndex:indexPath.row];
 
 
 vcardData = [[AddressBookManager sharedInstance] vCardDataForABRecordID:abEntry.abRecordID];
 
 image = [[AddressBookManager sharedInstance] imageForABRecordID:abEntry.abRecordID];
 fileName = abEntry.name;
 displayName = abEntry.name;
 
 }
 
 
 if(vcardData && displayName && fileName)
 {
 NSData *previewData = nil;
 if (image)
 {
 // reduce the image thumbnail for a smaller preview
 
 UIImage *cardImage = nil;
 
 UIGraphicsBeginImageContext(CGSizeMake(60, 60));
 [image drawInRect:CGRectMake(0, 0, 60, 60)];
 cardImage = UIGraphicsGetImageFromCurrentImageContext();
 UIGraphicsEndImageContext();
 
 previewData = UIImageJPEGRepresentation(cardImage, 1.0);
 }
 
 // always ensure that the filname has a vcf extension
 if (fileName) {
 if(![fileName pathExtension] || ![[fileName pathExtension] isEqualToString:@"vcf"])
 fileName = [fileName stringByAppendingPathExtension:@"vcf"];
 }
 
 NSDictionary *metaData = @{
 kSCloudMetaData_MediaType   : (__bridge NSString *)kUTTypeVCard,
 kSCloudMetaData_FileName    : fileName,
 kSCloudMetaData_DisplayName : displayName,
 kSCloudMetaData_FileSize    : [NSNumber numberWithUnsignedInteger:vcardData.length],
 };
 
 SCloudObject *scloud = nil;
 scloud = [[SCloudObject alloc] initWithDelegate:self
 data:vcardData
 metaData:metaData
 mediaType:(__bridge NSString *)kUTTypeVCard
 contextString:[STDatabaseManager.currentUser.jid full]];
 
 HUD = [[MBProgressHUD alloc] initWithView:self.view];
 HUD.mode = MBProgressHUDModeAnnularDeterminate;
 HUD.labelText = [NSString stringWithFormat:NSLS_COMMON_PREPARING, NSLS_COMMON_CONTACT];
 
 [self.view addSubview:HUD];
 
 __block NSError *error = nil;
 
 [HUD showAnimated:YES whileExecutingBlock:^{
 
 [scloud saveToCacheWithError:&error];
 
 } completionBlock:^{
 
 [HUD removeFromSuperview];
 
 Siren *siren = nil;
 if (!error)
 {
 siren = Siren.new;
 siren.mediaType     = (__bridge NSString*) kUTTypeVCard;
 siren.mimeType      = kMimeType_vCard;
 siren.cloudKey      = scloud.keyString;
 siren.cloudLocator  = scloud.locatorString;
 
 // added this code for ST 1.X compatibiity, we need a thumbnail for that version
 
 if(needsThumbNail)
 {
 UIImage* cardImage = [UIImage imageNamed:@"vcard@2x"];   // we always use this image for alignment
 UIImage* personImage = image?image:[UIImage imageNamed:@"defaultPerson"];
 
 UIGraphicsBeginImageContext(CGSizeMake(122, 94));
 [cardImage drawInRect:CGRectMake(0, 0, 122, 94)];
 [personImage drawInRect:CGRectMake(16, 15, 52, 51)];
 
 cardImage = UIGraphicsGetImageFromCurrentImageContext();
 UIGraphicsEndImageContext();
 
 siren.thumbnail = UIImageJPEGRepresentation(cardImage, 1.0);
 }
 else
 {
 if (previewData)
 siren.preview = previewData;
 
 }
 
 
 }
 
 [delegate scAddressBookPicker:self didFinishPickingWithSiren:siren error:error];
 }];
 }
	}
 }
 */

+ (UIImage *)getMovieURLThumbnail:(NSURL *)url
						thumbSize:(CGSize)thumbSize
						 duration:(NSString **)durationPtr {
	if (url == nil)	{
		if (durationPtr)
			*durationPtr = nil;
		return nil;
	}
	
	AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
	if (!asset)
		return nil;
	
	NSTimeInterval durationSeconds = CMTimeGetSeconds([asset duration]);
	NSString *duration = [NSString stringWithFormat:@"%f", durationSeconds];
	if (durationPtr)
		*durationPtr = duration;
	
	// take a thumbnail that is 3 seconds into the movie (if it's longer)
	AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
	gen.appliesPreferredTrackTransform = YES;
	CMTime time = CMTimeMakeWithSeconds((durationSeconds > 3) ? 3.0 : 0.0, 600);
	NSError *error = nil;
	CMTime actualTime;
	
	CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
	
	UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
	
	AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
	CGSize size = [videoTrack naturalSize];
	CGAffineTransform txf = [videoTrack preferredTransform];
	
	if (size.width == txf.tx && size.height == txf.ty)
		orientation =  UIInterfaceOrientationLandscapeRight;
	else if (txf.tx == 0 && txf.ty == 0)
		orientation =  UIInterfaceOrientationLandscapeLeft;
	else if (txf.tx == 0 && txf.ty == size.width)
		orientation =  UIInterfaceOrientationPortraitUpsideDown;
	
	CGFloat thumbScale;
	if((orientation == UIInterfaceOrientationPortrait)
	   || (orientation == UIInterfaceOrientationPortraitUpsideDown)) {
		thumbScale = (thumbSize.height > 0) ? thumbSize.height/size.height : thumbSize.width/size.width;
	}
	else {
		// ((orientation == UIInterfaceOrientationLandscapeRight) || (orientation == UIInterfaceOrientationLandscapeLeft))
		thumbScale = (thumbSize.width > 0) ? thumbSize.width/size.width : thumbSize.height/size.height;
	}
   CGSize actualThumbSz;
   
   if(orientation == UIInterfaceOrientationPortrait || orientation ==  UIInterfaceOrientationPortraitUpsideDown){
      actualThumbSz = CGSizeMake(size.height*thumbScale, size.width*thumbScale);
   }
   else{
      actualThumbSz = CGSizeMake(size.width*thumbScale, size.height*thumbScale);
   }
   
	UIImage *thumbnail = [self imageWithImage:[UIImage imageWithCGImage:image] scaledToSize:actualThumbSz];
 
	CGImageRelease(image);
	
	return thumbnail;
}

// NOTE: this is duplicated and should be moved into a UIImage Category class
+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    UIGraphicsBeginImageContext(CGSizeMake(newSize.width, newSize.height));
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

+ (UIImage *)imageWithOverlay:(UIImage *)image watermarkImage:(UIImage *)watermarkImage text:(NSString *)textString textColor:(UIColor *)textColor {
	CGFloat fontSize = 16.0;
	UIFont *font = [UIFont systemFontOfSize:fontSize];
	NSDictionary *attributes = @{ NSFontAttributeName: font };
	
	CGSize watermarkImageSize = watermarkImage ? watermarkImage.size : CGSizeMake(5, 5);
	
	CGPoint origin = CGPointMake(6, (image.size.height - 10 - watermarkImageSize.height * 2));
	
	CGSize textRectSize = [textString sizeWithAttributes:attributes];
	CGRect textRect = (CGRect){
		.origin.x = image.size.width - textRectSize.width - fontSize,
		.origin.y = origin.y + font.descender,
		.size.width = textRectSize.width,
		.size.height = textRectSize.height
	};
	CGRect badgeRect = (CGRect){
		.origin.x = textRect.origin.x - (watermarkImageSize.width * 2) -  2,
		.origin.y = origin.y,
		.size.width = watermarkImageSize.width * 2,
		.size.height = watermarkImageSize.height * 2
	};
	
	CGRect unionRect = (CGRect){
		.origin.x = badgeRect.origin.x,
		.origin.y = badgeRect.origin.y,
		.size.width = (textRect.origin.x + textRect.size.width) - badgeRect.origin.x,
		.size.height = (textRect.size.height > badgeRect.size.height ?textRect.size.height :badgeRect.size.height) + font.descender
	};
	unionRect = CGRectInset(unionRect, 2.0*font.descender, 2.0*font.descender);
	
	if(!watermarkImage)
	{
		unionRect.origin.x += watermarkImageSize.width;
		unionRect.size.width -= watermarkImageSize.width;
		unionRect.origin.y+=5;
	}
	
	UIGraphicsBeginImageContext(image.size);
	
	
	[image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
	[[UIColor colorWithWhite:0.0 alpha:.5] set];
	UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:unionRect cornerRadius:10.0];
	[path fill];
	
	if (watermarkImage)
		[watermarkImage drawInRect:badgeRect];
	
	[textColor set];
	
	NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
	style.lineBreakMode = NSLineBreakByTruncatingTail;
	style.alignment = NSTextAlignmentLeft;
	
	attributes = @{
				   NSFontAttributeName: font,
				   NSParagraphStyleAttributeName: style,
				   NSForegroundColorAttributeName: textColor
				   };
	
	[textString drawInRect:textRect withAttributes:attributes];
	
	//	UIRectFillUsingBlendMode(unionRect, kCGBlendModeOverlay);
	
	UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
	
	UIGraphicsEndImageContext();
	return newImage;
}

/**
 * Creates the proper AssetInfo to pass to MessageStream.
 **/

#if 0 // EA: add this back in
+ (NSDictionary *)assetInfoForAsset:(ALAsset *)asset withScale:(float)scale
{
    ALAssetRepresentation *rep = [asset defaultRepresentation];
    NSDictionary *metadata = rep.metadata;
    
    NSString * mediaType     = nil;
    NSString * mimeType      = nil;
    NSDate   * date          = nil;
    NSString * filename      = nil;
    NSNumber * fileSize      = nil;
    NSData   * thumbnailData = nil;
    NSData   * mediaData     = nil;
    NSString * duration      = nil;
    
    BOOL isCroppedPhoto = NO;
    UIImage *image = nil;
    
    
    mediaType = rep.UTI;
    
    mimeType = (__bridge_transfer NSString *)
    UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)mediaType, kUTTagClassMIMEType);
    
    if (metadata)
    {
        NSString *dateTime = [[rep.metadata objectForKey:@"{Exif}"] objectForKey:@"DateTimeOriginal"];
        if (dateTime)
            date = [NSDate dateFromEXIF:dateTime];
    }
    if (date == nil) {
        date = [asset valueForProperty:ALAssetPropertyDate];
    }
    
    filename = rep.filename;
    fileSize =  @(rep.size);
    
    if (rep.metadata[@"AdjustmentXMP"])
    {
        isCroppedPhoto = YES;
        CGImageRef croppedImage = [asset createAdjustedImageUsingCIImage];
        
        image = [UIImage imageWithCGImage:croppedImage
                                    scale:rep.scale
                              orientation:(UIImageOrientation)rep.orientation];
        
        CGImageRelease(croppedImage);
    }
    else
    {
        CGImageRef fullImage = rep.fullResolutionImage;
        if (fullImage)
        {
            image = [UIImage imageWithCGImage:fullImage
                                        scale:rep.scale
                                  orientation:(UIImageOrientation)rep.orientation];
        }
    }
    
    if (image)
    {
        UIImage *thumbnail = nil;
        
        CGFloat width = image.size.width;
        CGFloat height = image.size.height;
        
        //ST-928 03/20/15
        if (height > width)
            thumbnail = [image scaledToHeight:[UIImage maxSirenThumbnailHeightOrWidth]];
        else
            thumbnail = [image scaledToWidth:[UIImage maxSirenThumbnailHeightOrWidth]];
        
        thumbnailData = UIImageJPEGRepresentation(thumbnail, kThumbnailCompressionQuality);
    }
    
    if ([mediaType isEqualToString:(__bridge NSString *)kUTTypeGIF])
    {
        // Process this as an asset, don't mess with GIF
    }
    else if (UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeImage))
    {
        if (scale < 1.0)
        {
            mediaData = UIImageJPEGRepresentation([image scaled:scale], kCompressionQuality);
            fileSize = @(mediaData.length);
        }
        else if (isCroppedPhoto)
        {
            mediaData = UIImageJPEGRepresentation(image, kCompressionQuality);
            fileSize = @(mediaData.length);
        }
    }
    else if (UTTypeConformsTo((__bridge CFStringRef)mediaType, kUTTypeMovie))
    {
        duration = [NSString stringWithFormat:@"%f", [[asset valueForProperty:ALAssetPropertyDuration] doubleValue]];
    }
    
    // Create the metadata dictionary.
    
    NSMutableDictionary *metaDict = [[NSMutableDictionary alloc] initWithCapacity:10];
    
    [metadata filterEntriesFromMetaDataTo:metaDict];
    
    if (mediaType)
        [metaDict setObject:mediaType forKey:kSCloudMetaData_MediaType];
    
    if (mimeType)
        [metaDict setObject:mimeType forKey:kSCloudMetaData_MimeType];
    
    if (date)
        [metaDict setObject:[date rfc3339String] forKey:kSCloudMetaData_Date];
    
    if (filename)
        [metaDict setObject: filename forKey:kSCloudMetaData_FileName];
    
    if (fileSize)
        [metaDict setObject:fileSize forKey:kSCloudMetaData_FileSize];
    
    if (duration)
        [metaDict setObject:duration forKey:kSCloudMetaData_Duration];
	
	// EA: adding thumbnailData to metaDict
	if (thumbnailData)
		[metaDict setObject:thumbnailData forKey:kSCloudMetaData_Thumbnail];
	
    // And create the master assetInfo dictionary.
    
    NSMutableDictionary *assetInfo = [NSMutableDictionary dictionaryWithCapacity:4];
    
    [assetInfo setObject:metaDict forKey:kAssetInfo_Metadata];
    
//    if (thumbnailData)
//        [assetInfo setObject:thumbnailData forKey:kAssetInfo_ThumbnailData];
	
    if (mediaData)
        [assetInfo setObject:mediaData forKey:kAssetInfo_MediaData];
    else
        [assetInfo setObject:asset forKey:kAssetInfo_Asset];
    
    return assetInfo;
}
#endif

@end
