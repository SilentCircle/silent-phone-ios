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
//  SCSAutoLayout.m
//  SP3
//
//  Created by Eric Turner on 7/15/15.
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCSAutoLayout.h"

@implementation SCSAutoLayout


/**
 * This utility method returns a "single attribute", i.e., width or
 * height, NSLayoutConstraint for the given attrib argument, in the
 * given searchItems constraint array.
 *
 * @param attrib NSLayoutAttributeWidth or NSLayoutAttributeHeight;
 *               calling this method with any other NSLayoutAttribute is
 *               undefined.
 *
 * @param sView The view object for which to find a constraint.
 *
 * @return The constraint for the given attribute, or nil if not found.
 */
+ (NSLayoutConstraint *)constraintForAttribute:(NSLayoutAttribute)attrib searchItem:(UIView *)sView {
    for (NSLayoutConstraint *constraint in sView.constraints) {        
        if (constraint.firstItem == sView && constraint.firstAttribute == attrib) {
            return constraint;
        }
    }    
    return nil;
}

/**
 * This utility method returns a "center" NSLayoutConstraint for the 
 * given attrib argument, if found in the given sView argument's
 * superview constraints.
 *
 * @param attrib NSLayoutAttributeCenterX or NSLayoutAttributeCenterY; 
 *               calling this method with any other NSLayoutAttribute 
 *               is undefined.
 *
 * @param sView The view object for which to find a constraint.
 */
+ (NSLayoutConstraint *)centerAttribute:(NSLayoutAttribute)attrib searchItem:(UIView *)sView {
    for (NSLayoutConstraint *constraint in sView.superview.constraints) {
        if ((constraint.firstItem == sView && constraint.firstAttribute == attrib) ||
            (constraint.secondItem == sView && constraint.secondAttribute == attrib))
        {
            return constraint;
        }
    }    
    return nil;
}

// Returns a constraint with attribute matching the given attrib arg
// with relationship to the given searchItem's superview.
// Examples: NSLayoutAttributeTop, NSLayoutAttributeLeading
+ (NSLayoutConstraint *)constraintInSuperviewForAttribute:(NSLayoutAttribute)attrib searchItem:(UIView *)sView {
    for (NSLayoutConstraint *constraint in sView.superview.constraints) {
        if ((constraint.firstItem == sView && constraint.firstAttribute == attrib) ||
            (constraint.secondItem == sView && constraint.secondAttribute == attrib))
        {
            return constraint;
        }
    }
    return nil;
}


@end
