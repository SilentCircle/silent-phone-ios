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

#import "ActionSheetWithKeyboardView.h"
#import "KeyboardAccessoryView.h"
#import "ActionsheetView.h"
#import "SCPNotificationKeys.h"
#import "MessageBurnSliderView.h"
#define kActionSheetOpenSpeed 0.3f

#define kMaxMessageTextFontSize 25
#define kMaxMessageInputTextFontSize 20
@interface ActionSheetWithKeyboardView ()<HPGrowingTextViewDelegate, BurnSliderDelegate>
{
    KeyboardAccessoryView *invisibleInputView;
    
    BOOL isKeyboardOpen;
    
    ActionsheetView *actionSheetView;

    BOOL isActionSheetOpen;
    BOOL willOpenKeyboard;
    BOOL isKeyboardDecelerating;
    CGPoint lastTouchPositionInViewController;
    BOOL isActionSheetAnimating;
    BOOL isBurnSliderOpen;

    
    CGFloat lastContentOffset;
    
    float containerViewHeight;
    
    UIImageView *plusIconImageView;
    UIView *burnButtonBackgroundView;
    NSLayoutConstraint *burnButtonBackgroundTopConstraint;
    UIButton *burnButton;
    
    MessageBurnSliderView *slider;
    BOOL sliderObserverAdded;
    
    NSMutableArray *accessibilityElements;
    
    
    int displayedHeaderStripHeight;
}
@end
@implementation ActionSheetWithKeyboardView


- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self initalizeActionSheet];
    }
    return self;
}

-(instancetype)initWithFrame:(CGRect)frame{
    
    if (self = [super initWithFrame:frame]) {
        [self initalizeActionSheet];
    }
    return self;
}

-(instancetype)initWithViewController:(UIViewController *)viewC
{
    if (self = [super init]) {
        [self setFrame:CGRectMake(0,viewC.view.bounds.size.height - 40, viewC.view.bounds.size.width, 40)];
        [self initalizeActionSheet];
    }
    return self;
}

-(void) initalizeActionSheet
{
   // [self setBackgroundColor:[UIColor lightGrayColor]];
    
    // HPGrowingTextView for message text
    
    willOpenKeyboard = NO;
    accessibilityElements = [NSMutableArray arrayWithCapacity:4];
    for (int i = 0; i < 4; i++) {
        [accessibilityElements addObject:[NSNull null]];
    }
     _messageTextView = [[HPGrowingTextView alloc] init];
    _messageTextView.isScrollable = NO;
    [_messageTextView setNeedsDisplay];
    _messageTextView.contentInset = UIEdgeInsetsMake(0, 5, 0, 5);
    _messageTextView.minNumberOfLines = 1;
    [_messageTextView setMaxNumberOfLines:0];
    _messageTextView.returnKeyType = UIReturnKeyDefault;
    int _messageTextViewFont = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline].pointSize;
    if (_messageTextViewFont > kMaxMessageInputTextFontSize) {
        _messageTextViewFont = kMaxMessageInputTextFontSize;
    }
    _messageTextView.delegate = self;
    _messageTextView.internalTextView.autocorrectionType = UITextAutocorrectionTypeYes;//No;
    _messageTextView.internalTextView.scrollIndicatorInsets = UIEdgeInsetsMake(5, 0, 5, 0);
    _messageTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _messageTextView.layer.cornerRadius = 1;
    _messageTextView.clipsToBounds = YES;
    _messageTextView.internalTextView.keyboardAppearance = UIKeyboardAppearanceDark;
    _messageTextView.internalTextView.isAccessibilityElement = YES;
    _messageTextView.internalTextView.accessibilityHint = NSLocalizedString(@"Message text field", nil);
    _messageTextView.layer.cornerRadius = _messageTextView.frame.size.height / 2 - 5;
    _messageTextView.layer.masksToBounds = YES;

    
    _messageTextView.translatesAutoresizingMaskIntoConstraints = NO;
    _messageTextView.placeholder = NSLocalizedString(@"Say something ...", nil);
    [self addSubview:_messageTextView];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-80-[_messageTextView]-40-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_messageTextView)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(<=2)-[_messageTextView]-(<=2)-|" options:NSLayoutFormatAlignAllCenterY metrics:nil views:NSDictionaryOfVariableBindings(_messageTextView)]];
    
    [self setupInputAccessoryView];
    [self registerKeyboardNotifications];
    
    [accessibilityElements replaceObjectAtIndex:2 withObject:_messageTextView.internalTextView];
}

