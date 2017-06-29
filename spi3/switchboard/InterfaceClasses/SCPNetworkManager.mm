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
//  SCPNetworkManager.m
//  SP3
//
//  Created by Eric Turner on 5/26/15.
//  Based on original work by Janis Narbuts SP1
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SCPNetworkManager.h"
#import "SCPNetworkManager_Private.h"
#import "SCPCallbackInterface.h"
#import "SCPCallManager.h"
#import "SCPNotificationKeys.h"
#import "Reachability.h"
#import "ChatUtilities.h"
#import "NSDictionaryExtras.h"

// Wait for 30 seconds max for every HTTP request
#define HTTP_TIMEOUT    30.0f

// Store responses in the cache for two days
#define CACHE_TTL       2.0f * 24.0f * 3600.0f

// 50 secs is the max time we allow a background task to run
#define BACKGROUND_TASK_TIMEOUT 50

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelWarning;
//#endif

NSString * const SCPNetworkManagerErrorDomain = @"SCPNetworkManagerErrorDomain";

NSString * const SCPNetworkManagerEndpointV1Me                  = @"/v1/me/?api_key=";
NSString * const SCPNetworkManagerEndpointV1MeNewDevice         = @"/v1/me/device/%@/";
NSString * const SCPNetworkManagerEndpointV1MeDevice            = @"/v1/me/device/%@/?api_key=";
NSString * const SCPNetworkManagerEndpointV1MeAvatar            = @"/v1/me/avatar/?api_key=";
NSString * const SCPNetworkManagerEndpointV1User                = @"/v1/user/%@/?api_key=";
NSString * const SCPNetworkManagerEndpointV1UserPurchaseAppStore= @"/v1/user/%@/purchase/appstore/?api_key=";
NSString * const SCPNetworkManagerEndpointV1Products            = @"/v1/products/?api_key=";
NSString * const SCPNetworkManagerEndpointV1FreemiumCheck       = @"/v1/freemium_check/?os=ios&version=%@";
NSString * const SCPNetworkManagerEndpointV2ContactsValidate    = @"/v2/contacts/validate/?api_key=";
NSString * const SCPNetworkManagerEndpointV2People              = @"/v2/people/?terms=%@&start=0&max=20&api_key=";
NSString * const SCPNetworkManagerEndpointV1AuthDomain          = @"/v1/auth_domain/%@/";

typedef NS_ENUM(NSInteger, SCPTimerCallbackType) {
    SCPTimerCallbackTypeBackground,
    SCPTimerCallbackTypePushNotification
};

@interface SCPNetworkManager () {
    
    NSDateFormatter *_cachedDateFormatter;
    NSArray <NSString *> *_allowedCachedEndpoints;
    
    dispatch_queue_t _tiviQueue;
    
    int _timerSecondsPassed;
    NSTimer *_activeTimer;    
}

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;

@property (strong, nonatomic) Reachability *internetReach;
@property (strong, nonatomic) NSURLSession *sharedSession;

@end

@implementation SCPNetworkManager

#pragma mark - Lifecycle

- (instancetype)init {
    
    if(self = [super init]) {
        
        // Any TiVi engine commands have to be dispatched via this queue
        _tiviQueue = dispatch_queue_create( "com.silentphone.tivi", DISPATCH_QUEUE_SERIAL );
        
        self.internetReach = [Reachability reachabilityForInternetConnection];
        [self.internetReach startNotifier];
        
        // /v1/user endpoint is validated alone due to its nature (/v1/user/%@)
        _allowedCachedEndpoints = @[ @"/v2/people", @"/v2/contacts/validate" ];
        
        // Used to check the TTL of the cached NSURLRequests
        _cachedDateFormatter = [NSDateFormatter new];
        [_cachedDateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss ZZZ"];
        
        NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024
                                                             diskCapacity:20 * 1024 * 1024
                                                                 diskPath:nil];

        [NSURLCache setSharedURLCache:URLCache];

        self.sharedSession = [self constructURLSession];
    
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleDidBecomeActiveNotification:)
                                                     name: UIApplicationDidBecomeActiveNotification
                                                   object: nil];
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleDidEnterBackgroundNotification:)
                                                     name: UIApplicationDidEnterBackgroundNotification
                                                   object: nil];
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleWillTerminateNotification:)
                                                     name: UIApplicationWillTerminateNotification
                                                   object: nil];
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleCallDidEndNotification:)
                                                     name: kSCPCallDidEndNotification
                                                   object: nil];
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(handleReachabilityChangedNotification:)
                                                     name: kReachabilityChangedNotification
                                                   object: nil];
    }
    
    return self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications

