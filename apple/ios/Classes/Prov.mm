/*
Copyright (C) 2012, Tivi LTD, www.tiviphone.com. All rights reserved.
Copyright (C) 2012-2015, Silent Circle, LLC.  All rights reserved.

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
#import "Prov.h"
#import "SCCheckbox.h"
#import "SCProgressView.h"

static NSString * const kRecoveryURLString = @"https://accounts.silentcircle.com/account/recover/";
static NSString * const kTermsURLString    = @"https://accounts.silentcircle.com/terms/";
static NSString * const kPrivacyURLString  = @"https://accounts.silentcircle.com/privacy-policy/";
static NSString * const kTextfieldFontName = @"Arial";
static CGFloat const kTextfieldFontSize = 17.0;
#define kTextfieldFontColor [UIColor colorWithRed:246.0/255.0 green:243.0/255.0 blue:235.0/255.0 alpha:1.0]

const char *tg_translate(const char *key, int iKeyLen);
#define T_TR(_T_KEY) tg_translate(_T_KEY, sizeof(_T_KEY)-1)
#define T_TRL(_T_KEY, _T_KL) tg_translate(_T_KEY, _T_KL)
#define T_TRNS(_T_KEY) [NSString stringWithUTF8String:tg_translate(_T_KEY, sizeof(_T_KEY)-1)]

int hasIP();
char *trim(char *sz);
int checkProv(const char *pUserCode, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);
void cbFnc(void *p, int ok, const char *pMsg);
const char *getAPIKey();
int checkProvWithAPIKey(const char *aAPIKey, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);

int checkProvUserPass(const char *pUN, const char *pPWD, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);

static int iUserPassProv = 1;

@interface Prov ()
@property (retain, nonatomic) IBOutlet UIView *bottomSpacerView; 
@property (retain, nonatomic) IBOutlet UIView *contentView;
// textfields container view
@property (retain, nonatomic) IBOutlet UIView *inputView;
@property (retain, nonatomic) IBOutlet UILabel *lbVersion; // "version 3.4.0"
// space between inputView and privacyView
@property (retain, nonatomic) IBOutlet UIView *midSpacerView; 
// privacy views container
@property (retain, nonatomic) IBOutlet UIView *privacyView;
@property (retain, nonatomic) IBOutlet SCProgressView *progressView;
@property (retain, nonatomic) IBOutlet SCCheckbox *pwdCheckbox;
@property (retain, nonatomic) IBOutlet UIScrollView *scrollView;
@end

@implementation Prov

@synthesize bottomSpacerView=bottomSpacerView;
@synthesize btSignIn=btSignIn;
@synthesize btSignUp=btSignUp;
@synthesize contentView=contentView;
@synthesize inputView=inputView;
@synthesize lbVersion=lbVersion;
@synthesize midSpacerView=midSpacerView;
@synthesize privacyView=privacyView;
@synthesize progressView=progressView;
@synthesize pwdCheckbox=pwdCheckbox;
@synthesize scrollView=scrollView;
@synthesize tfUsername=tfUsername;
@synthesize tfPassword=tfPassword;
@synthesize tfToken=tfToken;
@synthesize uiBackgr=uiBackgr;
@synthesize uiNI=uiNI;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
       iProvStat=0;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [bottomSpacerView release];
    [btSignIn release];
    [btSignUp release]; //unused    
    [contentView release];
    [inputView release];
    [lbVersion release];
    [midSpacerView release];
    [privacyView release];
    [progressView release];
    [pwdCheckbox release];
    [scrollView release];
    [tfUsername release];
    [tfPassword release];
    [tfToken release]; //unused
    [uiBackgr release]; //unused
    [uiNI release]; //unused
    [super dealloc];
}


-(void)textFieldsHidden:(BOOL)b{
   
   if(iUserPassProv){
      [tfToken setHidden:YES];
      
      [tfUsername setHidden:b];
      [tfPassword setHidden:b];
   }
   else{
      [tfUsername setHidden:YES];
      [tfPassword setHidden:YES];
      
      [tfToken setHidden:b];
   }
}
-(void)setTranslations{
    //06/26/15 -------------------------------------------------------//
//   [tfPassword setPlaceholder:T_TRNS("Enter Password Here")];
//    [tfUsername setPlaceholder:T_TRNS("Enter Username Here")];
    
    // Clear any text in textfields set in IB
    tfUsername.text = nil;
    tfPassword.text = nil;
    // Set attributed string placeholder text
    [self setPlaceholderText:T_TRNS("Username") textfield:tfUsername];
    [self setPlaceholderText:T_TRNS("Password") textfield:tfPassword];
    
//   [btSignIn setTitle:T_TRNS("Join")];
    [btSignIn setTitle:T_TRNS("LOGIN") forState:UIControlStateNormal]; // USE "LOGIN" (for UIButton)
   //-----------------------------------------------------------------// 
    
    
   uiNI.title = T_TRNS("Welcome");
 //  self.navigationItem.title = T_TRNS("Welcomex");
   //[self navigationController].navigationBar.topItem.title =T_TRNS("Welcomey");
}

- (void)viewDidLoad
{
   [super viewDidLoad];
   [self testBackgroundReset];
   tfToken.delegate=self;
   tfPassword.delegate = self;
   tfUsername.delegate = self;
   
    progressView.hidden = YES;
    
   [btSignIn setEnabled:NO];
   
   tfToken.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
   //tfToken.enablesReturnKeyAutomatically=NO;
   [self setReturnKeyEnabled: NO];
   
   [self textFieldsHidden:NO];
       
   [self setTranslations];
    
    // Layout for various devices
    [self layoutViews];
    
    [self registerKeyboardListener];
    
    // Set version number in label
    NSString *vStr = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    lbVersion.text = [NSString stringWithFormat:@"version %@", vStr];
    lbVersion.accessibilityLabel = lbVersion.text;
    
    // Set checkbox handler
    [pwdCheckbox addTarget:self action:@selector(handleCheckboxTap) forControlEvents:UIControlEventTouchDown];    
}

- (void)setReturnKeyEnabled:(BOOL)b{

   return ;
   //is not working
   NSArray *windows = [[UIApplication sharedApplication] windows];
   for (UIWindow *window in [windows reverseObjectEnumerator])
   {
    	for (UIView *view in [window subviews])
    	{
    		if (!strcmp(object_getClassName(view), "UIKeyboard"))
    		{
            id k=view;
            [k setReturnKeyEnabled:b];
            break;
    			//return view;
    		}
    	}
   }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


#pragma mark - Textfield Methods

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
   
   NSString *nextString = [textField.text stringByReplacingCharactersInRange:range withString:string];
   
   if(iUserPassProv){
      
      if(tfUsername == textField){
         NSCharacterSet *nonUsername = [[NSCharacterSet characterSetWithCharactersInString:@"._ABCDEFGHIJKLMNOPQRSTUVWXYZqwertyuiopasdfghjklzxcvbnm1234567890"] invertedSet];
         
         if ([nextString stringByTrimmingCharactersInSet:nonUsername].length != nextString.length){
            return NO;
         }
      }
      
      UITextField * second = tfUsername == textField? tfPassword : tfUsername;
      BOOL ok = nextString.length > 0 && second.text.length > 0;
      
      [btSignIn setEnabled: ok ];
      [self setReturnKeyEnabled: ok];
      return YES;
   }
   
   
   if(nextString.length>16)return NO;
   
   NSCharacterSet *nonLettersNumbers = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"] invertedSet];
  
   
   if ([nextString stringByTrimmingCharactersInSet:nonLettersNumbers].length != nextString.length) {
      
      if([nextString.uppercaseString stringByTrimmingCharactersInSet:nonLettersNumbers].length != nextString.length)
         return NO;
      
      [textField setText: nextString.uppercaseString];
      return NO;
   }
   
   [btSignIn setEnabled:(nextString.length>=8)];
   [self setReturnKeyEnabled: nextString.length>=8];
   return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
   
   if(iUserPassProv){
      if(textField==tfUsername){
         if(tfUsername.text.length<1)return NO;
         [tfPassword becomeFirstResponder];
         return YES;
         
      }
      if(textField == tfPassword && tfPassword.text.length <= 0)return NO;
   }
   
   [self onSignInPress];
   return YES;
}

// Sets the given textfield with an attributed string using the given string
/**
 * This method is a setter to place an attributed string as placeholder
 * text on the given textfield.
 * 
 * @param str The string with which to initialize an attributed string
 * @param textfield The textfield on which to set the placeholder
 * attributed string.
 */
