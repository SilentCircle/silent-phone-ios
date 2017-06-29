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
//  SCSContactView.swift
//  SCImageView
//
//  Created by Eric Turner on 11/2/15.
//  Copyright © 2015 Eric Turner. All rights reserved.
//

import Foundation
import UIKit

/**
 * This class supports convenient use of masked circular Contact image.
 *
 * This class exposes a UIImageView property, "bgImgView", which will
 * display the contact image or default contact image, and a UILabel
 * property, "lbInitials", which will display the contact initials string.
 *
 * A convenience getter/setter for the "lbInitials" property is exposed
 * with the "initials" property.
 *
 * When an instance of this class is initialized with a frame, the
 * private setupBackgroundImageView() function is invoked to create the
 * "bgImgView" and
 * "lbInitials" property instances in code and lay them out in the self
 * containing view with AutoLayout constraints.
 *
 * When an instance of this class is deserialized from a xib/storyboard,
 * the awakeWithNib method calls the private setup methods to create
 * either or both of the "bgImgView" and "lbInitials" property instances
 * in code if they are found to be nil when deserialized. Property
 * instances created in code are laid out in the self containing view
 * with AutoLayout constraints.
 *
 * When the image property is initialized, a circular masking layer is
 * automatically applied to create the round contact image appearance.
 *
 * A UIImageView instance may be added to a xib/storyboard and connected
 * to the "bgImgView" outlet. At design time, an image added to the
 * bgImgView will not be masked in IB, but the circular mask will be
 * applied when the image property is set at runtime.
 *
 * Usage:
 *
 * The easiest design time case:
 * - add a UIView in a xib or storboard, size the view to the desired
 *   contact image size,
 * - set the class name to SCSContactView,
 *
 * The easiest runtime case using contact image:
 * - set the image property to the desired contact image.
 *
 * The easiest runtime case without a contact image:
 * - call the showDefaultContactImage method, then set "initials".
 * The "lbInitials" will be lazily initialized, pinned to center with
 * layout constraints, and font size calculated as a ratio of width.
 *
 * The "showDefaultContactImage" method displays the image named with
 * the "kEmptyContactImgName" constant. The "initials" setter
 * the initials had previously been hidden by setting the image property
 * the "lbInitials" label will be unhidden automatically.
 *
 * Note that the "lbInitials" label is lazily created and configured
 * by the "initials" property setter. If the "initials" setter is passed
 * a nil or empty String, the "lbInitials" label is removed.
 *
 * If it is desired that the initals are displayed over the contact
 * image, set the image first and then set the "initials" property with
 * a non-empty string.
 */
let kEmptyContactImgName = "EmptyContactPicture"
let kEmptyContactImgNameSmall = "EmptyContactPictureSmall"
let kNumberContactImgName = "NumberContactPicture"

let kDefaultContactViewInitialsFontName = "Arial"
let kDefaultContactViewInitialsFontColor = UIColor.white
let kVerifyLabelFontName = "Avenir-Heavy"
let kWhiteCircleOffsetFromProfilePicture = 8.0 //10.0

let kBackgroundColorArray = [UIColor] (arrayLiteral:
                                       UIColor(red: 248/255.0, green: 90/255.0, blue: 72/255.0, alpha: 1),
                                       UIColor(red: 145/255.0, green: 136/255.0, blue: 243/255.0, alpha: 1),
                                       UIColor(red: 62/255.0, green: 173/255.0, blue: 111/255.0, alpha: 1),
                                       UIColor(red: 164/255.0, green: 192/255.0, blue: 88/255.0, alpha: 1),
                                       UIColor(red: 91/255.0, green: 186/255.0, blue: 177/255.0, alpha: 1))

@objc class SCSContactView: UIView{
    
    @IBOutlet weak var bgImgView:  UIImageView?
    @IBOutlet weak var lbInitials: UILabel?
    @IBOutlet weak var lbVerify:   UILabel?
    
    //    private var _maskLayer: CALayer?
    var darkScreenLayer: CALayer?
    fileprivate var circleLayer: CAShapeLayer!
    var isShowingWhiteBorder:Bool = false
    
    fileprivate let utils = SCSImageUtilities()
    
    //MARK: Masked Image
    
    var image: UIImage?{
        get {
            return bgImgView?.image
        }
        set {
            
            removeLabel(&lbInitials)
            
            let showUnverified = (lbVerify != nil)
            removeDarkScreenLayer()
            removeLabel(&lbVerify)
            
            updateImage(newValue)
            
            if showUnverified{
                setupDarkScreenLayer()
                setupVerifyLabel()
            }
            
        }
    }
    
