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

#import <UIKit/UIKit.h>
#import "SCProgressView.h"
#import "SCProvisioningDelegate.h"


const char *tg_translate(const char *key, int iKeyLen);
#define T_TR(_T_KEY) tg_translate(_T_KEY, sizeof(_T_KEY)-1)
#define T_TRL(_T_KEY, _T_KL) tg_translate(_T_KEY, _T_KL)
#define T_TRNS(_T_KEY) [NSString stringWithUTF8String:tg_translate(_T_KEY, sizeof(_T_KEY)-1)]

void cbFnc(void *p, int ok, const char *pMsg);

/** SSO: the default Apple animation duration for most things */
static NSTimeInterval const kDefaultProvAnimationDuration = 0.35;


@class SCCheckbox;

@interface Prov : UIViewController <UITextFieldDelegate>

@property (assign, nonatomic) id<SCProvisioningDelegate> delegate;

@property (retain, nonatomic) IBOutlet UIImageView *ivLogo;

// Provisioning status flags (moved from ivars to properties 09/04/15
@property (assign, nonatomic) NSInteger iProvStat;
@property (assign, nonatomic) NSInteger iPrevErr;

// Textfields
@property (retain, nonatomic) IBOutlet UITextField *tfUsername;
@property (retain, nonatomic) IBOutlet UITextField *tfPassword;

// Buttons
@property (retain, nonatomic) IBOutlet UIButton *btLogin;   // changed from btSignIn
@property (retain, nonatomic) IBOutlet UIButton *btCreate;  // account creation button

// Views
@property (retain, nonatomic) IBOutlet UIView *bottomSpacerView;
@property (retain, nonatomic) IBOutlet UIView *contentView;
// textfields container view
@property (retain, nonatomic) IBOutlet UIView *inputContainer;
// Labels
@property (retain, nonatomic) IBOutlet UILabel *lbSubtitle; // "version 3.4.0"
@property (retain, nonatomic) IBOutlet UILabel *lbVersion; // "version 3.4.0"
// space between inputView and privacyView
@property (retain, nonatomic) IBOutlet UIView *midSpacerView; 

// password views
@property (assign, nonatomic) BOOL passwordViewsHidden;
@property (retain, nonatomic) IBOutlet UIView *passwordViewsContainer;
@property (retain, nonatomic) IBOutlet UIView *passwordFieldView;
@property (retain, nonatomic) IBOutlet UIView *pwdButtonsView;
@property (retain, nonatomic) IBOutlet SCCheckbox *pwdCheckbox;

// privacy views container
@property (retain, nonatomic) IBOutlet UIView *policiesContainer;

@property (retain, nonatomic) IBOutlet SCProgressView *progressView;

@property (retain, nonatomic) IBOutlet UIScrollView *scrollView;
// SubTitle container and views
@property (retain, nonatomic) IBOutlet UIView  *subTitleContainer; // lbSubtitle,lbVersion

// Setup
-(void)setTranslations;
- (void)setPlaceholderText:(NSString *)str textfield:(UITextField *)textfield;

// Provisioning
- (void)startCheckProv;
- (void)onProvisioningSuccess;
- (IBAction)onCreatePress:(id)sender;
- (BOOL)inputIsValid;
- (void) alertWithTitle:(NSString*)title message:(NSString*)msg;
// obscure password field if clear text
- (void)securePasswordField;
- (void)resetProgress;
- (BOOL)checkForNetwork;

// Layout
- (void)fadeOutView:(UIView *)aView duration:(NSTimeInterval)dur completion:(void (^)())competion;
- (void)fadeInView:(UIView *)aView duration:(NSTimeInterval)dur completion:(void (^)())competion;
- (void)layoutViews;
- (NSLayoutConstraint *)constraintForAttribute:(NSLayoutAttribute)attrib searchItem:(UIView *)sView;

- (void)resignAllResponders;
- (void)dismissKeyboard;


@end
