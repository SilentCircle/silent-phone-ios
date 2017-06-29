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
//  AppDelegate.m
//  SP3
//
//  Created by Eric Turner on 5/24/15.
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//
#import <Intents/Intents.h>

#import "AppDelegate.h"

#import "ChatUtilities.h"
#import "DBManager.h"
#import "Prov.h"
#import "OnboardingViewController.h"
#import "SystemPermissionManager.h"
#import "RavenClient.h"
#import "SCContainerVC.h"
#import "SCFileManager.h"
#import "SCLoggingManager.h"
#import "SCPCallbackInterface.h"
#import "SCPCallManager.h"
#import "SCPCall.h"
#import "SCPNetworkManager.h"
#import "SCPPasscodeManager.h"
#import "SCPNotificationKeys.h"
#import "SCPSettingsManager.h"
#import "SCSCallNavigationVC.h"
#import "SCSContactsManager.h"
#import "SCSContainerController.h"
#import "SCSFeatures.h"
#import "SCSMainTVC.h"
#import "StoreManager.h"
#import "UserService.h"
#import "SCSAvatarManager.h"
// for appearance
#import <QuickLook/QuickLook.h>
#import "UIColor+ApplicationColors.h"

#ifdef DEBUG
static NSString * const RAVEN_DSN = @"https://055d62fcc1eb4d7fab7c8f864c5abc7d:61a318fe1ee344ecba2db5f761d9ccab@sentry.silentcircle.org/12";
#else
static NSString * const RAVEN_DSN = @"https://db31eb70ba7a48429509b5ee78c0224c:c2203dedfed5475181e180ab1ecffdd5@sentry.silentcircle.org/7";
#endif

#define T_DISABLE_BLINK_WARN 1
#define T_CREATE_CALL_MNGR
#define T_SAS_NOVICE_LIMIT 2

static BOOL _fatalErrorEncountered = NO;

// Added for eventual provisioning window handling
@interface AppDelegate() <SCProvisioningDelegate>

@property(retain, nonatomic) UIWindow *cachedWindow;
@property(retain, nonatomic) UIWindow *provWindow;
@property(retain, nonatomic) SCContainerVC *provRootVC;

@end

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelWarning;
//#endif


@implementation AppDelegate

@synthesize window;


- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#ifdef DEBUG    
    if ([SCSFeatures enableLogging]) {
        _logManager = [SCLoggingManager new];
        [_logManager configureLogging];
    }
#endif
    
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{  
    DDLogInfo(@"%s SCPCallbackInterface setup", __PRETTY_FUNCTION__);
    [SCPCallbackInterface setup];
    
    [self setupRaven];
    
    [self setupAppearance];
    
    self.containerVC = (SCSContainerController*)self.window.rootViewController;
    
    // sign up for user update notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notifyUserDidUpdate:)
                                                 name:kSCSUserServiceUserDidUpdateNotification
                                               object:nil];

    // present provisioning VC if not yet provisioned
    if(![Switchboard isProvisioned]) {
        
        // Remove any passcode that might exist in the Keychain from a previous installation
        [[SCPPasscodeManager sharedManager] deletePasscode];
        
        [self setupAndDisplayProvisioningWindow];
    }
    else {
        
        [Switchboard startListenEngineCallbacks];
        
        [DBManager setup];
        [SCSAvatarManager setup];
        
        [UserService sharedService];
        
        [StoreManager initialize];
        
        // Needed in order to be able to blur the view
        [self.window makeKeyWindow];

        [SystemPermissionManager startPermissionsCheck];
    }
   
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    DDLogInfo(@"%s", __FUNCTION__);
    
    if (_fatalErrorEncountered) {
        return;
    }
    
    [[DBManager dBManagerInstance] loadBackgroundTasks];

    BOOL isProvisioned = [Switchboard isProvisioned];

    if (isProvisioned) {
        
        [Switchboard setCurrentDOut:NULL];
		[[UserService sharedService] checkUser];
		[[StoreManager sharedInstance] checkProducts];
	}
    else
        [self setupAndDisplayProvisioningWindow];
    
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    DDLogVerbose(@"%s", __PRETTY_FUNCTION__);
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    DDLogVerbose(@"%s", __PRETTY_FUNCTION__);
    [SCFileManager cleanMediaCache];
}

#pragma mark - Public

