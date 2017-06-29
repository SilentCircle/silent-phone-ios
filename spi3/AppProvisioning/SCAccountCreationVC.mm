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
//  SCAccountCreationVC.m
//  VoipPhone
//
//  Created by Eric Turner on 8/6/15.
//
//

#import "SCAccountCreationVC.h"
#import "Prov.h"
#import "SCProgressView.h"
//Categories
#import "UIDevice+Hardware.h"
#import "UIView+SCUtilities.h"

// prov.cpp line 920
int createUserOnWeb(const char *pUN, const char *pPWD,
                    const char *pEM, const char *pFN, const char *pLN,
                    void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);

int checkUserCreate(const char *pUN, const char *pPWD, const char *pdevID,
                    const char *pEM, const char *pFN, const char *pLN,
                    void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);


@implementation SCAccountCreationVC

@synthesize btCancel;
@synthesize tfEmail=tfEmail;
@synthesize tfFirstName=tfFirstName;
@synthesize tfLastName=tfLastName;
@synthesize tfDeviceName=tfDeviceName;
@synthesize lbAccountCreation=lbAccountCreation;



- (void)dealloc {
    [lbAccountCreation release];
    [btCancel release];
    [tfEmail release];
    [tfFirstName release];
    [tfLastName release];
    [tfDeviceName release];
    
    [super dealloc];
    NSLog(@"%s",__PRETTY_FUNCTION__);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"%s",__PRETTY_FUNCTION__);

    // Clear any text in textfields set in IB
    tfEmail.text = nil;
    tfFirstName.text = nil;
    tfLastName.text = nil;
    // Pre-populate the device name
    
    // Fetch the device name (set by user)
    NSString *deviceName = [[UIDevice currentDevice] name];
    
    // If the name has not been set for some reason
    // fetch the device platform
    if(deviceName.length == 0)
        deviceName = [[UIDevice currentDevice] platform];
    
    tfDeviceName.text = deviceName;
}

-(void)setTranslations{
    [super setTranslations];
    
    lbAccountCreation.text = NSLocalizedString(@"Account Creation", nil);
    // super sets this to "CREATE ACCOUNT" - reset here
    [self.btCreate setTitle:NSLocalizedString(@"CREATE", nil) forState:UIControlStateNormal];
    [btCancel setTitle:NSLocalizedString(@"CANCEL", nil) forState:UIControlStateNormal];
    
    [self setPlaceholderText:NSLocalizedString(@"Email", nil) textfield:tfEmail];
    [self setPlaceholderText:NSLocalizedString(@"First name", nil) textfield:tfFirstName];
    [self setPlaceholderText:NSLocalizedString(@"Last name", nil) textfield:tfLastName];

}

- (IBAction)onCancel:(id)sender {
    //JN: what's this about?
//   [self dismissViewControllerAnimated:NO completion:^(){}];
//    NSLog(@"%s",__PRETTY_FUNCTION__);    
//    if (0 && [self.delegate respondsToSelector:@selector(viewControllerDidCancelCreate:)]) {
//        [self.delegate viewControllerDidCancelCreate:self];
//    }
    if ([self.delegate respondsToSelector:@selector(viewControllerDidCancelCreate:)]) {
        [self.delegate viewControllerDidCancelCreate:self];
    }
}

/**
 * This method handles the create button tap action for this subclass.
 *
 * The button property and action are wired in IB.
 *
 * Note that the Prov superclass has an onCreatePress: method which
 * instantiates an instance of this class and calls the delegate,
 * (AppDelegate) to switch from the login vc (Prov) to this one.
 *
 * Here, we call the super startCheckProv method which does the
 * network provisiong calls and setup. The super method will call
 * inputIsValid method.
 */
