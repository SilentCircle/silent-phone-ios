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

#import "Prov.h"
#import "SCCheckbox.h"
#import "SCProgressView.h"
#import "SCAccountCreationVC.h"
#import "SSOWebVC.h"
#import "STKeychain.h"


//----------------------------------------------------------------------
#pragma mark - FEATURE CONSTANTS
/*
 * Uncomment #define statements to enable features.
 *
 * WARNING:
 * ONLY enable any of these features (uncomment the #defines) on a
 * feature or develop branch. These features are NOT production-ready
 * yet. 09/14/15
 *
 * Note:
 * USE_DEV_NETWORK must be defined when ENTERPRISE_LOGIN_ENABLED or
 * ACCOUNT_CREATION_ENABLED constants are defined, while in development.
 * That is, enterprise login and account creation are features that 
 * currently only work on the developer network.
 */

// Switch for using dev network or production (default) network
//#define USE_DEV_NETWORK

// Switch for enabling account creation UI and server calls
// 09/30/15 Always on - #ifdefs removed
//#define ENTERPRISE_LOGIN_ENABLED

// Switch for enabling account creation UI and server calls
#define ACCOUNT_CREATION_ENABLED

// Switch for enabling freemium feature (ET: not sure what this does yet)
#define FREEMIUM_ENABLED


// SSO login string constants (may need more appropriate naming)
//static NSString * const kSCEnterpriseUrlPrefix = @"https://accounts-dev.silentcircle.com/v1/auth_domain";
static NSString * const kSCEnterpriseUrlPrefix = @"https://accounts.silentcircle.com/v1/auth_domain";
static NSString * const kSCEnterpriseUrlScheme = @"silentcircle-entapi";

// Top constraint space height for moving policy views container view up
// when pasword views are hidden (sso)
static CGFloat const kPolicyViewsHiddenTopH = 12.0;

//----------------------------------------------------------------------


//----------------------------------------------------------------------
static NSString * const kRecoveryURLString = @"https://accounts.silentcircle.com/account/recover/";
static NSString * const kTermsURLString    = @"https://accounts.silentcircle.com/terms/";
static NSString * const kPrivacyURLString  = @"https://accounts.silentcircle.com/privacy-policy/";
static NSString * const kTextfieldFontName = @"Arial";
static CGFloat const kTextfieldFontSize = 17.0;
#define kTextfieldFontColor [UIColor colorWithRed:246.0/255.0 green:243.0/255.0 blue:235.0/255.0 alpha:1.0]
//----------------------------------------------------------------------


//----------------------------------------------------------------------
#pragma mark - C Function Declarations
//----------------------------------------------------------------------
int hasIP();
char *trim(char *sz);
int checkProv(const char *pUserCode, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);

const char *getAPIKey();
int checkProvWithAPIKey(const char *aAPIKey, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);

void cbSsoFnc(void *p, int code, const char *pMsg);
int checkProvUserPass(const char *pUN, const char *pPWD, const char *pdevID, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);
int checkProvAuthCookie(const char *pUN, const char *auth_cookie, const char *pdevID, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);
int getDomainAuthURL(const char *pLink, const char *pUN, char *auth_url, int auth_url_sz, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);
//----------------------------------------------------------------------


/** Added for SSO */
typedef NS_ENUM(NSInteger, SC_ProvCode) {
// prov.cpp
// getDomainAuthURL() begins with call to download_page2Loc:
// download_page2Loc() returns NULL if:
//   1) the url is malformed (line 287)
//   2) no provisioning cert (line 316)
//   3) s->getContent() returns NULL
//        
//   1 & 2 we aren't worried about because they already do their own cb() notification.
//   For 3, getContent() only returns NULL if iBytesReceived<=0.
//    
    // ERR: Failed to download JSON
    sso_no_json_err = -4,

//  Our SSO server returned JSON which did not include an auth_type field value
//    
    // "ERR: JSon field 'auth_type' not found”
    sso_no_auth_type_err = -3,

//    accounts.silentcircle.com server sent us a auth_type we didn't understand.
//    We need to handle this better. The scenario is an older client trying to log
//    in via an Enterprise LDAP (?) account.
//    
    // ERR: Server reported auth_type other than adfs!
    sso_wrong_auth_type_err = -2,
    
//    accounts.silentcircle.com again.
//    This is a malformed JSON issue, for which there is no way to continue.
//    
    // ERR: JSon field 'auth_url' not found
    sso_no_auth_url_err = -1
    
};

@interface Prov() <UIWebViewDelegate> 

/** The UIWebView subclass used for SSO authentication */
@property (retain, nonatomic) SSOWebVC *webVC;

/** Storage for policiesContainer NSLayoutAttributeTop height */
@property (assign, nonatomic) CGFloat cachedPoliciesTopH;

//@property (copy, nonatomic) NSString *lcUsername; // UNUSED: 09/25/15
@property (assign, nonatomic) BOOL existingDevIdFound;

@property (assign, nonatomic) SC_ProvCode sso_err;
@end


@implementation Prov

@synthesize bottomSpacerView=bottomSpacerView;
@synthesize btLogin=btLogin;
@synthesize btCreate=btCreate;
@synthesize cachedPoliciesTopH=cachedPoliciesTopH; // SSO
@synthesize contentView=contentView;
@synthesize iPrevErr=iPrevErr;   // from ivar to property for SSO
@synthesize iProvStat=iProvStat; // from ivar to property for SSO
@synthesize inputContainer=inputContainer; //renamed for SSO 
@synthesize ivLogo=ivLogo;
@synthesize lbSubtitle=lbSubtitle;
@synthesize lbVersion=lbVersion;
@synthesize midSpacerView=midSpacerView;
@synthesize passwordFieldView=passwordFieldView; // SSO unused?
@synthesize pwdButtonsView=pwdButtonsView; // SSO unused?
@synthesize passwordViewsContainer=passwordViewsContainer; //added for SSO 
@synthesize policiesContainer=policiesContainer; //renamed for SSO 
@synthesize progressView=progressView;
@synthesize pwdCheckbox=pwdCheckbox;
@synthesize scrollView=scrollView;
@synthesize subTitleContainer=subTitleContainer;
@synthesize tfUsername=tfUsername;
@synthesize tfPassword=tfPassword;


- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [bottomSpacerView release];
    [btLogin release];
    [btCreate release];
    [contentView release];
    [inputContainer release];
    [ivLogo release];
    [lbSubtitle release];
    [lbVersion release];
//    [_lcUsername release]; // UNUSED: 09/25/15
    [midSpacerView release];
    [passwordViewsContainer release];
    [policiesContainer release];
    [progressView release];
    [pwdCheckbox release];
    [scrollView release];
    [subTitleContainer release];
    [tfPassword release];
    [tfUsername release];    
    _webVC.webView.delegate = nil;
    [_webVC release];
    
    [super dealloc];
    NSLog(@"%s",__PRETTY_FUNCTION__);
}

-(void)setTranslations{
    
    // Set attributed string placeholder text
    [self setPlaceholderText:T_TRNS("Username") textfield:tfUsername];
    [self setPlaceholderText:T_TRNS("Password") textfield:tfPassword];
    
    [btLogin setTitle:T_TRNS("LOGIN") forState:UIControlStateNormal];
    
    // Hidden in IB
#ifdef ACCOUNT_CREATION_ENABLED
    btCreate.hidden = NO;
    [btCreate setTitle:T_TRNS("CREATE ACCOUNT") forState:UIControlStateNormal];
#endif
    
}

/*
 * This method is called when the view is first loaded into memory,
 * usually from a xib or storyboard, and before it is drawn. This is
 * only called once, at the beginning of the life of the view controller.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];

#ifdef USE_DEV_NETWORK   
        void setProvisioningToDevelop();
        setProvisioningToDevelop();
#endif
    
    // Clear any text in textfields set in IB
    tfUsername.text = nil;
    tfPassword.text = nil;
    [self registerTextfieldListeners];
    // Set checkbox handler
    [pwdCheckbox addTarget:self 
                    action:@selector(handleCheckboxTap) 
          forControlEvents:UIControlEventTouchDown];
    
    progressView.hidden = YES;
    
    [self setTranslations];    
    
    // Layout for various devices
    cachedPoliciesTopH  = [[self constraintInSuperviewForAttribute:NSLayoutAttributeTop 
                                                        searchItem:policiesContainer] constant];
    [self layoutViews];
    
    [self registerKeyboardListener];    
    
    // Update version label
    // Set version number in label
    NSString *vStr = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    
    lbVersion.text = [NSString stringWithFormat:@"%@ %@", T_TRNS("version"), vStr];
    lbVersion.accessibilityLabel = lbVersion.text;


#ifdef FREEMIUM_ENABLED    

    [btLogin setEnabled:NO];
   
   //we have to hide it here and do check with API server do we have freemium
   [btCreate setHidden:YES];
   dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      
      char b[2048];
      char url[256];
      
      BOOL hasFreemium = NO;//getFreemiumStatus()
      
      const char *t_getVersion(void);
      char* t_send_http_json(const char *url, const char *meth,  char *bufResp, int iMaxLen, int &iRespContentLen, const char *pContent);
      
      const char *url_wo_vers = "/v1/freemium_check/?os=ios&version=";
      snprintf(url, sizeof(url), "%s%s",url_wo_vers, t_getVersion());
      
      int iRespLen = 0;
      
      char *p = t_send_http_json(url, "GET", b, sizeof(b)-1, iRespLen, NULL);
      if(p && iRespLen>0){
         p[iRespLen] = 0;
         
         NSData *data = [[NSString stringWithUTF8String:p ] dataUsingEncoding:NSUTF8StringEncoding];
         NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                                  options:kNilOptions
                                                                    error:nil];
         if(json){
            NSNumber *b = json[@"freemium_enabled"];
            hasFreemium = b.boolValue;
           // NSLog(@"b=%@\n%@",b, json);
         }
         
      }  
      
      //[object performSelector:@selector(doSomething:) withObject:@YES];
      usleep(200*1000);

      if(hasFreemium){
         dispatch_async(dispatch_get_main_queue(), ^(void) {
            [btCreate setHidden:NO];
         });
      }
   });
#endif
     
}


#pragma mark - Decide login path
/*
 * We don't need to ask the user what type of account they have.  We can
 * determine it from the username
 */
- (void)decideLoginPath {
    NSLog(@"%s", __PRETTY_FUNCTION__);

    [self resignAllResponders];
    
    //
    // Enterprise login mode: username contains "@"
    //
    if ([tfUsername.text containsString:@"@"]) {
        
        [self.btLogin setEnabled:NO];
        self.view.userInteractionEnabled = NO;
        progressView.hidden = NO;
        
        [progressView startAnimatingDots];
        
        [self getDomainAuthForUser:tfUsername.text
                   completionBlock:^(NSURL *url, int errorCode) {
                       
                       [self resetProgress];
                       self.progressView.hidden = YES;
                       [self.btLogin setEnabled:YES];
                       self.view.userInteractionEnabled = YES;
                       
                       // Consider non-nil url a success, so fire off
                       // the web view with the url. It should load an
                       // enterprise server ADFS login page.
                       if(url)
                       {
                           NSLog(@"\n\tpresent webView with URL returned from domainAuthForUser: (as string): \n%@", url.absoluteString);
                           [self presentWebViewWithURL:url];
                       }
                       // Handle error for code
                       else if (errorCode != 0) {
                           [self handleSsoFailureWithCode:errorCode];
                       }
                       // FALLBACK to individual login
                       else
                       {
                           NSLog(@"%@%@%@",
                                 @"\ndecideLoginPath:\n\tWARNING:no url was returned from getDomainAuthForUser: ",
                                 tfUsername.text,
                                 @", and errorCode is 0. Fall back to Individual login UI.");

                           [self handleIndividualOption];
                       }
                   }];
    }
    // Individual login
    else {
        [self handleIndividualOption];
    }        
}

