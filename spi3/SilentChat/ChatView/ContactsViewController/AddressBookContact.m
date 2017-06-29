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
#import "AddressBookContact.h"
#import "ChatUtilities.h"
#import "SCSContactsManager.h"

@interface AddressBookContact () {
    
    BOOL _contactImageIsRequesting;
    BOOL _contactImageIsCached;
}

@property (nonatomic,strong) UIImage *cachedContactImage;

@end

@implementation AddressBookContact

- (UIImage *) setVcardThumbnail:(UIImage *) contactImage {

    float contactImageOffsetFromvCard = 5;
    float contactImageSize = 60;
    UIColor *fontColor = [UIColor colorWithRed:93/255.0f green:95/255.0f blue:102/255.0f alpha:1.0f];
    UIColor *receivedMessageBackgroundColor = [UIColor colorWithRed:246/255.0f green:243/255.0f blue:235/255.0f alpha:1.0f];
    
    UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320 / 2, 70)];
    [backgroundView setBackgroundColor:receivedMessageBackgroundColor];
    
    UILabel *contactName = [[UILabel alloc] initWithFrame:CGRectMake(contactImageSize + 5, 0, 320 / 2 - 55 -  10, 70)];
    [contactName setTextAlignment:NSTextAlignmentCenter];
    contactName.adjustsFontSizeToFitWidth = YES;
    [contactName setTextColor:fontColor];
    [contactName setFont:[[ChatUtilities utilitiesInstance] getFontWithSize:16]];
    contactName.numberOfLines = 2;
    contactName.text = _fullName;
    [backgroundView addSubview:contactName];

    UIImage *backgroundImage = [AddressBookContact imageWithView:backgroundView];
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
        UIGraphicsBeginImageContextWithOptions(backgroundImage.size, NO, [UIScreen mainScreen].scale);
    else
        UIGraphicsBeginImageContext(backgroundImage.size);
    [backgroundImage drawInRect:CGRectMake(0, 0, backgroundImage.size.width, backgroundImage.size.height)];
    [contactImage drawInRect:CGRectMake(contactImageOffsetFromvCard,contactImageOffsetFromvCard, contactImageSize,contactImageSize)];
    [[UIImage imageNamed:@"vcardCircle.png"] drawInRect:CGRectMake(contactImageOffsetFromvCard,contactImageOffsetFromvCard, contactImageSize,contactImageSize)];
    UIImage *contactImageInVcard = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return contactImageInVcard;
}

+ (UIImage *) imageWithView:(UIView *)view {
    
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
        UIGraphicsBeginImageContextWithOptions(view.frame.size, view.opaque, [UIScreen mainScreen].scale);
    else
        UIGraphicsBeginImageContext(view.bounds.size);
    
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage*)requestContactImageSynchronously {
    
    @synchronized (self) {

        if(_contactImageIsCached)
            return _cachedContactImage;
        
        if(!self.cnIdentifier)
            return nil;
        
        CNContactStore* addressBook = [CNContactStore new];
        NSError *error = nil;
        
        CNContact *contact = [addressBook unifiedContactWithIdentifier:self.cnIdentifier
                                                           keysToFetch:@[
                                                                         CNContactThumbnailImageDataKey,
                                                                         CNContactImageDataKey
                                                                         ]
                                                                 error:&error];
        
        if(!error) {
            
            if(contact.thumbnailImageData)
                _cachedContactImage = [UIImage imageWithData:contact.thumbnailImageData];
            else
                _cachedContactImage = [UIImage imageWithData:contact.imageData];
        }
        
        _contactImageIsCached = YES;
        
        return _cachedContactImage;
    }
}

- (BOOL)contactImageIsCached {
    
    return _contactImageIsCached;
}

- (UIImage *)cachedContactImage {
    
    if(_contactImageIsCached)
        return _cachedContactImage;
    else
        return nil;
}

- (void)requestContactImageWithCompletion:(void (^)(UIImage *contactImage, BOOL wasCached))completionBlock {
    
    if(_contactImageIsRequesting)
        return;
    
    if(_contactImageIsCached) {
        
        if(completionBlock)
            completionBlock(_cachedContactImage, YES);
        
        return;
    }

    _contactImageIsRequesting = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [self requestContactImageSynchronously];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            _contactImageIsRequesting = NO;
            
            if(completionBlock)
                completionBlock(_cachedContactImage, NO);
        });
    });
}

- (BOOL)isEqualToAddressBookContact:(AddressBookContact *)addressBookContact {
    
    if(![addressBookContact.cnIdentifier isEqualToString:self.cnIdentifier])
        return NO;
    
    if(![addressBookContact.firstName isEqualToString:self.firstName])
        return NO;

    if(![addressBookContact.middleName isEqualToString:self.middleName])
        return NO;

    if(![addressBookContact.lastName isEqualToString:self.lastName])
        return NO;
    
    if(![addressBookContact.fullName isEqualToString:self.fullName])
        return NO;
    
    if(![addressBookContact.sortByName isEqualToString:self.sortByName])
        return NO;
    
    if(![addressBookContact.searchString isEqualToString:self.searchString])
        return NO;
    
    return YES;
}
                   
@end
