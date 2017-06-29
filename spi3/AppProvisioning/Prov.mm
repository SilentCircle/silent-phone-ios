/*
Created by Janis Narbuts
Copyright (C) 2004-2012, Tivi LTD, www.tiviphone.com. All rights reserved.
Copyright (C) 2012-2017, Silent Circle, LLC.  All rights reserved.

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
//  Prov.h
//  VoipPhone
//
//  Created by Janis Narbuts on 8.11.2012.
//  Copyright (c) 2012 Tivi LTD, www.tiviphone.com. All rights reserved.
//
// Extended by Eric Turner and Jason Cooper for SC SSO 08/2015
// Copyright (c) 2015 Silent Circle. All rights reserved.
//

#import "Prov.h"

#import "ChatUtilities.h"
#import "SCAccountCreationVC.h"
#import "SCCheckbox.h"
#import "SCFileManager.h"
#import "SCPCallbackInterface.h"
#import "SCProgressView.h"
#import "SCSConstants.h"
#import "SSOWebVC.h"
#import "STKeychain.h"
// Categories
#import "UIView+SCUtilities.h"

//----------------------------------------------------------------------
#pragma mark - FEATURE CONSTANTS
/*
 * Uncomment #define statements to enable features.
 */

// Switch for enabling account creation UI and server calls
#define ENTERPRISE_LOGIN_ENABLED

// Switch for enabling account creation UI and server calls
//#define ACCOUNT_CREATION_ENABLED

// Switch for enabling freemium feature (ET: not sure what this does yet)
//#define FREEMIUM_ENABLED

// Top constraint space height for moving policy views container view up
// when pasword views are hidden (sso)
static CGFloat const kPolicyViewsHiddenTopH = 12.0;

//----------------------------------------------------------------------


//----------------------------------------------------------------------
NSString * const kRecoveryURLPath = @"/account/recover/";
NSString * const kTermsURLPath    = @"/terms/";
NSString * const kPrivacyURLPath  = @"/privacy-policy/";

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
int checkProvUserPass(const char *pUN, const char *pPWD, const char *pTFA, const char *pdevID, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);
int getDomainAuthURL(const char *pLink, const char *pUsername, char *auth_url, int auth_sz, char *redirect_url, int redirect_sz, char *auth_type, int auth_type_sz, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);
//----------------------------------------------------------------------


/** Added for SSO */
typedef NS_ENUM(NSInteger, SC_ProvCode) {
    
    // The provided string is not an email address
    sso_not_email = -5,
    
    // Failed to download JSON
    sso_no_json_err = -4,

    // Our SSO server returned JSON which did not include an auth_type field value
    sso_no_auth_type_err = -3,

    // sccps.silentcircle.com server sent us a auth_type we didn't understand.
    // We need to handle this better. The scenario is an older client trying to log
    // in via an Enterprise LDAP (?) account.
    sso_wrong_auth_type_err = -2,
    
    // auth_uri or redirect_uri fields are empty
    sso_no_auth_url_err = -1,

    // no error, everything is OK
    sso_no_err = 0
};

@interface Prov() <UIWebViewDelegate> 

/** The UIWebView subclass used for SSO authentication */
@property (strong, nonatomic) SSOWebVC *webVC;

/** The auth type (ADFS or OIDC) */
@property (strong, nonatomic) NSString *authType;

/** Storage for policiesContainer NSLayoutAttributeTop height */
@property (nonatomic) CGFloat cachedPoliciesTopH;

@property (nonatomic) BOOL existingDevIdFound;

@property (nonatomic) SC_ProvCode sso_err;

@end

@interface Prov ()
@property (retain, nonatomic) IBOutlet UIView *bottomSpacerView;
@property (retain, nonatomic) IBOutlet UILabel *lbBuildInfo; // "version 3.4.0"
@property (retain, nonatomic) IBOutlet UILabel *lbSubtitle;  // "by Silent Circle"
@property (retain, nonatomic) IBOutlet UIView *passwordViewsContainer;
@end

@implementation Prov
{
    NSString *_redirectUriBase;
    BOOL _tfaActive;
    BOOL _initProgViewConfigured;
}

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
@synthesize lbBuildInfo=lbBuildInfo;
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
@synthesize termsPrivacy=termsPrivacy;


- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _webVC.webView.delegate = nil;
}

-(void)setTranslations{
    
    // Set attributed string placeholder text
    [self setPlaceholderText:NSLocalizedString(@"Username", nil) textfield:tfUsername];
    [self setPlaceholderText:NSLocalizedString(@"Password", nil) textfield:tfPassword];
    [btLogin setTitle:NSLocalizedString(@"LOGIN", nil) forState:UIControlStateNormal];
    
    
    //localization for terms of serverice and privacy prolicy.
    if(termsPrivacy.restorationIdentifier){
        //get localization key
        NSString *key_tersPrivacy = [NSString stringWithFormat:@"%@.text", termsPrivacy.restorationIdentifier];
        NSString *termsPrivacyStr = NSLocalizedStringFromTable(key_tersPrivacy, @"Prov", nil);
        if(![termsPrivacyStr isEqualToString:key_tersPrivacy]){
            [termsPrivacy setText:termsPrivacyStr];
            //set termsPrivacy NSMutableAttributedString
            NSMutableAttributedString * termsPrivacyMutableAttributedStr = [[NSMutableAttributedString alloc] initWithString:termsPrivacyStr];
            //set color and font for termsPrivacy NSMutableAttributedString
            NSRange range = NSMakeRange(0, [termsPrivacyMutableAttributedStr length]);
            [termsPrivacyMutableAttributedStr addAttribute:NSForegroundColorAttributeName value:[UIColor grayColor] range:range];
            [termsPrivacyMutableAttributedStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"ArialMT" size:15.0] range:range];
            //set link for terms of services
            NSString *terms = NSLocalizedString(@"terms of service", nil);
            NSRange termRange = [termsPrivacyStr rangeOfString:terms];
            [termsPrivacyMutableAttributedStr addAttribute: NSLinkAttributeName value: [ChatUtilities buildWebURLForPath:kTermsURLPath] range: NSMakeRange(termRange.location, [terms length])];
            //set link for privacy policy
            NSString *privacy = NSLocalizedString(@"privacy policy", nil);
            NSRange privacyRange = [termsPrivacyStr rangeOfString:privacy];
            [termsPrivacyMutableAttributedStr addAttribute: NSLinkAttributeName value: [ChatUtilities buildWebURLForPath:kPrivacyURLPath] range: NSMakeRange(privacyRange.location, [privacy length])];
            range = NSMakeRange([termsPrivacyMutableAttributedStr length]-[privacy length] -3, 3);
            [termsPrivacyMutableAttributedStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"Arial-BoldMT" size:15.0] range:range];
            //align text and set link color
            [termsPrivacy setAttributedText:termsPrivacyMutableAttributedStr];
            [termsPrivacy setTextAlignment:NSTextAlignmentCenter];
            [termsPrivacy setLinkTextAttributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}];
        }
        
    }
    
    // Hidden in IB
#ifdef ACCOUNT_CREATION_ENABLED
    btCreate.hidden = NO;
    [btCreate setTitle:NSLocalizedString(@"CREATE ACCOUNT", nil) forState:UIControlStateNormal];
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
    
    [self registerKeyboardListener];    
    
    // build info
    NSString *vStr = @"(N/A)";
    NSDictionary *dict = nil;
#if DEBUG 
    dict = [SCFileManager debugBuildDict];
    if (dict) {
        if (dict[kApp_version]) { 
            vStr = [NSString stringWithFormat:@"%@ (%@)", 
                    dict[kApp_version], 
                    dict[kCurrent_branch_count]];
        }
        if (dict[kCurrent_branch]) {
            NSString *branchInfo = [NSString stringWithFormat:@"%@ %@",
                                    dict[kCurrent_branch],
                                    dict[kCurrent_short_hash]];
            vStr = [NSString stringWithFormat:@"%@ %@", vStr, branchInfo];
        }         
    }
    
#else
    dict = [SCFileManager releaseBuildDict];
    if (dict) {
        if (dict[kApp_version]) { 
            vStr = [NSString stringWithFormat:@"v%@ (%@)", 
                    dict[kApp_version], 
                    (dict[kBuild_count]) ?: @"N/A"];
        }
    }
        
