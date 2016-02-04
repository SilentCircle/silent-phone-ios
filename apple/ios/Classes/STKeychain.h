//
//  STKeychain.h
//
//  Created by Buzz Andersen on 3/7/11.
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

/** Error codes that can be returned in NSError objects. */
typedef enum {
    /** No error. */
    kSPKeychainErrorNone = noErr,
    
    /** Some of the arguments were invalid. */
    kSPKeychainErrorBadArguments = -1001,
    
    /** There was no password. */
    kSPKeychainErrorNoPassword = -1002,
    
    /** One or more parameters passed internally were not valid. */
    kSPKeychainErrorInvalidParameter = errSecParam,
    
    /** Failed to allocate memory. */
    kSPKeychainErrorFailedToAllocated = errSecAllocate,
    
    /** No trust results are available. */
    kSPKeychainErrorNotAvailable = errSecNotAvailable,
    
    /** Authorization/Authentication failed. */
    kSPKeychainErrorAuthorizationFailed = errSecAuthFailed,
    
    /** The item already exists. */
    kSPKeychainErrorDuplicatedItem = errSecDuplicateItem,
    
    /** The item cannot be found.*/
    kSPKeychainErrorNotFound = errSecItemNotFound,
    
    /** Interaction with the Security Server is not allowed. */
    kSPKeychainErrorInteractionNotAllowed = errSecInteractionNotAllowed,
    
    /** Unable to decode the provided data. */
    kSPKeychainErrorFailedToDecode = errSecDecode
} SPKeychainErrorCode;


extern NSString * const STKeychainErrorDomain;
extern NSString * const kSPDeviceIdAccountKey;
extern NSString * const kSPDeviceIdServiceKey;

extern NSString * const kSPKeychainAccessControlKey;
extern NSString * const kSPKeychainAccountKey;
extern NSString * const kSPKeychainAccessGroupKey;
extern NSString * const kSPKeychainCreatedAtKey;
extern NSString * const kSPKeychainClassKey;
extern NSString * const kSPKeychainDataKey;
extern NSString * const kSPKeychainDescriptionKey;
extern NSString * const kSPKeychainLabelKey;
extern NSString * const kSPKeychainLastModifiedKey;
extern NSString * const kSPKeychainServiceKey;
extern NSString * const kSPKeychainSyncKey ;
extern NSString * const kSPKeychainTombKey;


@interface STKeychain : NSObject

+ (NSString *)getPasswordForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error;
+ (BOOL)storeUsername:(NSString *)username andPassword:(NSString *)password forServiceName:(NSString *)serviceName updateExisting:(BOOL)updateExisting error:(NSError **)error;
+ (BOOL)deleteItemForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error;

//08/03/15
/**
 * Returns YES if a keychain item matching kSPDeviceIdAccountKey and
 * kSPDeviceIdServiceKey is found, AND if the decoded GUID string has
 * string length greater than 0.
 */
+ (BOOL)deviceIdExists;

/**
 * Returns the encoded GUID device id string found in the keychain,
 * or nil if it does not exist.
 *
 * @see createAndStoreDeviceIdWithError:
 */
+ (NSString *)getEncodedDeviceId;

/**
 * Returns the decoded GUID device id string found in the keychain, or 
 * nil if it does not exist.
 *
 * @see createAndStoreDeviceIdWithError:
 */
+ (NSString *)getDecodedDeviceId;

/**
 * Returns the device id keychain dictionary or nil if it doesn't exist.
 *
 * The returned keychain dictionary contains all attributes and data.
 */
+ (NSDictionary *)getDeviceIdKeychainDict;

