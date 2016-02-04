/*
Copyright (C) 2016, Silent Circle, LLC.  All rights reserved.

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
#import "DevicesTableHeaderView.h"
#import "Utilities.h"
#import "DeviceCell.h"
#import "CallButton.h"

#define kLeftOffset 10.
#define kRightOffset 70.

@implementation DevicesTableHeaderView

-  (id)initWithFrame:(CGRect)aRect {
    
    if (self = [super initWithFrame:aRect]) {
        
        [self setBackgroundColor:[UIColor colorWithRed:38./256. green:38./256. blue:41./256. alpha:1.]];
        
        _title = [[UILabel alloc] initWithFrame:CGRectMake(kLeftOffset, 0, aRect.size.width - kRightOffset, CGRectGetHeight(self.frame))];
        [_title setFont:[[Utilities utilitiesInstance] getFontWithSize:_title.font.pointSize]];
        [_title setTextAlignment:NSTextAlignmentLeft];
        [_title setTextColor:[UIColor whiteColor]];
        [self addSubview:_title];
        
        _rescanButton = [[UIButton alloc] initWithFrame:CGRectMake([Utilities utilitiesInstance].screenWidth - kRightOffset, 0, kRightOffset, CGRectGetHeight(self.frame))];
        [_rescanButton.titleLabel setFont:[[Utilities utilitiesInstance] getFontWithSize:_rescanButton.titleLabel.font.pointSize]];
        [_rescanButton setTitle:@"Rescan" forState:UIControlStateNormal];
        [_rescanButton setTitleColor:[UIColor colorWithRed:38./256. green:38./256. blue:41./256. alpha:1.] forState:UIControlStateNormal];
        [_rescanButton setBackgroundColor:[UIColor colorWithRed:138./256. green:138./256. blue:138./256. alpha:1.]];
        [self addSubview:_rescanButton];
    }
    
    return self;
}

@end
