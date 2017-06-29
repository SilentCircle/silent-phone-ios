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
//  SCSConfHeaderFooterView.h
//  SPi3
//
//  Created by Eric Turner on 11/14/15.
//  Copyright © 2015 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * This class is a WIP. The original idea was to have a single reusable
 * UITableViewHeaderFooterView subclass which could provide optional
 * "alt" top and/or bottom views, with "Main" intended as a generic
 * tableView section header view.
 *
 * The original conference call controller had special "message" views
 * at the bottom of the Conference section and at the top of the Private
 * section, which would appear conditionally based on the count of call
 * cells in each section. 
 *
 * The original intent of this class was to provide the lower Private
 * section to display a "PRIVATE" section header, and on top of that
 * display a "message" view as if it belonged to the bottom of the 
 * Conference section, and optionally, display a Private "message" view
 * underneath. This was to be accomplished in some of the commented
 * methods with AutoLayout.
 *
 * Initial attempts to use this class as designed resulted in AutoLayout
 * errors and unexpected results, which led to commenting a number of
 * the features. Likely, the development of the tableView handling and 
 * proper conditions for section views display was causing at least some
 * of the problems.
 *
 * The GTD solution for the ConferenceVC was to simply use different
 * xibs for each of the three required views, with height and colors
 * laid out explicitly. 
 *
 * Note that the useMainHeaderStyle, useMainFooterStyle, and 
 * useBottomFooterStyle methods do work as expected and are used in the
 * (current version) of SCSConferenceTVC. The bgColor, font, textColor, 
 * and textAlign values are at the top of the .m as #defines. Would that
 * this class be extended, these would likely become properties 
 * optionally defined by the client.
 */
@interface SCSConfHeaderFooterView : UITableViewHeaderFooterView

@property (weak, nonatomic) IBOutlet UIView *mainView;
@property (weak, nonatomic) IBOutlet UILabel *mainViewLabel;
// A convenience setter - gets/sets the mainViewLabel.text property
@property (copy, nonatomic) NSString *mainText;
//@property (readonly, nonatomic) BOOL mainViewIsVisible;
//@property (nonatomic) CGFloat mainHeight;
//@property (weak, nonatomic) IBOutlet NSLayoutConstraint *lcMainViewH;

/** A container view for the altBottomLabel */
@property (weak, nonatomic) IBOutlet UIView *altBottomView;
/** A label for displaying a message directly below the main section 
 * label. For ConferenceTVC, this is the "Drag here to remove from 
 * conference" */
@property (weak, nonatomic) IBOutlet UILabel *altBottomLabel;
/** A convenience accessor/setter for altBottomLabel.text */
@property (copy, nonatomic) NSString *bottomText;
//@property (readonly, nonatomic) BOOL bottomViewIsVisible;
//@property (nonatomic) CGFloat bottomHeight;
//@property (weak, nonatomic) IBOutlet NSLayoutConstraint *lcAltBottomViewH;


+ (NSString *)reusedId;

//- (void)showTopView;
//- (void)hideTopView;

- (void)useMainHeaderStyle;
- (void)useMainFooterStyle;
//- (void)showMainView;
//- (void)hideMainView;
//- (void)showOnlyMain;

- (void)useMainHeaderText;
- (void)useMainFooterText;
- (void)leftAlignMainText;
- (void)centerAlignMainText;
- (void)rightAlignMainText;

// Bottom
- (void)useBottomFooterStyle;
//- (void)showBottomView;
//- (void)hideBottomView;

- (void)useBottomFooterText;
- (NSString *)bottomText;
- (void)leftAlignBottomText;
- (void)centerAlignBottomText;
- (void)rightAlignBottomText;

@end