/**
 * Creates a GUID and stores in the keychain.
 *
 * The keychain is stored, and can then be accessed, with the account
 * and service identifier constants, kSPDeviceIdAccountKey and 
 * kSPDeviceIdServiceKey. The device id GUID is a guaranteed globally
 * unique identifier string provifed by the Apple NSUUID class, which is
 * string encoded and stored in the keychain. In the provisioning 
 * process, the decoded GUID is evaluated by the server at provisioning
 * time.
 *
 * Note that the GUID string may be encoded as base64 or hex string,
 * depending on the USE_BASE_64 BOOL const defined in the implementation
 * file. Currently, hex encoding is employed (08/03/15).
 *
 * NOTE: This method calls the deviceIdExists method. If deviceIdExists
 * returns YES, this method returns NO without writing a new keychain
 * item.
 *
 * @param error An optional NSError instance, passed by reference by
 *              the caller.
 *
 * @return YES if keychain item was stored without error, otherwise NO.
 * 
 * @see Prov.mm for client provisioning usage of the stored device id.
 */
+ (BOOL)createAndStoreDeviceIdWithError:(NSError **)error;

/**
 * This method is a wrapper for encoding a given NSString to a 
 * base64-encoded or hex-encoded NSString, determined by the 
 * USE_BASE_64 BOOL const defined in the implementation.
 * Currently, hex encoding is employed (08/03/15).
 *
 * @param str A UTF8-encoded NSString to be encoded.
 *
 * @return An NSString encoded as base64 or as hex.
 */
+ (NSString *)encodedStringFromString:(NSString *)str;

/**
 * This method is a wrapper for decoding an encoded NSString to a 
 * UTF8-encoded NSString, determined by the USE_BASE_64 BOOL const 
 * defined in the implementation.
 * Currently, hex encoding is employed (08/03/15).
 *
 * @param encStr An NSString encoded as base64 or as hex.
 *
 * @return A UTF8-encoded NSString to be encoded.
 *
 * @see encodedStringFromString:
 */
+ (NSString *)decodedStringFromString:(NSString *)encStr;

/**
 * A utility method to encode a UTF8-encoded NSString to base64.
 *
 * @param str An NSString to be encoded as bas64
 * 
 * @return A base64-encoded string
 */
+ (NSString *)base64EncodedStringFromString:(NSString *)str;

/**
 * A utility method to decode a base64-encoded string to a UTF8-encoded 
 * NSString.
 *
 * @param encStr A base64-encoded string
 * 
 * @return A UTF8-encoded NSString.
 */
+ (NSString *)decodedStringFromBase64String:(NSString *)bStr;

/**
 * A utility method to encode a UTF8-encoded NSString as a string of
 * of string representations of hexadecimal values of the given string's
 * characters.
 *
 * @param str An NSString to be encoded as hex
 * 
 * @return A hex-encoded string
 */
+ (NSString *)hexEncodedString:(NSString *)str;

/**
 * A utility method to decode a hex-encoded string to a UTF8-encoded 
 * NSString.
 *
 * @param hxStr A hex-encoded string
 * 
 * @return A UTF8-encoded NSString.
 */
+ (NSString *)decodedStringFromHexString:(NSString *)hxStr;

#pragma mark - Testing
/**
 * A keychain utility method to return all keychain items for the given
 * service and account names.
 *
 * @param service A string identifier with which to match the 
 *                kSecAttrService attribute in a keychain query.
 *
 * @param account A string identifier with which to match the 
 *                kSecAttrAccount attribute in a keychain query.
 *
 * @param error An optional NSError instance, passed by reference by
 *              the caller.
 *
 * @return An NSArray of kechain dictionaries found matching the given
 *         service and account attributes.
 */
+ (NSArray *)getAllWithService:(NSString *)service account:(NSString *)account error:(NSError **)error;

/**
 * A keychain utility method for deleting a keychain item matching the 
 * given service and account names.
 *
 * @param service A string identifier with which to match the 
 *                kSecAttrService attribute in a keychain query.
 *
 * @param account A string identifier with which to match the 
 *                kSecAttrAccount attribute in a keychain query. 
 */
- (void)deleteALLKeychainItemsForService:(NSString *)service account:(NSString *)account;
@end
