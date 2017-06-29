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
//  SCPCallbackInterface.m
//  SP3
//
//  Created by Eric Turner on 5/13/15.
//  Based on original work by Janis Narbuts SP1
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

#ifndef NULL
#ifdef  __cplusplus
#define NULL    0
#else
#define NULL    ((void *)0)
#endif
#endif

#include <stdio.h>

#import <Foundation/Foundation.h>

#import "DBManager.h"
#import "ChatManager.h"
#import "DBManager+MessageReceiving.h"
#import "SCPCallbackInterface.h"
#import "SCPCallbackInterface_Private.h"
#import "SCPCallbackInterfaceUtilities_Private.h"
#import "SCPCallManager.h"
#import "SCPAccountsManager.h"
#import "SCSAudioManager.h"
#import "SCPMotionManager.h"
#import "SCPNetworkManager.h"
#import "SCPNotificationKeys.h"
#import "SCPPushHandler.h"
#import "STKeychain.h"
#import "StoreManager.h"
#import "UserService.h"
#import "SCPDeviceManager.h"
#import "SCSFeatures.h"
#import "ChatUtilities.h"
#import "SCPNotificationsManager.h"
#import "SCDataDestroyer.h"
#import "SCFileManager.h"
#import "SCPSettingsManager.h"
#import "SCSAvatarManager.h"

#include "engcb.h"
#include "axolotl_glue.h"
#include "interfaceApp/AppInterfaceImpl.h"

#if HAS_DATA_RETENTION
// data retention
#include "dataRetention/ScDataRetention.h"
#include "SCPCall.h"
#endif

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Local C Function Declarations

void initSwitchboard(const char *path);
int checkProvUserPass(const char *pUN, const char *pPWD, const char *pdevID, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);
void cbFnc(void *p, int ok, const char *pMsg); //tmp
void t_init_glob();
void zina_setDataRetentionFlags(const std::string &jsonFlags, int drIsOn);

int32_t s3Helper(const std::string& region, const std::string& requestData, std::string* response);
int32_t httpHelper(const std::string& requestUri, const std::string& method, const std::string& requestData, std::string* response);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


SCPCallbackInterface *Switchboard = nil;
BOOL _bDataRetentionOn = NO;

@interface SCPCallbackInterface ()

@property (strong, nonatomic) SCPDeviceManager *devManager;
@property (strong, nonatomic) SCPMotionManager *motionManager;
@property (strong, nonatomic) SCPPushHandler *pushHandler;

// Utilities
@property (nonatomic) NSInteger iAppStartTime;

@end

@implementation SCPCallbackInterface


+ (void)setup {
    DDLogVerbose(@"%s", __PRETTY_FUNCTION__);

    static SCPCallbackInterface *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#if 0
        setProvisioningToDevelop();
#warning PROVISIONING SERVER SET TO DEVELOP
#endif
        instance = [self new];

        Switchboard = instance;

        // isProvisioned requires FS path to be set
        setFSPath(NULL);

        // Clear NSuserDefaults if user is not yet provisioned
        // This happens to prevent having a filled NSUserDefaults directory
        // after an iCloud backup
        if(![instance isProvisioned])
            [SCDataDestroyer clearUserDefaults];

        // This call will normally be a no op, but will run a file migration
        // operation - moving tivi dir and files from /Documents dir to
        // other locations - if it hasn't yet been run.
        // This call needs to run first and block here before continuing.
        [SCFileManager setup];

        initSwitchboard(NULL);

        instance.iAppStartTime = get_time();

        instance.notificationsManager = [SCPNotificationsManager new];

        instance.callHelper = [SCPCallHelper new];

        instance.networkManager = [SCPNetworkManager new];
        
        instance.userResolver = [SCSUserResolver new];
        
        // Init creates static instances
        (void)[[SCPAccountsManager alloc] init];
        (void)[[SCPCallManager alloc] init];
        (void)[[SCSAudioManager alloc] init];

       //if just init dealloc happens instanly and listeners are removed from SCPDeviceManager
        instance.devManager = [SCPDeviceManager new];

        instance.pushHandler = [SCPPushHandler new];
        
        DDLogVerbose(@"%s Switchboard initialized", __PRETTY_FUNCTION__);
    });
}

