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

#import <CoreLocation/CoreLocation.h>

#import "LocationManager.h"

#import "ChatUtilities.h"
#import "RecentObject.h"

#import "SCPNotificationKeys.h"

@interface LocationManager () <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;

@end

@implementation LocationManager

+(LocationManager *)sharedManager
{
    static dispatch_once_t once;
    static LocationManager *locationManagerInstance;
    
    dispatch_once(&once, ^{
        
        locationManagerInstance = [[self alloc] init];
        locationManagerInstance.locationManager = [CLLocationManager new];
        locationManagerInstance.locationManager.delegate = locationManagerInstance;
        locationManagerInstance.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        locationManagerInstance.locationManager.distanceFilter = 1000;
        
        [[NSNotificationCenter defaultCenter] addObserver: locationManagerInstance
                                                 selector: @selector(handleWillEnterForegroundNotification:)
                                                     name: UIApplicationWillEnterForegroundNotification
                                                   object: nil];
        
        [[NSNotificationCenter defaultCenter] addObserver: locationManagerInstance
                                                 selector: @selector(handleDidEnterBackgroundNotification:)
                                                     name: UIApplicationDidEnterBackgroundNotification
                                                   object: nil];
    });
    
    return locationManagerInstance;
}

#pragma mark - Notifications

- (void)handleWillEnterForegroundNotification:(NSNotification*)notification
{
    if([ChatUtilities utilitiesInstance].selectedRecentObject && [ChatUtilities utilitiesInstance].selectedRecentObject.shareLocationTime > time(NULL))
    {
        [_locationManager startUpdatingLocation];
    }
}

- (void)handleDidEnterBackgroundNotification:(NSNotification*)notification
{
    [_locationManager stopUpdatingLocation];
}

#pragma mark - CLLocationManagerDelegate

/**
 * When location detected, stop updating
 * updating restarts when user opens chat or opens application
 **/
-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    [ChatUtilities utilitiesInstance].userLocation = [locations lastObject];
    
    // if location sending time has run out, stop monitoring
    if([ChatUtilities utilitiesInstance].selectedRecentObject.shareLocationTime < time(NULL))
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_locationManager stopUpdatingLocation];
            [_locationManager stopMonitoringSignificantLocationChanges];
        });
    }
}
/*
-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if(status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted)
        [self promptForEnablingLocationFromSettings];
    else if(status == kCLAuthorizationStatusAuthorizedWhenInUse)
        [self startUpdatingLocation];
}*/

#pragma mark - Public API

-(void)startUpdatingLocation
{
    if([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined)
    {
       // [self requestLocationPermission];
        return;
    }
    
    [_locationManager startUpdatingLocation];
}

-(void)stopUpdatingLocation
{
    if([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined)
        return;
    
    [_locationManager stopMonitoringSignificantLocationChanges];
    [_locationManager stopUpdatingLocation];    
}

-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse)
    {
        [self startUpdatingLocation];
    } else
    {
        [self stopUpdatingLocation];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kdidChangeLocationStatus object:self];
}

#pragma mark - Private API

-(void)requestLocationPermission
{
    CLAuthorizationStatus locStatus = [CLLocationManager authorizationStatus];
    
    if(locStatus == kCLAuthorizationStatusDenied || locStatus == kCLAuthorizationStatusRestricted
    || locStatus == kCLAuthorizationStatusNotDetermined)
        [self.locationManager requestWhenInUseAuthorization];
}
/*
-(void)promptForEnablingLocationFromSettings
{
    [[ChatUtilities utilitiesInstance] askPermissionForSettingWithName:@"Location"];
}*/

@end