#endif    
    lbBuildInfo.text = vStr;
    lbBuildInfo.accessibilityLabel = [NSString stringWithFormat:@"%@ %@",
                                      NSLocalizedString(@"version", @"login screen build version"), vStr];


    //12/29/15
    [self setLoginButtonEnabled:NO];
    
#ifdef FREEMIUM_ENABLED    

    [btLogin setEnabled:NO];
   
    //we have to hide it here and do check with API server do we have freemium
    [btCreate setHidden:YES];
    
    const char *t_getVersion(void);

    NSString *endpoint = [NSString stringWithFormat:SCPNetworkManagerEndpointV1FreemiumCheck, [NSString stringWithUTF8String:t_getVersion()]];
    
    [Switchboard.networkManager apiRequestInEndpoint:endpoint
                                              method:SCPNetworkManagerMethodGET
                                           arguments:nil
                                          completion:^(NSError *error, id response) {
                                           
                                               BOOL hasFreemium = NO;
                                               
                                               if(!error) {
                                                   
                                                   NSDictionary *responseDictionary = (NSDictionary *)response;
                                                   
                                                   NSNumber *freemiumEnabled = [responseDictionary objectForKey:@"freemium_enabled"];

                                                   if(freemiumEnabled != nil)
                                                       hasFreemium = (freemiumEnabled.boolValue == YES);
                                               }
                                               
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                   
                                                   if(hasFreemium)
                                                       [btCreate setHidden:NO];
                                               });
                                           }];
#endif
}


#pragma mark - Decide login path
/*
 * We don't need to ask the user what type of account they have.  We can
 * determine it from the username
 */
- (void)decideLoginPath {

    [self resignAllResponders];

    NSString *username = tfUsername.text;
    
    // SSO mode: username contains "@"
    if ([username containsString:@"@"]) {

        [self lockFormAndShowProgressView];
        
        [progressView startAnimatingDots];
        
        [self domainAuthForUser:username
                     completion:^(NSURL *url, SC_ProvCode errorCode) {
                       
                       [self unlockFormAndHideProgressView];
                       
                       // Consider non-nil url a success, so fire off
                       // the web view with the url. It should load an
                       // enterprise server ADFS login page.
                       if(url)
                           [self presentWebViewWithURL:url];
                       else if (errorCode)
                           [self handleSsoFailureWithCode:errorCode];
                       else
                           [self handleIndividualOption];
                }];
    }
    else
        [self handleIndividualOption];
}

#pragma mark - SSO Individual Option Handler

/**
 * "Individual" login means username and password login, as distinct
 * from "enterprise" login, or SSO.
 */
- (void)handleIndividualOption {
    
    // Show the password views with fade-in and place cursor
    // in username or password textfield
    if (_passwordViewsHidden)
        [self showHiddenEnterpriseLoginViewsWithAnimation:YES
                                               completion:^{
                                                   
                                                   if (tfUsername.text && tfUsername.text.length > 0)
                                                       [tfPassword becomeFirstResponder];
                                                   else
                                                       [tfUsername becomeFirstResponder];
                                               }];
    else
        [self startCheckProv:nil];
}

#pragma mark - SSO Enterprise Login Methods

static BOOL const LOG_SSO = YES;

