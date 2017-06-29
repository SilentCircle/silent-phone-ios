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
//  DBManager+Encryption.m
//  SPi3
//
//  Created by Gints Osis on 01/08/16.
//  Copyright © 2016 Silent Circle. All rights reserved.
//

#import "DBManager+Encryption.h"
@implementation DBManager (Encryption)
void encryptData(const char *name, NSString *nsToEncrypt, std::string & str){
    unsigned char *get32ByteAxoKey(void);
    unsigned char *key = get32ByteAxoKey();
    
    AESencrypt aes;
    
    aes.key256((const uint8_t*)key);
    
    int len = (int)[nsToEncrypt lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    
    // Decrypt the session data and initialize a conversation
    uint8_t* sessionEnc = new uint8_t[len+1];
    unsigned char iv[] = "0123456789abcdef0123456789abcdef";
    
    snprintf((char*)iv, sizeof(iv),"%s",name);
    
    aes.cfb_encrypt((unsigned char*)nsToEncrypt.UTF8String, sessionEnc, len, iv);
    str.assign((char *)sessionEnc, len);
    delete[] sessionEnc;
}

-(NSString *)decryptData:(const char *)name dataFromDB: (std::string &) dataFromDB{
    unsigned char *get32ByteAxoKey(void);
    unsigned char *key = get32ByteAxoKey();
    
    AESencrypt aes;
    
    aes.key256((const uint8_t*)key);
    
    int len = (int)dataFromDB.size();
    
    // Decrypt the session data and initialize a conversation
    uint8_t* sessionDec = new uint8_t[len+1];
    unsigned char iv[] = "0123456789abcdef0123456789abcdef";
    
    snprintf((char*)iv, sizeof(iv),"%s", name);
    
    aes.cfb_decrypt((unsigned char*)dataFromDB.data(), sessionDec, len, iv);
    
    sessionDec[len]=0;
    
    NSString *ns = [NSString stringWithUTF8String:(char*)sessionDec];
    
    delete[] sessionDec;
    return ns;
}
@end
