//
//  STKeychain.m
//
//  Created by Buzz Andersen on 10/20/08.
//  Based partly on code by Jonathan Wight, Jon Crosby, and Mike Malone.
//  Copyright 2011 System of Touch. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <UIKit/UIKit.h>

#import "STKeychain.h"
//#import "DeviceUtil.h"
#import "NSString+hex.h"

NSString * const STKeychainErrorDomain = @"com.silentcircle.SPKeychainErrorDomain";
NSString * const kSPDeviceIdAccountKey = @"SPDeviceIdAccount";
NSString * const kSPDeviceIdServiceKey = @"SPDeviceIdService";
//NSString * const kSPDeviceIdKey = @"device_id";
//static NSString * const kSPDeviceIdDelimiterKey = @"^"; //caret to split fields in string

NSString * const kSPKeychainAccessControlKey = @"acct";
NSString * const kSPKeychainAccountKey = @"acct";
NSString * const kSPKeychainAccessGroupKey = @"agrp";
NSString * const kSPKeychainCreatedAtKey = @"cdat";
NSString * const kSPKeychainClassKey = @"class";
NSString * const kSPKeychainDataKey = @"v_Data";
NSString * const kSPKeychainDescriptionKey = @"desc";
NSString * const kSPKeychainLabelKey = @"labl";
NSString * const kSPKeychainLastModifiedKey = @"mdat";
NSString * const kSPKeychainServiceKey = @"svce";
NSString * const kSPKeychainSyncKey = @"sync";
NSString * const kSPKeychainTombKey = @"tomb";


static BOOL const USE_BASE_64 = NO; // or HEX_STRING


#define USE_MAC_KEYCHAIN_API !TARGET_OS_IPHONE || (TARGET_IPHONE_SIMULATOR && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0)


@interface STKeychain ()

#if USE_MAC_KEYCHAIN_API
+ (SecKeychainItemRef)getKeychainItemReferenceForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error;
#else
+ (NSMutableDictionary *)_queryForService:(NSString *)service account:(NSString *)account;
+ (void)_clearALLKeychainItemsForService:(NSString *)service account:(NSString *)account;
#endif

@end

@implementation STKeychain


#if USE_MAC_KEYCHAIN_API

+ (NSString *)getPasswordForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error {
	if (!username || !serviceName) {
		*error = [NSError errorWithDomain:STKeychainErrorDomain code:-2000 userInfo:nil];
		return nil;
	}
	
	SecKeychainItemRef item = [STKeychain getKeychainItemReferenceForUsername:username andServiceName:serviceName error:error];
	if (*error || !item) {
		return nil;
	}
	
	// from Advanced Mac OS X Programming, ch. 16
    UInt32 length;
    char *password;
    SecKeychainAttribute attributes[8];
    SecKeychainAttributeList list;
	
    attributes[0].tag = kSecAccountItemAttr;
    attributes[1].tag = kSecDescriptionItemAttr;
    attributes[2].tag = kSecLabelItemAttr;
    attributes[3].tag = kSecModDateItemAttr;
    
    list.count = 4;
    list.attr = attributes;
    
    OSStatus status = SecKeychainItemCopyContent(item, NULL, &list, &length, (void **)&password);
	
	if (status != noErr) {
		*error = [NSError errorWithDomain:STKeychainErrorDomain code:status userInfo:nil];
		return nil;
    }
    
	NSString *passwordString = nil;
	
	if (password != NULL) {
		char passwordBuffer[1024];
		
		if (length > 1023) {
			length = 1023;
		}
		strncpy(passwordBuffer, password, length);
		
		passwordBuffer[length] = '\0';
		passwordString = [NSString stringWithCString:passwordBuffer encoding:NSUTF8StringEncoding];
	}
	
	SecKeychainItemFreeContent(&list, password);
    
    CFRelease(item);
    
    return passwordString;
}