-(void) setupInputAccessoryView
{
    invisibleInputView = [[KeyboardAccessoryView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.frame.size.height)];
    [invisibleInputView setUserInteractionEnabled:NO];
    [invisibleInputView setBackgroundColor:[UIColor clearColor]];
    _messageTextView.internalTextView.inputAccessoryView = invisibleInputView;
}

#pragma mark Call Header Strip

-(void) willShowHeaderStrip:(NSNotification *) note
{
    NSLayoutConstraint *constraint = [note.userInfo objectForKey:kSCPConstraintDictionaryKey];
    if (!constraint)
        return;
    displayedHeaderStripHeight = constraint.constant;
    
    CGRect containerFrame = self.frame;
    containerFrame.origin.y -= displayedHeaderStripHeight;
    
    [UIView animateWithDuration:0.25f animations:^{
        self.frame = containerFrame;
    }];

}

-(void) willHideHeaderStrip:(NSNotification *) note
{
    NSLayoutConstraint *constraint = [note.userInfo objectForKey:kSCPConstraintDictionaryKey];
    if (!constraint)
        return;
    displayedHeaderStripHeight = constraint.constant;
    CGRect containerFrame = self.frame;
    containerFrame.origin.y += displayedHeaderStripHeight;
    
    [UIView animateWithDuration:0.25f animations:^{
        self.frame = containerFrame;
    }];
}

#pragma mark - Notification Registration

- (void)registerKeyboardNotifications {
    
    if (!_registeredForKeyboardNotifications)
    {
         [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willShowHeaderStrip:) name:kSCPWillShowHeaderStrip object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willHideHeaderStrip:) name:kSCPWillHideHeaderStrip object:nil];
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inputAccessoryViewFrameDidChange:) name:UIInputAccessoryFrameDidChange object:nil];
        _registeredForKeyboardNotifications = YES;
    }
    
}

- (void)deregisterKeyboardNotifications {
    
    if (_registeredForKeyboardNotifications)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UIInputAccessoryFrameDidChange object:nil];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kSCPWillShowHeaderStrip object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kSCPWillHideHeaderStrip object:nil];
        _registeredForKeyboardNotifications = NO;
    }
}

#pragma mark Keyboard Delegate
-(void) inputAccessoryViewFrameDidChange:(NSNotification *) note
{
    if (!isKeyboardOpen)
    {
        return;
    }
    UIView *inputAccessoryView = [note.userInfo objectForKey:kSCPViewDictionaryKey];
    if (!inputAccessoryView)
        return;
    CGRect containerFrame = self.frame;
    
    CGPoint inputOriginInView = [self.superview convertPoint:inputAccessoryView.frame.origin fromView:inputAccessoryView.superview];
    if (inputOriginInView.y > 0)
    {
        containerFrame.origin.y = inputOriginInView.y - containerFrame.size.height + 40;
       BOOL didChange = [self tryToSetContainerFrame:containerFrame];
        
        if (didChange)
        {
            [self.delegate shouldChangeBottomOffsetTo:self.superview.frame.size.height - containerFrame.origin.y canScroll:NO animated:YES];
        }
    }
}