- (IBAction)handleLocalCreateTap:(id)sender {

    //TODO: better email validation
    BOOL validEmail = [tfEmail.text containsString:@"@"];
    if (!validEmail) {
        [self alertWithTitle:NSLocalizedString(@"Invalid Input", nil)
                     message:NSLocalizedString(@"Email address appears to be invalid", nil)];
        return;
    }
        
    if (![self inputIsValid]) {
        [self alertWithTitle:NSLocalizedString(@"Invalid Input", nil)
                     message:NSLocalizedString(@"All fields are required", nil)];
    }        
    else {    
        NSString *un = self.tfUsername.text; NSString *pw = self.tfPassword.text;
        NSString *em = tfEmail.text; NSString *fn = tfFirstName.text;
        NSString *ln = tfLastName.text;
        
        self.view.userInteractionEnabled = NO;
        self.progressView.hidden = NO;
        [self securePasswordField];
        
        [self.scrollView scrollRectToVisible:self.ivLogo.frame animated:YES];        
        
        self.iProvStat=0;
        self.iPrevErr=0;   
        
        self.view.userInteractionEnabled = NO;
        self.progressView.hidden = NO;
        [self securePasswordField];
        
        /*
         * Added for SSO  (nice feature) -
         * Hide password checkbox and forgot my password views while
         * displaying progress view.
         */
        [UIView fadeOutView:self.pwdButtonsView duration:0 completion:nil];
        
        [self.progressView startAnimatingDots];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            int r;
            NSString *dId = [self keychainDevIdCreateIfNeeded];
            r=checkUserCreate(un.UTF8String, pw.UTF8String, dId.UTF8String, em.UTF8String, fn.UTF8String, ln.UTF8String, cbFnc, self);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                // Provisioning SUCCESS
                if(r==0){
                    [self.progressView stopAnimatingDots];
                    [self.progressView successWithCompletion:^{
                        [self onProvisioningSuccess];
                    }];                
                } 
                // Provisioning FAILED
                else {
                    [self resetProgress];
                    self.progressView.hidden = YES;
                    [self.btLogin setEnabled:YES];
                    self.view.userInteractionEnabled = YES;
                    
                    [UIView fadeInView:self.pwdButtonsView duration:kDefaultProvAnimationDuration completion:nil];
                                        
                    [self alertWithTitle:NSLocalizedString(@"Server Error", nil)
                                 message:NSLocalizedString(@"Failed to get API Key", nil)];
                }
            }); // end dispatch_async to main_queue
            
        }); // end dispatch_async to global queue
        
    } // end if/else !valid
    
} // end handleLocalCreateTap:

- (BOOL)inputIsValid {
    BOOL unAndpwd = [super inputIsValid];
        
    NSString *em = tfEmail.text;
    NSString *fn = tfFirstName.text;
    NSString *ln = tfLastName.text;
    NSString *dv = tfDeviceName.text;
    return (unAndpwd && 
            em && em.length > 0 &&
            fn && fn.length > 0 &&
            ln && ln.length > 0 &&
            dv && dv.length > 0
            );
}


#pragma mark - Textfield Methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // username
    if(textField==self.tfUsername){
        if(self.tfUsername.text.length<1) 
            return NO;
        [self.tfPassword becomeFirstResponder];
        return YES;        
    }
    // password
    else if(textField == self.tfPassword) {
        if (self.tfPassword.text.length <= 0) 
            return NO;        
        [tfEmail becomeFirstResponder];
        return YES;
    }
    // email
    else if(textField == tfEmail) {
        if (tfEmail.text.length <= 0) 
            return NO;        
        [tfFirstName becomeFirstResponder];
        return YES;
    }
    // firstname
    else if(textField == tfFirstName) {
        if (tfFirstName.text.length <= 0) 
            return NO;        
        [tfLastName becomeFirstResponder];
        return YES;
    }
    // lastname
    else if(textField == tfLastName) {
        if (tfLastName.text.length <= 0) 
            return NO;        
        [tfDeviceName becomeFirstResponder];
        return YES;
    }
    // devicename
    else if(textField == tfDeviceName) {
        if (tfDeviceName.text.length <= 0) 
            return NO;        
    }
    
    [self handleLocalCreateTap:nil];
    return YES;
}


#pragma mark - UI Utilities

- (void)resignAllResponders {
    [super resignAllResponders];
    [tfEmail resignFirstResponder];
    [tfFirstName resignFirstResponder];
    [tfLastName resignFirstResponder];
}

- (void)layoutViews {
    if (![self isViewLoaded]) {
        NSLog(@"%s\n\n CALLED BEFORE VIEW LOAD",__PRETTY_FUNCTION__);
        return;
    }
    
    NSLog(@"%s",__PRETTY_FUNCTION__);

    // Pin contentView edges to self.view to brace scrollview width
    NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:self.contentView
                                                                      attribute:NSLayoutAttributeLeading
                                                                      relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.view
                                                                      attribute:NSLayoutAttributeLeading
                                                                     multiplier:1.0
                                                                       constant:0];
    [self.view addConstraint:leftConstraint];
    
    NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:self.contentView
                                                                       attribute:NSLayoutAttributeTrailing
                                                                       relatedBy:NSLayoutRelationEqual
                                                                          toItem:self.view
                                                                       attribute:NSLayoutAttributeTrailing
                                                                      multiplier:1.0
                                                                        constant:0];
    [self.view addConstraint:rightConstraint];

    
    self.scrollView.contentSize = CGSizeMake(self.view.frame.size.width, 
                                             self.contentView.frame.size.height);

    [self.view needsUpdateConstraints];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}


@end
