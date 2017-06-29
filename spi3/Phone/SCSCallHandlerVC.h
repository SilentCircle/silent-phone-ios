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
//  SCSCallHandlerVC.h
//  SPi3
//
//  Created by Eric Turner on 12/14/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * This class is an abstract class intented for abstracting 
 * implementations common to the several view controllers which handle
 * calls - currently, the dial pad, call screen, conference, and video
 * screen controllers.
 *
 * Note that the "call handler" view controllers should subclass this 
 * abstract superclass; this class is not itself intended for 
 * initialization.
 */
@interface SCSCallHandlerVC : UIViewController

/** This flag is set by SCSCallNavigationVC when transitioning between
 child view controllers. */
@property (nonatomic) BOOL isInTransition;

// These methods are intended to be invoked by the SCSCallNavigationVC
// container class which handles switching between call handler VCs.
// These methods are to be preferred over the UIViewControllerDelegate
// viewWillAppear: and viewWillDisappear: callbacks because of their
// unpredictability.
//
// There is no initial implementation in this abstract class but
// subclasses should call super when overriding in case these are
// implemented in this class in the future.
- (void)prepareToBecomeActive;
- (void)prepareToBecomeInactive;

@end
