//
//  SCPAppDelegateInterface.h
//  SCPSwitchboard
//
//  Created by Eric Turner on 5/24/15.
//  Based on original work by Janis Narbuts SP1
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol SCPAppDelegateInterface <NSObject>

@required
// SCP
- (UIApplication *)sharedApplication;

@optional

@end
