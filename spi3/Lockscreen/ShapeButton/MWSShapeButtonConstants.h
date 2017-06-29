/*
Copyright (C) 2014-2017, Silent Circle, LLC.  All rights reserved.

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
//  SCShapeButtonConstants.h
//
//  Created by Eric Turner on 7/1/14.
//  Copyright (c) 2014 MagicWave Software LLC. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - MWSShapeButtonConstants Constants

extern NSString * const MWS_ShapeButton_fillColor;
extern NSString * const MWS_ShapeButton_highlightColor;
extern NSString * const MWS_ShapeButton_strokeColor;
extern NSString * const MWS_ShapeButton_subTitleColor;
extern NSString * const MWS_ShapeButton_titleColor;

// Non-color properties
extern NSString * const MWS_ShapeButton_cornerRadius;
extern NSString * const MWS_ShapeButton_isCircleShape;
extern NSString * const MWS_ShapeButton_shapePath;
extern NSString * const MWS_ShapeButton_strokeWidth;
extern NSString * const MWS_ShapeButton_subTitleText;
extern NSString * const MWS_ShapeButton_titleText;
extern NSString * const MWS_ShapeButton_useHighlightAnimation;

#define MWS_DEFAULT_SHAPEBUTTON_CORNER_RADIUS       0
#define MWS_DEFAULT_SHAPEBUTTON_STROKE_WIDTH        2
#define MWS_DEFAULT_SHAPEBUTTON_STROKE_COLOR        self.superview.tintColor
#define MWS_DEFAULT_SHAPEBUTTON_FILL_COLOR          [UIColor clearColor]
#define MWS_DEFAULT_SHAPEBUTTON_HIGHLIGHT_COLOR     MWS_DEFAULT_STROKE_COLOR // default: highlight same as stroke
extern NSTimeInterval const MWS_SHAPE_BUTTON_ANIMATION_DURATION;

@interface MWSShapeButtonConstants : NSObject
@end