#pragma mark - SSO Individual Option Handler

/**
 * "Individual" login means username and password login, as distinct
 * from "enterprise" login, or SSO.
 */
- (void)handleIndividualOption {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    // Show the password views with fade-in and place cursor
    // in username or password textfield
    if (_passwordViewsHidden) {
        [self showHiddenEnterpriseLoginViewsWithAnimation:YES completion:^{
            if (tfUsername.text && tfUsername.text.length > 0)
                [tfPassword becomeFirstResponder];
            else
                [tfUsername becomeFirstResponder];
        }];
    }
    else {
        [self startCheckProv];
    }
}

#pragma mark - SSO Enterprise Login Methods

-(BOOL)getDomainAuthForUser:(NSString*)userName
            completionBlock:(void (^)( NSURL* url, int errorCode))completionBlock
{
    BOOL result = NO;
    
    NSRange range = [userName rangeOfString : @"@"];
    if(range.location != NSNotFound)
    {        
        NSString *pLink = [NSString
                           stringWithFormat:@"%@/%@/", 
                           kSCEnterpriseUrlPrefix, 
                           [userName substringFromIndex:range.location+1]
                           ];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            NSURL * url = NULL;
            
            int errorCode = 0;
            
            char auth_url[2048];
            
            memset(auth_url, 0, sizeof(auth_url));
            
            // Receive ADFS URL from domainname query
            errorCode = getDomainAuthURL(pLink.UTF8String,
                                         userName.UTF8String,
                                         auth_url, sizeof(auth_url),
                                         cbSsoFnc, self);
            
            if(errorCode == 0)
            {
                NSString*  urlString = [NSString stringWithUTF8String: auth_url];
                url = [NSURL URLWithString: [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            }
            
            if(completionBlock)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    (completionBlock)(url, errorCode);
                });
            }
        });
    }
    else
    {
        NSLog(@"Not a valid email address");
    }
    
    return result;
}

-(void) presentWebViewWithURL:(NSURL *)inURL
{
    // Intialize with URL, make self the webView delegate to dismiss
    // loadingView, error handling, etc.
    SSOWebVC *webVC = [SSOWebVC ssoWebVCWithURL:inURL delegate:self];    
    
    // Initialize a navigationController wrapper programmatically
    UINavigationController *navcon = [[[UINavigationController alloc] initWithRootViewController:webVC] autorelease];
    
    // Set Cancel bar button
    UIBarButtonItem *bbtn = [self cancelBarButtonItemWithAction:@selector(dismissWebVC)];
    webVC.navigationItem.leftBarButtonItem  = bbtn;
    
    self.webVC = [webVC retain]; // persist a handle to the webVC property instance
    
    // Cross dissolve presentation:
    // default is UIModalTransitionStyleCoverVertical which slides up 
    // from bottom and dismisses sliding down.
    navcon.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    // Present the navigationController    
    [self presentViewController:navcon animated:YES completion:nil];
}

/**
 * Dismiss the webVC to return to the self view.
 */
- (void)dismissWebVC {
    NSLog(@"%s called",__PRETTY_FUNCTION__);
    
    self.webVC.webView.delegate = nil;
    
    [self resetProgress];
    
    [self dismissViewControllerAnimated:YES completion:^{
        self.webVC = nil;
    }];
}


#pragma mark - SSO UIWebViewDelegate Methods

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
   
    NSLog(@"%s\n\tcalled with request url string:\n%@",__PRETTY_FUNCTION__, request.URL.absoluteString);
    
    BOOL shouldLoad = YES;
    
    if([request.URL.scheme isEqualToString:kSCEnterpriseUrlScheme]){
        NSString *URLString = [[request URL] absoluteString];
        
        if ([URLString containsString:@"code="]) {
            NSString *accessToken = [[URLString componentsSeparatedByString:@"="] lastObject];
            
            shouldLoad = NO;
            
            [self dismissWebVC];
            
            /* start the progress again in progressView */
            self.view.userInteractionEnabled = NO;
            [self resetProgress];
            progressView.hidden = NO;
            [progressView startAnimatingDots];
    
            
            /* use the accessToken to retrieve the api_key */
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSString *UN = tfUsername.text;
                int r;
                
//                NSString *dId = [STKeychain getDecodedDeviceId];
                NSString *dId = [self keychainDevIdCreateIfNeeded];
                
                // Not sure if checkProvUserPass(...) can handle nil devId param.
                // So if there is no existing long term devId,
                // (we wouldn't expect one unless this is a re-install), 
                // set to empty string.
                dId = (dId) ?: @""; 
                
                r = checkProvAuthCookie([UN cStringUsingEncoding:NSUTF8StringEncoding],
                                        [accessToken cStringUsingEncoding:NSUTF8StringEncoding],
                                        dId.UTF8String,
                                        cbSsoFnc, self);
                                
                dispatch_async(dispatch_get_main_queue(), ^{
                                                            
                    // FAILED
                    if(r != 0) {
                        
                        NSLog(@"ERROR: Failed to get API Key");
                        [self alertWithTitle:@"" message:T_TRNS("Failed to get API Key")];
                        return;
                    } 
                    
                    // SUCCESS
                    NSLog(@"\ncheckProvAuthCookie() SUCCESS");
                    [progressView successWithCompletion:^{
                        [self onProvisioningSuccess];
                    }];
                    
                }); // end dispatch_async to main_queue
                
            }); // end dispatch_async to global_queue
            
        } // end if (URLString contains "code="

    } // end request.URL.scheme is kSCEnterpriseUrlScheme
    
    return shouldLoad;
    
} // end webView:shouldStartLoadWithRequest:navigationType:


