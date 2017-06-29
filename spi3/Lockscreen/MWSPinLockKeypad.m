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
//  MWSPinLockKeypad.m
//
//  Created by Eric Turner on 7/1/14.
//  Copyright (c) 2014 MagicWave Software LLC. All rights reserved.
//


#import "MWSPinLockKeypad.h"
#import "MWSShapeButton.h"
#import "MWSShapeButtonConstants.h"
#import "MWSShapeButtonsView.h"
#import "MWSPinLockScreenConstants.h"

#import "Silent_Phone-Swift.h"

@interface MWSPinLockKeypad () <MWSShapeButtonDelegate>

/** A storage array for collecting titles of `MWSShapeButtons` entered by user */
@property (strong, nonatomic) NSMutableArray *arrEntries;

/** A subview containing the small `MWSShapeButton`s. These fill for user pad entries. */
@property (weak, nonatomic) IBOutlet MWSShapeButtonsView *circleButtonsView;

/** The top container view */
@property (weak, nonatomic) IBOutlet UIView *topView;

/** A subview containing the top label; default title is "Enter passcode" */
@property (weak, nonatomic) IBOutlet UILabel *topLabel;

/** A subview containing the bottom label;
    default title is empty. Used to display error messages during passcode creation/editing */
@property (weak, nonatomic) IBOutlet UILabel *bottomLabel;

/** A subview containing the tappable `MWSShapeButton`s */
//@property (weak, nonatomic) IBOutlet UIView *mainButtonsView;

/** The bottom container view; in system lockscreen appears "Cancel" */
@property (weak, nonatomic) IBOutlet UIView *bottomView;

/** A dual-purpose button for handling entry deletes and log out events. 
 * Analogous to system lockscreen "Cancel" */
@property (weak, nonatomic) IBOutlet UIButton *btnRight;
@property (weak, nonatomic) UIButton *btnEntryEdit; // semantic pointer to btnRight

@property (weak, nonatomic) IBOutlet UIButton *btnTouchID;

@property (strong, nonatomic) IBOutletCollection(NSLayoutConstraint) NSArray *buttonWidthConstraints;
@property (weak, nonatomic) IBOutlet UIStackView *outerStackView;
@property (strong, nonatomic) IBOutletCollection(UIStackView) NSArray *innerStackViews;

@end


@implementation MWSPinLockKeypad
{
    IBOutlet NSLayoutConstraint *_topViewHeightConstraint;
    IBOutlet NSLayoutConstraint *_mainButtonsViewWidthConstraint;
    IBOutlet NSLayoutConstraint *_mainButtonsViewHeightConstraint;
    IBOutlet NSLayoutConstraint *_bottomViewTopSpaceConstraint;
    
    BOOL _layoutIsConfigured;
    
    NSString *_bottomText;
}

#pragma mark - Layout

/**
 * Sets the `btnEntryEdit` button title, initializes user's entries storage array, configures circleButtons in 
 * subviews with a color, and sets view/subview background colors to clear.
 *
 * The self view and subviews are set with clearColor backgrounds at hydration from storyboard, for
 * the intended effect of the `MWSLockScreenVC` blurred background view; in IB these background
 * colors may be set for visibility at design time.
 */
- (void)awakeFromNib {
    [super awakeFromNib];
    
    // Clear "Cancel" button title, set in IB
    _btnEntryEdit = _btnRight;
    
    [self clear];
    
    // Hide "TouchID" button
    _btnTouchID.enabled = NO;
    _btnTouchID.hidden  = YES;
    
    // clear subview background colors.
    // Background colors are likely set in IB for visual convenience for layout, but are set to clear here at runtime
    UIColor *clearColor = [UIColor clearColor];
    self.backgroundColor = clearColor;
    _topView.backgroundColor = clearColor;
    _mainButtonsView.backgroundColor = clearColor;
    _bottomView.backgroundColor = clearColor;
    _circleButtonsView.backgroundColor = clearColor;
    _topLabel.backgroundColor = clearColor;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (!_layoutIsConfigured){
        _layoutIsConfigured = YES;
        [self configureButtons];
    }    
}