-(void) keyboardDidShow:(NSNotification *) note
{
    
}
-(void) keyboardWillShow:(NSNotification *)note
{
    [self closeBurnSlider];
    willOpenKeyboard = YES;
    if (isActionSheetOpen)
    {
        [self actionSheetButtonClick:nil];
    }
    willOpenKeyboard = NO;
    isKeyboardOpen = YES;
    
    // get keyboard size and location
    CGRect keyboardBounds;
    [[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboardBounds];
    NSNumber *duration = [note.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSNumber *curve = [note.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    
    // Need to translate the bounds to account for rotation.
    keyboardBounds = [self.superview convertRect:keyboardBounds toView:nil];
    
    // get a rect for the textView frame
    CGRect containerFrame = self.frame;
    containerFrame.origin.y = self.superview.bounds.size.height - keyboardBounds.size.height - self.frame.size.height + 40;
    //containerFrame.origin.y -= containerFrame.size.height;
    
    // animations settings
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationDuration:[duration doubleValue]];
    [UIView setAnimationCurve:(UIViewAnimationCurve)[curve intValue]];
    
    // set view with new info
    self.frame = containerFrame;
    
    [self.delegate shouldChangeBottomOffsetTo:self.superview.frame.size.height - self.frame.origin.y canScroll:!isActionSheetAnimating animated:NO];
    
    
    // commit animations
    [UIView commitAnimations];
    
    
    //[self scrollToLastVisible:NO];
}

-(void) keyboardWillHide:(NSNotification *)note
{
    isKeyboardOpen = NO;
    if (!isActionSheetOpen) {
        [self.delegate shouldChangeBottomOffsetTo:self.frame.size.height canScroll:NO animated:YES];
        [self setFrame:CGRectMake(0, self.superview.frame.size.height - self.frame.size.height, self.frame.size.width, self.frame.size.height)];
    }
   // [self.delegate shouldChangeBottomOffsetTo:self.superview.frame.size.height - self.frame.origin.y canScroll:YES];
}

#pragma mark ActionSheetClick

-(void) actionSheetButtonClick:(id) sender
{
    [self closeBurnSlider];
    // do it without observer
    // turn on observer only when action sheet is open
    dispatch_async(dispatch_get_main_queue(), ^{
        [actionSheetView setHidden:NO];
    });
    BOOL isKeyboardOpenBeforeChange = isKeyboardOpen;
    if(!isActionSheetOpen)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [actionSheetView setHidden:NO];
        });
        isActionSheetOpen = YES;
        if ([_messageTextView isFirstResponder])
        {
            [UIView animateWithDuration:0.15f animations:^{
                [_messageTextView resignFirstResponder];
            }];
        }
        if (!isKeyboardOpenBeforeChange)
        {
            isActionSheetAnimating = YES;
            [UIView animateWithDuration:kActionSheetOpenSpeed animations:^(void){
                [self callDelegateWithAction:@selector(willOpenActionSheet:) object:self];
                CGRect containerFrame = self.frame;
                containerFrame.origin.y -= 250;
                self.frame = containerFrame;
                [self.delegate shouldChangeBottomOffsetTo:self.superview.frame.size.height - self.frame.origin.y canScroll:YES animated:NO];
                plusIconImageView.transform = CGAffineTransformMakeRotation(45 * M_PI/180);
                [self layoutIfNeeded];
            }completion:^(BOOL finished)
             {
                 isActionSheetAnimating = NO;
             }];
        } else
        {
            [self layoutIfNeeded];
            isActionSheetAnimating = YES;
            [UIView animateWithDuration:kActionSheetOpenSpeed animations:^(void){
                [self callDelegateWithAction:@selector(willOpenActionSheet:) object:self];
                CGRect containerFrame = self.frame;
                containerFrame.origin.y = self.superview.frame.size.height - (250 + self.frame.size.height);
                self.frame = containerFrame;
                [self.delegate shouldChangeBottomOffsetTo:self.superview.frame.size.height - self.frame.origin.y canScroll:YES animated:YES];
                plusIconImageView.transform = CGAffineTransformMakeRotation(45 * M_PI/180);
                [self layoutIfNeeded];
            }completion:^(BOOL finished)
             {
                 isActionSheetAnimating = NO;
             }];
        }
        
    } else
    {
        isActionSheetOpen = NO;
        if (isKeyboardOpenBeforeChange)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [actionSheetView setHidden:YES];
            });
        }
        isActionSheetAnimating = YES;
        [UIView animateWithDuration:kActionSheetOpenSpeed animations:^(void){
            [self callDelegateWithAction:@selector(willCloseActionSheet:) object:self];
            CGRect containerFrame = self.frame;
            containerFrame.origin.y = self.superview.frame.size.height - CGRectGetHeight(self.frame);
            self.frame = containerFrame;
            plusIconImageView.transform = CGAffineTransformMakeRotation(90 * M_PI/180);
            if (!willOpenKeyboard)
            {
                [self.delegate shouldChangeBottomOffsetTo:self.superview.frame.size.height - self.frame.origin.y canScroll:!willOpenKeyboard animated:YES];
            }
            [self layoutIfNeeded];
        } completion:^(BOOL finished){
            isActionSheetAnimating = NO;
        }];

    }

    
}