- (BOOL)replaceCurrentWindowWithWindow:(UIWindow *)newWindow {
    
    // Do not allow further replacement if the cacheWindow is already holding the original window
    if(_cachedWindow)
        return NO;
    
    _cachedWindow = self.window;
    
    self.window = newWindow;
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (BOOL)restoreWindow {
    
    if(!_cachedWindow)
        return NO;
    
    self.window = _cachedWindow;
    [self.window makeKeyAndVisible];
    
    _cachedWindow = nil;
    
    return YES;
}

#pragma mark - Provisioning

-(void)showProvScreen{
    
    // SSO / Account Creation / Individual login
    UIStoryboard *sbProv = [UIStoryboard storyboardWithName:@"Prov" bundle:nil];
    Prov *provVC = [sbProv instantiateInitialViewController];
    provVC.delegate = self;
    
    [self needsDisplayProvisioningController:provVC animated:NO];
}


#pragma mark - Provisioning Window

- (void)setupAndDisplayProvisioningWindow {
    
//    if (self.cachedWindow == self.window) return;
    if (self.provWindow && self.provWindow == self.window) return;
    
    // Clear any pending local notifications and reset the badge number
    // We do that because the app badge might indicate that there are X unread notifications
    // if the user uninstalled the app before opening it to read them
    //
    // In general, we want to reset any existing notifications if the user is presented with the
    // provisioning screen
    [Switchboard.notificationsManager cancelAllNotifications];

    self.cachedWindow = self.window;
    _cachedWindow.hidden = YES;
    
    self.provWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UIStoryboard *sbProv = [UIStoryboard storyboardWithName:@"Prov" bundle:nil];
    SCContainerVC *rootVC = nil;

    OnboardingViewController *onboardingViewC = [sbProv instantiateViewControllerWithIdentifier:@"Onboarding"];
    onboardingViewC.provDelegate = self;    
    rootVC = [[SCContainerVC alloc] initWithViewController:onboardingViewC];
        
    rootVC.view.frame = _provWindow.bounds;
    self.provRootVC = rootVC;
    
    self.provWindow.rootViewController = rootVC;
    self.window = _provWindow;
    [self.window makeKeyAndVisible];
}

- (void)cleanupProvisioningAndDisplayAppWindowWithCompletion:(void (^)())completion {
    
    _cachedWindow.hidden = NO;
    _cachedWindow.alpha = 0.0;
    
    [UIView animateWithDuration:1. animations:^{
        
        self.window = _cachedWindow;
        [self.window makeKeyAndVisible];
        
        _cachedWindow.alpha = 1.0;
        _provWindow.alpha = 0.0;
        
    } completion:^(BOOL finished) {
        
        self.provRootVC = nil;
        self.provWindow = nil;
        self.cachedWindow = nil;
        
        if (completion) {
            completion();
        }
    }];
}


//----------------------------------------------------------------------
#pragma mark - SCProvisioningDelegate Methods
//----------------------------------------------------------------------
- (void)provisioningDidFinish {
    
    [Switchboard startEngineWithProvisioningSuccess];
    
    __weak AppDelegate *weakSelf = self;
    
    [self cleanupProvisioningAndDisplayAppWindowWithCompletion:^{
        
        __strong AppDelegate *strongSelf = weakSelf;
        
        if(!strongSelf)
            return;
        
        [SystemPermissionManager startPermissionsCheck];
    }];
}

- (void)needsDisplayProvisioningController:(UIViewController*)vc animated:(BOOL)animated {
    // Do not try to switch to vc if already the active vc
    if (_provRootVC.activeVC == vc) {
        return;
    }
    [_provRootVC presentVC:vc animationOption:UIViewAnimationOptionTransitionCrossDissolve duration:0.15];
}

- (void)viewControllerDidCancelCreate:(UIViewController *)vc {
    [self showProvScreen];
}

-(void) showProvisioningFromOnboarding
{
    [self showProvScreen];
}
//----------------------------------------------------------------------
// End SCProvisioningDelegate
//----------------------------------------------------------------------

#pragma mark - Notification Center Handlers

- (void)application:(UIApplication *)app didReceiveLocalNotification:(UILocalNotification *)notif {
    DDLogVerbose(@"%s", __PRETTY_FUNCTION__);
    
    [Switchboard.notificationsManager handleActionWithIdentifier:nil forLocalNotification:notif];
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)())completionHandler
{
    DDLogVerbose(@"%s", __PRETTY_FUNCTION__);
    [Switchboard.notificationsManager handleActionWithIdentifier:identifier forLocalNotification:notification];

    completionHandler();
}

