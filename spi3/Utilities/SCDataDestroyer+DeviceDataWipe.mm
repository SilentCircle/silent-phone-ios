//
//  SCDataDestroyer+DeviceDataWipe.m
//  SPi3
//
//  Created by Gints Osis on 10/03/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SCDataDestroyer+DeviceDataWipe.h"
#import "SCPNetworkManager.h"
#include "interfaceApp/AppInterfaceImpl.h"
#import "axolotl_glue.h"
#import "SCPCallbackInterface.h"

using namespace zina;
@implementation SCDataDestroyer (DeviceDataWipe)
+(void)removeUserDeviceFromWebWithCompletion:(void (^)())completion
{
    // If there is not network just return
    if (![Switchboard allAccountsOnline])
    {
        completion();
        return;
    }

    NSString *deviceId = [Switchboard getCurrentDeviceId];
    NSString *endpoint = [NSString stringWithFormat:SCPNetworkManagerEndpointV1MeDevice, deviceId];
    
    [Switchboard.networkManager apiRequestInEndpoint:endpoint
                                              method:SCPNetworkManagerMethodDELETE
                                           arguments:nil
                                          completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {
                                              completion();
                                          }];
}
@end
