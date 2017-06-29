//
//  SystemPermissionManager.h
//  SPi3
//
//  Created by Ethan Arutunian on 4/20/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SystemPermissionManagerDelegate <NSObject>
@required
- (BOOL)hasPermission;
- (void)performPermissionCheck;
// NOTE: after the permission check is complete, delegate must call:
// [SystemPermissionManager permissionCheckComplete:self];
@end

typedef enum SystemPermissionType_e {
    SystemPermission_Microphone = 0
    ,SystemPermission_Notifications
    ,SystemPermission_Contacts
    ,SystemPermission_Siri
    ,kNumSystemPermissions
} SystemPermissionType;

@interface SystemPermissionManager : NSObject

+ (void)startPermissionsCheck;
+ (BOOL)hasPermission:(SystemPermissionType)permissionType;

+ (void)permissionCheckComplete:(NSObject <SystemPermissionManagerDelegate> *)delegate;

@end
