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
//  SCPCallbackInterface+Utilities.h
//  SCPSwitchboard
//
//  Created by Eric Turner on 5/24/15.
//  Based on original work by Janis Narbuts SP1
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

extern NSString * const kSIP_PWD_UsernameKey;
extern NSString * const kSIP_PWD_ServiceNameKey;
extern NSString * const kSIP_API_UsernameKey;
extern NSString * const kSIP_API_ServiceNameKey;

#import "SCPCallbackInterface.h"

@interface SCPCallbackInterface (Utilities)

// Unneeded API
///**
// * C functions declared in SCPCallbackInterfaceEngineUtilities.h,
//*/
//
//- (NSString *)appId;
//- (NSString *)pushToken;
//- (NSString *)versionName;
//- (NSInteger)iOSVersion;
//- (NSString *)prefLang;
//- (CGFloat)cpuUsage;
//- (void)tiviLog1:(NSString *)msg cfgId:(NSInteger)cfgId;

@end

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
void rememberAppStartupTime();
void freemem_to_log();
const char *getPrefLang();

//main/tools/os/sys_utils.cpp
int get_time();
//CTLangStrings.cpp
void initLang(const char *pDef);
