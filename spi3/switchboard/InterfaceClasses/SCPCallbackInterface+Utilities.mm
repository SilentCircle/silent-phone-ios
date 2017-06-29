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
//  SCPCallbackInterface+Utilities.m
//  SCPSwitchboard
//
//  Created by Eric Turner on 5/24/15.
//  Based on original work by Janis Narbuts SP1
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "SCPCallbackInterface+Utilities.h"
#import "SCPCallbackInterfaceUtilities_Private.h"
#import "STKeychain.h"
#import "SCSPLog_private.h"

#include <string>

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif


#define APIKEY_AESINDEX 1100 // Note: Do not change this value, as this will break the decryption of existing API keys!


@implementation SCPCallbackInterface (Utilities)


////////////////////////////////////////////////////////////////////////
#pragma mark - End ObjC
////////////////////////////////////////////////////////////////////////
@end


#define T_MAX_DEV_ID_LEN 63
#define T_MAX_DEV_ID_LEN_BIN (T_MAX_DEV_ID_LEN/2)

#pragma mark - AppID

const char *getAppID(){
    static char appid[256]={0};
    if(appid[0])return appid;
    
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    
#if defined(USE_PRODUCTION_APNS)
#warning "info: using production APNS"
    snprintf(appid, sizeof(appid), "%s.voip",bundleIdentifier.UTF8String);
    DDLogVerbose(@"-(%@) Using PRODUCTION APNS %@.voip",__THIS_FILE__,bundleIdentifier);
#else
#warning "info: using development APNS"
    snprintf(appid, sizeof(appid), "%s.voip--DEV",bundleIdentifier.UTF8String);
    DDLogVerbose(@"-(%@) Using DEVELOPMENT APNS %@.voip",__THIS_FILE__,bundleIdentifier);
#endif
        
    return appid;
}

#pragma mark - SIP Auth

const char * getAPIKeyForProv(); // forward declaration

extern int32_t setSIPPassword(const std::string& password);
extern int32_t setSIPAuthName(const std::string& password);
extern const char *t_getDevID_md5();

void setupSIPAuth() {
    setSIPPassword(getAPIKeyForProv());
    setSIPAuthName(t_getDevID_md5());
}

#pragma mark - PWDKey

NSString * const kSIP_PWD_UsernameKey = @"_SIP_USER_PWD_KEY";
NSString * const kSIP_PWD_ServiceNameKey = @"_SIP_SC";

#define T_AES_KEY_SIZE 32

void loadPWDKey(){
    
#define T_AES_KEY_SIZE 32
    DDLogVerbose(@"-(%@)%s  <--",__THIS_FILE__, __FUNCTION__);
    
    unsigned char buf[T_AES_KEY_SIZE+2];
    char bufHex[T_AES_KEY_SIZE*2+2];
    memset(buf, 0, sizeof(buf));
    
    NSError *er =nil;
    NSString * key = [STKeychain getPasswordForUsername:kSIP_PWD_UsernameKey
                                         andServiceName:kSIP_PWD_ServiceNameKey error:&er];
    
    if(key)key = [[NSString alloc]initWithString:key];
    
    if(er){
        DDLogError(@"-(%@)loadPWDKey: Error getPasswordForUsername: %@", 
                   __THIS_FILE__, er.debugDescription);
    }
        
    if(!key || key.length<1){
        DDLogInfo(@"-(%@)loadPWDKey: PWDKey not found in keychain",__THIS_FILE__);
        
        FILE *f=fopen("/dev/urandom","rb");
        if(f){
            
            fread(buf,1,T_AES_KEY_SIZE,f);
            bin2Hex(buf, bufHex, T_AES_KEY_SIZE);
            if(key)[key release];
            
            NSError *er =nil;
            key = [[NSString alloc] initWithUTF8String: bufHex ];            
            [STKeychain storeUsername:kSIP_PWD_UsernameKey andPassword:key
                       forServiceName:kSIP_PWD_ServiceNameKey updateExisting:NO error:&er];
            
            if (er) {
                DDLogError(@"-(%@)loadPWDKey Error saving PWDKey to keychain: %@",
                           __THIS_FILE__, er.debugDescription);
            } else { 
                DDLogInfo(@"-(%@)loadPWDKey PWDKey saved to keychain",__THIS_FILE__);
            }
            
            fclose(f);
        }
    }
    else{
        int l = (int)key.length;
        if(l > T_AES_KEY_SIZE*2)l = T_AES_KEY_SIZE*2;
        hex2BinL(buf, (char*)key.UTF8String, l);
    }
    
    void setPWDKey(unsigned char *k, int iLen);
    setPWDKey(buf, T_AES_KEY_SIZE);
    
    if(key)[key release];
    
    DDLogVerbose(@"-(%@)loadPWDKey  -->",__THIS_FILE__);
}