- (void)setPlaceholderText:(NSString *)str textfield:(UITextField *)textfield {
    UIFont *font = [UIFont fontWithName:kTextfieldFontName size:kTextfieldFontSize];
    NSDictionary *attribs = @{
                              NSFontAttributeName:font,
                              NSForegroundColorAttributeName:kTextfieldFontColor
                              };
    textfield.attributedPlaceholder = [[NSAttributedString alloc] initWithString:str 
                                                                      attributes:attribs];
}


#pragma mark - Keyboard Methods

- (void)registerKeyboardListener {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

/**
 * This method sets the scrollview edge insets with addtional height to
 * allow views lower in the content view to be visible above when the
 * keyboard appears, and scrolls the checkbox view to above the
 * keyboard.
 *
 * The textield container views and the view containing the checkbox
 * control are wrapped in the inputView container. Note that a point at
 * the bottom edge of the inputView container is tested to be contained
 * by the keyboard rect. This is to ensure that the checkbox container
 * view under the password textfield can be scrolled into view above
 * the keyboard.
 *
 * Note also, that the call to scroll the scrollview to a 1pt tall rect 
 * representing the bottom edge of the inputView is wrapped in a
 * dispatch_async block. This is to workaround the hidden Apple behavior
 * which automatically scrolls to the bottom of the lowest textfield 
 * subview when it becomes firstResponder _after_ the
 * scrollRectToVisible call. Dispatching to the main queue makes the
 * call to the scrollview happen after the Apple behavior.
 *
 * @param notification Sent by the NSNotificationCenter callback with
 * keyboard geometry info.
 */
- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGRect kbRect = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbRect.size.height, 0.0);
    scrollView.contentInset = contentInsets;

    CGRect vFrame = self.view.frame;
    CGRect bottomEdge = CGRectMake(0.0, CGRectGetMaxY(inputView.frame), vFrame.size.width, 1.0);
    CGPoint bottomInputPoint = bottomEdge.origin;

    CGRect aRect = self.view.frame;
    aRect.size.height -= kbRect.size.height;    
    if (!CGRectContainsPoint(aRect, bottomInputPoint)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.scrollView scrollRectToVisible:bottomEdge animated:YES];
        });        
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    scrollView.contentInset = contentInsets;
}