-(void)domainAuthForUser:(NSString*)userName completion:(void (^)(NSURL* url, SC_ProvCode errorCode))completion {
    
    if(!completion)
        return;
    
    if([userName rangeOfString:@"@"].location == NSNotFound) {
        
        // Fallback to the individual option
        completion(nil, sso_not_email);
        return;
    }
    
    NSString *urlPath = [NSString stringWithFormat:SCPNetworkManagerEndpointV1AuthDomain, userName];
    
    [Switchboard.networkManager apiRequestInEndpoint:urlPath
                                              method:SCPNetworkManagerMethodGET
                                           arguments:nil
                                          completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {
                                              
                                              if(error) {
                                                  
                                                  completion(nil, sso_no_json_err);
                                                  return;
                                              }
                                              
                                              if(httpResponse.statusCode != 200) {
                                                  
                                                  completion(nil, sso_no_json_err);
                                                  return;
                                              }
                                                  
                                              NSDictionary *responseDict = (NSDictionary *)responseObject;
                                              
                                              if(![responseDict objectForKey:@"auth_type"]) {
                                                  
                                                  completion(nil, sso_no_auth_type_err);
                                                  return;
                                              }
                                              
                                              NSString *authType = [responseDict objectForKey:@"auth_type"];
                                              
                                              if(![authType isEqualToString:@"ADFS"] && ![authType isEqualToString:@"OIDC"]) {
                                                  
                                                  completion(nil, sso_wrong_auth_type_err);
                                                  return;
                                              }
                                              
                                              NSString *authURI     = [responseDict objectForKey:@"auth_uri"];
                                              NSString *redirectURI = [responseDict objectForKey:@"redirect_uri"];
                                              
                                              if(authURI == nil || redirectURI == nil) {
                                                  
                                                  completion(nil, sso_no_auth_url_err);
                                                  return;
                                              }
                                              
                                              self.authType = authType;
                                              
                                              NSArray *redirectParts = [redirectURI componentsSeparatedByString:@"?"];
                                              
                                              if([redirectParts count] > 0)
                                                  _redirectUriBase = [[NSString alloc] initWithString:(NSString *)[redirectParts objectAtIndex:0]];
                                              
                                              NSURL *authURL = [NSURL URLWithString:authURI];
                                              
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  completion(authURL, sso_no_err);
                                              });
                                          }];
}

-(void) presentWebViewWithURL:(NSURL *)inURL {
    
    // Intialize with URL, make self the webView delegate to dismiss
    // loadingView, error handling, etc.
    SSOWebVC *webVC = [SSOWebVC ssoWebVCWithURL:inURL delegate:self];    
    
    // Initialize a navigationController wrapper programmatically
    UINavigationController *navcon = [[UINavigationController alloc] initWithRootViewController:webVC];
    
    // Set Cancel bar button
    UIBarButtonItem *bbtn = [self cancelBarButtonItemWithAction:@selector(dismissWebVC)];
    webVC.navigationItem.leftBarButtonItem  = bbtn;
    
    self.webVC = webVC; // persist a handle to the webVC property instance
    
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
    [self dismissWebVCwithCompletion:nil];
}

- (void)dismissWebVCwithCompletion:(void (^)())completion {
    
    self.webVC.webView.delegate = nil;
    
    [self unlockFormAndHideProgressView];
    
    [self dismissViewControllerAnimated:YES completion:^{
        self.webVC = nil;
        
        if(completion)
            completion();
    }];
}

