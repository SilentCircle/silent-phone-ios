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
//
//  Created by Janis Narbuts on 4.2.2012.
//

#import <UIKit/UIKit.h>
#import "KeychainItemWrapper.h"

int isBackgroundReadable(const char *fn);
void log_file_protection_prop(const char *fn);
void setFileAttributes(const char *fn, int iProtect);
char *loadFile(const  char *fn, int &iLen);
void saveFile(const char *fn,void *p, int iLen);
void bin2Hex(unsigned char *Bin, char * Hex ,int iBinLen);
int hex2BinL(unsigned char *Bin, char *Hex, int iLen);

//http://www.ios-developer.net/iphone-ipad-programmer/development/file-saving-and-loading/using-the-document-directory-to-store-files
void setFileStorePath(const char *p);
char *getFileStorePath();

void setFSPath(char *p);

void testD3(){
   int get_time(void);
   NSDateFormatter *dateformater =[[NSDateFormatter alloc] init];
   [dateformater setLocale:[NSLocale localeWithLocaleIdentifier:@"en"]];
   [dateformater setDateStyle:kCFDateFormatterMediumStyle];//set current locale
   [dateformater setTimeStyle:kCFDateFormatterNoStyle];
   NSDate *date = [NSDate dateWithTimeIntervalSince1970:get_time()];
   NSString *s = [dateformater stringFromDate:date];
   NSLog(@"date %@",s);
   [dateformater release];
}

void testD(){
   int get_time();
   // CFDateRef date = CFDateCreate(NULL, get_time()-kCFAbsoluteTimeIntervalSince1970);
   CFLocaleRef currentLocale = CFLocaleCopyCurrent();
   
   CFDateFormatterRef dateFormatter = CFDateFormatterCreate
   (NULL, currentLocale, kCFDateFormatterLongStyle, kCFDateFormatterLongStyle);
   
   CFStringRef formattedString = CFDateFormatterCreateStringWithAbsoluteTime
   (NULL, dateFormatter, get_time()-kCFAbsoluteTimeIntervalSince1970);//date);
   CFShow(formattedString);
   
   // Memory management
   //CFRelease(date);
   CFRelease(currentLocale);
   CFRelease(dateFormatter);
   CFRelease(formattedString);
}
void testD2(){
   int get_time();
   CFDateRef date = CFDateCreate(NULL, get_time()-kCFAbsoluteTimeIntervalSince1970);
   CFLocaleRef currentLocale = CFLocaleCopyCurrent();
   
   CFDateFormatterRef dateFormatter = CFDateFormatterCreate
   (NULL, currentLocale, kCFDateFormatterNoStyle, kCFDateFormatterShortStyle);
   
   CFStringRef formattedString = CFDateFormatterCreateStringWithDate
   (NULL, dateFormatter, date);
   CFShow(formattedString);
   
   // Memory management
   CFRelease(date);
   CFRelease(currentLocale);
   CFRelease(dateFormatter);
   CFRelease(formattedString);
}


#import <mach/mach.h>
#import <mach/mach_host.h>

void apple_log_CFStr(const char *p, CFStringRef str){
   NSLog(@"%s %@",p,str);
   
}
void apple_startup_log(const char *p){
   NSLog(@"%s\n", p);
}
void apple_log_x(const char *p){
   NSLog(@"%s", p);
}
void tmp_log(const char *p){
   NSLog(@"%s", p);
}


void tivi_log1(const char *p, int val){
   NSLog(@"%s=%d\n", p, val);
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
      NSLog(@"Failed to fetch vm statistics");
      return 0;
   }
   
   /* Stats in bytes */
   unsigned int mem_free = vm_stat.free_count * pagesize;
   return mem_free;
}
void freemem_to_log(){
   unsigned int uiU=usedMemory();
   unsigned int ui=get_free_memory();
   NSLog(@"freemem=%dK, used-mem=%dK",ui>>10, uiU>>10);
}

#define T_MAX_DEV_ID_LEN 63
#define T_MAX_DEV_ID_LEN_BIN (T_MAX_DEV_ID_LEN/2)

static char bufDevID[T_MAX_DEV_ID_LEN+2];
static char bufMD5[T_MAX_DEV_ID_LEN+32+1];