// TODO: Needs iPad Support here
/**
 * In the immediate term I think we can experiment to find the most
 * appropriate multiplier value for all iPads. Another approach to 
 * layout for different device screen sizes is with sizeClasses in IB,
 * but the sizeClasses didn't seem to give enough granularity, so this
 * is how we're doing it for now.
 *
 * The magic multiplier values are a result of trial and error, laying
 * out the lockscreen in IB for each device screen size with the 
 * MWSPinLockScreenVC background image set with a screenshot taken of
 * Apples lockscreen on the various iphone screens. These reference 
 * images are in the lockscreen resources dir.
 *
 * Also see comment in MWSPinLockScreenVC viewDidLoad for how to leave
 * this background image in place to compare the actual view layout
 * overlaying the image of the Apple layout.
 */
- (void)setTopViewHeightMultiplier:(NSLayoutConstraint *)c device:(MWSDevice *)device {
    switch (device.type) {
        case MWSDeviceTypeMwSiPhone_4_or_less:
            [c updateMultiplier:0.145];
            break;
        case MWSDeviceTypeMwSiPhone_5:
            [c updateMultiplier:0.215];
            break;
        case MWSDeviceTypeMwSiPhone_6_7:
            [c updateMultiplier:0.223];
            break;            
        case MWSDeviceTypeMwSiPhone_6_7P:
            [c updateMultiplier:0.228];
            break;      
        // Not supported yet    
        case MWSDeviceTypeMwSiPhone_iPad:
        case MWSDeviceTypeMwSiPhone_iPadPro:
            [c updateMultiplier:0.223]; // TEST same as 6
            break;
        case MWSDeviceTypeMwsDeviceUnknown:
            break;
    }    
}

- (void)setMainButtonsViewWidthMultiplier:(NSLayoutConstraint *)c device:(MWSDevice *)device {
    CGFloat iPhoneW = 0.8344;  // same for all iPhones (probably already set in IB)
    switch (device.type) {
        // iPhones multiplier is common
        case MWSDeviceTypeMwSiPhone_4_or_less:
        case MWSDeviceTypeMwSiPhone_5:
        case MWSDeviceTypeMwSiPhone_6_7:
        case MWSDeviceTypeMwSiPhone_6_7P:
            [c updateMultiplier:iPhoneW];
//            break; // TEST all as same
        // Not supported yet
        case MWSDeviceTypeMwSiPhone_iPad:
        case MWSDeviceTypeMwSiPhone_iPadPro:
        case MWSDeviceTypeMwsDeviceUnknown:
            break;
    }
}

- (void)setMainButtonsViewHeightMultiplier:(NSLayoutConstraint *)c device:(MWSDevice *)device {
    
    switch (device.type) {
        // iPhone 4 needs taller buttons view proportionally
        case MWSDeviceTypeMwSiPhone_4_or_less:
            [c updateMultiplier:0.7];
            break;
            // 5, 6, 6+ iPhones multiplier is common
        case MWSDeviceTypeMwSiPhone_5:
        case MWSDeviceTypeMwSiPhone_6_7:
        case MWSDeviceTypeMwSiPhone_6_7P:
            [c updateMultiplier:0.6];
            break;
        // Not supported yet
        case MWSDeviceTypeMwSiPhone_iPad:
        case MWSDeviceTypeMwSiPhone_iPadPro:
            [c updateMultiplier:0.6]; // TEST same as > 4
            break;
        case MWSDeviceTypeMwsDeviceUnknown:
            break;
    }
}

- (CGFloat)keypadButtonMultiplierWithDevice:(MWSDevice *)device {
    switch (device.type) {
        case MWSDeviceTypeMwSiPhone_4_or_less:
            return 0.15;
        case MWSDeviceTypeMwSiPhone_5:
        case MWSDeviceTypeMwSiPhone_6_7:
        case MWSDeviceTypeMwSiPhone_6_7P:
            return 0.1303;
        case MWSDeviceTypeMwSiPhone_iPad:
        case MWSDeviceTypeMwSiPhone_iPadPro:    
            return 0.1303;  // TEST with same as > 4
        case MWSDeviceTypeMwsDeviceUnknown:
            break;
    }
    
    return 1;
}

