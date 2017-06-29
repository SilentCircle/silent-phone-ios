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
//  SCPChatManager.m
//  SCPSwitchboard
//
//  Created by Eric Turner on 7/9/15.
//  Copyright (c) 2015 Silent Circle. All rights reserved.
//

#import "SCPChatManager.h"
//#import "axolotl_glue.h"
//#import "DBManager.h"
//#import <silentphone_ios/DBManager.h>

SCPChatManager *SPChatManager = nil;

//JN orig stubs
//int32_t recv_axo(const std::string& msg, const std::string& attachment, const std::string& atribs){
//    
//    NSString *nsMsg= [NSString stringWithUTF8String:msg.c_str()];
//    
//    NSLog(@"axomsg=%@ att=%s atr=%s", nsMsg, attachment.c_str(), atribs.c_str());
//    
//    return 0; 
//}
//
//void state_report_axo(int64_t messageID, int32_t code, const std::string& stateMsg){
//    NSLog(@"state_report_axo: messageId: %lld, code: %d, stateMsg: %s", messageID, code, stateMsg.c_str());
//}

//Gints current use
//void stateAxoMsg(int64_t messageIdentfier, int32_t statusCode, const std::string& stateInformation);
//int32_t receiveAxoMsg(const std::string& messageDescriptor, const std::string& attachementDescriptor, const std::string& messageAttributes);


@implementation SCPChatManager
{    
//    DBManager *_dbManager;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
        
    SPChatManager = self;

//    CTAxoInterfaceBase::sharedInstance()->setCallbacks(stateAxoMsg, receiveAxoMsg);
    
    return self;
}

-(int64_t)send:(NSString *)msg attachment:(NSString *)attachment attribs:(NSString *)attribs {
//    return CTAxoInterfaceBase::sharedInstance()->sendJSONMessage(msg.UTF8String, attachment.UTF8String, attribs.UTF8String);
    return 0;
}

@end