void initDevID(){
   
   memset(bufDevID,0,sizeof(bufDevID));
   
#if 0
   //depricated  6.0
   NSString *n = [[UIDevice currentDevice]uniqueIdentifier];
   
   const char *pn=n.UTF8String;
#else
   int iDevIdLen=0;
   char fn[1024];
   snprintf(fn,sizeof(fn)-1, "%s/devid-hex.txt", getFileStorePath());
   
   
   char *pn=loadFile(fn, iDevIdLen);
   
 //  NSLog(@"init Dev[%s+%s+%d]",fn,pn ? pn:" ", iDevIdLen);
   
   if(!pn || iDevIdLen<=0){
   
      pn=&bufDevID[0];
      
      FILE *f=fopen("/dev/urandom","rb");
      if(f){
         unsigned char buf[T_MAX_DEV_ID_LEN_BIN+1];
         fread(buf,1,T_MAX_DEV_ID_LEN_BIN,f);
         fclose(f);
         
         bin2Hex(buf, bufDevID, T_MAX_DEV_ID_LEN_BIN);
         bufDevID[T_MAX_DEV_ID_LEN]=0;
         
         saveFile(fn, bufDevID, T_MAX_DEV_ID_LEN);
         setFileAttributes(fn,0);
      }
      
   }
   else{
      //if app restarts we see NSFileProtectionComplete
      
      //why it does not work at the first time??
      //must stay here
      setFileAttributes(fn,0);
   }
   
#endif
   void safeStrCpy(char *dst, const char *name, int iMaxSize);
   safeStrCpy(&bufDevID[0],pn,sizeof(bufDevID)-1);
   
   int calcMD5(unsigned char *p, int iLen, char *out);
   calcMD5((unsigned char*)pn,strlen(pn),&bufMD5[0]);
  // NSLog(@"ok Dev[%s+%s+%s+%d]",bufMD5,bufDevID , pn,strlen(pn));
   
   
}


static char push_token[256]={0};
const char *push_fn = "push-token.txt";

void setPushToken(const char *p){
   int l = snprintf(push_token, sizeof(push_token),"%s",p);
   char fn[2048];
   snprintf(fn,sizeof(fn)-1, "%s/%s", getFileStorePath(),push_fn);
   
   saveFile(fn, (void*)p, l);
   
   void *getAccountByID(int id);
   void * ph = getAccountByID(0);
   if(!ph)return;
   
   const char* sendEngMsg(void *pEng, const char *p);

   const char*res =  sendEngMsg(NULL, "all_online");
   if(res && strcmp(res,"true")==0){
      sendEngMsg(NULL,":rereg");
   }
   
   
   //   NSString * t = [NSString stringWithFormat:@":push-token %@",newToken ];
   
   //doCmd(t.UTF8String);
}

void setVPushToken(const char *p){
   setPushToken(p);
}

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
//TODO move to os/ios.mm
const char *getVersionName(){
   
   static char buf[256]={0};
   if(buf[0])return buf;
   
   NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
   NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
   
   snprintf(buf, sizeof(buf), "%s",version.UTF8String);
   return buf;
}

const char *getAppID(){
   static char appid[256]={0};
   if(appid[0])return appid;
   
   
   NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
   
   if(1){
#if defined(DEBUG)
      snprintf(appid, sizeof(appid), "%s.voip--DEV",bundleIdentifier.UTF8String);
#else
      snprintf(appid, sizeof(appid), "%s.voip",bundleIdentifier.UTF8String);
#endif
      return appid;
   }
#if defined(DEBUG)
   snprintf(appid, sizeof(appid), "%s--DEV",bundleIdentifier.UTF8String);
#else
   snprintf(appid, sizeof(appid), "%s",bundleIdentifier.UTF8String);
#endif
   
   
   return appid;

}

const char *t_getDevID(int &l){
   l=63;
   return &bufDevID[0];
}

const char *t_getDevID_md5(){
   
   return &bufMD5[0];
}


int iAppStartTime;
int get_time();

int secSinceAppStarted(){
   return get_time()-iAppStartTime;
}

void rememberAppStartupTime(){
   iAppStartTime=get_time();
}

/*
 @interface STKeychain : NSObject
 
 + (NSString *)getPasswordForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error;
 + (BOOL)storeUsername:(NSString *)username andPassword:(NSString *)password forServiceName:(NSString *)serviceName updateExisting:(BOOL)updateExisting error:(NSError **)error;
 + (BOOL)deleteItemForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error;
 
 @end
 */