#pragma mark DoneButton

-(void) doneButtonClick:(id) sender
{
    [self closeBurnSlider];
    [self callDelegateWithAction:@selector(doneButtonClick:) object:sender];
}
#pragma mark BurnButton
-(void) closeBurnSlider
{
    if (burnButtonBackgroundTopConstraint.constant < 0)
    {
        [self burnButtonClick:burnButton];
    }
}
-(void) burnButtonClick:(id) sender
{
    if (burnButtonBackgroundTopConstraint.constant < 0)
    {
        isBurnSliderOpen = NO;
        [self hideBurnSlider];
        burnButtonBackgroundTopConstraint.constant = 3;
    } else
    {
        isBurnSliderOpen = YES;
        [burnButton setEnabled:NO];
        burnButtonBackgroundTopConstraint.constant -=220;
    }
    [UIView animateWithDuration:0.2f animations:^{
        [self layoutIfNeeded];
    } completion:^(BOOL finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (isBurnSliderOpen)
            {
                [self showBurnSlider:sender];
            } else
            {
                [burnButton setEnabled:YES];
            }
        });
    }];
    
    [self callDelegateWithAction:@selector(burnButtonClick:) object:sender];
}

#pragma mark ActionSheetScrolling

-(void) scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGPoint touchPositionIn_containerView = [scrollView.panGestureRecognizer locationInView:self];
    CGPoint touchPositionInViewController = [scrollView.panGestureRecognizer locationInView:self.superview];
    if(!isKeyboardDecelerating && !isKeyboardOpen && isActionSheetOpen && scrollView.panGestureRecognizer.state != UIGestureRecognizerStatePossible && !isActionSheetAnimating)
    {
        // drag down
        if (touchPositionIn_containerView.y  > 0) {
            CGRect containerViewFrame = self.frame;
            containerViewFrame.origin.y += touchPositionInViewController.y - lastTouchPositionInViewController.y;
            [self tryToSetContainerFrame:containerViewFrame];
            [self.delegate shouldChangeBottomOffsetTo:self.superview.frame.size.height - containerViewFrame.origin.y canScroll:NO animated:YES];
            //[self layoutIfNeeded];
            [self callDelegateWithAction:@selector(didSwipeActionSheet:) object:self];
            
        } else
        {
            // drag up
            if (actionSheetView.frame.origin.y > self.superview.frame.size.height - 250 && lastContentOffset < scrollView.contentOffset.y && self.frame.origin.y + self.frame.size.height < self.superview.frame.size.height) {
                CGRect containerViewFrame = self.frame;
                containerViewFrame.origin.y += touchPositionInViewController.y - lastTouchPositionInViewController.y;
                if (containerViewFrame.origin.y < self.superview.frame.size.height - 250 - 40 ) {
                    containerViewFrame.origin.y = self.superview.frame.size.height - 250 - 40;
                }
                [self tryToSetContainerFrame:containerViewFrame];
                [self.delegate shouldChangeBottomOffsetTo:self.superview.frame.size.height - containerViewFrame.origin.y canScroll:NO animated:YES];
               // [self layoutIfNeeded];
                [self callDelegateWithAction:@selector(didSwipeActionSheet:) object:self];
            }
        }
    }
    
    lastTouchPositionInViewController = touchPositionInViewController;
    lastContentOffset = scrollView.contentOffset.y;
}

