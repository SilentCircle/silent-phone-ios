//
//  DBManager+DeviceList.m
//  SPi3
//
//  Created by Gints Osis on 11/05/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "DBManager+DeviceList.h"
#import "axolotl_glue.h"
#import "SCPCallbackInterface.h"

#include "interfaceApp/AppInterfaceImpl.h"

using namespace std;
using namespace zina;

@implementation DBManager (DeviceList)

+(NSArray *)deviceListForDisplayUUID:(NSString *)uuid
{
    AppInterfaceImpl *app = (AppInterfaceImpl*)CTAxoInterfaceBase::sharedInstance()->getAxoAppInterface();
    string un(uuid.UTF8String);
    shared_ptr<list<string> > listPeer = app->getIdentityKeys(un);
    
    if (listPeer->empty())
    {
        [Switchboard rescanDevicesForUserWithUUID:uuid];

        listPeer = app->getIdentityKeys(un);

        if (listPeer->empty())
        {
            return @[];
        }
    }
    NSMutableArray *deviceArray = [[NSMutableArray alloc] init];
    while (!listPeer->empty())
    {
        
        std::string resultStr = listPeer->front();
        NSString *deviceString = [NSString stringWithUTF8String:resultStr.c_str()];
        NSArray *deviceInfoArray = [deviceString componentsSeparatedByString:@":"];
        [deviceArray addObject:deviceInfoArray];
        listPeer->erase(listPeer->begin());
    }
    return [NSArray arrayWithArray:deviceArray];
}
@end
