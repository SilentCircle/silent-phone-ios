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
//  MaskedView.m
//  SPi3
//
//  Created by Gints Osis on 12/04/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "MaskedView.h"

@implementation MaskedView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.alpha = 0.2f;
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    
    // creates masks for triangle views, depending on tags
    // 1 - left triangle of Onboarding1
    // 2 - right triangle of Onboarding1
    // 3 - left triangle of Onboarding2
    // 4 - right triangle of Onboarding2
    // 5 - right triangle of Onboarding3
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    CGMutablePathRef path = CGPathCreateMutable();
    
    switch (self.tag) {
        case 1:
        {
            CGPathMoveToPoint(path, nil, 0, self.frame.size.height);
            CGPathAddLineToPoint(path, nil, self.frame.size.width, self.frame.size.height);
            CGPathAddLineToPoint(path, nil, 0, 0);
        }
            break;

        case 2:
        {
            CGPathMoveToPoint(path, nil, 0, self.frame.size.height);
            CGPathAddLineToPoint(path, nil, self.frame.size.width, self.frame.size.height);
            CGPathAddLineToPoint(path, nil, self.frame.size.width, 20);
            CGPathAddLineToPoint(path, nil, self.frame.size.width - 20, 0);
        }
            break;
        case 3:
        {
            CGPathMoveToPoint(path, nil, 0, self.frame.size.height);
            CGPathAddLineToPoint(path, nil, self.frame.size.width - 40, self.frame.size.height);
            CGPathAddLineToPoint(path, nil, 0, 0);
        }
            break;
        case 4:
        {
            CGPathMoveToPoint(path, nil, 20, self.frame.size.height);
            CGPathAddLineToPoint(path, nil, self.frame.size.width, self.frame.size.height);
            CGPathAddLineToPoint(path, nil, self.frame.size.width, 20);
        }
            break;
        case 5:
        {
            CGPathMoveToPoint(path, nil, 0, self.frame.size.height/1.5f);
            CGPathAddLineToPoint(path, nil, self.frame.size.width, self.frame.size.height);
            CGPathAddLineToPoint(path, nil, self.frame.size.width, 0);
        }
            break;
            
        default:
            break;
    }
    
    CGPathCloseSubpath(path);
    maskLayer.path = path;
    self.layer.mask = maskLayer;

}


@end
