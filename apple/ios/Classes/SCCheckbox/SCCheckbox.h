/*
Copyright (C) 2015, Silent Circle, LLC.  All rights reserved.

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

#import <UIKit/UIKit.h>

/**
 * Simple checkbox control toggles checkmark image on touch down.
 *
 * The layout of the control and private ivar subviews, 
 * _boundingBox and _imageView, are laid out in IB with AutoLayout.
 * The _imageView container of the checkmark image should be positioned
 * to overlay the _boundingBox. The control may oversized to expose a
 * bigger tap target.
 * 
 * The control sets its private _boundingBox layer border with a width
 * of 2.0, and the borderColor is initially set white with 0.75 alpha. 
 *
 * The control adds itself and a handler method as a target/action pair
 * of itself, and adds/removes the _imageView checkmark image to toggle 
 * the checked and unchecked appearance on touch down. The isChecked
 * getter is true when the _imageView is not nil.
 *
 * Consumers of this control should add a target/action pair.
 *
 * The image is a private property, set to mask to the self view
 * tint color. The self tintColor setter is overridden to additionally
 * set the _boundingBox borderColor to the given tintColor.
 */
@interface SCCheckbox : UIControl

/**
 * Returns YES if checkmark image is not nil, NO otherwise.
 */
@property (assign, readonly) BOOL isChecked;

/**
 * If checkmark image is not nil, sets image to nil; otherwise, 
 * initializes checkmark image.
 */
- (void)toggleCheckmark;

@end
