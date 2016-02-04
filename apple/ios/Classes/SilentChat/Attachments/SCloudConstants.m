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

#import "SCloudConstants.h"

NSString *const LocalUserActiveDeviceMayHaveChangedNotification = @"LocalUserActiveDeviceMayHaveChanged";

NSString *const kNetworkID_Production  = @"production";
NSString *const kNetworkID_QA          = @"qa";
NSString *const kNetworkID_Testing     = @"test";
NSString *const kNetworkID_Development = @"dev";
NSString *const kNetworkID_Fake        = @"fake";

NSString *const kSilentStorageS3Mime = @"application/x-scloud";
NSString *const kSilentStorageS3Bucket = @"com.silentcircle.silenttext.scloud";

static uint8_t newProductionWebAPIKeyHash[] =
{   0x8E, 0xD1, 0x94, 0xC5, 0x79, 0xD7, 0x49, 0xDD,
    0x3A, 0xE7, 0xAE, 0xDA, 0xA2, 0xF5, 0xA8, 0xAF,
    0x9F, 0xC9, 0xEB, 0xE4, 0x52, 0x2E, 0x40, 0x8F,
    0xCE, 0x6F, 0x7B, 0x17, 0xA4, 0x6E, 0x97, 0xBD
};

static uint8_t newQAWebAPIKeyHash[] =
{   0x56, 0x50, 0xDD, 0x75, 0x0A, 0xBC, 0x6F, 0xE5,
    0x37, 0x68, 0x14, 0x46, 0x1A, 0x3B, 0xF4, 0xAE,
    0xD6, 0x91, 0x3C, 0x1C, 0xBF, 0x0E, 0x53, 0x56,
    0x8D, 0x64, 0x29, 0x53, 0x42, 0x4B, 0x3E, 0x37
};

#define newDevWebAPIKeyHash  newQAWebAPIKeyHash

static uint8_t newTestWebAPIKeyHash[] =
{   0x35, 0xE9, 0xF6, 0x30, 0x61, 0xFF, 0xA8, 0x56,
    0xFE, 0x3B, 0xF5, 0x55, 0x3B, 0x6F, 0x04, 0xAE,
    0x5A, 0xA5, 0xE3, 0x46, 0xD0, 0xF3, 0xAC, 0x2A,
    0x00, 0xEB, 0x9C, 0x7F, 0xB1, 0xC1, 0xA7, 0xA7
};

NSTimeInterval const kDefaultSRVRecordLifespan = 3600 * 24; // is once a day reasonable?

NSString *const kSCErrorDomain = @"com.silentcircle.error";

@implementation SCloudConstants