+ (SCPCallbackInterface *)sharedInstance {
    return Switchboard;
}


#pragma mark - Accounts Wrapper Methods
- (void *)activeAccounts {
    return [SPAccountsManager activeAccounts];
}
- (NSInteger)countOfActiveAccounts {
    return [SPAccountsManager countOfActiveAccounts];
}
- (BOOL)allAccountsOnline {
    return [SPAccountsManager allAccountsOnline];
}
- (BOOL)accountIsOn:(void *)acct {
    return [SPAccountsManager accountIsOn:acct];
}
- (NSInteger)accountsCountForIsActive:(BOOL)isActive {
    return [SPAccountsManager accountsCountForIsActive:isActive];
}
- (void *)accountAtIndex:(NSInteger)idx {
    return [SPAccountsManager accountAtIndex:idx];
}
- (void *)accountAtIndex:(NSInteger)idx isActive:(BOOL)isActive {
    return [SPAccountsManager accountAtIndex:idx isActive:isActive];
}
//- (NSString *)infoForAccountAtIndex:(NSInteger)idx forKey:(NSString *)aKey {
//    return [_accountsManager infoForAccountAtIndex:idx forKey:aKey];
//}
//- (NSString *)infoForAccountAtIndex:(NSInteger)anID isActive:(BOOL)isActive forKey:(NSString *)aKey {
//    return [_accountsManager infoForAccountAtIndex:anID isActive:isActive forKey:aKey];
//}
- (void *)getCurrentDOut {
    return [SPAccountsManager getCurrentDOut];
}
- (int)setCurrentDOut:(void*)acct {
    return [SPAccountsManager setCurrentDOut:acct];
}
- (NSString *)currentDOutState:(void*)acct { // "yes", "no", "connecting"
    return [SPAccountsManager currentDOutState:acct];
}
- (BOOL)currentDOutIsNULL {
    return [SPAccountsManager currentDOutIsNULL];
}
- (BOOL)isCurrentDOut:(id)sipAccount {
    return [SPAccountsManager isCurrentDOut:sipAccount];
}
- (BOOL)accountAtIndexIsCurrentDOut:(NSInteger)idx {
    return [SPAccountsManager accountAtIndexIsCurrentDOut:idx];
}

- (NSString *)getCurrentDeviceId {

    const char *devid = t_getDevID_md5();

    return [NSString stringWithCString:devid encoding:NSUTF8StringEncoding];
}

- (NSArray *)indexesOfUniqueAccounts {
    return [SPAccountsManager indexesOfUniqueAccounts];
}

- (BOOL)hasNonSilentCircleAccounts {
    return [SPAccountsManager hasNonSilentCircleAccounts];
}


- (NSString *)titleForAccount:(void *)acct {
    return [SPAccountsManager titleForAccount:acct];
}
- (NSString *)numberForAccount:(void *)acct {
    return [SPAccountsManager numberForAccount:acct];
}
- (NSString *)usernameForAccount:(void *)acct {
    return [SPAccountsManager usernameForAccount:acct];
}
- (NSString *)regErrorForAccount:(void *)acct {
    return [SPAccountsManager regErrorForAccount:acct];
}
- (void *)emptyAccount {
    return [SPAccountsManager emptyAccount];
}

#pragma mark - Motion Manager API
- (void)startMotionDetect {
    if (nil == _motionManager) {
        _motionManager = [[SCPMotionManager alloc] init];
        [_motionManager start];
    }
}
- (void)stopMotionDetect {
    [_motionManager stop];
}
- (BOOL)motionDetectIsOn {
    if (nil == _motionManager)
        return NO;
    else
        return [_motionManager isOn];
}