    fileprivate func updateImage(_ image: UIImage?){
        
        if nil == image{
            bgImgView?.image = nil;
            bgImgView?.accessibilityLabel = ""
            return
        }
        
        var img = image!
        
        if !bounds.size.equalTo(CGSize.zero) {
            
            if !bounds.size.equalTo(img.size){
                img = utils.imageThumbnail(img, targetSize: bounds.size, useFitting: false)
            }
        }
        
        bgImgView?.image = img
        bgImgView?.contentMode = .scaleAspectFit
        bgImgView?.backgroundColor = UIColor.clear
        bgImgView?.accessibilityLabel = "contact photo"
        bgImgView?.layer.masksToBounds = true;
    }
    
    //MARK: Initials
    
    var initials: String?{
        get{
            return lbInitials?.text
        }
        set{
            // Handle unverified
            let showUnverified = (lbVerify != nil)
            removeLabel(&lbVerify)
            removeDarkScreenLayer()
            
            if newValue == nil || newValue == "" {
                removeLabel(&lbInitials)
            } else if lbInitials == nil {
                setupInitialsLabel(newValue!)
            } else {
                lbInitials?.text = newValue!
            }
            
            if showUnverified{
                setupDarkScreenLayer()
                setupVerifyLabel()
            }
        }
    }
    
    func setupInitialsLabel(_ text: String){
        
        // The most appropriate ratio of the font size to the label
        // width is the meaning of life to 100
        // (assuming Arial font)
        let meaningOfLife = 0.42
        
        let lb = centeredLabel()
        lbInitials = lb
        
        let fontSize = lb.frame.width * CGFloat(meaningOfLife)
        let font = UIFont(name:kDefaultContactViewInitialsFontName, size:fontSize)
        lb.font = font
        lb.text = text
        lb.textColor = kDefaultContactViewInitialsFontColor
    }
    
    //MARK: Default Contact Image
    
    func showDefaultContactImage(){
       
        let txtInitials: String? = lbInitials?.text
        // (note that image setter currently calls to remove initials
        // label also. Leaving this call here in case the image setter
        // implmentation changes in the future.)
        removeLabel(&lbInitials)
        
        image = UIImage(named: (bounds.size.width == 50 ? kEmptyContactImgNameSmall : kEmptyContactImgName))
        
        if txtInitials != nil{
            setupInitialsLabel(txtInitials!)
        }
    }
    
    func showDefaultContactColorWithContactName(_ contactName: NSString){
                
        let  index:Int = abs( contactName.hash % kBackgroundColorArray.count);
        let txtInitials: String? = lbInitials?.text
        // (note that image setter currently calls to remove initials
        // label also. Leaving this call here in case the image setter
        // implmentation changes in the future.)
        removeLabel(&lbInitials)
        
        image = nil
        bgImgView?.image = nil
        bgImgView?.backgroundColor = kBackgroundColorArray[index] as UIColor
        
        if txtInitials != nil{
            setupInitialsLabel(txtInitials!)
        }
    }
    
    //MARK: Number Contact Image
    
    func showNumberContactImage(){
        removeLabel(&lbInitials)
        image = UIImage(named: kNumberContactImgName)
    }
    
    //MARK: White Circle Border
    
    func showWhiteBorder(){
        if (!isShowingWhiteBorder)
        {
            isShowingWhiteBorder = true
            setNeedsDisplay()
        }
    }
    
    func invalidateWhiteCircle() -> Void{
        if circleLayer != nil {
            circleLayer! .removeFromSuperlayer()
            circleLayer = nil
        }
    }
    
    override func draw(_ rect: CGRect) {
        if circleLayer == nil && isShowingWhiteBorder {
            circleLayer = CAShapeLayer()
            
            let bezierPath = UIBezierPath()
            
            // adds circle with empty space in the right side to fit the callScreenCircle.png images space
            bezierPath.addArc(withCenter: CGPoint(x: frame.size.width/2, y: frame.size.width/2), radius: frame.size.width/2 + CGFloat(kWhiteCircleOffsetFromProfilePicture), startAngle:-0.35, endAngle: CGFloat(Double.pi / 2)-1.25, clockwise: false)
            circleLayer!.path = bezierPath.cgPath
            circleLayer!.strokeColor = UIColor.white.cgColor
            circleLayer!.lineWidth = 3
            circleLayer!.fillColor = UIColor.clear.cgColor
            layer.addSublayer(circleLayer!)
        }
    }
    
    //MARK: Verified? - dark screen layer
    
    func showUnverified(_ show: Bool){
        showDarkLayer(show)
        
        if show {
            if lbVerify==nil{
                setupVerifyLabel()
            }
        } else {
            removeLabel(&lbVerify)
        }
    }
    
    func setupVerifyLabel(){
        let lb = centeredLabel()
        lbVerify = lb
        let font = UIFont(name: kVerifyLabelFontName,size: 18.0)!
        setLargestFont(lbVerify!, font: font, text: NSLocalizedString("Verify?", comment: ""))
        lbVerify?.textColor = UIColor.white
        lbVerify?.isAccessibilityElement = true
    }
    