- (void)handleReachabilityChangedNotification:(NSNotification *)notification {

    dispatch_async(_tiviQueue, ^{
        
        checkIPNow();
    });
}

- (void)handleDidBecomeActiveNotification:(NSNotification *)notification {

    DDLogVerbose(@"%s", __PRETTY_FUNCTION__);

    [self endBackgroundTask];

    if(_activeTimer) {
        
        [_activeTimer invalidate];
        _activeTimer = nil;
    }

    dispatch_async(_tiviQueue, ^{
        
        const char *xr[]={"", ":onka", ":onforeground"};
        z_main(0, 3, xr);
    });
    
    [Switchboard.notificationsManager cancelAllNotifications];
}

- (void)handleDidEnterBackgroundNotification:(NSNotification *)notification {
    
    DDLogVerbose(@"%s", __PRETTY_FUNCTION__);
    
    [self activateBackgroundLogicForType:SCPTimerCallbackTypeBackground];
}

- (void)handleWillTerminateNotification:(NSNotification *)notification {

    DDLogVerbose(@"%s", __PRETTY_FUNCTION__);

    t_onEndApp(); //kills phone engine?

    [_internetReach stopNotifier];
}

- (void)handleCallDidEndNotification:(NSNotification *)notification {
 
    DDLogVerbose(@"%s activeCallCount: %ld", __PRETTY_FUNCTION__, (unsigned long)[SPCallManager activeCallCount]);

    // Only allow the background task to run
    // if there are no more active calls
    if([SPCallManager activeCallCount] > 0)
        return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // Only start the timer when the call
        // ends while the app is backgrounded
        if([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
            return;
        
        [self activateBackgroundLogicForType:SCPTimerCallbackTypeBackground];
    });
}

#pragma mark - Long running background task

- (void) activateBackgroundLogicForType:(SCPTimerCallbackType)type {
    
    [self beginBackgroundTask];
    
    if(_activeTimer) {
        
        [_activeTimer invalidate];
        _activeTimer = nil;
    }
    
    _timerSecondsPassed = 0;
    
    _activeTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                    target:self
                                                  selector:@selector(timerCallback:)
                                                  userInfo:@{ kSCPTimerCallbackTypeKey : @(type) }
                                                   repeats:YES];
}

- (void) beginBackgroundTask {
    
    DDLogVerbose(@"%s", __PRETTY_FUNCTION__);

    dispatch_async(dispatch_get_main_queue(), ^{
        
        if(self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            
            DDLogVerbose(@"%s Ending the previously set background task [%lu]", __PRETTY_FUNCTION__, (unsigned long)self.backgroundTaskIdentifier);
            
            [self endBackgroundTask];
        }
        
        self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            
            [self endBackgroundTask];
        }];
    });
}

- (void) endBackgroundTask {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if(self.backgroundTaskIdentifier == UIBackgroundTaskInvalid)
            return;
        
        DDLogVerbose(@"%s Ending background task [%lu]", __PRETTY_FUNCTION__, (unsigned long)self.backgroundTaskIdentifier);
        
        _timerSecondsPassed = 0;
        
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    });
}

/**
 Timer callback that is called by NSTimers set from either
 the didEnterBackground: notification method or from the 
 pushNotificationReceived method

 @param timer The timer calling this callback
 */
