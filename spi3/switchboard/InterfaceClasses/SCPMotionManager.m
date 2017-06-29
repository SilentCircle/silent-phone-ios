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
//  SCPMotionManager.m
//  SP3
//
//  Created by Eric Turner on 5/25/15.
//  Based on original work by Janis Narbuts SP1
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SCPMotionManager.h"
#import "SCPNotificationKeys.h"

@interface SCPMotionManager ()
@property (assign, nonatomic) BOOL _proximityIsNear;
@end

@implementation SCPMotionManager

- (instancetype)init
{
    NSString *ns = [[UIDevice currentDevice] model];
    
    //if !iPod_Touch return
    if (!ns || ![ns isEqualToString:@"iPod touch"]) { 
        return nil;
    }
    
    self = [super init];
    return self;
}

- (void)start {
    
//    __weak typeof (self) weakSelf = self;
//    //accelerometerActive    
//    [self setDeviceMotionUpdateInterval:0.5f];
//    [self startAccelerometerUpdatesToQueue:[[NSOperationQueue alloc] init]
//                                        withHandler:^(CMAccelerometerData *data, NSError *error) {
//                                            dispatch_async(dispatch_get_main_queue(), ^{
//                                                
//                                                __strong typeof (weakSelf) strongSelf = weakSelf;
//                                                
//                                                //i want positive
//                                                float angle = atan2(data.acceleration.y, data.acceleration.x)+3.1416f;
//                                                float z=data.acceleration.z;
//
//                                                 NSString *ns = [NSString stringWithFormat:@"angle=%.2f %.1f %.1f %.1f",
//                                                                 angle, data.acceleration.x, data.acceleration.y, z ];
//                                                strongSelf.currentDataLog = ns;
//
//                                                int on=angle>3.7f && angle<5.7f && z<.5f && z>-.5f;
//                                                int off=(angle>.8 && angle<2.2) || (z>.85f || z<-.85f); //pi/2 +-pi/4
//                                                
//                                                if (on) {
//                                                    strongSelf._proximityIsNear = YES;
//                                                }
//                                                else if (off) {
//                                                    strongSelf._proximityIsNear = NO;
//                                                }
//                                                
//                                                [strongSelf postNotice];
//                                            });
//                                        }
//     ];

    //accelerometerActive    
    [self setDeviceMotionUpdateInterval:0.5f];
    [self startAccelerometerUpdatesToQueue:[[NSOperationQueue alloc] init]
                               withHandler:^(CMAccelerometerData *data, NSError *error) {
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       
                                       //i want positive
                                       float angle = atan2(data.acceleration.y, data.acceleration.x)+3.1416f;
                                       float z=data.acceleration.z;
                                       
                                       NSString *ns = [NSString stringWithFormat:@"angle=%.2f %.1f %.1f %.1f",
                                                       angle, data.acceleration.x, data.acceleration.y, z ];
                                       self.currentDataLog = ns;
                                       
                                       int on=angle>3.7f && angle<5.7f && z<.5f && z>-.5f;
                                       int off=(angle>.8 && angle<2.2) || (z>.85f || z<-.85f); //pi/2 +-pi/4
                                       
                                       if (on) {
                                           self._proximityIsNear = YES;
                                           [self postNotice];
                                       }
                                       else if (off) {
                                           self._proximityIsNear = NO;
                                           [self postNotice];
                                       }
                                       
                                   });
                               }
     ];
}

- (void)postNotice {
    [[NSNotificationCenter defaultCenter] postNotificationName: kSCPDeviceAngleDidChangeNotification object: self];
}

- (void)stop {
    [self stopAccelerometerUpdates];
}

- (BOOL)isOn {
    return self._proximityIsNear;
}


@end