- (NSInteger)outerStackViewSpacingWithDevice:(MWSDevice *)device {
    switch (device.type) {
        case MWSDeviceTypeMwSiPhone_4_or_less:
            return 23;
        case MWSDeviceTypeMwSiPhone_5:
            return 21;
        case MWSDeviceTypeMwSiPhone_6_7:
            return 25;
        case MWSDeviceTypeMwSiPhone_6_7P:
            return 27;
        case MWSDeviceTypeMwSiPhone_iPad:
        case MWSDeviceTypeMwSiPhone_iPadPro:    
            return 21;  // TEST with same as > 5
        case MWSDeviceTypeMwsDeviceUnknown:
            break;
    }
    
    return 21;
}

- (NSInteger)innerStackViewSpacingWithDevice:(MWSDevice *)device {
    switch (device.type) {
        case MWSDeviceTypeMwSiPhone_4_or_less:
            return 16;
        case MWSDeviceTypeMwSiPhone_5:
            return 14;
        case MWSDeviceTypeMwSiPhone_6_7:
            return 16;
        case MWSDeviceTypeMwSiPhone_6_7P:
            return 18;
        case MWSDeviceTypeMwSiPhone_iPad:
        case MWSDeviceTypeMwSiPhone_iPadPro:    
            return 16;  // TEST with same as > 6
        case MWSDeviceTypeMwsDeviceUnknown:
            break;
    }
    
    return 16;
}


#pragma mark - MWSShapeButtonDelegate Methods

/**
 * Invokes the fill-to-highlight color change method and notifies the delegate.
 *
 * This callback is invoked by `MWSCircleButton` touchesBegan: event to set highlight color
 * in the "tracker" circle button, informing the display of number of user button selections, or
 * "entries".
 *
 * The calling  `MWSCircleButton` title text is stored in the `arrEntries` 
 * array, which is used both for tracking number of entries and for passing to the self 
 * `MWSLockPadDelegate` when the `arrEntries` array is full.
 *
 * `updateEditButtonTitle` is invoked to set the `btnEntryEdit` title appropriately for the number of
 * currently stored title entries.
 *
 * @param cb An `MWSCircleButton` instance
 */
- (void)shapeButtonDidStartTouch:(MWSShapeButton *)cb {
    
    // Clear the shapes on first character, just in case
    if(_arrEntries.count == 0)
        [_circleButtonsView clearShapeHighlightsWithAnimation:NO];
    
    [_arrEntries addObject: cb.lblTitle.text];
    
    // Highlight the tracking circleButton
    [_circleButtonsView highlightShapeAtIndex: _arrEntries.count - 1 animated: NO];
    
    // Update the Cancel/Delete button title
    [self updateEditButtonTitle];
    
    [self updateAccessibilityHintForCircleButtons];

    if ([_delegate respondsToSelector: @selector(shapeButtonDidStartTouch:)]) {
        [_delegate shapeButtonDidStartTouch: cb];
    }
}

/**
 * Invokes the highlight-back-to-fill color change method and notifies the delegate.
 *
 * The `arrEntries` array stores user-selected button titles, added in the 
 * `[MWSShapeButtonDelegate shapeButtonDidStartTouch:]` callback. This method checks at each
 * button "touch up" event whether the `arrEntries` array count is "full", defined by the
 * MWS_PIN_ENTRIES_COUNT constant. When the `arrEntries` is full, this method notifies its
 * delegate with the array.
 *
 * @param cb An `MWSCircleButton` instance
 * @see `MWSLockScreenConstants`
 */
- (void)shapeButtonDidEndTouch:(MWSShapeButton *)cb {
    if ([_delegate respondsToSelector: @selector(shapeButtonDidEndTouch:)]) {
        [_delegate shapeButtonDidEndTouch: cb];
    }
    
    // Message delegate with arrEntries selections when complete
    if (_arrEntries.count == MWS_PIN_ENTRIES_COUNT && [_delegate respondsToSelector: @selector(lockPadSelectedButtonTitles:)]) {

        [_bottomLabel setHidden:YES];

        [_delegate lockPadSelectedButtonTitles: _arrEntries];
    }
}


#pragma mark - Logout/Delete Button

/**
 * Fires the `[MWSLockPadViewDelegate lockPadSelectedCancel]` delegate callback, notifying of a
 * user "Log out" selection if there are no stored user PIN entries in `arrEntries`, or, removes
 * the previous button title user selection from `arrEntries` and invokes `updateEditButtonTitle` to
 * update button title.
 *
 * Note: this method could be updated for use by the delegate so as to let the delegate determine
 * the functionality of the button. To implement, the delegate callbacks would be defined in the
 * MWSLockPadViewDelegate protocol. When this method is fired, the button would be passed to the
 * delegate, which could manage with the use of tags. The updateEditButtonTitle method would need to 
 * be refactored to allow for delegate configuration for state changes. In both methods, the current
 * implementation would be executed unless the delegate implements these new callbacks.
 */
