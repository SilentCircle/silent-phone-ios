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
//  SCPinningObject.m
//  VoipPhone
//
//  Created by Stelios Petrakis on 10/04/16.
//
//

#import "SCPinningObject.h"

#include <mbedtls/config.h>
#include <mbedtls/ssl.h>
#include <mbedtls/sha256.h>

@implementation SCPinningObject

#pragma mark NSURLConnectionDelegate

-(BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace*)space {
    
    return [[space authenticationMethod] isEqualToString: NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        
        BOOL serverTrustIsValid = [[self class] evaluateServerTrust:challenge.protectionSpace.serverTrust
                                                        forHostname:challenge.protectionSpace.host];
        
        if(serverTrustIsValid) // SPKI keys match, continue with other checks
            return [challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
        else // SPKI keys do not match
            return [challenge.sender cancelAuthenticationChallenge:challenge];
    }
    
    return [challenge.sender rejectProtectionSpaceAndContinueWithChallenge:challenge];
}

#pragma mark NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        
        BOOL serverTrustIsValid = [[self class] evaluateServerTrust:challenge.protectionSpace.serverTrust
                                                        forHostname:challenge.protectionSpace.host];
        
        if(serverTrustIsValid) { // SPKI keys match, continue with other checks
            
            if (completionHandler) {
                
                NSURLCredential*  credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
                
                completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
            }
            
        } else {
            
            if (completionHandler) {
                completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, NULL);
            }
        }
        
    } else if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodClientCertificate]) {
        
        if (completionHandler) {
            completionHandler(NSURLSessionAuthChallengeRejectProtectionSpace, NULL);
        }
    }
}

#pragma mark Class methods

+ (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forHostname:(NSString*)serverHostname {
    
    if (serverTrust == NULL)
        return NO;
    
    // Re-check the certificate chain using the default SSL validation in case it was disabled
    
    // Create and use a sane SSL policy to force hostname validation, even if the supplied trust has a bad
    // policy configured (such as one from SecPolicyCreateBasicX509())
    SecPolicyRef SslPolicy = SecPolicyCreateSSL(YES, (__bridge CFStringRef)serverHostname);
    SecTrustSetPolicies(serverTrust, SslPolicy);
    CFRelease(SslPolicy);
    
    SecTrustResultType trustResult = kSecTrustResultInvalid;
    
    // Evaluate the certificate chain
    if (SecTrustEvaluate(serverTrust, &trustResult) != errSecSuccess)
        return NO;
    
    if ((trustResult != kSecTrustResultUnspecified) && (trustResult != kSecTrustResultProceed)) {
        
        // Default SSL validation failed
        CFDictionaryRef evaluationDetails = SecTrustCopyResult(serverTrust);
        NSLog(@"Error: default SSL validation failed for %@: %@", serverHostname, evaluationDetails);
        CFRelease(evaluationDetails);
        
        return NO;
    }
    
    // Base-64 encoded SHA-256 hashes of root certs' SPKI (Subject Public Key Info)
    NSArray *certSPKIhashes = @[
                                // Entrust Root Certification Authority (used by sccps.silentcircle.com) Serial Number: 1164660820
                                @"bb+uANN7nNc/j7R95lkXrwDg3d9C286sIMF8AnXuIJU=",
                                // Entrust Root Certification Authority - G2 (used by sccps.silentcircle.com) Serial Number: 1246989352
                                @"du6FkDdMcVQ3u8prumAo6t3i3G27uMP2EOhR8R0at/U=",
                                // DST Root CA X3 (used by sentry.silentcircle.org)
                                @"Vjs8r4z+80wjNcr1YKepWQboSIRi63WsWXhIMN+eWys=",
                                // Baltimore CyberTrust Root (used by Amazon AWS) Serial Number: 33554617
                                @"Y9mvm0exBk1JoQ57f9Vm28jKo5lFm/woKcVxrYxu80o="
                                ];
    
    BOOL containsHash = NO;
    
    // Loop through the server certificate chain
    CFIndex count = SecTrustGetCertificateCount(serverTrust);
    
    for(int i = 0; i < count; i++) {
        
        SecCertificateRef serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, i);
        
        NSData* serverCertificateData = (NSData*)CFBridgingRelease(SecCertificateCopyData(serverCertificate));
        
        // Get the SPKI offered by the server for the selected certificate
        NSString *serverSPKIhash = [[self class] getPubKeyHashForCertificate:serverCertificateData];
                
        // Check if it exists in the list of saved Root Cert SPKI hashes
        if([certSPKIhashes containsObject:serverSPKIhash]) {
            
            containsHash = YES;
            break;
        }
    }
    
    if(!containsHash)
        NSLog(@"%s Server Certificate SPKI not contained in local SPKI hash list!", __PRETTY_FUNCTION__);
    
    return containsHash;
}

#pragma mark Private methods

+ (NSString *)getPubKeyHashForCertificate:(NSData*)serverCertificateData {
    
    // Initialize the certificate
    mbedtls_x509_crt cert;
    memset(&cert, 0, sizeof( mbedtls_x509_crt ));
    mbedtls_x509_crt_init(&cert);
    
    // Parse the certificate
    const unsigned char *certificateDataBytes = (const unsigned char *)[serverCertificateData bytes];
    
    int iCertErr = mbedtls_x509_crt_parse(&cert, certificateDataBytes, [serverCertificateData length]);
    
    if (iCertErr != 0) {
        mbedtls_x509_crt_free( &cert );
        return nil;
    }
    
    // polarssl does not seem to have a way to determine buffer size ahead of time. The keys I've seen are 294 bytes.
    uint8_t output_buf[1024];
    memset(output_buf, 0, sizeof(output_buf));
    
    // Write a public key to a SubjectPublicKeyInfo DER structure
    // Note: data is written at the end of the buffer!
    int len = mbedtls_pk_write_pubkey_der(&cert.pk, output_buf, sizeof(output_buf));
    
    mbedtls_x509_crt_free( &cert );
    
    if (len < 0)
        return nil;
    
    unsigned char hash[32]; // SHA-256
    
    mbedtls_sha256(output_buf+sizeof(output_buf)-len, len, hash, 0);
    
    NSData *keyHashData = [NSData dataWithBytes:hash length:sizeof(hash)];
    
    return [keyHashData base64EncodedStringWithOptions:0];
}

@end
