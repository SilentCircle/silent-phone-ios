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
#import <UIKit/UIKit.h>

/**
 Class used to store and retrieve information regarding
 Address Book contacts such as:
 
 * first/last/middle name
 * company name
 * avatar image
 * contact info (phone number, email, usernames)
 */
@interface AddressBookContact : NSObject

@property (nonatomic, strong) NSString *firstName;

@property (nonatomic, strong) NSString *middleName;

@property (nonatomic, strong) NSString *lastName;

@property (nonatomic, strong) NSString *companyName;

/**
 The contact full name contains the first and last name
 if they exist and if not, the nick name or organization name
 */
@property (nonatomic, strong) NSString *fullName;

/**
 The name to be used by Contacts Manager in order to sort the contacts while
 respecting user's preference in iOS settings.
 */
@property (nonatomic, strong) NSString *sortByName;

/**
 The uuid of the contact if it is matched against a
 Silent Circle contact, nil otherwise.
 */
@property (nonatomic, strong) NSString *uuid;

/**
 The display alias of the contact if it is matched against a
 Silent Circle contact, nil otherwise.
 */
@property (nonatomic, strong) NSString *displayAlias;

/**
 String that contains all contactInfo values concatenated for fast search
 
 @see contactInfo
 */
@property (nonatomic, strong) NSString *searchString;

/**
 The unique contacts framework identifier that can be used
 in order to fetch the cnContact if needed
 */
@property (nonatomic,strong) NSString *cnIdentifier;

/**
 Array containing all the contact information after
 they have been extracted and cleaned up from Contacts Manager
 */
@property (nonatomic, strong) NSArray * contactInfo;

- (UIImage *) setVcardThumbnail:(UIImage *) contactImage;

/**
 Returns whether the contact image is already cached.

 @return Whether the contact image is already cached.
 */
- (BOOL)contactImageIsCached;

/**
 The cached contact image.
 
 This value can be nil if there is no image requested for that contact yet (look on the methods below on how to request it), 
 or it can have a value if it has been already requested
 
 @return The cached contact image from a previous request
 */
- (UIImage *)cachedContactImage;

/**
 Checks if the contact image has been requested from the Contacts Framework and requests it if not.
 
 @param completionBlock A block that is being executed in the main thread, containing the contactImage and whether if this image has been fetched from cache or not. contactImage can be nil.
 */
- (void)requestContactImageWithCompletion:(void (^)(UIImage *contactImage, BOOL wasCached))completionBlock;

/**
 As the above method but instead of requesting the image in a background thread and dispatching a completion block when finished,
 it requests it on the same thread that is being called and returns the image synchronously. Use it when you already are working
 on a bg thread
 
 @return The contactImage
 */
- (UIImage*)requestContactImageSynchronously;

/**
 Compares the current AddressBookContact object against another one.
 
 The method first checks their cnIdentifiers, so it only works for objects from the Address Book. It then goes on and checks the first name, last name, user and sortby name as well as the phone numbers string.
 
 @param addressBookContact The other AddressBookContact object we want to be compared with
 @return YES if the two objects are equal, no otherwise
 */
- (BOOL)isEqualToAddressBookContact:(AddressBookContact *)addressBookContact;

@end