/**
 * Handles UI configuration for a given SSO status code.
 *
 * NOTE: Only getDomainAuthURL() status codes are supported here yet.
 * So far, we display the same alert for all SSO codes.
 *
 * @param code An SSO process status int, defined in SC_ProvCode enum.
 *
 * @return user-facing alert messages for the given status code.
 */
- (void)handleSsoFailureWithCode:(SC_ProvCode)code {
    NSLog(@"%s called with code: %ld", __PRETTY_FUNCTION__, (long)code);

    switch (code) {
        // These are all getDomainAuthForUser() errors.
        // Present an alert
        case sso_no_json_err:          // -4
        case sso_no_auth_type_err:     // -3
        case sso_wrong_auth_type_err:  // -2
        case sso_no_auth_url_err: {    // -1
            NSString *errMsg = [self alertMessageForStatusCode:code];
            [self alertWithTitle:@"" message:errMsg];
        }
            break;
            
        default:
            break;
    }
    
    // @see removeDevIdForProvFailIfNeeded method documentation
    [self removeDevIdForProvFailIfNeeded];
    
    [self resetProgress];
    self.progressView.hidden = YES;
    [self.btLogin setEnabled:YES];
    self.view.userInteractionEnabled = YES;

}

/**
 * Alert message string for a given SSO status code.
 *
 * NOTE: Only getDomainAuthURL() status codes are supported here yet.
 *
 * @param code An SSO process status int, defined in SC_ProvCode enum.
 *
 * @return user-facing alert messages for the given status code.
 */
- (NSString *)alertMessageForStatusCode:(SC_ProvCode)code {
    
    switch (code) {
        case sso_no_json_err:          // -4
        case sso_no_auth_type_err:     // -3
        case sso_wrong_auth_type_err:  // -2
        case sso_no_auth_url_err: {    // -1
            NSString *domain = [[tfUsername.text componentsSeparatedByString:@"@"] lastObject];
            return [NSString stringWithFormat:@"%@%@%@%@",
                    T_TRNS("An enterprise server could not be located, "),
                    T_TRNS("or could not be authenticated, for the "),
                    domain,
                    T_TRNS(" domain")];
        }
        default:
            // default to unknown
            break;
    }
    
    // Unknown
    return T_TRNS("An unknown server error has occurred");
}

/*
 * The webView may take a while to load a URL. The loadingView
 * (SC logo with "connecting" message -see in IB) will display until
 * self, as the webView delegate, gets this callback. This method fades
 * out the loadingView.
 */
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSLog(@"%s",__PRETTY_FUNCTION__);
    
    [self fadeOutView:self.webVC.loadingView 
             duration:kDefaultProvAnimationDuration 
           completion:nil];
}

/**
 * For webView load failure, dismiss the webView and display an error
 * alertView.
 *
 * JC - This throws even on successful login.   I suspect that's because we are
 * capturing an unknown redirect uri (silentcircle-entapi://)
 *
 * The ADFS SSO webpage reloads on failed password, so we need to figure out
 * how to exit cleanly when the user gives up...
 *
 * ET: while the webView is in view, if user wants to give up, he/she
 * can use the Cancel button, top left on the navBar.
 */
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"%s called",__PRETTY_FUNCTION__);
    
    
    // Ignore if this is the enterpise redirect
    if([webView.request.URL.scheme isEqualToString:kSCEnterpriseUrlScheme]){
        return;
    }
    
    NSString *strURL = webView.request.URL.path;
    if ([strURL containsString:@"redirect"]) {
        NSLog(@"%s\n\tIgnoring call with \"redirect\" in URL path",__PRETTY_FUNCTION__);
        return;
    }
    
    NSLog(@"%s\nERROR: loading url: %@", __PRETTY_FUNCTION__, strURL);

    NSString *domain = [[tfUsername.text componentsSeparatedByString:@"@"] lastObject];
    NSString *msg = [NSString stringWithFormat:@"%@%@%@",
                     T_TRNS("An Enterprise server for the "),
                     domain,
                     T_TRNS(" domain did not respond.")];
    
    UIAlertController *ac = [UIAlertController
                             alertControllerWithTitle:@""  //T_TRNS("Error")
                             message:msg
                             preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction
                               actionWithTitle:T_TRNS("Dismiss")
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action) {
                                    NSLog(@"WebViewDidFail alert Dismiss button - dismiss webVC");
                                   [self dismissWebVC];
                               }];
    [ac addAction:okAction];
    
    [_webVC presentViewController:ac animated:YES completion:nil];
}


#pragma mark - Login & Account Creation  

/**
 * This method is the entry point for calls to the webAPI for 
 * individual login, i.e., authentication with oridinary 
 * username/password credentials.
 *
 * Note: in this method we check the keychain for an existing long term
 * device id, in case our app has been re-installed on this device. If
 * no device id is found, one is created and stored in the keychain.
 * Keychain handling is documented in the method.
 */
