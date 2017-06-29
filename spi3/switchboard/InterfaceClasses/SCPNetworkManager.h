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
//  SCPNetworkManager.h
//  SP3
//
//  Created by Eric Turner on 5/26/15.
//  Based on original work by Janis Narbuts SP1
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SCPinningObject.h"

typedef NS_ENUM(NSInteger, SCPNetworkManagerMethod) {
    SCPNetworkManagerMethodUnknown,
    SCPNetworkManagerMethodGET,
    SCPNetworkManagerMethodPOST,
    SCPNetworkManagerMethodPUT,
    SCPNetworkManagerMethodDELETE,
    SCPNetworkManagerMethodHEAD
};

typedef NS_ENUM(NSInteger, SCPNetworkManagerErrorCode) {
    SCPNetworkManagerErrorCodeUnknown           = -1,
    SCPNetworkManagerErrorCodeNoAPIKey          = -100,
    SCPNetworkManagerErrorCodeNoURL             = -200,
    SCPNetworkManagerErrorCodeRequestTimedOut   = -300
};

extern NSString *const SCPNetworkManagerErrorDomain;

extern NSString *const SCPNetworkManagerEndpointV1Me;
extern NSString *const SCPNetworkManagerEndpointV1MeAvatar;
extern NSString *const SCPNetworkManagerEndpointV2ContactsValidate;
extern NSString *const SCPNetworkManagerEndpointV2People;
extern NSString *const SCPNetworkManagerEndpointV1MeDevice;
extern NSString *const SCPNetworkManagerEndpointV1MeNewDevice;
extern NSString *const SCPNetworkManagerEndpointV1User;
extern NSString *const SCPNetworkManagerEndpointV1UserPurchaseAppStore;
extern NSString *const SCPNetworkManagerEndpointV1Products;
extern NSString *const SCPNetworkManagerEndpointV1FreemiumCheck;
extern NSString *const SCPNetworkManagerEndpointV1AuthDomain;

@interface SCPNetworkManager : SCPinningObject

/**
 Called by SCPPushHandler when
 
 `- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(NSString *)type`
 delegate method is called.
 */
- (void)pushNotificationReceived;

/**
 Makes a request to Silent Circle API server to a certain endpoint
 using a method defined in SCPNetworkManagerMethod with or without arguments (which are internally serialized to JSON)
 and responding via a completion block. All the requests are pinned using the SCPPinningObject class.

 @param endpoint The endpoint to make the request to.
 @param method The method to use (@look SCPNetworkManagerMethod).
 @param arguments An object (dictionary, array, etc) that holds the data to be sent. This data is converted to a serialized JSON object.
 @param completion The completion block to be used in order to be notified about the request success or failure. It contains an NSError object in case of failure, a reponse object which is the JSON deserialized object of the response (NSDictionary, NSArray etc depending on the endpoint) and the NSHTTPURLResponse object. The completion block code runs in the same thread that the network request was made, which can be used to your advantage if you want to make any extra heavy-loading tasks before dispatching to the main thread.

 @return The NSURLSessionTask object if the request has been made, nil otherwise
 */
- (NSURLSessionTask *)apiRequestInEndpoint:(NSString *)endpoint
                                    method:(SCPNetworkManagerMethod)method
                                 arguments:(id)arguments
                                completion:(void(^)(NSError *error, id responseObject, NSHTTPURLResponse * httpResponse))completion;

