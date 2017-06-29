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
//  SCPDeviceManager.m
//  SCPSwitchboard
//
//  Created by Eric Turner on 5/26/15.
//  Based on original work by Janis Narbuts SP1
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SCPDeviceManager.h"
#import "SCPNotificationKeys.h"
#import "ChatUtilities.h"
#import "axolotl_glue.h"

#include "interfaceApp/AppInterfaceImpl.h"

using namespace std;
using namespace zina;

// t_a_main.cpp
int findIntByServKey(void *pEng, const char *key, int *ret);

@implementation SCPDeviceManager

- (instancetype)init {
    
    if(self = [super init]) {
        
        // Register for battery level and state change notifications.
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(batteryDidChange:)
                                                     name:UIDeviceBatteryLevelDidChangeNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(batteryDidChange:)
                                                     name:UIDeviceBatteryStateDidChangeNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(batteryDidChange:)
                                                     name:kSCSDidSaveConfigNotification object:nil];
        
        [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    }

    return self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Battery Methods

- (void)batteryDidChange:(NSNotification *)notification
{
    [self checkBattery];
}

-(void)checkBattery {
    
    if(_isShowingVideoScreen)
        return;
    
    UIDeviceBatteryState batteryState = [UIDevice currentDevice].batteryState;
    float batteryLevel = [UIDevice currentDevice].batteryLevel;
    
    BOOL on = NO;
    
    if(batteryState == UIDeviceBatteryStateFull ||
       batteryState == UIDeviceBatteryStateCharging) {
        
        if(batteryLevel >= .3)
            on = YES;
    }
    
    [[UIApplication sharedApplication] setIdleTimerDisabled: on && [SCPDeviceManager shouldKeepScreenOnWithBatteryCheck]];
}

+ (BOOL)shouldKeepScreenOnWithBatteryCheck {
    
    int iKeepScreenOnIfBatOk=0;
    const char *str = "iKeepScreenOnIfBatOk";
    findIntByServKey(NULL, str, &iKeepScreenOnIfBatOk);
    return iKeepScreenOnIfBatOk==1? YES : NO;
}

#pragma mark - Rescanning

+ (void)rescanLocalUserDevices {
    
    AppInterfaceImpl *app = (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
    string username = app->getOwnUser();
    app->rescanUserDevices(username);
}

+ (void)rescanDevicesForUserWithUUID:(NSString *)uuid {
    
    if(!uuid)
        return;
    
    uuid = [[ChatUtilities utilitiesInstance] removePeerInfo:uuid
                                                   lowerCase:NO];
    
    AppInterfaceImpl *app = (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
    string username(uuid.UTF8String);
    app->rescanUserDevices(username);
}


@end