#pragma mark - SSO UIWebViewDelegate Methods

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
   
    BOOL shouldLoad = YES;
    
    NSString *URLString = [[request URL] absoluteString];

    if (_redirectUriBase && [URLString rangeOfString:_redirectUriBase].location == 0) {
        
        if ([URLString containsString:@"code="]) {
            
            shouldLoad = NO;
            
            NSString *code = nil;
            NSString *state = nil;
            
            NSString *queryPart = [[URLString componentsSeparatedByString:@"?"] lastObject];
            NSArray *getParameters = [queryPart componentsSeparatedByString:@"&"];
            
            for (NSString *getParameterString in getParameters) {
                
                NSArray *getParameterCouple = [getParameterString componentsSeparatedByString:@"="];
                NSString *getKey    = [getParameterCouple firstObject];
                NSString *getValue  = [getParameterCouple lastObject];
                
                if([getKey isEqualToString:@"code"])
                    code = getValue;
                else if([getKey isEqualToString:@"state"])
                    state = getValue;
            }
            
            if(code == nil)
                return YES;
            
            if(state == nil)
                state = @"";
            
            [self dismissWebVCwithCompletion:^{
                
                // Start the progress again in progressView
                [self.view setUserInteractionEnabled:NO];
                [self resetProgress];
                [progressView setHidden:NO];
                [progressView startAnimatingDots];
                
                // Use the accessToken to retrieve the api_key
                NSString *UN = tfUsername.text;
                NSString *dId = [self keychainDevIdCreateIfNeeded];
                
                // Not sure if checkProvUserPass(...) can handle nil devId param.
                // So if there is no existing long term devId,
                // (we wouldn't expect one unless this is a re-install),
                // set to empty string.
                dId = (dId) ?: @"";
                
                const char *t_getDev_name(void);
                const char *dev_name=t_getDev_name();
                
                const char *t_getDevID_md5(void);
                const char *dev_id=t_getDevID_md5();
                
                const char *t_getVersion(void);
                const char *version = t_getVersion();
                
                NSString *endpoint = [NSString stringWithFormat:SCPNetworkManagerEndpointV1MeNewDevice, [NSString stringWithCString:dev_id
                                                                                                                           encoding:NSUTF8StringEncoding]];
                
                NSDictionary *arguments = @{
                                            @"username"             : UN,
                                            @"auth_type"            : self.authType,
                                            @"auth_code"            : code,
                                            @"state"                : state,
                                            @"device_name"          : [NSString stringWithCString:dev_name
                                                                                         encoding:NSUTF8StringEncoding],
                                            @"app"                  : @"silent_phone",
                                            @"persistent_device_id" : dId,
                                            @"device_class"         : @"ios",
                                            @"version"              : [NSString stringWithCString:version
                                                                                         encoding:NSUTF8StringEncoding]
                                            };
                
                [Switchboard.networkManager apiRequestInEndpoint:endpoint
                                                          method:SCPNetworkManagerMethodPUT
                                                       arguments:arguments
                                                      completion:^(NSError *error, id responseObject, NSHTTPURLResponse *httpResponse) {
                                                      
                                                          NSDictionary *responseDict = (NSDictionary *)responseObject;
                                                          
                                                          BOOL succeeded = YES;
                                                          
                                                          if(error || httpResponse.statusCode != 200)
                                                              succeeded = NO;
                                                          else {
                                                              
                                                              if(!responseDict)
                                                                  succeeded = NO;
                                                              else if( ![responseDict objectForKey:@"api_key"] ||
                                                                      (![[responseDict objectForKey:@"result"] isEqualToString:@"success"])
                                                                      )
                                                                  succeeded = NO;
                                                          }
                                                          
                                                          if(succeeded) {
                                                              
                                                              NSString *apiKey = [responseDict objectForKey:@"api_key"];
                                                              
                                                              int storeProvAPIKey(const char *p);
                                                              
                                                              storeProvAPIKey(apiKey.UTF8String);
                                                              
                                                              int checkProvWithAPIKey(const char *aAPIKey, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);
                                                              
                                                              checkProvWithAPIKey(apiKey.UTF8String, cbSsoFnc, (__bridge void *)self);
                                                          }

                                                          dispatch_async(dispatch_get_main_queue(), ^{
                                                              
                                                              if(!succeeded) {
                                                                  
                                                                  [self alertWithTitle:NSLocalizedString(@"Error", nil)
                                                                               message:NSLocalizedString(@"Please try again", nil)];
                                                                  
                                                                  [self.progressView setHidden:YES];
                                                                  [self.btLogin setEnabled:YES];
                                                                  [self.view setUserInteractionEnabled:YES];
                                                                  
                                                                  return;
                                                              }
                                                              
                                                              [progressView successWithCompletion:^{
                                                                  [self onProvisioningSuccess];
                                                              }];
                                                          });
                                                       }];
            }];
        }
        else if([URLString containsString:@"error="]) {
            
            // In case the user denies access
            shouldLoad = NO;
            
            [self dismissWebVCwithCompletion:^{
                
                [self alertWithTitle:@"" message:NSLocalizedString(@"Access denied", nil)];
                
                self.progressView.hidden = YES;
                [self.btLogin setEnabled:YES];
                self.view.userInteractionEnabled = YES;
            }];
        }
    }
    
    return shouldLoad;
}

- (NSString *)baseUriWithString:(NSString *)uri {
    if (nil == _redirectUriBase || _redirectUriBase.length == 0) return nil;
    
    NSString *cmp = [uri substringToIndex:_redirectUriBase.length];
    return cmp;
}

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
            
            return [NSString stringWithFormat:NSLocalizedString(@"An enterprise server could not be located, or could not be authenticated, for the %@ domain", nil), domain];
        }
        default:
            // default to unknown
            break;
    }
    
    // Unknown
    return NSLocalizedString(@"An unknown server error has occurred", nil);
}