- (void)startCheckProv {
    NSLog(@"%s called",__PRETTY_FUNCTION__);
    
    iProvStat=0;
    iPrevErr=0;   
        
    btLogin.enabled = NO;
    self.view.userInteractionEnabled = NO;
    progressView.hidden = NO;
    [self securePasswordField];
    
    // Hide password checkbox and forgot my password views while
    // displaying progress view.
    [self fadeOutView:pwdButtonsView duration:0 completion:nil];
    
    [progressView startAnimatingDots];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int r;
        char bufC[128];      
        const char *p=[tfUsername.text UTF8String];
        
        strncpy(bufC,p,127);
        bufC[127]=0;
        trim(&bufC[0]);
        
//        NSString *dId = [STKeychain getDecodedDeviceId];
        NSString *dId = [self keychainDevIdCreateIfNeeded];
        
        // login authentication call
        NSLog(@"\nstartCheckProv");
        r=checkProvUserPass(&bufC[0], tfPassword.text.UTF8String, dId.UTF8String, cbFnc, self);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Provisioning SUCCESS
            if(r==0){
                [progressView successWithCompletion:^{
                    [self onProvisioningSuccess];
                }];                
            } 
            // Provisioning FAILED
            else {
                // @see removeDevIdForProvFailIfNeeded method documentation
                [self removeDevIdForProvFailIfNeeded];
                
                // Unhide password checkbox and forgot my password views
                [self fadeInView:pwdButtonsView 
                        duration:kDefaultProvAnimationDuration 
                      completion:nil];

                [self resetProgress];
                self.progressView.hidden = YES;
                btLogin.enabled = YES;
                self.view.userInteractionEnabled = YES;
                
            } // end if provisioning success/fail
            
        }); // end dispatch main_queue
        
    }); // end dispatch global_queue
    
} // end startCheckProv


/**
 * This method is called invoked by the cbFnc(...) function during the
 * networking authentication process to update the progressView.
 */
-(void)cbTLS:(int)ok msg:(const char*)msg {
    NSLog(@"%s\nprov=[%s] %d",__PRETTY_FUNCTION__,msg,ok);
    
    if(ok<=0){
        if(iPrevErr==-2)return;
        iPrevErr=ok;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self alertWithTitle:@" " message:[NSString stringWithUTF8String:msg]];            
        });
    }
    else{
        iProvStat++;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            float f=(float)iProvStat/16.;
            NSLog(@"iProvStat:%1.2ld / 16. = f(%1.2f)",(long)iProvStat,f);
            if(f>1.)f=1.;
            [progressView setProgress:f];
        });
    }
}

- (void)onProvisioningSuccess {
    NSLog(@"%s called",__PRETTY_FUNCTION__);
    
    if ([_delegate respondsToSelector:@selector(provisioningDidFinish)]) {
        [_delegate provisioningDidFinish];
    }
}

- (IBAction)onCreatePress:(id)sender {
    if(![self checkForNetwork]){
        return;
    }
    
    if ([_delegate respondsToSelector:@selector(needsDisplayProvisioningController:animated:)]) {
        UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Prov" bundle:nil];
        SCAccountCreationVC *vc = [sb instantiateViewControllerWithIdentifier:@"SCAccountCreationVC"];
        vc.delegate = self.delegate;
        [_delegate needsDisplayProvisioningController:vc animated:YES];
    }
}

/**
 * This method is called by either textFieldShouldReturn for a keyboard
 * Join button action, or from a user press of the Login button which
 * is wired to this IBAction in IB.
 */
-(IBAction)onLoginPress{   
    if(![self checkForNetwork]){
        return;
    }
    
    // Invalid textfield input
    if (NO == [self inputIsValid]) {
                
        UITextField *tfFirstResponder = tfUsername;
        
        if (tfUsername.text.length < 1) {
            [self alertWithTitle:T_TRNS("Invalid Input")
                         message:T_TRNS("Username cannot be blank")];
        }
        else {
            [self alertWithTitle:T_TRNS("Invalid Input")
                         message:T_TRNS("All fields are required")];
            tfFirstResponder = tfPassword;
        }
        
        [tfFirstResponder becomeFirstResponder];
    }
    else {
        [self decideLoginPath];
    }
}


#pragma mark - Keychain

- (NSString *)keychainDevIdCreateIfNeeded {

//    _lcUsername = [[tfUsername.text lowercaseString] retain]; // UNUSED: 09/25/15
    _existingDevIdFound = [STKeychain deviceIdExists];
    
    if (NO == _existingDevIdFound) {
        NSError *error = nil;
        
        NSLog(@"%s\n\t CREATE deviceId",__PRETTY_FUNCTION__);
        BOOL result = [STKeychain createAndStoreDeviceIdWithError:&error];
        
        if (error || !result) {
            if (error) {
                NSLog(@"%sError creating/storing device id keychain\n%@",
                      __PRETTY_FUNCTION__, [error localizedDescription]);
            } else {
                NSLog(@"%sUnknown keychain error:\nNo error returned creating/storing "
                      "device id keychain but STKeychain returned FALSE",
                      __PRETTY_FUNCTION__);
            }
        }
    }
    else {
        NSLog(@"%s\n\t EXISTING deviceId FOUND",__PRETTY_FUNCTION__);
    }
    
    NSString *devId = [STKeychain getEncodedDeviceId];
    // TESTING - log encoded keychain string
//    NSLog(@"\n\tencoded devId: %@", devId);
    
    return devId;
}

- (void)removeDevIdForProvFailIfNeeded {
    // If provisioning failed and existingDeviceIdFound is
    // true, the user may have entered a wrong password.
    // In that case, the deviceId keychain item was not
    // created or modified, and we need not do anything.
    //
    // If existingDeviceIdFound is false, then a deviceId
    // keychain item was created and stored for a user which
    // cannot be provisioned - likely, a wrong username
    // and/or password. In that case, we destroy the
    // keychain item; it will be created again on the next try.
    if (NO == _existingDevIdFound && [STKeychain deviceIdExists]) {

        NSError *error;
        
//        NSLog(@"%s\nDeleting device id keychain item for %@\n",
//              __PRETTY_FUNCTION__,_lcUsername);

        NSLog(@"%s\n\t DELETE deviceId",__PRETTY_FUNCTION__);
        [STKeychain deleteItemForUsername:kSPDeviceIdAccountKey
                           andServiceName:kSPDeviceIdServiceKey
                                    error:&error];
        if (error) {
            NSLog(@"%s\nError deleting device id keychain item:\n%@",
                  __PRETTY_FUNCTION__, [error localizedDescription]);
        }
        // Important: clear the ivar for a user retry
//        self.lcUsername = nil;
        }
}