- (void) timerCallback:(NSTimer *)timer {

    // Extract the callback type (either PushNotification or Background)
    SCPTimerCallbackType type = (SCPTimerCallbackType)((NSNumber *)[timer.userInfo objectForKey:kSCPTimerCallbackTypeKey]).integerValue;
    
    if(_timerSecondsPassed > BACKGROUND_TASK_TIMEOUT) {
        
        DDLogVerbose(@"%s Time exceeded", __PRETTY_FUNCTION__);
        
        [self endBackgroundTask];
        [timer invalidate];
        timer = nil;
        
        return;
    }
    
    if([UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
        
        DDLogVerbose(@"%s App became active", __PRETTY_FUNCTION__);
        
        [self endBackgroundTask];
        [timer invalidate];
        timer = nil;
        
        return;
    }
    
    switch (_timerSecondsPassed) {
            
        case 0: {
            
            if(type == SCPTimerCallbackTypePushNotification) {
                
                DDLogVerbose(@"%s Sending :onpushnotification", __PRETTY_FUNCTION__);
                
                dispatch_async(_tiviQueue, ^{
                    
                    [Switchboard doCmd:@":onpushnotification"];
                });
            }
            else if(type == SCPTimerCallbackTypeBackground) {
                
                DDLogVerbose(@"%s Sending :onbackground", __PRETTY_FUNCTION__);
                
                dispatch_async(_tiviQueue, ^{
                    
                    const char *xr[]={"", ":onbackground"};
                    z_main(0, 2, xr);
                });
            }
        }
            break;
            
        case 30: {
            
            DDLogVerbose(@"%s Sending :setexpireszero", __PRETTY_FUNCTION__);
            
            dispatch_async(_tiviQueue, ^{
                
                const char *xr2[]={"", ":setexpireszero"};
                z_main(0, 2, xr2);
            });
        }
            break;
            
        case 40: {
            
            DDLogVerbose(@"%s Sending :stopsockets", __PRETTY_FUNCTION__);
            
            dispatch_async(_tiviQueue, ^{
                
                const char *xr3[]={"", ":stopsockets"};
                z_main(0, 2, xr3);
            });
        }
            break;
            
        case BACKGROUND_TASK_TIMEOUT: {
            
            DDLogVerbose(@"%s Ending local background task...", __PRETTY_FUNCTION__);
            
            [self endBackgroundTask];
            [timer invalidate];
            timer = nil;
            
            return;
        }
            break;
            
        default:
            break;
    }
    
    _timerSecondsPassed += 1;
    
    DDLogVerbose(@"%s secondsPassed: %d Type: %@",
                 __PRETTY_FUNCTION__,
                 _timerSecondsPassed,
                 type == SCPTimerCallbackTypeBackground ? @"Background" : @"Push Notification");
}

#pragma mark - Public

-(BOOL) hasNetworkConnection {
    
    return ([_internetReach currentReachabilityStatus] != NotReachable);
}

#pragma mark - Push Notification

- (void)pushNotificationReceived {
    
    DDLogVerbose(@"%s", __PRETTY_FUNCTION__);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // Only start the timer when we receive
        // a push while the app is backgrounded
        if([UIApplication sharedApplication].applicationState != UIApplicationStateBackground)
            return;
        
        [self activateBackgroundLogicForType:SCPTimerCallbackTypePushNotification];
    });
}

#pragma mark - API requests

- (NSURLSession *)constructURLSession {

    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    [configuration setTimeoutIntervalForRequest:HTTP_TIMEOUT];
    
    return [NSURLSession sessionWithConfiguration:configuration
                                         delegate:self
                                    delegateQueue:nil];
}

/**
 Returns the cached response if the request meets the criteria
 
 The criteria are:
 
 * The request endpoint URL must be one of the following:
    * /v1/user/
    * /v2/people/
    * /v2/contacts/validate/
 
 * The cached response Date header must not exceed the
 TTL set at the `CACHE_TTL` define. If the Date is older
 then the cached response is removed from the cache.
 
 @param request The NSURLRequest object to check against
 @return The cached response object if exists, nil otherwise
 */
- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request {
    
    if(!request)
        return nil;
    
    if(!request.URL)
        return nil;
    
    // Check if the request URL is allowed to be extracted from cache
    if(![_allowedCachedEndpoints containsObject:request.URL.path]) {
        
        // Check if it's a /v1/user/ request
        NSRange userResolutionRange = [request.URL.path rangeOfString:@"/v1/user/"];
        BOOL isUserResolutionRequest = (userResolutionRange.location != NSNotFound);

        if(!isUserResolutionRequest)
            return nil;
        else {
            
            // Do not allow the /v1/user/%@/device/ requests to be cached
            NSRange userDeviceRange = [request.URL.path rangeOfString:@"/device"];
            BOOL isUserDeviceRequest = (userDeviceRange.location != NSNotFound);
            
            if(isUserDeviceRequest)
                return nil;
        }
    }
    
    NSURLCache *sharedCache = [NSURLCache sharedURLCache];
    
    NSCachedURLResponse *cachedResponse = [sharedCache cachedResponseForRequest:request];

    if(cachedResponse) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)cachedResponse.response;
        
        if(httpResponse && httpResponse.allHeaderFields && httpResponse.allHeaderFields[@"Date"]) {
        
            NSString *dateString = httpResponse.allHeaderFields[@"Date"];
            NSDate *requestDate = [_cachedDateFormatter dateFromString:dateString];
            
            NSTimeInterval dateDifference = [[NSDate date] timeIntervalSinceDate:requestDate];
            
            // Remove cached request if it exceeds the TTL
            if(dateDifference > CACHE_TTL) {
                
                [sharedCache removeCachedResponseForRequest:request];
                return nil;
            }
        }
    }
    
    return cachedResponse;
}