- (void)dismissKeyboard {
    [tfUsername resignFirstResponder];
    [tfPassword resignFirstResponder];
}


#pragma mark Show Password
- (void)handleCheckboxTap {
    tfPassword.secureTextEntry = !pwdCheckbox.isChecked;
}

#pragma mark Forgot Password
- (IBAction)handleForgotPasswordTap:(id)sender {
    [self dismissKeyboard];
    [self launchSarariWithURLString:kRecoveryURLString];
}

#pragma mark Show Terms of Service
- (IBAction)handleTermsTap:(id)sender {
    [self dismissKeyboard];
    [self launchSarariWithURLString:kTermsURLString];
}

#pragma mark Show Terms of Service
- (IBAction)handlePrivacyTap:(id)sender {
    [self dismissKeyboard];
    [self launchSarariWithURLString:kPrivacyURLString];
}

- (void)launchSarariWithURLString:(NSString *)str {
    NSAssert(str != nil && str.length > 0, @"URL string must not be nil or blank");    
    NSURL *recoveryURL = [[NSURL alloc] initWithString:str];
    [[UIApplication sharedApplication] openURL:recoveryURL];    
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
   return UIStatusBarStyleLightContent;
}

-(void)provOk{
   [_provResponce onProvResponce:1];
   [self dismissViewControllerAnimated:YES completion:^(){}];
}

-(void)startCheckPorv:(void *)unused{
   iProvStat=0;
   iPrevErr=0;   
   
    self.view.userInteractionEnabled = NO;
    progressView.hidden = NO;
    [progressView start];
    
   [self textFieldsHidden:YES];
   
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      int r;
      char bufC[128];
      
      if(iUserPassProv){
         const char *p=[tfUsername.text UTF8String];
         
         strncpy(bufC,p,127);
         bufC[127]=0;
         trim(&bufC[0]);
          
          //Test progressView
//          for(int i=0;i<15;i++){
//              cbFnc(self, 1, "aa");
//              usleep(100*1000*2);
//          }
//          cbFnc(self, 1, "aa");
//          r=0;
         r=checkProvUserPass(&bufC[0],tfPassword.text.UTF8String, cbFnc, self);
          
      }
      else{
         const char *p=[tfToken.text UTF8String];
         
         strncpy(bufC,p,127);
         bufC[127]=0;
         
         trim(&bufC[0]);
         r=checkProv(&bufC[0], cbFnc, self);
      }
      
       __unsafe_unretained typeof(self) weakSelf = self;       
      dispatch_async(dispatch_get_main_queue(), ^{
          
          __strong typeof(weakSelf) strongSelf = weakSelf;          
         [strongSelf textFieldsHidden:NO];
         [strongSelf.btSignIn setEnabled:YES];

          NSLog(@"\nSTOP progress -- (startCheckPorv: dispatch-to-main-queue)");
          [strongSelf.progressView stop];

          if(r==0){
              [progressView successWithCompletion:^{
                  [strongSelf provOk];
              }];                
          } else {
              [strongSelf.progressView stop];
              [strongSelf.progressView resetProgress];
              strongSelf.progressView.hidden = YES;
              self.view.userInteractionEnabled = YES;
          }
      });
   });
   

     
}