/*
 * The webView may take a while to load a URL. The loadingView
 * (SC logo with "connecting" message -see in IB) will display until
 * self, as the webView delegate, gets this callback. This method fades
 * out the loadingView.
 */
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSLog(@"%s",__PRETTY_FUNCTION__);
    
    [UIView fadeOutView:self.webVC.loadingView 
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
    
    // Ignore if the returned error means
    // that the asynchronous load was cancelled
    // ref: https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Miscellaneous/Foundation_Constants/
    if (error.code == NSURLErrorCancelled)
        return;
    
    // Ignore if this is the enterpise redirect
    NSString *requestStr = webView.request.URL.absoluteString;
    if (_redirectUriBase && [requestStr isEqualToString:_redirectUriBase]) {
        return;
    }
    
    NSString *strURL = webView.request.URL.path;
    if ([strURL containsString:@"redirect"]) {
        if (LOG_SSO) {
            NSLog(@"%s\n\tIgnoring call with \"redirect\" in URL path",__PRETTY_FUNCTION__);
        }
        return;
    }
    
    NSLog(@"%s\nERROR: loading url: %@", __PRETTY_FUNCTION__, strURL);

    NSString *domain = [[tfUsername.text componentsSeparatedByString:@"@"] lastObject];
    NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"An Enterprise server for the %@ domain did not respond.", nil), domain];
    
    UIAlertController *ac = [UIAlertController
                             alertControllerWithTitle:@""  //T_TRNS("Error")
                             message:msg
                             preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"Dismiss", nil)
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action) {
                                    NSLog(@"WebViewDidFail alert Dismiss button - dismiss webVC");
                                   [self dismissWebVCwithCompletion:^{
                                       self.progressView.hidden = YES;
                                       [self.btLogin setEnabled:YES];
                                       self.view.userInteractionEnabled = YES;
                                   }];
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
- (void)startCheckProv:(NSString*)tfaCode {
    
    iProvStat=0;
    iPrevErr=0;   
    
    [self lockFormAndShowProgressView];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int r;
        char bufC[128];      
        const char *p=[tfUsername.text UTF8String];
        
        strncpy(bufC,p,127);
        bufC[127]=0;
        trim(&bufC[0]);
        
        NSString *dId = [self keychainDevIdCreateIfNeeded];
        
        if(!dId) {
            
            [self unlockFormAndHideProgressView];
            return;
        }
        
        // login authentication call
        NSLog(@"\nstartCheckProv");
        
        r=checkProvUserPass(&bufC[0], tfPassword.text.UTF8String, (tfaCode ? tfaCode.UTF8String : NULL), dId.UTF8String, cbFnc, (__bridge void *)self);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            // Provisioning SUCCESS
            if(r==0){
                
                _tfaActive = NO;
                
                [progressView successWithCompletion:^{
                    [self onProvisioningSuccess];
                }];                
            } 
            // Provisioning FAILED
            else {
                // @see removeDevIdForProvFailIfNeeded method documentation
                [self removeDevIdForProvFailIfNeeded];
                
                [self unlockFormAndHideProgressView];
                
            } // end if provisioning success/fail
            
        }); // end dispatch main_queue
        
    }); // end dispatch global_queue
    
} // end startCheckProv

- (void)lockFormAndShowProgressView {
    
    if (!_initProgViewConfigured) {
        [progressView configureInitialLayout];
        _initProgViewConfigured = YES;
    }

    dispatch_async(dispatch_get_main_queue(), ^{

        [self setLoginButtonEnabled:NO];
        self.view.userInteractionEnabled = NO;
        progressView.hidden = NO;
        [self securePasswordField];
        
        // Hide password checkbox and forgot my password views while
        // displaying progress view.
        [UIView fadeOutView:pwdButtonsView duration:0 completion:nil];
        
        [progressView startAnimatingDots];
    });
}