#pragma mark - Provisioning Utilities

- (BOOL)inputIsValid {
    NSString *un  = tfUsername.text;
    
    /*
     * Modified for SSO
     */
    if (_passwordViewsHidden) {
        return (un && un.length > 0);
    }
    
    NSString *pwd = tfPassword.text;
    return (un && un.length > 0 && pwd && pwd.length > 0);
}

- (BOOL)checkForNetwork {
    BOOL hasNetwork = (BOOL)hasIP();
    if (NO == hasNetwork) {
//        [self showMsgMT:T_TRNS("Network not available") msg:""];
        [self alertWithTitle:T_TRNS("Network not available") message:@""];
    }
    return  hasNetwork;
}

// 09/30/15 DEPRECATED / OUTDATED - Use UIAlertController API
// @see alertWithTitle:message:
//-(void)showMsgMT:(NSString *)title msg:(const char*)msg{
//    NSString *m= [NSString stringWithUTF8String:msg];
//    [self alertWithTitle:title message:m];
//}

// This method presents a UIAlertController, new with iOS 8, and should
// be preferred over the older alert presentation in the method above.
// Note that an alertController is a UIViewController and is presented
// like any other view controller, the webVC for example.
- (void)alertWithTitle:(NSString*)title message:(NSString*)msg
{
    [self alertWithTitle:title message:msg completion:nil];
}

- (void)alertWithTitle:(NSString*)title message:(NSString*)msg completion:(void (^)())completion {

    UIAlertController *ac = [UIAlertController
                             alertControllerWithTitle:title
                             message:msg
                             preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction
                               actionWithTitle:T_TRNS("Dismiss")
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action) {
                                   if (completion) {
                                       NSLog(@"Alert OK action - run completion block");
                                       completion();
                                   }
                               }];
    [ac addAction:okAction];
    
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - Textfield Methods

/*
 * Commented for SSO : allow any text entry
 */
//- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
//    
//    NSString *nextString = [textField.text stringByReplacingCharactersInRange:range withString:string];
//    
//    if(tfUsername == textField){
//        NSCharacterSet *nonUsername = [[NSCharacterSet characterSetWithCharactersInString:@"._ABCDEFGHIJKLMNOPQRSTUVWXYZqwertyuiopasdfghjklzxcvbnm1234567890"] invertedSet];
//        
//        if ([nextString stringByTrimmingCharactersInSet:nonUsername].length != nextString.length){
//            return NO;
//        }
//    }
//    
//    UITextField * second = tfUsername == textField? tfPassword : tfUsername;
//    BOOL ok = nextString.length > 0 && second.text.length > 0;
//    
//    [btLogin setEnabled: ok ];
//    
//    return YES;
//}

/**
 * This isn't technically a delegate method (not part of UITextFieldDelegate protocol).
 * We registered for notifications of UIControlEventEditingChanged (in registerTextfieldListeners):
 **/
- (void)textFieldDidChange:(id)sender {
    
    UITextField *txfld = (UITextField *)sender;
    if (![txfld isKindOfClass:[UITextField class]]) {
        NSLog(@"%s\n\tERROR: expected sender to be UITextfield instance at line %d",
              __PRETTY_FUNCTION__, __LINE__);
        return;
    }

    NSString *txt = txfld.text;
    
    // If user enters "@" in username string, hide password views
    if (txfld == tfUsername) {
        BOOL txtContainsAt = [txt containsString:@"@"];
        if (!_passwordViewsHidden && txtContainsAt) {
            
            [self hideViewsForEnterpriseLoginWithAnimation:YES completion:^{
                // FIX: this keyboard Return key bit swallows the next typed character
//                [self setTextfield:tfUsername keyboardReturnKey:UIReturnKeyGo];
            }];
        }
        // If txt does not contain "@", show password views
        else if (_passwordViewsHidden && !txtContainsAt) {
            
            [self showHiddenEnterpriseLoginViewsWithAnimation:YES completion:^{
                // FIX: this keyboard Return key bit swallows the next typed character
//                [self setTextfield:tfUsername keyboardReturnKey:UIReturnKeyNext];
            }];
        }
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    if(textField==tfUsername){
        if(tfUsername.text.length<1)return NO;

        /*
         * Modified for SSO 
         */
        if (!_passwordViewsHidden) {
            [tfPassword becomeFirstResponder];
        }
        else {
//            dispatch_async(dispatch_get_main_queue(), ^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self onLoginPress];
            });
        }
        
        return YES;
    }
    
    if(textField == tfPassword && tfPassword.text.length <= 0)return NO;
    [self onLoginPress];
    
    return YES;
}

- (void)resignAllResponders {
    [tfUsername resignFirstResponder];
    [tfPassword resignFirstResponder];
}

