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
//  SPUser.h
//  VoipPhone
//
//  Created by Ethan Arutunian on 12/31/14.
//
//

#import <UIKit/UIKit.h>

typedef enum UserPermission_e {
    UserPermission_CanReceiveVoicemail = 0
    ,UserPermission_CanSendMedia
    ,UserPermission_CreateConference
    ,UserPermission_HasOCA
    ,UserPermission_InboundCalling
    ,UserPermission_InboundMessaging
    ,UserPermission_InitiateVideo
    ,UserPermission_OutboundCalling
    ,UserPermission_OutboundMessaging
    ,UserPermission_SendAttachment
    ,UserPermission_OutboundPSTNCalling
} UserPermission;

#if HAS_DATA_RETENTION
// Data Retention types
static uint32_t kDRType_None                 = 0x00;
static uint32_t kDRType_Attachment_PlainText = 0x01;
static uint32_t kDRType_Call_Metadata        = 0x02;
static uint32_t kDRType_Call_PlainText       = 0x04;
static uint32_t kDRType_Message_Metadata     = 0x08;
static uint32_t kDRType_Message_PlainText    = 0x10;

// Data Retention Block codes
static uint32_t kDRBlock_None                 = 0x00;
static uint32_t kDRBlock_RemoteMetadata       = 0x01;
static uint32_t kDRBlock_RemoteData           = 0x02;
static uint32_t kDRBlock_LocalMetadata        = 0x04;
static uint32_t kDRBlock_LocalData            = 0x08;
#endif // HAS_DATA_RETENTION


@interface SPUser : NSObject

@property (nonatomic, strong) NSString *userID;
@property (nonatomic, strong) NSString *uuid;
@property (nonatomic, strong) NSString *avatarURL;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) NSString *displayAlias;
@property (nonatomic, strong) NSString *displayTN;
@property (nonatomic, strong) NSString *displayOrganization;
@property (nonatomic) int devicesCnt;
@property (nonatomic) int prekeyCnt;
@property (nonatomic, strong) NSString *displayPlan;
@property (nonatomic, strong) NSDate *subscriptionExpireDate;
@property (nonatomic, assign) BOOL subscriptionAutoRenews;
@property (nonatomic, strong) NSDictionary *permissions;
@property (nonatomic, assign) double remainingCredit;
@property (nonatomic, strong) NSString *creditCurrency;
@property (nonatomic, strong) NSNumber *maximumBurnSecs;
@property (nonatomic, strong) NSString *model;
@property (nonatomic, assign) int minutesLeft;
@property (nonatomic, assign) int totalMinutes;

#if HAS_DATA_RETENTION
@property (nonatomic, assign) BOOL drEnabled;
@property (nonatomic, strong) NSString *drOrganization;
@property (nonatomic, assign) uint32_t drTypeCode; // bitfield of enabled DR types
@property (nonatomic, assign) uint32_t drBlockCode; // bitfield of enabled DR blocks
#endif // HAS_DATA_RETENTION

- (SPUser *)initWithDict:(NSDictionary *)dict;
//- (NSDictionary *)toDict;

#if HAS_DATA_RETENTION
+ (uint32_t)DRTypeCodeFromDict:(NSDictionary *)dict;
+ (uint32_t)DRBlockCodeFromDict:(NSDictionary *)dict;
#endif // HAS_DATA_RETENTION

- (BOOL)hasPermission:(UserPermission)permission;
- (NSString *)localizedRemainingCredits;

@end
