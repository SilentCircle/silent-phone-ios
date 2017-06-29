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
//  SCProgressView.h
//  Silent Phone
//
//  Created by Eric Turner on 6/29/15.
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCProgressView : UIView

- (void)startAnimatingDots;

- (void)stopAnimatingDots;

- (void)successWithCompletion:(void (^)(void))completion;

- (void)setProgress:(CGFloat)progress;

- (void)resetProgress;

/**
 * 09/23/16
 * This method is required to be called before displaying. It wraps
 * calls to the layoutOuterView methods which simply set the corner 
 * radius to create a circular "outer" canvas view, and the 
 * layoutInnerView method which sets the corner radii of the "dot"
 * subviews to be circular.
 *
 * Previously, awakeFromNib did the initial configuration of the Core
 * Graphic layers but with iOS 10, the containing view heirarchy has not
 * resized its subviews when awakeFromNib is called. This results in a 
 * default size of 1000x1000 before subviews are laid out. 
 *
 * This was the case in Prov.mm, maybe related to the contentView being
 * a UIScrollView subview. The implementation of this method means that
 * Prov can defer the call here to configure the progress view until it
 * is needed, by which time, the view hierarchy is established.
 *
 * However, this means that where this class previously configured 
 * itself automatically when deserialized from a storyboard, now an 
 * explicit call to this method is required.
 */
- (void)configureInitialLayout;

// for testing
- (void)animateProgress;

@end