#pragma mark - API Key

NSString * const kSIP_API_ServiceNameKey = @"_SIP_API";
NSString * const kSIP_API_UsernameKey    = @"_API";
NSString * const kSIP_API_UserDefaultsKey= @"kSCAPIUserDefaultsKey";

/**
 storeGetAPIKey is used to read (iGet = 1) or write (iGet = 0) the API key
 
 We are storing and retrieving the API key in the Keychain.
 
 While there are multiple ways of the writing/reading the API key (NSUserDefaults, filesystem access, Keychain),
 only the keychain API gives us the option to a) store the API key securely and b) access if (read/write) even if the 
 device is locked (ref: kSecAttrAccessibleAlwaysThisDeviceOnly).
 
 More precisely, for the filesystem case, we would require the API key to be encrypted/decrypted first but this 
 process would require the use of encryptPWD/decryptPWD methods that used the Keychain. So there is no point of using 
 the Keychain for one thing and the filesystem of another.

 Also for the NSUserDefaults case, we would face the above problem but also the fact that if the device is rebooted, 
 the app hasn't launched yet and user received an incoming call notification, then when the app would launch in the background,
 the contents of NSUserDefaults wouldn't be available (ref: [UIApplication sharedApplication].isProtectedDataAvailable).
 
 ref: http://stackoverflow.com/a/20893564/60949
 
 @param iGet 1 if we want to read the API key and 0 if we want to write the API key
 @param p The API key used in the case we are writing the API key (iGet = 0)
 
 @return The API key. If the API key is not found, NULL is returned but before that an exception is raised.
 */
static const char *storeGetAPIKey(int iGet, const char *p = NULL){
    DDLogVerbose(@"-(%@)storeGetAPIKey  -->",__THIS_FILE__);
    
    NSString *argKey = (p==NULL) ? @"NULL" : [NSString stringWithUTF8String:p];
    NSString *funcDescr = [NSString stringWithFormat:@"storeGetAPIKey(%i, %@)", iGet, argKey];
   
    static char bufAPI[128]="";
    
    if(iGet) {
        
        NSError *er =nil;

       
       
        //if we have it in memory return it, do not try to load the apikey it will never change
       if(bufAPI[0]){
          return &bufAPI[0];
       }
       
        
        // Check NSUserDefaults (left for porting the older implementation for existing SPi3 users)
        if([[NSUserDefaults standardUserDefaults] stringForKey:kSIP_API_UserDefaultsKey]) {
           
            memset(bufAPI, 0, sizeof(bufAPI));
           
            NSString *encodedAPIKey = [[NSUserDefaults standardUserDefaults] stringForKey:kSIP_API_UserDefaultsKey];
            
            int isAESKeySet(void);
            
            if(!isAESKeySet()){
                
                NSString *msg = @"called: isAESKeySet() returned false (no pwd set). Throwing generic exception instead of returning NULL apiKey";
                NSString *reason = [NSString stringWithFormat:@"%@ %@", funcDescr, msg];
                @throw [NSException exceptionWithName:NSGenericException reason:reason userInfo:nil];
                
                return NULL;
            }
            
            int decryptPWD(const char *hexIn, int iLen, char *outPwd, int iMaxOut, int iIndex);
            
            // Decrypt it
            decryptPWD(encodedAPIKey.UTF8String, (int)strlen(encodedAPIKey.UTF8String), bufAPI, sizeof(bufAPI), APIKEY_AESINDEX);
            
            bufAPI[sizeof(bufAPI)-1]=0;
            
            // Save it to keychain
            [STKeychain storeUsername:kSIP_API_UsernameKey
                          andPassword:[NSString stringWithUTF8String:bufAPI]
                       forServiceName:kSIP_API_ServiceNameKey
                       updateExisting:YES
                                error:&er];
            
            if(er){
                
                if(er)
                    DDLogError(@"(%@)storeGetAPIKey - Error: APIKey could not be saved in keychain: %@",
                               __THIS_FILE__, er.debugDescription);
                    
                
                NSString *msg = @"APIKey could not be saved in keychain. Throwing generic exception instead of returning NULL apiKey";
                NSString *reason = [NSString stringWithFormat:@"%@ %@", funcDescr, msg];
                @throw [NSException exceptionWithName:NSGenericException reason:reason userInfo:nil];
                
                return NULL;
            }
            
            // Remove it from NSUserDefaults
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSIP_API_UserDefaultsKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
        // Read from Keychain
        } else {
            memset(bufAPI, 0, sizeof(bufAPI));
            
            NSString *key = [STKeychain getPasswordForUsername:kSIP_API_UsernameKey
                                                andServiceName:kSIP_API_ServiceNameKey
                                                         error:&er];
            
            if(key && key.length>0) {
                
                strncpy(bufAPI, key.UTF8String, sizeof(bufAPI));
                bufAPI[sizeof(bufAPI)-1]=0;
                
            } else {
                
                if(er)
                    DDLogError(@"(%@)storeGetAPIKey - Error: APIKey not found in keychain: %@\nThrow generic exception instead of returning NULL apiKey.",
                               __THIS_FILE__, er.debugDescription);
                
                NSString *msg = @"APIKey not found in keychain. Throwing generic exception instead of returning NULL apiKey";
                NSString *reason = [NSString stringWithFormat:@"%@ %@", funcDescr, msg];
                @throw [NSException exceptionWithName:NSGenericException reason:reason userInfo:nil];
                
                // If the key cannot be found either in filesystem nor in Keychain
                // we have to wipe all the data from the app and present the user with a provisioning window
                return NULL;
            }
        }
        
        return &bufAPI[0];
        
    } else {
       
        memset(bufAPI, 0, sizeof(bufAPI));
       
        NSError *er =nil;
        
        [STKeychain storeUsername:kSIP_API_UsernameKey
                      andPassword:[NSString stringWithUTF8String:p]
                   forServiceName:kSIP_API_ServiceNameKey
                   updateExisting:YES
                            error:&er];
        
        if(er){
            
            if(er)
                DDLogError(@"(%@)storeGetAPIKey - Error: APIKey could not be saved in keychain: %@",
                           __THIS_FILE__, er.debugDescription);
            
            NSString *msg = @"APIKey could not be saved in keychain. Throwing generic exception instead of returning NULL apiKey";
            NSString *reason = [NSString stringWithFormat:@"%@ %@", funcDescr, msg];
            @throw [NSException exceptionWithName:NSGenericException reason:reason userInfo:nil];
            
            return NULL;
        }
    }
    
    DDLogVerbose(@"-(%@)storeGetAPIKey  <--",__THIS_FILE__);
    
    return p;
}