-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    isKeyboardDecelerating = NO;
}

-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if(!isKeyboardOpen)
    {
        isKeyboardDecelerating = decelerate;
        CGPoint touchPositionIn_containerView = [scrollView.panGestureRecognizer locationInView:self];
        
        if(self.frame.origin.y < self.superview.frame.size.height - 250 /2 - self.frame.size.height || touchPositionIn_containerView.y > 70)
        {
            [self animateActionSheetOpen:NO];
        } else if (self.frame.origin.y <= self.superview.frame.size.height - self.frame.size.height)
        {
            [self animateActionSheetOpen:YES];
        }
    }
}

-(void) animateActionSheetOpen:(BOOL) open
{
    if(isActionSheetOpen && !isActionSheetAnimating)
    {
        if(open)
        {
            isActionSheetAnimating = YES;
            [UIView animateWithDuration:kActionSheetOpenSpeed animations:^(void){
                CGRect containerFrame = self.frame;
                containerFrame.origin.y = self.superview.frame.size.height - containerFrame.size.height;
                self.frame = containerFrame;
                [self.delegate shouldChangeBottomOffsetTo:self.superview.frame.size.height - containerFrame.origin.y canScroll:YES animated:YES];
                [self layoutIfNeeded];
                [self callDelegateWithAction:@selector(didSwipeActionSheet:) object:self];
                plusIconImageView.transform = CGAffineTransformMakeRotation(90 * M_PI/180);
                
            } completion:^(BOOL finished){
                dispatch_async(dispatch_get_main_queue(), ^{
                    isActionSheetOpen = NO;
                    isActionSheetAnimating = NO;
                });
            }];
        } else
        {
            if (actionSheetView.frame.origin.y + actionSheetView.frame.size.height > self.superview.frame.size.height)
            {
                isActionSheetOpen = YES;
                isActionSheetAnimating = YES;
                [UIView animateWithDuration:kActionSheetOpenSpeed animations:^(void){
                    CGRect containerFrame = self.frame;
                    containerFrame.origin.y = self.superview.frame.size.height - 250 - containerFrame.size.height;
                    self.frame = containerFrame;
                    [self.delegate shouldChangeBottomOffsetTo:self.superview.frame.size.height - containerFrame.origin.y canScroll:YES animated:YES];
                    [self callDelegateWithAction:@selector(didSwipeActionSheet:) object:self];
                    plusIconImageView.transform = CGAffineTransformMakeRotation(45 * M_PI/180);
                    [self layoutIfNeeded];
                } completion:^(BOOL finished)
                 {
                     isActionSheetAnimating = NO;
                 }];
            }
        }
    }
}

-(void)setFontForTextField:(UIFont *)font
{
    [_messageTextView setFont:font];
    
    containerViewHeight = font.pointSize;
    [_messageTextView.internalTextView setFont:font];
}