    func showDarkLayer(_ show: Bool){
        if show {
            if let imgViewBounds = bgImgView?.bounds {
                if darkScreenLayer==nil || !imgViewBounds.equalTo(darkScreenLayer!.bounds){
                    removeDarkScreenLayer()
                    setupDarkScreenLayer()
                    setNeedsDisplay()
                }
            }
            darkScreenLayer?.backgroundColor = darkScreenCGColor()
        } else {
            removeDarkScreenLayer()
        }
    }
    
    fileprivate func setupDarkScreenLayer(){
        if let imgViewBounds = bgImgView?.bounds {
            let screenLayer = CALayer()
            screenLayer.frame = imgViewBounds
            screenLayer.backgroundColor = darkScreenCGColor()
            screenLayer.cornerRadius = imgViewBounds.height / 2;
            screenLayer.masksToBounds = true
            layer.addSublayer(screenLayer)
            darkScreenLayer = screenLayer
        }
    }
    
    fileprivate func removeDarkScreenLayer(){
        darkScreenLayer?.removeFromSuperlayer()
        darkScreenLayer = nil
    }
    
    fileprivate func darkScreenCGColor() -> CGColor {
        return UIColor.black.withAlphaComponent(0.75).cgColor
    }
    
    //MARK: Initializers
    
    override init(frame: CGRect){
        super.init(frame: frame)
        setupImageViews()
    }
    
    required init?(coder aDecoder: NSCoder){
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib(){
        
        super.awakeFromNib()
        
        setupImageViews()
    }
    
    //MARK: Setup
    
    fileprivate func setupImageViews(){
        
        self.layoutIfNeeded()
        
        // Set self bgColor to clear (side effect of this function)
        backgroundColor = UIColor.clear
        if (nil == bgImgView){
            setupBackgroundImageView()
            // Set default empty contact image
            showDefaultContactImage()
        }
    }
    
    fileprivate func setupBackgroundImageView(){
        let iv = UIImageView.init(frame: frame)
        iv.backgroundColor = UIColor.clear
        iv.contentMode = .scaleAspectFill
        insertSubview(iv, at: 0)
        setConstraintsOnView(iv)
        bgImgView = iv
    }
    
    func setConstraintsOnView(_ aView: UIView){
        let views = ["aView":aView]
        aView.translatesAutoresizingMaskIntoConstraints = false
        self.addConstraints(NSLayoutConstraint .constraints(withVisualFormat: "H:|[aView]|",
            options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views))
        self.addConstraints(NSLayoutConstraint .constraints(withVisualFormat: "V:|[aView]|",
            options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views))
    }
    
    //MARK: Utilities
    
    func centeredLabel() -> UILabel{
        
        let lb = UILabel(frame:bounds)
        
        addSubview(lb)
        lb.translatesAutoresizingMaskIntoConstraints = false
        
        // pin all sides
        let views = ["label":lb]
        self.addConstraints(NSLayoutConstraint .constraints(withVisualFormat: "H:|[label]|",
            options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views))
        self.addConstraints(NSLayoutConstraint .constraints(withVisualFormat: "V:|[label]|",
            options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views))
        
        self.layoutIfNeeded()
        
        lb.textAlignment = .center
        lb.adjustsFontSizeToFitWidth = true;
        lb.allowsDefaultTighteningForTruncation = true
        lb.baselineAdjustment = .alignCenters
        
        // We usually show the profile image alongside with the contact name
        // so there is no need for the VoiceOver to also speak the initials
        // (Reported by Frank)
        lb.accessibilityLabel = ""
        lb.accessibilityElementsHidden = false;
        
        return lb
    }
    
    func setLargestFont(_ label: UILabel, font: UIFont?, text: String){
        
        if font == nil || text == "" {
            return
        }
        
        var resFont = font! // result
        let lbSize = CGSize(width: label.frame.width, height: label.frame.height)
        var maxSize  = Int(300.0) // arbitrarily chosen max font (would it ever be bigger?)
        var minSize  = Int(8.0)   // arbitrarily chosen min font for readability
        let constraintSize = CGSize(width: lbSize.width, height: CGFloat.greatestFiniteMagnitude)
        let marginW = lbSize.width  * 0.85
        let marginH = lbSize.height * 0.85
        
        while(minSize <= maxSize){
            let fontSize = (minSize + maxSize) / 2
            resFont = font!.withSize( CGFloat(fontSize) )
            let txt = NSAttributedString(string: text, attributes: [NSFontAttributeName:resFont])
            let txtSize = txt.boundingRect(with: constraintSize, options: .usesLineFragmentOrigin, context: nil).size
            
            if txtSize.width < lbSize.width && txtSize.width >= marginW && txtSize.height < lbSize.height && txtSize.height >= marginH {
                break
            }else if txtSize.height > lbSize.height || txtSize.width > lbSize.width{
                maxSize = fontSize - 1
            }else{
                minSize = fontSize + 1
            }
        }
        
        label.font = resFont
        label.text = text
    }
    
    
    func removeLabel(_ label: inout UILabel?){
        if label == nil{
            return
        }
        label!.removeFromSuperview()
        label = nil
    }
    
}