//----------------------------------------------------------------------
//ET 04/20/16
// These C functions are required to wrap the getStoreAPIKey function
// because it contains ObjC code, which the compiler disallows when
// calling directly from Prov.cpp function.
//
// Function renamed to reduce confusion (mine)
//
//int storeAPIKeyToKC(const char *p){
int storeProvAPIKey(const char *p){
    const char *r = storeGetAPIKey(0, p);
    return r ? 0 : -1;
}
//const char * getAPIKeyFromKC(){
const char * getAPIKeyForProv(){
    return storeGetAPIKey(1, NULL);
}
//----------------------------------------------------------------------

#pragma mark - PushToken
static char push_token[256]={0};
const char *push_fn = "push-token.txt";
char *getFileStorePath();
char *loadFile(const  char *fn, int &iLen);

const char *getPushToken(){
    if(push_token[0]) return &push_token[0];
    static int iTestet=0;
    if(!iTestet){
        iTestet=1;
        char fn[2048];
        snprintf(fn,sizeof(fn)-1, "%s/%s", getFileStorePath(), push_fn);
        
        int l=0;
        char *p = loadFile(fn, l);
        if(p && l>0){
            snprintf(push_token, sizeof(push_token),"%s",p);
            delete p;
        }
        
    }
    
    return &push_token[0];
}

bool setPushToken(const char *p) {
    
    int l = snprintf(push_token, sizeof(push_token),"%s",p);
    char fn[2048];
    snprintf(fn,sizeof(fn)-1, "%s/%s", getFileStorePath(),push_fn);
    
    saveFile(fn, (void*)p, l);
    
    void *getAccountByID(int id);
    void * ph = getAccountByID(0);
    
    if(!ph) {
        return false;
    }
    
    const char* sendEngMsg(void *pEng, const char *p);
    
    const char*res =  sendEngMsg(NULL, "all_online");
    
    if(res && strcmp(res,"true")==0){

        sendEngMsg(NULL,":rereg");
        return true;
    }
    
    return false;
}

#pragma mark - Utilities

int getIOSVersion(){
    static int v =0;
    if(v)return v;
    NSString *ver = [[UIDevice currentDevice] systemVersion];
    v = [ver intValue];
    return v;
}

