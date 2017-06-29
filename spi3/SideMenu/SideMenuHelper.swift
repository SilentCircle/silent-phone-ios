//
//  SideMenuHelper.swift
//
//  Created by Eric Turner on 02/08/17
//  Copyright © 2017 Silent Circle, Inc. All rights reserved.
//


import UIKit

@objc open class SideMenuHelper: NSObject {

    // The navCon passed here is the "root" navCon, nested in the container view
    @objc public class func setupSideMenu(_ navCon: UINavigationController) -> [AnyObject] {
        // Define the menus
        let sb = UIStoryboard.init(name: "Main", bundle: nil)
        let menuNav = sb.instantiateViewController(withIdentifier: "LeftMenuNavigationController") as! UISideMenuNavigationController
        // Set up only left side menu
        SideMenuManager.menuLeftNavigationController = menuNav
        SideMenuManager.menuLeftNavigationController?.leftSide = true 
        SideMenuManager.menuPresentMode = .menuSlideIn
        
        //NOTE: the gestures must be ordered in the return array:
        // - pan gesture
        // - screenEdge gesture
        var grs = [AnyObject]()
        
        // The menuPanGesture presents SideMenu by swiping right across navCon.navbar        
        grs.append( SideMenuManager.menuAddPanGestureToPresent(toView: navCon.navigationBar) )
        // The screenEdge gesture presents SideMenu by swiping right from left screen edge
        grs.append( SideMenuManager.menuAddScreenEdgePanGesturesToPresent(toView: navCon.view, forMenu: .left).first as AnyObject )

        // menuAnimationBackgroundColor fades in statusBar color - in our
        // case it should be clearColor so that side menu appears to 
        // overlay entire main vc.
        SideMenuManager.menuAnimationBackgroundColor = UIColor.clear
        
        return grs
    }
    
    @objc public class func sideMenuNavCon()  -> UISideMenuNavigationController {
        return SideMenuManager.menuLeftNavigationController!
    }
}
