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
//  SCImageUtilities.swift
//  SPi3
//
//  Created by Eric Turner on 10/29/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//
//  Utility methods from Erica Sadun iOS Drawing: Practical UIKit Solutions
//  converted from Objective C to Swift by Eric Turner
//

import Foundation
import UIKit

@objc open class SCSImageUtilities: NSObject {
    
    //MARK: Utilities
    // [Sadun p. 96]
    func imageThumbnail(_ sourceImage: UIImage, targetSize: CGSize, useFitting: Bool) ->UIImage{
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        
        // Establish the output thumbnail rectangle
        let targetRect = rectWithSize(targetSize)
        
        // Create the source image's bounding rectangle
        let naturalRect = CGRect(origin: CGPoint.zero, size: sourceImage.size)
        
        // Calculate fitting or filling destination rectangle
        let destinationRect = useFitting ?
            rectByFittingInRect(naturalRect, destRect: targetRect) :
            rectByFillingInRect(naturalRect, destRect: targetRect)
        
        // Draw the new thumbnail
        sourceImage.draw(in: destinationRect)
        
        // Retrieve and return the new image
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return thumbnail!
    }
    
    func ringImage(_ size: CGSize, width: CGFloat, color: UIColor, save: Bool)->UIImage{
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        let path = UIBezierPath(ovalIn: rectWithSize(size).insetBy(dx: width, dy: width))
        path.lineWidth = width
        color.setStroke()
        path.stroke()
        let ringImg = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if save{
            if let data = UIImagePNGRepresentation(ringImg!){
                let filepath = getDocumentsPath().appendingPathComponent("newImage.png")
                    print("Path to saved image: \(filepath)")
                    try? data.write(to: URL(fileURLWithPath: filepath), options: [.atomic])
            }
        }
        
        return ringImg!
    }
    
    // This is a storage location for images produced by the ringImage() function
    // NOTE: this app NO LONGER USES DOCUMENTS DIRECTORY for any storage or access
    internal func getDocumentsPath()->NSString{
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
    }
    
    //MARK: Filling
    
    // [Sadun p. 90]
    // Calculate scale for filling a destination
//    func aspectMaxFillDimension(sourceSize sourceSize: CGSize, destRect: CGRect) -> CGFloat{
    func aspectScaleFill(_ sourceSize: CGSize, destRect: CGRect) ->CGFloat{
        let destSize = destRect.size
        let scaleW = destSize.width  / sourceSize.width
        let scaleH = destSize.height / sourceSize.height
        return max(scaleW, scaleH)
    }
    
    // [Sadun p. 90]
    // Return a rect that fills the destination
    func rectByFillingInRect(_ sourceRect: CGRect, destRect: CGRect) ->CGRect{
        let aspect = aspectScaleFill(sourceRect.size, destRect: destRect)
        let targetSize = sizeScaleByFactor(sourceRect.size, factor: aspect)
        return rectAroundCenter(rectGetCenter(destRect), size: targetSize)
    }
    
    
    //MARK: Fitting
    
    // [Sadun p. 88]
    // Calculate scale for fitting a size to a destination
//    func aspectMinFitDimension(sourceSize sourceSize: CGSize, destRect: CGRect) -> CGFloat{
    func aspectScaleFit(_ sourceSize: CGSize, destRect: CGRect) ->CGFloat{
        let destSize = destRect.size
        let scaleW = destSize.width / sourceSize.width
        let scaleH = destSize.height / sourceSize.height
        return min(scaleW, scaleH)
    }
    
    // [Sadun p. 88]
    // Return a rect fitting a source to a destination
    func rectByFittingInRect(_ sourceRect: CGRect, destRect: CGRect) ->CGRect{
        let aspect = aspectScaleFit(sourceRect.size, destRect: destRect)
        let targetSize = sizeScaleByFactor(sourceRect.size, factor: aspect)
        return rectAroundCenter(rectGetCenter(destRect), size: targetSize)
    }
    
    
    //MARK: Geometry Utilities
    
    // [Sadun p. 88]
    // Multiply size components by factor
//    func scaledSize(size: CGSize, factor: CGFloat) -> CGSize{
    func sizeScaleByFactor(_ size: CGSize, factor: CGFloat) ->CGSize{
        return CGSize(width: size.width * factor, height: size.height * factor)
    }
    
    // [Sadun p. 81]
    func rectAroundCenter(_ center: CGPoint, size: CGSize) ->CGRect{
        let halfW = size.width / 2.0
        let halfH = size.height / 2.0
        return CGRect(x: center.x - halfW, y: center.y - halfH, width: size.width, height: size.height)
    }
    
    // unused
    // [Sadun p. 83]
    func rectCenteredInRect(_ rect: CGRect, mainRect: CGRect) ->CGRect{
        let dx = mainRect.midX - rect.midX
        let dy = mainRect.midY - rect.midY
        return rect.offsetBy(dx: dx, dy: dy)
    }
    
    // [Sadun p. 81]
//    func centerPointInRect(rect: CGRect) -> CGPoint{
    func rectGetCenter(_ rect: CGRect) ->CGPoint{
        return CGPoint(x: rect.midX, y: rect.midY)
    }
    
    func rectWithSize(_ size: CGSize) ->CGRect{
        return CGRect(origin: CGPoint.zero, size: size)
    }

    
}