/**
 * This method is a setter to place an attributed string as placeholder
 * text on the given textfield.
 * 
 * @param str The string with which to initialize an attributed string
 *
 * @param textfield The textfield on which to set the placeholder
 *                  attributed string.
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

// obscure password field if clear text
- (void)securePasswordField {
    if (pwdCheckbox.isChecked) {
        [pwdCheckbox toggleCheckmark];
        [self handleCheckboxTap];
    }
}

- (void)registerTextfieldListeners {
    [tfUsername addTarget:self 
                   action:@selector(textFieldDidChange:) 
         forControlEvents:UIControlEventEditingChanged];
}


/**
 * This sets the keyboard Return key text to one of the Apple-defined
 * values (arbitrary text cannot be set):  
 typedef enum : NSInteger {
 UIReturnKeyDefault,
 UIReturnKeyGo,
 UIReturnKeyGoogle,
 UIReturnKeyJoin,
 UIReturnKeyNext,
 UIReturnKeyRoute,
 UIReturnKeySearch,
 UIReturnKeySend,
 UIReturnKeyYahoo,
 UIReturnKeyDone,
 UIReturnKeyEmergencyCall,
 } UIReturnKeyType;
 *
 * UNUSED - changing keyboard during typing for SSO login drops typed
 * characters.
 */
- (void)setTextfield:(UITextField*)txtfld keyboardReturnKey:(UIReturnKeyType)type {
    // We must bracket the change of return key type with resign/become
    // first responder so that the keyboard will recognize the change.
    [txtfld resignFirstResponder];
    txtfld.returnKeyType = type;
    [txtfld becomeFirstResponder];
}


#pragma mark - Privacy Views Handlers

- (void)handleCheckboxTap {
    tfPassword.secureTextEntry = !pwdCheckbox.isChecked;
}

- (IBAction)handleForgotPasswordTap:(id)sender {
    [self dismissKeyboard];
    [self launchSafariWithURLString:kRecoveryURLString];
}

- (IBAction)handleTermsTap:(id)sender {
    [self dismissKeyboard];
    [self launchSafariWithURLString:kTermsURLString];
}

- (IBAction)handlePrivacyTap:(id)sender {
    [self dismissKeyboard];
    [self launchSafariWithURLString:kPrivacyURLString];
}

- (void)launchSafariWithURLString:(NSString *)str {
    NSAssert(str != nil && str.length > 0, @"URL string must not be nil or blank");    
    NSURL *recoveryURL = [[NSURL alloc] initWithString:str];
    [[UIApplication sharedApplication] openURL:recoveryURL];    
}


#pragma mark - ProgressView Methods
/**
 * Stops the progressView dots animation, progress circle animation,
 * and iProvStat progress counter.
 */
- (void)resetProgress {
    [progressView stopAnimatingDots];
    [progressView resetProgress];
    iProvStat = 0;
}


#pragma mark - View Utilities

