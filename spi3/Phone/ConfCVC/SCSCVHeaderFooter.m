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
//  SCSCVHeaderFooter.m
//  SPi3
//
//  Created by Eric Turner on 1/15/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "SCSCVHeaderFooter.h"
#import "UIColor+ApplicationColors.h"

static NSString * const kSCSCVHeaderFooter_ID = @"SCSCVHeaderFooter_ID";

#define kHeaderBgColor   [UIColor colorWithWhite:0.375 alpha:1]
#define kHeaderFont      [UIFont fontWithName:@"Arial" size:16.]
#define kHeaderFontColor [UIColor colorWithWhite:0.75 alpha:1]
#define kHeaderTextAlign NSTextAlignmentLeft

//current Conf tv.bgColor [UIColor colorWithRed:51/255.0 green:52/255.0 blue:59/255.0 alpha:1]
#define kFooterBgColor   [UIColor colorWithWhite:.15 alpha:1]
#define kFooterFont      [UIFont fontWithName:@"Arial" size:14.]
#define kFooterFontColor [UIColor colorWithWhite:0.5 alpha:1]
#define kFooterTextAlign NSTextAlignmentCenter

@implementation SCSCVHeaderFooter

+ (NSString *)reusedId {
    return kSCSCVHeaderFooter_ID;
}

#pragma mark - Main

- (void)useMainHeaderStyle {
    _mainView.backgroundColor = kHeaderBgColor;
    [self useMainHeaderText];
}

- (void)useMainFooterStyle {
    _mainView.backgroundColor = kFooterBgColor;
    [self useMainFooterText];
}


#pragma mark - Main Text
- (NSString *)mainText {
    return _mainViewLabel.text;
}

- (void)setMainText:(NSString *)txt {
    _mainViewLabel.text = txt;
}

- (void)useMainHeaderText {
    _mainViewLabel.font = kHeaderFont;
    _mainViewLabel.textColor = kHeaderFontColor;
    _mainViewLabel.textAlignment = kHeaderTextAlign;
}

- (void)useMainFooterText {
    _mainViewLabel.font = kFooterFont;
    _mainViewLabel.textColor = kFooterFontColor;
    _mainViewLabel.textAlignment = kFooterTextAlign;
}

- (void)leftAlignMainText {
    [self _textAlign:NSTextAlignmentLeft label:_mainViewLabel];
}

- (void)centerAlignMainText {
    [self _textAlign:NSTextAlignmentCenter label:_mainViewLabel];
}

- (void)rightAlignMainText {
    [self _textAlign:NSTextAlignmentRight label:_mainViewLabel];
}


#pragma mark - Alt Bottom
- (void)useBottomFooterStyle {
    _altBottomView.backgroundColor = kFooterBgColor;
    [self useBottomFooterText];
}


#pragma mark - Bottom Text

- (void)useBottomFooterText {
    _altBottomLabel.font = kFooterFont;
    _altBottomLabel.textColor = kFooterFontColor;
    [self _textAlign:kFooterTextAlign label:_altBottomLabel];
}

- (NSString *)bottomText {
    return _altBottomLabel.text;
}
- (void)setBottomText:(NSString *)txt {
    _altBottomLabel.text = txt;
}

- (void)leftAlignBottomText {
    [self _textAlign:NSTextAlignmentLeft label:_altBottomLabel];
}

- (void)centerAlignBottomText {
    [self _textAlign:NSTextAlignmentCenter label:_altBottomLabel];
}

- (void)rightAlignBottomText {
    [self _textAlign:NSTextAlignmentRight label:_altBottomLabel];
}


#pragma mark - Utilities

- (void)_textAlign:(NSTextAlignment)align label:(UILabel*)lbl {
    lbl.textAlignment = align;
}


@end