#pragma mark HPGrowingTextViewDelegate
-(void)growingTextViewDidChange:(HPGrowingTextView *)growingTextView
{
    [self closeBurnSlider];
}
- (void)growingTextView:(HPGrowingTextView *)growingTextView willChangeHeight:(float)height
{
    // change frames of actionSheet, _containerView and chatTable
    // according to textview changed height
    float diff = (growingTextView.frame.size.height - height);
    
    CGRect r = self.frame;
    r.size.height -= diff;
    r.origin.y += diff;
    self.frame = r;
    
    [self.delegate shouldChangeBottomOffsetTo:self.superview.frame.size.height - self.frame.origin.y canScroll:YES animated:YES];
    [self updateConstraints];
}



#pragma mark UI BUtton addition
-(void) addAttachmentButton:(UIButton *) actionSheetButton
{
    [accessibilityElements replaceObjectAtIndex:1 withObject:actionSheetButton];
    actionSheetButton.isAccessibilityElement = YES;
    actionSheetButton.accessibilityValue = @"Open action sheet";
    [actionSheetButton addTarget:self action:@selector(actionSheetButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    actionSheetButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:actionSheetButton];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[actionSheetButton]-0-[_messageTextView]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_messageTextView,actionSheetButton)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(2)-[actionSheetButton]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(actionSheetButton)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[actionSheetButton(40)]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:NSDictionaryOfVariableBindings(actionSheetButton)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[actionSheetButton(37)]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:NSDictionaryOfVariableBindings(actionSheetButton)]];
    
    actionSheetButton.layer.masksToBounds = YES;
    actionSheetButton.layer.cornerRadius = 25 / 2;
    
    // view covering spacing between rounded corners of textview and attachments button
    UIView *collapseView = [[UIView alloc] init];
    [collapseView setBackgroundColor:actionSheetButton.backgroundColor];
    collapseView.translatesAutoresizingMaskIntoConstraints = NO;
    collapseView.isAccessibilityElement = NO;
    [self addSubview:collapseView];
    [self sendSubviewToBack:collapseView];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[collapseView]-(-20)-[_messageTextView]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_messageTextView,collapseView)]];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(2)-[collapseView]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(collapseView)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[collapseView(40)]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:NSDictionaryOfVariableBindings(collapseView)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[collapseView(37)]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:NSDictionaryOfVariableBindings(collapseView)]];
    
    // seperate plusicon, because it rotates when opening attachment view
    [actionSheetButton updateConstraints];
    plusIconImageView = [[UIImageView alloc] initWithImage:actionSheetButton.imageView.image];
    plusIconImageView.translatesAutoresizingMaskIntoConstraints = NO;
    plusIconImageView.isAccessibilityElement = NO;
    [self addSubview:plusIconImageView];
    NSLayoutConstraint *centerX =[NSLayoutConstraint
                                   constraintWithItem:actionSheetButton
                                   attribute:NSLayoutAttributeCenterX
                                   relatedBy:NSLayoutRelationEqual
                                   toItem:plusIconImageView
                                   attribute:NSLayoutAttributeCenterX
                                   multiplier:1.0f
                                   constant:0.f];
    
    NSLayoutConstraint *centerY =[NSLayoutConstraint
                                  constraintWithItem:actionSheetButton
                                  attribute:NSLayoutAttributeCenterY
                                  relatedBy:NSLayoutRelationEqual
                                  toItem:plusIconImageView
                                  attribute:NSLayoutAttributeCenterY
                                  multiplier:1.0f
                                  constant:0.f];
    [self addConstraint:centerX];
    [self addConstraint:centerY];
    
   // plusIconImageView.center = button.center;
    [actionSheetButton setImage:[UIImage new] forState:0];
    _messageTextView.backgroundColor = actionSheetButton.backgroundColor;
}

-(void) addDoneButton:(UIButton *) doneButton
{
    [accessibilityElements replaceObjectAtIndex:3 withObject:doneButton];
    doneButton.isAccessibilityElement = YES;
    doneButton.accessibilityValue = @"Send";
    [doneButton addTarget:self action:@selector(doneButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    doneButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:doneButton];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[_messageTextView]-0-[doneButton]-0-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_messageTextView,doneButton)]];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[doneButton]-(0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(doneButton)]];
    
   // [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[doneButton(40)]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:NSDictionaryOfVariableBindings(doneButton)]];
    //[self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[doneButton(40)]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:NSDictionaryOfVariableBindings(doneButton)]];
    
    
    [self updateConstraints];
}