+ (NSDictionary *)SilentCircleNetworkInfo
{
    return @{
             kNetworkID_Production:
                 @{
                     @"displayName" : @"Production",
                     
                     @"brokerSRV"   : @"_broker-client._tcp.silentcircle.com",
                     
//                    @"brokerURL"   : @"199.217.106.51",
                     @"brokerURL"   : @"accounts.silentcircle.com",
                    @"brokerPort"  : @(443),
                     
//                     @"xmppSRV"     : @"_xmpp-client._tcp.silentcircle.com",
//                     @"xmppDomain"  : @"silentcircle.com",
                     
                     // These are fallback ports
//                     @"xmppURL"     : @"ves97t.silentcircle.net",
//                     @"xmppPort"    : @(443),
                     
//                     @"xmppSHA256"  : @[ // array
//                             [NSData dataWithBytes:newProductionXmppKeyHash length:sizeof(newProductionXmppKeyHash)]
//                             ],
                     
                     @"webAPISHA256": @[ // array
                             [NSData dataWithBytes:newProductionWebAPIKeyHash length:sizeof(newProductionWebAPIKeyHash)]
                             ],
                     
                     @"canProvision": @(YES),
                     @"canMulticast": @(YES),
                     @"canDelayNotifications": @(NO),
                     },
             
             
             kNetworkID_QA:
                 @{
                     @"displayName" : @"QA",
                     @"displayColor": [UIColor colorWithRed:255/255.0f green:88/255.0f blue:161/255.0f alpha:1.0f],
                     
                     @"brokerSRV"   : @"_broker-client._tcp.xmpp-qa.silentcircle.net",
//                     @"xmppSRV"     : @"_xmpp-client._tcp.xmpp-qa.silentcircle.net",
                     
                     //			@"brokerURL"   : @"accounts-qa.silentcircle.com",
                     //			@"brokerPort"  : @(443),
                     
                     //			@"xmppURL"     : @"jb02q-fsyyz.silentcircle.net",
                     //			@"xmppPort"    : @(5223),
                     
//                     @"xmppDomain"  : @"xmpp-qa.silentcircle.net",
//                     
//                     @"xmppSHA256"  : @[ // array
//                             [NSData dataWithBytes:newQAXmppKeyHash length:sizeof(newQAXmppKeyHash)]
//                             ],
                     
                     @"webAPISHA256": @[ // array
                             [NSData dataWithBytes:newQAWebAPIKeyHash length:sizeof(newQAWebAPIKeyHash)]
                             ],
                     
#if INCLUDE_QA_NET
                     @"canProvision": @(YES),
#endif
                     @"canMulticast": @(YES),
                     @"canDelayNotifications": @(YES),
                     },
             
             
             kNetworkID_Testing:
                 @{
                     @"displayName" : @"Testing",
                     @"displayColor": [UIColor colorWithRed:149/255.0f green:182/255.0f blue:11/255.0f alpha:1.0f],
                     
                     @"brokerSRV"   : @"_broker-client._tcp.xmpp-testing.silentcircle.net",
//                     @"xmppSRV"     : @"_xmpp-client._tcp.xmpp-testing.silentcircle.net",
                     
                     @"brokerURL"   : @"accounts-testing.silentcircle.com",
                     @"brokerPort"  : @(443),
                     
//                     @"xmppDomain"  : @"xmpp-testing.silentcircle.net",
//                     
//                     @"xmppSHA256"  : @[ // array
//                             [NSData dataWithBytes:newTestXmppKeyHash length:sizeof(newTestXmppKeyHash)]
//                             ],
                     
                     @"webAPISHA256": @[ // array
                             [NSData dataWithBytes:newTestWebAPIKeyHash length:sizeof(newTestWebAPIKeyHash)]
                             ],
                     
#if INCLUDE_TEST_NET
                     @"canProvision": @(YES),
#endif
                     @"canMulticast": @(YES),
                     @"canDelayNotifications": @(YES),
                     },
             
             
             kNetworkID_Development:
                 @{
                     @"displayName" : @"Development",
                     @"displayColor": [UIColor colorWithRed:149/255.0f green:114/255.0f blue:10/255.0f alpha:1.0f],
                     
                     @"brokerSRV"   : @"_broker-client._tcp.xmpp-dev.silentcircle.net",
//                     @"xmppSRV"     : @"_xmpp-client._tcp.xmpp-dev.silentcircle.net",
                     
                     //			@"brokerURL"   : @"sccps-testing.silentcircle.com",
                     //			@"brokerPort"  : @(443),
                     
                     //			@"brokerURL"   : @"accounts-dev.silentcircle.com",
                     //			@"brokerPort"  : @(443),
                     
//                     @"xmppURL"     : @"jb01d-jtymq.silentcircle.net",
//                     @"xmppPort"    : @(5223),
//                     
//                     @"xmppDomain"  : @"xmpp-dev.silentcircle.net",
//                     
//                     @"xmppSHA256"  : @[ // array
//                             [NSData dataWithBytes:newDevXmppKeyHash length:sizeof(newDevXmppKeyHash)]
//                             ],
                     
                     @"webAPISHA256": @[ // array
                             [NSData dataWithBytes:newDevWebAPIKeyHash length:sizeof(newDevWebAPIKeyHash)]
                             ],
                     
#if INCLUDE_DEV_NET
                     @"canProvision": @(YES),
#endif
                     @"canMulticast": @(YES),
                     @"canDelayNotifications": @(YES),
                     },
             
             
             kNetworkID_Fake:
                 @{
                     @"displayName" : @"Fake",
                     @"displayColor": [UIColor colorWithRed:129/255.0f green:187/255.0f blue:121/255.0f alpha:1.0f],
                     
//                     @"xmppDomain"  : @"fake.silentcircle.net",
                     
                     @"canProvision": @(NO),
                     @"canMulticast": @(YES),
                     @"canDelayNotifications": @(YES),
                     },
             
             };
}