- (IBAction)handleLogoutDeleteButton:(UIButton *)sender {

    if (_arrEntries.count == 0 && [_delegate respondsToSelector:@selector(shouldShowCancelButton)] && [_delegate shouldShowCancelButton]) {
        
        if ([_delegate respondsToSelector: @selector(lockPadSelectedCancel)]) {
            [_delegate lockPadSelectedCancel];
        }
        return;
    }

    // Clear last entry and update tracker circle and logoutDeleteButton title
    [_circleButtonsView clearShapeHighlightAtIndex: (_arrEntries.count - 1) animated: YES];
    [self.arrEntries removeLastObject];    
    [self updateEditButtonTitle];
    [self updateAccessibilityHintForCircleButtons];
}

/**
 * Sets the dual-purpose `btnEntryEdit` title appropriately for the current state.
 *
 * When the `arrEntries` array is empty, the button title is set to the MWS_CANCEL_TITLE string
 * constant, and to the MWS_DELETE_TITLE otherwise.
 *
 * Note: this method and `handleLogoutDeleteButton:` could be refactored to optionally enable the
 * delegate to control the button appearance/state and functionality, as described in the 
 * `handleLogoutDeleteButton:` documentation.
 *
 * @see handleLogoutDeleteButton: for more on refactoring
 */
- (void)updateEditButtonTitle {
    
    NSString *title = nil;
    
    if(self.arrEntries.count > 0)
        title = MWS_DELETE_TITLE;
    else if([_delegate respondsToSelector:@selector(shouldShowCancelButton)] && [_delegate shouldShowCancelButton])
        title = MWS_CANCEL_TITLE;

    [self.btnEntryEdit setHidden:!title];
    
    if(title)
        [self.btnEntryEdit setTitle: title
                           forState: UIControlStateNormal];
}

- (void)updateAccessibilityHintForCircleButtons {
    
    _circleButtonsView.accessibilityHint = [NSString stringWithFormat:@"%lu %@ 4 %@",
                                            (unsigned long)[self.arrEntries count],
                                            NSLocalizedString(@"of", nil),
                                            NSLocalizedString(@"values entered", nil)];
}


#pragma mark - Utilities

/** 
 * Return circleButton title label text
 */
- (NSString *)strEntryWithButton:(MWSShapeButton *)cb {
    NSString *title = cb.lblTitle.text;
    return title;
}

- (void)clear {
    
    // initialize arrEntries
    _arrEntries = [NSMutableArray arrayWithCapacity: MWS_PIN_ENTRIES_COUNT];
    
    [self updateEditButtonTitle];
    [self updateAccessibilityHintForCircleButtons];
}

#pragma mark - Public

/**
 * Resets self to a PIN sequence start state and updates the display.
 *
 * When the `arrEntries` collection of user button title entries is passed to `MTLockScreenVC`, it
 * notifies its MWSLockScreenDelegate with the entries and is returned a BOOL pass/fail. If the
 * PIN/entries fails authentication, `MTLockScreenVC` calls this method to restart the PIN sequence.
 *
 * This method reinitializes the arrEntries array, updates the `logoutDeleteButton` and invokes
 * `[trackerButtonsView shakeAndClearShapeButtonsWithCompletion:]` to do the Apple
 * "wrong-password shake". The userInteractionEnabled flag is cleared at the start of the method to
 * prevent addtional button press events while the shake animation runs, and then reenables
 * user interaction in the completion callback;
 */
- (void)animateInvalidEntryResponseWithText:(NSString *)text completion:(void (^)(void))completion {
    
    NSString *announcedText = (text ? text : NSLocalizedString(@"Wrong Passcode", nil));
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, NSLocalizedString(announcedText, nil));
    });

    _bottomText = text;
    
    [self clear];

    [_circleButtonsView shakeAndClearShapeButtonsWithCompletion:^{
        
        if(_bottomText)
            [self setBottomText:_bottomText];
        
        if(completion)
            completion();
    }];
}