- (NSString *)stringForMethod:(SCPNetworkManagerMethod)method {
    
    NSString *httpMethod = nil;
    
    switch(method) {
            
        case SCPNetworkManagerMethodGET:
            httpMethod = @"GET";
            break;
        case SCPNetworkManagerMethodPOST:
            httpMethod = @"POST";
            break;
        case SCPNetworkManagerMethodPUT:
            httpMethod = @"PUT";
            break;
        case SCPNetworkManagerMethodDELETE:
            httpMethod = @"DELETE";
            break;
        case SCPNetworkManagerMethodHEAD:
            httpMethod = @"HEAD";
            break;
        case SCPNetworkManagerMethodUnknown:
            httpMethod = nil;
    }
    
    return httpMethod;
}

- (void)checkForInvalidAPIKey:(id)responseObj {
 
    if(!responseObj)
        return;
    
    if(![responseObj isKindOfClass:[NSDictionary class]])
        return;
    
    if(![(NSDictionary *)responseObj safeStringForKey:@"error_id"])
        return;
    
    NSString *errorId = [(NSDictionary *)responseObj safeStringForKey:@"error_id"];
    
    // If the API states that the API key used is invalid
    // then proceed with the wipe countdown
    if([errorId isEqualToString:@"api-key-invalid"]) {
        
        HTTPLogWarn(@"%s api-key-invalid: BEGIN DATA WIPE COUNTDOWN", __PRETTY_FUNCTION__);
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCSUserDeviceWasRemovedNotification
                                                            object:self];
    }
}

- (NSURLRequest *)buildRequestForEndpoint:(NSString *)endpoint method:(SCPNetworkManagerMethod)method arguments:(id)arguments error:(NSError **)outError {
    
    NSRange apiKeyRange = [endpoint rangeOfString:@"api_key="];
    
    BOOL requiresAPI = (// If there the api_key= is found in the endpoint
                        (apiKeyRange.location != NSNotFound) &&
                        // and there is no api key already
                        (apiKeyRange.location + apiKeyRange.length == [endpoint length]));
    
    if(requiresAPI) {
        
        NSString *apiKey = [[ChatUtilities utilitiesInstance] apiKey];
        
        if (!apiKey || apiKey.length == 0) {
            
            HTTPLogError(@"%s No API key", __PRETTY_FUNCTION__);

            if(outError)
                *outError = [[NSError alloc] initWithDomain:SCPNetworkManagerErrorDomain
                                                       code:SCPNetworkManagerErrorCodeNoAPIKey
                                                   userInfo:nil];
            
            return nil;
        }
        
        endpoint = [endpoint stringByAppendingString:apiKey];
    }
    
    NSURL *urlPath = [ChatUtilities buildApiURLForPath:endpoint];
    
    if(!urlPath) {
        
        HTTPLogError(@"%s No URL path", __PRETTY_FUNCTION__);

        if(outError)
            *outError = [[NSError alloc] initWithDomain:SCPNetworkManagerErrorDomain
                                                   code:SCPNetworkManagerErrorCodeNoURL
                                               userInfo:nil];
        
        return nil;
    }
    
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:urlPath.absoluteString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:urlComponents.URL];
    
    NSString *methodString = [self stringForMethod:method];
    
    if(!methodString)
        return nil;
    
    [request setHTTPMethod:methodString];
    
    if(arguments) {

        NSData *requestData = nil;
        
        if([arguments isKindOfClass:[NSData class]])
            requestData = arguments;
        else if([NSJSONSerialization isValidJSONObject:arguments]) {
            
            NSError *serializationError = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:arguments
                                                               options:0
                                                                 error:&serializationError];
            
            if (serializationError) {
                
                HTTPLogError(@"%s Serialization Error", __PRETTY_FUNCTION__);

                if(outError)
                    *outError = serializationError;
                
                return nil;
            }
            
            requestData = jsonData;
        }

        [request setValue:@"application/json"
       forHTTPHeaderField:@"Accept"];
        
        [request setValue:@"application/json"
       forHTTPHeaderField:@"Content-Type"];
        
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[requestData length]]
       forHTTPHeaderField:@"Content-Length"];
        
        [request setHTTPBody:requestData];
    }

    return request;
}

