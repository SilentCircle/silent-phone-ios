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
//  Devices.swift
//  LockScreenDemo
//
//  Created by Eric Turner on 7/6/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//
//  Inspired by Beslan Tularov, 
//  http://stackoverflow.com/questions/24059327/detect-current-device-with-ui-user-interface-idiom-in-swift
//

import UIKit

enum UIUserInterfaceIdiom : Int
{
    case unspecified
    case phone
    case pad
}

struct ScreenSize
{
    static let SCREEN_WIDTH         = UIScreen.main.bounds.size.width
    static let SCREEN_HEIGHT        = UIScreen.main.bounds.size.height
    static let SCREEN_MAX_LENGTH    = max(ScreenSize.SCREEN_WIDTH, ScreenSize.SCREEN_HEIGHT)
    static let SCREEN_MIN_LENGTH    = min(ScreenSize.SCREEN_WIDTH, ScreenSize.SCREEN_HEIGHT)
}

struct DeviceType
{
    static let IS_IPHONE_4_OR_LESS  = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH  <  568.0
    static let IS_IPHONE_5          = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH ==  568.0
    static let IS_IPHONE_6_7        = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH ==  667.0
    static let IS_IPHONE_6_7P       = UIDevice.current.userInterfaceIdiom == .phone && ScreenSize.SCREEN_MAX_LENGTH ==  736.0
    static let IS_IPAD              = UIDevice.current.userInterfaceIdiom == .pad   && ScreenSize.SCREEN_MAX_LENGTH == 1024.0
    static let IS_IPAD_PRO          = UIDevice.current.userInterfaceIdiom == .pad   && ScreenSize.SCREEN_MAX_LENGTH == 1366.0
}



//MARK: Objective C class use
@objc public enum MWSDeviceType : UInt {
    case mwsDeviceUnknown,
     mwSiPhone_4_or_less,
     mwSiPhone_5,
     mwSiPhone_6_7,
     mwSiPhone_6_7P,
     mwSiPhone_iPad,
     mwSiPhone_iPadPro
};

@objc class MWSDevice : NSObject {

    override init() {
        super.init()
    }
    
    var type: MWSDeviceType {
        get {
            if (DeviceType.IS_IPHONE_4_OR_LESS) {
                return MWSDeviceType.mwSiPhone_4_or_less
            } else if (DeviceType.IS_IPHONE_5) {
                return MWSDeviceType.mwSiPhone_5
            } else if (DeviceType.IS_IPHONE_6_7) {
                return MWSDeviceType.mwSiPhone_6_7
            } else if (DeviceType.IS_IPHONE_6_7P) {
                return MWSDeviceType.mwSiPhone_6_7P
            } else if (DeviceType.IS_IPAD) {
                return MWSDeviceType.mwSiPhone_iPad
            } else if (DeviceType.IS_IPAD_PRO) {
                return MWSDeviceType.mwSiPhone_iPadPro
            }            
            return MWSDeviceType.mwsDeviceUnknown
        }
    }
        
    override var description: String {
        get {
            var str: String = ""
            
            switch self.type {
            case .mwSiPhone_4_or_less:
                str = "iPhone 4 or less"
            case .mwSiPhone_5:
                str = "iPhone 5"
            case .mwSiPhone_6_7:
                str = "iPhone 6/7"
            case .mwSiPhone_6_7P:
                str = "iPhone 6/7 Plus"
            case .mwSiPhone_iPad:
                str = "iPad"
            case .mwSiPhone_iPadPro:
                str = "iPad Pro"
            default:
                str = "Unknown device"
            }
            
            return str + "\n\(super.description)" 
        }
    }
    
    class func deviceType() -> MWSDeviceType {
        return MWSDevice().type
    }
}
