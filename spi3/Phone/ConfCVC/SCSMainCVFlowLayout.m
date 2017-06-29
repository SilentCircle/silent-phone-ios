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
//  SCSMainCVFlowLayout.m
//  SPi3
//
//  Created by Eric Turner on 11/4/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import "SCSMainCVFlowLayout.h"

// Extern definitions used by ConfCVC (previously used here)
CGFloat const scsSectionHeaderH = 36.;
CGFloat const scsSectionFooterH = 28.;

static CGFloat    const kInterimSpace      =   8.;
static CGFloat    const kItemHeight        = 181.; // matches xib item height
static CGFloat    const kCvInsetMargin     =   8.;

@implementation SCSMainCVFlowLayout


#pragma mark - Configuration

- (void)awakeFromNib {
    [super awakeFromNib];
    
    [self configureLayout];
}

// Set static layout values
- (void)configureLayout {
    CGSize viewSize = [UIScreen mainScreen].bounds.size;
    CGFloat viewW   = viewSize.width;
    
    self.itemSize = (CGSize){.width = (viewW / 2) - (kInterimSpace/2 + kCvInsetMargin), .height = kItemHeight};
    self.sectionInset = UIEdgeInsetsMake(kCvInsetMargin, kCvInsetMargin, kCvInsetMargin, kCvInsetMargin);
    
    // header/footerReferenceSize is better set here, statically, to 1pt
    // height, and the different required heights for variable
    // conditions, returned by the collectionView
    // UICollectionViewDelegateFlowLayout delegate.
    // @see SCSConferenceCVC collectionView:layout:insetForSectionAtIndex:
    self.headerReferenceSize = (CGSize){ viewW, 1.0 };
    // When footerReferenceSize is set to CGSizeZero, crash results with error:
    // No UICollectionViewLayoutAttributes found for footer in section
    self.footerReferenceSize = (CGSize){ viewW, 1.0 };

    self.minimumInteritemSpacing = kInterimSpace;
    self.minimumLineSpacing = kInterimSpace;
}

- (BOOL)sectionHeadersPinToVisibleBounds {
    return YES;
}

- (BOOL)sectionFootersPinToVisibleBounds {
    return YES;
}

@end