- (id)synchronousApiRequestInEndpoint:(NSString *)endpoint method:(SCPNetworkManagerMethod)method arguments:(id)arguments error:(NSError **)outError httpResponse:(NSHTTPURLResponse **)httpResponse {
    
    HTTPLogDebug(@"%s: %@ %@", __PRETTY_FUNCTION__, [self stringForMethod:method], endpoint);

    NSError *requestError = nil;
    NSURLRequest *urlRequest = [self buildRequestForEndpoint:endpoint
                                                      method:method
                                                   arguments:arguments
                                                       error:&requestError];
    
    if(requestError) {
        
        if(outError)
            *outError = requestError;
        
        return nil;
    }
    
    // Check against cache
    NSCachedURLResponse *cachedURLResponse = [self cachedResponseForRequest:urlRequest];
    NSJSONSerialization *jsonSerialization = nil;
    
    if(cachedURLResponse && cachedURLResponse.data) {
        
        HTTPLogDebug(@"%s Using cached response for %@", __PRETTY_FUNCTION__, urlRequest.URL);
        
        NSError *serializationError = nil;
        jsonSerialization = [NSJSONSerialization JSONObjectWithData:cachedURLResponse.data
                                                            options:0
                                                              error:&serializationError];
        
        *outError = serializationError;
        *httpResponse = (NSHTTPURLResponse *)cachedURLResponse.response;

        if(serializationError)
            return cachedURLResponse.data;
        else
            return jsonSerialization;
    }
    
    return [self synchronousApiRequest:urlRequest
                                 error:outError
                              response:httpResponse];
}

- (id)synchronousApiRequest:(NSURLRequest *)request error:(NSError **)outError response:(NSHTTPURLResponse **)httpResponse {
    
    __block id responseObj = nil;
    __block NSError *blockError = nil;
    __block NSHTTPURLResponse *blockResponse = nil;
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [[_sharedSession dataTaskWithRequest:request
                       completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                    
                            NSHTTPURLResponse *localHttpResponse = (NSHTTPURLResponse *)response;

                            blockResponse = localHttpResponse;
                           
                            if(error) {
                                
                                HTTPLogError(@"%s Error: %@", __PRETTY_FUNCTION__, error);

                                blockError = error;
                                
                                dispatch_semaphore_signal(semaphore);
                                
                                return;
                            }
                             
                            NSError *serializationError = nil;
                            NSJSONSerialization *jsonSerialization = [NSJSONSerialization JSONObjectWithData:data
                                                                                                     options:0
                                                                                                       error:&serializationError];

                            if(serializationError) {
                             
                                HTTPLogError(@"%s Serialization error: %@", __PRETTY_FUNCTION__, error);

                                blockError = serializationError;

                                responseObj = data;
                            }
                            else
                                responseObj = jsonSerialization;

                            dispatch_semaphore_signal(semaphore);
                    
                       }] resume];
    
    long timeout = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(HTTP_TIMEOUT * NSEC_PER_SEC)));
    
    // If the request has been timed out, return an error code
    if(timeout > 0) {
        
        *outError = [NSError errorWithDomain:SCPNetworkManagerErrorDomain
                                        code:SCPNetworkManagerErrorCodeRequestTimedOut
                                    userInfo:nil];
        
        return nil;
    }
        
    if(outError)
        *outError = blockError;
    
    if(httpResponse)
        *httpResponse = blockResponse;
    
    if(!blockError)
        [self checkForInvalidAPIKey:responseObj];
    
    return responseObj;
}

- (NSURLSessionTask *)apiRequestInEndpoint:(NSString *)endpoint
                                    method:(SCPNetworkManagerMethod)method
                                 arguments:(id)arguments
                                completion:(void(^)(NSError *error, id responseObject, NSHTTPURLResponse * httpResponse))completion {
    
    return [self apiRequestInEndpoint:endpoint
                               method:method
                            arguments:arguments
                     useSharedSession:YES
                           completion:completion];
}