- (void)notifyUserDidUpdate:(NSNotification *)note {
    SPUser *currentUser = [UserService currentUser];
    if(!currentUser)
        return;
    
    if(currentUser.uuid && currentUser.displayAlias) {
        [[RavenClient sharedClient] setUser:@{
                                              @"id" : currentUser.uuid,
                                              @"username" : currentUser.displayAlias
                                              }];
    }
#if HAS_DATA_RETENTION
    // check if we explicitly block DR
    [Switchboard configureDataRetention:[UserService currentUserBlocksLocalDR] blockRemote:[UserService currentUserBlocksRemoteDR]];
#endif // HAS_DATA_RETENTION
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nullable))restorationHandler {
    
    if(![Switchboard isProvisioned])
        return NO;
    
    // Is the device running iOS10?
    if(![INStartAudioCallIntent class])
        return NO;
 
    BOOL isAudioCall   = [userActivity.activityType isEqualToString:INStartAudioCallIntentIdentifier];
    BOOL isVideoCall   = [userActivity.activityType isEqualToString:INStartVideoCallIntentIdentifier];
    BOOL isTextMessage = [userActivity.activityType isEqualToString:INSendMessageIntentIdentifier];
    
    // Only allow  audio calls, video calls and text messages
    if(!isAudioCall && !isVideoCall && !isTextMessage)
        return NO;
    
    if(!userActivity.interaction)
        return NO;
    
    NSString *messageContent = @"";
    INPerson *person = nil;
    
    if(isAudioCall) {

        INStartAudioCallIntent *startAudioCallIntent = (INStartAudioCallIntent*)userActivity.interaction.intent;
        
        if(!startAudioCallIntent)
            return NO;
        
        person = [startAudioCallIntent.contacts firstObject];
    }
    else if(isVideoCall){
        
        INStartVideoCallIntent *startVideoCallIntent = (INStartVideoCallIntent*)userActivity.interaction.intent;
        
        if(!startVideoCallIntent)
            return NO;
        
        person = [startVideoCallIntent.contacts firstObject];
    }
    else {
        
        INSendMessageIntent *sendMessageIntent = (INSendMessageIntent *)userActivity.interaction.intent;
        
        if(!sendMessageIntent)
            return NO;
        
        if(sendMessageIntent.content)
            messageContent = sendMessageIntent.content;
        
        person = [sendMessageIntent.recipients firstObject];
    }
    
    if(!person)
        return NO;
    
    NSString *personValue = person.personHandle.value;
    
    if(!personValue)
        return NO;

    NSString *peerAddress = [[SCSContactsManager sharedManager] cleanContactInfo:personValue];
    
    if(![[ChatUtilities utilitiesInstance] isNumber:peerAddress])
        peerAddress = [[ChatUtilities utilitiesInstance] addPeerInfo:peerAddress
                                                           lowerCase:YES];

    if(isAudioCall)
        [self.containerVC presentCallScreenForContactName:peerAddress
                                        queueVideoRequest:NO];
    else if(isVideoCall)
        [self.containerVC presentCallScreenForContactName:peerAddress
                                        queueVideoRequest:YES];
    else
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCPNeedsTransitionToChatWithContactNameNotification 
                                                            object:self 
                                                          userInfo:@{
                                                                     kSCPContactNameDictionaryKey       : peerAddress,
                                                                     kSCPMessageContentDictionaryKey    : messageContent
                                                                     }];
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options {
    
    if(![Switchboard isProvisioned])
        return NO;
    
    if ([[url scheme] isEqualToString:@"file"]) {
        
        // Check if user has permission to upload attachments
        if (![[UserService currentUser] hasPermission:UserPermission_SendAttachment]) {
            
            // off-load to upsell flow
            [[UserService sharedService] upsellPermission:UserPermission_SendAttachment];
            return NO;
        }
        
        [self.containerVC presentShareSheetWithFileURL:url];
    }
    else if([[url scheme] isEqualToString:@"silentphone"] || [[url scheme] isEqualToString:@"sip"]) {
        
        NSString *username = [url resourceSpecifier];
        
        if(!username)
            return NO;
        
        [[ChatUtilities utilitiesInstance] checkIfContactNameExists:username
                                                         completion:^(RecentObject *updatedRecent) {
                                                             
             if(updatedRecent)
                 [[NSNotificationCenter defaultCenter] postNotificationName:kSCPNeedsTransitionToChatWithContactNameNotification 
                                                                     object:self 
                                                                   userInfo:@{ kSCPContactNameDictionaryKey : username}];
             else
                 [self.containerVC displayAlertWithText:NSLocalizedString(@"Error", nil)
                                                message:NSLocalizedString(@"User not found", nil)];
         }];
    }
    
    return YES;
}


#pragma mark - Rotation Handling

- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window{
    
    // Handle rotation callback for provisioning window
    // App will crash here if the rootVC is the SCContainerVC class, as
    // it is for the provisioning window.
    if (NO == [self.window.rootViewController isKindOfClass:[SCSContainerController class]]) {
        return UIInterfaceOrientationMaskAll;
    }

    /* burger
    // Rotation for videoVC may be any orientation, otherwise, portrait
    SCSContainerController *containerVC = (SCSContainerController*)self.window.rootViewController;
    SCSRootViewController *rootVC = [containerVC rootViewController];
    if ([rootVC callNavIsPresented]) {
        return [rootVC supportedInterfaceOrientations];
    }
    return UIInterfaceOrientationMaskPortrait;
     */
    SCSContainerController *containerVC = (SCSContainerController*)self.window.rootViewController;
    return [containerVC supportedInterfaceOrientations];
}

#pragma mark - Push Notification register settings
// The only callback after user has accepted/denied push notifications is here
// NOTE: this is deprecated in iOS10
- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    [SystemPermissionManager permissionCheckComplete:Switchboard.notificationsManager];
}

#pragma mark - Raven

- (void)setupRaven {
    
    // Setup exception handling via Raven (Sentry)
    RavenClient *client = [RavenClient clientWithDSN:RAVEN_DSN];
    [RavenClient setSharedClient:client];
    [[RavenClient sharedClient] setTags:@{
                                          @"Build version": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]
                                          }
                      withDefaultValues:YES];
    
    SPUser *currentUser = [UserService currentUser];
    if (currentUser && currentUser.uuid && currentUser.displayAlias) {
        [[RavenClient sharedClient] setUser:@{
                @"id" : currentUser.uuid,
                @"username" : currentUser.displayAlias
        }];
    }
    
    [[RavenClient sharedClient] setupExceptionHandler];
}

#pragma mark - Appearance

// Fixes navigation bar appearance throughout the app
- (void) setupAppearance {
    
    NSArray *classes = @[[UINavigationController class],
                         [QLPreviewController class],
                         [UIImagePickerController class],
                         [CNContactViewController class],
                         [CNContactPickerViewController class]
                         ];
    
//    UIFont *preferredFont = [[ChatUtilities utilitiesInstance] getFontWithSize:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline].pointSize];
    
    [[UINavigationBar appearance] setTintColor:[UIColor lightBgColor]];
    for(Class className in classes) {
        
        [[UINavigationBar appearanceWhenContainedInInstancesOfClasses:@[className]] setTranslucent:NO];
        [[UINavigationBar appearanceWhenContainedInInstancesOfClasses:@[className]] setTitleTextAttributes:@{
                                                                                                             NSForegroundColorAttributeName: [UIColor navBarTitleColor],
                                                                                                             NSFontAttributeName: [[ChatUtilities utilitiesInstance] getMediumFontWithSize:17]
                                                                                                             }];
        [[UINavigationBar appearanceWhenContainedInInstancesOfClasses:@[className]] setBarTintColor:[ChatUtilities utilitiesInstance].kNavigationBarColor];
        [[UINavigationBar appearanceWhenContainedInInstancesOfClasses:@[className]] setBackgroundImage:[UIImage new]
                                                                                         forBarMetrics:UIBarMetricsDefault];
        [[UINavigationBar appearanceWhenContainedInInstancesOfClasses:@[className]] setShadowImage:[UIImage new]];
    }
}

#pragma mark - Back To Call Touches

// Catch the touches and detect when the status bar is tapped
// (Used in the SCSReturnToCallButton class)
- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    [super touchesBegan:touches withEvent:event];
    
    CGPoint location = [[[event allTouches] anyObject] locationInView:[self window]];
    CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
    
    if (CGRectContainsPoint(statusBarFrame, location))
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCPStatusBarTappedNotification
                                                            object:self];
}


#pragma mark - End ObjC
@end


/**********************************************************************/
/**
 * Note that this function definition here requires this AppDelegate.m 
 * to become AppDelegate.mm.
 */
//void exitWithFatalErrorMsg(const char *msg){
void exitWithFatalErrorMsg(const char *msg) {
    _fatalErrorEncountered = YES;
    NSString *_msg = [NSString stringWithUTF8String:msg];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(2);
        dispatch_async(dispatch_get_main_queue(), ^{
            
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Fatal Error", nil)
                                                                        message:_msg
                                                                 preferredStyle:UIAlertControllerStyleAlert];
            
            
            [ac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Exit", nil)
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action){
                                                     exit(0);
                                                 }]];
            
            AppDelegate *app = (AppDelegate*)[UIApplication sharedApplication].delegate;
            
            UIViewController *vc = app.window.rootViewController;
            
            [vc presentViewController:ac animated:YES completion:nil];
        });
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            sleep(2);
            void t_onEndApp();
            t_onEndApp();
            sleep(30);
            exit(0);
        });
    });    

    NSString *log_msg = [NSString stringWithFormat:@"FATAL ERROR: %@", _msg];
    DDLogError(@"%s %@", __FUNCTION__, log_msg);
}

/**********************************************************************/