#pragma mark - Networking API

#pragma mark - Provisioning

- (BOOL)isProvisioned {
    int32_t p = isProvisioned(1);
    return (p != 0) ? YES : NO;
}

- (void)startEngineWithProvisioningSuccess {

    t_init_glob();
    
    setupSIPAuth();

    [SCPSettingsManager setup];
    
    const char *xr[]={"",":delay_reg=1",":reg",":onka",":onforeground"};
    int z_main_init(int argc, const char* argv[]);
    z_main_init(5,xr);

    setPhoneCB(&fncCBRet, NULL);

    // Note: this must be called before [DBManager setup]
    [self initAxo];

    NSLog(@"%s Initialize DBManager singleton", __PRETTY_FUNCTION__);
    [DBManager setup];//this will always call ":delay_reg=0"
    
    [SCSAvatarManager setup];

    [Switchboard setCurrentDOut:NULL];

    [[UserService sharedService] checkUser];

    [StoreManager initialize];

    [[StoreManager sharedInstance] checkProducts];
}


#pragma mark - Push Token API

- (BOOL)setPushToken:(NSString *)ptoken {
    return (BOOL)setPushToken(ptoken.UTF8String);
}

#pragma mark - wipeData

-(void)setCfgForDataDestroy {
    doCmd("set cfg.iExitingAndDoSaveNothingOnDisk=1");
}

#pragma mark - Utilities

- (NSInteger)secondsSinceAppStarted {
    NSInteger curTime = get_time();
    NSInteger retInt = curTime - _iAppStartTime;
    return retInt;
}

- (void)setIsShowingVideoScreen:(BOOL)isShowingVideoScreen {

    if(!self.devManager)
        return;

    [self.devManager setIsShowingVideoScreen:isShowingVideoScreen];
}

// The order to initializing things when app launches or
// after user successfully provisions is as follows:
//
// (Everything happens on the main thread)
//
// * setPhoneCB (to listen for engine callbacks)
// * delay_reg=1 (to wait for the DBs to get ready)
// * [Switchboard initAxo] (to initialize zina and open the first zina db/store)
// * [DBManager setup] (to initialize all SPi managers and open the second zina db/store)
// * [DBManager getDatabase] (called by [DBManager setup] to get all the conversations)
// * delay_reg=0 (called by [DBManager getDatabase] after both zina dbs/stores have been opened successfully)
// * [Switchboard setCurrentDOut:NULL] (must be called when app is on foreground (?))
// * [UserService sharedService] checkUser] (same as above)
// * [StoreManager shareInstance] checkProducts] (same as above)
-(void)startListenEngineCallbacks{
    if(!isProvisioned(0))
        return;

    setPhoneCB(&fncCBRet, NULL);

    doCmd(":delay_reg=1");//wait for db to be ready
    doCmd(":reg");

    // Initialize axo instance
    [self initAxo];
}

// IMPORTANT: AppDelegate calls this method at launch
// (once provisioned) BEFORE [DBManager setup] is called. In this way
// we ensure the sharedInstance is initialized with the httpHelper
// function callback before DBManager starts using it. This is
// to fix a race condition causing a crash on slower devices
// (iPhone 5).
// N.B. This call must be preceded by a doCmd call, which ensures
// engMain->start() has been called.
- (void)initAxo {

    //ET: axolotl_glue.cpp setCallbacks static function definition
    // is annotated, "should call this from UI before init" (JN), so
    // this is called first.
    CTAxoInterfaceBase::setCallbacks(stateAxoMsg, receiveAxoMsg, notifyCallback);

    void *getAccountByID(int id, int iIsEnabled);
    const char* sendEngMsg(void *pEng, const char *p);
    const char *un = sendEngMsg(getAccountByID(0, 1), "cfg.un");
    CTAxoInterfaceBase::sharedInstance(un);
}