- (NSURLSessionTask *)apiRequestInEndpoint:(NSString *)endpoint
                                    method:(SCPNetworkManagerMethod)method
                                 arguments:(id)arguments
                          useSharedSession:(BOOL)useSharedSession
                                completion:(void(^)(NSError *error, id responseObject, NSHTTPURLResponse * httpResponse))completion {

    HTTPLogDebug(@"%s: %@ %@", __PRETTY_FUNCTION__, [self stringForMethod:method], endpoint);
    
    NSError *requestError = nil;
    NSURLRequest *urlRequest = [self buildRequestForEndpoint:endpoint
                                                      method:method
                                                   arguments:arguments
                                                       error:&requestError];
    
    if(requestError) {
        
        if(completion)
            completion(requestError, nil, nil);
        
        return nil;
    }
    
    // Check against cache
    NSCachedURLResponse *cachedURLResponse = [self cachedResponseForRequest:urlRequest];

    if(cachedURLResponse && cachedURLResponse.data) {
        
        HTTPLogDebug(@"%s Using cached response for %@", __PRETTY_FUNCTION__, urlRequest.URL);

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

            NSError *serializationError = nil;
            NSJSONSerialization *jsonSerialization = [NSJSONSerialization JSONObjectWithData:cachedURLResponse.data
                                                                                     options:0
                                                                                       error:&serializationError];
            
            if(serializationError)
                completion(serializationError, cachedURLResponse.data, (NSHTTPURLResponse *)cachedURLResponse.response);
            else
                completion(nil, jsonSerialization, (NSHTTPURLResponse *)cachedURLResponse.response);
        });
        
        return nil;
    }
    
    return [self apiRequest:urlRequest
           useSharedSession:useSharedSession
                 completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {
        
                     if(completion)
                         completion(error, responseObject, httpResponse);
                 }];
}

- (NSURLSessionTask *)apiRequest:(NSURLRequest *)request
                      completion:(void(^)(NSError * error, id responseObject, NSHTTPURLResponse *httpResponse))completion {

    return [self apiRequest:request
           useSharedSession:YES
                 completion:completion];
}

- (NSURLSessionTask *)apiRequest:(NSURLRequest *)request
                useSharedSession:(BOOL)useSharedSession
                      completion:(void(^)(NSError * error, id responseObject, NSHTTPURLResponse *httpResponse))completion {
    
    NSURLSession *session = _sharedSession;
    
    if(!useSharedSession)
        session = [self constructURLSession];
    
    __weak SCPNetworkManager *weakSelf = self;
    
    NSURLSessionTask *task = [session dataTaskWithRequest:request
                                        completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                            
                                            __strong SCPNetworkManager *strongSelf = weakSelf;
                                            
                                            if(!strongSelf)
                                                return;
                                            
                                            if(!completion)
                                                return;

                                            // Dispatch the results to another thread
                                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

                                                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                                
                                                if(error) {
                                                    
                                                    HTTPLogError(@"%s Error: %@", __PRETTY_FUNCTION__, error);

                                                    completion(error, nil, httpResponse);
                                                    return;
                                                }
                                                
                                                NSError *serializationError = nil;
                                                NSJSONSerialization *jsonSerialization = [NSJSONSerialization JSONObjectWithData:data
                                                                                                                         options:0
                                                                                                                           error:&serializationError];
                                                
                                                if(serializationError)
                                                    completion(serializationError, data, httpResponse);
                                                else {
                                                    
                                                    [strongSelf checkForInvalidAPIKey:jsonSerialization];
                                                    
                                                    completion(nil, jsonSerialization, httpResponse);
                                                }
                                            });
                                        }];
    
    [task resume];
    
    if(!useSharedSession)
        [session finishTasksAndInvalidate];
    
    return task;
}

+ (NSString *)prepareEndpoint:(NSString *)endpoint withUsername:(NSString *)username {
    
    username = [[ChatUtilities utilitiesInstance] removePeerInfo:username
                                                       lowerCase:NO];
    
    NSString *encodedUsername = [username stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
    
    return [NSString stringWithFormat:endpoint, encodedUsername];
}

/**
 We use this delegate method to check whether our requests
 are happening using HTTP/2 (note: they should).
 */
//- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics {
//    
//    for (NSURLSessionTaskTransactionMetrics *transactionMetric in metrics.transactionMetrics) {
//        
//        if(!transactionMetric.networkProtocolName)
//            continue;
//        
//        BOOL isHTTP2 = [transactionMetric.networkProtocolName isEqualToString:@"h2"];
//        
//        DDLogVerbose(@"%s > %@", __PRETTY_FUNCTION__, isHTTP2 ? @"HTTP/2! :)" : @"NON HTTP/2 :(");
//    }
//}

@end
