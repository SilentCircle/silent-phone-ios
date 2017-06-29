//
//  SystemPermissionManager.m
//  SPi3
//
//  Created by Ethan Arutunian on 4/20/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

#import "SystemPermissionManager.h"

#import "SCSAudioManager.h"
#import "SCSContactsManager.h"
#import "SCPCallbackInterface.h"
#import "SCPNotificationKeys.h"

#import <Intents/Intents.h>     // Siri permission check is here

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

static SystemPermissionManager *_permissionManager;

@interface SiriPermissionDelegate : NSObject <SystemPermissionManagerDelegate>
@end

@implementation SystemPermissionManager {
    NSMutableArray *_delegateList;
    NSObject <SystemPermissionManagerDelegate> *_delegateMap[kNumSystemPermissions];
    NSObject <SystemPermissionManagerDelegate> *_pendingDelegate;
}

+ (SystemPermissionManager *)manager
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _permissionManager = [self new];
    });
    return _permissionManager;
}

- (id)init {
    if ((self = [super init]) != nil) {
        for (int i=0; i<kNumSystemPermissions; i++)
            _delegateMap[i] = nil;
    }
    return self;
}

+ (void)startPermissionsCheck {
    [[SystemPermissionManager manager] startPermissionsCheck];
}

- (void)startPermissionsCheck {
    if (_pendingDelegate != nil) {
        DDLogError(@"Invalid permission request - already started");
        return;
    }

    _delegateList = [[NSMutableArray alloc] initWithCapacity:5];
    [self _addDelegate:SPAudioManager forType:SystemPermission_Microphone];
    [self _addDelegate:[SCSContactsManager sharedManager] forType:SystemPermission_Contacts];
    [self _addDelegate:Switchboard.notificationsManager forType:SystemPermission_Notifications];
    [self _addDelegate:[[SiriPermissionDelegate alloc] init] forType:SystemPermission_Siri];
    
    _pendingDelegate = [_delegateList firstObject];
    dispatch_async(dispatch_get_main_queue(), ^{
        [_pendingDelegate performSelector:@selector(performPermissionCheck)];
    });
}

- (void)_addDelegate:(NSObject <SystemPermissionManagerDelegate> *)delegate forType:(SystemPermissionType)permissionType {
    [_delegateList addObject:delegate];
    _delegateMap[permissionType] = delegate;
}

+ (BOOL)hasPermission:(SystemPermissionType)permissionType {
    return [[SystemPermissionManager manager] hasPermission:permissionType];
}

- (BOOL)hasPermission:(SystemPermissionType)permissionType {
    if (!_delegateMap[permissionType])
        return NO;
    
    return [_delegateMap[permissionType] hasPermission];
}

+ (void)permissionCheckComplete:(NSObject <SystemPermissionManagerDelegate> *)delegate {
    return [[SystemPermissionManager manager] permissionCheckComplete:delegate];
}

- (void)permissionCheckComplete:(NSObject <SystemPermissionManagerDelegate> *)delegate {
    if (delegate != _pendingDelegate) {
        DDLogError(@"Invalid permission check");
        return;
    }

    // lookup the permission type for this delegate
    int type = -1;
    for (int t=0; t<kNumSystemPermissions; t++) {
        if (_delegateMap[t] == delegate) {
            type = t;
            break;
        }
    }
    if (type < 0) {
        DDLogError(@"Invalid permission check delegate");
        return;
    }
    
    // send out a notification
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // NOTE: this must run in a separate thread otherwise calls to hasPermission may block
        NSDictionary *notifyDict = @{@"type": [NSNumber numberWithInt:type]
                                     ,@"granted": [NSNumber numberWithBool:[delegate hasPermission]]};

        [[NSNotificationCenter defaultCenter] postNotificationName:PermissionChangedNotification object:self userInfo:notifyDict];
    });

    NSUInteger idx = [_delegateList indexOfObject:delegate];
    if (++idx >= [_delegateList count]) {
        _pendingDelegate = nil;
        return;
    }
    
    _pendingDelegate = [_delegateList objectAtIndex:idx];

    [_pendingDelegate performSelector:@selector(performPermissionCheck)];
}

@end

@implementation SiriPermissionDelegate

- (void)performPermissionCheck {
    if ([INPreferences class]) {
        INSiriAuthorizationStatus permission = [INPreferences siriAuthorizationStatus];
        if (permission == INSiriAuthorizationStatusNotDetermined) {
            [INPreferences requestSiriAuthorization:^(INSiriAuthorizationStatus status) {
                [SystemPermissionManager permissionCheckComplete:self];
            }];
        } else
            [SystemPermissionManager permissionCheckComplete:self];
    } else
        [SystemPermissionManager permissionCheckComplete:self];
}

- (BOOL)hasPermission {
    if (![INPreferences class])
        return NO;
    
    return ([INPreferences siriAuthorizationStatus] == INSiriAuthorizationStatusAuthorized);
}

@end