#import "STKeychain.h"

void testKC(){
   static NSString *serv_name= @"SIP_SC_TEST";
   if(0){
      NSError *er =nil;
      [STKeychain storeUsername:@"sip_test_user" andPassword:@"sip_test_pwd" forServiceName:serv_name updateExisting:NO error:&er];
   }
   if(1){
      NSError *er =nil;
      NSString * p = [STKeychain getPasswordForUsername:@"sip_test_user" andServiceName:serv_name error:&er];
      NSLog(@"pwd=%@ err=%@",p,er);
   }
}

void loadPWDKey(){
   
   static NSString *serv_name= @"_SIP_SC";
   static NSString *key_id= @"_SIP_USER_PWD_KEY";
   
#define T_AES_KEY_SIZE 32
   NSLog(@"KC");

   unsigned char buf[T_AES_KEY_SIZE+2];
   char bufHex[T_AES_KEY_SIZE*2+2];
   memset(buf, 0, sizeof(buf));
   
   NSError *er =nil;
   NSString * key = [STKeychain getPasswordForUsername:key_id andServiceName:serv_name error:&er];
   if(key)key = [[NSString alloc]initWithString:key];
   //printf("k=[%s]\n",key?key.UTF8String:"null");
  // [STKeychain deleteItemForUsername:key_id andServiceName:serv_name error:&er];
   //exit(0);
   if(er){
      NSLog(@"KC - getPasswordForUsername err=%@", er);
   }
   
   if(!key  || key.length<1){
      KeychainItemWrapper *keychain = [[KeychainItemWrapper alloc] initWithIdentifier:@"SC-SP-key" accessGroup:nil];
      key=[keychain objectForKey:(id)kSecValueData];
    //   printf("k=[%s]\n",key.UTF8String);
     // exit(0);
      //migrate
      if(key && key.length>0){
         key = [[NSString alloc]initWithString:key];
         NSError *er =nil;
         [STKeychain storeUsername:key_id andPassword:key forServiceName:serv_name updateExisting:NO error:&er];
         NSLog(@"KC - migrate %@", er?er:@"ok");
      }
      
      [keychain release];
      
   }
 //  exit(0);
   
   
   if(!key || key.length<1){
      NSLog(@"KC  %d %d ", !key , key? key.length: -5);

      FILE *f=fopen("/dev/urandom","rb");
      if(f){
         
         fread(buf,1,T_AES_KEY_SIZE,f);
         bin2Hex(buf, bufHex, T_AES_KEY_SIZE);
         if(key)[key release];
         
         key = [[NSString alloc] initWithUTF8String: bufHex ];
#if 0
         [keychain setObject:(__bridge id)kSecAttrAccessibleAlwaysThisDeviceOnly forKey:(__bridge id)kSecAttrAccessible];
         [keychain setObject:key forKey:(id)kSecValueData];
#else
         NSError *er =nil;
         [STKeychain storeUsername:key_id andPassword:key forServiceName:serv_name updateExisting:NO error:&er];
         NSLog(@"KC - save  %@", er?er:@"ok");

#endif
         fclose(f);
      }
   }
   else{
      int l = key.length;
      if(l > T_AES_KEY_SIZE*2)l = T_AES_KEY_SIZE*2;
      hex2BinL(buf, (char*)key.UTF8String, l);
   }
   
   void setPWDKey(unsigned char *k, int iLen);
   setPWDKey(buf, T_AES_KEY_SIZE);
   
   if(key)[key release];

   NSLog(@"KC - ok");
   
}

static const char *storeGetAPIKey(int iGet, const char *p = NULL){
   static NSString *serv_name= @"_SIP_API";
   static NSString *key_id= @"_API";
   

   NSLog(@"KC-API");
   

   if(iGet){
      static char bufAPI[128];
      memset(bufAPI, 0, sizeof(bufAPI));
      
      NSError *er =nil;
      NSString * key = [STKeychain getPasswordForUsername:key_id andServiceName:serv_name error:&er];
      if(er){
         NSLog(@"KC-API - getPasswordForUsername err=%@", er);
      }
      if(key && key.length>0){
         strncpy(bufAPI, key.UTF8String, sizeof(bufAPI));
         bufAPI[sizeof(bufAPI)-1]=0;
      }
      else return NULL;
      
      return &bufAPI[0];
   }
   else{
      
      NSError *er =nil;
      NSString *key = [[NSString alloc] initWithUTF8String:p];
      [STKeychain storeUsername:key_id andPassword:key forServiceName:serv_name updateExisting:YES error:&er];
      [key release];
      if(er){
         NSLog(@"KC-API  %@", er?er:@"ok");
         return NULL;
      }
      
   }

   NSLog(@"KC-API - ok");
   return p;
}