- (BOOL)isZinaReady {

    zina::AppInterface* t_getAxoAppInterface(void);
    bool isZinaHttpHelperSet(void);

    if(!isZinaHttpHelperSet())
        return NO;

    return (t_getAxoAppInterface() != NULL);
}

#pragma mark - Notifications

- (void)postNotification:(NSString *)key {
    [self postNotification:key obj:self userInfo:nil delay:0];
}

- (void)postNotification:(NSString *)key obj:(id)obj userInfo:(NSDictionary *)uInfo delay:(NSTimeInterval)delay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:key object:obj userInfo:uInfo];
    });
}


#pragma mark TMP?

-(void)alert:(NSString *)str{

    NSLog(@"SCPCallbackInterface ALERT: %@", str);
}

- (int32_t)doCmd:(NSString *)aCmd {
    return doCmd(aCmd.UTF8String);
}
- (int32_t)doCmd:(NSString *)aCmd callId:(int32_t)cid {
    const char *cmd = [aCmd UTF8String];
    return (int32_t)doCmd(cmd, cid);
}

- (NSString *)sendEngMsg:(void *)eng msg:(NSString *)msg {
    const char *r = sendEngMsg(eng, msg.UTF8String);
    return [NSString stringWithUTF8String:r];
}

#if HAS_DATA_RETENTION
#pragma mark -- Data Retention
/*
 - "Block local data retention" [BLDR]

 Enable this setting to absolutely prevent Silent Phone from retaining
 communications plaintext and uploading it to a designated
 organization.  If your organization enables data retention and you
 have this enabled service may be restricted.

 - "Block local metadata retention" [BLMR]

 Enable this setting to absolutely prevent Silent Phone from retaining
 metadata about your communications and uploading it to a designated
 organization.  If your organization enables metadata retention and you
 have this enabled service may be restricted.

 [Enabling BLMR auto-enables BLDR in the UI.]

 - "Block remote data retention" [BRDR]

 Enable this setting to avoid communicating with other Silent Phone
 users who are retaining communications plaintext and uploading it to
 third parties.  If another user is subject to data retention this will
 prevent you from communicating with that user.

 - "Block remote metadata retention" [BRMR]

 Enable this setting to avoid communicating with other Silent Phone
 users who are retaining metadata about your communications and
 uploading it to third parties.  If another user is subject to metadata
 retention this will prevent you from communicating with that user.

 [Enabling BRMR auto-enables BRDR in the UI.]
 */

static NSArray *kDataRetentionBlockFlags = @[@"bldr" // "Block local data retention"
                                 ,@"blmr" // "Block local metadata retention"
                                 ,@"brdr" // "Block remote data retention"
                                 ,@"brmr" // "Block remote metadata retention"
                                 ];

// DR rejection error codes:
//- Not Delivered Due to Policy: DR required [ERRDRQ]
//- Not Delivered Due to Policy: MR required [ERRMRQ]
//- Not Delivered Due to Policy: DR rejected [ERRDRJ]
//- Not Delivered Due to Policy: MR rejected [ERRMRJ]
//- Not Delivered Due to decryption failure [ERRDECF]
//- Not Delivered Due to DR policy and user blocked DR [ERRBLK]

static NSString *kError_DRRecipientBlocked = @"Recipient device declined data retention\n\n"\
        "The user to whom you sent this message has declined to communicate with other users who are subject to data retention. As your organization has a policy of retaining data there's no way to respect both of your wishes. Communication between you is blocked. To allow communication, you could ask that user to deselect \"Block data retention\" in his or her Silent Phone settings or you could ask your organization to disable data retention on your account.";

static NSString *kError_DRRecipientRequires = @"Recipient requires data retention\n\n"\
"The recipient's organization has a policy of retaining data about Silent Phone communications content, however you have blocked Silent Phone from allowing this data to be retained. Communication between you is blocked. To allow communication, unset \"Block data retention\" in Silent Phone settings.";

static NSString *kError_DRDecryptionFailed = @"Recipient was unable to decrypt the message.";