-(void) addBurnButton:(UIButton *) button
{
    button.accessibilityLabel = NSLocalizedString(@"Open burn slider", nil);
    button.isAccessibilityElement = YES;
    [accessibilityElements replaceObjectAtIndex:0 withObject:button];
    burnButton = button;
    [burnButton addTarget:self action:@selector(burnButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    burnButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:burnButton];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-2-[burnButton]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_messageTextView,burnButton)]];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(2)-[burnButton]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(burnButton)]];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[burnButton(34)]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:NSDictionaryOfVariableBindings(burnButton)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[burnButton(34)]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:NSDictionaryOfVariableBindings(burnButton)]];
    
    
    burnButton.layer.masksToBounds = YES;
    burnButton.layer.cornerRadius = 34 / 2;
    
    burnButtonBackgroundView = [[UIView alloc] init];
    [burnButtonBackgroundView setBackgroundColor:burnButton.backgroundColor];
    burnButtonBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    burnButtonBackgroundView.layer.masksToBounds = YES;
    burnButtonBackgroundView.layer.cornerRadius = 34 / 2;
    [burnButtonBackgroundView setUserInteractionEnabled:NO];
    
    [self addSubview:burnButtonBackgroundView];
    [self sendSubviewToBack:burnButtonBackgroundView];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-2-[burnButtonBackgroundView]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_messageTextView,burnButtonBackgroundView)]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[burnButtonBackgroundView]-(-34)-[burnButton]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(burnButtonBackgroundView,burnButton)]];
    
    burnButtonBackgroundTopConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(2)-[burnButtonBackgroundView]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(burnButtonBackgroundView)][0];
    [self addConstraint:burnButtonBackgroundTopConstraint];
    
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[burnButtonBackgroundView(34)]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:NSDictionaryOfVariableBindings(burnButtonBackgroundView)]];
   // [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[burnButtonBackgroundView(34)]" options:NSLayoutFormatAlignAllCenterY metrics:nil views:NSDictionaryOfVariableBindings(burnButtonBackgroundView)]];
    
    [self updateConstraints];
}

// sets view property on actionSheetView to be added as subview when actionsheet loads
// actionsheetView might not exist at this time
-(void) addActionSheetView:(UIView *) view
{
    if (!actionSheetView)
    {
        actionSheetView = [[ActionsheetView alloc] init];
        [actionSheetView addSubview:view];
        [self.superview addSubview:actionSheetView];
        [actionSheetView setBackgroundColor:[UIColor redColor]];
        [actionSheetView setFrame:CGRectMake(0, self.frame.origin.y + self.frame.size.height, self.frame.size.width, 250)];
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [actionSheetView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(0)-[view]-(0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(view)]];
        
        [actionSheetView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(0)-[view]-(0)-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(view)]];
        [actionSheetView updateConstraints];
        [self addObserver:actionSheetView forKeyPath:@"frame" options:NSKeyValueObservingOptionOld context:NULL];
    }
}

-(void) hideInputForNumberActionSheet
{
    for (UIView *view in self.subviews)
    {
        [view setHidden:YES];
    }
    [burnButton setHidden:NO];
    [burnButtonBackgroundView setHidden:NO];
}



#pragma mark Burn slider 