- (void)unlockFormAndHideProgressView {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // Unhide password checkbox and forgot my password views
        [UIView fadeInView:pwdButtonsView
                duration:kDefaultProvAnimationDuration
              completion:nil];
        
        [self resetProgress];
        [self setLoginButtonEnabled:YES];
        self.view.userInteractionEnabled = YES;
        self.progressView.hidden = YES;
    });
}

/**
 * This method is called invoked by the cbFnc(...) function during the
 * networking authentication process to update the progressView.
 */
-(void)cbTLS:(int)ok msg:(const char*)msg {
    NSLog(@"%s\nprov=[%s] %d",__PRETTY_FUNCTION__,msg,ok);
    
    if(ok<=0){
        if(iPrevErr==-2)return;
        iPrevErr=ok;
		NSString *msgS = [NSString stringWithUTF8String:msg];
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if(ok == -4) {
                
                if(_tfaActive)
                    [self onTFAError:NSLocalizedString(@"Authentication token was invalid", nil)];
                else {
                    
                    _tfaActive = YES;
                    [self showTFADialog];
                }
            }
			else
                [self alertWithTitle:NSLocalizedString(@"Error", nil)
                             message:msgS];
        });
    }
    else{
        iProvStat++;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            float f=(float)iProvStat/13.;
            NSLog(@"iProvStat:%1.2ld / 13. = f(%1.2f)",(long)iProvStat,f);
            if(f>1.)f=1.;
            [progressView setProgress:f];
        });
    }
}

- (void)showTFADialog {

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Two Factor Authentication", nil)
                                                                             message:NSLocalizedString(@"Enter your authentication token below", nil)
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        [textField setKeyboardType:UIKeyboardTypeNumberPad];
        [textField setPlaceholder:NSLocalizedString(@"Authentication token", nil)];
    }];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *action) {
                                                         
                                                         NSString *tfaCode = alertController.textFields.firstObject.text;
                                                         
                                                         if([tfaCode length] != 6) {
                                                             
                                                             [self onTFAError:NSLocalizedString(@"Authentication token must be six characters long", nil)];
                                                             
                                                             return;
                                                         }
                                                         
                                                         [self startCheckProv:tfaCode];
                                                     }];
    [alertController addAction:okAction];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {
                                                             _tfaActive = NO;
                                                         }];
    [alertController addAction:cancelAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)onTFAError:(NSString*)errorString {
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil)
                                                                             message:errorString
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *tryAgainAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Try again", nil)
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *action) {
                                                               [self showTFADialog];
                                                           }];
    [alertController addAction:tryAgainAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {
                                                             _tfaActive = NO;
                                                         }];
    [alertController addAction:cancelAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
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
            [self alertWithTitle:NSLocalizedString(@"Invalid Input", nil)
                         message:NSLocalizedString(@"Username cannot be blank", nil)];
        }
        else {
            [self alertWithTitle:NSLocalizedString(@"Invalid Input", nil)
                         message:NSLocalizedString(@"All fields are required", nil)];
            tfFirstResponder = tfPassword;
        }
        
        [tfFirstResponder becomeFirstResponder];
    }
    else {
        [self decideLoginPath];
    }
}

//12/29/15
- (void)setLoginButtonEnabled:(BOOL)enable {
    btLogin.enabled = enable;
    btLogin.alpha = (enable) ? 1 : 0.35;
}

#pragma mark - Keychain

- (NSString *)keychainDevIdCreateIfNeeded {

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
        
        NSLog(@"%s\n\t DELETE deviceId",__PRETTY_FUNCTION__);
        [STKeychain deleteItemForUsername:kSPDeviceIdAccountKey
                           andServiceName:kSPDeviceIdServiceKey
                                    error:&error];
        if (error) {
            NSLog(@"%s\nError deleting device id keychain item:\n%@",
                  __PRETTY_FUNCTION__, [error localizedDescription]);
        }
    }
}

#pragma mark - Provisioning Utilities

- (BOOL)inputIsValid {
    NSString *un  = tfUsername.text;
    
#ifdef ENTERPRISE_LOGIN_ENABLED
    /*
     * Modified for SSO
     */
    if ([self isSSOUsername]) {
        return (un && un.length > 0);
    }
#endif
    
    NSString *pwd = tfPassword.text;
    return (un && un.length > 0 && pwd && pwd.length > 0);
}