static NSString *kError_DRRecipientUnavailable = @"Recipient is not available.";

NSDictionary *kDR_Policy_Errors = @{@"errdrq":kError_DRRecipientRequires
                                           ,@"errmrq":kError_DRRecipientRequires
                                           ,@"errdrj":kError_DRRecipientBlocked
                                           ,@"errmrj":kError_DRRecipientBlocked
                                           ,@"errdecf":kError_DRDecryptionFailed
                                           ,@"errblk":kError_DRRecipientUnavailable
                                    };

- (void)configureDataRetention:(BOOL)bBlockLocalDR blockRemote:(BOOL)bBlockRemoteDR {
    NSMutableDictionary *flagsDict = [NSMutableDictionary dictionaryWithCapacity:[kDataRetentionBlockFlags count]+3];
    [flagsDict setValue:((bBlockLocalDR) ? @YES : @NO) forKey:@"bldr"];
    [flagsDict setValue:((bBlockLocalDR) ? @YES : @NO) forKey:@"blmr"];
    [flagsDict setValue:((bBlockRemoteDR) ? @YES : @NO) forKey:@"brdr"];
    [flagsDict setValue:((bBlockRemoteDR) ? @YES : @NO) forKey:@"brmr"];

    // set local flags based on user's DR type codes
    uint32_t typeCode = [UserService currentUser].drTypeCode;
    [flagsDict setValue:((typeCode & kDRType_Message_Metadata) ? @YES : @NO) forKey:@"lrmm"]; // "local retains message metadata"
    [flagsDict setValue:((typeCode & kDRType_Message_PlainText) ? @YES : @NO) forKey:@"lrmp"]; // "local retains message plaintext"
    [flagsDict setValue:((typeCode & kDRType_Attachment_PlainText) ? @YES : @NO) forKey:@"lrap"]; // "local retains  attachment plaintext"

    NSData *jsonD = [NSJSONSerialization dataWithJSONObject:flagsDict options:kNilOptions error:nil];
    NSString *jsonS = [[NSString alloc] initWithData:jsonD encoding:NSUTF8StringEncoding];

    if ( (typeCode > 0) && (!bBlockLocalDR) ) {
         zina_setDataRetentionFlags(jsonS.UTF8String , 1);
    } else {
         zina_setDataRetentionFlags(jsonS.UTF8String, 0);
    }
}

- (BOOL)doesUserRetainDataType:(uint32_t)typeCode {
    if ([UserService currentUserBlocksLocalDR])
        return NO;
    return (([UserService currentUser].drTypeCode & typeCode) > 0);
}

- (void)retainCallMetadata:(SCPCall *)call {
    if (!call.SIPCallId)
        return;

    NSString *recipient = [[ChatUtilities utilitiesInstance] removePeerInfo:[call bufPeer] lowerCase:NO];
    if ([call isOCA])
        zina::ScDataRetention::sendSilentWorldCallMetadata(call.SIPCallId.UTF8String, call.isIncoming ? "received" : "placed", "", recipient.UTF8String, call.startTime, call.endTime);
    else
        zina::ScDataRetention::sendInCircleCallMetadata(call.SIPCallId.UTF8String, call.isIncoming ? "received" : "placed", recipient.UTF8String, call.startTime, call.endTime);
}
#endif // HAS_DATA_RETENTION

- (void)rescanLocalUserDevices {
    
    [SCPDeviceManager rescanLocalUserDevices];
}

- (void)rescanDevicesForUserWithUUID:(NSString *)uuid {
    
    [SCPDeviceManager rescanDevicesForUserWithUUID:uuid];
}

/*
-(void)block_fnc:(int) ok msg:(const char *)msg{
    saved_block(ok, msg);
}
*/
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - End ObjC
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
@end

