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
//  SCPinningObject.h
//  VoipPhone
//
//  Created by Stelios Petrakis on 10/04/16.
//
//

#import <Foundation/Foundation.h>

/**
 SCPinningObject can be used as an object that acts as a implementer of NSURLConnectionDelegate and NSURLSessionDelegate
 methods that relate to certificate pinning.
 
 The object checks the server trust certificate PK against the saved SHA-256 hashes of PK of the saved Root Certificates.
 
 You can view examples of usage of the SCPinningObject in the RavenClient.h and RecentObject.h classes.
 
 For cases that the SCPinningObject cannot be used as-is, the evaluateServerTrust:forHostname: class helper method can be used
 to check the server trust against the saved certificates.
 */
@interface SCPinningObject : NSObject <NSURLConnectionDelegate, NSURLSessionDelegate>

/**
 Check the server trust certificate PK against the saved hashes.
 
 This method verifies that the certificate chain is valid
 @param serverTrust The server trust (provided by the NSURLConnection/NSURLSessionDelegate methods).
 @return BOOL Yes if the server trust contains one of the saved root hashes, NO if not
 */
+ (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forHostname:(NSString*)serverHostname;

@end