/**
 Makes a request to Silent Circle API server to a certain endpoint
 using a method defined in SCPNetworkManagerMethod with or without arguments (which are internally serialized to JSON)
 and responding via a completion block. All the requests are pinned using the SCPPinningObject class.
 
 @discussion Use the useSharedSession argument to promote this request and make it be fulfilled faster.
 Warning: DO NOT set this argument to NO if you are doing a lot of background API resolutions (v1/user etc)
 as this might lead to heavy memory allocation. Set this property to YES only when it is critical that
 the request needs to be fulfilled faster (e.g. SCPCallHelper, when we need to push a new ChatVC etc.)
 
 @param endpoint The endpoint to make the request to.
 @param method The method to use (@look SCPNetworkManagerMethod).
 @param arguments An object (dictionary, array, etc) that holds the data to be sent. This data is converted to a serialized JSON object.
 @param useSharedSession Whether the request should use the shared session object of the SCPNetworkManager class or a separate one which will make the request be fulfilled faster.
 @param completion The completion block to be used in order to be notified about the request success or failure. It contains an NSError object in case of failure, a reponse object which is the JSON deserialized object of the response (NSDictionary, NSArray etc depending on the endpoint) and the NSHTTPURLResponse object. The completion block code runs in the same thread that the network request was made, which can be used to your advantage if you want to make any extra heavy-loading tasks before dispatching to the main thread.
 
 @return The NSURLSessionTask object if the request has been made, nil otherwise
 */
- (NSURLSessionTask *)apiRequestInEndpoint:(NSString *)endpoint
                                    method:(SCPNetworkManagerMethod)method
                                 arguments:(id)arguments
                          useSharedSession:(BOOL)useSharedSession
                                completion:(void(^)(NSError *error, id responseObject, NSHTTPURLResponse * httpResponse))completion;

/**
 Makes a request to Silent Circle API server with a certain NSURLRequest
 and responding via a completion block. All the requests are pinned using the SCPPinningObject class.
 
 @param request The NSURLrequest.
 @param completion The completion block to be used in order to be notified about the request success or failure. It contains an NSError object in case of failure, a reponse object which is the JSON deserialized object of the response (NSDictionary, NSArray etc depending on the endpoint) and the NSHTTPURLResponse object. The completion block code runs in the same thread that the network request was made, which can be used to your advantage if you want to make any extra heavy-loading tasks before dispatching to the main thread.
 
 @return The NSURLSessionTask object if the request has been made, nil otherwise
 */
- (NSURLSessionTask *)apiRequest:(NSURLRequest *)request completion:(void(^)(NSError * error, id responseObject, NSHTTPURLResponse *httpResponse))completion;

/**
 Makes a synchronous request to Silent Circle API server to a certain endpoint using a method defined in SCPNetworkManagerMethod 
 with or without arguments (which are internally serialized to JSON)
 and responding via a completion block. All the requests are pinned using the SCPPinningObject class.
 
 Warning: This method is to be used *only* when synchronous request are really required (e.g. libzina helper methods). It is recommended
 that you always prefer the apiRequestInEndpoint:method:arguments:completion: method instead.
 
 @param endpoint The endpoint to make the request to.
 @param method The method to use (@look SCPNetworkManagerMethod).
 @param arguments An object (dictionary, array, etc) that holds the data to be sent. This data is converted to a serialized JSON object.
 @param outError The output error.
 @param httpResponse The NSHTTPURLResponse object.
 @return The json deserialized object of the response or the NSURLResponse object in cases where the response is in a non JSON form.
 */
- (id)synchronousApiRequestInEndpoint:(NSString *)endpoint
                               method:(SCPNetworkManagerMethod)method arguments:(id)arguments
                                error:(NSError **)outError httpResponse:(NSHTTPURLResponse **)httpResponse;

/**
 Makes a synchronous request to Silent Circle API server with a certain NSURLRequest
 and responding via a completion block. All the requests are pinned using the SCPPinningObject class.

 @param request The NSURLrequest.
 @param outError The output error.
 @param httpResponse The NSHTTPURLResponse object.
 @return The json deserialized object of the response or the NSURLResponse object in cases where the response is in a non JSON form.
 */
- (id)synchronousApiRequest:(NSURLRequest *)request error:(NSError **)outError response:(NSHTTPURLResponse **)httpResponse;

/**
 Prepares the endpoint with a specific username.

 @param The endpoint to use (typically either SCPNetworkManagerEndpointV1User or SCPNetworkManagerEndpointV2People).
 @param username The username to use
 @return The prepared endpoint url string
 */
+ (NSString *)prepareEndpoint:(NSString *)endpoint withUsername:(NSString *)username;

/**
 Check for available network connection

 @return YES if network is reachable NO otherwise
 */
-(BOOL) hasNetworkConnection;

@end
