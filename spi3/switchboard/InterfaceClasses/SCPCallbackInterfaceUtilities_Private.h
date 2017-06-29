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
//  SCPCallbackInterfaceUtilities_Private.h
//  SCPSwitchboard
//
//  Created by Eric Turner on 5/24/15.
//  Based on original work by Janis Narbuts SP1
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

/**
 * This header declares C funtions implemented elsewhere.
 */
#ifndef SCPSwitchboard_SCPCallbackInterfaceEngineUtilities_h
#define SCPSwitchboard_SCPCallbackInterfaceEngineUtilities_h

#include "t_devID.h"

//From: SP3 initAppHelper
void setFileAttributes(const char *fn, int iProtect);
char *loadFile(const  char *fn, int &iLen);
void saveFile(const char *fn,void *p, int iLen);
void bin2Hex(unsigned char *Bin, char * Hex ,int iBinLen);
int hex2BinL(unsigned char *Bin, char *Hex, int iLen);

//http://www.ios-developer.net/iphone-ipad-programmer/development/file-saving-and-loading/using-the-document-directory-to-store-files
void setFileStorePath(const char *p);
char *getFileStorePath();
void setFSPath(char *p);

int isProvisioned(int iCheckNow);

#pragma mark - AppID
const char *getAppID();

#pragma mark - DeviceID
devIdErrorCode initDevID(void);
const char *t_getDevID(int &l);
const char *t_getDevID_md5();

#pragma mark - PWDKey
void loadPWDKey();

#pragma mark - SIP setup
void setupSIPAuth();

#pragma mark - PushToken
const char *getPushToken();
bool setPushToken(const char *p);

#pragma mark - Utilities
int getIOSVersion();
const char *getVersionName();
const char *getPrefLang();
float cpu_usage();
vm_size_t usedMemory(void);
unsigned int get_free_memory();
void freemem_to_log();

#pragma mark - File System Utilities
//implemented in ios.mm
void setFSPath(char *p);
//implemented in CTLangStrings.cpp
void initLang(const char *pDef);


#pragma mark - Logging
void tivi_log1(const char *p, int val);

#endif