-(void)showBurnSlider:(id)sender
{
    if(!slider)
    {
        CGRect burnButtonRect = burnButton.frame;
        [burnButton setAccessibilityLabel:NSLocalizedString(@"Close burn slider", nil)];
        [UIView animateWithDuration:0.2f animations:^(void){
            [self layoutIfNeeded];
        } completion:^(BOOL finsihed){
            dispatch_async(dispatch_get_main_queue(), ^{
                
                slider = [[MessageBurnSliderView alloc] initWithFrame:CGRectMake(0,self.superview.frame.size.height - burnButtonRect.size.height, 200, burnButtonRect.size.height)];
                [slider setBurnSliderDelegate:self];
                
                CGAffineTransform trans = CGAffineTransformMakeRotation(-M_PI * 0.5);
                slider.transform = trans;
                
                if (!sliderObserverAdded)
                {
                    sliderObserverAdded = YES;
                    [self addObserver:slider forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:nil];
                }
                
                CGPoint burnOrigin = [self convertPoint:burnButton.frame.origin toView:self.superview];
                burnOrigin.y = self.frame.origin.y - slider.frame.size.height;
                slider.frame = CGRectMake(burnOrigin.x, burnOrigin.y, slider.frame.size.width, slider.frame.size.height);
                [self.superview addSubview:slider];
                
                [burnButton setEnabled:YES];
                [self layoutIfNeeded];
            });
        }];
    }
}

-(void) hideBurnSlider
{
    if(!slider)
        return;
    
    if (sliderObserverAdded)
    {
        sliderObserverAdded = NO;
        [self removeObserver:slider forKeyPath:@"frame"];
    }
    [burnButton setAccessibilityLabel:NSLocalizedString(@"Open burn slider", nil)];
    [burnButton setEnabled:NO];
    [UIView animateWithDuration:0.2f animations:^(void){
        [self layoutIfNeeded];
        
    } completion:^(BOOL finished) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [burnButton setEnabled:YES];
        });
    }];
    [slider deRegisterNotifications];
    [slider removeFromSuperview];
    slider = nil;
    
}

-(BOOL) tryToSetContainerFrame:(CGRect ) rect
{
    if (rect.origin.y > self.superview.frame.size.height - 250 - self.frame.size.height  && rect.origin.y < self.superview.frame.size.height - self.frame.size.height) {
        self.frame = rect;
        return YES;
    } else
    {
        return NO;
        /*self.frame = CGRectMake(0, self.superview.frame.size.height - self.frame.size.height, self.frame.size.width, self.frame.size.height);
        isActionSheetOpen = NO;*/
    }
}

-(NSInteger)accessibilityElementCount
{
    return 4;
}
-(id)accessibilityElementAtIndex:(NSInteger)index
{
    return accessibilityElements[index];
}

-(NSInteger)indexOfAccessibilityElement:(id)element
{
    return [accessibilityElements indexOfObject:element];
}

// We need to substract bottom layout guide offset when resetting frame from viewwilltransitionToSize:
#define kBottomLayoutOffset 20
-(void)setFrameForScreenSize:(CGSize)size
{
    CGRect frame = self.frame;
    frame.size.width = size.width;
    
    if (isActionSheetOpen)
    {
        frame.origin.y = size.height - actionSheetView.frame.size.height - self.frame.size.height - kBottomLayoutOffset;
    } else
    {
        frame.origin.y = size.height - self.frame.size.height - kBottomLayoutOffset;
    }
        
    CGRect actionsheetRect = actionSheetView.frame;
    actionsheetRect.size.width = size.width;
    actionSheetView.frame = actionsheetRect;
    self.frame = frame;
    [self updateConstraints];
}

#pragma mark Delegation
- (void)callDelegateWithAction:(SEL)action object:(id)obj {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if ([_delegate respondsToSelector:action])
    {
        [_delegate performSelector:action withObject:obj];
    }
#pragma clang diagnostic pop
}

#pragma mark - BurnSliderDelegate

-(void)burnSliderValueChanged:(long)newBurnTime {
    
    if(_delegate && [_delegate respondsToSelector:@selector(burnSliderValueChanged:)])
        [_delegate burnSliderValueChanged:newBurnTime];
}



@end
