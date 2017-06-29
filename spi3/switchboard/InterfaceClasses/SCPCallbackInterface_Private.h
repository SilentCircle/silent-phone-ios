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
//  SCPCallbackInterface_Private.h
//  SCPSwitchboard
//
//  Created by Eric Turner on 5/27/15.
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

/**
 * This header declares C funtions implemented elsewhere.
 */
#ifndef SCPSwitchboard_SCPCallbackInterface_Private_h
#define SCPSwitchboard_SCPCallbackInterface_Private_h

//implemented in SCPCallbackInterface.mm
int fncCBRet(void *ret, void *ph, int iCallID, int msgid, const char *psz, int iSZLen);
void _prov_cb(void *p, int ok, const char *pMsg);

// t_a_main.cpp
const char* sendEngMsg(void *pEng, const char *p);
//int doCmd(const char *p, void *pEng);
int doCmd(const char *cmd, int iCallID, void *pEng);

// prov.cpp
int checkProvUserPass(const char *pUN, const char *pPWD, void (*cb)(void *p, int ok, const char *pMsg), void *cbRet);

// sys_utils.cpp
int get_time();

// ios.mm
void initLang(const char *pDef);
//int isBackgroundReadable(const char *fn);
//void log_file_protection_prop(const char *fn);
//void setFileAttributes(const char *fn, int iProtect);
//char *loadFile(const  char *fn, int &iLen);
//void saveFile(const char *fn,void *p, int iLen);
//void bin2Hex(unsigned char *Bin, char * Hex ,int iBinLen);
//int hex2BinL(unsigned char *Bin, char *Hex, int iLen);

// prov.cpp
void setProvisioningToDevelop();

#endif
