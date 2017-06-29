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
//VoipPhone
//Created by Janis Narbuts
//Copyright (c) 2004-2012 Tivi LTD, www.tiviphone.com. All rights reserved.

#include <string.h>
#import <UIKit/UIKit.h>
#include <CFNetwork/CFNetwork.h>
#include "../baseclasses/CTBase.h"
#import "STKeychain.h"
#import "UIDevice+Hardware.h"
#import "SCFileManager.h"
#import "SCSPLog_private.h"

//#if DEBUG
//static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
//#else
//static const DDLogLevel ddLogLevel = DDLogLevelError;
//#endif

NSString *toNSFromTBN(CTStrBase *b, int N){
   if(!b || !b->getLen())return @"";
   NSString *r=[NSString stringWithCharacters:(const unichar*)b->getText() length:MIN(N,b->getLen())];
   return r;
}

NSString *toNSFromTB(CTStrBase *b){
   if(!b || !b->getLen())return @"";

   NSString *r=[NSString stringWithCharacters:(const unichar*)b->getText() length:b->getLen()];   
   return r;
}

char * t_CFStringCopyUTF8String(CFStringRef str,  char *buffer, int iMaxLen) {
   if (str == NULL || !buffer || iMaxLen<1) {
      return NULL;
   }
   buffer[0]=0;
   iMaxLen--;
   
   // CFIndex length = CFStringGetLength(aString);
   // CFIndex maxSize  = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8);
   
   if (CFStringGetCString(str, buffer, iMaxLen, kCFStringEncodingUTF8)) {
      return buffer;
   }
   return NULL;
}

const char *t_getVersion(){
   NSString* nsB = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
   if(!nsB)return "error";
   return nsB.UTF8String;
}



int showSSLErrorMsg(void *ret, const char *p){
   DDLogError(@"showSSLErrorMsg: tls err --exiting %s",p);
   exit(1);
   return 0;
}

NSString *findFilePathNS(const char *fn){
   char bufFN[256];
   const char *pExt="";
   int l=(int)strlen(fn);
   strncpy(bufFN,fn,255);
   bufFN[255]=0;
   if(l>255)l=255;
   for(int i=l-1;i>=0;i--){
      bufFN[i]=fn[i];
      if(fn[i]=='.'){
         bufFN[i]=0;
         pExt=&bufFN[i+1];
         
      }
      
   }
//   printf("[f=%s ext=%s]\n",&bufFN[0],pExt);
    DDLogVerbose(@"-(%@)findFilePathNS: file=%s ext=%s",__THIS_FILE__,&bufFN[0],pExt);
   // return "";
   NSString *ns= [[NSBundle mainBundle] pathForResource: [NSString stringWithUTF8String:&bufFN[0]] ofType: [NSString stringWithUTF8String:pExt]];
   return ns;
   
}
const char *findFilePath(const char *fn){
   NSString *ns=findFilePathNS(fn);
   if(!ns)return NULL;
   return [ns UTF8String];
   
}

char *iosLoadFile(const char *fn, int &iLen )
{
   NSString *ns=findFilePathNS(fn);
   iLen=0;
   if(!ns)return 0;
   NSData *data = [NSData dataWithContentsOfFile:ns];//autorelease];
   if(!data)return NULL;
   
   char *p=new char[data.length+1];
   if(p){
      iLen=(int)data.length;
      memcpy(p,data.bytes,iLen);
      p[iLen]=0;
   }
   //--printf("[ptr=%p,%p]",data,p);
   //[data release];//?? crash
   return p;
}

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

void setFSPath(char *p){   
    NSString *path = [SCFileManager tiviDirectoryURL].relativePath;
    setFileStorePath([path UTF8String]);   
}


void *initARPool(){
#if !__has_feature(objc_arc)
   return [[NSAutoreleasePool alloc] init];
#else
   return (void*)1;//[[NSAutoreleasePool alloc] init];
#endif
}
void relARPool(void *p){
#if !__has_feature(objc_arc)
   NSAutoreleasePool *pool=(NSAutoreleasePool*)p;
   [pool release];
#else
   
#endif
}



const char *t_getDev_name(){
    
    // Fetch the device name (set by user)
    NSString *n = [[UIDevice currentDevice] name];

#if TARGET_IPHONE_SIMULATOR
    if(n)
        n = [n stringByAppendingString:@" - Simulator"];
#endif

    // If the name has not been set for some reason
    // fetch the device platform
    if(n.length == 0)
        n = [[UIDevice currentDevice] platform];
    
    return n.UTF8String;
}

int isTablet(void){
   static int ok = -1;
   if(ok != -1)return ok;
   
   ok = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
   if(ok)return ok;
   
   NSString *ns = [[UIDevice currentDevice] model];
   ok = [ns hasPrefix:@"iPad"] || [ns isEqualToString:@"iPad"];
   return ok;
}

const char *t_getDev_keychainId(const char *s){
    
    //10/24/15 - this method signature was changed months ago;
    // not sure why it was not updated here.
//    NSString *dId = [STKeychain getEncodedDeviceIdForUsername:[NSString stringWithUTF8String:s]];
    NSString *dId = [STKeychain getEncodedDeviceId];

    return dId.UTF8String;
}


int isBackgroundReadable(const char *fn){
   NSString *p = [[[NSFileManager defaultManager] attributesOfItemAtPath: [NSString stringWithUTF8String: fn ]
                                                                   error:NULL] valueForKey:NSFileProtectionKey];
   return [p isEqualToString:NSFileProtectionNone];
}

void log_file_protection_prop(const char *fn){
   /*
    NSFileProtectionKey
    NSFileProtectionNone
    
    */
   
   NSString *p = [[[NSFileManager defaultManager] attributesOfItemAtPath: [NSString stringWithUTF8String: fn ]
                                                                   error:NULL] valueForKey:NSFileProtectionKey];
   DDLogVerbose(@"-(%@)log_file_protection_prop: [fn(%s)=%@",__THIS_FILE__,fn,p);
}

void setFileAttributes(const char *fn, int iProtect){
   
   NSString * const pr = iProtect? NSFileProtectionComplete : NSFileProtectionNone;
    if (iProtect) {
        DDLogVerbose(@"-(%@)setFileAttributes: called to set %s with attribute NSFileProtectionComplete",__THIS_FILE__,fn);
    }
   NSDictionary *d=[NSDictionary dictionaryWithObject:pr
                                               forKey:NSFileProtectionKey];
   NSError *err = nil;
   
   BOOL b = [[NSFileManager defaultManager] setAttributes: d ofItemAtPath:[NSString stringWithUTF8String: fn ]error:&err  ];
   if(!b){
      DDLogVerbose(@"-(%@)setFileAttributes: (%s,%d)=%d er=[%@]",__THIS_FILE__,fn, iProtect, b, err.debugDescription);
   }
}

void dbg_sip_ios(char *p, int iLen){
//   NSLog(@"%.*s",iLen, p);
    TV_SIPInfo(@"%.*s", iLen, p);
}