void notifyGeneric(const uint8_t* content, size_t contentLength,
                   const uint8_t* event, size_t eventLength,
                   const uint8_t* contentType, size_t typeLength){

    NSString *body = contentLength? [NSString stringWithFormat:@"%.*s",(int)contentLength, content]:nil;
    NSString *ev = eventLength? [NSString stringWithFormat:@"%.*s",(int)eventLength, event]:nil;
    NSString *cType = typeLength? [NSString stringWithFormat:@"%.*s",(int)typeLength, contentType]:nil;

    // Only post the UserServiceNotification if
    // event == x-sc-refresh-provisioning
    if(ev && [ev isEqualToString:@"x-sc-refresh-provisioning"]) {

        __block NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];

        if(body)  dic[@"body"]  =  body;
        if(ev)    dic[@"event"] =  ev;
        if(cType) dic[@"type"]  =  cType;

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

            [[NSNotificationCenter defaultCenter] postNotificationName:kSCSUserServiceUpdateUserNotification
                                                                object:Switchboard
                                                              userInfo:dic];
            dic = nil;
        });
    }
}

int fncCBRet(void *ret, void *ph, int iCallID, int msgid, const char *psz, int iSZLen){

    if(!iSZLen && psz)iSZLen = (int)strlen(psz);

    while(psz && psz[0]<' ' && psz[0] && iSZLen>0){psz++; iSZLen--;}//psz can start with  c<' '

//    NSString *ns = psz ? [NSString stringWithFormat:@"%.*s", iSZLen, psz] : nil;
    NSString *ns = psz ? [[NSString alloc]initWithBytes:psz
                                                 length:iSZLen
                                               encoding:NSUTF8StringEncoding] : nil;

    DDLogVerbose(@"%@ fncCBRet: msg=%s cid=%d %@",__THIS_FILE__,CT_cb_msg::toString(msgid), iCallID, ns);

    if (iCallID) {
        [SPCallManager handleFncCallback:ret ph:ph iCallID:iCallID msgid:msgid ns:ns];
    }
    else if(msgid == CT_cb_msg::eReg || msgid == CT_cb_msg::eError){
        //TODO if call==NULL where to show registration state ???
        //[phone updateRegStatus:msgid info:ns]
//         updatePhoneUIStateWithAccount:ret

        //JN this is ok , it was CallStateDidChange but it can not be related to call
        [Switchboard postNotification:kSCPEngineStateDidChangeNotification obj:Switchboard userInfo:nil delay:0];
    }
    else{
        NSLog(@"%sYou will never see this... I am sure about that! JN",__PRETTY_FUNCTION__);
    }

    return 0;
}

//void initPhoneLib(const char *path){
void initSwitchboard(const char *path){

    const char *pLang = getPrefLang();//get default lan
    initLang(pLang);

#if defined(DEBUG)
    DDLogVerbose(@"%s build=debug",__PRETTY_FUNCTION__);
#else
    DDLogVerbose(@"%s build=release",__PRETTY_FUNCTION__);
#endif

    devIdErrorCode devIdErrorCode = initDevID();

    // If dev id couldn't not be created
    // then the last wipe of the app wasn't completed successfully
    // (Typically cause NSUserDefaults weren't being cleared properly)
    // So try to wipe the data again.
    if(devIdErrorCode != devIdErrorCodeNoError) {

        [SCDataDestroyer wipeAllAppDataImmediatelyWithCompletion:^{ exit(0); }];
        return;
    }

//    rememberAppStartupTime();

    loadPWDKey();
    
    int isProvisioned(int iCheckNow);
    int z_main_init(int argc, const char* argv[]);
    void initGlobConstr();

    // global config is a key/value file;
    // user config is xml
    if(isProvisioned(1)){
        // setup SIP
        setupSIPAuth();
        
        //initializes the global config
        initGlobConstr();

        [SCPSettingsManager setup];
//        const char *x[]={"",":w 5",":m abc hi",":exit"}; // example of multiple arg commands
        const char *x[]={""};
        // creates/intializes engine singleton
        // accepts multiple arguments
        z_main_init(0,x);
    }
    else{

    }

    // see main.mm SP1
    freemem_to_log();
}