@end

// forward
static SCLError  SCCrypto_GetErrorString( SCLError err,  size_t	bufSize, char *outString);

@implementation SCloudUtilities

+ (NSString *)displayStringFromSCLError:(SCLError)protocolError
{
    // See also: stringFromSCLError (for technical strings)
    
    SCLError err;
    
    char errorBuf[256];
    err = SCCrypto_GetErrorString(protocolError, sizeof(errorBuf), errorBuf);
    
    if (err == kSCLError_NoErr)
        return [NSString stringWithUTF8String:errorBuf];
    else
        return nil;
}

+ (NSError *)errorWithSCLError:(SCLError)err
{
    NSString *errStr = [self displayStringFromSCLError:err];
    
    NSDictionary *details = nil;
    if (errStr) {
        details = @{ NSLocalizedDescriptionKey : errStr };
    }
    
    return [NSError errorWithDomain:kSCErrorDomain code:err userInfo:details];
}

@end

typedef struct {
	SCLError     err;
	const char *msg;
} error_map_entry;

static const error_map_entry error_map_table[] =
{
	{ kSCLError_NoErr,         "Successful" },
	{ kSCLError_UnknownError,  "Generic Error" },
	{ kSCLError_NOP,         	"Non-fatal 'no-operation' requested."},
	{ kSCLError_BadParams,    	"Invalid argument provided."},
	
	
	{ kSCLError_OutOfMemory,          "Out of memory"},
	{ kSCLError_BufferTooSmall,       "Not enough space for output"},
	
	{ kSCLError_UserAbort,             "User Abort"},
	{ kSCLError_UnknownRequest,        "Unknown Request"},
	{ kSCLError_LazyProgrammer,        "Feature incomplete"},
	
	{ kSCLError_FeatureNotAvailable,  "Feature not available" },
	{ kSCLError_ResourceUnavailable,  "Resource not available" },
	{ kSCLError_NotConnected,         "Not connected" },
	{ kSCLError_ImproperInitialization,  "Not Initialized" },
	{ kSCLError_CorruptData,           "Corrupt Data" },
	{ kSCLError_SelfTestFailed,        "Self Test Failed" },
	{ kSCLError_BadIntegrity,               "Bad Integrity" },
	{ kSCLError_BadHashNumber,         "Invalid hash specified" },
	{ kSCLError_BadCipherNumber,       "Invalid cipher specified" },
	{ kSCLError_BadPRNGNumber,              "Invalid PRNG specified" },
	{ kSCLError_SecretsMismatch,       "Shared Secret Mismatch" },
	{ kSCLError_KeyNotFound,           "Key Not Found" },
	{ kSCLError_ProtocolError,        "Protocol Error" },
	{ kSCLError_ProtocolContention,        "Protocol Contention" },
	{ kSCLError_KeyLocked     ,        "Key Locked" },
	{ kSCLError_KeyExpired    ,        "Key Expired" },
	{ kSCLError_OtherError    ,        "Other Error" },
};

#define ERROR_MAP_TABLE_SIZE (sizeof(error_map_table) / sizeof(error_map_entry))

static SCLError  SCCrypto_GetErrorString( SCLError err,  size_t	bufSize, char *outString)
{
	int i;
	*outString = 0;
	
	for(i = 0; i< ERROR_MAP_TABLE_SIZE; i++)
		if(error_map_table[i].err == err)
		{
			if(strlen(error_map_table[i].msg) +1 > bufSize)
				return (kSCLError_BufferTooSmall);
			strcpy(outString, error_map_table[i].msg);
			return kSCLError_NoErr;
		}
	
	return kSCLError_UnknownError;
}