// trying to fix circle path drawing too soon
/**
 * This method is called by layoutSubviews. I tried calling it from
 * awakeFromNib and from the MWSPinLockScreenVC viewDidLoad and
 * viewWillAppear methods, but the timing of when views lay out in the
 * hierarchy and can draw, is best this way (so far).
 *
 * @see setMainButtonsViewWidthMultiplier: for how we apply a multiplier
 * to get proper layout for different device screens.
 */
- (void)configureButtons { //tmp method name
    // Configure "tracking" circles in shapeButtonsView with superview tintColor
    
    MWSDevice *device = [[MWSDevice alloc] init];
    NSLog(@"%s deviceType: %lu \n%@", __PRETTY_FUNCTION__, (unsigned long)device.type, device.description);
    
    //STACKVIEWS
    _outerStackView.spacing = [self outerStackViewSpacingWithDevice:device];
    for (UIStackView *sv in _innerStackViews) {
        sv.spacing = [self innerStackViewSpacingWithDevice:device];
    }
    
    // update top/main/bottom view constraints
    [self setTopViewHeightMultiplier:_topViewHeightConstraint device:device];
    
    [self setMainButtonsViewWidthMultiplier:_mainButtonsViewWidthConstraint device:device];
    [self setMainButtonsViewHeightMultiplier:_mainButtonsViewHeightConstraint device:device];
    
    _bottomViewTopSpaceConstraint.constant = (device.type == MWSDeviceTypeMwSiPhone_4_or_less) ? 0 : 16;
    
    // Then update the proportional layout for device screen size
    // configure keypadButtons (keypad circles in _mainButtonsView)
    //
    //TEST: first keypad buttons (then tracking buttons or topView)
    NSArray *keypadButtons = [MWSShapeButtonsView allShapeButtonsInSubviewsOfView:_mainButtonsView];
    
    CGFloat mx = [self keypadButtonMultiplierWithDevice:device];
    for (NSLayoutConstraint *c in _buttonWidthConstraints) {
        [c updateMultiplier:mx];
    }
    
    [_mainButtonsView layoutIfNeeded];
    
    UIColor *btnsColor = [UIColor colorWithRed:1. green:1. blue:1. alpha:0.5];
    
    [_btnRight setTitleColor:btnsColor forState:UIControlStateNormal];
    
    //-------------------------------- Make all shapes circles and configure with btnsColor --------------------------//
    // optionsDict with color and shape configurations
    NSMutableDictionary *mDict = [[MWSShapeButtonsView shapeOptionsWithColor:btnsColor] mutableCopy];
    mDict[MWS_ShapeButton_isCircleShape] = [NSNumber numberWithBool:YES];
    
    //TEST - configure title/subTitle textColors explicitly
    mDict[MWS_ShapeButton_titleColor] = [UIColor whiteColor];
    mDict[MWS_ShapeButton_subTitleColor] = [UIColor whiteColor];
    
    // Draw buttons with options
    [MWSShapeButtonsView configureShapeButtons:keypadButtons
                                   withOptions:[NSDictionary dictionaryWithDictionary:mDict]];

    // this is required here before drawing button shapes
    [_circleButtonsView layoutIfNeeded];
    
    // configure tracking circles (non-keypad circles in _circleButtonsView)
    // with opaque highlight color
    mDict[MWS_ShapeButton_highlightColor] = [btnsColor colorWithAlphaComponent:1.];
    [_circleButtonsView configureAllShapesWithOptions:[NSDictionary dictionaryWithDictionary:mDict]];
    
}

- (void)setLabelTitle:(NSString *)labelTitle clearDots:(BOOL)shouldClearDots {

    if(shouldClearDots) {

        [self clear];
        
        if(_circleButtonsView)
            [_circleButtonsView clearShapeHighlightsWithAnimation:NO];
    }

    [_topLabel setText:labelTitle];
}

- (void)setBottomText:(NSString *)text {
    
    if(!text) {
    
        [_bottomLabel setHidden:YES];
        return;
    }
    
    [_bottomLabel setText:text];
    [_bottomLabel setHidden:([text isEqualToString:@""])];
}

- (void)enableTouchIDtarget:(id)target action:(SEL)action {

    [_btnTouchID setEnabled:YES];
    [_btnTouchID setHidden:NO];
    [_btnTouchID addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
}

@end