const char *getVersionName(){
    
    static char buf[256]={0};
    if(buf[0])return buf;
    
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
    
    snprintf(buf, sizeof(buf), "%s",version.UTF8String);
    return buf;
}

const char *getPrefLang(){
    NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
    NSArray* languages = [defs objectForKey:@"AppleLanguages"];
    NSString *current = [languages objectAtIndex:0];
    DDLogDebug(@"-(%@)getPrefLang %@",__THIS_FILE__, current);

    return current.UTF8String;
}

const char *getSystemCountryCode(void){
   NSLocale *currentLocale = [NSLocale currentLocale];  // get the current locale.
   NSString *countryCode = [currentLocale objectForKey:NSLocaleCountryCode] ;//]NSLocaleCountryCode];
   
   if(!countryCode)return "us";
   
   return [countryCode lowercaseString].UTF8String;
   
}

#import <mach/mach.h>
#import <mach/mach_host.h>
float cpu_usage()
{
    //--
    return 0.1;
    //cpu_usage is  leaking memory????
    
#if 0
    kern_return_t kr;
    task_info_data_t tinfo;
    mach_msg_type_number_t task_info_count;
    
    task_info_count = TASK_INFO_MAX;
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    
    task_basic_info_t      basic_info;
    thread_array_t         thread_list;
    mach_msg_type_number_t thread_count;
    
    thread_info_data_t     thinfo;
    mach_msg_type_number_t thread_info_count;
    
    thread_basic_info_t basic_info_th;
    uint32_t stat_thread = 0; // Mach threads
    
    basic_info = (task_basic_info_t)tinfo;
    
    // get threads in the task
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return -1;
    }
    if (thread_count > 0)
        stat_thread += thread_count;
    
    long tot_sec = 0;
    long tot_usec = 0;
    float tot_cpu = 0;
    int j;
    
    for (j = 0; j < thread_count; j++)
    {
        thread_info_count = THREAD_INFO_MAX;
        kr = thread_info(thread_list[j], THREAD_BASIC_INFO,
                         (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            return -1;
        }
        
        basic_info_th = (thread_basic_info_t)thinfo;
        
        if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
            tot_sec = tot_sec + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
            tot_usec = tot_usec + basic_info_th->user_time.microseconds + basic_info_th->system_time.microseconds;
            tot_cpu = tot_cpu + basic_info_th->cpu_usage *100/ (float)TH_USAGE_SCALE;
        }
        
    } // for each thread
    
    return tot_cpu;
#endif
}

vm_size_t usedMemory(void) {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    return (kerr == KERN_SUCCESS) ? info.resident_size : 0; // size in bytes
}

unsigned int get_free_memory() {
    mach_port_t host_port;
    mach_msg_type_number_t host_size;
    vm_size_t pagesize;
    host_port = mach_host_self();
    host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    host_page_size(host_port, &pagesize);
    vm_statistics_data_t vm_stat;
    
    if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS) {
        DDLogWarn(@"-(%@)usedMemory: Failed to fetch vm statistics",__THIS_FILE__);
        return 0;
    }
    
    /* Stats in bytes */
    unsigned int mem_free = (unsigned int)(vm_stat.free_count * pagesize);
    return mem_free;
}

void freemem_to_log(){
    unsigned int uiU=(unsigned int)usedMemory();
    unsigned int ui=get_free_memory();
    DDLogVerbose(@"-(%@)freemem_to_log: freemem=%dK, used-mem=%dK",__THIS_FILE__,ui>>10, uiU>>10);
}

#pragma mark - Logging

void tivi_log1(const char *p, int val){    
    NSString *msg = [NSString stringWithFormat:@"%s, %d", p, val];
    NSString *tag = [NSString stringWithFormat:@"%@ tivi_log1", __THIS_FILE__];
    ios_log_tivi(tivi_log, tag.UTF8String, msg.UTF8String);
}

void tmp_log(const char *p){
    NSString *tag = [NSString stringWithFormat:@"%@ tmp_log", __THIS_FILE__];
    ios_log_tivi(tivi_log, tag.UTF8String, p);
}

//ET: this appears to be unused
void Log(char const* format, ...){
    char buf[2048];
    
    va_list arg;
    va_start(arg, format);
    vsnprintf(buf, sizeof(buf), format, arg);
    va_end( arg );
    
    ios_log_tivi(tivi_log, @"axolog: ".UTF8String, buf);
}

int iAppStartTime;
int get_time();

int secSinceAppStarted(){
    return get_time()-iAppStartTime;
}

void rememberAppStartupTime(){
    iAppStartTime=get_time();
}


