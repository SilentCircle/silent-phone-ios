//
//  SCUISideMenuNavigationExtensions.swift
//  SPi3
//
//  Created by Eric Turner on 3/15/17.
//  Copyright © 2017 Silent Circle. All rights reserved.
//

import Foundation

extension UISideMenuNavigationController {
        
    //MARK: Accessibility
    /**
     * Implements VoiceOver support for dismissal of self 
     * UISideMenuNavigationController by the self 
     * presenting view controller.
     *
     * Note: only supported case is (3-finger) swipe left
     */
    override open func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        if (direction == .right) {             
//            print("UISideMenuNavigationController extension -- Accessibility swipe right")            
        } else if (direction == .left) {
//            print("UISideMenuNavigationController extension -- Accessibility swipe left")
            
            self.presentingViewController?.dismiss(animated: true, completion: nil)
            
        } else if (direction == .next) {             
//            print("UISideMenuNavigationController extension -- Accessibility swipe next")             
        } else if (direction == .previous) {
//            print("UISideMenuNavigationController extension -- Accessibility swipe previous")   
        }
        return true;
    }

}