-(IBAction)onBtPress{
 //  const char *p=[tfToken.text UTF8String];
  //    [self provOk];
}

-(IBAction)onSignUpPress{
   NSString* launchUrl = [NSString stringWithFormat:@"https://accounts.silentcircle.com"];
   [[UIApplication sharedApplication] openURL:[NSURL URLWithString: launchUrl]];
}

-(IBAction)onSignInPress{
   
   if(!hasIP()){
      [self showMsgMT:T_TRNS("Network not available") msg:""];
      return;
   }
   
   [tfUsername resignFirstResponder];
   [tfPassword resignFirstResponder];
   [tfToken resignFirstResponder];

   [self performSelector:@selector(startCheckPorv:) withObject:nil afterDelay:.1];
   
}

-(void)showMsgMT:(NSString *)title msg:(const char*)msg{
   NSString *m= [NSString stringWithUTF8String:msg];  
   UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                   message:m 
                                                  delegate:nil 
                                         cancelButtonTitle:nil
                                         otherButtonTitles:@"Ok",Nil];
   [alert show];
   [alert release];
}
-(void)cbTLS:(int)ok  msg:(const char*)msg {
   NSLog(@"prov=[%s] %d",msg,ok);
   
   if(ok<=0){
      if(iPrevErr==-2)return;
      iPrevErr=ok;
      dispatch_async(dispatch_get_main_queue(), ^{
         
//         [self showMsgMT:T_TRNS("No provisioning data available")  msg:msg];//#SP-635
         [self showMsgMT:@" "  msg:msg];

      });
   }
   else{
         iProvStat++;
      
         dispatch_async(dispatch_get_main_queue(), ^{
            float f=(float)iProvStat/16.;
             NSLog(@"iProvStat:%1.2d / 16. = f(%1.2f)",iProvStat,f);
            if(f>1.)f=1.;
             [progressView setProgress:f];
         });
   }
}


#pragma mark - UI Utilities

- (void)layoutViews {
    // Pin contentView edges to self.view to brace scrollview width
    NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:self.contentView
                                                                      attribute:NSLayoutAttributeLeading
                                                                      relatedBy:0
                                                                         toItem:self.view
                                                                      attribute:NSLayoutAttributeLeft
                                                                     multiplier:1.0
                                                                       constant:0];
    [self.view addConstraint:leftConstraint];
    
    NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:self.contentView
                                                                       attribute:NSLayoutAttributeTrailing
                                                                       relatedBy:0
                                                                          toItem:self.view
                                                                       attribute:NSLayoutAttributeRight
                                                                      multiplier:1.0
                                                                        constant:0];
    [self.view addConstraint:rightConstraint];
    
    // Calculate the midSpaceView height to expand or contract for 
    // current device screen height.
    CGRect bounds = [[UIScreen mainScreen] bounds];
    CGFloat screenH = MAX(bounds.size.width, bounds.size.height);
    CGFloat viewElementsH = CGRectGetMaxY(inputView.frame) + CGRectGetHeight(privacyView.frame) + CGRectGetHeight(bottomSpacerView.frame);
    CGFloat midSpaceH = screenH - viewElementsH;
    NSLayoutConstraint *mSpacerViewH = [self constraintForAttribute:NSLayoutAttributeHeight 
                                                         searchItem:midSpacerView];
    mSpacerViewH.constant = midSpaceH;
}

/**
 * This utility method returns a "single attribute", i.e., width or 
 * height, NSLayoutConstraint for the given attrib argument, in the
 * given searchItems constraint array.
 *
 * @param attrib NSLayoutAttributeWidth or NSLayoutAttributeHeight; 
 * calling this method with any other NSLayoutAttribute is undefined.
 *
 * @param sView The view object for which to find a constraint.
 * @return The constraint for the given attribute, or nil if not found.
 */
- (NSLayoutConstraint *)constraintForAttribute:(NSLayoutAttribute)attrib searchItem:(UIView *)sView {    
    for (NSLayoutConstraint *constraint in sView.constraints) {        
        if (constraint.firstItem == sView && constraint.firstAttribute == attrib) {
            return constraint;
        }
    }    
    return nil;
}


#pragma - JN TESTS
+(UIImage*)getSplashImage{
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    if ([UIScreen mainScreen].scale == 2.f && screenHeight == 568.0f) {
        return [UIImage imageNamed:@"Default-568h.png"];
    }
    return [UIImage imageNamed:@"Default.png"];
}

-(void)testBackgroundReset{
    
    [uiBackgr setImage:[Prov getSplashImage]];
}


@end

void cbFnc(void *p, int ok, const char *pMsg){
   Prov *pr=(Prov*)p;
   if(pr){
      [pr cbTLS:ok msg:pMsg];
   }
}
