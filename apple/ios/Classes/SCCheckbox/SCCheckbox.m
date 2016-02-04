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

#import "SCCheckbox.h"

static CGFloat const kBoundingBoxBorderWidth = 2.0;
//#define kDefaultTintColor [UIColor colorWithWhite:1.0 alpha:0.75] 
#define kDefaultTintColor [UIColor colorWithRed:246.0/255.0 green:243.0/255.0 blue:235.0/255.0 alpha:1.0]
#define kBaseCheckImage [UIImage imageNamed:@"checkmark_512x512.png"]

@interface SCCheckbox ()
@property (strong, nonatomic) UIImage *checkImage;
@end

@implementation SCCheckbox
{
    IBOutlet UIView *_boundingBox;
    IBOutlet UIImageView *_imageView;
    UIImage *_imgCheckmark;
}

- (void)awakeFromNib {
    // clear any IB imageView image to make checkbox unchecked
    _imageView.image = nil;
    _imgCheckmark = [kBaseCheckImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    // clear any boundingBox IB color and set borderWidth
    _boundingBox.backgroundColor = [UIColor clearColor];
    _boundingBox.layer.borderWidth = kBoundingBoxBorderWidth;
    
    // Set self tintColor with default (updates bounding box)
    self.tintColor = [self defaultTintColor];
    
    [self addTarget:self 
             action:@selector(toggleCheckmark)
   forControlEvents:UIControlEventTouchDown];
}

/**
 * Add/remove checkmark image to toggle.
 */
- (void)toggleCheckmark {
    _imageView.image = (_imageView.image) ? nil : _imgCheckmark;
}

/**
 * Override default implementation to set bounding box border color
 * with tintColor.
 */
- (void)setTintColor:(UIColor *)tColor {
    [super setTintColor:tColor];
    _boundingBox.layer.borderColor = [tColor CGColor];
}

#pragma mark - Accessors

- (UIColor *)defaultTintColor {
    return kDefaultTintColor;
}

- (NSString *)accessibilityValue {
    NSString *status = (self.isChecked)?@"checked":@"not checked";
    return status;
}

#pragma ReadOnly Getter

- (BOOL)isChecked {
//    NSLog(@"%s return isChecked: %@", __PRETTY_FUNCTION__, (nil !=_imageView.image)?@"YES":@"NO");
    return (nil != _imageView.image);
}

@end