- (BOOL)isSSOUsername {
    NSString *uname = tfUsername.text;
    BOOL txtContainsAt = (uname && uname.length > 0 && [uname containsString:@"@"]);
    return txtContainsAt;
}

- (BOOL)checkForNetwork {
    BOOL hasNetwork = (BOOL)hasIP();
    if (NO == hasNetwork) {
        [self alertWithTitle:NSLocalizedString(@"Network not available", nil) message:@""];
    }
    return  hasNetwork;
}

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
                               actionWithTitle:NSLocalizedString(@"Dismiss", nil)
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

/**
 * This isn't technically a delegate method (not part of UITextFieldDelegate protocol).
 * We registered for notifications of UIControlEventEditingChanged (in registerTextfieldListeners):
 **/
- (void)textFieldDidChange:(id)sender {

    if ([self inputIsValid] && NO == btLogin.enabled) {
        [self setLoginButtonEnabled:YES];
    } else if (NO == [self inputIsValid] && btLogin.enabled) {
        [self setLoginButtonEnabled: NO];
    }
#ifndef ENTERPRISE_LOGIN_ENABLED
        return;
#endif
    
    UITextField *txfld = (UITextField *)sender;
    if (![txfld isKindOfClass:[UITextField class]]) {
        NSLog(@"%s\n\tERROR: expected sender to be UITextfield instance at line %d",
              __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    // If user enters "@" in username string, hide password views
    if (txfld == tfUsername) {
        BOOL txtContainsAt = [self isSSOUsername];
        
        NSString *btTitle = (txtContainsAt) ? NSLocalizedString(@"SSO LOGIN", nil) : NSLocalizedString(@"LOGIN", nil);
        [btLogin setTitle:btTitle forState:UIControlStateNormal];
        
        if (!_passwordViewsHidden && txtContainsAt) {
            
            [self hideViewsForEnterpriseLoginWithAnimation:YES completion:nil];
        }
        // If txt does not contain "@", show password views
        else if (_passwordViewsHidden && !txtContainsAt) {
            
            [self showHiddenEnterpriseLoginViewsWithAnimation:YES completion:nil];
        }
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    if(textField==tfUsername){
        if(tfUsername.text.length<1)return NO;

#ifdef ENTERPRISE_LOGIN_ENABLED
        /*
         * Modified for SSO 
         */
        if (!_passwordViewsHidden) {
            [tfPassword becomeFirstResponder];
        }
        else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self onLoginPress];
            });
        }
        
        return YES;
#else
        [tfPassword becomeFirstResponder];
        return YES;
#endif        
    }
    
    if(textField == tfPassword && tfPassword.text.length <= 0)
        return NO;
    
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
    [tfPassword addTarget:self
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
    [self launchSafariWithURL:[ChatUtilities buildWebURLForPath:kRecoveryURLPath]];
}

- (IBAction)handleTermsTap:(id)sender {
    [self dismissKeyboard];
    [self launchSafariWithURL:[ChatUtilities buildWebURLForPath:kTermsURLPath]];
}

- (IBAction)handlePrivacyTap:(id)sender {
    [self dismissKeyboard];
    [self launchSafariWithURL:[ChatUtilities buildWebURLForPath:kPrivacyURLPath]];
}

- (void)launchSafariWithURL:(NSURL *)url {
    
    if(!url)
        return;
    
    [[UIApplication sharedApplication] openURL:url];
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
    UIBarButtonItem *bbtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                          target:self
                                                                          action:action];
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
    UIBarButtonItem *bbtn = [[UIBarButtonItem alloc] initWithTitle:title
                                                             style:UIBarButtonItemStyleDone
                                                            target:self
                                                            action:action];
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
    Prov *pr=(__bridge Prov*)p;
    if(pr){
        pr.sso_err = (SC_ProvCode)code;
        NSLog(@"SC_ProvCode %d: %@", code, [NSString stringWithUTF8String:pMsg]);
        [pr cbTLS:code msg:pMsg];
    }
}

void cbFnc(void *p, int ok, const char *pMsg){
   Prov *pr=(__bridge Prov*)p;
   if(pr){
      [pr cbTLS:ok msg:pMsg];
   }
}
