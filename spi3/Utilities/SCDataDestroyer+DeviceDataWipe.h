//
//  SCDataDestroyer+DeviceDataWipe.h
//  SPi3
//
//  Created by Gints Osis on 10/03/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCDataDestroyer.h"

@interface SCDataDestroyer (DeviceDataWipe)
/*
 Category to remove device from accounts device list before wiping all local device data
 This function get's own deviceId and calls SCPNetworkManagerEndpointV1MeDevice network request with delete method and posts completion when done reguardless of result.
 */
+(void) removeUserDeviceFromWebWithCompletion:(void (^)())completion;
@end