int storeAPIKeyToKC(const char *p){
   const char *r = storeGetAPIKey(0, p);
   return r ? 0 : -1;
}

const char * getAPIKeyFromKC(){
   return storeGetAPIKey(1, NULL);
}


int getIOSVersion(){
   static int v =0;
   if(v)return v;
   NSString *ver = [[UIDevice currentDevice] systemVersion];
   v = [ver intValue];
   return v;
}


const char *getPrefLang(){
   NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
   NSArray* languages = [defs objectForKey:@"AppleLanguages"];
   NSString *current = [languages objectAtIndex:0];
   NSLog(@"preferredLang: %@", current);
   /*
   NSArray  *a = [NSLocale preferredLanguages];
   for(int i=0;i<a.count;i++){
      NSLog(@"pl=%d: %@",i, a[i]);
   }
   */
   
   return current.UTF8String;
   
}

void initLang(const char *pDef);

void setProvisioningToDevelop();

void Log(char const* format, ...){
   char buf[2048];
   
   va_list arg;
   va_start(arg, format);
   vsnprintf(buf, sizeof(buf), format, arg);
   va_end( arg );
   
 //  log_fnc(tag, buf);
   NSLog(@"axolog=[%s]", buf);
}

int main(int argc, char *argv[])
{
   
    //09/24/15 set ios9 network debugging logs
//    setenv("CFNETWORK_DIAGNOSTICS", "3", 1);

   //puts(argv[0]);
   // void test_pwd_ed(int iSetKey);test_pwd_ed(1);exit(0);
   
   NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
  // void setProvisioningToDevelop();
//#warning REMOVE THIS not using Production
  //setProvisioningToDevelop();
   testD3();

//   return 0;
   

    //force english
  // getPrefLang();
   /*
    [[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithObjects:@"de", nil] forKey:@"AppleLanguages"];
   //[NSUserDefaults resetStandardUserDefaults];
    [[NSUserDefaults standardUserDefaults] synchronize];
   */
  
   setFSPath(argv[0]);
   
   const char *pLang = getPrefLang();//get default lan
   initLang(pLang);
   
#if defined(DEBUG)
   NSLog(@"[path=%s] build=debug",argv[0]);
#else
   NSLog(@"[path=%s] build=release",argv[0]);
#endif
   
    void initDevID();
   initDevID();
   
   rememberAppStartupTime();
   
   loadPWDKey();
   
   int isProvisioned(int iCheckNow);
   int z_main_init(int argc, const char* argv[]);
   void initGlobConstr();
   
   if(isProvisioned(1)){
      
      initGlobConstr();
      
      const char *x[]={""};
      z_main_init(0,x);
   }
   else{
      
   }
   
   freemem_to_log();
   
   int retVal = UIApplicationMain(argc, argv, nil, nil);// NSStringFromClass([AppDelegate class]));
   
   [pool release];
   return retVal;
   
}

#import <mach/mach.h>

float cpu_usage()
{
   //--
   return 0.1;
   //cpu_usage is  leaking memory????
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
}
/*
 [[NSNotificationCenter defaultCenter] addObserver: self
 selector:@selector(receivedRotate:)
 name:UIDeviceOrientationDidChangeNotification
 object: nil];
 
 - (void)receivedRotate:(NSNotification*)notif {
 UIDeviceOrientation interfaceOrientation = [[UIDevice currentDevice] orientation];
 switch (interfaceOrientation) {
 case UIInterfaceOrientationPortrait: {
 break;
 }
 case UIInterfaceOrientationLandscapeLeft: {
 break;
 }
 case UIInterfaceOrientationLandscapeRight: {
 break;
 }
 default:
 break;
 }
 }
 
 */