- (void)hideViewsForEnterpriseLoginWithAnimation:(BOOL)animated completion:(void (^)())completion {
    
    if (_passwordViewsHidden) {
        NSLog(@"%s\n\tWARNING: called to hide Enterprise login views which are already hidden at line %d",
              __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    _passwordViewsHidden = YES;
    
    NSLayoutConstraint *policiesConstraint = [self constraintInSuperviewForAttribute:NSLayoutAttributeTop
                                                                          searchItem:policiesContainer];
    NSLayoutConstraint *bottomConstraint = [self constraintForAttribute:NSLayoutAttributeHeight 
                                                             searchItem:bottomSpacerView];
    
    NSTimeInterval dur = (animated) ? kDefaultProvAnimationDuration : 0.0;
    [UIView animateWithDuration:dur animations:^{
        passwordViewsContainer.alpha = 0.0;
        btCreate.alpha = 0.0;

        // Shorten the policiesContainer top constraint height to display
        // under the username field, in the space of the hidden password field
        policiesConstraint.constant = kPolicyViewsHiddenTopH;

        // Add the shortened height to the bottomSpacer height constraint
        // to balance the difference in the contentView height
        bottomConstraint.constant = bottomConstraint.constant + (cachedPoliciesTopH - kPolicyViewsHiddenTopH);
        
        [self.contentView layoutIfNeeded];
        
    } completion:^(BOOL finished) {
        passwordViewsContainer.hidden = YES;
//        _passwordViewsHidden = YES;
        btCreate.hidden = YES;
                
        if (completion)
            completion();
    }];
}

- (void)showHiddenEnterpriseLoginViewsWithAnimation:(BOOL)animated completion:(void (^)())completion {

    if (!_passwordViewsHidden) {
        NSLog(@"%s\n\tWARNING: called to show hidden Enterprise login views which are not hidden at line %d",
              __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    passwordViewsContainer.alpha = 0.0;
    passwordViewsContainer.hidden = NO;
    _passwordViewsHidden = NO;
    
#ifdef ACCOUNT_CREATION_ENABLED
    btCreate.alpha = 0.0;
    btCreate.hidden = NO;
    [btCreate setTitle:T_TRNS("CREATE ACCOUNT") forState:UIControlStateNormal];
#endif


    NSLayoutConstraint *policiesConstraint = [self constraintInSuperviewForAttribute:NSLayoutAttributeTop
                                                                          searchItem:policiesContainer];
    NSLayoutConstraint *bottomConstraint = [self constraintForAttribute:NSLayoutAttributeHeight 
                                                             searchItem:bottomSpacerView];

    NSTimeInterval dur = (animated) ? kDefaultProvAnimationDuration : 0.0;    
    [UIView animateWithDuration:dur animations:^{
        passwordViewsContainer.alpha = 1.0;
        
#ifdef ACCOUNT_CREATION_ENABLED
        btCreate.alpha = 1.0;
#endif
        
        // Reset the policiesContainer top constraint height to its original
        // height (set in IB, stored in the cachedPoliciesTopH property in viewDidLoad)
        // to display under the passwordContainer
        policiesConstraint.constant = cachedPoliciesTopH;
        
        // Shorten the bottomSpacer to balance the difference of added
        // policiesContainer height
        bottomConstraint.constant = bottomConstraint.constant + (kPolicyViewsHiddenTopH - cachedPoliciesTopH);
        
        [self.contentView layoutIfNeeded];
        
    } completion:^(BOOL finished) {
        if (completion)
            completion();
    }];
}

/** 
 * Fades out the given view if duration is longer than zero, else hides
 * the view without fade animation. Completion block may be nil.
 * Note that a NSTimeInterval is just a double.
 *
 * Example: [self fadeOutView:lbVersion duration:0.0 completion:nil];
 * This hides the version label (a UIView subclass) immediately, no animation.
 */
- (void)fadeOutView:(UIView *)aView duration:(NSTimeInterval)dur completion:(void (^)())completion {
    [UIView animateWithDuration:dur animations:^{
        aView.alpha = 0.0;
    } completion:^(BOOL finished) {
        aView.hidden = YES;
        if (completion)
            completion();
    }];
}

/** 
 * Fades in the given view if duration is longer than zero, else unhides
 * the view without fade animation. Completion block may be nil.
 *
 * Example:     
 * [self fadeInView:passwordFieldView duration:0.35 completion:^{
 *     // Ensure password text is obscured -
 *     // wait until the animation is complete so that unchecking
 *     // the checkbox will be visible.
 *     [self securePasswordField];
 *  }];
 *
 * This hides the version label (a UIView subclass) immediately, no animation.
 */
- (void)fadeInView:(UIView *)aView duration:(NSTimeInterval)dur completion:(void (^)())completion {
    if (aView.isHidden) {
        aView.alpha = 0.0;
        aView.hidden = NO;
    }
    [UIView animateWithDuration:dur animations:^{
        aView.alpha = 1.0;
    } completion:^(BOOL finished) {
        if (completion)
            completion();
    }];
}

- (void)layoutViews {
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
    
    
    // Calculate the midSpaceView height to expand or contract for 
    // current device screen height.
    CGRect bounds = [[UIScreen mainScreen] bounds];
    CGFloat screenH = MAX(bounds.size.width, bounds.size.height);
    
    // Adjust bottomSpacerView height
    CGFloat policiesH = CGRectGetMaxY(policiesContainer.frame);
    CGFloat bottomSpaceH = screenH - policiesH;
    NSLayoutConstraint *mSpacerViewH = [self constraintForAttribute:NSLayoutAttributeHeight 
                                                         searchItem:bottomSpacerView];
    mSpacerViewH.constant = bottomSpaceH;
}

/**
 * This utility method returns a "single attribute", i.e., width or 
 * height, NSLayoutConstraint for the given attrib argument, in the
 * given searchItems constraint array.
 *
 * @param attrib NSLayoutAttributeWidth or NSLayoutAttributeHeight; 
 *               calling this method with any other NSLayoutAttribute is
                 undefined.
 *
 * @param sView The view object for which to find a constraint.
 *
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

- (NSLayoutConstraint *)constraintInSuperviewForAttribute:(NSLayoutAttribute)attrib searchItem:(UIView *)sView {
    for (NSLayoutConstraint *constraint in sView.superview.constraints) {        
        if ((constraint.firstItem == sView && constraint.firstAttribute == attrib) ||
            (constraint.secondItem == sView && constraint.secondAttribute == attrib)) 
        {
            return constraint;
        }
    }    
    return nil;    
}


#pragma mark - BarButton Constructors

/** 
 * SSwebVC Cancel bar button constructor.
 *
 * @param action A selector which is essentially a pointer to a method,
 *               passed in the form @selector(dismisswebVC).
 *
 * @return A Cancel barButtonItem configured with the given action with
 *         self as target.
 */
- (UIBarButtonItem *)cancelBarButtonItemWithAction:(SEL)action {
    UIBarButtonItem *bbtn = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel 
                                                                           target:self 
                                                                           action:action] autorelease];
    return bbtn;
}

/** 
 * SSwebVC Generic bar button constructor.
 *
 * @param title A button title
 * 
 * @param action A selector which is essentially a pointer to a method,
 *               passed in the form @selector(myButtonHandlerMethod).
 *
 * @return A Cancel barButtonItem configured with the given action with
 *         self as target.
 */
- (UIBarButtonItem *)barButtonItemWithTitle:(NSString *)title action:(SEL)action {
    UIBarButtonItem *bbtn = [[[UIBarButtonItem alloc] initWithTitle:title 
                                                              style:UIBarButtonItemStyleDone 
                                                             target:self 
                                                             action:action] autorelease];
    return bbtn;
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
    CGRect bottomEdge = CGRectMake(0.0, CGRectGetMaxY(inputContainer.frame), vFrame.size.width, 1.0);
    CGPoint bottomInputPoint = bottomEdge.origin;
    
    /*
     * Modified for SSO 
     * This block ensures the view scrolls far enough above the keyboard
     * to display the "show password" checkbox 
     */
    if (!_passwordViewsHidden) {
        CGRect aRect = self.view.frame;
        aRect.size.height -= kbRect.size.height;    
        if (!CGRectContainsPoint(aRect, bottomInputPoint)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.scrollView scrollRectToVisible:bottomEdge animated:YES];
            });        
        }
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    scrollView.contentInset = contentInsets;
}

- (void)dismissKeyboard {
    [self resignAllResponders];
}


#pragma mark - UIViewController Methods

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end


#pragma mark - Provisioning callbacks
void cbSsoFnc(void *p, int code, const char *pMsg){
    Prov *pr=(Prov*)p;
    if(pr){
        pr.sso_err = code;
        NSLog(@"SC_ProvCode %d: %@", code, [NSString stringWithUTF8String:pMsg]);
    }
}

void cbFnc(void *p, int ok, const char *pMsg){
   Prov *pr=(Prov*)p;
   if(pr){
      [pr cbTLS:ok msg:pMsg];
   }
}
