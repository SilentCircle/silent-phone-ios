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

//  Created by Gints Osis on 15/07/16.
//  Copyright © 2016 gosis. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HPGrowingTextView.h"
@class HPGrowingTextView;
@protocol HPGrowingTextViewDelegate;
@protocol KeyboardWithActionSheetDelegate<NSObject>
@optional
-(void) willOpenActionSheet:(id) actionsheetWithKeyboardView;
-(void) didOpenActionSheet:(id) actionsheetWithKeyboardView;

-(void) didCloseActionSheet:(id) actionsheetWithKeyboardView;
-(void) willCloseActionSheet:(id) actionsheetWithKeyboardView;

-(void) didSwipeActionSheet:(id) actionsheetWithKeyboardView;

-(void) doneButtonClick:(id) sender;
-(void) burnButtonClick:(id) sender;

-(void) burnSliderValueChanged:(long) newBurnTime;

-(void) shouldChangeBottomOffsetTo:(CGFloat) offset canScroll:(BOOL) canScroll animated:(BOOL) animated;
@end

@interface ActionSheetWithKeyboardView : UIView
-(instancetype) initWithViewController:(UIViewController *) viewC;

-(void) setFontForTextField:(UIFont *) font;

-(void) scrollViewDidScroll:(UIScrollView *)scrollView;
-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView;
-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate;

-(void) setFrameForScreenSize:(CGSize) size;

-(void)deregisterKeyboardNotifications;
- (void)registerKeyboardNotifications;


-(void) hideInputForNumberActionSheet;
@property BOOL registeredForKeyboardNotifications;
@property (nonatomic, weak) id<KeyboardWithActionSheetDelegate> delegate;

@property (strong, nonatomic) HPGrowingTextView *messageTextView;
-(void) closeBurnSlider;

// Addition of ContainerView elements
-(void) addAttachmentButton:(UIButton *) actionSheetButton;
-(void) addDoneButton:(UIButton *) doneButton;
-(void) addBurnButton:(UIButton *) burnButton;
-(void) addActionSheetView:(UIView *) view;
@end