+ (BOOL)storeUsername:(NSString *)username andPassword:(NSString *)password forServiceName:(NSString *)serviceName updateExisting:(BOOL)updateExisting error:(NSError **)error {
	if (!username || !password || !serviceName) {
		*error = [NSError errorWithDomain:STKeychainErrorDomain code:-2000 userInfo:nil];
		return NO;
	}
	
	OSStatus status = noErr;
	
	SecKeychainItemRef item = [STKeychain getKeychainItemReferenceForUsername:username andServiceName:serviceName error:error];
	
	if (*error && [*error code] != noErr) {
        return NO;
	}
	
	*error = nil;
	
	if (item) {
		status = SecKeychainItemModifyAttributesAndData(item,
                                                        NULL,
                                                        (UInt32)[password lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                                        [password UTF8String]);
		
		CFRelease(item);
	} else {
		status = SecKeychainAddGenericPassword(NULL,
                                               (UInt32)[serviceName lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 
                                               [serviceName UTF8String],
                                               (UInt32)[username lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                               [username UTF8String],
                                               (UInt32)[password lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                               [password UTF8String],
                                               NULL);
	}
	
	if (status != noErr) {
		*error = [NSError errorWithDomain:STKeychainErrorDomain code:status userInfo:nil];
        return NO;
	}
    
    return YES;
}

+ (BOOL)deleteItemForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error {
	if (!username || !serviceName) {
		*error = [NSError errorWithDomain:STKeychainErrorDomain code:2000 userInfo:nil];
		return NO;
	}
	
	*error = nil;
	
	SecKeychainItemRef item = [STKeychain getKeychainItemReferenceForUsername:username andServiceName:serviceName error:error];
	
	if (*error && [*error code] != noErr) {
		return NO;
	}
	
	OSStatus status;
	
	if (item) {
		status = SecKeychainItemDelete(item);
		
		CFRelease(item);
	}
	
	if (status != noErr) {
		*error = [NSError errorWithDomain:STKeychainErrorDomain code:status userInfo:nil];
        return NO;
	}
    
    return YES;
}

// NOTE: Item reference passed back by reference must be released!
+ (SecKeychainItemRef)getKeychainItemReferenceForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error {
	if (!username || !serviceName) {
		*error = [NSError errorWithDomain:STKeychainErrorDomain code:-2000 userInfo:nil];
		return nil;
	}
	
	*error = nil;
    
	SecKeychainItemRef item;
	
	OSStatus status = SecKeychainFindGenericPassword(NULL,
                                                     (UInt32)[serviceName lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                                     [serviceName UTF8String],
                                                     (UInt32)[username lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                                     [username UTF8String],
                                                     NULL,
                                                     NULL,
                                                     &item);
	
	if (status != noErr) {
		if (status != errSecItemNotFound) {
			*error = [NSError errorWithDomain:STKeychainErrorDomain code:status userInfo:nil];
		}
		
		return nil;		
	}
	
	return item;
}

#else

+ (NSString *)getPasswordForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error {
	if (!username || !serviceName) {
		if (error != nil) {
			*error = [NSError errorWithDomain:STKeychainErrorDomain code:-2000 userInfo:nil];
		}
		return nil;
	}
	
	if (error != nil) {
		*error = nil;
	}
    
	// Set up a query dictionary with the base query attributes: item type (generic), username, and service
	
	NSArray *keys = [[[NSArray alloc] initWithObjects:(NSString *)kSecClass, kSecAttrAccount, kSecAttrService, nil] autorelease];
	NSArray *objects = [[[NSArray alloc] initWithObjects:(NSString *)kSecClassGenericPassword, username, serviceName, nil] autorelease];
	
	NSMutableDictionary *query = [[[NSMutableDictionary alloc] initWithObjects:objects forKeys:keys] autorelease];
	
	// First do a query for attributes, in case we already have a Keychain item with no password data set.
	// One likely way such an incorrect item could have come about is due to the previous (incorrect)
	// version of this code (which set the password as a generic attribute instead of password data).
	
	NSDictionary *attributeResult = NULL;
	NSMutableDictionary *attributeQuery = [query mutableCopy];
	[attributeQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnAttributes];
	OSStatus status = SecItemCopyMatching((CFDictionaryRef)attributeQuery, (CFTypeRef *)&attributeResult);
	
	[attributeResult release];
	[attributeQuery release];
	
	if (status != noErr) {
		// No existing item found--simply return nil for the password
		if (error != nil && status != errSecItemNotFound) {
			//Only return an error if a real exception happened--not simply for "not found."
			*error = [NSError errorWithDomain:STKeychainErrorDomain code:status userInfo:nil];
		}
		
		return nil;
	}
	
	// We have an existing item, now query for the password data associated with it.
	
	NSData *resultData = nil;
	NSMutableDictionary *passwordQuery = [query mutableCopy];
	[passwordQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    
	status = SecItemCopyMatching((CFDictionaryRef)passwordQuery, (CFTypeRef *)&resultData);
	
	[resultData autorelease];
	[passwordQuery release];
	
	if (status != noErr) {
		if (status == errSecItemNotFound) {
			// We found attributes for the item previously, but no password now, so return a special error.
			// Users of this API will probably want to detect this error and prompt the user to
			// re-enter their credentials.  When you attempt to store the re-entered credentials
			// using storeUsername:andPassword:forServiceName:updateExisting:error
			// the old, incorrect entry will be deleted and a new one with a properly encrypted
			// password will be added.
			if (error != nil) {
				*error = [NSError errorWithDomain:STKeychainErrorDomain code:-1999 userInfo:nil];
			}
		} else if (error != nil) {
			// Something else went wrong. Simply return the normal Keychain API error code.
            *error = [NSError errorWithDomain:STKeychainErrorDomain code:status userInfo:nil];
		}
		
		return nil;
	}
    
	NSString *password = nil;	
    
	if (resultData) {
		password = [[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding];
	}
	else if (error != nil) {
		// There is an existing item, but we weren't able to get password data for it for some reason,
		// Possibly as a result of an item being incorrectly entered by the previous code.
		// Set the -1999 error so the code above us can prompt the user again.
        *error = [NSError errorWithDomain:STKeychainErrorDomain code:-1999 userInfo:nil];
	}
    
	return [password autorelease];
}

+ (BOOL)storeUsername:(NSString *)username andPassword:(NSString *)password forServiceName:(NSString *)serviceName updateExisting:(BOOL)updateExisting error:(NSError **)error 
{		
	if (!username || !password || !serviceName) {
		if (error != nil) {
			*error = [NSError errorWithDomain:STKeychainErrorDomain code:-2000 userInfo:nil];
		}
		
        return NO;
	}
	
	// See if we already have a password entered for these credentials.
	NSError *getError = nil;
	NSString *existingPassword = [STKeychain getPasswordForUsername:username andServiceName:serviceName error:&getError];
    
	if ([getError code] == -1999) {
		// There is an existing entry without a password properly stored (possibly as a result of the previous incorrect version of this code.
		// Delete the existing item before moving on entering a correct one.
        
		getError = nil;
		
		[self deleteItemForUsername:username andServiceName:serviceName error:&getError];
        
		if ([getError code] != noErr) {
			if (error != nil) {
				*error = getError;
			}
			return NO;
		}
	} else if ([getError code] != noErr) {
		if (error != nil) {
			*error = getError;
		}
		return NO;
	}
	
	if (error != nil) {
		*error = nil;
	}
	
	OSStatus status = noErr;
    
	if (existingPassword) {
		// We have an existing, properly entered item with a password.
		// Update the existing item.
		
		if (![existingPassword isEqualToString:password] && updateExisting) {
			//Only update if we're allowed to update existing.  If not, simply do nothing.
         //(__bridge id)kSecAttrAccessibleAlwaysThisDeviceOnly forKey:(__bridge id)kSecAttrAccessible];
			
			NSArray *keys = [[[NSArray alloc] initWithObjects:(NSString *)kSecClass, 
                              (__bridge id)kSecAttrAccessible,
                              kSecAttrService, 
                              kSecAttrLabel, 
                              kSecAttrAccount, 
                              nil] autorelease];
			
			NSArray *objects = [[[NSArray alloc] initWithObjects:(NSString *)kSecClassGenericPassword, 
                                 (__bridge id)kSecAttrAccessibleAlwaysThisDeviceOnly,
                                 serviceName,
                                 serviceName,
                                 username,
                                 nil] autorelease];
			
			NSDictionary *query = [[[NSDictionary alloc] initWithObjects:objects forKeys:keys] autorelease];			
			
			status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)[NSDictionary dictionaryWithObject:[password dataUsingEncoding:NSUTF8StringEncoding] forKey:(NSString *)kSecValueData]);
		}
      
	}
	else {
		// No existing entry (or an existing, improperly entered, and therefore now
		// deleted, entry).  Create a new entry.
		
		NSArray *keys = [[[NSArray alloc] initWithObjects:(NSString *)kSecClass, 
                          (__bridge id)kSecAttrAccessible,
                          kSecAttrService, 
                          kSecAttrLabel, 
                          kSecAttrAccount, 
                          kSecValueData, 
                          nil] autorelease];
		
		NSArray *objects = [[[NSArray alloc] initWithObjects:(NSString *)kSecClassGenericPassword, 
                             (__bridge id)kSecAttrAccessibleAlwaysThisDeviceOnly,
                             serviceName,
                             serviceName,
                             username,
                             [password dataUsingEncoding:NSUTF8StringEncoding],
                             nil] autorelease];
		
		NSDictionary *query = [[[NSDictionary alloc] initWithObjects:objects forKeys:keys] autorelease];			
        
		status = SecItemAdd((CFDictionaryRef) query, NULL);
	}
	
	if (status != noErr) {
		// Something went wrong with adding the new item. Return the Keychain error code.
		if (error != nil) {
			*error = [NSError errorWithDomain:STKeychainErrorDomain code:status userInfo:nil];
		}
        return NO;
	}
    
    return YES;
}

+ (BOOL)deleteItemForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error 
{
	if (!username || !serviceName) {
		if (error != nil) {
			*error = [NSError errorWithDomain:STKeychainErrorDomain code:-2000 userInfo:nil];
		}
		return NO;
	}
	
	if (error != nil) {
		*error = nil;
	}
    
	NSArray *keys = [[[NSArray alloc] initWithObjects:(NSString *)kSecClass, kSecAttrAccount, kSecAttrService, kSecReturnAttributes, nil] autorelease];
	NSArray *objects = [[[NSArray alloc] initWithObjects:(NSString *)kSecClassGenericPassword, username, serviceName, kCFBooleanTrue, nil] autorelease];
	
	NSDictionary *query = [[[NSDictionary alloc] initWithObjects:objects forKeys:keys] autorelease];
	
	OSStatus status = SecItemDelete((CFDictionaryRef) query);
	
	if (status != noErr) {
		if (error != nil) {
			*error = [NSError errorWithDomain:STKeychainErrorDomain code:status userInfo:nil];
		}
        	return NO;
	}
    
    return YES;
}


// 08/03/15 long term device ID storage/access
#pragma mark - Device ID

+ (BOOL)deviceIdExists {
    NSString *devId = [self getDecodedDeviceId];
    BOOL devIdExists = (devId && devId.length > 0);
    return devIdExists;
}

// [guid]/[device model]
+ (BOOL)createAndStoreDeviceIdWithError:(NSError **)error 
{
    if ([self deviceIdExists]) {
        NSLog(@"%sALERT: keychain item for deviceId exists. NOT creating new keychain item", __PRETTY_FUNCTION__);
        return NO;
    }

    OSStatus status = kSPKeychainErrorBadArguments;
    
    NSMutableDictionary *writeQuery = [self _queryForService:kSPDeviceIdServiceKey 
                                                     account:kSPDeviceIdAccountKey];
//    [writeQuery setObject:(NSString *)kSPDeviceIdServiceKey forKey:(__bridge id)kSecAttrLabel]; // need label attrib?
    [writeQuery setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly 
                   forKey:(__bridge id)kSecAttrAccessible];
    
#pragma mark Device ID GUID
    
    // GUID
    NSString *guid = [[NSUUID UUID] UUIDString];
    
    // encode
    NSString *encodedStr = [self encodedStringFromString:guid];

    // data
    NSData *dataStr = [encodedStr dataUsingEncoding:NSUTF8StringEncoding];    
    [writeQuery setObject:dataStr forKey:(id<NSCopying>)kSecValueData];
    
    // Write to keychain
    NSLog(@"Write new device id to keychain:\n%@\n\n", encodedStr);    
    status = SecItemAdd((__bridge CFDictionaryRef)writeQuery, NULL);
    
    if (status != noErr) {
        if (error != nil) {
            *error = [NSError errorWithDomain:STKeychainErrorDomain code:status userInfo:nil];
        }
    }
    
    return (status == noErr);
}

+ (NSString *)getEncodedDeviceId {

    NSDictionary *keychainDict = [self getDeviceIdKeychainDict];
    if (nil == keychainDict || keychainDict.count == 0) {
        return nil;
    }
    
    NSData *devIdData = keychainDict[kSPKeychainDataKey];
    NSString *encodedDevId = [[[NSString alloc] initWithData:devIdData 
                                                    encoding:NSUTF8StringEncoding] autorelease];
    return encodedDevId;
}

+ (NSString *)getDecodedDeviceId {
    NSString *encStr = [self getEncodedDeviceId];
    if (nil == encStr || encStr.length == 0) {
        return nil;
    }

    NSString *devIdStr = [self decodedStringFromString:encStr];
    return devIdStr;
}

// Returns LAST keychain dictionary returned from the 
// getAllWithService:account:error method
+ (NSDictionary *)getDeviceIdKeychainDict {
    NSError *error = nil;
    NSArray *matches = [self getAllWithService:kSPDeviceIdServiceKey 
                                       account:kSPDeviceIdAccountKey 
                                         error:&error];
    if (nil == matches) {
        NSLog(@"%s\n -- NO device id found in keychain", __PRETTY_FUNCTION__);
        return nil;
    }
    
    if (error) {
        NSLog(@"%s\n -- Error accessing device id\n%@", 
              __PRETTY_FUNCTION__, [error localizedDescription]);
        return nil;
    }
    
    if (matches.count > 1) {
        NSLog(@"%s\n -- WARNING: multiple device id keychain items found - returning LAST", 
              __PRETTY_FUNCTION__);
    }

    NSDictionary *keychainDict = (__bridge NSDictionary *)[matches lastObject];
    return keychainDict;
}

+ (NSArray *)getAllWithService:(NSString *)service account:(NSString *)account error:(NSError **)error {
    
    NSMutableDictionary *query = [NSMutableDictionary dictionaryWithCapacity:4];
    [query setObject:service forKey:(__bridge id)kSecAttrService];
    [query setObject:account forKey:(__bridge id)kSecAttrAccount];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];
    [query setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [query setObject:(__bridge id)kSecMatchLimitAll forKey:(__bridge id)kSecMatchLimit];
    
    OSStatus status = kSPKeychainErrorBadArguments;
    CFTypeRef results = NULL;
    status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&results);
        
    if (status != noErr) {
        if (error != nil) {
            *error = [NSError errorWithDomain:STKeychainErrorDomain code:status userInfo:nil];
        }
        return nil;
    }
    
    return (NSArray *)results;
}

// Public wrapper for deleteAll method
// Note: instance method for safety against accidental usage
- (void)deleteALLKeychainItemsForService:(NSString *)service account:(NSString *)account {
    [[self class] _clearALLKeychainItemsForService:service account:account];
}

#pragma mark Utilities

+ (NSString *)encodedStringFromString:(NSString *)str {
    if (USE_BASE_64) {
        return [self base64EncodedStringFromString:str];
    } else {
        return [self hexEncodedString:str];
    }
}

+ (NSString *)decodedStringFromString:(NSString *)encStr {
    if (USE_BASE_64) {
        return [self decodedStringFromBase64String:encStr];
    } else {
        return [self decodedStringFromHexString:encStr];
    }    
}

+ (NSString *)hexEncodedString:(NSString *)str {
    return [NSString stringToHex:str];
}

+ (NSString *)decodedStringFromHexString:(NSString *)hxStr {
    return [NSString stringFromHex:hxStr];
}

+ (NSString *)base64EncodedStringFromString:(NSString *)str {
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64Str = [data base64EncodedStringWithOptions:0];    
    return base64Str;
}

+ (NSString *)decodedStringFromBase64String:(NSString *)bStr {
    NSData *data = [[[NSData alloc] initWithBase64EncodedString:bStr options:0] autorelease];
    NSString *decodedStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [decodedStr autorelease];
}


#pragma mark - Private

// Base query dictionary utility - 
// mutable dictionary returned may be used to add query attributes
+ (NSMutableDictionary *)_queryForService:(NSString *)service account:(NSString *)account {

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:4];
    
    [dictionary setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    
    if (service) {
        [dictionary setObject:service forKey:(__bridge id)kSecAttrService];
    }
    
    if (account) {
        [dictionary setObject:account forKey:(__bridge id)kSecAttrAccount];
    }
    
    return dictionary;
}

// Wrapped by the public deleteALLKeychainItemsForService:account instance method
+ (void)_clearALLKeychainItemsForService:(NSString *)service account:(NSString *)account {
    
    NSError *error = nil;
    NSArray *accounts = [self getAllWithService:service account:account error:&error];
    for (int i=0; i<accounts.count; i++) {
        NSError *error = nil;
        [self deleteItemForUsername:account andServiceName:service error:&error];
    }
}

#endif



@end