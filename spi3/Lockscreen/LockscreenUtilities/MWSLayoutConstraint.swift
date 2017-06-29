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
//  MWSLayoutConstraint.swift
//  LockScreenDemo
//
//  Created by Eric Turner on 7/6/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//
//  by Andrew Schreiber
//  http://stackoverflow.com/questions/19593641/can-i-change-multiplier-property-for-nslayoutconstraint
//  modified per tzaloga comments

//  Note: as explained by Matt, deactivating/activating the constraint actually
//

import UIKit

extension NSLayoutConstraint {
    
@discardableResult func updateMultiplier(_ multiplier:CGFloat) -> NSLayoutConstraint {
        
        NSLayoutConstraint.deactivate([self])
        
        let newConstraint = NSLayoutConstraint(
            item: firstItem,
            attribute: firstAttribute,
            relatedBy: relation,
            toItem: secondItem,
            attribute: secondAttribute,
            multiplier: multiplier,
            constant: constant)
        
        newConstraint.priority = priority
        newConstraint.shouldBeArchived = self.shouldBeArchived
        newConstraint.identifier = self.identifier      

        NSLayoutConstraint.activate([newConstraint])
        
        return newConstraint
    }

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
//    public class func constraintForAttribute(attrib:NSLayoutAttribute, view:UIView) -> NSLayoutConstraint? {            
//        if let i = view.constraints.indexOf({$0.firstItem as! NSObject == view && $0.firstAttribute == attrib}) {
//            return view.constraints[i]
//        }
//        return nil
//    }

}