#pragma mark -- S3 callback helper
/*
 * Class:     AxolotlNative
 * Method:    s3Helper
 */
/*
 * HTTP request helper callback for provisioning etc.
 */
int32_t s3Helper(const std::string& region, const std::string& requestData, std::string* response) {

    // region: fully qualified URL
    // requestData: is binary data passed in as 'string'
    NSData *data = [NSData dataWithBytes:requestData.c_str()
                                  length:requestData.length()];

    if ([data length] == 0)
        return -1; // no data??

    NSString *urlS = [NSString stringWithCString:region.c_str()
                                        encoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSInteger statusCode = -1;

    NSHTTPURLResponse *httpResponse = nil;

    [Switchboard.networkManager synchronousApiRequestInEndpoint:urlS
                                                         method:SCPNetworkManagerMethodPUT
                                                      arguments:data
                                                          error:&error
                                                   httpResponse:&httpResponse];

    if(httpResponse)
        statusCode = httpResponse.statusCode;

    return (int32_t)statusCode;
}

#pragma mark - HTTP helper

/*
 * Class:     AxolotlNative
 * Method:    httpHelper
 */
/*
 * HTTP request helper callback for provisioning etc.
 */
int32_t httpHelper(const std::string& requestUri, const std::string& method, const std::string& requestData, std::string* response) {

    if(requestUri.empty())
        return 400; // Bad request if request uri is empty

    SCPNetworkManagerMethod methodEnum = SCPNetworkManagerMethodUnknown;

    if(method == "GET")
        methodEnum = SCPNetworkManagerMethodGET;
    else if(method == "POST")
        methodEnum = SCPNetworkManagerMethodPOST;
    else if(method == "PUT")
        methodEnum = SCPNetworkManagerMethodPUT;
    else if(method == "DELETE")
        methodEnum = SCPNetworkManagerMethodDELETE;
    else if(method == "HEAD")
        methodEnum = SCPNetworkManagerMethodHEAD;

    if(methodEnum == SCPNetworkManagerMethodUnknown)
        return 405; // Method not implemented if the method is not on the list

    NSData *arguments = nil;

    if(!requestData.empty()) {

        NSString *requestDataString = [NSString stringWithCString:requestData.c_str()
                                                         encoding:NSUTF8StringEncoding];

        arguments = [requestDataString dataUsingEncoding:NSUTF8StringEncoding];
    }

    NSError *error = nil;
    NSHTTPURLResponse *httpResponse = nil;

    NSString *apiRequest = [NSString stringWithCString:requestUri.c_str()
                                              encoding:NSUTF8StringEncoding];

    id jsonObject = [Switchboard.networkManager synchronousApiRequestInEndpoint:apiRequest
                                                                         method:methodEnum
                                                                      arguments:arguments
                                                                          error:&error
                                                                   httpResponse:&httpResponse];

    NSInteger statusCode = 444; // No response if there is no http response

    if(httpResponse)
        statusCode = httpResponse.statusCode;

    if(error)
        return (int32_t)statusCode;

    if(jsonObject && [NSJSONSerialization isValidJSONObject:jsonObject]) {

        NSError *serializationError = nil;

        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonObject
                                                           options:0
                                                             error:&serializationError];

        if(jsonData) {

            NSString *jsonString = [[NSString alloc] initWithData:jsonData
                                                         encoding:NSUTF8StringEncoding];


            if(response && jsonString)
                response->assign(jsonString.UTF8String, strlen(jsonString.UTF8String));
        }
    }

    return (int32_t)statusCode;
}

#pragma mark Provisioning Progress Callback
// provisioning callback - originally only logs
void _prov_cb(void *p, int ok, const char *pMsg){
    progressBlock b = (__bridge progressBlock)p;
    b(ok, pMsg);
    //printf("ok=%d msg=%s\n", ok, pMsg);
}

